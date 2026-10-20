"""Scoring and exit-status checks for the shared trigger-eval runner."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


RUNNER = Path(__file__).resolve().parents[1] / "scripts/trigger-eval/trigger_eval.py"

# Emits Claude's stream-json for one turn. The query's first word picks the
# first tool: "pick:<skill>" selects that skill, "tool:<name>" calls a tool.
FAKE_CLAUDE = r"""#!/usr/bin/env python3
import json, sys
query = sys.argv[sys.argv.index("-p") + 1]
kind, _, value = query.split()[0].partition(":")
def emit(event):
    print(json.dumps(event), flush=True)
emit({"type": "system", "subtype": "init", "model": "fake-model"})
if kind == "pick":
    emit({"type": "stream_event", "event": {"type": "content_block_start",
          "content_block": {"type": "tool_use", "name": "Skill"}}})
    emit({"type": "stream_event", "event": {"type": "content_block_delta",
          "delta": {"type": "input_json_delta", "partial_json": json.dumps({"skill": value})}}})
else:
    emit({"type": "stream_event", "event": {"type": "content_block_start",
          "content_block": {"type": "tool_use", "name": value}}})
"""


class TriggerEvalTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="trigger-eval-", dir="/tmp")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        (self.root / "bin").mkdir()
        claude = self.root / "bin/claude"
        claude.write_text(FAKE_CLAUDE)
        claude.chmod(0o755)

    def run_cases(self, cases):
        eval_set = self.root / "cases.json"
        eval_set.write_text(json.dumps(cases))
        env = {**os.environ, "PATH": f"{self.root / 'bin'}:{os.environ['PATH']}"}
        result = subprocess.run(
            [sys.executable, "-B", str(RUNNER), "--skill", "plug:target-skill",
             "--eval-set", str(eval_set), "--runs", "2", "--workers", "2", "--timeout", "30"],
            cwd=self.root, env=env, capture_output=True, text=True, check=False,
        )
        return result.returncode, json.loads(result.stdout)

    def test_all_expectations_met_exits_zero(self):
        status, output = self.run_cases([
            {"query": "pick:plug:target-skill read the source", "should_trigger": True},
            {"query": "pick:plug:sibling run a search", "should_trigger": False},
            {"query": "tool:Bash list files", "should_trigger": False},
        ])
        self.assertEqual(status, 0)
        self.assertEqual(output["skill"], "plug:target-skill")
        self.assertEqual(output["summary"], {"total": 3, "passed": 3, "failed": 0})
        first_tools = [result["first_tools"] for result in output["results"]]
        self.assertEqual(first_tools, [["target", "target"], ["skill:plug:sibling"] * 2, ["Bash", "Bash"]])

    def test_a_missed_positive_exits_nonzero(self):
        status, output = self.run_cases([
            {"query": "pick:plug:sibling read the source", "should_trigger": True},
        ])
        self.assertEqual(status, 1)
        self.assertEqual(output["summary"]["failed"], 1)

    def test_a_false_trigger_exits_nonzero(self):
        status, output = self.run_cases([
            {"query": "pick:plug:target-skill search the web", "should_trigger": False},
        ])
        self.assertEqual(status, 1)
        self.assertFalse(output["results"][0]["pass"])


if __name__ == "__main__":
    unittest.main()
