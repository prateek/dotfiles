from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "packages/review/skills/land-changes/scripts/options.py"


class LandOptionsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = dict(os.environ, XDG_CONFIG_HOME=str(self.root / "config"), HOME=str(self.root / "home"))

    def command(self, *flags, repo="github.com/me/widget", target="main"):
        return [sys.executable, str(SCRIPT), "--repo-id", repo, "--target", target, *flags]

    def run_options(self, *flags, repo="github.com/me/widget", target="main", error=None):
        result = subprocess.run(self.command(*flags, repo=repo, target=target), env=self.env,
                                text=True, capture_output=True)
        if error is not None:
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(error, result.stderr)
            return result
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_resolve_and_show_do_not_create_configuration(self):
        for flags, action in (((), "land"), (("--show-defaults",), "show_defaults")):
            with self.subTest(flags=flags):
                result = self.run_options(*flags)
                self.assertEqual(result["settings"], {"review_gate": "auto", "deploy": False, "tests": "run"})
                self.assertEqual(result["sources"], {"review_gate": "builtin", "deploy": "builtin", "tests": "builtin"})
                self.assertEqual(result["action"], action)
                self.assertIs(result["defaults_saved"], False)
        self.assertFalse((self.root / "config").exists())

    def test_explicit_false_overrides_saved_true_without_changing_it(self):
        saved = self.run_options("--deploy=true", "--save-defaults")
        path = Path(saved["defaults_path"])
        self.assertEqual(json.loads(path.read_text())["defaults"], {"deploy": True})
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(path.parent.stat().st_mode & 0o777, 0o700)
        original = path.read_bytes()
        result = self.run_options("--deploy=false", "--review-gate=skip")
        self.assertEqual(result["settings"], {"review_gate": "skip", "deploy": False, "tests": "run"})
        self.assertEqual(result["sources"], {"review_gate": "argument", "deploy": "argument", "tests": "builtin"})
        self.assertEqual(self.run_options()["settings"], {"review_gate": "auto", "deploy": True, "tests": "run"})
        self.assertEqual(path.read_bytes(), original)

    def test_tests_skip_is_an_explicit_one_time_setting(self):
        result = self.run_options("--tests=skip")
        self.assertEqual(result["settings"], {"review_gate": "auto", "deploy": False, "tests": "skip"})
        self.assertEqual(result["sources"]["tests"], "argument")
        self.assertEqual(result["saved_defaults"], {})
        self.assertFalse(Path(result["defaults_path"]).exists())
        self.assertEqual(self.run_options()["settings"]["tests"], "run")

    def test_tests_defaults_support_selective_save_override_and_reset(self):
        saved = self.run_options("--tests=skip", "--save-defaults")
        self.assertEqual(saved["saved_defaults"], {"tests": "skip"})
        merged = self.run_options("--deploy=false", "--save-defaults")
        self.assertEqual(merged["saved_defaults"], {"tests": "skip", "deploy": False})
        self.assertEqual(merged["sources"]["tests"], "saved")
        self.assertEqual(self.run_options("--tests=run")["settings"]["tests"], "run")
        shown = self.run_options("--show-defaults")
        self.assertEqual(shown["settings"]["tests"], "skip")
        self.assertEqual(shown["sources"]["tests"], "saved")
        reset = self.run_options("--reset-defaults")
        self.assertEqual(reset["settings"]["tests"], "run")
        self.assertEqual(reset["sources"]["tests"], "builtin")

    def test_every_review_mode_can_override_saved_preferences(self):
        self.run_options("--review-gate=skip", "--save-defaults")
        for mode in ("auto", "skip", "confirm"):
            with self.subTest(mode=mode):
                result = self.run_options(f"--review-gate={mode}")
                self.assertEqual(result["settings"]["review_gate"], mode)
                self.assertEqual(result["sources"]["review_gate"], "argument")
                self.assertEqual(self.run_options()["saved_defaults"], {"review_gate": "skip"})

    def test_save_merges_only_explicit_values_and_reset_is_configuration_only(self):
        self.run_options("--review-gate=skip", "--save-defaults")
        saved = self.run_options("--deploy=false", "--save-defaults")
        self.assertEqual(saved["saved_defaults"], {"review_gate": "skip", "deploy": False})
        shown = self.run_options("--show-defaults")
        self.assertEqual(shown["action"], "show_defaults")
        self.assertEqual(shown["sources"], {"review_gate": "saved", "deploy": "saved", "tests": "builtin"})
        reset = self.run_options("--reset-defaults")
        self.assertEqual(reset["action"], "reset_defaults")
        self.assertFalse(Path(reset["defaults_path"]).exists())
        self.assertEqual(self.run_options()["settings"], {"review_gate": "auto", "deploy": False, "tests": "run"})

    def test_reset_preserves_other_repository_and_target_preferences(self):
        scopes = (("github.com/me/widget", "main"), ("github.com/fork/widget", "main"),
                  ("github.com/me/widget", "release/stable"))
        for repo, target in scopes:
            self.run_options("--deploy=true", "--save-defaults", repo=repo, target=target)
        self.run_options("--reset-defaults")
        for repo, target in scopes[1:]:
            with self.subTest(repo=repo, target=target):
                self.assertEqual(self.run_options(repo=repo, target=target)["saved_defaults"], {"deploy": True})

    def test_identity_and_target_scope_defaults_independently_of_worktree(self):
        self.run_options("--review-gate=skip", "--save-defaults")
        for repo, target in (("github.com/fork/widget", "main"), ("github.com/me/widget", "release"),
                             ("git.example/me/widget", "main")):
            with self.subTest(repo=repo, target=target):
                self.assertEqual(self.run_options(repo=repo, target=target)["settings"]["review_gate"], "auto")
        other = self.root / "another-worktree"
        other.mkdir()
        result = subprocess.run(self.command(), env=self.env, cwd=other, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["settings"]["review_gate"], "skip")

    def test_invalid_or_conflicting_flags_never_write_defaults(self):
        cases = [
            (["--deploy=yes", "--save-defaults"], "invalid choice"),
            (["--review-gate=true"], "invalid choice"),
            (["--dep=true"], "unrecognized arguments"),
            (["--deploy=false", "--deploy=true", "--save-defaults"], "duplicate option"),
            (["--save-defaults"], "requires an explicit"),
            (["--show-defaults", "--deploy=true"], "cannot combine"),
            (["--show-defaults", "--reset-defaults"], "not allowed"),
            (["--show-defaults", "--show-defaults"], "duplicate option"),
            (["--reset-defaults", "--reset-defaults"], "duplicate option"),
            (["--deploy=true", "--save-defaults", "--save-defaults"], "duplicate option"),
            (["--review-gate=auto", "--review-gate=skip"], "duplicate option"),
            (["--show-defaults", "--save-defaults"], "not allowed"),
            (["--reset-defaults", "--deploy=false"], "cannot combine"),
            (["--deploy=False"], "invalid choice"),
            (["--tests=false", "--save-defaults"], "invalid choice"),
            (["--tests=RUN"], "invalid choice"),
            (["--tests=skip", "--tests=run"], "duplicate option"),
            (["--show-defaults", "--tests=skip"], "cannot combine"),
            (["--reset-defaults", "--tests=run"], "cannot combine"),
        ]
        for flags, message in cases:
            with self.subTest(flags=flags):
                self.run_options(*flags, error=message)
        self.assertFalse((self.root / "config").exists())

    def test_corrupt_or_mismatched_defaults_fail_instead_of_authorizing(self):
        result = self.run_options("--deploy=true", "--save-defaults")
        path = Path(result["defaults_path"])
        valid = json.loads(path.read_text())
        for changed in ("not json", json.dumps(dict(valid, version=2)),
                        json.dumps(dict(valid, version=True)),
                        json.dumps(dict(valid, repo_id="github.com/other/widget")),
                        json.dumps(dict(valid, target="other")),
                        json.dumps(dict(valid, defaults={"deploy": "false"})),
                        json.dumps(dict(valid, defaults={"deploy": 0})),
                        json.dumps(dict(valid, defaults={"review_gate": "bypass"})),
                        json.dumps(dict(valid, defaults={"review_gate": []})),
                        json.dumps(dict(valid, defaults={"tests": False})),
                        json.dumps(dict(valid, defaults={"tests": "false"})),
                        json.dumps(dict(valid, defaults={"tests": []})),
                        json.dumps(dict(valid, defaults=[])),
                        json.dumps(dict(valid, defaults={"command": "anything"})),
                        json.dumps(dict(valid, extra="unknown")),
                        json.dumps(valid).replace('"deploy": true', '"deploy": true, "deploy": false')):
            with self.subTest(changed=changed):
                path.write_text(changed)
                self.run_options(error="invalid defaults")
                self.run_options("--review-gate=skip", "--deploy=false", "--save-defaults", error="invalid defaults")
                self.assertEqual(path.read_text(), changed)
        self.run_options("--reset-defaults")
        self.assertEqual(self.run_options()["settings"]["deploy"], False)

    def test_symlinked_record_requires_reset_without_touching_its_target(self):
        result = self.run_options("--deploy=true", "--save-defaults")
        path = Path(result["defaults_path"])
        original = path.read_bytes()
        destination = self.root / "other-config.json"
        path.rename(destination)
        path.symlink_to(destination)
        self.run_options(error="symlinked defaults")
        self.run_options("--review-gate=skip", "--save-defaults", error="symlinked defaults")
        self.run_options("--reset-defaults")
        self.assertFalse(path.is_symlink())
        self.assertEqual(destination.read_bytes(), original)
        self.assertEqual(self.run_options()["saved_defaults"], {})

    def test_invalid_identity_is_rejected_before_writing(self):
        for repo in ("https://github.com/me/widget", "git@github.com:me/widget", "github.com/me/../widget",
                     "github.com//widget", "widget", "github.com/me/bad name"):
            with self.subTest(repo=repo):
                self.run_options("--deploy=true", "--save-defaults", repo=repo, error="identity" if " " in repo else "canonical")
        self.run_options("--deploy=true", "--save-defaults", target="", error="nonempty")
        self.assertFalse((self.root / "config").exists())

    def test_concurrent_saves_preserve_all_explicit_settings(self):
        processes = [subprocess.Popen(self.command(flag, "--save-defaults"), env=self.env,
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                     for flag in ("--review-gate=skip", "--deploy=true", "--tests=skip")]
        for process in processes:
            _, stderr = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, stderr)
        self.assertEqual(self.run_options()["settings"], {"review_gate": "skip", "deploy": True, "tests": "skip"})

    def test_xdg_fallback_and_relative_directory_rejection(self):
        self.env.pop("XDG_CONFIG_HOME")
        result = self.run_options("--show-defaults")
        self.assertTrue(result["defaults_path"].startswith(str(self.root / "home/.config/land-changes/repos")))
        self.env["XDG_CONFIG_HOME"] = "relative"
        self.run_options("--deploy=true", "--save-defaults", error="absolute")


if __name__ == "__main__":
    unittest.main()
