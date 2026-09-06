import json
import tomllib

from tests.support.python import ROOT, RepoTestCase


class ChezmoiConfigTests(RepoTestCase):
    def test_session_archive_alias_requires_explicit_host_registration(self):
        source = "home/dot_config/wiki-agent-sessions/config.toml.tmpl"
        missing = tomllib.loads(self.render(source).decode())
        self.assertEqual(missing, {"host_alias": ""})
        configured = tomllib.loads(self.render(source, data={
            "machines_local": {"wiki_host_alias": "buildbox"},
        }).decode())
        self.assertEqual(configured, {"host_alias": "buildbox"})

    def chezmoi(self, *args):
        return self.command([
            "chezmoi", "--source", str(ROOT), "--config", str(self.config),
            "--destination", str(self.home), "--cache", str(self.work / "cache"),
            "--persistent-state", str(self.work / "state.boltdb"), "--no-tty", *args,
        ])

    def test_initialization_persists_effective_machine_identity_and_disables_pager(self):
        self.chezmoi("init", "--promptDefaults", "--promptChoice", "machine_type=ci")
        text = self.config.read_text()
        config = tomllib.loads(text)
        self.assertEqual(config["pager"], "")
        self.assertEqual(config["data"]["machine_type"], "ci")
        self.assertNotIn("install_profile", text)
        effective = json.loads(self.chezmoi("dump-config", "--format=json").stdout)
        self.assertEqual(effective["pager"], "")
        self.assertEqual(effective["data"]["machine_type"], "ci")

    def test_reinitialization_carries_legacy_jamf_identity_to_the_top_level(self):
        self.config.write_text('[data]\nmachine_type = "work"\n[data.elevation]\njamf_policy_id = "LEGACY777"\n')
        self.chezmoi("init", "--promptDefaults")
        data = tomllib.loads(self.config.read_text())["data"]
        self.assertEqual(data["machine_type"], "work")
        self.assertEqual(data["jamf_policy_id"], "LEGACY777")

    def test_unmanaged_listing_excludes_local_and_secret_state_but_reports_unrelated_files(self):
        excluded = (
            ".zprofile.local", ".zshrc.local", ".config/chezmoi/chezmoi.toml",
            ".config/cmux/settings.json", ".config/op/config", ".gnupg/gpg.conf", ".ssh/config",
        )
        for name in (*excluded, ".local-unmanaged-marker"):
            path = self.home / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.touch()
        listing = self.chezmoi("--override-data", '{"machine_type":"personal"}', "unmanaged", "--path-style=relative").stdout.decode().splitlines()
        self.assertIn(".local-unmanaged-marker", listing)
        for prefix in (".zprofile.local", ".zshrc.local", ".config/chezmoi", ".config/cmux/settings.json", ".config/op", ".gnupg", ".ssh"):
            self.assertFalse(any(path == prefix or path.startswith(prefix + "/") for path in listing), listing)
