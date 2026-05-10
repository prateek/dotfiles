import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


SKILL_ROOT = Path(__file__).resolve().parents[1]
UX_SCRIPTS_ROOT = SKILL_ROOT / "scripts" / "ux"
sys.path.insert(0, str(UX_SCRIPTS_ROOT))

import run_workflows  # noqa: E402


class RunWorkflowsTests(unittest.TestCase):
    @patch.object(run_workflows, "capture_accessibility", return_value={"raw": "ok"})
    @patch.object(run_workflows, "capture_screenshot", return_value=None)
    @patch.object(run_workflows.subprocess, "run")
    def test_reset_keychain_step_uses_simctl_keychain_reset(
        self,
        mock_run,
        _mock_screenshot,
        _mock_accessibility,
    ) -> None:
        mock_run.return_value = SimpleNamespace(returncode=0, stdout="Reset keychain", stderr="")

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
