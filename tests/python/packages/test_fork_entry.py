import copy
import sys
import tomllib

from tests.support.python import ROOT, RepoTestCase


class ForkEntryTests(RepoTestCase):
    def setUp(self):
        super().setUp()
        self.manifest = self.work / "packages.toml"
        self.manifest.write_bytes((ROOT / "home/.chezmoidata/packages.toml").read_bytes())
        self.original = tomllib.loads(self.manifest.read_text())

    def edit(self, action, name, *args):
        result = self.command([
            sys.executable, str(ROOT / "scripts/packages/fork-lifecycle-entry"),
            action, "--file", str(self.manifest), "--name", name, *args,
        ])
        self.assertEqual(result.stderr, b"")
        return result.stdout

    def test_add_remove_preserve_unrelated_groups_and_repeat_without_churn(self):
        self.assertIn(b"added prateek/tap/x-fork", self.edit(
            "add", "prateek/tap/x-fork", "--kind", "cask", "--replaces", "x"))
        expected = copy.deepcopy(self.original)
        entries = expected["packages"]["groups"]["forks"]["entries"]
        entries.append({"name": "prateek/tap/x-fork", "kind": "cask", "replaces": "x"})
        self.assertEqual(tomllib.loads(self.manifest.read_text()), expected)

        before = self.manifest.read_bytes()
        self.assertIn(b"already listed", self.edit("add", "prateek/tap/x-fork", "--kind", "cask"))
        self.assertEqual(self.manifest.read_bytes(), before)

        self.edit("add", "prateek/tap/y-fork", "--kind", "formula")
        entries.append({"name": "prateek/tap/y-fork", "kind": "formula"})
        self.assertEqual(tomllib.loads(self.manifest.read_text()), expected)
        self.assertIn(b"removed prateek/tap/x-fork", self.edit("remove", "prateek/tap/x-fork"))
        entries.remove({"name": "prateek/tap/x-fork", "kind": "cask", "replaces": "x"})
        self.assertEqual(tomllib.loads(self.manifest.read_text()), expected)

        before = self.manifest.read_bytes()
        self.assertIn(b"not listed", self.edit("remove", "prateek/tap/x-fork"))
        self.assertEqual(self.manifest.read_bytes(), before)
