import json
import os
from pathlib import Path
import sys
import time

from tests.support.python import ROOT, RepoTestCase


class AcpxRoutingTests(RepoTestCase):
    def setUp(self):
        super().setUp()
        self.policy = self.home / ".config/acpx/routing.json"
        self.policy.parent.mkdir(parents=True)
        self.catalogs = self.work / "catalogs.json"
        self.snapshot = self.home / ".acpx/catalogs.json"
        self.selection = self.work / "selection.json"
        self.report = self.home / ".acpx/routing.json"
        self.config_path = self.home / ".acpx/config.json"
        self.render_policy()
        auth_dir = self.home / ".codex"
        auth_dir.mkdir()
        (auth_dir / "auth.json").write_text('{"auth_mode":"chatgpt","tokens":{"fixture":"token"}}')
        self.env["CODEX_HOME"] = str(auth_dir)

    def render_policy(self, machine="personal", agents=None):
        data = {"machines_local": {"agent_clis": agents}} if agents is not None else None
        policy = json.loads(self.render("home/dot_config/acpx/routing.json.tmpl", machine, data=data))
        policy["launcher"] = str(ROOT / "scripts/acpx/reconcile")
        self.policy.write_text(json.dumps(policy))
        return policy

    def cli(self, action, *args, expected_status=0, env=None, cwd=ROOT):
        return self.command([
            sys.executable, str(ROOT / "scripts/acpx/reconcile"), action, *args,
            "--policy", str(self.policy), "--snapshot", str(self.snapshot),
            "--config", str(self.config_path), "--report", str(self.report),
        ], expected_status=expected_status, env=env, cwd=cwd)

    def refresh(self, catalogs, *flags):
        self.catalogs.write_text(json.dumps(catalogs))
        return json.loads(self.cli("refresh", "--catalogs", str(self.catalogs), *flags).stdout)

    def decide(self, snapshot, pairs, **extra):
        families = {}
        for family, pair in pairs.items():
            row = {"reason": "Producer describes the frontier and its lower workhorse tier.",
                   "sources": ["catalog descriptions"]}
            for slot, target in zip(("current", "previous"), pair):
                if target is None:
                    row[slot] = None
                    row[slot + "_error"] = "No distinct lower capability model is available"
                else:
                    route, model = target
                    row[slot] = next(key for key, candidate in snapshot["candidates"].items()
                                     if candidate["route"] == route and candidate["id"] == model)
            families[family] = row
        decision = {"snapshot_id": snapshot["snapshot_id"], "families": families, **extra}
        self.selection.write_text(json.dumps(decision))
        return decision

    def commit(self, *flags, expected_status=0):
        return self.cli("commit", "--selection", str(self.selection), *flags, expected_status=expected_status)

    def gpt_catalog(self):
        return {"codex": {"models": [
            {"id": "gpt-6.1-sol", "description": "Latest workhorse", "default_effort": "low",
             "efforts": ["low", "medium", "high", "xhigh", "max"]},
            {"id": "gpt-6-astra", "description": "Frontier intelligence", "default_effort": "medium",
             "efforts": ["low", "medium", "high", "xhigh", "max"]},
        ]}}

    def select_gpt(self):
        snap = self.refresh(self.gpt_catalog())
        self.decide(snap, {"gpt": (("codex", "gpt-6-astra"), ("codex", "gpt-6.1-sol"))})
        self.commit()
        return json.loads(self.report.read_text())

    def test_routes_derive_from_agent_clis_without_a_second_allowlist(self):
        policy = self.render_policy(agents=["cursor-agent"])
        self.assertEqual(policy["declared"], ["cursor"])
        policy = self.render_policy("work")
        self.assertIn("claude-vertex", policy["declared"])
        self.assertIn("pi", policy["declared"])
        self.assertNotIn("codex", policy["declared"])
        self.assertNotIn("claude", policy["declared"])
        for machine in ("personal", "homelab", "work", "devbox", "ci"):
            self.render_policy(machine)

    def test_agent_selects_capability_independent_of_generation_and_suffix_only_changes_thinking(self):
        report = self.select_gpt()["shortcuts"]
        for alias, model, effort, effective in (
            ("agpt", "gpt-6-astra", "default", "medium"),
            ("agptx", "gpt-6-astra", "high", "high"),
            ("agptxx", "gpt-6-astra", "xhigh", "xhigh"),
            ("pgpt", "gpt-6.1-sol", "default", "low"),
            ("pgptx", "gpt-6.1-sol", "medium", "medium"),
            ("agptw", "gpt-6.1-sol", "default", "low"),
        ):
            selected = report[alias]
            self.assertEqual((selected["model"], selected["effort"], selected["effective_effort"]),
                             (model, effort, effective))
            config = json.loads(next(arg.split("=", 1)[1] for arg in selected["argv"]
                                     if arg.startswith("CODEX_CONFIG=")))
            self.assertEqual(config["model"], model)
            self.assertEqual(config["model_provider"], "openai")
            self.assertEqual(config["service_tier"], "default")
            if effort == "default":
                self.assertEqual(config["model_reasoning_effort"], effective)
            else:
                self.assertEqual(config["model_reasoning_effort"], effort)

    def test_new_model_names_need_no_policy_edit_and_catalog_refresh_does_not_choose(self):
        snap = self.refresh({"codex": {"models": [
            {"id": "gpt-9-newtier", "efforts": [], "description": "New frontier"},
        ]}})
        self.assertFalse(self.report.exists())
        self.decide(snap, {"gpt": (("codex", "gpt-9-newtier"), None)})
        self.commit()
        self.assertEqual(json.loads(self.cli("show", "agpt").stdout)["model"], "gpt-9-newtier")
        self.assertIn(b"No distinct lower", self.cli("show", "pgpt", expected_status=2).stderr)
        self.assertIn(b"unknown shortcut", self.cli("show", "agptxxxx", expected_status=2).stderr)

    def test_default_unknown_and_excessive_steps_fail_without_changing_model(self):
        snap = self.refresh({"codex": {"models": [{"id": "gpt-6-astra", "efforts": ["medium", "high"]}]}})
        decision = self.decide(snap, {"gpt": (("codex", "gpt-6-astra"), None)})
        self.commit()
        self.assertIn(b"default thinking level is unknown", self.cli("show", "agptx", expected_status=2).stderr)
        decision["families"]["gpt"]["current_default_effort"] = "medium"
        self.selection.write_text(json.dumps(decision))
        self.commit()
        self.assertEqual(json.loads(self.cli("show", "agptx").stdout)["effort"], "high")
        self.assertIn(b"exceeds supported maximum", self.cli("show", "agptxx", expected_status=2).stderr)

    def test_paid_and_undeclared_candidates_are_excluded_unless_explicitly_enabled(self):
        catalogs = self.gpt_catalog() | {
            "openai": {"models": [
                {"id": "gpt-10-astra", "provider": "openai", "efforts": []},
                {"id": "gpt-6-sol", "provider": "openai-codex", "efforts": []},
            ]},
            "openrouter": {"models": [{"id": "openai/gpt-10-astra", "provider": "openrouter", "efforts": []}]},
            "cursor": {"models": [{"id": "gpt-20-astra", "efforts": []}]},
            "local": {"models": [{"id": "qwen3", "provider": "ollama", "efforts": []}]},
        }
        snap = self.refresh(catalogs)
        ids = {row["id"] for row in snap["candidates"].values()}
        self.assertEqual(ids, {"gpt-6-astra", "gpt-6.1-sol", "gpt-6-sol"})
        snap = self.refresh(catalogs, "--allow-paid")
        self.decide(snap, {"gpt": (("openrouter", "openai/gpt-10-astra"), ("codex", "gpt-6-astra"))})
        self.assertIn(b"access mode", self.commit(expected_status=2).stderr)
        self.commit("--allow-paid")
        self.assertIn(b"paid API candidates", self.cli("show", "agpt", expected_status=2).stderr)
        chosen = json.loads(self.cli("show", "agpt", "--allow-paid").stdout)
        self.assertIn("--allow-paid", chosen["acpx_agent"])
        self.assertEqual(chosen["argv"], ["omp", "acp", "--provider", "openrouter", "--model", "openai/gpt-10-astra"])

    def test_invalid_provider_rejected_and_local_family_is_preserved(self):
        self.catalogs.write_text(json.dumps({"openrouter": {"models": [
            {"id": "gpt-6-astra", "provider": "untrusted", "efforts": []},
        ]}}))
        self.assertIn(b"undeclared provider", self.cli("refresh", "--catalogs", str(self.catalogs), expected_status=2).stderr)
        snap = self.refresh({"local": {"models": [
            {"id": "gpt-6-astra", "provider": "ollama", "efforts": []},
            {"id": "qwen3", "provider": "ollama", "efforts": []},
        ]}})
        self.assertEqual([m["id"] for m in snap["candidates"].values()], ["gpt-6-astra"])

    def test_work_defaults_and_claude_alias_pinning_with_cursor_plugin_roots(self):
        self.render_policy("work")
        plugins = self.home / ".agents/plugins"
        plugins.mkdir(parents=True)
        snap = self.refresh({
            "claude-vertex": {"models": [{"id": "claude-fable-5-1@20260923", "efforts": ["medium", "high"]}]},
            "cursor": {"models": [{"id": "gpt-5.6-sol", "efforts": ["low", "high"],
                                    "default_effort": "low", "default_variant": "gpt-5.6-sol",
                                    "variants": {"high": "gpt-5.6-sol-high"}}]},
        })
        self.decide(snap, {"fable": (("claude-vertex", "claude-fable-5-1@20260923"), None),
                           "gpt": (("cursor", "gpt-5.6-sol"), None)})
        self.commit()
        report = json.loads(self.report.read_text())["shortcuts"]
        argv = report["afable"]["argv"]
        self.assertIn("CLAUDE_CODE_USE_VERTEX=1", argv)
        self.assertIn("ANTHROPIC_DEFAULT_FABLE_MODEL=claude-fable-5-1@20260923", argv)
        self.assertIn("CLAUDE_CODE_DISABLE_FAST_MODE=1", argv)
        self.assertNotIn("CLAUDE_CODE_EFFORT_LEVEL=medium", argv)
        self.assertIn("CLAUDE_CODE_EFFORT_LEVEL", argv)
        self.assertEqual(report["agpt"]["argv"], ["cursor-agent", "--model", "gpt-5.6-sol", "--add-dir", str(plugins), "acp"])
        self.assertEqual(report["agptx"]["argv"][2], "gpt-5.6-sol-high")
        plugins.rmdir()
        self.commit()
        self.assertNotIn("--add-dir", json.loads(self.report.read_text())["shortcuts"]["agpt"]["argv"])

    def test_native_only_pi_choices_are_reported_but_cannot_be_executed_as_acp(self):
        self.render_policy(agents=["pi"])
        snap = self.refresh({"pi": {"models": [
            {"id": "gpt-6-astra", "provider": "openai-codex", "access": "included",
             "default_effort": "medium", "efforts": ["medium", "high"]},
            {"id": "gpt-7-astra", "provider": "openrouter", "access": "paid", "efforts": []},
        ]}})
        self.assertEqual(len(snap["candidates"]), 1)
        self.decide(snap, {"gpt": (("pi", "gpt-6-astra"), None)})
        self.commit()
        chosen = json.loads(self.cli("show", "agpt").stdout)
        self.assertTrue(chosen["native_only"])
        self.assertIsNone(chosen["argv"])
        self.assertIn(b"native delegation only", self.cli("run", "agpt", expected_status=2).stderr)

    def test_pi_choice_can_use_same_model_thinking_on_an_included_external_harness(self):
        catalogs = self.gpt_catalog() | {"pi": {"models": [
            {"id": "gpt-6-astra", "provider": "openai-codex", "access": "included",
             "default_effort": "high", "efforts": ["medium", "high", "xhigh"]},
        ]}}
        snap = self.refresh(catalogs)
        self.decide(snap, {"gpt": (("pi", "gpt-6-astra"), ("codex", "gpt-6.1-sol"))})
        self.commit()
        chosen = json.loads(self.cli("show", "agpt").stdout)
        self.assertEqual(chosen["route"], "pi")
        self.assertEqual(chosen["external_route"], "codex")
        self.assertEqual(chosen["effective_effort"], "high")
        self.assertFalse(chosen["native_only"])
        config = json.loads(next(arg.split("=", 1)[1] for arg in chosen["argv"] if arg.startswith("CODEX_CONFIG=")))
        self.assertEqual(config["model_reasoning_effort"], "high")

    def test_selections_require_snapshot_membership_family_evidence_and_distinct_models(self):
        snap = self.refresh(self.gpt_catalog())
        original = self.decide(snap, {"gpt": (("codex", "gpt-6-astra"), ("codex", "gpt-6.1-sol"))})
        for field, value, error in (
            ("current", "invented", "not an eligible catalog candidate"),
            ("previous", original["families"]["gpt"]["current"], "different models"),
            ("sources", [], "evidence sources"),
            ("current_default_effort", "low", "contradicts catalog"),
        ):
            with self.subTest(field=field):
                decision = json.loads(json.dumps(original))
                decision["families"]["gpt"][field] = value
                self.selection.write_text(json.dumps(decision))
                self.assertIn(error.encode(), self.commit(expected_status=2).stderr)
                self.assertFalse(self.report.exists())
        original["snapshot_id"] = "another-refresh"
        self.selection.write_text(json.dumps(original))
        self.assertIn(b"does not match", self.commit(expected_status=2).stderr)

    def test_snapshot_tampering_and_changed_machine_configuration_invalidate_selection(self):
        snap = self.refresh(self.gpt_catalog())
        self.decide(snap, {"gpt": (("codex", "gpt-6-astra"), None)})
        corrupt = json.loads(self.snapshot.read_text())
        corrupt["created_at"] += 1
        self.snapshot.write_text(json.dumps(corrupt))
        self.assertIn(b"digest mismatch", self.commit(expected_status=2).stderr)
        self.snapshot.write_text(json.dumps(snap))
        self.commit()
        policy = json.loads(self.policy.read_text())
        policy["machine"] = "another-machine"
        self.policy.write_text(json.dumps(policy))
        self.assertIn(b"configuration changed", self.cli("show", "agpt", expected_status=2).stderr)
        self.assertIn(b"different machine", self.commit(expected_status=2).stderr)

    def test_cache_ttl_stale_grace_and_refresh_failure_preserve_last_success(self):
        self.select_gpt()
        self.assertIn(b"access mode", self.cli("show", "agpt", "--allow-paid", expected_status=2).stderr)
        original = self.report.read_text()
        self.catalogs.write_text(json.dumps({"codex": {"error": "temporary failure"}}))
        self.cli("refresh", "--catalogs", str(self.catalogs), expected_status=2)
        self.assertEqual(self.report.read_text(), original)
        report = json.loads(original)
        report["selected_at"] = time.time() - 90000
        self.report.write_text(json.dumps(report))
        self.assertIn(b"cache expired", self.cli("show", "agpt", expected_status=2).stderr)
        result = self.cli("show", "agpt", "--allow-stale")
        self.assertTrue(json.loads(result.stdout)["stale"])
        self.assertIn(b"25 hours old", result.stderr)
        report["selected_at"] = time.time() - 604801
        self.report.write_text(json.dumps(report))
        self.cli("show", "agpt", "--allow-stale", expected_status=2)

    def test_setup_preserves_custom_state_is_idempotent_migrates_ownership_and_retires_aliases(self):
        self.config_path.parent.mkdir()
        original = {"format": "json", "auth": {"fixture": "secret"},
                    "agents": {"custom": {"argv": ["custom"]}, "pgpt": {"argv": ["old"]}}}
        self.config_path.write_text(json.dumps(original))
        self.report.write_text(json.dumps({"version": 1, "managed_aliases": ["pgpt"]}))
        self.cli("setup")
        applied = json.loads(self.config_path.read_text())
        self.assertEqual(applied["format"], "json")
        self.assertEqual(applied["auth"], original["auth"])
        self.assertEqual(applied["agents"]["custom"], original["agents"]["custom"])
        self.assertEqual(applied["agents"]["agpt"]["argv"], [str(ROOT / "scripts/acpx/reconcile"), "run", "agpt"])
        before = self.config_path.stat().st_mtime_ns
        self.cli("setup")
        self.assertEqual(self.config_path.stat().st_mtime_ns, before)
        self.assertEqual(self.config_path.stat().st_mode & 0o777, 0o600)
        self.render_policy("ci")
        self.cli("setup")
        self.assertEqual(json.loads(self.config_path.read_text())["agents"], {"custom": original["agents"]["custom"]})

    def test_setup_collision_and_malformed_config_leave_files_untouched(self):
        self.config_path.parent.mkdir()
        original = '{"agents":{"pgpt":{"argv":["custom"]}}}'
        self.config_path.write_text(original)
        self.assertIn(b"conflicts with unmanaged", self.cli("setup", expected_status=2).stderr)
        self.assertEqual(self.config_path.read_text(), original)
        self.assertFalse(self.report.exists())
        self.config_path.write_text("bad json")
        self.cli("setup", expected_status=2)
        self.assertEqual(self.config_path.read_text(), "bad json")

    def test_commit_preserves_legacy_ownership_before_first_setup(self):
        self.config_path.parent.mkdir()
        self.config_path.write_text(json.dumps({"agents": {"pgpt": {"argv": ["old"]}}}))
        self.report.write_text(json.dumps({"version": 1, "managed_aliases": ["pgpt"]}))
        self.select_gpt()
        self.cli("setup")
        self.assertEqual(json.loads(self.config_path.read_text())["agents"]["pgpt"]["argv"][-2:], ["run", "pgpt"])

    def test_setup_and_commit_refuse_symlinks(self):
        target = self.work / "original.json"
        target.write_text('{"agents":{}}')
        self.config_path.parent.mkdir()
        self.config_path.symlink_to(target)
        self.assertIn(b"refusing to replace symlink", self.cli("setup", expected_status=2).stderr)
        self.assertEqual(target.read_text(), '{"agents":{}}')
        self.config_path.unlink()
        snap = self.refresh(self.gpt_catalog())
        self.decide(snap, {"gpt": (("codex", "gpt-6-astra"), None)})
        self.report.symlink_to(target)
        self.assertIn(b"refusing to replace symlink", self.commit(expected_status=2).stderr)
        self.assertEqual(target.read_text(), '{"agents":{}}')

    def fake_binary(self, name, body):
        directory = self.work / "bin"
        directory.mkdir(exist_ok=True)
        binary = directory / name
        binary.write_text(f"#!{sys.executable}\n" + body)
        binary.chmod(0o700)
        return {"PATH": str(directory) + os.pathsep + self.env["PATH"]}

    def test_guarded_execution_uses_selected_model_and_rejects_expired_cache_before_launch(self):
        self.select_gpt()
        env = self.fake_binary("codex-acp", "import os\nprint(os.environ['CODEX_CONFIG'])\n")
        result = self.cli("run", "agptx", env=env)
        self.assertEqual(json.loads(result.stdout)["model_reasoning_effort"], "high")
        report = json.loads(self.report.read_text())
        report["selected_at"] = time.time() - 90000
        self.report.write_text(json.dumps(report))
        result = self.cli("run", "agptx", env=env, expected_status=2)
        self.assertIn(b"cache expired", result.stderr)
        self.assertEqual(result.stdout, b"")

    def test_changed_codex_auth_cannot_turn_a_cached_subscription_into_api_usage(self):
        self.select_gpt()
        (self.home / ".codex/auth.json").write_text('{"auth_mode":"apikey","OPENAI_API_KEY":"fixture"}')
        env = self.fake_binary("codex-acp", "raise RuntimeError('Must not launch this adapter')\n")
        result = self.cli("run", "agpt", env=env, expected_status=2)
        self.assertIn(b"access source changed", result.stderr)
        self.assertEqual(result.stdout, b"")

    def test_guarded_command_rejects_a_model_selection_changed_after_inspection(self):
        self.select_gpt()
        inspected = json.loads(self.cli("show", "agpt").stdout)
        catalogs = self.gpt_catalog()
        catalogs["codex"]["models"].append({"id": "gpt-9-frontier", "description": "New frontier",
                                           "default_effort": "medium", "efforts": ["medium", "high"]})
        snap = self.refresh(catalogs)
        self.decide(snap, {"gpt": (("codex", "gpt-9-frontier"), ("codex", "gpt-6-astra"))})
        self.commit()
        result = self.command([sys.executable, *inspected["guard_argv"]], expected_status=2)
        self.assertIn(b"selection changed after inspection", result.stderr)
        self.assertEqual(result.stdout, b"")

    def test_cursor_missing_requested_variant_does_not_lower_effort(self):
        self.render_policy(agents=["cursor-agent"])
        snap = self.refresh({"cursor": {"models": [{"id": "gpt-5.6-sol", "default_effort": "low",
            "efforts": ["low", "high"], "variants": {"low": "gpt-5.6-sol-low"}}]}})
        self.decide(snap, {"gpt": (("cursor", "gpt-5.6-sol"), None)})
        self.commit()
        self.assertIn(b"no advertised default or effort variant", self.cli("show", "agptx", expected_status=2).stderr)

    def test_discovery_retains_codex_descriptions_defaults_and_never_sends_prompt(self):
        self.render_policy(agents=["codex"])
        account = self.home / "codex-active-account"
        account.mkdir()
        (account / "auth.json").write_text((self.home / ".codex/auth.json").read_text())
        self.env["CODEX_HOME"] = str(account)
        (self.home / ".codex/models_cache.json").write_text(json.dumps({"models": [
            {"slug": "gpt-6-astra", "description": "Other account", "default_reasoning_level": "high"},
        ]}))
        cache = account / "models_cache.json"
        cache.write_text(json.dumps({"models": [{"slug": "gpt-6-astra", "description": "Frontier intelligence",
                                                "default_reasoning_level": "medium", "priority": 2}]}))
        env = self.fake_binary("codex-acp", '''import json, os, sys
assert json.loads(os.environ['CODEX_CONFIG']) == {'model_provider':'openai','service_tier':'default'}
for line in sys.stdin:
    request = json.loads(line)
    assert request['method'] in ('initialize', 'session/new')
    result = {} if request['method'] == 'initialize' else {'models': {'availableModels': [
        {'modelId': 'gpt-6-astra[medium]', 'description': 'Frontier'},
        {'modelId': 'gpt-6-astra[high]', 'description': 'Frontier'},
        {'modelId': 'gpt-9-configured', 'description': 'Unadvertised configured default'},
    ]}}
    print(json.dumps({'jsonrpc': '2.0', 'id': request['id'], 'result': result}), flush=True)
''')
        result = self.cli("refresh", env=env | {"CODEX_CONFIG": "inherited bad config"})
        rows = list(json.loads(result.stdout)["candidates"].values())
        self.assertEqual(len(rows), 1)
        candidate = rows[0]
        self.assertEqual((candidate["description"], candidate["default_effort"], candidate["efforts"]),
                         ("Frontier intelligence", "medium", ["medium", "high"]))

    def test_cursor_discovery_keeps_default_variants_descriptions_and_excludes_fast(self):
        self.render_policy(agents=["cursor-agent"])
        env = self.fake_binary("cursor-agent", '''import sys
assert sys.argv[1:] == ['--list-models']
print("""Available models
gpt-5.6-sol - Workhorse (default)
gpt-5.6-sol-low - Low thinking
gpt-5.6-sol-high - More thinking
gpt-7-astra-high-fast - Fast
gemini-3.8-flash[effort=high,fast=false] - Alternative
gemini-5-pro[effort=high,fast=true] - Fast alternative""")
''')
        candidates = list(json.loads(self.cli("refresh", env=env).stdout)["candidates"].values())
        self.assertEqual({c["id"] for c in candidates}, {"gpt-5.6-sol", "gemini-3.8-flash"})
        gpt = next(c for c in candidates if c["family"] == "gpt")
        self.assertEqual(gpt["default_variant"], "gpt-5.6-sol")
        self.assertIn("Workhorse (default)", gpt["descriptions"])
        self.assertEqual(gpt["variants"]["high"], "gpt-5.6-sol-high")

    def test_omp_discovery_snapshots_once_and_preserves_subscription_provider(self):
        self.render_policy(agents=["omp"])
        calls = self.work / "calls"
        env = self.fake_binary("omp", '''import json, os, sys
assert sys.argv[1:] == ['models', 'refresh', '--json']
with open(os.environ['CALLS'], 'a') as f: f.write('catalog\\n')
print(json.dumps({'models': [
    {'provider': 'openai-codex', 'id': 'gpt-6-astra', 'thinking': ['medium','high']},
    {'provider': 'openai', 'id': 'gpt-7-astra', 'thinking': ['medium']},
]}))
''')
        result = self.cli("refresh", env=env | {"CALLS": str(calls)})
        self.assertEqual(calls.read_text(), "catalog\n")
        candidates = list(json.loads(result.stdout)["candidates"].values())
        self.assertEqual([(c["provider"], c["access"]) for c in candidates], [("openai-codex", "included")])

    def test_pi_helper_reads_installed_runtime_through_an_npm_shim_without_inference(self):
        self.render_policy(agents=["pi"])
        prefix = self.work / "pi-install"
        binary = prefix / "node_modules/.bin/pi"
        binary.parent.mkdir(parents=True)
        binary.write_text("#!/bin/sh\nexit 1\n")
        binary.chmod(0o700)
        package = prefix / "node_modules/@earendil-works/pi-coding-agent"
        core = package / "dist/core"
        core.mkdir(parents=True)
        (package / "package.json").write_text(json.dumps({"name": "@earendil-works/pi-coding-agent", "type": "module"}))
        (core / "model-runtime.js").write_text('''
export class ModelRuntime {
  static async create(options) {
    if (options.allowModelNetwork !== false || process.env.PI_OFFLINE !== '1' || process.env.PI_TELEMETRY !== '0')
      throw new Error('Discovery must be offline with telemetry disabled');
    return { getAvailableSnapshot: () => [
      {id: 'gpt-6-astra', provider: 'openai-codex', name: 'Frontier'},
      {id: 'gpt-7-astra', provider: 'openrouter', name: 'API frontier'}],
      isUsingSubscription: (provider) => provider === 'openai-codex' };
  }
}
''')
        (core / "auth-storage.js").write_text("export class ReadOnlyAuthStorage {}\n")
        (core / "settings-manager.js").write_text('''export class SettingsManager {
  static create() { return {getModelThinkingLevel: () => 'high', getDefaultThinkingLevel: () => 'medium'}; }
}\n''')
        (core / "defaults.js").write_text("export const DEFAULT_THINKING_LEVEL = 'medium';\n")
        ai = prefix / "node_modules/@earendil-works/pi-ai"
        (ai / "dist").mkdir(parents=True)
        (ai / "package.json").write_text('{"type":"module"}')
        (ai / "dist/index.js").write_text('''
export const getSupportedThinkingLevels = () => ['medium', 'high', 'xhigh'];
export const clampThinkingLevel = (model, level) => level;
''')
        result = self.cli("refresh", env={"PATH": str(binary.parent) + os.pathsep + self.env["PATH"],
                                          "PI_TELEMETRY": "1"})
        rows = list(json.loads(result.stdout)["candidates"].values())
        self.assertEqual([(r["id"], r["access"], r["default_effort"]) for r in rows],
                         [("gpt-6-astra", "included", "high")])

    def test_gemini_discovery_requires_included_auth_and_disables_reporting(self):
        self.render_policy(agents=["gemini"])
        env = self.fake_binary("gemini", '''import json, os, sys
assert sys.argv[1:] == ['--acp']
assert os.environ['GEMINI_TELEMETRY_ENABLED'] == 'false'
assert os.environ['GEMINI_TELEMETRY_TRACES_ENABLED'] == 'false'
assert 'GEMINI_API_KEY' not in os.environ and 'GOOGLE_API_KEY' not in os.environ
for line in sys.stdin:
    request = json.loads(line)
    assert request['method'] in ('initialize', 'session/new')
    result = {} if request['method'] == 'initialize' else {'models': {'availableModels': [
        {'modelId': 'gemini-3.8-pro', 'description': 'Frontier Gemini'}]}}
    print(json.dumps({'jsonrpc':'2.0','id':request['id'],'result':result}), flush=True)
''')
        result = self.cli("refresh", env=env, expected_status=2)
        self.assertIn("usageStatisticsEnabled=false", json.loads(result.stdout)["problems"]["gemini"])
        settings = self.home / ".gemini/settings.json"
        settings.parent.mkdir()
        settings.write_text(json.dumps({"privacy": {"usageStatisticsEnabled": False},
                                        "security": {"auth": {"selectedType": "gemini-api-key"}}}))
        result = self.cli("refresh", env=env, expected_status=2)
        self.assertIn("oauth-personal", json.loads(result.stdout)["problems"]["gemini"])
        settings.write_text(json.dumps({"privacy": {"usageStatisticsEnabled": False},
                                        "security": {"auth": {"selectedType": "oauth-personal"}}}))
        result = self.cli("refresh", env=env | {"GEMINI_API_KEY": "inherited-api", "GOOGLE_API_KEY": "inherited-api"})
        self.assertEqual([r["id"] for r in json.loads(result.stdout)["candidates"].values()], ["gemini-3.8-pro"])
        self.decide(json.loads(result.stdout), {"gemini": (("gemini", "gemini-3.8-pro"), None)})
        self.commit()
        env = self.fake_binary("gemini", "print('adapter launched')\n")
        settings.write_text(json.dumps({"privacy": {"usageStatisticsEnabled": False},
                                        "security": {"auth": {"selectedType": "vertex-ai"}}}))
        result = self.cli("run", "agemini", env=env, expected_status=2)
        self.assertIn(b"oauth-personal", result.stderr)
        self.assertEqual(result.stdout, b"")
        settings.write_text(json.dumps({"privacy": {"usageStatisticsEnabled": True},
                                        "security": {"auth": {"selectedType": "oauth-personal"}}}))
        result = self.cli("run", "agemini", env=env, expected_status=2)
        self.assertIn(b"usageStatisticsEnabled=false", result.stderr)
        self.assertEqual(result.stdout, b"")
        settings.write_text(json.dumps({"privacy": {"usageStatisticsEnabled": False},
                                        "security": {"auth": {"selectedType": "oauth-personal"}}}))
        project = self.work / "gemini-project"
        (project / ".gemini").mkdir(parents=True)
        override = project / ".gemini/settings.json"
        for contents, message in (
            ({"security": {"auth": {"selectedType": "vertex-ai"}}}, b"oauth-personal"),
            ({"security": {"auth": {"selectedType": None}}}, b"oauth-personal"),
            ({"privacy": {"usageStatisticsEnabled": True}}, b"usageStatisticsEnabled=false"),
            ({"security": {"auth": {"useExternal": True}}}, b"external authentication"),
        ):
            override.write_text(json.dumps(contents))
            result = self.cli("run", "agemini", env=env, cwd=project, expected_status=2)
            self.assertIn(message, result.stderr)
            self.assertEqual(result.stdout, b"")
        override.write_text('{"security":{"auth":{"selectedType":"vertex-ai"}}}')
        result = self.cli("run", "agemini", env=env | {"GEMINI_CLI_SYSTEM_SETTINGS_PATH": str(override)},
                          expected_status=2)
        self.assertIn(b"oauth-personal", result.stderr)
        self.assertEqual(result.stdout, b"")
        override.write_text('{"security":{"auth":{"useExternal":true}}}')
        result = self.cli("run", "agemini", env=env | {"GEMINI_CLI_SYSTEM_DEFAULTS_PATH": str(override)},
                          expected_status=2)
        self.assertIn(b"external authentication", result.stderr)
        self.assertEqual(result.stdout, b"")

    def test_claude_sdk_reports_actual_access_and_preserves_capability_descriptions(self):
        self.render_policy(agents=["claude"])
        prefix = self.work / "claude-install"
        binary = prefix / "node_modules/.bin/claude-agent-acp"
        binary.parent.mkdir(parents=True)
        binary.write_text("#!/bin/sh\nexit 1\n")
        binary.chmod(0o700)
        adapter = prefix / "node_modules/@agentclientprotocol/claude-agent-acp"
        adapter.mkdir(parents=True)
        (adapter / "package.json").write_text('{"name":"@agentclientprotocol/claude-agent-acp"}')
        sdk = adapter / "node_modules/@anthropic-ai/claude-agent-sdk"
        sdk.mkdir(parents=True)
        (sdk / "package.json").write_text('{"type":"module","main":"index.js"}')
        (sdk / "index.js").write_text('''
import { existsSync } from 'node:fs';
import { join } from 'node:path';
export function query({ options }) {
  if (process.env.DISABLE_TELEMETRY !== '1' || process.env.DISABLE_ERROR_REPORTING !== '1')
    throw new Error('Reporting must be disabled');
  return {
    accountInfo: async () => process.env.AUTH_KIND === 'api' ||
      (options.settingSources.includes('project') && options.settingSources.includes('local') &&
       existsSync(join(options.cwd, '.claude/settings.local.json')))
      ? { apiProvider: 'firstParty', apiKeySource: 'user', subscriptionType: 'max' }
      : { apiProvider: 'firstParty', apiKeySource: 'none', subscriptionType: 'max' },
    supportedModels: async () => [{value:'fable', resolvedModel:'claude-fable-5-1',
      description:'Research flagship', supportsEffort:true, supportedEffortLevels:['medium','high']}],
    close() {},
  };
}
''')
        env = {"PATH": str(binary.parent) + os.pathsep + self.env["PATH"], "DISABLE_TELEMETRY": "0"}
        result = self.cli("refresh", env=env)
        candidate = next(iter(json.loads(result.stdout)["candidates"].values()))
        self.assertEqual((candidate["description"], candidate["access"]), ("Research flagship", "included"))
        self.decide(json.loads(result.stdout), {"fable": (("claude", "claude-fable-5-1"), None)})
        self.commit()
        result = self.cli("run", "afable", env=env | {"AUTH_KIND": "api"}, expected_status=2)
        self.assertIn(b"access source changed", result.stderr)
        result = self.cli("refresh", env=env | {"AUTH_KIND": "api"}, expected_status=2)
        self.assertEqual(json.loads(result.stdout)["candidates"], {})
        result = self.cli("refresh", "--allow-paid", env=env | {"AUTH_KIND": "api"})
        self.assertEqual(next(iter(json.loads(result.stdout)["candidates"].values()))["access"], "paid")
        project = self.work / "project"
        (project / ".claude").mkdir(parents=True)
        (project / ".claude/settings.local.json").write_text('{"apiKeyHelper":"project-key"}')
        result = self.cli("run", "afable", env=env, cwd=project, expected_status=2)
        self.assertIn(b"access source changed", result.stderr)
        self.assertEqual(result.stdout, b"")

    def test_missing_dependency_reports_unavailable_without_overwriting_selection(self):
        self.select_gpt()
        original = self.report.read_text()
        policy = json.loads(self.policy.read_text())
        policy["declared"] = ["codex"]
        policy["routes"]["codex"]["requires"] = [str(self.work / "absent")]
        self.policy.write_text(json.dumps(policy))
        result = self.cli("refresh", expected_status=2)
        self.assertIn("missing dependencies", json.loads(result.stdout)["problems"]["codex"])
        self.assertEqual(self.report.read_text(), original)

    def test_partial_refresh_cannot_replace_a_known_model_after_its_catalog_fails(self):
        self.render_policy(agents=["codex", "cursor-agent"])
        self.select_gpt()
        original = self.report.read_text()
        catalogs = {"codex": {"error": "catalog timed out"}, "cursor": {"models": [
            {"id": "gpt-5.6-sol", "efforts": [], "default_variant": "gpt-5.6-sol"},
        ]}}
        snap = self.refresh(catalogs)
        self.decide(snap, {"gpt": (("cursor", "gpt-5.6-sol"), None)})
        result = self.commit(expected_status=2)
        self.assertIn(b"catalog failed for previously selected model", result.stderr)
        self.assertEqual(self.report.read_text(), original)
        catalogs["cursor"]["models"] = [
            {"id": model, "efforts": [], "default_variant": model}
            for model in ("gpt-6-astra", "gpt-6.1-sol")
        ]
        snap = self.refresh(catalogs)
        self.decide(snap, {"gpt": (("cursor", "gpt-6-astra"), ("cursor", "gpt-6.1-sol"))})
        self.commit()
        self.assertEqual(json.loads(self.cli("show", "agpt").stdout)["route"], "cursor")
