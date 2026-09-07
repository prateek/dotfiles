import sys
import unittest
from pathlib import Path


SKILL_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_ROOT = SKILL_ROOT / "scripts"
sys.path.insert(0, str(SCRIPTS_ROOT))

from ux.workflow_matrix import (  # noqa: E402
    normalize_device_matrix,
    summarize_device_coverage,
    validate_workflow_devices,
    workflow_lane_ids,
)
from collect.ux import _workflow_matrix_summary  # noqa: E402


class WorkflowMatrixTests(unittest.TestCase):
    def test_selects_requested_workflow_lanes(self) -> None:
        lanes = normalize_device_matrix(
            {
                "device_matrix": [
                    {"id": "iphone", "device": "iPhone 16 Pro", "traits": ["compact"], "default": True},
                    {"id": "ipad", "device": "iPad Pro 13-inch (M4)", "traits": ["regular", "ipad"]},
                ]
            }
        )

        selected = workflow_lane_ids({"name": "Playback", "devices": ["iphone", "ipad"]}, lanes)

        self.assertEqual(selected, ["iphone", "ipad"])

    def test_flags_unknown_lane_references(self) -> None:
        lanes = normalize_device_matrix({"device_matrix": [{"id": "iphone", "device": "iPhone 16 Pro"}]})

        errors = validate_workflow_devices([{"name": "Playback", "devices": ["ipad"]}], lanes)

        self.assertEqual(len(errors), 1)
        self.assertIn("ipad", errors[0])

    def test_reports_adaptive_coverage_gaps_when_only_compact_lane_runs(self) -> None:
        lanes = normalize_device_matrix(
            {
                "device_matrix": [
                    {"id": "iphone", "device": "iPhone 16 Pro", "traits": ["compact"], "default": True},
                    {"id": "ipad", "device": "iPad Pro 13-inch (M4)", "traits": ["regular", "ipad"]},
                ]
            }
        )
        workflows = [{"name": "Browse", "devices": ["iphone"]}]
        flow_results = {
            "results": {
                "workflows": [
                    {
                        "name": "Browse",
                        "device_lane": "iphone",
                        "device_traits": ["compact"],
                    }
                ]
            }
        }

        summary = summarize_device_coverage(
            lanes=lanes,
            workflows=workflows,
            flow_results=flow_results,
            adaptive_signals=[{"path": "MoviesDo/Features/MainTab/MainTabView.swift", "line": 23}],
        )

        self.assertTrue(summary["adaptive_ui_detected"])
        self.assertIn("regular-width", " ".join(summary["coverage_gaps"]))
        self.assertIn("only one device lane", " ".join(summary["coverage_gaps"]))

    def test_promotes_adaptive_coverage_gaps_to_validation_errors(self) -> None:
        summary = _workflow_matrix_summary(
            {
                "device_matrix": [
                    {"id": "iphone", "device": "iPhone 16 Pro", "traits": ["compact"], "default": True},
                    {"id": "ipad", "device": "iPad Pro 13-inch (M4)", "traits": ["regular", "ipad"]},
                ],
                "workflows": [{"name": "Browse", "devices": ["iphone"]}],
            },
            [{"path": "MoviesDo/Features/MainTab/MainTabView.swift", "line": 23}],
            {
                "results": {
                    "workflows": [
                        {
                            "name": "Browse",
                            "device_lane": "iphone",
                            "device_traits": ["compact"],
                        }
                    ]
                }
            },
        )

        self.assertIn("regular-width", " ".join(summary["validation_errors"]))
        self.assertIn("only one device lane", " ".join(summary["validation_errors"]))


if __name__ == "__main__":
    unittest.main()
