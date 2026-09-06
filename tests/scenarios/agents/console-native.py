"""External Claude build verification, selected only through the host lane."""

import hashlib
import json
import os
import shutil
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / ".agents/skills/agent-skill-management/scripts"))

import skill_console as constants
from tests.support.python import RepoTestCase

BINARY = Path(sys.argv.pop(1)).resolve()


class ConsoleNativeTests(RepoTestCase):
    def setUp(self):
        super().setUp()
        self.binary = BINARY.read_bytes()
        self.assertEqual(hashlib.sha256(self.binary).hexdigest(), constants.BINARY_SHA256,
                         f"requires Claude {constants.BINARY_VERSION} build recorded by skill_console")

    def test_constant_provenance(self):
        required = {
            "DEFAULT_BUDGET_FRACTION", "DEFAULT_BYTES_PER_TOKEN", "DEFAULT_CONTEXT_WINDOW",
            "DEFAULT_MAX_DESC_CHARS", "DECAY_HALF_LIFE_DAYS", "DECAY_FLOOR",
            "LEGACY_BYTES_PER_TOKEN_FAMILIES", "MODEL_FAMILIES", "BINARY_VERSION",
        }
        by_name = {item.name: item.source for item in constants.BINARY_PROVENANCE}
        self.assertLessEqual(required, by_name.keys())
        for item in constants.BINARY_PROVENANCE:
            with self.subTest(constant=item.name):
                self.assertIn(item.source.encode(), self.binary)
        for name, prefix in (
            ("DEFAULT_BUDGET_FRACTION", "x2o="), ("DEFAULT_BYTES_PER_TOKEN", "Q1n="),
            ("DEFAULT_CONTEXT_WINDOW", "A2o="), ("DEFAULT_MAX_DESC_CHARS", "R2o="),
        ):
            self.assertEqual(by_name[name], f"{prefix}{getattr(constants, name)}")
        self.assertIn(f"o/{constants.DECAY_HALF_LIFE_DAYS:g})", by_name["DECAY_HALF_LIFE_DAYS"])
        self.assertIn(f",{constants.DECAY_FLOOR})", by_name["DECAY_FLOOR"])
        self.assertIn(f"/{constants.MS_PER_DAY}", by_name["MS_PER_DAY"])
        self.assertEqual(by_name["BINARY_VERSION"], f'VERSION:"{constants.BINARY_VERSION}"')
        families = by_name["LEGACY_BYTES_PER_TOKEN_FAMILIES"]
        for family in constants.LEGACY_BYTES_PER_TOKEN_FAMILIES:
            self.assertIn(f'"{family}"', families)
        self.assertEqual(families.count('"'), 2 * len(constants.LEGACY_BYTES_PER_TOKEN_FAMILIES))
        for family in constants.MODEL_FAMILIES:
            self.assertIn(f'includes("{family}")', by_name["MODEL_FAMILIES"])

    def test_render_apply_cycle(self):
        repo = self.work / "repo"
        shutil.copytree(ROOT, repo, ignore=shutil.ignore_patterns(".git", "build", ".venv", "__pycache__", "mise.local.toml"))
        self.command(["git", "init", "-q", str(repo)])
        self.command(["git", "add", "-A"], cwd=repo)
        self.command(["git", "-c", "user.name=console-test", "-c", "user.email=test@example.invalid",
                      "commit", "-q", "-m", "fixture"], cwd=repo)
        bin_dir = self.work / "bin"
        bin_dir.mkdir()
        (bin_dir / "claude").symlink_to(BINARY)
        self.env["PATH"] = str(bin_dir) + os.pathsep + self.env["PATH"]
        console = str(repo / ".agents/skills/agent-skill-management/scripts/skill-console")
        rendered = self.command([console, "render", "--no-open", "--json", "--model", "claude-fable-5-1",
                                 "--context-window", "200000", "--out", str(self.work / "render.html")], cwd=repo)
        self.assertTrue((self.work / "render.html").stat().st_size)
        self.assertIn(b"skillListingBudgetFraction is unset", rendered.stderr)
        payload = json.loads(rendered.stdout)
        self.assertIs(payload["ok"], True)
        snapshot, admission = payload["snapshot"], payload["admission"]
        self.assertEqual((snapshot["model"], snapshot["bytes_per_token"]), ("claude-fable-5-1", 3))
        self.assertEqual(snapshot["budget_chars"], admission["budget"])
        self.assertEqual(len(admission["full"]) + len(admission["name_only"]), len(admission["costs"]))
        self.assertGreater(len(admission["costs"]), 0)
        predicted = {"cap_chars": admission["budget"], "newly_admitted": [], "newly_dropped": [],
                     "added_name_only": 0, "removed_name_only": 0}
        for name, value in (("mode", admission["mode"]), ("demand", admission["demand_chars"]),
                            ("rendered", admission["rendered_chars"]), ("full", len(admission["full"])),
                            ("name_only", len(admission["name_only"]))):
            predicted.update({f"{name}_before": value, f"{name}_after": value})
        decisions = self.work / "decisions.json"
        decisions.write_text(json.dumps({"schema_version": 1, "harness": "claude", "snapshot": snapshot,
                                         "predicted": predicted, "operations": []}))
        before = self.command(["git", "status", "--porcelain"], cwd=repo).stdout
        result = self.command([console, "apply", str(decisions), "--json"], cwd=repo)
        self.assertEqual(self.command(["git", "status", "--porcelain"], cwd=repo).stdout, before)
        applied = json.loads(result.stdout)
        self.assertIs(applied["ok"], True)
        self.assertIs(applied["dry_run"], True)
        for field in ("edits", "applied", "unapplied"):
            self.assertEqual(applied[field], [])
        self.assertIsNone(applied["staging_root"])
        staging = Path(self.env["XDG_STATE_HOME"]) / "dotfiles/skill-console/staging"
        self.assertFalse(staging.exists() and any(staging.iterdir()))


unittest.main()
