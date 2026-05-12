from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
import os
from pathlib import Path

SCRIPT_ROOT = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPT_ROOT))

from create_experiment import (
    cache_repo_path,
    canonical_repo_path,
    parse_repo_ref,
    parse_repo_sparse_specs,
)


SCRIPT_PATH = SCRIPT_ROOT / "create_experiment.py"


class CreateExperimentTests(unittest.TestCase):
    def test_path_helpers_follow_expected_layout(self) -> None:
        repo = parse_repo_ref("acme/widget")
        canonical_root = Path("/tmp/canonical")
        cache_root = Path("/tmp/reference-cache")

        self.assertEqual(
            canonical_repo_path(repo, canonical_root),
            canonical_root / "acme" / "widget",
        )
        self.assertEqual(
            cache_repo_path(repo, cache_root),
            cache_root / "github.com" / "acme" / "widget",
        )

    def test_cli_prefers_canonical_clone_and_cleans_experiment_copy(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            base = Path(tmp_dir)
            canonical_root = base / "canonical"
            cache_root = base / "cache"
            experiments_root = base / "experiments"

            remote = create_remote_repo(base / "remote.git", default_branch="main")
            canonical_repo = canonical_root / "acme" / "widget"
            canonical_repo.parent.mkdir(parents=True, exist_ok=True)
            run(["git", "clone", str(remote), str(canonical_repo)])

            # Make the canonical working tree dirty; normalization should clean the experiment copy.
            (canonical_repo / "scratch.txt").write_text("ignore me\n", encoding="utf-8")

            run(
                [
                    sys.executable,
                    str(SCRIPT_PATH),
                    "--root",
                    str(experiments_root),
                    "--name",
                    "canonical-demo",
                    "--goal",
                    "Verify canonical seeding.",
                    "--repo",
                    "acme/widget",
                    "--canonical-root",
                    str(canonical_root),
                    "--cache-root",
                    str(cache_root),
                    "--grm-mode",
                    "on",
                ]
            )

            experiment_repo = (
                experiments_root / "canonical-demo" / "references" / "repos" / "acme" / "widget"
            )
            self.assertTrue(experiment_repo.exists())
            self.assertFalse((experiment_repo / "scratch.txt").exists())
            self.assertFalse((cache_root / "github.com" / "acme" / "widget").exists())
            self.assertEqual(
                git_stdout(experiment_repo, "status", "--porcelain"),
                "",
            )
            index_text = (
                experiments_root / "canonical-demo" / "references" / "index.md"
            ).read_text(encoding="utf-8")
            self.assertIn("fastcp:canonical", index_text)

    def test_cli_uses_existing_cache_when_canonical_clone_is_unavailable(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            base = Path(tmp_dir)
            canonical_root = base / "canonical"
            cache_root = base / "cache"
            experiments_root = base / "experiments"

            remote = create_remote_repo(base / "remote.git", default_branch="main")
            cache_repo = cache_root / "github.com" / "acme" / "widget"
            cache_repo.parent.mkdir(parents=True, exist_ok=True)
            run(["git", "clone", str(remote), str(cache_repo)])

            run(
                [
                    sys.executable,
                    str(SCRIPT_PATH),
                    "--root",
                    str(experiments_root),
                    "--name",
                    "cache-demo",
                    "--goal",
                    "Verify cache seeding.",
                    "--repo",
                    "acme/widget",
                    "--canonical-root",
                    str(canonical_root),
                    "--cache-root",
                    str(cache_root),
                    "--grm-mode",
                    "off",
                ],
                env={"PATH": os_environ_path()},
            )

            experiment_repo = (
                experiments_root / "cache-demo" / "references" / "repos" / "acme" / "widget"
            )
            self.assertTrue(cache_repo.exists())
            self.assertTrue(experiment_repo.exists())
            self.assertEqual(
                git_stdout(experiment_repo, "status", "--porcelain"),
                "",
            )
            index_text = (
                experiments_root / "cache-demo" / "references" / "index.md"
            ).read_text(encoding="utf-8")
            self.assertIn("fastcp:cache", index_text)

    def test_sparse_specs_normalize_paths_for_a_repo(self) -> None:
        specs = parse_repo_sparse_specs(
            [
                "acme/widget=docs,examples",
                "acme/widget=./docs",
            ]
        )

        self.assertEqual(specs, {"acme/widget": ["docs", "examples", "docs"]})

    def test_cli_sparse_checkout_uses_canonical_seed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            base = Path(tmp_dir)
            canonical_root = base / "canonical"
            cache_root = base / "cache"
            experiments_root = base / "experiments"

            remote = create_remote_repo(
                base / "remote.git",
                default_branch="main",
                files={
                    "README.md": "# demo\n",
                    "kept/note.txt": "keep me\n",
                    "skipped/blob.txt": "skip me\n",
                },
            )
            canonical_repo = canonical_root / "acme" / "widget"
            canonical_repo.parent.mkdir(parents=True, exist_ok=True)
            run(["git", "clone", str(remote), str(canonical_repo)])

            run(
                [
                    sys.executable,
                    str(SCRIPT_PATH),
                    "--root",
                    str(experiments_root),
                    "--name",
                    "sparse-demo",
                    "--goal",
                    "Verify sparse canonical seeding.",
                    "--repo",
                    "acme/widget",
                    "--repo-sparse",
                    "acme/widget=kept",
                    "--canonical-root",
                    str(canonical_root),
                    "--cache-root",
                    str(cache_root),
                    "--grm-mode",
                    "on",
                ]
            )

            experiment_repo = (
                experiments_root / "sparse-demo" / "references" / "repos" / "acme" / "widget"
            )
            self.assertTrue((experiment_repo / "kept" / "note.txt").exists())
            self.assertFalse((experiment_repo / "skipped" / "blob.txt").exists())
            self.assertEqual(
                git_stdout(experiment_repo, "config", "--get", "core.sparseCheckout"),
                "true",
            )
            self.assertEqual(
                git_stdout(experiment_repo, "status", "--porcelain"),
                "",
            )
            index_text = (
                experiments_root / "sparse-demo" / "references" / "index.md"
            ).read_text(encoding="utf-8")
            self.assertIn("git-sparse-shared:canonical", index_text)
            self.assertIn("`kept`", index_text)

    def test_cli_rejects_sparse_spec_for_missing_repo(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT_PATH),
                    "--root",
                    tmp_dir,
                    "--name",
                    "bad-sparse",
                    "--goal",
                    "Verify validation.",
                    "--repo",
                    "acme/widget",
                    "--repo-sparse",
                    "other/repo=docs",
                    "--no-clone",
                ],
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("not listed by --repo", result.stderr)


def create_remote_repo(
    remote_path: Path, *, default_branch: str, files: dict[str, str] | None = None
) -> Path:
    remote_path.parent.mkdir(parents=True, exist_ok=True)
    run(["git", "init", "--bare", str(remote_path)])

    worktree = remote_path.parent / "worktree"
    run(["git", "clone", str(remote_path), str(worktree)])
    run(["git", "config", "user.name", "Repo Audit"], cwd=worktree)
    run(["git", "config", "user.email", "repo-audit@example.com"], cwd=worktree)
    run(["git", "checkout", "-b", default_branch], cwd=worktree)

    files = files or {"README.md": "# demo\n"}
    for path, content in files.items():
        target = worktree / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")

    run(["git", "add", "."], cwd=worktree)
    run(["git", "commit", "-m", "initial"], cwd=worktree)
    run(["git", "push", "-u", "origin", default_branch], cwd=worktree)
    run(["git", "symbolic-ref", "HEAD", f"refs/heads/{default_branch}"], cwd=remote_path)
    return remote_path


def git_stdout(repo: Path, *args: str) -> str:
    return run(["git", *args], cwd=repo).stdout.strip()


def run(
    cmd: list[str], *, cwd: Path | None = None, env: dict[str, str] | None = None
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise AssertionError(
            f"Command failed ({result.returncode}): {' '.join(cmd)}\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )
    return result


def os_environ_path() -> str:
    return (
        str(Path.home() / ".local" / "bin")
        + ":"
        + str(Path.home() / ".cargo" / "bin")
        + ":"
        + os.environ["PATH"]
    )


if __name__ == "__main__":
    unittest.main()
