import base64
import hashlib
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import uuid

from tests.support.python import ROOT, RepoTestCase

TEMPLATE = "home/.chezmoitemplates/orca-settings.desired.json.tmpl"
SCRIPT = str(ROOT / "scripts/orca/settings-reconcile")
# Orca's profile-state schema (profile-state-database-schema.ts at v1.4.217).
SCHEMA = """
CREATE TABLE profile_state_meta (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);
CREATE TABLE profile_state_documents (
  domain TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL, domain_version INTEGER NOT NULL,
  revision INTEGER NOT NULL, updated_at INTEGER NOT NULL, content_hash TEXT NOT NULL);
"""


def sha256(text):
    return hashlib.sha256(text.encode()).hexdigest()


class OrcaDesiredSettingsTests(RepoTestCase):
    def desired(self, machine, **data):
        return json.loads(self.render(TEMPLATE, machine, data=data))

    def test_agent_and_editor_entries_follow_agent_clis_and_casks(self):
        editors = {"cursor", "code"}
        labels = ["Open in Finder", "Open in Cursor", "Open in VS Code"]
        expected = {
            "personal": ("codex", {"cursor"}, editors, labels),
            "homelab": ("codex", {"cursor", "claude-agent-teams"}, set(), ["Open in Finder"]),
            "work": ("claude", {"codex", "omp", "gemini"}, editors, labels),
        }
        for machine, (default, hidden, open_in, quick) in expected.items():
            with self.subTest(machine=machine):
                settings = self.desired(machine)
                self.assertEqual(settings["defaultTuiAgent"], default)
                self.assertEqual(set(settings["disabledTuiAgents"]), hidden)
                self.assertEqual({app["command"] for app in settings["openInApplications"]}, open_in)
                self.assertEqual([entry["label"] for entry in settings["terminalQuickCommands"]], quick)
        settings = self.desired("work", machines_local={"agent_clis": ["claude"]})
        self.assertEqual(settings["defaultTuiAgent"], "claude")
        self.assertIn("cursor", settings["disabledTuiAgents"])
        self.assertNotIn("defaultTuiAgent", self.desired("ci"))

    def test_flat_preferences_adopt_the_agreed_values_and_drop_retired_keys(self):
        settings = self.desired("work")
        cursor = next(entry for entry in settings["terminalQuickCommands"] if entry["id"] == "open-in-cursor")
        self.assertEqual(cursor["command"], "cursor --classic . && exit")
        self.assertEqual(cursor["scope"], {"type": "global"})
        self.assertEqual(settings["terminalDividerColorDark"], "#c20000")
        self.assertEqual(settings["terminalShortcutPolicy"], "terminal-first")
        self.assertEqual(settings["workspaceDir"], str(self.home / "code/worktrees"))
        self.assertNotIn("terminalScrollbackBytes", settings)
        self.assertNotIn("settings", settings)


class OrcaSettingsReconcileTests(RepoTestCase):
    def setUp(self):
        super().setUp()
        self.user_data = self.work / "orca"
        self.profile = self.user_data / "profiles/local-default"
        self.profile.mkdir(parents=True)
        self.index = self.user_data / "orca-profile-index.json"
        self.index.write_text(json.dumps({
            "schemaVersion": 1, "activeProfileId": "local-default",
            "profiles": [{"id": "local-default", "name": "Personal"}],
        }))
        self.db = self.profile / "profile-state.db"
        self.seed({"theme": "system", "terminalShortcutPolicy": "orca-first", "userOnly": {"keep": "✳ café"}})

    def seed(self, settings, *, revision=41, user_version=3):
        for stale in self.profile.glob("profile-state.db*"):
            stale.unlink()
        con = sqlite3.connect(self.db, isolation_level=None)
        con.execute("PRAGMA journal_mode = WAL")
        con.execute(f"PRAGMA user_version = {user_version}")
        con.executescript(SCHEMA)
        payload = json.dumps(settings, separators=(",", ":"), ensure_ascii=False)
        repos = json.dumps({"entries": []})
        con.execute("INSERT INTO profile_state_meta VALUES ('profile_id', 'local-default'), ('revision', ?)",
                    (str(revision),))
        con.execute("INSERT INTO profile_state_documents VALUES ('settings', ?, 1, ?, 1000, ?)",
                    (payload, revision - 1, sha256(payload)))
        con.execute("INSERT INTO profile_state_documents VALUES ('repos', ?, 1, ?, 1000, ?)",
                    (repos, revision - 5, sha256(repos)))
        con.close()

    def reconcile(self, mode, *, expected_status=0, desired=None):
        desired = {"theme": "dark", "terminalShortcutPolicy": "terminal-first"} if desired is None else desired
        encoded = base64.b64encode(json.dumps(desired).encode()).decode()
        return self.command([SCRIPT, mode, "--user-data", str(self.user_data), "--desired-b64", encoded],
                            expected_status=expected_status)

    def store(self):
        con = sqlite3.connect(f"file:{self.db}?mode=ro", uri=True)
        rows = {domain: row for domain, *row in con.execute(
            "SELECT domain, payload, revision, updated_at, content_hash FROM profile_state_documents")}
        meta = dict(con.execute("SELECT key, value FROM profile_state_meta"))
        journal = con.execute("PRAGMA journal_mode").fetchone()[0]
        con.close()
        return rows, meta, journal

    def test_check_reports_drift_and_apply_writes_one_revision_fenced_settings_row(self):
        result = self.reconcile("check", expected_status=1)
        self.assertIn(b"2 of 2 tracked keys differ", result.stdout)
        self.assertIn(b'terminalShortcutPolicy: live "orca-first" -> desired "terminal-first"', result.stdout)
        result = self.reconcile("apply")
        self.assertIn(b"applied: profile revision 41 -> 42", result.stdout)
        rows, meta, journal = self.store()
        payload, revision, updated_at, content_hash = rows["settings"]
        settings = json.loads(payload)
        self.assertEqual(settings, {"theme": "dark", "terminalShortcutPolicy": "terminal-first",
                                    "userOnly": {"keep": "✳ café"}})
        self.assertEqual(list(settings), ["theme", "terminalShortcutPolicy", "userOnly"])
        self.assertEqual(payload, json.dumps(settings, separators=(",", ":"), ensure_ascii=False))
        self.assertEqual(content_hash, sha256(payload))
        self.assertEqual((revision, meta["revision"]), (42, "42"))
        self.assertGreater(updated_at, 1000)
        self.assertEqual(tuple(rows["repos"][1:]), (36, 1000, sha256(json.dumps({"entries": []}))))
        self.assertEqual(journal, "wal")
        self.assertFalse((self.user_data / ".profile-state-access/maintenance").exists())
        before = self.store()
        self.assertIn(b"ok: Orca settings (local-default) match all 2 tracked keys", self.reconcile("apply").stdout)
        self.assertEqual(self.store(), before)
        self.reconcile("check")

    def test_apply_refuses_while_orca_holds_the_store_and_leaves_no_lease_behind(self):
        access = self.user_data / ".profile-state-access"
        token = str(uuid.uuid4())
        lease = access / "participants" / token
        lease.mkdir(parents=True)
        owner = {"token": token, "pid": os.getpid(), "host": "here", "platform": sys.platform, "pidNamespace": None}
        (lease / f"{token}.owner").write_text(json.dumps(owner))
        result = self.reconcile("apply", expected_status=2)
        self.assertIn(f"Orca holds the profile store (pid {os.getpid()} on here)".encode(), result.stderr)
        self.assertEqual(self.store()[1]["revision"], "41")
        self.assertFalse((access / "maintenance").exists())
        self.assertEqual(list((access / "candidates").glob("*")), [])
        # A participant whose process has exited no longer blocks the write.
        exited = subprocess.Popen(["true"])
        exited.wait()
        (lease / f"{token}.owner").write_text(json.dumps(owner | {"pid": exited.pid}))
        self.reconcile("apply")
        self.assertEqual(self.store()[1]["revision"], "42")
        shutil.rmtree(lease)
        (access / "maintenance").mkdir()
        (access / "maintenance" / f"{token}.owner").write_text(json.dumps(owner))
        result = self.reconcile("apply", expected_status=2, desired={"theme": "light"})
        self.assertIn(b"another maintenance run holds the profile store", result.stderr)
        self.assertEqual(self.store()[1]["revision"], "42")

    def test_apply_fails_closed_on_a_foreign_store_version_and_skips_a_missing_database(self):
        self.seed({"theme": "system"}, user_version=4)
        result = self.reconcile("apply", expected_status=2)
        self.assertIn(b"user_version is 4, expected 3", result.stderr)
        self.assertEqual(self.store()[1]["revision"], "41")
        for stale in self.profile.glob("profile-state.db*"):
            stale.unlink()
        result = self.reconcile("check", expected_status=2)
        self.assertIn(b"no profile-state database", result.stderr)
        self.assertFalse(self.db.exists())

    def test_active_profile_resolves_from_the_index_with_its_backup_as_fallback(self):
        backup = self.user_data / "orca-profile-index.json.bak"
        backup.write_text(self.index.read_text())
        self.index.write_text("{torn")
        self.reconcile("check", expected_status=1)
        self.index.write_text(json.dumps({"schemaVersion": 1, "activeProfileId": "other",
                                          "profiles": [{"id": "other"}, {"id": "local-default"}]}))
        result = self.reconcile("check", expected_status=2)
        self.assertIn(b"profiles/other/profile-state.db", result.stderr)
