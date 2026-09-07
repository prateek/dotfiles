import json
import tomllib

from tests.support.python import ROOT, RepoTestCase


class SetappAppListTests(RepoTestCase):
    renderer = str(ROOT / "scripts/packages/render-setapp-applist")
    desktop_apps = ["CleanShot X", "iStat Menus", "Maestri", "Soulver", "Yoink"]

    def applist(self, machine, *args, expected_status=0):
        result = self.command(
            [self.renderer, "--machine-type", machine, *args], expected_status=expected_status,
        )
        if expected_status == 0:
            self.assertEqual(result.stderr, b"")
        return result

    def names(self, machine):
        return self.applist(machine).stdout.decode().splitlines()

    def test_desktop_machine_types_select_the_subscription_apps(self):
        for machine in ("personal", "work"):
            with self.subTest(machine=machine):
                self.assertEqual(self.names(machine), self.desktop_apps)

    def test_machine_types_without_the_setapp_cask_render_nothing(self):
        for machine in ("ci", "homelab"):
            with self.subTest(machine=machine):
                self.assertEqual(self.applist(machine).stdout, b"")

    def test_every_declared_app_has_an_install_path(self):
        packages = tomllib.loads((ROOT / "home/.chezmoidata/packages.toml").read_text())
        for name, group in packages["packages"]["groups"].items():
            if not group.get("setapp_apps"):
                continue
            with self.subTest(group=name):
                # setapp-cli drives the Setapp desktop client, so a group that
                # names Setapp apps has no install path without the cask.
                self.assertIn("setapp", [cask["name"] for cask in group.get("casks", [])])

    def test_a_group_naming_setapp_apps_without_the_cask_fails_the_render(self):
        # A host-local machines_local override can select groups no static
        # check sees, so the template refuses a selection with no install path.
        override = {
            "machine_type": "personal",
            "machines_local": {"groups": ["setapp-orphan"]},
            "packages": {"groups": {"setapp-orphan": {"setapp_apps": [{"name": "Yoink"}]}}},
        }
        result = self.command([
            "chezmoi", "--source", str(ROOT / "home"), "--config", str(self.config),
            "--destination", str(self.home), "--no-tty",
            "--override-data", json.dumps(override),
            "execute-template", "--file", str(ROOT / "home/.chezmoitemplates/setapp-applist.tmpl"),
        ], expected_status=1)
        self.assertIn(b'the "setapp" cask is not in the selected groups', result.stderr)

    def test_file_output_matches_stdout_with_one_trailing_newline(self):
        output = self.work / "rendered AppList"
        self.applist("personal", "--output", str(output))
        raw = output.read_bytes()
        self.assertEqual(raw, self.applist("personal").stdout)
        self.assertTrue(raw.endswith(b"\n"))
        self.assertFalse(raw.endswith(b"\n\n"))

    def test_unknown_machine_type_has_a_diagnostic(self):
        result = self.applist("bogus", expected_status=1)
        self.assertIn(b"unknown machine type", result.stderr)
