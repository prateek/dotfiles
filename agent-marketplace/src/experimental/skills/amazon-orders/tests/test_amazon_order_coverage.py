import json
from pathlib import Path
import subprocess
import sys
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/order-coverage.py"


class AmazonOrderCoverageTests(unittest.TestCase):
    def run_coverage(self, value, *args):
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            input=json.dumps(value), text=True, capture_output=True, timeout=5,
        )

    def test_date_bounds_preserve_unknown_and_missing_field_counts(self):
        rows = [
            {"id": "older", "date_iso": "2024-10-10", "total": "$2", "items": []},
            {"id": "lower", "date_iso": "2024-10-11", "items": [{"title": "PRIVATE"}]},
            {"id": "upper", "date_iso": "2026-10-11", "total": "$3", "items": []},
            {"id": "newer", "date_iso": "2026-10-12", "items": []},
            {"id": "undated", "items": [{"asin": "EXAMPLE"}]},
        ]
        result = self.run_coverage(rows, "--since", "2024-10-11", "--until", "2026-10-11")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {
            "stored_orders": 5,
            "stored_date_min": "2024-10-10", "stored_date_max": "2026-10-12",
            "undated_orders": 1,
            "selection_since": "2024-10-11", "selection_until": "2026-10-11",
            "selected_orders": 2, "selected_items": 1,
            "orders_missing_total": 1, "orders_missing_items": 1,
            "items_missing_asin": 1,
        })

    def test_unbounded_query_includes_undated_orders(self):
        result = self.run_coverage([{"id": "PRIVATE", "items": None}])
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["selected_orders"], 1)
        self.assertEqual(report["undated_orders"], 1)
        self.assertNotIn("PRIVATE", result.stdout + result.stderr)

    def test_empty_upstream_results(self):
        for value in (None, []):
            with self.subTest(value=value):
                result = self.run_coverage(value)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout)["stored_orders"], 0)

    def test_malformed_records_fail_without_disclosing_values(self):
        for row in (
            {}, {"id": 123}, {"id": "PRIVATE", "date_iso": False},
            {"id": "PRIVATE", "date_iso": "PRIVATE"},
            {"id": "PRIVATE", "items": False}, {"id": "PRIVATE", "items": {}},
            {"id": "PRIVATE", "total": {"PRIVATE": 1}},
            {"id": "PRIVATE", "items": [{"asin": ["PRIVATE"]}]},
        ):
            with self.subTest(row=row):
                result = self.run_coverage([row])
                self.assertEqual(result.returncode, 2)
                self.assertIn("stdin must be valid amz orders JSON", result.stderr)
                self.assertEqual(result.stdout, "")
                self.assertNotIn("PRIVATE", result.stderr)


if __name__ == "__main__":
    unittest.main()
