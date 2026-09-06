import hashlib
import shutil
import sys
from pathlib import Path

from tests.support.python import ROOT, RepoTestCase


class VendorPatchTests(RepoTestCase):
    packages = ROOT / "home/dot_agents/packages"
    apply = ROOT / ".agents/skills/agent-skill-management/scripts/apply-vendor-patches"

    def patches(self):
        patches = sorted(self.packages.glob("*/patches/*/**/*.patch"))
        self.assertTrue(patches, "the applied-patch gate needs at least one patch")
        return patches

    def test_committed_patches_are_applied(self):
        self.patches()
        result = self.command([sys.executable, str(self.apply), "--check"])
        self.assertIn(b"OK apply-vendor-patches", result.stdout)
        self.assertEqual(result.stderr, b"")

    def test_patches_keep_upstream_paths_for_unmodified_submission(self):
        for patch in self.patches():
            with self.subTest(patch=patch.relative_to(self.packages)):
                targets = [line[6:] for line in patch.read_text().splitlines() if line.startswith("+++ b/")]
                self.assertTrue(any(target.startswith("integrations/") for target in targets))
                self.assertFalse(any(target.startswith("home/") for target in targets))

    def test_reverse_reaches_recorded_pristine_and_reapply_restores_every_package_byte(self):
        work = self.work / "repo"
        copied = work / "home/dot_agents/packages"
        shutil.copytree(self.packages, copied, symlinks=True)
        self.command(["git", "init", "-q", str(work)])
        for patch in reversed(self.patches()):
            relative = patch.relative_to(self.packages)
            package, _, skill, *_ = relative.parts
            target = next(line[6:] for line in patch.read_text().splitlines() if line.startswith("+++ b/"))
            depth = Path(target).parts.index(skill) + 2
            directory = f"home/dot_agents/packages/{package}/skills/vendor/{skill}"
            self.command(["git", "apply", "--reverse", f"-p{depth}", f"--directory={directory}", str(patch)], cwd=work)
        args = [sys.executable, str(self.apply), "--packages-root", str(copied)]
        result = self.command([*args, "--check"], expected_status=1, cwd=work)
        self.assertIn(b"not applied to", result.stderr)

        hashes = sorted(self.packages.glob("*/patches/*/pristine.sha256"))
        self.assertTrue(hashes, "pristine hashes are the independent witness")
        for hashfile in hashes:
            package, _, skill, _ = hashfile.relative_to(self.packages).parts
            reverted = copied / package / "skills/vendor" / skill / "SKILL.md"
            self.assertEqual(hashlib.sha256(reverted.read_bytes()).hexdigest(), hashfile.read_text().split()[0], skill)
        for extra in ([], ["--check"]):
            result = self.command([*args, *extra], cwd=work)
            self.assertIn(b"OK apply-vendor-patches", result.stdout)
            self.assertEqual(result.stderr, b"")
        original_paths = {path.relative_to(self.packages) for path in self.packages.rglob("*")}
        self.assertEqual(original_paths, {path.relative_to(copied) for path in copied.rglob("*")})
        for relative in original_paths:
            original, actual = self.packages / relative, copied / relative
            if original.is_symlink():
                self.assertEqual(original.readlink(), actual.readlink(), str(relative))
            elif original.is_file():
                self.assertEqual(original.read_bytes(), actual.read_bytes(), str(relative))
            else:
                self.assertTrue(actual.is_dir(), str(relative))
