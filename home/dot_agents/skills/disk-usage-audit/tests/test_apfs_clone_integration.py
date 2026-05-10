from __future__ import annotations

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts" / "apfs_usage_audit.py"
SPEC = importlib.util.spec_from_file_location("apfs_usage_audit", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class ApfsCloneIntegrationTests(unittest.TestCase):
    def test_probe_file_reports_clone_metadata_for_full_clone(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            source = Path(tmpdir) / "source.bin"
            clone = Path(tmpdir) / "clone.bin"

            subprocess.run(
                ["dd", "if=/dev/zero", f"of={source}", "bs=1m", "count=4"],
                check=True,
                capture_output=True,
                text=True,
            )
            subprocess.run(["cp", "-c", str(source), str(clone)], check=True)

            source_metrics = MODULE.probe_path(source)
            clone_metrics = MODULE.probe_path(clone)

            self.assertEqual(source_metrics.clone_id, clone_metrics.clone_id)
            self.assertGreaterEqual(source_metrics.clone_refcnt, 2)
            self.assertTrue(source_metrics.may_share_blocks)
            self.assertTrue(clone_metrics.may_share_blocks)
            self.assertEqual(source_metrics.reclaimable_bytes, 0)
            self.assertEqual(clone_metrics.reclaimable_bytes, 0)


if __name__ == "__main__":
    unittest.main()
