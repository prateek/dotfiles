import sys
import unittest
from pathlib import Path


SKILL_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_ROOT = SKILL_ROOT / "scripts"
sys.path.insert(0, str(SCRIPTS_ROOT))

from common.idb_utils import normalize_accessibility_tree  # noqa: E402


class NormalizeAccessibilityTreeTests(unittest.TestCase):
    def test_wraps_multiple_nested_roots_in_synthetic_application_node(self) -> None:
        tree = normalize_accessibility_tree(
            [
                {
                    "type": "Window",
                    "AXLabel": "Movies.do",
                    "frame": {"x": 0, "y": 0, "width": 390, "height": 780},
                    "children": [{"type": "NavigationBar", "AXLabel": "Home"}],
                },
                {
                    "type": "Window",
                    "frame": {"x": 0, "y": 780, "width": 390, "height": 64},
                    "children": [{"type": "TabBar", "children": [{"type": "Button", "AXLabel": "Browse"}]}],
                },
            ],
            nested=True,
        )

        self.assertEqual(tree["type"], "Application")
        self.assertEqual(len(tree["children"]), 2)
        self.assertEqual(tree["children"][1]["children"][0]["type"], "TabBar")
        self.assertEqual(tree["frame"], {"x": 0, "y": 0, "width": 390, "height": 844})


if __name__ == "__main__":
    unittest.main()
