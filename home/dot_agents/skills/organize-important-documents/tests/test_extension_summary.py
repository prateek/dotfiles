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


class ExtensionSummaryUnitTest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tmpdir.name)
        (self.root / "A").mkdir()
        (self.root / "A" / "passport.pdf").write_text("a")
        (self.root / "A" / "scan.pdf").write_text("b")
        (self.root / "A" / "notes.txt").write_text("c")
        self.module = load_module(
            "extension_summary",
            Path(__file__).resolve().parents[1] / "scripts" / "extension_summary.py",
        )

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_summarize_extensions_counts_files(self):
        payload = self.module.summarize_extensions(self.root)
        counts = {item["extension"]: item["count"] for item in payload["extensions"]}
        self.assertEqual(payload["total_files"], 3)
        self.assertEqual(counts["pdf"], 2)
        self.assertEqual(counts["txt"], 1)


if __name__ == "__main__":
    unittest.main()
