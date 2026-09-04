import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

SKILL_ROOT = Path(__file__).resolve().parents[1]
UX_SCRIPTS_ROOT = SKILL_ROOT / "scripts" / "ux"
sys.path.insert(0, str(UX_SCRIPTS_ROOT))


def load_run_workflows():
    module_path = UX_SCRIPTS_ROOT / "run_workflows.py"
    if not module_path.exists():
        module_path = UX_SCRIPTS_ROOT / "literal_run_workflows.py"

    spec = importlib.util.spec_from_file_location("run_workflows", module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"could not load {module_path}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


run_workflows = load_run_workflows()


class RunWorkflowsTests(unittest.TestCase):
    def test_resolves_simulator_skill_beside_rendered_skill(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            skills_root = Path(tmp) / "skills"
            audit_root = skills_root / "ios-audit"
            simulator_root = skills_root / "ios-simulator-skill"
            audit_root.mkdir(parents=True)
            simulator_root.mkdir()

            self.assertEqual(
                run_workflows.resolve_default_sim_skill_dir(audit_root),
                simulator_root,
            )

    def test_resolves_simulator_skill_from_package_source(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            skills_root = Path(tmp) / "skills"
            audit_root = skills_root / "local" / "ios-audit"
            simulator_root = skills_root / "vendor" / "ios-simulator-skill"
            audit_root.mkdir(parents=True)
            simulator_root.mkdir(parents=True)

            self.assertEqual(
                run_workflows.resolve_default_sim_skill_dir(audit_root),
                simulator_root,
            )

    @patch.object(run_workflows, "capture_accessibility", return_value={"raw": "ok"})
    @patch.object(run_workflows, "capture_screenshot", return_value=None)
    @patch.object(run_workflows.subprocess, "run")
    def test_reset_keychain_step_uses_simctl_keychain_reset(
        self,
        mock_run,
        _mock_screenshot,
        _mock_accessibility,
    ) -> None:
        mock_run.return_value = SimpleNamespace(
            returncode=0, stdout="Reset keychain", stderr=""
        )

        result = run_workflows.execute_step(
            {
                "action": "reset_keychain",
                "description": "Reset persisted auth",
                "screenshot": False,
            },
            {"bundle_id": "com.movies.do.ios"},
            "/tmp/ios-simulator-skill",
            "/tmp/ios-audit-output",
            "Sign In",
            0,
            "DEVICE-UDID",
        )

        self.assertTrue(result["success"])
        self.assertEqual(result["interaction_type"], "keychain reset")
        self.assertEqual(result["output"], "Reset keychain")
        mock_run.assert_called_once_with(
            ["xcrun", "simctl", "keychain", "DEVICE-UDID", "reset"],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )


if __name__ == "__main__":
    unittest.main()
