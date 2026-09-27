from pathlib import Path
import subprocess
import unittest


class SkillRewriteTests(unittest.TestCase):
    def test_native_flow_contracts(self):
        root = Path(__file__).resolve().parents[3]
        result = subprocess.run(
            ["node", "--test", "--test-reporter=tap", "tests/node/skill-rewrite.test.mjs"],
            cwd=root, text=True, capture_output=True, timeout=60,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertRegex(result.stdout, r"# pass [1-9][0-9]*")
