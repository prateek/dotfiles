import contextlib
import importlib.util
import io
import json
import pathlib
import sqlite3
import tempfile
import shlex
import unittest
from unittest.mock import patch

from tests.support.python import ROOT


SCRIPT = ROOT / "home/dot_config/raycast/scripts/executable_orca-agent-session.py"


class OrcaShortcutTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location("orca_shortcut", SCRIPT)
        self.app = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.app)
        self.worktree = {"worktreeId": "repo::/project", "path": "/project", "isActive": True}
        self.pane = {"type": "terminal", "handle": "focused", "terminal": "focused",
                     "id": "tab::leaf", "tabId": "tab", "parentTabId": "tab", "leafId": "leaf",
                     "active": True, "isActive": True, "title": "Agent"}
        self.tabs = [self.pane]
        self.process = "claude"
        self.running = True
        self.sessions = [self.session("claude")]
        self.calls = []
        self.rpc_calls = []
        self.terminal_host = None
        self.connected = True
        self.ssh_connected = True
        self.environment = None

    def session(self, agent, sid="source", **extra):
        return {"agent": agent, "sessionId": sid, "cwd": "/project",
                "filePath": f"/store/{sid}.jsonl", "updatedAt": "2026-09-01T00:00:00Z",
                "executionHostId": "local", **extra}

    def cli(self, *args):
        self.calls.append(args)
        if args[:2] == ("worktree", "ps"):
            return {"worktrees": [self.worktree]}
        if args[:2] == ("terminal", "list"):
            return {"visualLayouts": [{"worktreeId": self.worktree["worktreeId"], "root": {
                "type": "group", "activeTabId": "tab", "tabs": [
                    {"tabId": "tab", "activeLeafId": "leaf", "panes": self.pane}]
            }}]}
        if args[:2] == ("terminal", "split"):
            return {"terminal": {"handle": "forked"}}
        self.fail(f"Unexpected CLI call: {args}")

    def rpc(self, method, params, **kwargs):
        self.rpc_calls.append((method, params))
        if method == "preflight.detectAgents":
            return ["claude", "codex", "pi", "omp"]
        if method == "terminal.agentStatus":
            return {"agentStatus": {"isRunningAgent": self.running}}
        if method == "terminal.inspectProcess":
            return {"process": {"foregroundProcess": self.process}}
        if method == "session.tabs.list":
            return {"activeTabId": self.pane["id"], "tabs": self.tabs}
        if method == "terminal.show":
            return {"terminal": {"executionHostId": self.terminal_host or self.worktree.get("hostId", "local"),
                                 "connected": self.connected, "writable": self.connected}}
        if method == "ssh.getState":
            return {"state": {"status": "connected" if self.ssh_connected else "disconnected"}}
        if method == "aiVault.listSessions":
            return {"sessions": self.sessions if params.get("unlimited") else self.sessions[:100]}
        self.fail(f"Unexpected RPC: {method}")

    def run_cli(self, *args):
        output = io.StringIO()
        with (patch.object(self.app, "selected_environment", return_value=self.environment),
              patch.object(self.app, "orca_cli", side_effect=self.cli),
              patch.object(self.app, "rpc", side_effect=self.rpc),
              patch.object(self.app, "agentsview_base_url", return_value=None),
              patch("sys.argv", [str(SCRIPT), "--json", *args]),
              contextlib.redirect_stdout(output)):
            try:
                self.app.main()
                code = 0
            except SystemExit as error:
                code = error.code
        return code, json.loads(output.getvalue())

    def test_server_selection_reads_the_active_profile_readonly(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            (root / "orca-profile-index.json").write_text(json.dumps({"activeProfileId": "second"}))
            for profile, environment in [("first", None), ("second", "paired-server")]:
                folder = root / "profiles" / profile
                folder.mkdir(parents=True)
                with sqlite3.connect(folder / "profile-state.db") as connection:
                    connection.execute("CREATE TABLE profile_state_documents (domain TEXT, payload TEXT)")
                    connection.execute("INSERT INTO profile_state_documents VALUES (?, ?)",
                                       ("settings", json.dumps({"activeRuntimeEnvironmentId": environment})))
            with patch.object(self.app, "ORCA_USER_DATA", directory):
                self.assertEqual(self.app.selected_environment(), "paired-server")

    def test_missing_profile_database_refuses_local_fallback_without_creating_state(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            (root / "orca-profile-index.json").write_text(json.dumps({"activeProfileId": "missing"}))
            with patch.object(self.app, "ORCA_USER_DATA", directory), contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaises(SystemExit):
                    self.app.selected_environment()
            self.assertFalse((root / "profiles").exists())

    def test_fork_commands_use_native_fork_and_explicit_source(self):
        for agent, expected in [
            ("claude", ["claude", "--dangerously-skip-permissions", "--resume", "source", "--fork-session"]),
            ("codex", ["env", "CODEX_HOME=/account home", "codex", "--dangerously-bypass-approvals-and-sandbox", "fork", "source"]),
            ("pi", ["pi", "--fork", "/store/source.jsonl"]),
            ("omp", ["omp", "--fork", "/store/source.jsonl"]),
        ]:
            with self.subTest(agent=agent):
                self.process = agent
                self.sessions = [self.session(agent, codexHome="/account home" if agent == "codex" else None)]
                code, output = self.run_cli("--fork")
                self.assertEqual(code, 0, output)
                self.assertEqual(shlex.split(output["forkCommand"]), ["cd", "/project", "&&", *expected])
                self.assertEqual(output["newTerminal"], "forked")
                self.assertEqual(self.calls[-1][3], "focused")

    def test_codex_default_home_does_not_inherit_orca_account_home(self):
        self.process = "codex"
        self.sessions = [self.session("codex", codexHome=None)]
        with patch.dict("os.environ", {"CODEX_HOME": "/wrong-account"}):
            code, output = self.run_cli("--fork", "--dry-run")
        self.assertEqual(code, 0, output)
        self.assertIn("CODEX_HOME=" + str(ROOT.home() / ".codex"), shlex.split(output["forkCommand"]))
        self.assertFalse(any(call[:2] == ("terminal", "split") for call in self.calls))

    def test_pi_session_is_found_beyond_global_vault_limit(self):
        self.process = "pi"
        self.sessions = [self.session("codex", str(i), cwd="/elsewhere") for i in range(100)]
        self.sessions.append(self.session("pi"))
        code, output = self.run_cli("--fork", "--dry-run")
        self.assertEqual(code, 0, output)
        self.assertEqual(output["agent"], "pi")

    def test_reveal_and_fork_use_focused_provider_id_over_newest_session(self):
        self.process = "pi"
        self.pane["agentStatus"] = {"agentType": "pi", "providerSession": {
            "id": "source", "transcriptPath": "/store/source.jsonl"}}
        self.sessions = [self.session("pi", "other", updatedAt="2026-09-26T00:00:00Z"), self.session("pi")]
        for args in [(), ("--fork", "--dry-run")]:
            with self.subTest(args=args):
                code, output = self.run_cli(*args)
                self.assertEqual(code, 0, output)
                self.assertEqual(output["sessionId"], "source")

    def test_node_process_uses_pane_agent_identity(self):
        self.process = "node"
        self.pane["launchAgent"] = "pi"
        self.sessions = [self.session("pi")]
        code, output = self.run_cli("--fork", "--dry-run")
        self.assertEqual(code, 0, output)
        self.assertEqual(output["agent"], "pi")

    def test_unknown_agent_never_selects_another_agents_session(self):
        self.process = "zsh"
        code, output = self.run_cli("--fork")
        self.assertNotEqual(code, 0, output)
        self.assertIn("identify", output["error"])
        self.assertFalse(any(call[:2] == ("terminal", "split") for call in self.calls))

    def test_ambiguous_sessions_require_pane_identity(self):
        self.sessions.append(self.session("claude", "other"))
        code, output = self.run_cli("--fork")
        self.assertNotEqual(code, 0, output)
        self.assertIn("session", output["error"])

    def test_missing_bound_session_does_not_fall_back_to_another(self):
        self.pane["agentStatus"] = {"agentType": "claude", "providerSession": {"id": "missing"}}
        code, output = self.run_cli("--fork")
        self.assertNotEqual(code, 0, output)
        self.assertFalse(any(call[:2] == ("terminal", "split") for call in self.calls))

    def test_remote_copy_is_not_used_for_a_local_terminal(self):
        self.sessions = [self.session("claude", executionHostId="ssh:other")]
        code, output = self.run_cli("--fork")
        self.assertNotEqual(code, 0, output)

    def test_remote_bound_session_does_not_require_a_local_vault_copy(self):
        for host in ["ssh:devbox", "runtime:server"]:
            with self.subTest(host=host):
                self.worktree["hostId"] = host
                self.pane["agentStatus"] = {"agentType": "claude", "providerSession": {
                    "id": "remote-source", "transcriptPath": "/remote/source.jsonl"}}
                code, output = self.run_cli("--fork", "--dry-run")
                self.assertEqual(code, 0, output)
                self.assertEqual(output["sessionId"], "remote-source")
                self.assertEqual(output["executionHostId"], host)
                self.assertIn("remote-source", shlex.split(output["forkCommand"]))
                self.assertFalse(any(method == "aiVault.listSessions" for method, _ in self.rpc_calls))

    def test_selected_paired_server_owns_its_local_terminal_and_session(self):
        self.environment = "server"
        self.terminal_host = "local"
        self.pane["agentStatus"] = {"agentType": "claude", "providerSession": {"id": "paired-source"}}
        code, output = self.run_cli("--fork", "--dry-run")
        self.assertEqual(code, 0, output)
        self.assertEqual(output["sessionId"], "paired-source")
        self.assertEqual(output["executionHostId"], "runtime:server")
        self.assertFalse(any(method == "aiVault.listSessions" for method, _ in self.rpc_calls))

    def test_remote_cursor_binding_resolves_but_fork_is_refused(self):
        self.process = "cursor-agent"
        self.terminal_host = "ssh:devbox"
        self.pane["agentStatus"] = {"agentType": "cursor", "providerSession": {"id": "cursor-source"}}
        code, output = self.run_cli()
        self.assertEqual(code, 0, output)
        self.assertEqual((output["agent"], output["sessionId"]), ("cursor", "cursor-source"))
        code, output = self.run_cli("--fork")
        self.assertNotEqual(code, 0, output)
        self.assertIn("can't fork", output["error"])
        self.assertFalse(any(call[:2] == ("terminal", "split") for call in self.calls))

    def test_remote_codex_fork_keeps_remote_account_home_with_spaces(self):
        self.process = "codex"
        self.terminal_host = "runtime:server"
        self.pane["agentStatus"] = {"agentType": "codex", "providerSession": {
            "id": "remote", "transcriptPath": "/remote/account home/sessions/2026/10/07/rollout.jsonl"}}
        with patch.dict("os.environ", {"CODEX_HOME": "/wrong-local-account"}):
            code, output = self.run_cli("--fork", "--dry-run")
        self.assertEqual(code, 0, output)
        self.assertIn("CODEX_HOME=/remote/account home", shlex.split(output["forkCommand"]))

    def test_unbound_remote_pane_never_uses_unique_local_session(self):
        self.terminal_host = "ssh:devbox"
        code, output = self.run_cli("--fork")
        self.assertNotEqual(code, 0, output)
        self.assertIn("no local fallback", output["error"])
        self.assertFalse(any(call[:2] == ("terminal", "split") for call in self.calls))

    def test_remote_codex_without_account_evidence_refuses_to_fork(self):
        self.process = "codex"
        self.terminal_host = "ssh:devbox"
        self.pane["agentStatus"] = {"agentType": "codex", "providerSession": {"id": "remote"}}
        code, output = self.run_cli("--fork")
        self.assertNotEqual(code, 0, output)
        self.assertIn("account home", output["error"])
        self.assertFalse(any(call[:2] == ("terminal", "split") for call in self.calls))

    def test_disconnected_pane_never_forks_retained_hook_identity(self):
        self.connected = False
        code, output = self.run_cli("--fork")
        self.assertNotEqual(code, 0, output)
        self.assertIn("disconnected", output["error"])
        self.assertFalse(any(call[:2] == ("terminal", "split") for call in self.calls))

    def test_disconnected_ssh_host_overrides_retained_terminal_connected_flag(self):
        self.terminal_host = "ssh:devbox"
        self.ssh_connected = False
        self.pane["agentStatus"] = {"agentType": "claude", "providerSession": {"id": "remote"}}
        code, output = self.run_cli("--fork")
        self.assertNotEqual(code, 0, output)
        self.assertIn("disconnected", output["error"])
        self.assertFalse(any(call[:2] == ("terminal", "split") for call in self.calls))

    def test_unsupported_agent_never_resumes_as_a_second_writer(self):
        self.process = "gemini"
        self.sessions = [self.session("gemini")]
        code, output = self.run_cli("--fork")
        self.assertNotEqual(code, 0, output)
        self.assertIn("can't fork", output["error"])
        self.assertFalse(any(call[:2] == ("terminal", "split") for call in self.calls))

    def test_agent_only_does_not_require_a_persisted_session(self):
        self.sessions = []
        code, output = self.run_cli("--agent-only")
        self.assertEqual(code, 0, output)
        self.assertEqual(output, {"agent": "claude"})

    def test_agent_catalog_uses_runtime_detection_without_a_workspace(self):
        code, output = self.run_cli("--list-agents")
        self.assertEqual(code, 0, output)
        self.assertEqual(output, {"agents": ["claude", "codex", "pi", "omp"]})
        self.assertEqual(self.calls, [])

    def test_focused_shell_does_not_select_a_hidden_agent(self):
        self.running = False
        self.tabs.append(self.pane | {"id": "other::leaf", "terminal": "hidden", "isActive": False})
        code, output = self.run_cli("--fork")
        self.assertNotEqual(code, 0, output)
        self.assertIn("focused terminal", output["error"])
        self.assertFalse(any(call[:2] == ("terminal", "split") for call in self.calls))
