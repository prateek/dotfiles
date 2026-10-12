import json
import os
import shlex
import sys

from tests.support.python import ROOT, RepoTestCase
from .test_packages import write_overlay_marketplace


class UpstreamPluginTests(RepoTestCase):
    def setUp(self):
        super().setUp()
        self.catalog = write_overlay_marketplace(self.work / "upstream", {
            "on": ("claude", "codex"), "off": ("claude", "codex"),
        }, name="official", version="2.0.0")
        self.policy = self.work / "policy.toml"
        self.policy.write_text("\n".join(
            f'[[agent_upstream_plugins]]\nmarketplace = "official"\nplugin = "{name}"\n'
            'repository = "example/upstream"\nref = "main"\nclaude = true\ncodex = true\n'
            f'default_loaded = {str(loaded).lower()}\n' for name, loaded in (("on", True), ("off", False))
        ))
        self.state = self.work / "state.json"
        self.log = self.work / "commands.log"
        self.state.write_text(json.dumps({
            "marketplaces": {}, "codex_marketplaces": {},
            "upstream_sources": {"https://github.com/example/upstream.git": str(self.catalog)},
            "claude": {"other@foreign": {"version": "1.0.0", "enabled": True}},
            "codex": {"other@foreign": {"version": "1.0.0", "enabled": False}},
        }))
        self.env.update(FAKE_PLUGIN_STATE=str(self.state), FAKE_PLUGIN_LOG=str(self.log))
        self.env["CODEX_HOME"] = str(self.home / ".codex")
        executables = self.work / "bin"
        executables.mkdir()
        self.env["PATH"] = str(executables) + os.pathsep + self.env["PATH"]
        for cli in ("claude", "codex", "omp"):
            script = executables / cli
            script.write_text(f'#!/bin/sh\nFAKE_PLUGIN_CLI={cli} exec {shlex.quote(sys.executable)} '
                              f'{shlex.quote(str(ROOT / "tests/scenarios/agents/fake-plugin-cli.py"))} "$@"\n')
            script.chmod(0o700)

    def reconcile(self, *args, **kwargs):
        script = ROOT / ".agents/skills/agent-skill-management/scripts/reconcile-upstream-agent-plugins"
        return self.command([sys.executable, str(script), "--policy", str(self.policy),
                             "--apply", "--agent", "claude", "--agent", "codex", *args], **kwargs)

    def test_installs_official_plugins_preserving_defaults_and_foreign_state(self):
        self.reconcile()
        state = json.loads(self.state.read_text())
        for agent in ("claude", "codex"):
            self.assertEqual(state[agent]["on@official"], {"version": "2.0.0", "enabled": True})
            self.assertEqual(state[agent]["off@official"], {"version": "2.0.0", "enabled": False})
        self.assertEqual(state["claude"]["other@foreign"], {"version": "1.0.0", "enabled": True})
        self.assertEqual(state["codex"]["other@foreign"], {"version": "1.0.0", "enabled": False})
        self.log.write_text("")
        self.reconcile()
        self.assertEqual(json.loads(self.state.read_text()), state)
        self.assertTrue(all(" list " in line for line in self.log.read_text().splitlines()))
        self.reconcile("--update")
        self.assertFalse(json.loads(self.state.read_text())["codex"]["off@official"]["enabled"])
        self.assertFalse(json.loads(self.state.read_text())["claude"]["off@official"]["enabled"])

    def test_failed_disabled_refresh_restores_disabled_state(self):
        self.reconcile()
        self.env["FAKE_PLUGIN_FAIL"] = "off@official"
        self.env["FAKE_PLUGIN_FAIL_CLI"] = "codex"
        self.env["FAKE_PLUGIN_ENABLE_BEFORE_FAILURE"] = "1"
        result = self.reconcile("--update", expected_status=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"simulated install failure", result.stderr)
        state = json.loads(self.state.read_text())
        self.assertFalse(state["codex"]["off@official"]["enabled"])

    def test_dry_run_and_invalid_policy_cannot_mutate_native_state(self):
        before = self.state.read_bytes()
        self.reconcile("--dry-run")
        self.assertEqual(self.state.read_bytes(), before)
        self.log.unlink()
        self.policy.write_text(self.policy.read_text().replace('marketplace = "official"', 'marketplace = "prateek-local"'))
        result = self.reconcile(expected_status=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"cannot own prateek-local", result.stderr)
        self.assertFalse(self.log.exists())

    def test_marketplace_name_collision_is_rejected_before_mutation(self):
        state = json.loads(self.state.read_text())
        state["marketplaces"]["official"] = str(self.catalog)
        state["claude_marketplace_sources"] = {"official": "https://github.com/other/foreign.git"}
        self.state.write_text(json.dumps(state))
        before = self.state.read_bytes()
        result = self.reconcile(expected_status=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"source conflict", result.stderr)
        self.assertEqual(self.state.read_bytes(), before)
        self.assertTrue(all(" list " in line for line in self.log.read_text().splitlines()))

    def test_existing_codex_ref_conflict_is_rejected(self):
        self.reconcile()
        config = self.home / ".codex/config.toml"
        config.parent.mkdir(exist_ok=True)
        config.write_text('[marketplaces.official]\nsource_type = "git"\n'
                          'source = "https://github.com/example/upstream.git"\nref = "other-branch"\n')
        before = self.state.read_bytes()
        self.log.write_text("")
        result = self.reconcile(expected_status=1)
        self.assertIn(b"ref conflict", result.stderr)
        self.assertEqual(self.state.read_bytes(), before)
        self.assertTrue(all(" list " in line for line in self.log.read_text().splitlines()))

    def seed_omp_wrappers(self):
        old = write_overlay_marketplace(self.work / "old", {"on": ("claude",), "off": ("claude",)},
                                        name="prateek-local", version="1.0.0")
        state = json.loads(self.state.read_text())
        state["marketplaces"]["prateek-local"] = str(old)
        state["omp"] = {"on@prateek-local": {"version": "1.0.0", "enabled": False},
                        "off@prateek-local": {"version": "1.0.0", "enabled": False}}
        self.state.write_text(json.dumps(state))
        registry = self.home / ".omp/marketplaces.json"
        registry.parent.mkdir()
        registry.write_text(json.dumps({"marketplaces": [{"name": "prateek-local", "sourceUri": str(old)}]}))

    def test_omp_replaces_conflicting_wrappers_and_preserves_defaults(self):
        self.seed_omp_wrappers()
        self.reconcile("--agent", "omp")
        state = json.loads(self.state.read_text())["omp"]
        self.assertEqual(state, {"on@official": {"version": "2.0.0", "enabled": True},
                                 "off@official": {"version": "2.0.0", "enabled": False}})

    def test_omp_failed_replacement_restores_old_version_and_disabled_state(self):
        self.seed_omp_wrappers()
        self.env["FAKE_PLUGIN_FAIL"] = "on@official"
        self.env["FAKE_PLUGIN_FAIL_CLI"] = "omp"
        self.reconcile("--agent", "omp", expected_status=1)
        state = json.loads(self.state.read_text())["omp"]
        self.assertEqual(state["on@prateek-local"], {"version": "1.0.0", "enabled": False})
        self.assertNotIn("on@official", state)

    def test_codex_declared_marketplace_with_missing_snapshot_bootstraps(self):
        config = self.home / ".codex/config.toml"
        config.parent.mkdir()
        config.write_text('[marketplaces.official]\nsource_type = "git"\n'
                          'source = "https://github.com/example/upstream.git"\nref = "main"\n')
        self.reconcile()
        self.assertTrue((self.home / ".codex/.tmp/marketplaces/official/.agents/plugins/marketplace.json").is_file())
        state = json.loads(self.state.read_text())
        self.assertEqual(state["codex"]["on@official"], {"version": "2.0.0", "enabled": True})
        self.log.write_text("")
        self.reconcile()
        self.assertTrue(all(" list " in line for line in self.log.read_text().splitlines()))
