"""Comparison profile creation preserves existing profiles and never migrates data."""

import configparser
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "scripts/firefox/create-vanilla-profile"


class VanillaProfileTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve() / "Firefox"
        self.root.mkdir()
        self.original = b"[General]\nStartWithLastProfile=1\nVersion=2\n\n[Profile0]\nName=Primary\nIsRelative=1\nPath=Profiles/primary\nDefault=1\n\n[InstallABC]\nDefault=Profiles/primary\nLocked=1\n"
        (self.root / "profiles.ini").write_bytes(self.original)
        primary = self.root / "Profiles/primary"
        primary.mkdir(parents=True)
        for name in ["prefs.js", "cookies.sqlite", "places.sqlite", "sessionstore.jsonlz4"]:
            (primary / name).write_bytes(b"private fixture content")
        self.bin = Path(self.temp.name) / "bin"
        self.bin.mkdir()
        self.ps = self.bin / "ps"
        self.ps.write_text("#!/bin/sh\nexit 0\n")
        self.ps.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ["PATH"])

    def run_setup(self, *args):
        return subprocess.run([str(SCRIPT), "--firefox-root", str(self.root), *args],
                              env=self.env, capture_output=True, text=True)

    def snapshot(self):
        return {str(p.relative_to(self.root)): p.read_bytes() for p in self.root.rglob("*") if p.is_file()}

    def test_preview_creation_and_repeat_preserve_primary_and_runtime_data(self):
        before = self.snapshot()
        self.assertEqual(self.run_setup("--dry-run").returncode, 0)
        self.assertEqual(self.snapshot(), before)
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        target = self.root / "Profiles/dotfiles-vanilla-sidebery"
        self.assertEqual({p.name for p in target.iterdir()}, {"user.js", ".dotfiles-vanilla-profile.json"})
        config = configparser.ConfigParser()
        config.read(self.root / "profiles.ini")
        self.assertEqual(config["Profile0"]["default"], "1")
        self.assertEqual(config["InstallABC"]["default"], "Profiles/primary")
        self.assertNotIn("default", config["Profile1"])
        self.assertEqual(config["Profile1"]["name"], "Vanilla + Sidebery")
        for name, value in before.items():
            if name != "profiles.ini":
                self.assertEqual((self.root / name).read_bytes(), value)
        self.assertEqual(target.stat().st_mode & 0o777, 0o700)
        self.assertEqual((target / "user.js").stat().st_mode & 0o777, 0o600)
        (target / "user.js").write_text("// user customization\n")
        (target / "sessionstore.jsonlz4").write_bytes(b"new user tabs")
        after = self.snapshot()
        self.assertEqual(self.run_setup().returncode, 0)
        self.assertEqual(self.snapshot(), after)

    def test_running_firefox_blocks_writes(self):
        self.ps.write_text("#!/bin/sh\nprintf '%s\\n' '/Applications/Firefox.app/Contents/MacOS/firefox'\n")
        before = self.snapshot()
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Quit all Firefox profiles", result.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_existing_name_directory_and_symlink_are_never_adopted(self):
        for kind in ["name", "directory", "symlink"]:
            with self.subTest(kind=kind):
                target = self.root / "Profiles/dotfiles-vanilla-sidebery"
                if kind == "name":
                    (self.root / "profiles.ini").write_bytes(self.original.replace(b"Name=Primary", b"Name=Vanilla + Sidebery"))
                elif kind == "directory":
                    target.mkdir()
                    (target / "user.js").write_text("// foreign settings")
                else:
                    target.symlink_to(self.root / "Profiles/primary", target_is_directory=True)
                before = self.snapshot()
                result = self.run_setup()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.snapshot(), before)
                (self.root / "profiles.ini").write_bytes(self.original)
                if target.is_symlink():
                    target.unlink()
                elif target.exists():
                    (target / "user.js").unlink()
                    target.rmdir()

    def test_interrupted_registration_resumes_without_overwriting_profile(self):
        self.assertEqual(self.run_setup().returncode, 0)
        (self.root / "profiles.ini").write_bytes(self.original)
        target = self.root / "Profiles/dotfiles-vanilla-sidebery"
        (target / "user.js").write_text("// retained after interruption")
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((target / "user.js").read_text(), "// retained after interruption")
        self.assertIn(b"Name=Vanilla + Sidebery", (self.root / "profiles.ini").read_bytes())


if __name__ == "__main__":
    unittest.main()
