import json
import subprocess
import tempfile
import unittest
from pathlib import Path


class DocumentAuditE2ETest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tmpdir.name)
        (self.root / "Taxes").mkdir()
        (self.root / "Health").mkdir()
        (self.root / "Taxes" / "2024-return.pdf").write_text("return")
        (self.root / "Taxes" / "scan.pdf").write_text("scan1")
        (self.root / "Health" / "scan.pdf").write_text("scan2")
        self.scripts_dir = Path(__file__).resolve().parents[1] / "scripts"

    def tearDown(self):
        self.tmpdir.cleanup()

    def run_script(self, name: str):
        output = subprocess.check_output(
            ["python3", str(self.scripts_dir / name), str(self.root)],
            text=True,
        )
        return json.loads(output)

    def test_reports_surface_core_inventory_signals(self):
        inventory = self.run_script("inventory_tree.py")
        extension_summary = self.run_script("extension_summary.py")
        duplicates = self.run_script("duplicate_name_report.py")

        inventory_paths = {entry["path"] for entry in inventory["entries"]}
        self.assertIn(".", inventory_paths)
        self.assertIn("Taxes", inventory_paths)
        self.assertIn("Health", inventory_paths)

        extension_counts = {item["extension"]: item["count"] for item in extension_summary["extensions"]}
        self.assertEqual(extension_counts["pdf"], 3)

        self.assertEqual(len(duplicates["duplicate_groups"]), 1)
        self.assertEqual(duplicates["duplicate_groups"][0]["basename"], "scan.pdf")


if __name__ == "__main__":
    unittest.main()
