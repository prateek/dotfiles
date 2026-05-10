from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "apfs_usage_audit.py"


class ApfsUsageCliTests(unittest.TestCase):
    def test_validate_top_distinguishes_unique_and_shared_candidates(self) -> None:
        with tempfile.TemporaryDirectory() as root_tmpdir, tempfile.TemporaryDirectory() as external_tmpdir:
            root = Path(root_tmpdir).resolve()
            unique_dir = (root / "unique").resolve()
            shared_dir = (root / "shared").resolve()
            unique_dir.mkdir()
            shared_dir.mkdir()

            unique_file = unique_dir / "owned.bin"
            external_source = Path(external_tmpdir) / "source.bin"
            shared_clone = shared_dir / "clone.bin"

            subprocess.run(
                ["dd", "if=/dev/zero", f"of={unique_file}", "bs=1m", "count=3"],
                check=True,
                capture_output=True,
                text=True,
            )
            subprocess.run(
                ["dd", "if=/dev/zero", f"of={external_source}", "bs=1m", "count=4"],
                check=True,
                capture_output=True,
                text=True,
            )
            subprocess.run(["cp", "-c", str(external_source), str(shared_clone)], check=True)

            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "validate-top",
                    str(root),
                    "--depth",
                    "1",
                    "--top",
                    "2",
                    "--json",
                ],
                check=False,
                capture_output=True,
                text=True,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            payload = json.loads(result.stdout)
            summaries = {entry["path"]: entry for entry in payload["validated_paths"]}
            merged = {entry["path"]: entry for entry in payload["validated_candidates"]}

            self.assertGreater(summaries[str(unique_dir)]["reclaimable_bytes"], 0)
            self.assertEqual(summaries[str(shared_dir)]["reclaimable_bytes"], 0)
            self.assertGreater(summaries[str(shared_dir)]["external_clone_groups"], 0)
            self.assertIn(payload["discovery"]["tool"], {"du", "gdu"})
            logical = {entry["path"]: entry for entry in payload["logical_candidates"]}
            self.assertEqual(
                merged[str(unique_dir)]["du_candidate_bytes"],
                logical[str(unique_dir)]["du_bytes"],
            )
            self.assertEqual(payload["logical_candidates"][0]["path"], str(shared_dir))
            self.assertGreater(payload["logical_candidates"][0]["du_bytes"], payload["logical_candidates"][1]["du_bytes"])


if __name__ == "__main__":
    unittest.main()
