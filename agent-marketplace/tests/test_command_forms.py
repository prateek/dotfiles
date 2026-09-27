from __future__ import annotations

import re
import shutil
import subprocess
import unittest
from pathlib import Path


PATCH = Path(__file__).resolve().parents[1] / "packages/utils-agent/patches/002-agent-slack-command-forms.patch"


def card_lines() -> list[str]:
    added = [line[1:] for line in PATCH.read_text().splitlines() if line.startswith("+") and not line.startswith("+++")]
    start = added.index("```bash", added.index("## Command forms"))
    end = added.index("```", start + 1)
    return added[start + 1:end]


class AgentSlackCommandFormsTests(unittest.TestCase):
    """The patched command card must match the installed CLI; drift makes agents guess flags."""

    def setUp(self):
        self.binary = shutil.which("agent-slack")
        if not self.binary:
            self.skipTest("agent-slack is not installed")

    def test_every_documented_command_and_flag_exists(self):
        lines = card_lines()
        self.assertTrue(lines)
        for line in lines:
            group, command = line.split()[1:3]
            result = subprocess.run([self.binary, group, command, "--help"], capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, f"{line}: {result.stderr}")
            self.assertIn(f"agent-slack {group} {command}", result.stdout, line)
            for flag in re.findall(r"--[a-z][a-z-]+", line):
                self.assertIn(flag, result.stdout, f"{line}: {flag} missing from installed help")


if __name__ == "__main__":
    unittest.main()
