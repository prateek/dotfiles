import json
import os
import sys

from tests.support.python import ROOT, RepoTestCase


class AcpxRoutingTests(RepoTestCase):
    def setUp(self):
        super().setUp()
        self.policy = self.work / "routing.json"
        self.catalogs = self.work / "catalogs.json"

    def resolve(self, catalogs, *, machine="personal", data=None):
        self.policy.write_bytes(self.render("home/dot_config/acpx/routing.json.tmpl", machine, data=data))
        self.catalogs.write_text(json.dumps(catalogs))
        result = self.command([
            sys.executable, str(ROOT / "scripts/acpx/reconcile"), "resolve",
            "--policy", str(self.policy), "--catalogs", str(self.catalogs),
        ])
        return json.loads(result.stdout)

    def test_declared_route_without_a_selected_harness_agent_fails_the_render(self):
        for machine, agents, route, harness in (
            ("work", ["claude"], "cursor", "cursor"),
            ("personal", ["claude", "codex"], "local", "omp"),
        ):
            with self.subTest(machine=machine):
                result = self.command([
                    "chezmoi", "--source", str(ROOT), "--config", str(self.config),
                    "--destination", str(self.home), "--override-data",
                    json.dumps({"machine_type": machine, "chezmoi": {"os": "darwin"},
                                "machines_local": {"agent_clis": agents}}),
                    "execute-template", "--file", str(ROOT / "home/dot_config/acpx/routing.json.tmpl"),
                ], expected_status=1)
                self.assertIn(f'route "{route}" needs harness "{harness}"'.encode(), result.stderr)
        # Every shipped machine type declares only routes its agents provide.
        for machine in ("personal", "homelab", "work", "devbox", "ci"):
            with self.subTest(machine=machine):
                self.render("home/dot_config/acpx/routing.json.tmpl", machine)

    def test_native_gpt_profiles_set_exact_model_effort_and_service_tier(self):
        report = self.resolve({
            "codex": {"models": [
                {"id": "gpt-6.1-sol", "efforts": ["low", "medium", "high", "xhigh", "max"]},
                {"id": "gpt-6-astra", "efforts": ["medium", "high", "xhigh"]},
                {"id": "gpt-6-sol", "efforts": ["low", "medium", "high", "xhigh"]},
            ]},
            "openrouter": {"models": [
                {"id": "openai/gpt-6.1-sol", "efforts": ["medium", "high", "xhigh"], "provider": "openrouter"},
            ]},
        })
        for alias, model, effort in (("agpt", "gpt-6.1-sol", "medium"),
                                     ("agptx", "gpt-6-astra", "medium"),
                                     ("pgpt", "gpt-6-sol", "medium")):
            selected = report["shortcuts"][alias]
            self.assertEqual((selected["route"], selected["model"], selected["effort"]),
                             ("codex", model, effort))
            settings = next(arg for arg in selected["argv"] if arg.startswith("CODEX_CONFIG="))
            self.assertEqual(json.loads(settings.split("=", 1)[1]), {
                "model": model, "model_reasoning_effort": effort, "service_tier": "default",
            })
            self.assertNotIn("-c", selected["argv"])

    def test_explicit_profiles_exclude_newer_generations_fast_and_wrong_tiers(self):
        report = self.resolve({"codex": {"models": [
            {"id": model, "efforts": ["low", "medium", "high", "xhigh"]}
            for model in ("gpt-6.1-sol", "gpt-6-sol", "gpt-6-astra", "gpt-7-astra",
                          "gpt-6.1-luna", "gpt-6-astra-fast", "gpt-6.1-sol-2026-09-29")
        ]}})
        selected = report["shortcuts"]
        for alias, model, effort in (
            ("agpt", "gpt-6.1-sol-2026-09-29", "medium"),
            ("agptw", "gpt-6.1-sol-2026-09-29", "medium"),
            ("agptx", "gpt-6-astra", "medium"),
            ("agptxx", "gpt-6-astra", "high"),
            ("agptxxx", "gpt-6-astra", "xhigh"),
            ("pgpt", "gpt-6-sol", "medium"),
            ("pgptx", "gpt-6-sol", "high"),
        ):
            self.assertEqual((selected[alias]["model"], selected[alias]["effort"]), (model, effort))
        self.assertIn("does not support max effort", selected["pgptxxx"]["error"])
        rejected = self.command([sys.executable, str(ROOT / "scripts/acpx/reconcile"),
                                 *selected["pgptxxx"]["argv"][1:]], expected_status=2)
        self.assertIn(b"pgptxxx", rejected.stderr)

    def test_preferred_harness_does_not_borrow_pinned_model_from_another_catalog(self):
        report = self.resolve({
            "claude": {"models": [{"id": "claude-opus-5.5[1m]", "efforts": ["medium", "high"]}]},
            "openrouter": {"models": [{"id": "anthropic/claude-opus-5", "provider": "openrouter", "efforts": ["medium"]}]},
        })
        self.assertEqual(report["shortcuts"]["aopus"]["model"], "claude-opus-5.5[1m]")
        self.assertIn("claude does not advertise claude-opus-5", report["shortcuts"]["popus"]["error"])
        self.assertIn("CLAUDE_CODE_DISABLE_FAST_MODE=1", report["shortcuts"]["aopus"]["argv"])
        self.assertIn("ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-5.5[1m]", report["shortcuts"]["aopus"]["argv"])

    def test_claude_profiles_accept_provider_generation_spelling_and_pin_aliases(self):
        report = self.resolve({"claude": {"models": [
            {"id": model, "efforts": ["medium", "high", "xhigh", "max"]}
            for model in ("claude-opus-5-5@20260923", "claude-opus-5", "claude-fable-5-1", "claude-fable-5")
        ]}})
        for alias, model, effort in (
            ("aopus", "claude-opus-5-5@20260923", "medium"),
            ("aopusx", "claude-opus-5-5@20260923", "high"),
            ("popus", "claude-opus-5", "medium"),
            ("afable", "claude-fable-5-1", "medium"),
            ("afablex", "claude-fable-5-1", "high"),
            ("pfable", "claude-fable-5", "medium"),
        ):
            selected = report["shortcuts"][alias]
            self.assertEqual((selected["model"], selected["effort"]), (model, effort))
            self.assertIn("ANTHROPIC_MODEL=" + model, selected["argv"])
            self.assertIn("CLAUDE_CODE_EFFORT_LEVEL=" + effort, selected["argv"])

    def test_previous_gemini_is_numeric_below_the_pinned_generation(self):
        catalogs = {"openrouter": {"models": [
            {"id": "google/" + model, "provider": "openrouter", "efforts": ["high"]}
            for model in ("gemini-3.8-flash", "gemini-3.7-flash", "gemini-3.6-pro",
                          "gemini-3.10-pro", "gemini-3.7-pro", "gemini-3.7-flash-lite")
        ]}}
        report = self.resolve(catalogs)
        self.assertEqual(report["shortcuts"]["agemini"]["model"], "google/gemini-3.8-flash")
        self.assertEqual(report["shortcuts"]["pgemini"]["model"], "google/gemini-3.7-pro")
        catalogs["openrouter"]["models"] = catalogs["openrouter"]["models"][:1]
        self.assertIn("no preceding gemini generation", self.resolve(catalogs)["shortcuts"]["pgemini"]["error"])

    def test_local_preference_preserves_family_and_machine_declarations_exclude_cursor(self):
        catalogs = {
            "local": {"models": [{"id": "qwen3", "provider": "ollama", "efforts": ["medium", "high"]}]},
            "codex": {"models": [{"id": "gpt-6.1-sol", "efforts": ["medium", "high"]}]},
            "cursor": {"models": [{"id": "gpt-6-astra", "efforts": ["medium", "high"], "variants": {"high": "gpt-6-astra-high"}}]},
        }
        report = self.resolve(catalogs)
        self.assertEqual(report["shortcuts"]["agpt"]["route"], "codex")
        self.assertNotIn("cursor", report["catalogs"])
        catalogs["local"]["models"] = [{"id": "gpt-6.1-sol", "provider": "ollama", "efforts": ["medium", "high"]}]
        self.assertEqual(self.resolve(catalogs)["shortcuts"]["agpt"]["route"], "local")

    def test_work_routes_native_claude_through_vertex_and_gpt_through_cursor(self):
        catalogs = {
            "claude-vertex": {"models": [{"id": "claude-fable-5-1", "efforts": ["medium", "high", "max"]}]},
            "cursor": {"models": [{"id": "gpt-6.1-sol", "efforts": ["medium", "high"], "variants": {"medium": "gpt-6.1-sol-medium", "high": "gpt-6.1-sol-high"}}]},
            "codex": {"models": [{"id": "gpt-6-astra", "efforts": ["medium", "high"]}]},
        }
        plugins = self.home / ".agents/plugins"
        plugins.mkdir(parents=True)
        report = self.resolve(catalogs, machine="work")
        claude = report["shortcuts"]["afable"]
        self.assertEqual(claude["route"], "claude-vertex")
        self.assertIn("CLAUDE_CODE_USE_VERTEX=1", claude["argv"])
        self.assertIn("ANTHROPIC_MODEL=claude-fable-5-1", claude["argv"])
        self.assertIn("CLAUDE_CODE_EFFORT_LEVEL=medium", claude["argv"])
        gpt = report["shortcuts"]["agpt"]
        self.assertEqual(gpt["route"], "cursor")
        self.assertEqual(gpt["argv"], ["cursor-agent", "--model", "gpt-6.1-sol-medium", "--add-dir", str(plugins), "acp"])
        marketplace = self.home / ".claude/plugins/marketplaces"
        marketplace.mkdir(parents=True)
        argv = self.resolve(catalogs, machine="work")["shortcuts"]["agpt"]["argv"]
        self.assertEqual(argv[-3:], ["--add-dir", str(marketplace), "acp"])
        plugins.rmdir()
        argv = self.resolve(catalogs, machine="work")["shortcuts"]["agpt"]["argv"]
        self.assertNotIn(str(plugins), argv)

    def test_host_family_preference_reorders_only_declared_routes(self):
        catalogs = {
            "codex": {"models": [{"id": "gpt-6-sol", "efforts": ["medium", "high"]}]},
            "openrouter": {"models": [{"id": "openai/gpt-6.1-sol", "provider": "openrouter", "efforts": ["medium", "high"]}]},
        }
        report = self.resolve(catalogs, data={"machines_local": {"acpx_order_gpt": ["openrouter", "codex"]}})
        self.assertEqual(report["shortcuts"]["agpt"]["route"], "openrouter")
        self.assertEqual(report["shortcuts"]["agpt"]["argv"], [
            "omp", "acp", "--provider", "openrouter", "--model", "openai/gpt-6.1-sol", "--thinking", "medium",
        ])
        policy = json.loads(self.policy.read_text())
        policy["preferences"]["gpt"] = ["cursor"]
        self.policy.write_text(json.dumps(policy))
        result = self.run_cli("resolve", expected_status=2)
        self.assertIn(b"preference must contain unique declared routes", result.stderr)

    def run_cli(self, action, *, expected_status=0):
        return self.command([
            sys.executable, str(ROOT / "scripts/acpx/reconcile"), action,
            "--policy", str(self.policy), "--catalogs", str(self.catalogs),
            "--config", str(self.home / ".acpx/config.json"), "--report", str(self.home / ".acpx/routing.json"),
        ], expected_status=expected_status)

    def test_regeneration_preserves_custom_state_retires_owned_aliases_and_is_idempotent(self):
        self.resolve({"codex": {"models": [{"id": "gpt-6.1-sol", "efforts": ["medium", "high"]}]}})
        directory = self.home / ".acpx"
        directory.mkdir()
        config = directory / "config.json"
        original = {"format": "json", "auth": {"test": "fixture-secret"}, "agents": {
            "custom": {"argv": ["custom-agent"]}, "agpt": {"command": "codex-acp", "args": ["-c", "model_reasoning_effort=high"]},
        }}
        config.write_text(json.dumps(original))
        self.run_cli("refresh")
        applied = json.loads(config.read_text())
        self.assertEqual(applied["format"], "json")
        self.assertEqual(applied["auth"], original["auth"])
        self.assertEqual(applied["agents"]["custom"], original["agents"]["custom"])
        self.assertIn("CODEX_CONFIG=", " ".join(applied["agents"]["agpt"]["argv"]))
        before = config.stat().st_mtime_ns
        self.run_cli("refresh")
        self.assertEqual(config.stat().st_mtime_ns, before)
        self.assertEqual(config.stat().st_mode & 0o777, 0o600)
        self.resolve({}, machine="ci")
        self.run_cli("refresh")
        self.assertEqual(json.loads(config.read_text())["agents"], {"custom": original["agents"]["custom"]})

    def test_unmanaged_name_collision_and_invalid_config_leave_files_untouched(self):
        self.resolve({})
        config = self.home / ".acpx/config.json"
        config.parent.mkdir()
        initial = '{"agents":{"pgpt":{"argv":["my-agent"]}}}'
        config.write_text(initial)
        result = self.run_cli("refresh", expected_status=2)
        self.assertIn(b"shortcut conflicts with unmanaged agents: pgpt", result.stderr)
        self.assertEqual(config.read_text(), initial)
        self.assertFalse((config.parent / "routing.json").exists())
        config.write_text("broken json")
        self.run_cli("refresh", expected_status=2)
        self.assertEqual(config.read_text(), "broken json")

    def test_broken_declared_routes_are_reported_and_unavailable_requests_fail_closed(self):
        report = self.resolve({"codex": {"error": "missing dependencies: codex-acp"}})
        self.assertEqual(report["problems"]["codex"], "missing dependencies: codex-acp")
        self.assertIn("no declared, usable route", report["shortcuts"]["agpt"]["error"])
        self.assertEqual(report["shortcuts"]["agpt"]["argv"][1], "reject")

    def test_refresh_summarizes_shortcuts_and_groups_route_problems(self):
        self.resolve({
            "codex": {"models": [{"id": "gpt-6-sol", "efforts": ["medium", "high"]}]},
            "local": {"error": "no accessible models"},
            "cerebras": {"error": "no accessible models"},
        })
        result = self.run_cli("refresh")
        shortcuts = json.loads((self.home / ".acpx/routing.json").read_text())["shortcuts"]
        resolved = sum("error" not in selected for selected in shortcuts.values())
        self.assertEqual(result.stdout.decode().splitlines(), [
            f"acpx: {resolved}/{len(shortcuts)} shortcuts resolved; details: acpx-routing show",
        ])
        self.assertIn(b"acpx: local, cerebras: no accessible models\n", result.stderr)

    def test_show_validates_resolved_unavailable_and_unknown_shortcuts(self):
        self.resolve({"codex": {"models": [{"id": "gpt-6.1-sol", "efforts": ["medium", "high"]}]}})
        self.run_cli("refresh")
        argv = [sys.executable, str(ROOT / "scripts/acpx/reconcile"), "show",
                "--report", str(self.home / ".acpx/routing.json")]
        result = self.command([*argv, "agpt"])
        self.assertEqual(json.loads(result.stdout)["model"], "gpt-6.1-sol")
        result = self.command([*argv, "agptx"], expected_status=2)
        self.assertIn(b"does not advertise gpt-6-astra", result.stderr)
        result = self.command([*argv, "agptxxxx"], expected_status=2)
        self.assertIn(b"unknown shortcut", result.stderr)

    def test_openai_route_accepts_the_chatgpt_subscription_login(self):
        report = self.resolve({
            "codex": {"error": "missing dependencies: codex-acp"},
            "openai": {"models": [{"id": "gpt-6.1-sol", "provider": "openai-codex", "efforts": ["medium", "high"]}]},
        })
        self.assertEqual(report["shortcuts"]["agpt"]["route"], "openai")
        self.assertEqual(report["shortcuts"]["agpt"]["argv"], [
            "omp", "acp", "--provider", "openai-codex", "--model", "gpt-6.1-sol", "--thinking", "medium",
        ])

    def test_missing_target_and_effort_do_not_substitute_another_model_or_route(self):
        catalogs = {
            "codex": {"models": [{"id": "gpt-6-sol", "efforts": ["medium", "high"]}]},
            "openrouter": {"models": [{"id": "openai/gpt-6.1-sol", "provider": "openrouter", "efforts": ["medium"]}]},
        }
        self.assertIn("codex does not advertise gpt-6.1-sol", self.resolve(catalogs)["shortcuts"]["agpt"]["error"])
        catalogs["codex"]["models"] = [{"id": "gpt-6.1-sol", "efforts": ["low", "high"]}]
        self.assertIn("does not support medium effort", self.resolve(catalogs)["shortcuts"]["agpt"]["error"])

    def test_invalid_profiles_fail_before_publication(self):
        self.resolve({})
        original = json.loads(self.policy.read_text())
        for changes, error in (
            ({"family": "unknown"}, "unknown model family"),
            ({"effort": "unknown"}, "unknown effort"),
            ({"model": "gpt-6.1-sol-fast"}, "unrecognized model target"),
            ({"previous_of": "agpt"}, "require exactly one"),
        ):
            with self.subTest(changes=changes):
                policy = json.loads(json.dumps(original))
                policy["models"]["profiles"]["agpt"].update(changes)
                self.policy.write_text(json.dumps(policy))
                result = self.run_cli("refresh", expected_status=2)
                self.assertIn(error.encode(), result.stderr)
                self.assertFalse((self.home / ".acpx/config.json").exists())
                self.assertFalse((self.home / ".acpx/routing.json").exists())

    def test_configuration_does_not_invent_effort_for_nonreasoning_models(self):
        report = self.resolve({"codex": {"models": [{"id": "gpt-6.1-sol", "efforts": []}]}})
        self.assertIn("does not support medium effort", report["shortcuts"]["agpt"]["error"])

    def test_live_discovery_uses_acp_catalog_and_snapshots_omp_once_without_prompting(self):
        self.policy.write_bytes(self.render("home/dot_config/acpx/routing.json.tmpl", data={
            "machines_local": {"acpx_routes": ["local", "codex", "openai", "openrouter"]},
        }))
        bin_dir = self.work / "bin"
        bin_dir.mkdir()
        codex = bin_dir / "codex-acp"
        codex.write_text(f"#!{sys.executable}\n" + '''
import json, os, sys
assert 'CODEX_CONFIG' not in os.environ
for line in sys.stdin:
    req = json.loads(line)
    with open(os.environ['CALLS'], 'a') as f: f.write(req['method'] + '\\n')
    assert req['method'] in ('initialize', 'session/new')
    result = {} if req['method'] == 'initialize' else {
        'models': {'availableModels': [
            {'modelId': 'gpt-6.1-sol[medium]'}, {'modelId': 'gpt-6.1-sol[high]'}
        ], 'currentModelId': 'gpt-6-astra[high]'},
        'configOptions': [{'id': 'model', 'options': [{'value': 'gpt-6-astra'}]}],
    }
    print(json.dumps({'jsonrpc': '2.0', 'id': req['id'], 'result': result}), flush=True)
''')
        omp = bin_dir / "omp"
        omp.write_text(f"#!{sys.executable}\n" + '''
import json, os, sys
assert sys.argv[1:] == ['models', 'refresh', '--json']
with open(os.environ['CALLS'], 'a') as f: f.write('omp catalog\\n')
print(json.dumps({'models': [
    {'provider': 'openrouter', 'id': 'openai/gpt-6-astra', 'thinking': ['high', 'max']},
    {'provider': 'ollama', 'id': 'qwen3', 'thinking': ['high']},
]}))
''')
        for path in (codex, omp):
            path.chmod(0o700)
        calls = self.work / "calls"
        result = self.command([
            sys.executable, str(ROOT / "scripts/acpx/reconcile"), "resolve", "--policy", str(self.policy),
        ], env={"PATH": str(bin_dir) + os.pathsep + self.env["PATH"], "CALLS": str(calls), "CODEX_CONFIG": "bad inherited config"})
        report = json.loads(result.stdout)
        self.assertEqual(report["shortcuts"]["agpt"]["model"], "gpt-6.1-sol")
        self.assertIn("does not advertise gpt-6-astra", report["shortcuts"]["agptx"]["error"])
        self.assertIn("no accessible models", report["problems"]["openai"])
        self.assertEqual(calls.read_text().splitlines(), ["omp catalog", "initialize", "session/new"])

    def test_cursor_catalog_ignores_fast_and_unqualified_effort_and_refreshes_versions(self):
        self.policy.write_bytes(self.render("home/dot_config/acpx/routing.json.tmpl", "work", data={
            "machines_local": {"acpx_routes": ["cursor"]},
        }))
        bin_dir = self.work / "bin"
        bin_dir.mkdir()
        cursor = bin_dir / "cursor-agent"
        cursor.write_text(f"#!{sys.executable}\n" + '''
import sys
assert sys.argv[1:] == ['--list-models']
print("""Available models
gpt-7-astra-high-fast - Fast
gpt-6.1-sol-medium - Workhorse
gpt-6-astra-medium - Stronger
gpt-6-astra-high - More reasoning
gpt-6-astra-max - More reasoning
gpt-6-sol-medium - Previous
claude-opus-5-5-thinking-medium - Opus
claude-opus-5-thinking-medium - Previous Opus
gemini-3.1-pro - No advertised effort
gemini-3.8-flash[effort=high,fast=false] - Gemini
gemini-5.0-pro[effort=high,fast=true] - Fast Gemini
Tip: choose a model""")
''')
        cursor.chmod(0o700)
        result = self.command([sys.executable, str(ROOT / "scripts/acpx/reconcile"), "resolve",
                               "--policy", str(self.policy)], env={"PATH": str(bin_dir) + os.pathsep + self.env["PATH"]})
        report = json.loads(result.stdout)
        for alias, model in (("agpt", "gpt-6.1-sol"), ("pgpt", "gpt-6-sol"),
                             ("aopus", "claude-opus-5-5"), ("popus", "claude-opus-5"),
                             ("agemini", "gemini-3.8-flash")):
            self.assertEqual(report["shortcuts"][alias]["model"], model)
        self.assertEqual(report["shortcuts"]["agptx"]["effort"], "medium")
        self.assertIn("no preceding gemini", report["shortcuts"]["pgemini"]["error"])

    def test_missing_actual_adapter_is_reported_even_when_harness_is_declared(self):
        self.policy.write_bytes(self.render("home/dot_config/acpx/routing.json.tmpl", data={
            "machines_local": {"acpx_routes": ["codex"]},
        }))
        policy = json.loads(self.policy.read_text())
        policy["routes"]["codex"]["requires"] = [str(self.work / "absent-codex-acp")]
        self.policy.write_text(json.dumps(policy))
        result = self.command([sys.executable, str(ROOT / "scripts/acpx/reconcile"), "resolve", "--policy", str(self.policy)])
        report = json.loads(result.stdout)
        self.assertIn("missing dependencies", report["problems"]["codex"])
        self.assertIn("error", report["shortcuts"]["agpt"])

    def test_publishing_refuses_symlinks_before_changing_either_file(self):
        self.resolve({})
        config = self.home / ".acpx/config.json"
        config.parent.mkdir()
        target = self.work / "original.json"
        target.write_text('{"agents":{}}')
        config.symlink_to(target)
        result = self.run_cli("refresh", expected_status=2)
        self.assertIn(b"refusing to replace symlink", result.stderr)
        self.assertEqual(target.read_text(), '{"agents":{}}')
        self.assertFalse((config.parent / "routing.json").exists())
