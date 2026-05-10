import sys
import unittest
from pathlib import Path


SKILL_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_ROOT = SKILL_ROOT / "scripts"
sys.path.insert(0, str(SCRIPTS_ROOT))

from collect.code_health import extract_numeric_literals, summarize_magic_literals  # noqa: E402


class CodeHealthMagicLiteralTests(unittest.TestCase):
    def test_extracts_nontrivial_numeric_literals(self) -> None:
        text = """
        let hd = 1080
        let sd = 480
        let ignored = 1
        let opacity = 0.5
        """

        literals = extract_numeric_literals(text)

        self.assertEqual(literals, ["1080", "480", "0.5"])

    def test_clusters_repeated_magic_literals(self) -> None:
        occurrences = {
            "2160": [
                {"path": "A.swift", "line": 10},
                {"path": "B.swift", "line": 20},
                {"path": "C.swift", "line": 30},
            ],
            "16": [
                {"path": "Spacing.swift", "line": 4},
                {"path": "Spacing.swift", "line": 5},
            ],
        }

        summary = summarize_magic_literals(occurrences, min_hits=3, top_n=5)

        self.assertEqual(len(summary), 1)
        self.assertEqual(summary[0]["literal"], "2160")
        self.assertEqual(summary[0]["count"], 3)


if __name__ == "__main__":
    unittest.main()
