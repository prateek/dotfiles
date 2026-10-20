import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
RUNNER = ROOT / 'scripts/doc-coauthoring-evals'
FIXTURE_PLAN = ROOT / 'agent-marketplace/src/core/skills/doc-coauthoring/evals/files/accretion/docs/plans/export-plan.md'

EVERGREEN = '''# JSON export

Owner: Rowan.

## Design

`render_rows` emits one JSON object per line and nothing for no rows. `--format`
values are lower-case only; the parser owns the format name and `render_rows`
stays free of argparse.

## Acceptance

`python3 -m unittest discover -s tests` passes with the new cases.

## Progress

- 2026-10-20: Rowan reviewed the plan; nothing is implemented. TSV output and
  its header row were dropped and the array form was replaced.
'''

ACCRETED = EVERGREEN.replace(
    '## Acceptance',
    '## Notes\n\nThe array form is no longer used. TSV output needs an escaping policy for tabs,\n'
    'as requested in the review comments.\n\n## Acceptance',
)


def grade(text_or_path):
    with tempfile.TemporaryDirectory() as directory:
        path = Path(text_or_path) if isinstance(text_or_path, Path) else Path(directory) / 'plan.md'
        if not isinstance(text_or_path, Path):
            path.write_text(text_or_path)
        result = subprocess.run([sys.executable, str(RUNNER), 'grade', str(path)], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    return json.loads(result.stdout)


class DocCoauthoringEvalsGradeTest(unittest.TestCase):
    def test_fixture_plan_fails_on_the_array_decision_it_predates(self):
        metrics = grade(FIXTURE_PLAN)
        self.assertFalse(metrics['deterministic_pass'])
        self.assertTrue(metrics['owner_present'])
        self.assertFalse(metrics['progress_section'])
        self.assertTrue(metrics['stale_array'])
        self.assertEqual(metrics['stale_tsv'], [])
        self.assertEqual(metrics['history'], [])

    def test_evergreen_plan_passes_and_progress_is_exempt(self):
        metrics = grade(EVERGREEN)
        self.assertTrue(metrics['deterministic_pass'], metrics)
        self.assertTrue(metrics['progress_dated'])
        self.assertEqual(metrics['stale_tsv'], [])
        self.assertEqual(metrics['stale_array'], [])
        self.assertEqual(metrics['history'], [])
        self.assertTrue(metrics['lower_case_rule'] and metrics['argparse_rule'] and metrics['unittest_command'])
        self.assertEqual(metrics['ndjson_lines'], 1)

    def test_accreted_body_is_flagged_line_by_line(self):
        metrics = grade(ACCRETED)
        self.assertFalse(metrics['deterministic_pass'])
        self.assertEqual(len(metrics['stale_array']), 1)
        self.assertEqual(len(metrics['stale_tsv']), 1)
        self.assertEqual(len(metrics['history']), 2)
        self.assertEqual(len(metrics['escaping_lines']), 1)
        self.assertIn('no longer', metrics['history'][0])
        self.assertGreater(metrics['body_words'], grade(EVERGREEN)['body_words'])

    def test_legitimate_text_is_not_flagged(self):
        plan = EVERGREEN.replace(
            '## Acceptance',
            '## Checks\n\n`parse_args([]).format == "text"` stays true and `render_rows([], "json")` returns\n'
            'an empty string. Names may contain tabs and newlines; `json.dumps` is used to\n'
            'escape them.\n\n## Acceptance',
        )
        metrics = grade(plan)
        self.assertEqual(metrics['stale_array'], [])
        self.assertEqual(metrics['stale_tsv'], [])
        self.assertEqual(metrics['history'], [])
        self.assertTrue(metrics['deterministic_pass'], metrics)

    def test_sections_after_progress_are_still_checked(self):
        metrics = grade(EVERGREEN + '\n## Notes\n\nTSV output was dropped per the review.\n')
        self.assertTrue(metrics['progress_dated'])
        self.assertEqual(len(metrics['stale_tsv']), 1)
        self.assertEqual(len(metrics['history']), 1)
        self.assertFalse(metrics['deterministic_pass'])


if __name__ == '__main__':
    unittest.main()
