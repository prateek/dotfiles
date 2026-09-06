import json
import os
import shlex
import shutil
import sys
import tomllib

from tests.support.python import ROOT, RepoTestCase

SCRIPTS = ROOT / ".agents/skills/agent-skill-management/scripts"


class PackageTestCase(RepoTestCase):
    def setUp(self):
        super().setUp()
        self.packages = self.work / "packages"
        self.packages.mkdir()
        self.plugins = self.work / ".agents/plugins"
        self.bin = self.work / "bin"
        self.bin.mkdir()
        self.env["PATH"] = str(self.bin) + os.pathsep + self.env["PATH"]
        self.env["AGENT_SKILL_PACKAGES_ROOT"] = str(self.packages)

    def tool(self, name, *args, **kwargs):
        return self.command([sys.executable, str(SCRIPTS / name), *map(str, args)], **kwargs)

    def skill(self, package, name, *, kind="local", dependency=None, description="Fixture skill."):
        path = package / "skills" / kind / name
        path.mkdir(parents=True)
        (path / "SKILL.md").write_text(f"---\nname: {name}\ndescription: {description}\n---\n\n# {name}\n")
        if dependency:
            (path / "SOURCE.md").write_text(
                "# Source\n\n"
                f"- Upstream: https://github.com/{dependency}\n"
                f"- APM dependency: `{dependency}`\n- Ref: `old`\n- License: MIT.\n"
            )
        return path

    def package(self, name="sample", *, loaded=None, codex="none", claude="none", dependencies=()):
        path = self.packages / name
        path.mkdir()
        policy = "" if loaded is None else f"default_loaded = {str(loaded).lower()}\n"
        (path / "package.toml").write_text(
            f'display_name = "{name.title()}"\n{policy}\n[render]\ncodex = "{codex}"\nclaude = "{claude}"\n'
        )
        deps = "apm:\n" + "".join(f"    - {dep}\n" for dep in dependencies) if dependencies else "apm: []\n"
        (path / "apm.yml").write_text(f"name: {name}\nversion: 1.0.0\ntargets:\n  - agent-skills\ndependencies:\n  {deps}")
        if dependencies:
            (path / "apm.lock.yaml").write_text("lockfile_version: '1'\ndependencies: []\n")
        self.skill(path, f"{name}-skill")
        return path


class PackageValidationTests(PackageTestCase):
    def test_committed_layout_provenance_and_inventory_are_valid(self):
        actual = ROOT / "home/dot_agents/packages"
        result = self.tool("validate-agent-packages", env={"AGENT_SKILL_PACKAGES_ROOT": str(actual)})
        self.assertEqual(result.stdout, b"OK validate-agent-packages\n")
        self.assertEqual(result.stderr, b"")
        for path in ("home/dot_agents/skills", "home/dot_claude/skills", "home/dot_agents/plugins"):
            self.assertFalse((ROOT / path).exists(), path)
        for path in ("core/skills/vendor/deep-research/SOURCE.md", "review/skills/vendor/crit/SOURCE.md", "experimental/skills/vendor/cli-creator/SOURCE.md"):
            self.assertTrue((actual / path).is_file(), path)
        for path in ("core/skills/local/deep-research", "ios/skills/vendor/swift-patterns/swift-patterns/SKILL.md", "ios/skills/vendor/swiftui-expert/swiftui-expert-skill/SKILL.md"):
            self.assertFalse((actual / path).exists(), path)
        result = self.tool("inventory-agent-skills", env={"AGENT_SKILL_PACKAGES_ROOT": str(actual)})
        inventory = json.loads(result.stdout)["packages"]
        self.assertTrue(inventory)
        for package in inventory:
            self.assertIs(type(package["default_loaded"]), bool, package)
            self.assertIsInstance(package["payloads"], list, package)
        self.assertEqual((ROOT / "home/dot_codex/symlink_skills").read_text().strip(), "../.agents/skills")

    def test_validator_rejects_non_sha_dependency_refs(self):
        package = self.package(dependencies=["example/repo/skills/invalid#main"])
        (package / "apm.lock.yaml").write_text("lockfile_version: '1'\ndependencies: []\n")
        result = self.tool("validate-agent-packages", expected_status=1)
        self.assertIn(b"dependency ref pins must be full commit SHAs", result.stderr)

    def test_validator_rejects_overlong_descriptions(self):
        package = self.package()
        (package / "skills/local/sample-skill/SKILL.md").write_text(
            "---\nname: sample-skill\ndescription: >-\n  " + "x" * 1100 + "\n---\n# Fixture\n"
        )
        result = self.tool("validate-agent-packages", expected_status=1)
        self.assertIn(b"description exceeds 1024 chars", result.stderr)

    def test_validator_refuses_a_filename_chezmoi_would_execute(self):
        package = self.package()
        (package / "skills/local/sample-skill/run_manifest.json").write_text("{}")
        result = self.tool("validate-agent-packages", expected_status=1)
        self.assertIn(b"rename with a literal_ prefix", result.stderr)

    def test_validator_requires_hooks_manifest(self):
        package = self.package()
        (package / "hooks").mkdir()
        (package / "hooks/session-start").touch()
        result = self.tool("validate-agent-packages", expected_status=1)
        self.assertIn(b"hooks payload is missing hooks.json", result.stderr)

    def test_source_audit_accepts_skills_and_hooks_but_refuses_unsupported_components(self):
        result = self.tool("audit-apm-source-surface", ROOT / "home/dot_agents/packages/core/skills/local/code-gardening")
        self.assertEqual(result.stderr, b"")
        audit = self.work / "audit"
        (audit / "example/plugin/.apm/hooks").mkdir(parents=True)
        (audit / "example/plugin/hooks").mkdir()
        self.tool("audit-apm-source-surface", audit)
        (audit / "prompts").mkdir()
        result = self.tool("audit-apm-source-surface", audit, expected_status=1)
        self.assertIn(b"unsupported APM component", result.stderr)


class PackageVendorTests(PackageTestCase):
    def setUp(self):
        super().setUp()
        shutil.copyfile(ROOT / "tests/scenarios/agents/fake-apm.zsh", self.bin / "apm")
        (self.bin / "apm").chmod(0o700)
        self.sample = self.package(dependencies=["Example/Repo/skills/fake-skill"])
        curated = self.skill(self.sample, "curated-fake", kind="vendor", dependency="Example/Repo/skills/fake-skill")
        (curated / "SKILL.md").write_text("---\nname: fake-skill\ndescription: Existing curated skill.\n---\n# Curated skill\n")
        with (curated / "SOURCE.md").open("a") as source:
            source.write("- Notes: Vendored source is kept under the local skill id `curated-fake`.\n")
        self.skill(self.sample, "stale-skill", kind="vendor", dependency="example/old/skills/stale-skill")

    def vendor(self, name="sample", **kwargs):
        return self.tool("vendor-agent-package", name, "--packages-root", self.packages, **kwargs)

    def assert_manifest_exception(self, result):
        self.assertEqual(result.stderr, b"vendor-agent-package: ignoring apm audit config-consistency manifest false positive\n")
        self.assertIn(b'"name": "config-consistency", "passed": false', result.stdout)

    def test_vendor_preserves_curated_ids_and_provenance_and_removes_stale_skills(self):
        result = self.vendor()
        self.assert_manifest_exception(result)
        vendor = self.sample / "skills/vendor"
        for path in ("curated-fake/SKILL.md", "curated-fake/agents/openai.yaml", "plugin-skill/SKILL.md", "second-skill/SKILL.md"):
            self.assertTrue((vendor / path).is_file(), path)
        self.assertFalse((vendor / "fake-skill").exists())
        self.assertFalse((vendor / "stale-skill").exists())
        source = (vendor / "curated-fake/SOURCE.md").read_text()
        for literal in ("Ref: `abc123`", "APM dependency: `Example/Repo/skills/fake-skill`", "Upstream: https://github.com/Example/Repo/tree/abc123/skills/fake-skill", "local skill id `curated-fake`"):
            self.assertIn(literal, source)
        hooks = self.sample / "hooks"
        self.assertTrue((hooks / "hooks.json").is_file())
        self.assertTrue(os.access(hooks / "session-start", os.X_OK))
        self.assertIn("APM dependency: `Example/Plugin`", (hooks / "SOURCE.md").read_text())
        self.assertIn("Ref: `def456`", (hooks / "SOURCE.md").read_text())
        self.assertTrue((self.sample / "apm.lock.yaml").is_file())

    def test_vendor_refuses_hand_authored_hooks_before_replacing_skills(self):
        hooks = self.sample / "hooks"
        hooks.mkdir()
        (hooks / "hooks.json").write_text('{"hooks": {}}\n')
        result = self.vendor(expected_status=1)
        self.assertIn(b"not APM-vendored", result.stderr)
        self.assertEqual((hooks / "hooks.json").read_text(), '{"hooks": {}}\n')
        self.assertTrue((self.sample / "skills/vendor/stale-skill/SKILL.md").is_file())
        self.assertFalse((self.sample / "skills/vendor/second-skill").exists())

    def test_vendor_rejects_audit_findings_outside_the_manifest_exception(self):
        result = self.vendor(expected_status=1, env={"FAKE_APM_AUDIT_FAIL": "other"})
        self.assertIn(b"hidden-unicode", result.stdout)
        self.assertNotIn(b"ignoring apm audit", result.stderr)

    def test_vendor_refuses_multiple_dependencies_with_hooks(self):
        result = self.vendor(expected_status=1, env={"FAKE_APM_HOOKS": "conflict"})
        self.assertIn(b"multiple dependencies ship hooks/", result.stderr)

    def test_removing_all_dependencies_removes_vendor_state_but_preserves_local_skills(self):
        empty = self.package("empty")
        old = self.skill(empty, "old-skill", kind="vendor", dependency="example/old")
        (empty / "apm.lock.yaml").write_text("lockfile_version: '1'\ndependencies: []\n")
        (empty / "hooks").mkdir()
        (empty / "hooks/hooks.json").write_text('{"hooks": {}}')
        shutil.copyfile(old / "SOURCE.md", empty / "hooks/SOURCE.md")
        result = self.vendor("empty")
        self.assert_manifest_exception(result)
        for path in ("skills/vendor/old-skill", "hooks", "apm.lock.yaml"):
            self.assertFalse((empty / path).exists(), path)
        self.assertTrue((empty / "skills/local/empty-skill/SKILL.md").is_file())


class PackageRenderTests(PackageTestCase):
    def render_plugins(self, *extra, **kwargs):
        return self.tool("render-agent-plugin-marketplace", "--plugins-root", self.plugins, *extra, **kwargs)

    def test_real_marketplace_paths_context_and_loading_templates_match_source_policy(self):
        actual = ROOT / "home/dot_agents/packages"
        self.env["AGENT_SKILL_PACKAGES_ROOT"] = str(actual)
        for options in (["--skip-config-templates"], ["--check"]):
            result = self.render_plugins(*options)
            self.assertEqual(set(result.stderr.decode().splitlines()), {
                "warning: review: codex has no mapping for evals; that payload is claude-only",
                "warning: review: codex has no mapping for hooks; that payload is claude-only",
                "warning: superpowers: codex has no mapping for hooks; that payload is claude-only",
            })
        codex = json.loads((self.plugins / "marketplace.json").read_text())
        self.assertTrue(codex["plugins"])
        for plugin in codex["plugins"]:
            self.assertEqual(plugin["source"], {"source": "local", "path": f'./.agents/plugins/plugins/{plugin["name"]}'})
        claude = json.loads((self.plugins / ".claude-plugin/marketplace.json").read_text())
        self.assertTrue(claude["plugins"])
        for plugin in claude["plugins"]:
            self.assertEqual(plugin["source"], f'./plugins/{plugin["name"]}')
        self.assertTrue(os.access(self.plugins / "plugins/superpowers/hooks/run-hook.cmd", os.X_OK))
        json.loads(self.tool("audit-skill-context", "--agent", "codex", self.plugins / "plugins/core/skills").stdout)
        expected = {
            f"{path.parent.name}@prateek-local": tomllib.loads(path.read_text()).get("default_loaded", True)
            for path in actual.glob("*/package.toml")
        }
        self.assertIn(True, expected.values())
        self.assertIn(False, expected.values())
        claude = json.loads(self.render("home/.chezmoitemplates/agent-claude-plugin-settings.json.tmpl"))["enabledPlugins"]
        codex = tomllib.loads((ROOT / "home/.chezmoitemplates/agent-codex-plugin-config.toml.tmpl").read_text())["plugins"]
        pi = json.loads(self.render("home/dot_pi/agent/claude-plugins.json.tmpl"))["plugins"]
        self.assertEqual({key: claude[key] for key in expected}, expected)
        self.assertEqual({key: codex[key]["enabled"] for key in expected}, expected)
        self.assertEqual({key: pi[key]["enabled"] for key in expected}, expected)

    def test_payloads_preserve_execution_modes_and_agent_specific_hooks_discovery(self):
        package = self.package("hooked", codex="plugin", claude="plugin")
        (package / "hooks").mkdir()
        (package / "hooks/hooks.json").write_text('{"hooks": {"SessionStart": []}}')
        (package / "hooks/session-start").write_text("#!/bin/sh\necho hi\n")
        (package / "hooks/session-start").chmod(0o755)
        (package / "commands").mkdir()
        (package / "commands/hello.md").touch()
        result = self.render_plugins("--skip-config-templates")
        self.assertEqual(set(result.stderr.decode().splitlines()), {
            "warning: hooked: codex has no mapping for hooks; that payload is claude-only",
            "warning: hooked: codex has no mapping for commands; that payload is claude-only",
        })
        rendered = self.plugins / "plugins/hooked"
        self.assertTrue((rendered / "commands/hello.md").is_file())
        self.assertTrue((rendered / "hooks/hooks.json").is_file())
        self.assertTrue(os.access(rendered / "hooks/session-start", os.X_OK))
        self.assertNotIn("hooks", json.loads((rendered / ".claude-plugin/plugin.json").read_text()))
        self.assertEqual(json.loads((rendered / ".codex-plugin/plugin.json").read_text())["hooks"], {})
        self.render_plugins("--check", "--skip-config-templates")
        (rendered / "hooks/session-start").chmod(0o644)
        result = self.render_plugins("--check", "--skip-config-templates", expected_status=1)
        self.assertIn(b"changed plugins/hooked/hooks/session-start", result.stdout + result.stderr)

    def test_root_maintenance_preserves_runtime_and_hand_authored_claude_skills(self):
        codex, claude = self.home / ".agents/skills", self.home / ".claude/skills"
        (codex / ".system/runtime").mkdir(parents=True)
        (codex / ".system/runtime/SKILL.md").write_text("runtime\n")
        (codex / "stale-core-skill").mkdir()
        (codex / "stale-core-skill/SKILL.md").touch()
        claude.mkdir(parents=True)
        (claude / "README.generated.md").touch()
        args = ("--codex-root", codex, "--claude-root", claude)
        self.tool("maintain-agent-skill-roots", *args)
        self.assertEqual((codex / ".system/runtime/SKILL.md").read_text(), "runtime\n")
        self.assertFalse((codex / "stale-core-skill").exists())
        self.assertTrue((codex / "README.generated.md").is_file())
        self.assertTrue((codex / ".gitignore").is_file())
        self.assertFalse(claude.exists())
        (claude / "hand-authored").mkdir(parents=True)
        result = self.tool("maintain-agent-skill-roots", *args)
        self.assertIn(b"not a generated skill root", result.stderr)
        self.assertTrue((claude / "hand-authored").is_dir())


class PluginReconcileTests(PackageTestCase):
    def setUp(self):
        super().setUp()
        self.package("on", codex="plugin", claude="plugin")
        self.package("off", loaded=False, claude="plugin")
        self.state = self.work / "plugin-state.json"
        self.log = self.work / "plugin.log"
        self.state.write_text(json.dumps({
            "marketplaces": {"prateek-local": "/tmp/stale-plugins-root"},
            "claude": {"on@prateek-local": False, "stale@prateek-local": True, "other@other-mkt": True},
            "codex": ["on@prateek-local", "stale@prateek-local"],
        }))
        self.env.update(FAKE_PLUGIN_STATE=str(self.state), FAKE_PLUGIN_LOG=str(self.log))
        for cli in ("claude", "codex"):
            script = self.bin / cli
            script.write_text(f"#!/bin/sh\nFAKE_PLUGIN_CLI={cli} exec {shlex.quote(sys.executable)} {shlex.quote(str(ROOT / 'tests/scenarios/agents/fake-plugin-cli.py'))} \"$@\"\n")
            script.chmod(0o700)

    def reconcile(self, *args, **kwargs):
        return self.tool("reconcile-agent-plugins", "--apply", "--agent", "claude", "--agent", "codex", "--plugins-root", self.plugins, *args, **kwargs)

    def mutations(self):
        return [line for line in self.log.read_text().splitlines() if " list " not in line]

    def test_preview_respects_default_loading_and_agent_render_policy(self):
        result = self.tool("reconcile-agent-plugins")
        self.assertEqual(result.stderr, b"")
        self.assertEqual(result.stdout.decode().splitlines(), [
            "claude plugin marketplace add ~/.agents/plugins --scope user",
            "claude plugin marketplace update prateek-local",
            "codex plugin add on@prateek-local",
            "claude plugin install off@prateek-local --scope user",
            "claude plugin disable off@prateek-local --scope user",
            "claude plugin install on@prateek-local --scope user",
            "claude plugin enable on@prateek-local --scope user",
        ])
        self.assertFalse(self.log.exists())

    def test_apply_converges_own_marketplace_and_refreshes_only_codex_in_steady_state(self):
        self.reconcile()
        self.assertEqual(self.mutations(), [
            f"claude plugin marketplace add {self.plugins} --scope user",
            "claude plugin install off@prateek-local --scope user",
            "claude plugin disable off@prateek-local --scope user",
            "claude plugin enable on@prateek-local --scope user",
            "claude plugin uninstall stale@prateek-local --scope user",
            "codex plugin add on@prateek-local",
            "codex plugin remove stale@prateek-local",
        ])
        state = json.loads(self.state.read_text())
        self.assertEqual(state["claude"], {"on@prateek-local": True, "other@other-mkt": True, "off@prateek-local": False})
        self.assertEqual(state["codex"], ["on@prateek-local"])
        self.assertEqual(state["marketplaces"]["prateek-local"], str(self.plugins))
        self.log.write_text("")
        self.reconcile()
        self.assertEqual(self.mutations(), ["codex plugin add on@prateek-local"])

    def test_dry_run_reports_changes_without_mutating_cli_state(self):
        self.reconcile()
        state = json.loads(self.state.read_text())
        state["claude"]["on@prateek-local"] = False
        self.state.write_text(json.dumps(state))
        before = self.state.read_bytes()
        self.log.write_text("")
        result = self.reconcile("--dry-run")
        self.assertIn(b"[dry-run] claude plugin enable on@prateek-local --scope user\n", result.stdout)
        self.assertIn(b"[dry-run] codex plugin add on@prateek-local\n", result.stdout)
        self.assertEqual(self.mutations(), [])
        self.assertEqual(self.state.read_bytes(), before)
        state["claude"]["on@prateek-local"] = True
        self.state.write_text(json.dumps(state))
        self.log.write_text("")
        self.reconcile()
        self.assertEqual(self.mutations(), ["codex plugin add on@prateek-local"])

    def test_cli_failure_names_command_and_stops_later_mutations(self):
        result = self.reconcile(env={"FAKE_PLUGIN_FAIL": "install"}, expected_status=1)
        self.assertIn(b"claude plugin install off@prateek-local --scope user failed", result.stderr)
        self.assertIn(b"simulated install failure", result.stderr)
        self.assertEqual(self.mutations(), [
            f"claude plugin marketplace add {self.plugins} --scope user",
            "claude plugin install off@prateek-local --scope user",
        ])
