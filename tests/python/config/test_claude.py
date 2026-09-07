import json
import shutil

from tests.support.python import ROOT, RepoTestCase
from .plugins import package_policy


def hook_block(command, matcher=None):
    block = {"hooks": [] if command is None else [{"type": "command", "command": command}]}
    if matcher is not None:
        block["matcher"] = matcher
    return block


class ClaudeSettingsTests(RepoTestCase):
    template = "home/dot_claude/modify_private_settings.json.tmpl"
    managed_template = "home/.chezmoitemplates/claude-settings-managed.json.tmpl"
    plugin_template = "home/.chezmoitemplates/agent-claude-plugin-settings.json.tmpl"

    def setUp(self):
        super().setUp()
        self.modify = self.modifier(self.template)
        self.managed = json.loads(self.render(self.managed_template))
        self.current = {
            "permissions": {"allow": ["Bash(gh auth *)"], "deny": [], "additionalDirectories": []},
            "extraKnownMarketplaces": {
                "other-market": {"source": {"source": "github", "repo": "example/plugins"}},
                "prateek-local": {"source": {"source": "directory", "path": "/tmp/old"}},
            },
            "enabledPlugins": {"other@other-market": True, "stale@prateek-local": False},
            "hooks": {
                "UserPromptSubmit": [hook_block("printf user-owned-hook")],
                "PermissionRequest": [hook_block("printf stale-plan-hook", "ExitPlanMode"),
                                      hook_block("printf third-party-hook", "*")],
            },
            "statusLine": {"type": "command", "command": "printf status"},
            "skillListingBudgetFraction": 0.01,
        }

    def test_managed_settings_and_plugins_preserve_permissions_and_foreign_state(self):
        result = self.command(self.modify, json.dumps(self.current).encode())
        data = json.loads(result.stdout)
        self.assertNotIn("_generated", data)
        self.assertEqual(data["permissions"], self.current["permissions"])
        self.assertEqual(data["statusLine"], self.managed["statusLine"])
        self.assertEqual(data["extraKnownMarketplaces"]["other-market"], self.current["extraKnownMarketplaces"]["other-market"])
        self.assertEqual(data["extraKnownMarketplaces"]["prateek-local"]["source"],
                         {"source": "directory", "path": str(self.home / ".agents/plugins")})
        for name, enabled in package_policy("claude").items():
            with self.subTest(plugin=name):
                self.assertIs(data["enabledPlugins"][name], enabled)
        self.assertIs(data["enabledPlugins"]["stale@prateek-local"], False)
        self.assertIs(data["enabledPlugins"]["other@other-market"], True)
        self.assertEqual(data["skillListingBudgetFraction"], self.managed["skillListingBudgetFraction"])
        self.assertNotEqual(data["skillListingBudgetFraction"], 0.01)
        self.assertEqual(self.command(self.modify, result.stdout).stdout, result.stdout)

    def test_retired_matcher_disappears_while_other_matchers_and_events_survive(self):
        marker = [block for block in self.managed["hooks"]["PermissionRequest"] if block["matcher"] == "ExitPlanMode"]
        self.assertEqual(marker, [hook_block(None, "ExitPlanMode")])
        data = json.loads(self.command(self.modify, json.dumps(self.current).encode()).stdout)
        self.assertEqual(data["hooks"]["PermissionRequest"], [hook_block("printf third-party-hook", "*")])
        self.assertEqual(data["hooks"]["UserPromptSubmit"], [hook_block("printf user-owned-hook")])
        self.assertNotIn("crit plan-hook", json.dumps(data))

    def test_nested_user_marketplace_metadata_survives(self):
        current = {"extraKnownMarketplaces": {"prateek-local": {"userTag": "keep-me"}}}
        local = json.loads(self.command(self.modify, json.dumps(current).encode()).stdout)["extraKnownMarketplaces"]["prateek-local"]
        self.assertEqual(local["userTag"], "keep-me")
        self.assertEqual(local["source"]["path"], str(self.home / ".agents/plugins"))

    def test_work_override_and_policy_are_rendered(self):
        generated = json.loads(self.render(self.plugin_template))
        work = json.loads(self.render(self.managed_template, "work"))
        personal = json.loads(self.render(self.managed_template, "personal"))
        self.assertEqual(generated["enabledPlugins"], package_policy("claude"))
        self.assertIs(work["enabledPlugins"]["git-spice@chronosphere-claude-plugins"], False)
        self.assertNotIn("git-spice@chronosphere-claude-plugins", personal.get("enabledPlugins", {}))

    def synthetic_modifier(self):
        source = self.work / "synthetic-source"
        templates = source / ".chezmoitemplates"
        templates.mkdir(parents=True)
        (source / ".chezmoidata").mkdir()
        shutil.copyfile(ROOT / "home/.chezmoidata/agent_plugins.toml", source / ".chezmoidata/agent_plugins.toml")
        shutil.copyfile(ROOT / self.plugin_template, templates / "agent-claude-plugin-settings.json.tmpl")
        (templates / "claude-settings-managed.json.tmpl").write_text(json.dumps({"hooks": {
            "PermissionRequest": [hook_block("printf managed-plan-hook", "ExitPlanMode")],
            "Stop": [hook_block(None, "retired")],
        }}))
        return self.modifier(self.template, source=source)

    def test_synthetic_fragment_replaces_owned_matcher_and_retires_empty_event(self):
        modify = self.synthetic_modifier()
        data = json.loads(self.command(modify, json.dumps(self.current).encode()).stdout)
        self.assertEqual(data["hooks"]["PermissionRequest"], [hook_block("printf managed-plan-hook", "ExitPlanMode"),
                                                              hook_block("printf third-party-hook", "*")])
        self.assertNotIn("Stop", data["hooks"])
        self.assertEqual(data["hooks"]["UserPromptSubmit"], [hook_block("printf user-owned-hook")])
        current = {"hooks": {"Stop": [hook_block("printf old", "retired")]}}
        data = json.loads(self.command(modify, json.dumps(current).encode()).stdout)
        self.assertNotIn("Stop", data["hooks"])
        self.assertEqual(data["hooks"]["PermissionRequest"], [hook_block("printf managed-plan-hook", "ExitPlanMode")])

    def test_retirement_claims_foreign_blocks_under_the_owned_matcher(self):
        current = {"hooks": {"PermissionRequest": [hook_block("printf third-party-plan-hook", "ExitPlanMode"),
                                                    hook_block("printf keep", "Bash")]}}
        data = json.loads(self.command(self.modify, json.dumps(current).encode()).stdout)
        self.assertEqual(data["hooks"]["PermissionRequest"], [hook_block("printf keep", "Bash")])
