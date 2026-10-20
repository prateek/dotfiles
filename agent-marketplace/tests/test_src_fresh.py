"""Freshness decisions of the src skill's helper, against substitute ask and gh."""

import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


HELPER = Path(__file__).resolve().parents[1] / "src/utils-agent/skills/src/scripts/fresh"

# ask: `--no-fetch` prints the entry when it exists; a fetch creates it and logs.
FAKE_ASK = """#!/bin/sh
store=$FIXTURE_STORE
entry=$store/github/github.com/acme/widget/${FIXTURE_REF:-main}
[ -n "${FIXTURE_ASK_PATH:-}" ] && entry=$FIXTURE_ASK_PATH
if [ "$2" = --no-fetch ]; then
  [ -d "$entry" ] && { echo "$entry"; exit 0; }
  echo "no cached checkout" >&2; exit 1
fi
echo fetch >> "$store/ask.log"
mkdir -p "$entry" && : > "$entry/.ask-hash"
echo "$entry"
"""

# gh: logs each call; answers the default branch and the head commit date.
FAKE_GH = """#!/bin/sh
echo "$2" >> "$FIXTURE_STORE/gh.log"
[ -n "${FIXTURE_GH_FAIL:-}" ] && exit 1
case $2 in
  */commits/*) echo "$FIXTURE_HEAD" ;;
  *) echo main ;;
esac
"""


class FreshTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="src-fresh-", dir="/tmp")
        self.addCleanup(temp.cleanup)
        self.store = Path(temp.name)
        bin_dir = self.store / "bin"
        bin_dir.mkdir()
        for name, body in (("ask", FAKE_ASK), ("gh", FAKE_GH)):
            (bin_dir / name).write_text(body)
            (bin_dir / name).chmod(0o755)
        self.entry = self.store / "github/github.com/acme/widget/main"
        self.env = {
            **os.environ,
            "PATH": f"{bin_dir}:{os.environ['PATH']}",
            "FIXTURE_STORE": str(self.store),
            "FIXTURE_HEAD": "2026-10-10T12:00:00Z",
        }

    def cache(self, fetched_at):
        self.entry.mkdir(parents=True)
        (self.entry / "marker").write_text("cached")
        stamp = self.entry / ".ask-hash"
        stamp.write_text("sha256-x")
        os.utime(stamp, (fetched_at, fetched_at))

    def run_fresh(self, spec="github:acme/widget", **env):
        return subprocess.run(
            [str(HELPER), spec], env={**self.env, **env}, capture_output=True, text=True, check=False
        )

    def log(self, name):
        path = self.store / name
        return path.read_text().split() if path.exists() else []

    def test_missing_entry_is_fetched(self):
        result = self.run_fresh()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), str(self.entry))
        self.assertEqual(self.log("ask.log"), ["fetch"])

    def test_young_entry_is_served_without_github(self):
        self.cache(time.time() - 60)
        result = self.run_fresh()
        self.assertEqual(result.stdout.strip(), str(self.entry))
        self.assertEqual(self.log("gh.log"), [])
        self.assertEqual(self.log("ask.log"), [])

    def test_old_entry_on_moved_branch_is_refetched(self):
        self.cache(time.mktime((2026, 10, 1, 0, 0, 0, 0, 0, -1)))
        result = self.run_fresh()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("refetching", result.stderr)
        self.assertEqual(self.log("ask.log"), ["fetch"])
        self.assertFalse((self.entry / "marker").exists())

    def test_old_entry_on_unchanged_branch_is_kept_and_restamped(self):
        fetched = time.mktime((2026, 10, 15, 0, 0, 0, 0, 0, -1))
        self.cache(fetched)
        result = self.run_fresh("github:acme/widget@main")
        self.assertEqual(result.stdout.strip(), str(self.entry))
        self.assertTrue((self.entry / "marker").exists())
        self.assertGreater((self.entry / ".ask-hash").stat().st_mtime, fetched)
        self.assertEqual(self.log("gh.log"), ["repos/acme/widget/commits/main"])

    def test_unreachable_github_serves_the_cache_with_a_warning(self):
        self.cache(time.mktime((2026, 10, 1, 0, 0, 0, 0, 0, -1)))
        result = self.run_fresh(FIXTURE_GH_FAIL="1")
        self.assertEqual(result.stdout.strip(), str(self.entry))
        self.assertIn("freshness unchecked", result.stderr)
        self.assertTrue((self.entry / "marker").exists())

    def test_path_outside_the_specs_store_is_never_deleted(self):
        stray = self.store / "elsewhere"
        stray.mkdir()
        (stray / ".ask-hash").write_text("x")
        os.utime(stray / ".ask-hash", (0, 0))
        result = self.run_fresh(FIXTURE_ASK_PATH=str(stray))
        self.assertEqual(result.returncode, 1)
        self.assertIn("unexpected checkout path", result.stderr)
        self.assertTrue(stray.exists())

    def test_non_github_spec_is_rejected(self):
        result = self.run_fresh("npm:zod")
        self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
