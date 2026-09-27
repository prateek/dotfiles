import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


HELPER = Path(__file__).resolve().parents[3] / "scripts/1password/find-item"


class FindItemTests(unittest.TestCase):
    def test_exact_lookup_scopes_vault_and_exposes_only_id(self):
        with tempfile.TemporaryDirectory() as directory:
            fake = Path(directory) / "op"
            fake.write_text(
                "#!/usr/bin/env python3\n"
                "import json, sys\n"
                "assert sys.argv[1:] == ['item', 'list', '--vault', 'Devland', '--format=json']\n"
                "print(json.dumps([{'id':'a1','title':'Target','password':'dummy-secret'}, {'id':'a2','title':'Target copy'}]))\n"
            )
            fake.chmod(0o755)
            result = subprocess.run(
                [sys.executable, str(HELPER), "--vault", "Devland", "--title", "Target", "--op-command", str(fake)],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout), {"found": True, "id": "a1"})
            self.assertNotIn("dummy-secret", result.stdout + result.stderr)

    def test_no_match_is_explicit(self):
        with tempfile.TemporaryDirectory() as directory:
            fake = Path(directory) / "op"
            fake.write_text("#!/bin/sh\nprintf '[]\\n'\n")
            fake.chmod(0o755)
            result = subprocess.run(
                [sys.executable, str(HELPER), "--vault", "Devland", "--title", "Missing", "--op-command", str(fake)],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout), {"found": False, "id": None})

    def test_duplicate_titles_fail_without_item_fields(self):
        with tempfile.TemporaryDirectory() as directory:
            fake = Path(directory) / "op"
            fake.write_text("#!/bin/sh\nprintf '%s\\n' '[{\"id\":\"a1\",\"title\":\"Target\",\"password\":\"dummy-secret\"},{\"id\":\"a2\",\"title\":\"Target\"}]'\n")
            fake.chmod(0o755)
            result = subprocess.run(
                [sys.executable, str(HELPER), "--vault", "Devland", "--title", "Target", "--op-command", str(fake)],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 1)
            self.assertEqual(result.stdout, "")
            self.assertNotIn("dummy-secret", result.stderr)


if __name__ == "__main__":
    unittest.main()
