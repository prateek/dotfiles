import contextlib
import fcntl
import io
import itertools
import json
import os
from pathlib import Path
import runpy
import socket
import sqlite3
import subprocess
import tempfile
import threading
import unittest
from unittest.mock import patch

from tests.support.python import ROOT


SCRIPT = ROOT / "home/dot_local/bin/executable_orca-zen-mode"
BRIDGE = ROOT / "home/dot_local/libexec/orca-zen-mode.js"


class OrcaZenModeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.root = self.home / "Library/Application Support/orca"
        self.root.mkdir(parents=True)
        self.profile = self.root / "orca-profile-index.json"
        self.select_profile("test", "active-project")
        self.state = self.home / "state/orca-zen-mode/restore-test.json"
        self.ui = dict(pid=123, left=True, right=False, frontmost=True)
        self.preferences = dict(filterRepoIds=["previous-project", "another-project"],
                                hideSleepingWorkspaces=True, sidebarWidth=321)
        self.failed = False
        self.fail_rpc = False
        self.ignore_filter = False
        self.after_get = lambda: None
        self.writes = []
        self.rpc_writes = []
        self.main = runpy.run_path(str(SCRIPT))["main"]
        self.stopped = threading.Event()
        self.errors = []
        self.listener = socket.socket(socket.AF_UNIX)
        self.endpoint = str(self.home / "runtime.sock")
        self.listener.bind(self.endpoint)
        self.listener.listen()
        self.listener.settimeout(0.1)
        self.write_runtime()
        self.server = threading.Thread(target=self.serve)
        self.server.start()
        self.addCleanup(self.stop_server)

    def write_runtime(self):
        (self.root / "orca-runtime.json").write_text(json.dumps({
            "pid": self.ui["pid"], "authToken": "fixture-token",
            "transports": [{"kind": "unix", "endpoint": self.endpoint}]
        }))

    def select_profile(self, profile, repo):
        self.profile.write_text(json.dumps({"activeProfileId": profile}))
        database = self.root / "profiles" / profile / "profile-state.db"
        database.parent.mkdir(parents=True, exist_ok=True)
        with sqlite3.connect(database) as connection:
            connection.execute("CREATE TABLE IF NOT EXISTS profile_state_documents (domain TEXT PRIMARY KEY, payload TEXT)")
            connection.execute("INSERT OR REPLACE INTO profile_state_documents VALUES (?, ?)",
                               ("workspaceSession", json.dumps({"activeRepoId": repo,
                                "activeWorkspaceExecutionHostId": "runtime:remote-server"})))

    def serve(self):
        while not self.stopped.is_set():
            try:
                connection, _ = self.listener.accept()
            except TimeoutError:
                continue
            try:
                with connection, connection.makefile("rb") as stream:
                    request = json.loads(stream.readline())
                    self.assertEqual(request["authToken"], "fixture-token")
                    self.assertIn(request["method"], ["ui.get", "ui.set"])
                    if request["method"] == "ui.get":
                        self.after_get()
                    if request["method"] == "ui.set":
                        self.assertTrue(list(self.state.parent.glob("restore-*.json")),
                                        "save restoration before changing the filter")
                        self.assertEqual(list(request["params"]), ["filterRepoIds"],
                                         "do not overwrite unrelated UI preferences")
                        self.rpc_writes.append(request["params"])
                        if not self.ignore_filter:
                            self.preferences.update(request["params"])
                    response = {"id": request["id"], "ok": True, "result": {"ui": self.preferences}}
                    if self.fail_rpc and request["method"] == "ui.set":
                        response = {"id": request["id"], "ok": False, "error": {"message": "fixture failure"}}
                    connection.sendall(b'{"_keepalive":true}\n{"id":"another-request"}\n'
                                       + json.dumps(response).encode() + b"\n")
            except Exception as error:
                self.errors.append(error)

    def stop_server(self):
        self.stopped.set()
        self.server.join(timeout=2)
        self.listener.close()
        self.assertFalse(self.server.is_alive())
        if self.errors:
            raise self.errors[0]

    def osascript(self, argv, **kwargs):
        if len(argv) > 4:
            self.writes.append(argv[4:])
            self.assertTrue(list(self.state.parent.glob("restore-*.json")),
                            "save restoration before changing the UI")
            if self.failed:
                return subprocess.CompletedProcess(argv, 1, "", "Sidebar change failed")
            self.ui.update(left=json.loads(argv[5]), right=json.loads(argv[6]))
        return subprocess.CompletedProcess(argv, 0, json.dumps(self.ui), "")

    def invoke(self, *args):
        with (patch("sys.argv", [str(SCRIPT), *args]), patch("sys.platform", "darwin"),
              patch("pathlib.Path.home", return_value=self.home),
              patch.dict(os.environ, {"XDG_STATE_HOME": str(self.home / "state"),
                                      "ORCA_ENVIRONMENT": "wrong-server"}),
              patch("subprocess.run", side_effect=self.osascript),
              contextlib.redirect_stdout(io.StringIO())):
            self.main()

    def test_each_layout_and_filter_restores_after_sidebar_is_reopened(self):
        for left, right, filters in itertools.product([False, True], [False, True],
                                                      [[], ["previous-project", "another-project"]]):
            with self.subTest(left=left, right=right, filters=filters):
                self.ui.update(left=left, right=right)
                self.preferences["filterRepoIds"] = filters
                self.invoke()
                self.assertEqual((self.ui["left"], self.ui["right"]), (False, False))
                self.assertEqual(self.preferences["filterRepoIds"], ["active-project"])
                self.ui["left"] = True
                self.select_profile("test", "newly-selected-project")
                self.invoke()
                self.assertEqual((self.ui["left"], self.ui["right"]), (left, right))
                self.assertEqual(self.preferences, dict(filterRepoIds=filters,
                                 hideSleepingWorkspaces=True, sidebarWidth=321))
                self.assertFalse(self.state.exists())
                self.select_profile("test", "active-project")

    def test_failed_change_retains_restore_for_next_press(self):
        for boundary in ("sidebar", "rpc"):
            with self.subTest(boundary=boundary):
                self.failed = boundary == "sidebar"
                self.fail_rpc = boundary == "rpc"
                with self.assertRaisesRegex(RuntimeError, "Sidebar change failed|fixture failure"):
                    self.invoke()
                self.assertEqual(json.loads(self.state.read_text())["left"], True)
                self.ui["left"] = False  # A partial mutation must not become the new baseline.
                self.failed = self.fail_rpc = False
                self.invoke()
                self.assertEqual((self.ui["left"], self.ui["right"]), (True, False))
                self.assertEqual(self.preferences["filterRepoIds"], ["previous-project", "another-project"])
                self.assertFalse(self.state.exists())

    def test_restart_preserves_original_filter_and_layout(self):
        self.invoke()
        self.ui["pid"] += 1
        self.write_runtime()
        self.invoke()
        self.assertEqual((self.ui["left"], self.ui["right"]), (True, False))
        self.assertEqual(self.preferences["filterRepoIds"], ["previous-project", "another-project"])
        self.assertFalse(self.state.exists())

    def test_profiles_restore_independent_snapshots(self):
        self.invoke()
        self.select_profile("other", "other-project")
        self.ui.update(left=False, right=True)
        self.preferences["filterRepoIds"] = ["other-original"]
        self.invoke()
        self.assertEqual(self.preferences["filterRepoIds"], ["other-project"])
        self.invoke()
        self.assertEqual((self.ui["left"], self.ui["right"]), (False, True))
        self.assertEqual(self.preferences["filterRepoIds"], ["other-original"])
        self.assertTrue(self.state.exists())
        self.select_profile("test", "active-project")
        self.invoke()
        self.assertEqual((self.ui["left"], self.ui["right"]), (True, False))
        self.assertEqual(self.preferences["filterRepoIds"], ["previous-project", "another-project"])

    def test_status_and_background_refusal_do_not_change_state(self):
        self.ui["frontmost"] = False
        self.invoke("--status")
        with self.assertRaisesRegex(RuntimeError, "frontmost"):
            self.invoke()
        self.assertFalse(self.state.exists())
        self.assertEqual(self.writes + self.rpc_writes, [])

    def test_missing_project_refuses_before_any_mutation(self):
        self.select_profile("test", None)
        with self.assertRaisesRegex(RuntimeError, "Select an Orca project"):
            self.invoke()
        self.assertFalse(self.state.exists())
        self.assertEqual(self.writes + self.rpc_writes, [])

    def test_ignored_filter_is_not_reported_as_success(self):
        self.ignore_filter = True
        with self.assertRaisesRegex(RuntimeError, "Project filter change was not verified"):
            self.invoke()
        self.assertTrue(self.state.exists())
        self.assertEqual(self.writes, [])

    def test_focus_change_during_preflight_refuses_before_mutating(self):
        self.after_get = lambda: self.ui.update(frontmost=False)
        with self.assertRaisesRegex(RuntimeError, "focus or project changed"):
            self.invoke()
        self.assertEqual(self.writes + self.rpc_writes, [])

    def test_overlapping_shortcut_is_ignored(self):
        self.state.parent.mkdir(parents=True)
        with (self.state.parent / "lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.invoke()
        self.assertEqual(self.writes + self.rpc_writes, [])
        self.assertFalse(self.state.exists())

    def test_corrupt_state_refuses_without_changing_the_view(self):
        self.invoke()
        for corrupt in (None, {"profile": "test", "left": "yes", "right": False},
                        {"profile": "test", "left": True, "right": False, "filterRepoIds": "invalid"}):
            self.state.write_text(json.dumps(corrupt))
            self.writes.clear()
            self.rpc_writes.clear()
            with self.assertRaisesRegex(RuntimeError, "Invalid"):
                self.invoke()
            self.assertEqual(self.writes + self.rpc_writes, [])


class OrcaZenAccessibilityTests(unittest.TestCase):
    def test_sidebar_control_and_focus_contract(self):
        result = subprocess.run(
            ["node", str(ROOT / "tests/fixtures/orca-zen-mode/accessibility.cjs"), str(BRIDGE)],
            capture_output=True, text=True, timeout=20,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
