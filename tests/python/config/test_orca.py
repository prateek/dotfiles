import json

from tests.support.python import RepoTestCase


class OrcaConfigTests(RepoTestCase):
    template = "home/Library/Application Support/private_orca/modify_orca-data.json.tmpl"

    def test_work_overlay_and_base_preserve_application_state(self):
        modify = self.modifier(self.template, "work")
        current = {
            "schemaVersion": 1,
            "repos": [{"id": "abc", "path": "/code/repo", "displayName": "repo"}],
            "worktreeMeta": {"abc::/tmp/wt": {"comment": "keep me — ✳ café"}},
            "settings": {"theme": "system", "terminalFontFamily": "SF Mono", "disabledTuiAgents": [],
                         "terminalShortcutPolicy": "orca-first", "userOnlyPreference": "untouched"},
            "workspaceSession": {"activeRepoId": "abc"},
        }
        result = self.command(modify, json.dumps(current).encode())
        merged = json.loads(result.stdout)
        self.assertEqual({key: value for key, value in merged.items() if key != "settings"},
                         {key: value for key, value in current.items() if key != "settings"})
        expected = {
            "theme": "dark", "terminalFontFamily": "JetBrains Mono", "terminalShortcutPolicy": "terminal-first",
            "setupScriptLaunchMode": "split-horizontal", "terminalScrollbackBytes": 25000000,
            "defaultTuiAgent": "claude", "workspaceDir": str(self.home / "code/worktrees"),
            "disabledTuiAgents": ["codex"], "userOnlyPreference": "untouched",
        }
        settings = merged["settings"]
        for key, value in expected.items():
            with self.subTest(setting=key):
                self.assertEqual(settings[key], value)
        self.assertEqual({app["command"] for app in settings["openInApplications"]}, {"cursor", "code"})
        self.assertEqual([entry["label"] for entry in settings["terminalQuickCommands"]],
                         ["Open in Finder", "Open in Cursor", "Open in VS Code"])
        self.assertIn("keep me — ✳ café".encode(), result.stdout)
        self.assertEqual(self.command(modify, result.stdout).stdout, result.stdout)

    def test_missing_settings_recovers_without_replacing_repo_list(self):
        result = self.command(self.modifier(self.template, "work"), b'{"schemaVersion":1,"repos":[]}')
        merged = json.loads(result.stdout)
        self.assertEqual(merged["repos"], [])
        self.assertEqual(merged["settings"]["theme"], "dark")
        self.assertEqual(merged["settings"]["disabledTuiAgents"], ["codex"])

    def test_homelab_overlay_and_no_overlay_profile(self):
        for machine_type, disabled in (("homelab", ["claude-agent-teams"]), ("ci", None)):
            with self.subTest(machine_type=machine_type):
                result = self.command(self.modifier(self.template, machine_type), b'{"schemaVersion":1,"repos":[]}')
                settings = json.loads(result.stdout)["settings"]
                self.assertEqual(settings["defaultTuiAgent"], "codex")
                self.assertEqual(settings["theme"], "dark")
                self.assertEqual(settings["terminalShortcutPolicy"], "terminal-first")
                if disabled is None:
                    self.assertNotIn("disabledTuiAgents", settings)
                else:
                    self.assertEqual(settings["disabledTuiAgents"], disabled)
