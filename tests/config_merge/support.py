"""Real plist subprocesses and rendering shared by engine and app contracts."""

import base64
import math
import plistlib
import subprocess
from xml.parsers.expat import ExpatError

from tests.support.python import ROOT, RepoTestCase


class PlistTestCase(RepoTestCase):
    def setUp(self):
        super().setUp()
        for key in ("CHEZMOI_VERBOSE", "DOTFILES_PLIST_VERBOSE"):
            self.env.pop(key, None)

    def plist_command(self, argv, raw=b"", *, error=None, env=None):
        result = subprocess.run(
            argv,
            input=raw,
            capture_output=True,
            check=False,
            env=self.env | (env or {}),
            cwd=ROOT,
        )
        stderr = result.stderr.decode(errors="replace")
        detail = f"{argv[0]} exited {result.returncode}\nstderr:\n{stderr}"
        if error is not None:
            self.assertNotEqual(result.returncode, 0, detail)
            self.assertEqual(
                result.stdout, b"", "failure must not emit a replacement plist"
            )
            self.assertIn(error, stderr, detail)
        else:
            self.assertEqual(result.returncode, 0, detail)
            self.assertEqual(stderr, "", detail)
        return result.stdout

    def merge(self, desired_xml, raw, **kwargs):
        return self.plist_command(
            [
                str(ROOT / "scripts/macos/plist-merge"),
                "--bundle-id",
                "test.config-merge",
                "--desired-b64",
                base64.b64encode(desired_xml).decode(),
            ],
            raw,
            **kwargs,
        )

    def modifier(self, bundle_id):
        script = self.work / f"{bundle_id}.sh"
        script.write_bytes(
            self.render(
                f"home/Library/private_Preferences/modify_private_{bundle_id}.plist.tmpl"
            )
        )
        script.chmod(0o700)
        self.plist_command(["bash", "-n", str(script)])
        return [str(script)]

    def assert_plist(self, raw, expected):
        try:
            actual = plistlib.loads(raw)
        except (plistlib.InvalidFileException, ExpatError, ValueError) as exc:
            self.fail(f"stdout is not a plist: {exc}; first 120 bytes: {raw[:120]!r}")
        self.assert_typed_equal(actual, expected)
        return actual

    def assert_typed_equal(self, actual, expected, location="$"):
        self.assertIs(
            type(actual), type(expected), f"{location}: different value types"
        )
        if isinstance(expected, dict):
            self.assertEqual(
                actual.keys(), expected.keys(), f"{location}: different keys"
            )
            for key in expected:
                self.assert_typed_equal(
                    actual[key], expected[key], f"{location}[{key!r}]"
                )
        elif isinstance(expected, list):
            self.assertEqual(
                len(actual), len(expected), f"{location}: different lengths"
            )
            for index, (value, expected_value) in enumerate(zip(actual, expected)):
                self.assert_typed_equal(value, expected_value, f"{location}[{index}]")
        elif isinstance(expected, float) and math.isnan(expected):
            self.assertTrue(math.isnan(actual), location)
        else:
            self.assertEqual(actual, expected, location)
