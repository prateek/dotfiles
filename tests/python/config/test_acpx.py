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

    def test_native_gpt_effort_and_model_are_explicit_and_harness_precedes_generation(self):
        report = self.resolve({
            "codex": {"models": [
                {"id": "gpt-5.6-sol", "efforts": ["low", "high", "xhigh", "max"]},
                {"id": "gpt-5.5", "efforts": ["low", "high", "xhigh"]},
            ]},
            "openrouter": {"models": [
                {"id": "openai/gpt-6-astra", "efforts": ["high", "xhigh"], "provider": "openrouter"},
            ]},
        })
        for alias, model, effort in (("agpt", "gpt-5.6-sol", "high"),
                                     ("agptx", "gpt-5.6-sol", "xhigh"),
                                     ("pgpt", "gpt-5.5", "high")):
            selected = report["shortcuts"][alias]
            self.assertEqual((selected["route"], selected["model"], selected["effort"]),
                             ("codex", model, effort))
            settings = next(arg for arg in selected["argv"] if arg.startswith("CODEX_CONFIG="))
            self.assertEqual(json.loads(settings.split("=", 1)[1]), {
                "model": model, "model_reasoning_effort": effort, "service_tier": "default",
            })
            self.assertNotIn("-c", selected["argv"])

    def test_generation_order_tiers_writing_and_effort_overflow(self):
        report = self.resolve({"codex": {"models": [
            {"id": model, "efforts": ["low", "high", "max"]}
            for model in ("gpt-5.9-sol", "gpt-5.9-luna", "gpt-5.10-sol", "gpt-5.8", "gpt-6-astra-fast")
        ]}})
        selected = report["shortcuts"]
        self.assertEqual(selected["agpt"]["model"], "gpt-5.10-sol")
        self.assertEqual(selected["pgpt"]["model"], "gpt-5.9-sol")
        self.assertEqual((selected["agptw"]["model"], selected["agptw"]["effort"]), ("gpt-5.9-luna", "high"))
        self.assertEqual(selected["agptx"]["effort"], "max")
        self.assertIn("no effort 2 step(s) above high", selected["agptxx"]["error"])
        rejected = self.command([sys.executable, str(ROOT / "scripts/acpx/reconcile"),
                                 *selected["agptxx"]["argv"][1:]], expected_status=2)
        self.assertIn(b"agptxx", rejected.stderr)

    def test_preferred_harness_does_not_borrow_previous_generation_from_another_catalog(self):
        report = self.resolve({
            "claude": {"models": [{"id": "claude-opus-5[1m]", "efforts": ["high", "xhigh"]}]},
            "openrouter": {"models": [{"id": "anthropic/claude-opus-4.6", "provider": "openrouter", "efforts": ["high"]}]},
        })
        self.assertEqual(report["shortcuts"]["aopus"]["model"], "claude-opus-5[1m]")
        self.assertIn("claude has no preceding opus generation", report["shortcuts"]["popus"]["error"])
        self.assertIn("CLAUDE_CODE_DISABLE_FAST_MODE=1", report["shortcuts"]["aopus"]["argv"])
        self.assertIn("ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-5[1m]", report["shortcuts"]["aopus"]["argv"])

    def test_local_preference_preserves_family_and_machine_declarations_exclude_cursor(self):
        catalogs = {
            "local": {"models": [{"id": "qwen3", "provider": "ollama", "efforts": ["high"]}]},
            "codex": {"models": [{"id": "gpt-5.6-sol", "efforts": ["high"]}]},
            "cursor": {"models": [{"id": "gpt-6-astra", "efforts": ["high"], "variants": {"high": "gpt-6-astra-high"}}]},
        }
        report = self.resolve(catalogs)
        self.assertEqual(report["shortcuts"]["agpt"]["route"], "codex")
        self.assertNotIn("cursor", report["catalogs"])
        catalogs["local"]["models"] = [{"id": "gpt-5.5", "provider": "ollama", "efforts": ["high"]}]
        self.assertEqual(self.resolve(catalogs)["shortcuts"]["agpt"]["route"], "local")

    def test_work_routes_native_claude_through_vertex_and_gpt_through_cursor(self):
        catalogs = {
            "claude-vertex": {"models": [{"id": "claude-fable-5-1", "efforts": ["high", "max"]}]},
            "cursor": {"models": [{"id": "gpt-5.6-sol", "efforts": ["high"], "variants": {"high": "gpt-5.6-sol-high"}}]},
            "codex": {"models": [{"id": "gpt-6-astra", "efforts": ["high"]}]},
        }
        plugins = self.home / ".agents/plugins"
        plugins.mkdir(parents=True)
        report = self.resolve(catalogs, machine="work")
        claude = report["shortcuts"]["afable"]
        self.assertEqual(claude["route"], "claude-vertex")
        self.assertIn("CLAUDE_CODE_USE_VERTEX=1", claude["argv"])
        self.assertIn("ANTHROPIC_MODEL=claude-fable-5-1", claude["argv"])
        self.assertIn("CLAUDE_CODE_EFFORT_LEVEL=high", claude["argv"])
        gpt = report["shortcuts"]["agpt"]
        self.assertEqual(gpt["route"], "cursor")
        self.assertEqual(gpt["argv"], ["cursor-agent", "--model", "gpt-5.6-sol-high", "--add-dir", str(plugins), "acp"])
        marketplace = self.home / ".claude/plugins/marketplaces"
        marketplace.mkdir(parents=True)
        argv = self.resolve(catalogs, machine="work")["shortcuts"]["agpt"]["argv"]
        self.assertEqual(argv[-3:], ["--add-dir", str(marketplace), "acp"])
        plugins.rmdir()
        argv = self.resolve(catalogs, machine="work")["shortcuts"]["agpt"]["argv"]
        self.assertNotIn(str(plugins), argv)

    def test_host_family_preference_reorders_only_declared_routes(self):
        catalogs = {
            "codex": {"models": [{"id": "gpt-5.5", "efforts": ["high"]}]},
            "openrouter": {"models": [{"id": "openai/gpt-6-astra", "provider": "openrouter", "efforts": ["high"]}]},
        }
        report = self.resolve(catalogs, data={"machines_local": {"acpx_order_gpt": ["openrouter", "codex"]}})
        self.assertEqual(report["shortcuts"]["agpt"]["route"], "openrouter")
        self.assertEqual(report["shortcuts"]["agpt"]["argv"], [
            "omp", "acp", "--provider", "openrouter", "--model", "openai/gpt-6-astra", "--thinking", "high",
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
        self.resolve({"codex": {"models": [{"id": "gpt-5.5", "efforts": ["high"]}]}})
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
            "codex": {"models": [{"id": "gpt-5.5", "efforts": ["high"]}]},
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
        self.resolve({"codex": {"models": [{"id": "gpt-5.5", "efforts": ["high"]}]}})
        self.run_cli("refresh")
        argv = [sys.executable, str(ROOT / "scripts/acpx/reconcile"), "show",
                "--report", str(self.home / ".acpx/routing.json")]
        result = self.command([*argv, "agpt"])
        self.assertEqual(json.loads(result.stdout)["model"], "gpt-5.5")
        result = self.command([*argv, "agptx"], expected_status=2)
        self.assertIn(b"no effort 1 step(s) above high", result.stderr)
        result = self.command([*argv, "agptxxxx"], expected_status=2)
        self.assertIn(b"unknown shortcut", result.stderr)

    def test_openai_route_accepts_the_chatgpt_subscription_login(self):
        report = self.resolve({
            "codex": {"error": "missing dependencies: codex-acp"},
            "openai": {"models": [{"id": "gpt-5.5", "provider": "openai-codex", "efforts": ["high"]}]},
        })
        self.assertEqual(report["shortcuts"]["agpt"]["route"], "openai")
        self.assertEqual(report["shortcuts"]["agpt"]["argv"], [
            "omp", "acp", "--provider", "openai-codex", "--model", "gpt-5.5", "--thinking", "high",
        ])

    def test_configuration_does_not_invent_effort_for_nonreasoning_models(self):
        report = self.resolve({"codex": {"models": [{"id": "gpt-5.6-sol", "efforts": []}]}})
        self.assertIn("does not support high effort", report["shortcuts"]["agpt"]["error"])

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
            {'modelId': 'gpt-5.6-sol[high]'}, {'modelId': 'gpt-5.6-sol[xhigh]'}
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
        self.assertEqual(report["shortcuts"]["agpt"]["model"], "gpt-5.6-sol")
        self.assertEqual(report["shortcuts"]["agptx"]["effort"], "xhigh")
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
gpt-6-astra-high - Latest
gpt-6-astra-max - More reasoning
gpt-5.6-sol-high - Previous
claude-opus-5-thinking-high - Opus
claude-opus-4-6-thinking-high - Previous Opus
gemini-3.1-pro - No advertised effort
gemini-4.0-pro[effort=high,fast=false] - Gemini
gemini-5.0-pro[effort=high,fast=true] - Fast Gemini
Tip: choose a model""")
''')
        cursor.chmod(0o700)
        result = self.command([sys.executable, str(ROOT / "scripts/acpx/reconcile"), "resolve",
                               "--policy", str(self.policy)], env={"PATH": str(bin_dir) + os.pathsep + self.env["PATH"]})
        report = json.loads(result.stdout)
        for alias, model in (("agpt", "gpt-6-astra"), ("pgpt", "gpt-5.6-sol"),
                             ("aopus", "claude-opus-5"), ("popus", "claude-opus-4-6"),
                             ("agemini", "gemini-4.0-pro")):
            self.assertEqual(report["shortcuts"][alias]["model"], model)
        self.assertEqual(report["shortcuts"]["agptx"]["effort"], "max")
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
