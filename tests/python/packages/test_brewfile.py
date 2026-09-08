import tomllib

from tests.support.python import ROOT, RepoTestCase


class BrewfileTests(RepoTestCase):
    renderer = str(ROOT / "scripts/packages/render-brewfile")

    def brewfile(self, machine, *args):
        result = self.command([self.renderer, "--machine-type", machine, *args])
        self.assertEqual(result.stderr, b"")
        self.assertTrue(result.stdout)
        return result.stdout.decode()

    def assert_entries(self, output, *, present=(), absent=()):
        for entry in present:
            self.assertIn(entry, output)
        for entry in absent:
            self.assertNotIn(entry, output)

    def test_ci_core_excludes_desktop_development_and_overlays(self):
        output = self.brewfile("ci")
        self.assert_entries(output, present=(
            'tap "1password/tap"', 'brew "git"', 'cask "1password-cli"',
        ), absent=(
            'brew "crit"', 'cask "1password", args: { appdir: "/Applications" }',
            'brew "aria2"', 'cask "tailscale-app"',
        ))
        sections = [line.split()[0] for line in output.splitlines() if line.startswith(("tap ", "brew ", "cask "))]
        self.assertEqual(sections[0], "tap")

    def test_personal_selects_development_and_personal_apps_without_apple_or_work_groups(self):
        self.assert_entries(self.brewfile("personal"), present=(
            'brew "aria2"', 'brew "crit"', 'brew "f/mcptools/mcp", trusted: true',
            'brew "steipete/tap/imsg", trusted: true', 'brew "codex-acp"',
            'cask "arq"', 'cask "voiceink"', 'cask "google-drive"',
            'cask "setapp"', 'cask "jump-desktop"',
        ), absent=(
            'mas "', 'brew "gogcli"', 'tap "xcodesorg/made"', 'cask "codex"',
            'brew "homebrew/core/xcodes"', 'brew "fastlane"', 'brew "cirruslabs/cli/tart"',
            'facebook/fb/idb-companion', 'brew "swiftlint"',
            'cask "ghostpepper"', 'cask "tailscale-app"',
        ))

    def test_work_selects_shared_desktop_and_work_apps_without_personal_or_apple_groups(self):
        self.assert_entries(self.brewfile("work"), present=(
            'brew "aria2"', 'brew "f/mcptools/mcp", trusted: true',
            'cask "slack"', 'cask "google-drive"', 'cask "setapp"',
        ), absent=(
            'brew "homebrew/core/xcodes"', 'brew "fastlane"', 'brew "cirruslabs/cli/tart"',
            'brew "steipete/tap/imsg"', 'brew "gogcli"', 'cask "ghostpepper"',
            'cask "tailscale-app"', 'cask "arq"', 'cask "voiceink"',
            'brew "codex-acp"',
        ))

    def test_homelab_selects_apple_vm_and_agent_tools_without_desktop_subscriptions(self):
        self.assert_entries(self.brewfile("homelab"), present=(
            'brew "homebrew/core/xcodes", args: ["force-bottle"]',
            'brew "cirruslabs/cli/tart", trusted: true', 'brew "f/mcptools/mcp", trusted: true',
            'cask "tailscale-app"', 'cask "jump-desktop"', 'cask "agentsview"',
            'cask "stablyai/orca/orca"', 'brew "codex-acp"',
            'cask "claude"', 'cask "cmux"',
        ), absent=(
            'brew "steipete/tap/imsg"', 'brew "mas"', 'cask "setapp"', 'cask "codex"',
            'cask "ghostpepper"', 'cask "ghostty"', 'cask "google-drive"',
        ))

    def test_mac_app_store_requires_opt_in_and_keeps_shared_okta(self):
        self.assert_entries(self.brewfile("personal", "--include-mas"), present=(
            'mas "Things", id: 904280696', 'mas "Okta Verify", id: 490179405',
        ))
        self.assertIn('mas "Okta Verify", id: 490179405', self.brewfile("work", "--include-mas"))

    def test_apply_time_marketplace_build_tools_reach_every_machine_type(self):
        # run_onchange_after_36-agent-plugins.sh.tmpl builds the marketplace with just
        # and uv, on machines that never run mise install in this repo.
        for machine in ("ci", "personal", "homelab", "work"):
            with self.subTest(machine=machine):
                self.assert_entries(self.brewfile(machine), present=('brew "just"', 'brew "uv"'))

    def test_mise_owns_gog_while_homebrew_owns_crit(self):
        tools = tomllib.loads((ROOT / "home/dot_config/mise/conf.d/clis.toml").read_text())["tools"]
        self.assertFalse(any("tomasz-tomczyk/crit" in key for key in tools))
        self.assertEqual(tools["github:openclaw/gogcli"], {"version": "latest", "exe": "gog"})

    def test_file_output_matches_stdout_with_one_trailing_newline(self):
        output = self.work / "rendered Brewfile"
        self.command([self.renderer, "--machine-type", "ci", "--output", str(output)])
        raw = output.read_bytes()
        self.assertEqual(raw, self.brewfile("ci").encode())
        self.assertTrue(raw.endswith(b"\n"))
        self.assertFalse(raw.endswith(b"\n\n"))

    def test_unknown_machine_type_has_a_diagnostic(self):
        result = self.command([self.renderer, "--machine-type", "bogus"], expected_status=1)
        self.assertIn(b"unknown machine type", result.stderr)
