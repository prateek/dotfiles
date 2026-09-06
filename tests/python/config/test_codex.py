import tomllib

from tests.support.python import RepoTestCase
from .plugins import package_policy


class CodexConfigTests(RepoTestCase):
    def setUp(self):
        super().setUp()
        self.modify = self.modifier("home/dot_codex/modify_private_config.toml.tmpl")

    def test_defaults_and_plugin_policy_preserve_trust_approvals_and_foreign_state(self):
        raw = b'''
model = "old-model"
model_reasoning_effort = "max"
service_tier = "fast"
custom_top_level = "keep"
[agents]
max_threads = 1
max_depth = 1
[tui]
status_line = ["old"]
status_line_use_colors = false
[tui.keymap.pager]
page_down = "old"
close = "old"
[projects."/tmp/live-project"]
trust_level = "trusted"
[marketplaces.last30days-skill]
last_updated = "live"
last_revision = "live-revision"
source_type = "git"
source = "https://example.invalid/skill.git"
[marketplaces.prateek-local]
last_updated = "old"
source_type = "git"
source = "https://example.invalid/old.git"
[plugins."stale@prateek-local"]
enabled = false
[plugins."other@other-market"]
enabled = false
[hooks.state."/Users/prateek/.codex/hooks.json:pre_tool_use:0:0"]
enabled = false
trusted_hash = "sha256:live"
'''
        result = self.command(self.modify, raw)
        data = tomllib.loads(result.stdout.decode())
        current = tomllib.loads(raw.decode())
        for key, expected in {"model": "gpt-6-astra", "model_reasoning_effort": "xhigh",
                              "service_tier": "default", "custom_top_level": "keep"}.items():
            self.assertEqual(data[key], expected)
        self.assertEqual((data["agents"]["max_threads"], data["agents"]["max_depth"]), (16, 3))
        self.assertEqual(data["tui"]["status_line"],
                         ["model-with-reasoning", "context-used", "context-window-size", "five-hour-limit", "weekly-limit"])
        self.assertIs(data["tui"]["status_line_use_colors"], True)
        self.assertEqual(data["tui"]["keymap"]["pager"], {
            "scroll_up": ["up", "k"], "scroll_down": ["down", "j"], "page_up": ["page-up", "shift-space", "ctrl-b"],
            "page_down": ["page-down", "space", "ctrl-f"], "half_page_up": "ctrl-u", "half_page_down": "ctrl-d",
            "jump_top": "home", "jump_bottom": "end", "close": ["q", "ctrl-c"], "close_transcript": "ctrl-t",
        })
        self.assertEqual(data["projects"], current["projects"])
        self.assertEqual(data["hooks"], current["hooks"])
        self.assertEqual(data["marketplaces"]["last30days-skill"], current["marketplaces"]["last30days-skill"])
        self.assertEqual(data["marketplaces"]["prateek-local"]["source_type"], "local")
        self.assertEqual(data["marketplaces"]["prateek-local"]["source"], str(self.home / ".agents/plugins"))
        for name, enabled in package_policy("codex").items():
            with self.subTest(plugin=name):
                self.assertIs(data["plugins"][name]["enabled"], enabled)
        self.assertIs(data["plugins"]["stale@prateek-local"]["enabled"], False)
        self.assertIs(data["plugins"]["other@other-market"]["enabled"], False)
        self.assertEqual(self.command(self.modify, result.stdout).stdout, result.stdout)

    def test_unmanaged_comments_survive_toml_round_trip(self):
        raw = b'''# user-authored top-of-file comment
custom_top_level = "keep"  # inline comment
[unrelated]
# explanatory comment for the unrelated section
note = "preserve"
'''
        result = self.command(self.modify, raw)
        for comment in (b"# user-authored top-of-file comment", b"# inline comment",
                        b"# explanatory comment for the unrelated section"):
            self.assertIn(comment, result.stdout)
        self.assertEqual(tomllib.loads(result.stdout.decode())["unrelated"], {"note": "preserve"})

    def test_nested_marketplace_sibling_survives(self):
        result = self.command(self.modify, b'[marketplaces.prateek-local]\nuser_tag = "keep-me"\n')
        local = tomllib.loads(result.stdout.decode())["marketplaces"]["prateek-local"]
        self.assertEqual(local["user_tag"], "keep-me")
        self.assertEqual(local["source_type"], "local")
        self.assertEqual(local["source"], str(self.home / ".agents/plugins"))

    def test_empty_file_seeds_marketplace_and_package_defaults(self):
        result = self.command(self.modify)
        data = tomllib.loads(result.stdout.decode())
        self.assertEqual(data["marketplaces"]["prateek-local"]["source_type"], "local")
        for name, enabled in package_policy("codex").items():
            with self.subTest(plugin=name):
                self.assertIs(data["plugins"][name]["enabled"], enabled)
