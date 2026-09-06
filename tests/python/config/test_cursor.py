import json

from tests.support.python import RepoTestCase


class CursorConfigTests(RepoTestCase):
    def setUp(self):
        super().setUp()
        self.modify = self.modifier("home/dot_cursor/modify_private_cli-config.json.tmpl", "work")
        self.marketplace = {"source": "directory", "path": str(self.home / ".agents/plugins")}

    def test_registration_preserves_auth_model_permissions_and_other_marketplaces(self):
        current = {
            "authInfo": {"token": "secret-abc"},
            "model": {"modelId": "user-choice"},
            "permissions": {"allow": ["Read"]},
            "marketplaces": {"other": {"source": "github", "path": "x"}},
        }
        result = self.command(self.modify, json.dumps(current).encode())
        expected = current | {"marketplaces": current["marketplaces"] | {"prateek-local": self.marketplace}}
        self.assertEqual(json.loads(result.stdout), expected)
        self.assertEqual(result.stderr, b"")
        self.assertEqual(self.command(self.modify, result.stdout).stdout, result.stdout)

    def test_existing_registration_preserves_cursor_formatting(self):
        raw = json.dumps({"marketplaces": {"prateek-local": self.marketplace}}, separators=(",", ":")).encode()
        self.assertEqual(self.command(self.modify, raw).stdout, raw)

    def test_empty_config_is_rebuilt_without_app_owned_state(self):
        result = self.command(self.modify)
        self.assertEqual(json.loads(result.stdout), {"marketplaces": {"prateek-local": self.marketplace}})

    def test_config_is_managed_only_when_cursor_cli_is_selected(self):
        for machine_type, data, ignored in (
            ("personal", {}, True),
            ("work", {}, False),
            ("work", {"machines_local": {"agent_clis": ["claude"]}}, True),
        ):
            with self.subTest(machine_type=machine_type, data=data):
                lines = self.render("home/.chezmoiignore", machine_type, data=data).decode().splitlines()
                self.assertEqual(".cursor/cli-config.json" in lines, ignored)
