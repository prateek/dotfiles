import json
import os
import tomllib

from tests.support.python import ROOT, RepoTestCase
from .gate_examples import IGNORED, MANAGED, UNMANAGED


class PackageConfigGatesTests(RepoTestCase):
    def paths(self, machine, command, *, data=None, expected_status=0):
        override = {"machine_type": machine, "chezmoi": {"hostname": "dotfiles-test-host"}} | (data or {})
        result = self.command([
            "chezmoi", "--source", str(ROOT), "--config", str(self.config),
            "--destination", str(self.home), "--cache", str(self.work / "cache"),
            "--persistent-state", str(self.work / "state.boltdb"), "--no-tty",
            "--override-data", json.dumps(override), command,
            *(["--path-style", "relative"] if command == "managed" else []),
        ], expected_status=expected_status)
        if expected_status:
            return result
        self.assertEqual(result.stderr, b"")
        return set(result.stdout.decode().splitlines())

    def test_named_machine_types_manage_and_ignore_their_declared_application_paths(self):
        for machine in ("personal", "ci", "work", "homelab"):
            with self.subTest(machine=machine):
                managed = self.paths(machine, "managed")
                for path in MANAGED.get(machine, ()):
                    self.assertIn(path, managed)
                for path in UNMANAGED[machine]:
                    self.assertNotIn(path, managed)
                if machine in IGNORED:
                    ignored = self.paths(machine, "ignored")
                    for path in IGNORED[machine]:
                        self.assertIn(path, ignored)

    def test_empty_groups_ignore_every_named_optional_configuration(self):
        ignored = self.paths("ci", "ignored", data={"machines": {"type": {"ci": {"groups": []}}}})
        for path in IGNORED["empty"]:
            self.assertIn(path, ignored)

    def test_unknown_machine_type_fails_gate_evaluation(self):
        result = self.paths("bogus", "ignored", expected_status=1)
        self.assertIn(b"unknown machine type", result.stderr)

    def test_tuna_combo_layout_apps_winmux_misc_and_leader_hotkey(self):
        config = tomllib.loads((ROOT / "home/dot_config/tuna/config.toml").read_text())
        binds = {binding["key"]: binding for binding in config["comboMode"]["bindings"]}
        self.assertEqual(set(binds), {"a", "w", "z"})
        self.assertEqual(binds["a"]["label"], "apps")
        apps = {child["key"]: child["destination"]["command"] for child in binds["a"]["destination"]["bindings"]}
        self.assertEqual(set(apps), {"1", "t", "s", "b", "c", "m", "f"})
        for app in apps.values():
            self.assertEqual(app["actionIdentifier"], "tuna.common-actions/open")
            self.assertRegex(app["subjectIdentifiers"][0], r"^path:/.+\.app$")
        self.assertEqual(binds["w"]["label"], "winmux")
        winmux = {child["key"]: child["destination"]["command"] for child in binds["w"]["destination"]["bindings"]}
        self.assertEqual(
            {key: cmd["subjectIdentifiers"][0].split("; winmux ", 1)[1] for key, cmd in winmux.items()},
            {"h": "move left", "l": "move right", "c": "column-count off", "3": "column-count 3", "s": "open-sidebar"},
        )
        for cmd in winmux.values():
            self.assertEqual(cmd["actionIdentifier"], "tuna.common-actions/run-text-as-shell-command")
            self.assertTrue(cmd["subjectIdentifiers"][0].startswith('text:PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"; winmux '))
        self.assertEqual(binds["z"]["label"], "misc")
        self.assertLessEqual({"d", "m", "z", "t", "r", "g"},
                             {child["key"] for child in binds["z"]["destination"]["bindings"]})
        self.assertEqual(config["hotkeys"]["app"]["comboMode"], {"carbonKeyCode": 79, "carbonModifiers": 0})

    def test_claude_queue_draft_script_symlink_chord_pin_and_command(self):
        self.assertTrue(os.access(ROOT / "bin/claude-queue-draft", os.X_OK))
        self.assertTrue((ROOT / "home/bin/symlink_claude-queue-draft.tmpl").is_file())
        keys = json.loads((ROOT / "home/dot_claude/keybindings.json").read_text())
        chat = next(binding for binding in keys["bindings"] if binding["context"] == "Chat")
        self.assertEqual(chat["bindings"]["ctrl+x enter"], "chat:queueSubmit")
        self.assertTrue((ROOT / "home/dot_claude/commands/q.md").is_file())

    def test_mcporter_granola_oauth_endpoint_and_mise_install_declaration(self):
        config = json.loads((ROOT / "home/dot_config/mcporter/mcporter.json").read_text())
        self.assertEqual(config["mcpServers"]["granola"], {
            "description": "Official Granola meeting notes MCP",
            "baseUrl": "https://mcp.granola.ai/mcp", "auth": "oauth",
        })
        tools = tomllib.loads((ROOT / "home/dot_config/mise/conf.d/mcporter.toml").read_text())
        self.assertEqual(tools, {"tools": {"npm:mcporter": "latest"}})
