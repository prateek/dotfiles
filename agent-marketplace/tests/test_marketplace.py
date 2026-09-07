from __future__ import annotations

import difflib
import json
import os
from pathlib import Path
import py_compile
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest

import yaml
from apm_cli.utils.content_hash import compute_package_hash


PROJECT = Path(__file__).resolve().parents[1]


def _just_binary():
    resolved = shutil.which("just")
    if resolved and f"{os.sep}shims{os.sep}" in resolved:
        try:
            real = subprocess.run(["mise", "which", "just"], capture_output=True, text=True)
        except OSError:
            return resolved
        if real.returncode == 0 and real.stdout.strip():
            return real.stdout.strip()
    return resolved or "just"


# A shim would resolve its version from the fixture cwd, which has no mise config.
JUST = _just_binary()


class MarketplaceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="marketplace-test-")
        self.addCleanup(self.temp.cleanup)
        self.sandbox = Path(self.temp.name)
        self.root = self.sandbox / "project"
        self.root.mkdir()
        self.fixture_home = self.sandbox / "home"
        self.fixture_home.mkdir()
        self.package = self.root / "packages/example"
        self.skill = self.package / "skills/hello"
        self.skill.mkdir(parents=True)
        (self.skill / "SKILL.md").write_text(
            "---\nname: hello\ndescription: Say hello when asked.\n---\n\nHello.\n"
        )
        helper = self.skill / "hello.sh"
        helper.write_text("#!/bin/sh\nprintf 'hello\\n'\n")
        helper.chmod(0o755)
        codex = self.package / ".codex-plugin/plugin.json"
        codex.parent.mkdir()
        codex.write_text(json.dumps({
            "name": "example", "version": "1.0.0", "skills": "./skills/",
            "description": "Example skills", "license": "UNLICENSED",
            "interface": {"displayName": "Example Skills"},
        }))
        (self.root / "apm.yml").write_text(yaml.safe_dump({
            "name": "fixture-marketplace", "version": "1.0.0", "license": "UNLICENSED",
            "marketplace": {
                "owner": {"name": "Fixture"},
                "outputs": {"claude": {}, "codex": {}},
                "packages": [{"name": "example", "source": "./plugins/example", "category": "Productivity"}],
            },
        }))

    def recipe(self, name, *arguments, success=True, extra_env=None):
        environment = os.environ.copy()
        for key in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR"):
            environment.pop(key, None)
        environment.update(HOME=str(self.fixture_home), XDG_CONFIG_HOME=str(self.fixture_home / ".config"),
                           XDG_CACHE_HOME=str(self.fixture_home / ".cache"), GIT_TERMINAL_PROMPT="0")
        environment["PATH"] = os.pathsep.join(p for p in environment["PATH"].split(os.pathsep) if "/mise/shims" not in p)
        environment.update(extra_env or {})
        result = subprocess.run(
            [JUST, "--justfile", str(PROJECT / "justfile"), "--working-directory", str(self.root),
             "--set", "run", "", "--set", "python", sys.executable,
             "--set", "script", str(PROJECT / "scripts/marketplace.py"), name, *arguments],
            cwd=self.root, env=environment, capture_output=True, text=True, timeout=45,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_build_publishes_authored_skill_and_both_native_catalogs(self):
        self.recipe("build")
        output = self.root / "build/marketplace"
        for catalog in (".claude-plugin/marketplace.json", ".agents/plugins/marketplace.json"):
            data = json.loads((output / catalog).read_text())
            self.assertEqual(data["name"], "fixture-marketplace")
            self.assertEqual([p["name"] for p in data["plugins"]], ["example"])
        plugin = output / "plugins/example"
        self.assertEqual((plugin / "skills/hello/SKILL.md").read_text(),
                         "---\nname: hello\ndescription: Say hello when asked.\n---\n\nHello.\n")
        self.assertEqual((plugin / "skills/hello/hello.sh").stat().st_mode & 0o777, 0o755)
        manifest = json.loads((plugin / ".codex-plugin/plugin.json").read_text())
        self.assertEqual(manifest["interface"]["displayName"], "Example Skills")
        self.assertEqual(json.loads((plugin / ".claude-plugin/plugin.json").read_text())["name"], "example")

    def test_check_and_export_ignore_python_caches_without_following_cache_symlinks(self):
        module = self.imported_skill()
        helper = self.skill / "helper.py"
        helper.write_text("VALUE = 1\n")
        overlay = self.package / "overlays/skills/hello"
        overlay.mkdir(parents=True)
        (overlay / "notes.md").write_text("Authored notes.\n")
        self.recipe("check")
        receipt_path = self.root / "build/marketplace/release.json"
        expected = json.loads(receipt_path.read_text())
        outside = self.sandbox / "outside-source"
        outside.mkdir()
        (outside / "sentinel.txt").write_text("Outside the publication inputs.\n")
        for parent in (self.skill, overlay, module):
            cache = parent / "__pycache__"
            for kind in ("compiled", "symlink"):
                with self.subTest(source=parent.relative_to(self.root), kind=kind):
                    if kind == "compiled":
                        cache.mkdir()
                        py_compile.compile(str(helper), cfile=str(cache / "helper.pyc"), doraise=True)
                    else:
                        cache.symlink_to(outside, target_is_directory=True)
                    try:
                        self.recipe("check")
                        actual = json.loads(receipt_path.read_text())
                        self.assertEqual(actual["source_digest"], expected["source_digest"])
                        self.assertEqual(actual["files"], expected["files"])
                        self.recipe("export")
                        with tarfile.open(self.root / "build/marketplace.tar.gz") as archive:
                            self.assertFalse(any("__pycache__" in Path(name).parts for name in archive.getnames()))
                    finally:
                        if cache.is_symlink():
                            cache.unlink()
                        else:
                            shutil.rmtree(cache)

    def imported_skill(self):
        module = self.root / "apm_modules/example/upstream"
        module.mkdir(parents=True)
        (module / "SKILL.md").write_text(
            "---\nname: upstream\ndescription: An imported skill.\n---\n\nOriginal.\n"
        )
        (module / ".apm-pin").write_text(json.dumps({"schema_version": 1, "resolved_commit": "a" * 40}))
        (self.root / "apm.lock.yaml").write_text(yaml.safe_dump({
            "lockfile_version": "1", "apm_version": "0.29.1",
            "dependencies": [{
                "repo_url": "example/upstream", "host": "github.com",
                "name": "upstream", "resolved_commit": "a" * 40,
                "content_hash": compute_package_hash(module), "is_dev": True,
            }], "deployments": [],
        }))
        manifest = yaml.safe_load((self.root / "apm.yml").read_text())
        manifest["devDependencies"] = {"apm": ["example/upstream"]}
        (self.root / "apm.yml").write_text(yaml.safe_dump(manifest))
        (self.package / "publish.toml").write_text(
            '[[skills]]\nname = "curated"\ndependency = "example/upstream"\npath = "."\n'
        )
        return module

    def test_build_uses_selected_committed_skill_under_its_curated_name(self):
        module = self.imported_skill()
        self.recipe("build")
        published = self.root / "build/marketplace/plugins/example/skills"
        self.assertEqual((published / "curated/SKILL.md").read_text(), (module / "SKILL.md").read_text())
        self.assertFalse((published / "upstream").exists())
        self.assertFalse((published / "curated/.apm-pin").exists())

    def test_shared_root_cache_publishes_independent_plugins_without_package_manifests(self):
        self.imported_skill()
        peer = self.root / "packages/peer"
        (peer / ".codex-plugin").mkdir(parents=True)
        (peer / ".codex-plugin/plugin.json").write_text(json.dumps({
            "name": "peer", "version": "2.0.0", "description": "Peer skills", "skills": "./skills/",
        }))
        (peer / "publish.toml").write_text(
            '[[skills]]\nname = "shared"\ndependency = "example/upstream"\npath = "."\n'
        )
        manifest_path = self.root / "apm.yml"
        manifest = yaml.safe_load(manifest_path.read_text())
        manifest["devDependencies"] = {"apm": ["example/upstream"]}
        manifest["marketplace"]["packages"].append({
            "name": "peer", "source": "./plugins/peer", "category": "Productivity",
        })
        manifest_path.write_text(yaml.safe_dump(manifest))
        patches = self.package / "patches"
        patches.mkdir()
        (patches / "001-reviewed.patch").write_text(
            "--- a/skills/curated/SKILL.md\n+++ b/skills/curated/SKILL.md\n"
            "@@ -4,3 +4,3 @@\n ---\n \n-Original.\n+Reviewed.\n"
        )
        self.recipe("build")
        output = self.root / "build/marketplace"
        self.assertTrue((output / "plugins/example/skills/curated/SKILL.md").read_text().endswith("Reviewed.\n"))
        self.assertFalse((output / "apm.yml").exists())
        self.assertTrue((output / "plugins/peer/skills/shared/SKILL.md").read_text().endswith("Original.\n"))
        self.assertTrue((self.root / "apm_modules/example/upstream/SKILL.md").read_text().endswith("Original.\n"))
        for catalog in (".claude-plugin/marketplace.json", ".agents/plugins/marketplace.json"):
            self.assertEqual({p["name"] for p in json.loads((output / catalog).read_text())["plugins"]}, {"example", "peer"})
        for name, version in (("example", "1.0.0"), ("peer", "2.0.0")):
            for native in (".claude-plugin/plugin.json", ".codex-plugin/plugin.json"):
                self.assertEqual(json.loads((output / "plugins" / name / native).read_text())["version"], version)
            self.assertFalse((self.root / "packages" / name / "apm.yml").exists())
            self.assertFalse((output / "plugins" / name / "apm.yml").exists())

    def test_acquisition_rejects_obsolete_package_scope_before_touching_inputs(self):
        before = (self.root / "apm.yml").read_bytes()
        for target in ("fetch", "update"):
            with self.subTest(target=target):
                result = self.recipe(target, "example", success=False)
                # Acquisition is root-scoped, so a package argument names no recipe.
                self.assertIn("does not contain recipe `example`", result.stderr)
                self.assertEqual((self.root / "apm.yml").read_bytes(), before)
                self.assertFalse((self.root / "apm_modules").exists())
                self.assertFalse((self.root / "apm.lock.yaml").exists())

    def test_check_refuses_missing_skill_entrypoints_without_replacing_the_artifact(self):
        module = self.imported_skill()
        self.recipe("check")
        self.recipe("export")
        receipt = self.root / "build/marketplace/release.json"
        archive = self.root / "build/marketplace.tar.gz"
        accepted_receipt, accepted_archive = receipt.read_bytes(), archive.read_bytes()
        selection = self.package / "publish.toml"
        patch = self.package / "patches/001-delete-entrypoint.patch"
        patch.parent.mkdir()
        deletion = "".join(difflib.unified_diff((module / "SKILL.md").read_text().splitlines(True), [],
            fromfile="a/skills/curated/SKILL.md", tofile="/dev/null"))
        cases = (
            (self.skill / "SKILL.md", None),
            (selection, selection.read_text().replace('path = "."', 'path = "SKILL.md"')),
            (patch, deletion),
        )
        for path, replacement in cases:
            with self.subTest(path=path.relative_to(self.package)):
                original = path.read_bytes() if path.exists() else None
                try:
                    if replacement is None:
                        path.unlink()
                    else:
                        path.write_text(replacement)
                    result = self.recipe("check", success=False)
                    self.assertIn("skill", result.stderr.lower())
                    self.assertIn("SKILL.md", result.stderr)
                    self.assertEqual(receipt.read_bytes(), accepted_receipt)
                    result = self.recipe("export", success=False)
                    self.assertIn("stale build", result.stderr)
                    self.assertEqual(archive.read_bytes(), accepted_archive)
                finally:
                    if original is None:
                        path.unlink()
                    else:
                        path.write_bytes(original)

    def test_explicit_root_notices_accompany_a_selected_skill_in_the_export(self):
        module = self.imported_skill()
        nested = module / ".apm/skills/upstream"
        nested.mkdir(parents=True)
        (module / "SKILL.md").rename(nested / "SKILL.md")
        notices = {"LICENSE": "Fixture license text.\n", "THIRD_PARTY_NOTICES.md": "Fixture notices.\n"}
        for name, content in notices.items():
            (module / name).write_text(content)
        lock_path = self.root / "apm.lock.yaml"
        lock = yaml.safe_load(lock_path.read_text())
        lock["dependencies"][0]["content_hash"] = compute_package_hash(module)
        lock_path.write_text(yaml.safe_dump(lock))
        selection = self.package / "publish.toml"
        selection.write_text(selection.read_text().replace('path = "."', 'path = ".apm/skills/upstream"'))
        with selection.open("a") as stream:
            for name in notices:
                stream.write(f'\n[[payloads]]\ndependency = "example/upstream"\npath = "{name}"\n'
                             f'target = "licenses/example-upstream/{name}"\n')
        self.recipe("check")
        self.recipe("export")
        with tarfile.open(self.root / "build/marketplace.tar.gz") as archive:
            for name, content in notices.items():
                payload = archive.extractfile(f"marketplace/plugins/example/licenses/example-upstream/{name}")
                self.assertEqual(payload.read(), content.encode())
            skill = archive.extractfile("marketplace/plugins/example/skills/curated/SKILL.md")
            self.assertEqual(skill.read(), (nested / "SKILL.md").read_bytes())

    def test_check_rejects_cache_executable_bit_drift_from_git_acceptance(self):
        module = self.imported_skill()
        helper = module / "helper.sh"
        helper.write_text("#!/bin/sh\nexit 0\n")
        helper.chmod(0o755)
        lock_path = self.root / "apm.lock.yaml"
        lock = yaml.safe_load(lock_path.read_text())
        lock["dependencies"][0]["content_hash"] = compute_package_hash(module)
        lock_path.write_text(yaml.safe_dump(lock))
        environment = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        environment.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
        for arguments in (["init", "-q"], ["add", "--force", "--all"]):
            subprocess.run(["git", *arguments], cwd=self.root, env=environment, check=True)
        self.recipe("build")
        helper.chmod(0o644)
        result = self.recipe("check", success=False)
        self.assertIn("executable mode differs from Git", result.stderr)
        self.assertIn("helper.sh", result.stderr)
        helper.chmod(0o755)
        self.recipe("check")

    def test_build_rejects_damaged_cache_and_preserves_the_previous_artifact(self):
        module = self.imported_skill()
        self.recipe("build")
        artifact = self.root / "build/marketplace/plugins/example/skills/curated/SKILL.md"
        accepted = artifact.read_bytes()
        source = module / "SKILL.md"
        for damaged in (b"unreviewed replacement\n", None):
            with self.subTest(damaged=damaged):
                if damaged is None:
                    source.unlink()
                else:
                    source.write_bytes(damaged)
                result = self.recipe("build", success=False)
                self.assertIn("cache", result.stderr)
                self.assertIn("restore", result.stderr.lower())
                self.assertEqual(artifact.read_bytes(), accepted)
                if damaged is None:
                    self.assertFalse(source.exists())
                else:
                    self.assertEqual(source.read_bytes(), damaged)
                source.write_bytes(accepted)

    def test_local_patch_changes_only_the_artifact_and_refuses_drift(self):
        module = self.imported_skill()
        original = (module / "SKILL.md").read_bytes()
        patches = self.package / "patches"
        patches.mkdir()
        patch = patches / "001-reviewed.patch"
        patch.write_text(
            "--- a/skills/curated/SKILL.md\n+++ b/skills/curated/SKILL.md\n"
            "@@ -4,3 +4,3 @@\n ---\n \n-Original.\n+Reviewed.\n"
        )
        self.recipe("build")
        artifact = self.root / "build/marketplace/plugins/example/skills/curated/SKILL.md"
        self.assertTrue(artifact.read_text().endswith("Reviewed.\n"))
        self.assertEqual((module / "SKILL.md").read_bytes(), original)
        patch.write_text(patch.read_text().replace("-Original.", "-Different upstream."))
        result = self.recipe("build", success=False)
        self.assertIn("patch", result.stderr)
        self.assertTrue(artifact.read_text().endswith("Reviewed.\n"))

    def test_build_scans_local_patches_before_replacing_the_artifact(self):
        self.imported_skill()
        self.recipe("build")
        patches = self.package / "patches"
        patches.mkdir()
        (patches / "001-hidden.patch").write_text(
            "--- a/skills/curated/SKILL.md\n+++ b/skills/curated/SKILL.md\n"
            "@@ -4,3 +4,3 @@\n ---\n \n-Original.\n+Hidden \u202einstruction.\n"
        )
        result = self.recipe("build", success=False)
        self.assertIn("U+202E", result.stderr)
        artifact = self.root / "build/marketplace/plugins/example/skills/curated/SKILL.md"
        self.assertTrue(artifact.read_text().endswith("Original.\n"))

    def test_build_rejects_unsupported_dependency_components(self):
        module = self.imported_skill()
        selected = module / "skills/upstream"
        selected.mkdir(parents=True)
        (module / "SKILL.md").rename(selected / "SKILL.md")
        (module / "commands").mkdir()
        (module / "commands/unsupported.md").write_text("Unsupported component.\n")
        lock_path = self.root / "apm.lock.yaml"
        lock = yaml.safe_load(lock_path.read_text())
        lock["dependencies"][0]["content_hash"] = compute_package_hash(module)
        lock_path.write_text(yaml.safe_dump(lock))
        selection = self.package / "publish.toml"
        selection.write_text(selection.read_text().replace('path = "."', 'path = "skills/upstream"'))
        result = self.recipe("build", success=False)
        self.assertIn("unsupported APM component", result.stderr)
        self.assertFalse((self.root / "build/marketplace").exists())

    def test_publication_selection_includes_cached_hook_helpers(self):
        module = self.imported_skill()
        hooks = module / "hooks"
        hooks.mkdir()
        (hooks / "hooks.json").write_text('{"hooks": {}}\n')
        helper = hooks / "start.sh"
        helper.write_text("#!/bin/sh\nexit 0\n")
        helper.chmod(0o755)
        lock_path = self.root / "apm.lock.yaml"
        lock = yaml.safe_load(lock_path.read_text())
        lock["dependencies"][0]["content_hash"] = compute_package_hash(module)
        lock_path.write_text(yaml.safe_dump(lock))
        with (self.package / "publish.toml").open("a") as selection:
            selection.write('\n[[payloads]]\ndependency = "example/upstream"\npath = "hooks"\ntarget = "hooks"\n')
        codex = self.package / ".codex-plugin/plugin.json"
        manifest = json.loads(codex.read_text())
        manifest["hooks"] = {}
        codex.write_text(json.dumps(manifest))
        self.recipe("build")
        published = self.root / "build/marketplace/plugins/example/hooks/start.sh"
        self.assertEqual(published.read_bytes(), helper.read_bytes())
        self.assertEqual(published.stat().st_mode & 0o777, 0o755)

    def test_selection_excludes_an_unpublished_nested_skill_collection(self):
        module = self.imported_skill()
        nested = module / "skills/unselected"
        nested.mkdir(parents=True)
        (nested / "SKILL.md").write_text("Unselected upstream material.\n")
        (module / "SOURCE.md").write_text("Upstream's own document.\n")
        lock_path = self.root / "apm.lock.yaml"
        lock = yaml.safe_load(lock_path.read_text())
        lock["dependencies"][0]["content_hash"] = compute_package_hash(module)
        lock_path.write_text(yaml.safe_dump(lock))
        with (self.package / "publish.toml").open("a") as selection:
            selection.write('exclude = ["skills"]\n')
        self.recipe("build")
        published = self.root / "build/marketplace/plugins/example/skills/curated"
        self.assertFalse((published / "skills").exists())
        self.assertEqual((published / "SOURCE.md").read_text(), "Upstream's own document.\n")
        self.assertTrue((nested / "SKILL.md").exists())

    def test_acquisition_refuses_unaccepted_cache_before_calling_apm(self):
        module = self.imported_skill()
        environment = os.environ.copy()
        for key in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR"):
            environment.pop(key, None)
        environment.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
        subprocess.run(["git", "init", "-q"], cwd=self.root, env=environment, check=True)
        marker = self.root / "apm-called"
        executables = self.root / "bin"
        executables.mkdir()
        fake = executables / "apm"
        fake.write_text(f"#!{sys.executable}\nfrom pathlib import Path\nPath({str(marker)!r}).touch()\n")
        fake.chmod(0o755)
        original = (module / "SKILL.md").read_bytes()
        for target in ("fetch", "update"):
            with self.subTest(target=target):
                result = self.recipe(target, success=False,
                                   extra_env={"PATH": str(executables) + os.pathsep + os.environ["PATH"]})
                self.assertIn("unaccepted cache or lock changes", result.stderr)
                self.assertFalse(marker.exists())
                self.assertEqual((module / "SKILL.md").read_bytes(), original)

    def test_native_acquisition_refreshes_a_local_dependency_without_deployment(self):
        upstream = self.root / "upstream"
        upstream.mkdir()
        (upstream / "apm.yml").write_text("name: upstream\nversion: 1.0.0\n")
        skill = upstream / "SKILL.md"
        skill.write_text("---\nname: upstream\ndescription: Local dependency.\n---\n\nFirst.\n")
        manifest_path = self.root / "apm.yml"
        manifest = yaml.safe_load(manifest_path.read_text())
        manifest["devDependencies"] = {"apm": ["./upstream"]}
        manifest_path.write_text(yaml.safe_dump(manifest))
        environment = os.environ.copy()
        for key in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR"):
            environment.pop(key, None)
        environment.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
        for arguments in (["init", "-q"], ["config", "user.name", "Fixture"],
                          ["config", "user.email", "fixture@example.invalid"]):
            subprocess.run(["git", *arguments], cwd=self.root, env=environment, check=True)
        self.recipe("fetch")
        module = self.root / "apm_modules/_local/upstream"
        self.assertEqual((module / "SKILL.md").read_bytes(), skill.read_bytes())
        lock_path = self.root / "apm.lock.yaml"
        self.assertEqual(yaml.safe_load(lock_path.read_text())["dependencies"][0]["source"], "local")
        subprocess.run(["git", "add", "--force", "--all"], cwd=self.root, env=environment, check=True)
        subprocess.run(["git", "commit", "-q", "-m", "Accept fixture inputs"], cwd=self.root, env=environment, check=True)
        skill.write_text(skill.read_text().replace("First.", "Second."))
        self.recipe("update")
        self.assertTrue((module / "SKILL.md").read_text().endswith("Second.\n"))
        after = yaml.safe_load(lock_path.read_text())
        self.assertEqual(after["dependencies"][0]["source"], "local")
        self.assertFalse(after.get("deployments"))
        for target in (".agents", ".claude", ".codex", "AGENTS.md", "CLAUDE.md"):
            self.assertFalse((self.root / target).exists(), target)

    def test_native_failed_acquisition_propagates_through_make(self):
        manifest = self.root / "apm.yml"
        data = yaml.safe_load(manifest.read_text())
        data["devDependencies"] = {"apm": [str(self.sandbox / "missing-dependency")]}
        manifest.write_text(yaml.safe_dump(data))
        environment = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        subprocess.run(["git", "init", "-q"], cwd=self.root, env=environment, check=True)
        for target in ("fetch", "update"):
            result = self.recipe(target, success=False)
            self.assertIn("Local package path does not exist", result.stdout + result.stderr)
        self.assertFalse((self.root / "apm.lock.yaml").exists())
        for target in (".agents", ".claude", ".codex", "AGENTS.md", "CLAUDE.md"):
            self.assertFalse((self.root / target).exists(), target)

    def test_native_relock_then_prune_preserves_surviving_transitive_hooks(self):
        upstream = self.sandbox / "upstream"
        for name in ("kept", "leaf", "removed"):
            path = upstream / name
            path.mkdir(parents=True)
            data = {"name": name, "version": "1.0.0"}
            if name == "kept":
                data["dependencies"] = {"apm": [str(upstream / "leaf")]}
            (path / "apm.yml").write_text(yaml.safe_dump(data))
            (path / "SKILL.md").write_text(f"---\nname: {name}\ndescription: Fixture dependency.\n---\n")
        hooks = upstream / "leaf/.apm/hooks"
        hooks.mkdir(parents=True)
        (hooks / "hooks.json").write_text(json.dumps({"hooks": {"SessionStart": [{
            "hooks": [{"type": "command", "command": "./leaf-helper.sh"}]}]}}))
        (hooks / "leaf-helper.sh").write_text("#!/bin/sh\nexit 0\n")
        (hooks / "leaf-helper.sh").chmod(0o755)
        manifest_path = self.root / "apm.yml"
        manifest = yaml.safe_load(manifest_path.read_text())
        manifest["devDependencies"] = {"apm": [str(upstream / name) for name in ("kept", "removed")]}
        manifest_path.write_text(yaml.safe_dump(manifest))
        environment = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        environment.update(HOME=str(self.fixture_home), GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
        for args in (["init", "-q"], ["config", "user.name", "Fixture"], ["config", "user.email", "fixture@example.invalid"]):
            subprocess.run(["git", *args], cwd=self.root, env=environment, check=True)
        self.recipe("fetch")
        lock_path = self.root / "apm.lock.yaml"
        locked = yaml.safe_load(lock_path.read_text())["dependencies"]
        self.assertEqual({entry["name"] for entry in locked}, {"kept", "leaf", "removed"})
        self.assertEqual(next(entry["depth"] for entry in locked if entry["name"] == "leaf"), 2)
        cache = self.root / "apm_modules/_local"
        leaf_files = {str(path.relative_to(cache / "leaf")): (path.read_bytes(), path.stat().st_mode & 0o777)
                      for path in (cache / "leaf").rglob("*") if path.is_file()}
        for args in (["add", "--force", "--all"], ["commit", "-qm", "Accept inputs"]):
            subprocess.run(["git", *args], cwd=self.root, env=environment, check=True)
        manifest["devDependencies"]["apm"].remove(str(upstream / "removed"))
        manifest_path.write_text(yaml.safe_dump(manifest))
        self.recipe("fetch")
        self.assertEqual({entry["name"] for entry in yaml.safe_load(lock_path.read_text())["dependencies"]}, {"kept", "leaf"})
        for args in (["prune", "--dry-run"], ["prune"]):
            result = subprocess.run(["apm", *args], cwd=self.root, env=environment, capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((cache / "removed").exists())
        self.assertTrue((cache / "kept").is_dir())
        self.assertEqual({str(path.relative_to(cache / "leaf")): (path.read_bytes(), path.stat().st_mode & 0o777)
                          for path in (cache / "leaf").rglob("*") if path.is_file()}, leaf_files)
        for target in (".agents", ".claude", ".codex", ".cursor", "AGENTS.md", "CLAUDE.md"):
            self.assertFalse((self.root / target).exists(), target)

    def test_build_preserves_hook_helpers_and_codex_hook_suppression(self):
        hooks = self.package / "hooks"
        hooks.mkdir()
        (hooks / "hooks.json").write_text(json.dumps({"hooks": {"SessionStart": [{
            "hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/start.sh"}]
        }]}}))
        helper = hooks / "start.sh"
        helper.write_text("#!/bin/sh\nexit 0\n")
        helper.chmod(0o755)
        codex = self.package / ".codex-plugin/plugin.json"
        manifest = json.loads(codex.read_text())
        manifest["hooks"] = {}
        codex.write_text(json.dumps(manifest))
        self.recipe("build")
        plugin = self.root / "build/marketplace/plugins/example"
        self.assertEqual((plugin / "hooks/start.sh").read_bytes(), helper.read_bytes())
        self.assertEqual((plugin / "hooks/start.sh").stat().st_mode & 0o777, 0o755)
        self.assertEqual(json.loads((plugin / ".codex-plugin/plugin.json").read_text())["hooks"], {})
        self.assertNotIn("hooks", json.loads((plugin / ".claude-plugin/plugin.json").read_text()))

    def test_selection_rejects_escapes_collisions_and_removed_declarations(self):
        self.imported_skill()
        selection = self.package / "publish.toml"
        original = selection.read_text()
        for changed, error in (
            (original.replace('path = "."', 'path = "../../../../"'), "unsafe path"),
            (original.replace('name = "curated"', 'name = "../../escape"'), "unsafe path"),
            (original.replace('name = "curated"', 'name = "hello"'), "collision"),
        ):
            with self.subTest(error=error):
                selection.write_text(changed)
                result = self.recipe("build", success=False)
                self.assertIn(error, result.stderr)
        selection.write_text(original)
        manifest = self.root / "apm.yml"
        data = yaml.safe_load(manifest.read_text())
        data.pop("devDependencies")
        manifest.write_text(yaml.safe_dump(data))
        self.assertIn("declaration", self.recipe("build", success=False).stderr)

    def test_build_refuses_symlinks_even_when_apm_hash_ignores_them(self):
        module = self.imported_skill()
        (module / "escape").symlink_to(self.skill, target_is_directory=True)
        result = self.recipe("build", success=False)
        self.assertIn("symlink", result.stderr)
        self.assertFalse((self.root / "build/marketplace").exists())

    def test_build_requires_plugin_version_and_paired_invocation_policy(self):
        manifest = self.package / ".codex-plugin/plugin.json"
        original = manifest.read_text()
        manifest.write_text(original.replace('"1.0.0"', '""'))
        self.assertIn("version", self.recipe("build", success=False).stderr)
        manifest.write_text(original)
        skill = self.skill / "SKILL.md"
        skill.write_text(skill.read_text().replace("name: hello", "disable-model-invocation: true\nname: hello"))
        self.assertIn("allow_implicit_invocation", self.recipe("build", success=False).stderr)
        sidecar = self.skill / "agents/openai.yaml"
        sidecar.parent.mkdir()
        sidecar.write_text("policy:\n  allow_implicit_invocation: false\n")
        self.recipe("build")

    def test_overlays_are_additions_and_export_requires_fresh_checked_output(self):
        self.imported_skill()
        addition = self.package / "overlays/skills/curated/local.txt"
        addition.parent.mkdir(parents=True)
        addition.write_text("Reviewed addition.\n")
        self.recipe("build")
        self.assertEqual((self.root / "build/marketplace/plugins/example/skills/curated/local.txt").read_text(),
                         "Reviewed addition.\n")
        self.assertIn("check", self.recipe("export", success=False).stderr)
        self.recipe("check")
        self.recipe("export")
        self.assertTrue((self.root / "build/marketplace.tar.gz").is_file())
        addition.chmod(0o755)
        self.assertIn("stale", self.recipe("export", success=False).stderr)
        collision = addition.with_name("SKILL.md")
        collision.write_text("Clobber.\n")
        self.assertIn("collision", self.recipe("build", success=False).stderr)
        self.recipe("clean")
        self.assertFalse((self.root / "build").exists())
        self.assertTrue((self.root / "apm_modules/example/upstream/SKILL.md").exists())


if __name__ == "__main__":
    unittest.main()
