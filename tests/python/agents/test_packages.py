import json
import os
import shlex
import shutil
import subprocess
import sys
import tomllib
from pathlib import Path

from tests.support.python import ROOT, RepoTestCase

SCRIPTS = ROOT / ".agents/skills/agent-skill-management/scripts"
PROJECT = ROOT / "agent-marketplace"


class PackageTestCase(RepoTestCase):
    def setUp(self):
        super().setUp()
        self.repo = self.work / "repo"
        self.project = self.repo / "agent-marketplace"
        self.packages = self.project / "packages"
        self.packages.mkdir(parents=True)
        shutil.copytree(PROJECT / "scripts", self.project / "scripts")
        self.python = PROJECT / ".venv/bin/python"
        (self.project / "Makefile").write_text(
            f"RUN :=\nPYTHON := {shlex.quote(str(self.python))}\n" + (PROJECT / "Makefile").read_text())
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
        (path / "apm.yml").write_text(f"name: {json.dumps(name)}\nversion: 1.0.0\ndescription: Example skills\nlicense: UNLICENSED\ntargets: [claude]\n")
        (path / ".codex-plugin").mkdir()
        (path / ".codex-plugin/plugin.json").write_text(json.dumps({"name": name, "version": "1.0.0", "skills": "./skills/"}))
        with self.policy.open("a") as policy:
            policy.write(f"[agent_plugins.{name}]\ndefault_loaded = {str(loaded).lower()}\nclaude = {str(claude).lower()}\ncodex = {str(codex).lower()}\n\n")
        self.entries.append({"name": name, "source": f"./plugins/{name}", "category": "Productivity"})
        # JSON is an APM-supported YAML subset.
        (self.project / "apm.yml").write_text(json.dumps({"name": "prateek-local", "version": "1.0.0", "license": "UNLICENSED",
            "marketplace": {"owner": {"name": "Fixture"}, "outputs": {"claude": {}, "codex": {}}, "packages": self.entries}}))
        return path

    def build(self):
        self.command(["make", "-C", str(self.project), "build"])
        return self.project / "build/marketplace"

    def materialize(self, artifact=None, **kwargs):
        return self.tool("materialize-agent-plugins", "--artifact-root", artifact or self.build(), "--plugins-root", self.plugins, **kwargs)


class PackageValidationTests(PackageTestCase):

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
        for cli in ("claude", "codex"):
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
        for name in ("script_lib.sh", "features.tmpl", "agent-marketplace-tree-hash.tmpl",
                     "agent-claude-plugin-settings.json.tmpl", "agent-codex-plugin-config.toml.tmpl",
                     "claude-settings-managed.json.tmpl", "codex-config-managed.toml.tmpl",
                     "cursor-cli-config-managed.json.tmpl"):
            shutil.copy2(ROOT / "home/.chezmoitemplates" / name, templates / name)
        shutil.copy2(ROOT / "home/.chezmoidata/machines.toml", self.policy.parent / "machines.toml")
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
