import json
import os
import py_compile
import shlex
import shutil
import subprocess
import sys
import tomllib
from pathlib import Path

from tests.support.python import ROOT, RepoTestCase

SCRIPTS = ROOT / ".agents/skills/agent-skill-management/scripts"
PROJECT = ROOT / "agent-marketplace"


def _just_binary():
    resolved = shutil.which("just")
    if resolved and f"{os.sep}shims{os.sep}" in resolved:
        try:
            real = subprocess.run(["mise", "which", "just"], capture_output=True, text=True)
        except OSError:
            return resolved
        if real.returncode == 0 and real.stdout.strip():
            return real.stdout.strip()
    return resolved or "just"


# A shim would resolve its version from the fixture cwd, which has no mise config.
JUST = _just_binary()


def write_overlay_marketplace(root, plugins=None, name="work-overlay", version="0.1.0"):
    """Write a hand-maintained overlay marketplace; plugins maps each name to the clients listing it."""
    plugins = {"work": ("claude", "codex")} if plugins is None else plugins
    catalogs = {"claude": [], "codex": []}
    for plugin, clients in plugins.items():
        path = root / "plugins" / plugin
        (path / "skills/pair").mkdir(parents=True, exist_ok=True)
        (path / "skills/pair/SKILL.md").write_text("---\nname: pair\ndescription: Pair.\n---\n")
        for client in clients:
            (path / f".{client}-plugin").mkdir(exist_ok=True)
            (path / f".{client}-plugin/plugin.json").write_text(json.dumps({"name": plugin, "version": version}))
        if "claude" in clients:
            catalogs["claude"].append({"name": plugin, "source": f"./plugins/{plugin}"})
        if "codex" in clients:
            catalogs["codex"].append({"name": plugin, "source": {"source": "local", "path": f"./plugins/{plugin}"}})
    for client, catalog in (("claude", ".claude-plugin/marketplace.json"), ("codex", ".agents/plugins/marketplace.json")):
        (root / catalog).parent.mkdir(parents=True, exist_ok=True)
        (root / catalog).write_text(json.dumps({"name": name, "plugins": catalogs[client]}))
    return root


class PackageTestCase(RepoTestCase):
    def setUp(self):
        super().setUp()
        self.repo = self.work / "repo"
        self.project = self.repo / "agent-marketplace"
        self.packages = self.project / "packages"
        self.packages.mkdir(parents=True)
        shutil.copytree(PROJECT / "scripts", self.project / "scripts")
        self.python = PROJECT / ".venv/bin/python"
        shutil.copy(PROJECT / "justfile", self.project / "justfile")
        # The chezmoi apply script builds this copy through its own materializer,
        # so the runtime override has to reach that invocation too.
        self.env["MARKETPLACE_RUN"] = ""
        self.env["MARKETPLACE_PYTHON"] = str(self.python)
        self.plugins = self.home / ".agents/plugins"
        self.policy = self.repo / "home/.chezmoidata/agent_plugins.toml"
        self.policy.parent.mkdir(parents=True)
        self.policy.write_text("")
        self.env["AGENT_SKILL_PACKAGES_ROOT"] = str(self.packages)
        self.env["PATH"] = str(PROJECT / ".venv/bin") + os.pathsep + self.env["PATH"]
        self.entries = []

    def tool(self, name, *args, **kwargs):
        return self.command([sys.executable, str(SCRIPTS / name), *map(str, args)], **kwargs)

    def package(self, name="sample", *, loaded=False, codex=True, claude=True):
        path = self.packages / name
        skill = path / "skills" / (name + "-skill")
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text(f"---\nname: {name}-skill\ndescription: Fixture skill.\n---\n\nHello.\n")
        (path / ".codex-plugin").mkdir()
        (path / ".codex-plugin/plugin.json").write_text(json.dumps({"name": name, "version": "1.0.0", "skills": "./skills/", "description": "Example skills", "license": "UNLICENSED"}))
        with self.policy.open("a") as policy:
            policy.write(f"[agent_plugins.{name}]\ndefault_loaded = {str(loaded).lower()}\nclaude = {str(claude).lower()}\ncodex = {str(codex).lower()}\n\n")
        self.entries.append({"name": name, "source": f"./plugins/{name}", "category": "Productivity"})
        # JSON is an APM-supported YAML subset.
        (self.project / "apm.yml").write_text(json.dumps({"name": "prateek-local", "version": "1.0.0", "license": "UNLICENSED",
            "marketplace": {"owner": {"name": "Fixture"}, "outputs": {"claude": {}, "codex": {}}, "packages": self.entries}}))
        return path

    def build(self):
        self.command([JUST, "--justfile", str(self.project / "justfile"),
                      "--working-directory", str(self.project), "build"])
        return self.project / "build/marketplace"

    def materialize(self, artifact=None, **kwargs):
        return self.tool("materialize-agent-plugins", "--artifact-root", artifact or self.build(), "--plugins-root", self.plugins, **kwargs)


class PackageValidationTests(PackageTestCase):

    def test_build_on_materialization_resolves_repo_tools_from_outside_the_repo(self):
        self.package()
        shims = self.work / "shims"
        shims.mkdir()
        (shims / "just").write_text("#!/bin/sh\necho 'No version is set for shim: just' >&2\nexit 1\n")
        (shims / "mise").write_text(
            "#!/bin/sh\n"
            '[ "$1" = which ] && [ "$2" = just ] && [ -f mise.toml ] || exit 1\n'
            f"printf '%s\\n' {shlex.quote(JUST)}\n"
        )
        for path in shims.iterdir():
            path.chmod(0o700)
        self.tool("materialize-agent-plugins", "--project-root", self.project,
                  "--plugins-root", self.plugins, cwd=self.home,
                  env={"PATH": str(shims) + os.pathsep + self.env["PATH"]})
        self.assertEqual((self.plugins / "plugins/sample/skills/sample-skill/SKILL.md").read_text(),
                         "---\nname: sample-skill\ndescription: Fixture skill.\n---\n\nHello.\n")

    def test_legacy_retirement_checks_chezmoi_target_bytes_and_preserves_unknown_changes(self):
        source = self.repo / "home/dot_agents/packages/sample/skills/local/old/literal_run.py"
        source.parent.mkdir(parents=True)
        source.write_text("print('old')\n")
        for args in (["init", "-q"], ["add", "home/dot_agents/packages"],
                     ["-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "Legacy source"]):
            self.command(["git", *args], cwd=self.repo)
        target = self.home / ".agents/packages"
        installed = target / "sample/skills/local/old/run.py"
        installed.parent.mkdir(parents=True)
        installed.write_bytes(source.read_bytes())
        unknown = target / "personal-note"
        unknown.write_text("keep\n")
        args = ("--repo-root", self.repo, "--baseline", "HEAD", "--packages-root", target)
        self.assertIn(b"Preserved legacy source", self.tool("retire-legacy-agent-packages", *args).stderr)
        self.assertEqual(unknown.read_text(), "keep\n")
        unknown.unlink()
        result = self.tool("retire-legacy-agent-packages", *args)
        self.assertEqual(result.stderr, b"")
        self.assertFalse(target.exists())
        self.assertEqual((target.with_name("packages.retired") / installed.relative_to(target)).read_bytes(), source.read_bytes())
    def test_selected_inventory_and_explicit_policy(self):
        self.package("on", loaded=True)
        self.package("off", codex=False, claude=False)
        result = self.tool("validate-agent-packages")
        self.assertEqual(result.stdout, b"OK validate-agent-packages\n")
        inventory = json.loads(self.tool("inventory-agent-skills").stdout)["packages"]
        self.assertEqual({p["id"]: p["default_loaded"] for p in inventory}, {"off": False, "on": True})
        artifact = self.project / "build/marketplace"
        catalog = json.loads((artifact / ".agents/plugins/marketplace.json").read_text())
        self.assertEqual({p["name"] for p in catalog["plugins"]}, {"on", "off"})
        self.policy.write_text("")
        self.tool("validate-agent-packages", expected_status=1)

    def test_materialization_preserves_modes_stale_removal_and_previous_release_without_apm(self):
        package = self.package()
        helper = package / "skills/sample-skill/helper"
        helper.write_text("#!/bin/sh\nexit 0\n")
        helper.chmod(0o755)
        first = self.build()
        self.materialize(first, env={"PATH": "/usr/bin:/bin"})
        installed = self.plugins / "plugins/sample/skills/sample-skill/helper"
        self.assertEqual(installed.stat().st_mode & 0o777, 0o755)
        helper.unlink()
        self.materialize()
        self.assertFalse(installed.exists())
        previous = self.plugins.with_name("plugins.previous")
        self.assertTrue((previous / "plugins/sample/skills/sample-skill/helper").is_file())
        rollback_receipt = (previous / "release.json").read_bytes()
        self.materialize()
        self.assertEqual((previous / "release.json").read_bytes(), rollback_receipt)
        self.materialize(previous)
        self.assertEqual(installed.stat().st_mode & 0o777, 0o755)

    def test_failed_artifact_validation_preserves_live_and_foreign_directories(self):
        self.package()
        artifact = self.build()
        self.materialize(artifact)
        installed = self.plugins / "plugins/sample/skills/sample-skill/SKILL.md"
        before = installed.read_bytes()
        (artifact / "plugins/sample/skills/sample-skill/SKILL.md").write_text("damaged\n")
        result = self.materialize(artifact, expected_status=1)
        self.assertIn(b"release receipt", result.stderr)
        self.assertEqual(installed.read_bytes(), before)
        shutil.rmtree(self.plugins)
        self.plugins.mkdir()
        (self.plugins / "my-plugin").write_text("keep\n")
        result = self.materialize(expected_status=1)
        self.assertIn(b"unowned", result.stderr)
        self.assertEqual((self.plugins / "my-plugin").read_text(), "keep\n")

    def test_runtime_bytecode_preserves_repeat_materialization_upgrade_and_rollback(self):
        package = self.package()
        helper = package / "skills/sample-skill/helper.py"
        helper.write_text("VALUE = 1\n")
        artifact = self.build()
        self.materialize(artifact)
        installed = self.plugins / "plugins/sample/skills/sample-skill/helper.py"
        cache = installed.parent / "__pycache__/helper.pyc"
        py_compile.compile(str(installed), cfile=str(cache), doraise=True)
        cached_bytes = cache.read_bytes()
        receipt = (self.plugins / "release.json").read_bytes()

        self.materialize(artifact)
        self.assertEqual(cache.read_bytes(), cached_bytes)
        self.assertEqual((self.plugins / "release.json").read_bytes(), receipt)
        previous = self.plugins.with_name("plugins.previous")
        self.assertFalse(previous.exists())
        result = self.tool("reconcile-agent-plugins", "--plugins-root", self.plugins, "--policy", self.policy)
        self.assertIn(b"sample: version 1.0.0", result.stdout)

        helper.unlink()
        self.materialize()
        self.assertFalse(installed.exists())
        self.assertFalse(cache.parent.exists())
        self.assertEqual((previous / cache.relative_to(self.plugins)).read_bytes(), cached_bytes)
        self.materialize(previous)
        self.assertEqual(installed.read_text(), "VALUE = 1\n")
        self.assertFalse(cache.parent.exists())
        self.assertFalse((previous / installed.relative_to(self.plugins)).exists())

    def test_runtime_cache_tolerance_still_refuses_payload_drift(self):
        self.package()
        artifact = self.build()
        self.materialize(artifact)
        installed = self.plugins / "plugins/sample/skills/sample-skill/SKILL.md"
        before = installed.read_bytes()
        mode = installed.stat().st_mode & 0o777
        cache = installed.parent / "__pycache__"
        cache.mkdir()
        (cache / "helper.pyc").write_bytes(b"runtime bytecode")
        extra = installed.parent / "notes.txt"
        for kind in ("bytes", "mode", "missing", "extra", "symlink"):
            with self.subTest(kind=kind):
                try:
                    if kind == "bytes":
                        installed.write_text("local edit\n")
                    elif kind == "mode":
                        installed.chmod(0o755)
                    elif kind == "missing":
                        installed.unlink()
                    elif kind == "extra":
                        extra.write_text("keep\n")
                    else:
                        extra.symlink_to(installed)
                    result = self.materialize(artifact, expected_status=1)
                    self.assertIn(b"symlink" if kind == "symlink" else b"release receipt", result.stderr)
                    self.assertFalse(self.plugins.with_name("plugins.previous").exists())
                    if kind == "bytes":
                        self.assertEqual(installed.read_text(), "local edit\n")
                    elif kind == "mode":
                        self.assertEqual(installed.stat().st_mode & 0o777, 0o755)
                    elif kind == "missing":
                        self.assertFalse(installed.exists())
                    else:
                        self.assertTrue(extra.exists())
                finally:
                    installed.write_bytes(before)
                    installed.chmod(mode)
                    extra.unlink(missing_ok=True)

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
        self.package("on", loaded=True)
        self.package("off")
        self.materialize()
        self.state = self.work / "plugin-state.json"
        self.log = self.work / "plugin.log"
        self.state.write_text(json.dumps({
            "marketplaces": {"prateek-local": "/tmp/stale-plugins-root"},
            "codex_marketplaces": {"prateek-local": "/tmp/stale-plugins-root"},
            "omp": {"on@prateek-local": {"enabled": False, "version": "0.9.0"},
                    "stale@prateek-local": {"enabled": True, "version": "1.0.0"}},
            "claude": {"on@prateek-local": {"enabled": False, "version": "0.9.0"},
                       "stale@prateek-local": {"enabled": True, "version": "1.0.0"},
                       "other@other-mkt": {"enabled": True, "version": "2.0.0"}},
            "codex": {"on@prateek-local": {"enabled": True, "version": "0.9.0"},
                      "off@prateek-local": {"enabled": False, "version": "0.9.0"},
                      "stale@prateek-local": {"enabled": True, "version": "1.0.0"},
                      "other@other-mkt": {"enabled": False, "version": "2.0.0"}},
        }))
        self.env.update(FAKE_PLUGIN_STATE=str(self.state), FAKE_PLUGIN_LOG=str(self.log))
        executables = self.work / "bin"
        executables.mkdir()
        self.env["PATH"] = str(executables) + os.pathsep + self.env["PATH"]
        for cli in ("claude", "codex", "omp"):
            script = executables / cli
            script.write_text(f"#!/bin/sh\nFAKE_PLUGIN_CLI={cli} exec {shlex.quote(sys.executable)} {shlex.quote(str(ROOT / 'tests/scenarios/agents/fake-plugin-cli.py'))} \"$@\"\n")
            script.chmod(0o700)

    def reconcile(self, *args, **kwargs):
        return self.tool("reconcile-agent-plugins", "--apply", "--agent", "claude", "--agent", "codex",
                         "--plugins-root", self.plugins, "--policy", self.policy, *args, **kwargs)

    def test_converges_owned_versions_and_state_preserving_foreign_plugins(self):
        self.reconcile()
        state = json.loads(self.state.read_text())
        for agent in ("claude", "codex"):
            self.assertEqual(state[agent]["on@prateek-local"], {"enabled": True, "version": "1.0.0"})
            self.assertEqual(state[agent]["off@prateek-local"], {"enabled": False, "version": "1.0.0"})
            self.assertNotIn("stale@prateek-local", state[agent])
            self.assertEqual(state[agent]["other@other-mkt"]["version"], "2.0.0")
        self.assertFalse(state["codex"]["other@other-mkt"]["enabled"])
        self.log.write_text("")
        self.reconcile()
        mutations = [line for line in self.log.read_text().splitlines() if " list " not in line]
        self.assertEqual(mutations, ["codex plugin add on@prateek-local"])
        self.log.write_text("")
        self.reconcile("--refresh-disabled", "off")
        self.assertIn("codex plugin add off@prateek-local", self.log.read_text())
        self.assertFalse(json.loads(self.state.read_text())["codex"]["off@prateek-local"]["enabled"])


    def overlay_marketplace(self, version="0.1.0", plugins=None):
        return write_overlay_marketplace(self.work / "overlay/agent-plugins", plugins, version=version)

    def test_overlay_converges_its_own_marketplace_and_leaves_prateek_local_alone(self):
        root = self.overlay_marketplace()
        before = json.loads(self.state.read_text())
        self.tool("reconcile-agent-plugins", "--apply", "--overlay", "--agent", "claude", "--agent", "codex",
                  "--agent", "omp", "--plugins-root", root)
        state = json.loads(self.state.read_text())
        for agent in ("claude", "codex", "omp"):
            self.assertEqual(state[agent].pop("work@work-overlay"), {"enabled": True, "version": "0.1.0"})
            self.assertEqual(state[agent], before[agent])
        self.assertEqual(state["marketplaces"]["work-overlay"], str(root))
        self.assertEqual(state["marketplaces"]["prateek-local"], "/tmp/stale-plugins-root")

        self.overlay_marketplace(version="0.2.0")
        self.tool("reconcile-agent-plugins", "--apply", "--overlay", "--agent", "claude",
                  "--plugins-root", root)
        self.assertEqual(json.loads(self.state.read_text())["claude"]["work@work-overlay"]["version"], "0.2.0")

    def test_overlay_plugin_without_skills_still_converges(self):
        # Overlay plugins are hand-maintained; one may carry only commands or MCP config.
        root = self.overlay_marketplace()
        shutil.rmtree(root / "plugins/work/skills")
        self.tool("reconcile-agent-plugins", "--apply", "--overlay", "--agent", "claude", "--plugins-root", root)
        self.assertEqual(json.loads(self.state.read_text())["claude"]["work@work-overlay"],
                         {"enabled": True, "version": "0.1.0"})

    def test_overlay_plugin_reaches_only_the_clients_whose_catalog_lists_it(self):
        # A Claude-only plugin ships no Codex manifest; omp reads the Claude catalog.
        root = self.overlay_marketplace(plugins={"work": ("claude", "codex"), "hooks": ("claude",)})
        self.tool("reconcile-agent-plugins", "--apply", "--overlay", "--agent", "claude", "--agent", "codex",
                  "--agent", "omp", "--plugins-root", root)
        state = json.loads(self.state.read_text())
        for agent in ("claude", "omp"):
            self.assertEqual(state[agent]["hooks@work-overlay"], {"enabled": True, "version": "0.1.0"})
        self.assertNotIn("hooks@work-overlay", state["codex"])
        self.assertIn("work@work-overlay", state["codex"])

    def test_overlay_refuses_one_plugin_name_at_two_directories(self):
        root = self.overlay_marketplace(plugins={"work": ("claude", "codex"), "other": ("claude", "codex")})
        catalog = json.loads((root / ".claude-plugin/marketplace.json").read_text())
        catalog["plugins"][0]["source"] = "./plugins/other"
        (root / ".claude-plugin/marketplace.json").write_text(json.dumps(catalog))
        result = self.tool("reconcile-agent-plugins", "--apply", "--overlay", "--agent", "claude",
                           "--plugins-root", root, expected_status=1)
        self.assertIn(b"points at different directories", result.stderr)
        self.assertFalse(self.log.exists())

    def test_overlay_refuses_a_manifest_with_no_version(self):
        root = self.overlay_marketplace(plugins={"work": ("claude", "codex"), "hooks": ("claude",)})
        (root / "plugins/hooks/.claude-plugin/plugin.json").write_text(json.dumps({"name": "hooks"}))
        result = self.tool("reconcile-agent-plugins", "--apply", "--overlay", "--agent", "claude",
                           "--plugins-root", root, expected_status=1)
        self.assertIn(b"hooks has a manifest with no version", result.stderr)
        self.assertFalse(self.log.exists())

    def test_overlay_refuses_the_published_marketplace_name(self):
        root = self.overlay_marketplace()
        for catalog in (".claude-plugin/marketplace.json", ".agents/plugins/marketplace.json"):
            data = json.loads((root / catalog).read_text())
            (root / catalog).write_text(json.dumps({**data, "name": "prateek-local"}))
        result = self.tool("reconcile-agent-plugins", "--apply", "--overlay", "--agent", "claude",
                           "--plugins-root", root, expected_status=1)
        self.assertIn(b"cannot reuse the prateek-local name", result.stderr)
        self.assertFalse(self.log.exists())

    def test_overlay_refuses_split_manifest_versions(self):
        root = self.overlay_marketplace()
        (root / "plugins/work/.claude-plugin/plugin.json").write_text(json.dumps({"name": "work", "version": "0.2.0"}))
        result = self.tool("reconcile-agent-plugins", "--apply", "--overlay", "--agent", "claude",
                           "--plugins-root", root, expected_status=1)
        self.assertIn(b"different Claude and Codex manifest versions", result.stderr)
        self.assertFalse(self.log.exists())

    def omp_reconcile(self, *args, **kwargs):
        return self.tool("reconcile-agent-plugins", "--apply", "--agent", "omp",
                         "--plugins-root", self.plugins, "--policy", self.policy, *args, **kwargs)

    def test_omp_converges_versions_enabled_state_and_owned_orphans(self):
        self.omp_reconcile()
        state = json.loads(self.state.read_text())
        self.assertEqual(state["omp"], {"on@prateek-local": {"enabled": True, "version": "1.0.0"},
                                        "off@prateek-local": {"enabled": False, "version": "1.0.0"}})
        self.assertNotIn("stale@prateek-local", state["omp"])
        self.assertEqual(state["marketplaces"]["prateek-local"], str(self.plugins))
        self.log.write_text("")
        self.omp_reconcile()
        mutations = [line for line in self.log.read_text().splitlines() if " list" not in line]
        self.assertEqual(mutations, [])
        self.log.write_text("")
        dry = self.omp_reconcile("--dry-run")
        self.assertEqual(dry.stdout, b"")

    def test_omp_refreshes_catalog_before_installing_new_plugin(self):
        state = json.loads(self.state.read_text())
        state["marketplaces"]["prateek-local"] = str(self.plugins)
        state["omp"] = {"on@prateek-local": {"enabled": True, "version": "1.0.0"}}
        state["omp_catalog"] = ["on"]
        self.state.write_text(json.dumps(state))

        self.omp_reconcile()
        state = json.loads(self.state.read_text())
        self.assertEqual(state["omp"]["off@prateek-local"], {"enabled": False, "version": "1.0.0"})
        self.assertIn("off", state["omp_catalog"])

    def test_dry_run_reads_each_state_once_without_mutations(self):
        before = self.state.read_bytes()
        result = self.reconcile("--dry-run")
        self.assertIn(b"[dry-run]", result.stdout)
        self.assertEqual(self.state.read_bytes(), before)
        self.assertEqual(len(self.log.read_text().splitlines()), 4)

    def test_missing_policy_fails_before_any_native_call(self):
        self.policy.unlink()
        self.reconcile(expected_status=1)
        self.assertFalse(self.log.exists())

    def test_cli_failure_names_command_and_stops_later_mutations(self):
        result = self.reconcile(env={"FAKE_PLUGIN_FAIL": "install"}, expected_status=1)
        self.assertIn(b"claude plugin install", result.stderr)
        self.assertIn(b"simulated install failure", result.stderr)
        self.assertNotIn("codex", self.log.read_text())

    def test_later_codex_failure_keeps_refreshed_disabled_plugin_disabled(self):
        self.package("zbad", loaded=True)
        self.materialize()
        result = self.tool("reconcile-agent-plugins", "--apply", "--agent", "codex",
                           "--plugins-root", self.plugins, "--policy", self.policy,
                           env={"FAKE_PLUGIN_FAIL": "zbad@prateek-local"}, expected_status=1)
        self.assertIn(b"codex plugin add zbad@prateek-local failed", result.stderr)
        state = json.loads(self.state.read_text())["codex"]
        self.assertEqual(state["off@prateek-local"], {"version": "1.0.0", "enabled": False})

    def test_scoped_chezmoi_apply_converges_the_complete_agent_layout_and_hashes_source_changes(self):
        templates = self.repo / "home/.chezmoitemplates"
        templates.mkdir()
        for name in ("script_lib.sh", "features.tmpl", "agents.tmpl", "agent-marketplace-tree-hash.tmpl",
                     "agent-claude-plugin-settings.json.tmpl", "agent-codex-plugin-config.toml.tmpl",
                     "claude-settings-managed.json.tmpl", "codex-config-managed.toml.tmpl",
                     "cursor-cli-config-managed.json.tmpl", "work-overlay.tmpl"):
            shutil.copy2(ROOT / "home/.chezmoitemplates" / name, templates / name)
        for name in ("machines.toml", "agents.toml"):
            shutil.copy2(ROOT / "home/.chezmoidata" / name, self.policy.parent / name)
        shutil.copytree(SCRIPTS, self.repo / ".agents/skills/agent-skill-management/scripts",
                        ignore=shutil.ignore_patterns("__pycache__"))
        scripts = self.repo / "home/.chezmoiscripts"
        scripts.mkdir()
        for name in ("run_onchange_after_35-agent-skill-roots.sh.tmpl", "run_onchange_after_36-agent-plugins.sh.tmpl"):
            shutil.copy2(ROOT / "home/.chezmoiscripts" / name, scripts / name)
        source = scripts / "run_onchange_after_36-agent-plugins.sh.tmpl"
        for relative in ("dot_agents/AGENTS.md", "dot_claude/symlink_CLAUDE.md", "dot_codex/symlink_skills",
                         "dot_claude/modify_private_settings.json.tmpl", "dot_codex/modify_private_config.toml.tmpl",
                         "dot_cursor/modify_private_cli-config.json.tmpl", "dot_pi/agent/modify_settings.json.tmpl",
                         "dot_pi/agent/claude-plugins.json.tmpl"):
            target = self.repo / "home" / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / "home" / relative, target)
        (self.repo / ".chezmoiroot").write_text("home\n")
        self.env.update(CODEX_HOME=str(self.home / ".codex"), CLAUDE_CONFIG_DIR=str(self.home / ".claude"),
                        UV_CACHE_DIR=subprocess.check_output(["uv", "cache", "dir"], text=True).strip())
        initial = {
            ".claude/settings.json": '{"env":{"KEEP":"yes"},"enabledPlugins":{"other@other-mkt":true}}\n',
            ".codex/config.toml": '[unrelated]\nkeep = true\n[plugins."other@other-mkt"]\nenabled = false\n',
            ".cursor/cli-config.json": '{"auth":{"token":"fixture"}}\n',
            ".pi/agent/settings.json": '{"theme":"fixture","packages":["npm:fixture"]}\n',
            ".agents/skills/.system/runtime/SKILL.md": "Runtime sentinel.\n",
            ".agents/skills/stale/SKILL.md": "Old projection.\n",
            ".claude/skills/README.generated.md": "Old generated root.\n",
            ".agents/packages/personal-note": "Preserve unknown legacy source.\n",
        }
        for relative, content in initial.items():
            path = self.home / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        helper = self.packages / "on/skills/on-skill/helper.sh"
        helper.write_text("#!/bin/sh\nexit 0\n")
        helper.chmod(0o755)
        command = ["chezmoi", "--source", str(self.repo), "--config", str(self.config), "--destination", str(self.home),
                   "--cache", str(self.work / "chezmoi-cache"), "--persistent-state", str(self.work / "chezmoi-state"),
                   "--no-tty", "--override-data", json.dumps({"machine_type": "personal",
                   "chezmoi": {"hostname": "dotfiles-test-host"}, "machines_local": {"agent_clis": ["claude", "codex"]}})]
        before = self.command([*command, "execute-template", "--file", str(source)]).stdout
        self.assertIn(b"materialize-agent-plugins", self.command([*command, "diff", "--include=scripts"]).stdout)
        applied = self.command([*command, "apply", "--force"])
        self.assertIn(b"Preserved legacy source", applied.stderr)
        state = json.loads(self.state.read_text())
        self.assertEqual(state["claude"]["on@prateek-local"], {"version": "1.0.0", "enabled": True})
        self.assertFalse(state["codex"]["off@prateek-local"]["enabled"])
        self.assertEqual(state["codex"]["other@other-mkt"], {"version": "2.0.0", "enabled": False})
        self.assertTrue((self.plugins / "release.json").is_file())
        for native, catalog in (("claude", ".claude-plugin/marketplace.json"), ("codex", ".agents/plugins/marketplace.json")):
            entries = json.loads((self.plugins / catalog).read_text())["plugins"]
            for entry in entries:
                relative = entry["source"] if native == "claude" else entry["source"]["path"]
                plugin = self.plugins / relative
                self.assertEqual(plugin.resolve(), (self.plugins / "plugins" / entry["name"]).resolve())
                self.assertTrue((plugin / f".{native}-plugin/plugin.json").is_file())
        self.assertEqual((self.plugins / "plugins/on/skills/on-skill/helper.sh").stat().st_mode & 0o777, 0o755)
        self.assertEqual((self.home / ".codex/skills").readlink().as_posix(), "../.agents/skills")
        self.assertEqual((self.home / ".claude/CLAUDE.md").readlink().as_posix(), "../.agents/AGENTS.md")
        self.assertEqual((self.home / ".claude/CLAUDE.md").read_bytes(), (ROOT / "home/dot_agents/AGENTS.md").read_bytes())
        self.assertEqual((self.home / ".codex/skills/.system/runtime/SKILL.md").read_text(), initial[".agents/skills/.system/runtime/SKILL.md"])
        self.assertFalse((self.home / ".agents/skills/stale").exists())
        self.assertFalse((self.home / ".claude/skills").exists())
        self.assertEqual((self.home / ".agents/packages/personal-note").read_text(), initial[".agents/packages/personal-note"])
        claude = json.loads((self.home / ".claude/settings.json").read_text())
        self.assertEqual(claude["extraKnownMarketplaces"]["prateek-local"]["source"]["path"], str(self.plugins))
        self.assertEqual(claude["enabledPlugins"], {"on@prateek-local": True, "off@prateek-local": False, "other@other-mkt": True})
        self.assertEqual(claude["env"]["KEEP"], "yes")
        codex = tomllib.loads((self.home / ".codex/config.toml").read_text())
        self.assertEqual(codex["marketplaces"]["prateek-local"]["source"], str(self.plugins))
        self.assertEqual({key: value for key, value in codex["plugins"].items() if key.endswith("@prateek-local")},
                         {"on@prateek-local": {"enabled": True}, "off@prateek-local": {"enabled": False}})
        self.assertEqual(codex["plugins"]["other@other-mkt"], {"enabled": False})
        self.assertTrue(codex["unrelated"]["keep"])
        cursor = json.loads((self.home / ".cursor/cli-config.json").read_text())
        self.assertEqual(cursor["marketplaces"]["prateek-local"]["path"], str(self.plugins))
        self.assertEqual(cursor["auth"], {"token": "fixture"})
        pi = json.loads((self.home / ".pi/agent/claude-plugins.json").read_text())
        self.assertEqual(pi["marketplaces"]["prateek-local"], {"source": str(self.plugins), "autoupdate": False})
        self.assertEqual(pi["plugins"], {"on@prateek-local": {"enabled": True}, "off@prateek-local": {"enabled": False}})
        pi_settings = json.loads((self.home / ".pi/agent/settings.json").read_text())
        self.assertEqual(pi_settings["theme"], "fixture")
        self.assertIn("npm:fixture", pi_settings["packages"])
        self.assertIn("npm:pi-claude-marketplace", pi_settings["packages"])
        preserved = [self.home / name for name in initial if (self.home / name).is_file()]
        preserved.extend([self.home / ".pi/agent/claude-plugins.json", self.plugins / "release.json",
                          self.plugins.with_name("plugins.previous") / "release.json"])
        accepted = {path: path.read_bytes() for path in preserved}
        calls = self.log.read_bytes()
        self.command([*command, "apply", "--force"])
        self.command([*command, "verify", "--exclude=scripts"])
        self.assertEqual(self.log.read_bytes(), calls)
        self.assertEqual({path: path.read_bytes() for path in preserved}, accepted)
        helper.write_text("#!/bin/sh\nexit 1\n")
        after = self.command([*command, "execute-template", "--file", str(source)]).stdout
        self.assertNotEqual(before, after)
        helper.chmod(0o644)
        self.assertNotEqual(after, self.command([*command, "execute-template", "--file", str(source)]).stdout)


class WorkOverlayTemplateTests(RepoTestCase):
    overlay = {"work_overlay": {"repo": "git@example.invalid:work/repo.git", "ref": "main", "subdir": "users/me"}}

    def rendered(self, machine_type, data=None):
        render = lambda path: self.render(path, machine_type, data=data).decode()
        return {
            "claude": json.loads(render("home/.chezmoitemplates/agent-claude-plugin-settings.json.tmpl")),
            "codex": tomllib.loads(render("home/.chezmoitemplates/agent-codex-plugin-config.toml.tmpl")),
            "cursor": json.loads(render("home/.chezmoitemplates/cursor-cli-config-managed.json.tmpl")),
            "pi": json.loads(render("home/dot_pi/agent/claude-plugins.json.tmpl")),
            "script": render("home/.chezmoiscripts/run_onchange_after_39-agent-work-overlay.sh.tmpl"),
        }

    def test_overlay_marketplace_registers_only_on_work_with_a_repo(self):
        plugins = self.home / ".local/share/dotfiles/work-overlay/users/me/agent-plugins"
        without_catalog = self.rendered("work", self.overlay)
        write_overlay_marketplace(plugins, {"work": ("claude", "codex"), "extra": ("claude", "codex"),
                                            "hooks": ("claude",), "cli": ("codex",)}, name="acme")
        work = self.rendered("work", self.overlay)
        plugins = str(plugins)
        self.assertEqual(work["claude"]["extraKnownMarketplaces"]["acme"]["source"]["path"], plugins)
        self.assertEqual({k: v for k, v in work["claude"]["enabledPlugins"].items() if k.endswith("@acme")},
                         {"work@acme": True, "extra@acme": True, "hooks@acme": True})
        self.assertEqual(work["codex"]["marketplaces"]["acme"]["source"], plugins)
        self.assertEqual({k for k in work["codex"]["plugins"] if k.endswith("@acme")},
                         {"work@acme", "extra@acme", "cli@acme"})
        self.assertIs(work["codex"]["plugins"]["extra@acme"]["enabled"], True)
        self.assertEqual(work["cursor"]["marketplaces"]["acme"]["path"], plugins)
        self.assertEqual(work["pi"]["marketplaces"]["acme"]["source"], plugins)
        self.assertIs(work["pi"]["plugins"]["work@acme"]["enabled"], True)
        self.assertEqual({k for k in work["pi"]["plugins"] if k.endswith("@acme")},
                         {"work@acme", "extra@acme", "hooks@acme"})
        self.assertIn(f"--overlay --plugins-root \"$overlay\"", work["script"])
        self.assertIn(f"overlay='{plugins}'", work["script"])
        # Before the clone lands a catalog, clients get no marketplace but the script still runs.
        self.assertNotIn("acme", json.dumps({k: v for k, v in without_catalog.items() if k != "script"}))
        self.assertIn("--overlay", without_catalog["script"])
        for rendered in (self.rendered("work"), self.rendered("personal", self.overlay)):
            self.assertNotIn("acme", json.dumps({k: v for k, v in rendered.items() if k != "script"}))
            self.assertEqual(rendered["script"].strip(), "")

    def test_overlay_clone_is_shallow_and_sparse_on_the_overlay_directory(self):
        external = tomllib.loads(self.render("home/.chezmoiexternal.toml.tmpl", "work", data=self.overlay).decode())
        entry = external[".local/share/dotfiles/work-overlay"]
        self.assertEqual(entry["url"], self.overlay["work_overlay"]["repo"])
        self.assertEqual(entry["clone"]["args"], ["--depth", "1", "--single-branch", "--filter=blob:none",
                                                  "--sparse", "--branch", "main"])
        sparse = "home/.chezmoiscripts/run_after_36a-work-overlay-sparse.sh.tmpl"
        self.assertIn("sparse-checkout set --cone 'users/me'", self.render(sparse, "work", data=self.overlay).decode())
        self.assertEqual(self.render(sparse, "work").strip(), b"")
        self.assertNotIn(".local/share/dotfiles/work-overlay",
                         tomllib.loads(self.render("home/.chezmoiexternal.toml.tmpl", "personal", data=self.overlay).decode()))

    def test_a_catalog_that_fails_validation_leaves_clients_unregistered_and_apply_rendering(self):
        # The external renders from this template too; failing it would block the refresh that pulls a fix.
        plugins = self.home / ".local/share/dotfiles/work-overlay/users/me/agent-plugins"
        write_overlay_marketplace(plugins, name="prateek-local")
        rendered = self.rendered("work", self.overlay)
        self.assertNotIn(str(plugins), json.dumps({k: v for k, v in rendered.items() if k != "script"}))
        self.assertIn("--overlay --plugins-root \"$overlay\"", rendered["script"])
        external = tomllib.loads(self.render("home/.chezmoiexternal.toml.tmpl", "work", data=self.overlay).decode())
        self.assertIn(".local/share/dotfiles/work-overlay", external)

    def test_slack_doc_composes_overlay_fragments_only_when_the_overlay_is_enabled(self):
        docs = self.home / ".local/share/dotfiles/work-overlay/users/me/agents/docs"
        docs.mkdir(parents=True)
        (docs / "slack-channels.md").write_text("## Internal map\n\n#acme-oncall\n")
        script = "home/.chezmoiscripts/run_onchange_after_37-agent-slack-doc.sh.tmpl"
        for machine_type, data, expected in (("work", self.overlay, "#acme-oncall"),
                                             ("personal", self.overlay, "Not rendered on this machine"),
                                             ("work", None, "Not rendered on this machine")):
            with self.subTest(machine_type=machine_type, overlay=bool(data)):
                path = self.work / "compose-slack-doc.sh"
                path.write_bytes(self.render(script, machine_type, data=data))
                self.command(["bash", str(path)])
                slack = (self.home / ".agents/docs/slack.md").read_text()
                self.assertIn(expected, slack)
                self.assertEqual("#acme-oncall" in slack, expected == "#acme-oncall")


class CodexRpcTests(RepoTestCase):
    def test_fragmented_responses_and_notifications_across_multiple_requests(self):
        cli = self.work / "codex"
        cli.write_text(f"#!{sys.executable}\n" + '''import json, sys, time
for line in sys.stdin:
    request = json.loads(line)
    response = json.dumps({"id": request["id"], "result": {"method": request["method"]}})
    sys.stdout.write(response[:8])
    sys.stdout.flush()
    time.sleep(0.05)
    sys.stdout.write(response[8:] + '\\n{"method":"notification"}\\n')
    sys.stdout.flush()
''')
        cli.chmod(0o700)
        result = self.command([sys.executable, "-c",
            "import sys,json; sys.path.insert(0,sys.argv[1]); from codex_rpc import requests; "
            "print(json.dumps(requests([('one',{}),('two',{})],cli=sys.argv[2])))",
            str(SCRIPTS), str(cli)])
        self.assertEqual(json.loads(result.stdout), [{"method": "one"}, {"method": "two"}])
