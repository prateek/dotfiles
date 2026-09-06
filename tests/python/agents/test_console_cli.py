import json
import math
import os
import sys

from tests.python.agents.console_support import ConsoleCase, ConsoleRepoCase, ROOT, SCRIPTS, run_budget
from tests.python.agents.console_documents import decisions, op
from skill_console import Op
from skill_console.budget import utf16_length
from skill_console.decisions import dump


def install_unknown_claude(case):
    binary = case.work / "bin/claude"
    binary.parent.mkdir(exist_ok=True)
    binary.write_text("#!/bin/sh\nexit 0\n")
    binary.chmod(0o700)
    case.env["PATH"] = str(binary.parent) + os.pathsep + case.env["PATH"]


class ConsoleCliTests(ConsoleCase):
    def setUp(self):
        super().setUp()
        install_unknown_claude(self)

    def console(self, *args, **kwargs):
        return self.command([sys.executable, str(SCRIPTS / "skill-console"), *map(str, args)], **kwargs)

    def invalid_decisions(self):
        document = json.loads(dump(decisions(op(Op.SET_FRONTMATTER, "pkg:local", field="user-invocable", value=True))))
        document["schema_version"] = 2
        path = self.fixtures / "invalid-decisions.json"
        path.write_text(json.dumps(document))
        return path

    def test_budget_cli_preserves_every_fixture_field_and_both_cost_measures(self):
        paths = sorted(self.fixtures.glob("*.json"))
        self.assertTrue(paths)
        for path in paths:
            measures = [("width", {})]
            if path.stem.startswith("parity-"):
                measures.append(("utf16", {"measure": utf16_length}))
            for measure, kwargs in measures:
                with self.subTest(example=path.stem, measure=measure):
                    expected, _, _ = run_budget(path, **kwargs)
                    result = self.console("budget", "--fixture", path, "--json", "--measure", measure)
                    self.assertEqual(result.stderr, b"")
                    got = json.loads(result.stdout)
                    for field in ("mode", "budget", "budget_from_env", "demand_chars", "rendered_chars", "headroom_chars", "all_pinned"):
                        number = {"Infinity": math.inf, "-Infinity": -math.inf}.get(got[field], got[field])
                        self.assertEqual(number, getattr(expected, field), field)
                    for field in ("full", "name_only", "capped"):
                        self.assertEqual(got[field], list(getattr(expected, field)), field)
                    self.assertEqual(got["rendered"], {name: state.value for name, state in expected.rendered.items()})
                    self.assertEqual(len(got["costs"]), len(expected.costs))
                    for actual, cost in zip(got["costs"], expected.costs, strict=True):
                        for field in ("name", "index", "name_only_cost", "full_cost", "upgrade_cost", "capped", "width_divergent"):
                            self.assertEqual(actual[field], getattr(cost, field), field)

    def test_budget_cli_serializes_infinity_and_emits_the_full_listing(self):
        got = json.loads(self.console("budget", "--fixture", self.fixtures / "env-infinity.json", "--json").stdout)
        self.assertEqual(got["budget"], "Infinity")
        self.assertEqual(got["mode"], "fits")
        self.assertEqual(got["listing"], "- e:a: 0123456789\n- e:b: 0123456789")

    def test_budget_missing_or_malformed_fixture_and_apply_option_errors_exit_one(self):
        result = self.console("budget", "--fixture", self.fixtures / "does-not-exist.json", expected_status=1)
        self.assertTrue(result.stderr.startswith(b"skill-console: "))
        self.assertEqual(result.stdout, b"")
        path = self.fixtures / "malformed.json"
        path.write_text('{"inputs": {}}')
        result = self.console("budget", "--fixture", path, expected_status=1)
        self.assertIn(b"malformed fixture", result.stderr)
        self.assertEqual(result.stdout, b"")
        result = self.console("apply", self.invalid_decisions(), "--allow-dirty-targets", expected_status=1)
        self.assertIn(b"--commit", result.stderr)
        self.assertEqual(result.stdout, b"")

    def test_invalid_document_exits_three_with_structured_violation_and_pointer(self):
        result = self.console("apply", self.invalid_decisions(), "--json", expected_status=3)
        self.assertRegex(result.stderr.decode(), r"^skill-console: .*V1")
        payload = json.loads(result.stdout)
        self.assertIs(payload["ok"], False)
        self.assertEqual(payload["code"], 3)
        self.assertEqual(payload["violations"][0]["code"], "V1")
        self.assertEqual(payload["violations"][0]["pointer"], "/schema_version")

    def test_missing_model_and_bare_alias_are_discovery_errors_without_html(self):
        output = self.work / "never-written.html"
        result = self.console("render", "--no-open", "--out", output, expected_status=2)
        self.assertIn(b"--model", result.stderr)
        self.assertIn(b"--context-window", result.stderr)
        self.assertFalse(output.exists())
        result = self.console("render", "--no-open", "--model", "opus", "--context-window", "200000", "--out", output, expected_status=2)
        self.assertIn(b"alias", result.stderr.lower())
        self.assertFalse(output.exists())

    def test_config_directory_relocates_settings_usage_and_skills_and_env_disables_builtins(self):
        cfg = self.work / "claude-config"
        skill = cfg / "skills/cfgskill"
        skill.mkdir(parents=True)
        (cfg / "settings.json").write_text('{"skillListingBudgetFraction": 0.02}')
        (cfg / ".claude.json").write_text('{"skillUsage":{"init":{"usageCount":7,"lastUsedAt":1756800000000}}}')
        (skill / "SKILL.md").write_text("---\nname: cfgskill\ndescription: from the config dir\n---\n")
        project = self.work / "empty-project"
        project.mkdir()
        args = ("render", "--no-open", "--json", "--model", "claude-fable-5-1", "--context-window", "200000",
                "--project-root", project, "--now-ms", "1756800000000", "--out", self.work / "config.html")
        result = self.console(*args, env={"CLAUDE_CONFIG_DIR": str(cfg)})
        self.assertIn(b"binary hash is not", result.stderr)
        out = json.loads(result.stdout)
        rows = {row["name"]: row for row in out["rows"]}
        self.assertEqual(out["snapshot"]["budget_chars"], 12000)
        self.assertEqual(out["snapshot"]["fraction"], 0.02)
        self.assertEqual(rows["init"]["usage"], {"usage_count": 7, "last_used_at_ms": 1756800000000})
        self.assertEqual(rows["init"]["rank"], 7.0)
        self.assertEqual(rows["cfgskill"]["origin"], "user-skill")
        self.assertIs(rows["cfgskill"]["listed"], True)
        result = self.console(*args, env={"CLAUDE_CONFIG_DIR": str(cfg), "CLAUDE_CODE_DISABLE_BUNDLED_SKILLS": "1"})
        self.assertIn(b"binary hash is not", result.stderr)
        out = json.loads(result.stdout)
        self.assertFalse(any(row["listed"] for row in out["rows"] if row["origin"] == "builtin"))
        names = {cost["name"] for cost in out["admission"]["costs"]}
        self.assertIn("cfgskill", names)
        self.assertFalse({"init", "commit", "security-review"} & names)


class ConsoleUnknownProducerTests(ConsoleRepoCase):
    def test_unrecognized_binary_can_render_but_apply_refuses_before_staging_or_writing(self):
        install_unknown_claude(self)
        console = self.repo / ".agents/skills/agent-skill-management/scripts/skill-console"
        html = self.work / "render.html"
        result = self.command([sys.executable, str(console), "render", "--no-open", "--json",
                               "--model", "claude-fable-5-1", "--context-window", "200000", "--out", str(html)], cwd=self.repo)
        self.assertTrue(html.is_file())
        self.assertIn(b"skillListingBudgetFraction is unset", result.stderr)
        self.assertIn(b"binary hash is not", result.stderr)
        render = json.loads(result.stdout)
        self.assertIs(render["ok"], True)
        snapshot, admission = render["snapshot"], render["admission"]
        self.assertIs(snapshot["binary_hash_matched"], False)
        self.assertEqual(snapshot["model"], "claude-fable-5-1")
        self.assertEqual(snapshot["bytes_per_token"], 3)
        self.assertEqual(snapshot["budget_chars"], admission["budget"])
        self.assertGreater(len(admission["costs"]), 0)
        self.assertEqual(len(admission["full"]) + len(admission["name_only"]), len(admission["costs"]))
        predicted = {"cap_chars": admission["budget"], "newly_admitted": [], "newly_dropped": [],
                     "added_name_only": 0, "removed_name_only": 0}
        for suffix in ("before", "after"):
            predicted.update({f"mode_{suffix}": admission["mode"], f"demand_{suffix}": admission["demand_chars"],
                              f"rendered_{suffix}": admission["rendered_chars"], f"full_{suffix}": len(admission["full"]),
                              f"name_only_{suffix}": len(admission["name_only"])})
        document = self.work / "decisions.json"
        document.write_text(json.dumps({"schema_version": 1, "harness": "claude", "snapshot": snapshot,
                                        "predicted": predicted, "operations": []}))
        before = self.git("status", "--porcelain").stdout
        result = self.command([sys.executable, str(console), "apply", str(document), "--json"], cwd=self.repo, expected_status=3)
        self.assertIn(b"V10", result.stderr)
        payload = json.loads(result.stdout)
        self.assertIs(payload["ok"], False)
        self.assertEqual(payload["code"], 3)
        self.assertTrue(any(v["code"] == "V10" and v["pointer"] == "/snapshot/binary_hash_matched" for v in payload["violations"]))
        self.assertEqual(self.git("status", "--porcelain").stdout, before)
        staging = self.work / "state/dotfiles/skill-console/staging"
        self.assertFalse(list(staging.iterdir()) if staging.exists() else [])
