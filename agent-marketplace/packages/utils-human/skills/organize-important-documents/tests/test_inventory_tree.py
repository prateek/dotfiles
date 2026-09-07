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


class InventoryTreeUnitTest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tmpdir.name)
        (self.root / "Taxes").mkdir()
        (self.root / "Taxes" / "2024.pdf").write_text("return")
        (self.root / "Health").mkdir()
        (self.root / "Health" / "claim.pdf").write_text("claim")
        (self.root / ".hidden").mkdir()
        (self.root / ".hidden" / "ignore.txt").write_text("ignore")
        self.module = load_module(
            "inventory_tree",
            Path(__file__).resolve().parents[1] / "scripts" / "inventory_tree.py",
        )

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_build_inventory_skips_hidden_paths_by_default(self):
        entries = self.module.build_inventory(self.root, max_depth=2, include_hidden=False)
        paths = {entry.path for entry in entries}
        self.assertIn(".", paths)
        self.assertIn("Taxes", paths)
        self.assertNotIn(".hidden", paths)

        root_entry = next(entry for entry in entries if entry.path == ".")
        self.assertEqual(root_entry.total_file_count, 2)


if __name__ == "__main__":
    unittest.main()
