import contextlib
import importlib.util
import io
import json
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
        if method == "preflight.detectAgents":
            return ["claude", "codex", "pi", "omp"]
        if method == "terminal.agentStatus":
            return {"agentStatus": {"isRunningAgent": self.running}}
        if method == "terminal.inspectProcess":
            return {"process": {"foregroundProcess": self.process}}
        if method == "session.tabs.list":
            return {"activeTabId": self.pane["id"], "tabs": self.tabs}
        if method == "aiVault.listSessions":
            return {"sessions": self.sessions if params.get("unlimited") else self.sessions[:100]}
        self.fail(f"Unexpected RPC: {method}")

    def run_cli(self, *args):
        output = io.StringIO()
        with (patch.object(self.app, "orca_cli", side_effect=self.cli),
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
