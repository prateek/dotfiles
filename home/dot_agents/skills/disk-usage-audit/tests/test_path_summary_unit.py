from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts" / "apfs_usage_audit.py"
SPEC = importlib.util.spec_from_file_location("apfs_usage_audit", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class PathSummaryUnitTests(unittest.TestCase):
    def test_finalize_summary_reports_lower_bound_when_shared_blocks_dominate(self) -> None:
        stats = MODULE.AggregateStats(
            file_count=12,
            dir_count=3,
            skipped_paths=1,
            logical_bytes=24 * 1024 * 1024,
            allocated_bytes=12 * 1024 * 1024,
            reclaimable_bytes=2 * 1024 * 1024,
            may_share_blocks_files=4,
            shares_all_blocks_files=2,
            clone_members_by_id={111: 2},
            clone_refcnt_by_id={111: 3},
        )

        summary = MODULE.finalize_summary(Path("/tmp/demo"), "directory", stats)

        self.assertAlmostEqual(summary["reclaimable_ratio"], 2 / 12)
        self.assertEqual(summary["fully_contained_clone_groups"], 0)
        self.assertEqual(summary["external_clone_groups"], 1)
        joined_notes = " ".join(summary["notes"]).lower()
        self.assertIn("lower-bound", joined_notes)
        self.assertIn("shared", joined_notes)

    def test_finalize_summary_detects_fully_contained_clone_groups(self) -> None:
        stats = MODULE.AggregateStats(
            file_count=2,
            dir_count=0,
            skipped_paths=0,
            logical_bytes=8 * 1024 * 1024,
            allocated_bytes=8 * 1024 * 1024,
            reclaimable_bytes=0,
            may_share_blocks_files=2,
            shares_all_blocks_files=2,
            clone_members_by_id={222: 2},
            clone_refcnt_by_id={222: 2},
        )

        summary = MODULE.finalize_summary(Path("/tmp/group"), "directory", stats)

        self.assertEqual(summary["fully_contained_clone_groups"], 1)
        self.assertEqual(summary["external_clone_groups"], 0)
        joined_notes = " ".join(summary["notes"]).lower()
        self.assertIn("fully contained", joined_notes)
        self.assertIn("may be higher", joined_notes)

    def test_select_non_overlapping_candidates_drops_nested_children(self) -> None:
        candidates = [
            {"path": "/tmp/root/a", "logical_bytes": 9},
            {"path": "/tmp/root/a/nested", "logical_bytes": 8},
            {"path": "/tmp/root/b", "logical_bytes": 7},
        ]

        selected = MODULE._select_non_overlapping_candidates(candidates, top=3)

        self.assertEqual(
            [candidate["path"] for candidate in selected],
            ["/tmp/root/a", "/tmp/root/b"],
        )


if __name__ == "__main__":
    unittest.main()
