import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


def load_module(module_name: str, path: Path):
    spec = importlib.util.spec_from_file_location(module_name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


class DuplicateNameReportUnitTest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tmpdir.name)
        (self.root / "Taxes").mkdir()
        (self.root / "Immigration").mkdir()
        (self.root / "Taxes" / "scan.pdf").write_text("a")
        (self.root / "Immigration" / "scan.pdf").write_text("b")
        (self.root / "Immigration" / "i94.pdf").write_text("c")
        self.module = load_module(
            "duplicate_name_report",
            Path(__file__).resolve().parents[1] / "scripts" / "duplicate_name_report.py",
        )

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_duplicate_name_report_finds_shared_basenames(self):
        payload = self.module.duplicate_name_report(self.root)
        self.assertEqual(len(payload["duplicate_groups"]), 1)
        group = payload["duplicate_groups"][0]
        self.assertEqual(group["basename"], "scan.pdf")
        self.assertEqual(len(group["occurrences"]), 2)


if __name__ == "__main__":
    unittest.main()
