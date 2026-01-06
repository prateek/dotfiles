#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


class PrepareError(RuntimeError):
    pass


def _eprint(*args: object) -> None:
    print(*args, file=sys.stderr)


def _require_cmd(cmd: str) -> None:
    if not shutil_which(cmd):
        raise PrepareError(f"missing required command: {cmd}")


def shutil_which(cmd: str) -> str | None:
    # Local tiny shim to avoid importing shutil (keeps script ultra-portable).
    # Prefer python stdlib behavior: respect PATH.
    paths = os.environ.get("PATH", "").split(os.pathsep)
    for p in paths:
        candidate = Path(p) / cmd
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def _run(
    cmd: list[str],
    *,
    cwd: Path | None = None,
    capture: bool = False,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            cmd,
            cwd=str(cwd) if cwd else None,
            check=check,
            text=True,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE if capture else None,
        )
    except subprocess.CalledProcessError as exc:
        if capture:
            stderr = (exc.stderr or "").strip()
            stdout = (exc.stdout or "").strip()
            details = "\n".join([s for s in [stderr, stdout] if s])
            raise PrepareError(f"command failed: {shlex.join(cmd)}\n{details}") from exc
        raise PrepareError(f"command failed: {shlex.join(cmd)}") from exc


@dataclass(frozen=True)
class ParsedPr:
    number: int
    repo: str | None  # OWNER/REPO


_GITHUB_PR_RE = re.compile(
    r"https?://(?:www\.)?github\.com/(?P<owner>[^/]+)/(?P<repo>[^/]+)/pull/(?P<num>\d+)(?:/|$)"
)


def _parse_pr(value: str) -> ParsedPr:
    value = value.strip()
    if value.isdigit():
        return ParsedPr(number=int(value), repo=None)

    m = _GITHUB_PR_RE.search(value)
    if m:
        owner = m.group("owner")
        repo = m.group("repo")
        num = int(m.group("num"))
        return ParsedPr(number=num, repo=f"{owner}/{repo}")

    raise PrepareError(
        "unsupported PR identifier; pass a PR number (e.g. 123) or a GitHub PR URL "
        "(e.g. https://github.com/OWNER/REPO/pull/123)"
    )


def _parse_owner_repo_from_remote(remote_url: str) -> str | None:
    remote_url = remote_url.strip()
    # Match:
    # - https://github.com/owner/repo.git
    # - git@github.com:owner/repo.git
    # - ssh://git@github.com/owner/repo.git
    m = re.search(r"[:/](?P<owner>[^/]+)/(?P<repo>[^/]+?)(?:\.git)?$", remote_url)
    if not m:
        return None
    return f"{m.group('owner')}/{m.group('repo')}"


def _git_root(repo_dir: Path) -> Path:
    proc = _run(["git", "-C", str(repo_dir), "rev-parse", "--show-toplevel"], capture=True)
    return Path(proc.stdout.strip())


def _git_origin_repo(repo_dir: Path) -> str | None:
    proc = _run(
        ["git", "-C", str(repo_dir), "config", "--get", "remote.origin.url"],
        capture=True,
        check=False,
    )
    if proc.returncode != 0:
        return None
    return _parse_owner_repo_from_remote(proc.stdout)


def _git_is_clean(repo_dir: Path) -> bool:
    proc = _run(["git", "-C", str(repo_dir), "status", "--porcelain"], capture=True)
    return proc.stdout.strip() == ""


def _gh_pr_view(pr_number: int, repo: str) -> dict[str, Any]:
    proc = _run(
        [
            "gh",
            "pr",
            "view",
            str(pr_number),
            "-R",
            repo,
            "--json",
            "url,title,baseRefName,headRefName",
        ],
        capture=True,
    )
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise PrepareError("failed to parse `gh pr view` output as JSON") from exc
    return {
        "pr_url": data.get("url"),
        "title": data.get("title"),
        "base_ref": data.get("baseRefName"),
        "head_ref": data.get("headRefName"),
    }


def _wf_prepare(pr_number: int, *, worktree_name: str, repo: str) -> Path:
    _require_cmd("wf")
    _require_cmd("gh")

    wf_proc = _run(["wf", "new", "--reuse", "--json", worktree_name], capture=True)
    try:
        wf_data = json.loads(wf_proc.stdout)
    except json.JSONDecodeError as exc:
        raise PrepareError("failed to parse `wf new --json` output") from exc

    openai_path = wf_data.get("openai_path")
    if not openai_path:
        raise PrepareError("`wf new --json` did not return openai_path")
    worktree_dir = Path(openai_path).expanduser().resolve()

    if not _git_is_clean(worktree_dir):
        raise PrepareError(
            f"worktree is dirty: {worktree_dir}\n"
            f"clean it up or remove it (e.g. `wf rm {worktree_name} -y`) and retry"
        )

    _run(
        [
            "gh",
            "pr",
            "checkout",
            str(pr_number),
            "-R",
            repo,
            "--branch",
            worktree_name,
            "--force",
        ],
        cwd=worktree_dir,
        capture=True,
    )

    return worktree_dir


def _wt_prepare(pr_number: int, *, worktree_name: str, repo: str, repo_dir: Path) -> Path:
    _require_cmd("wt")
    _require_cmd("gh")

    repo_dir = repo_dir.expanduser().resolve()
    repo_root = _git_root(repo_dir)

    if not _git_is_clean(repo_root):
        raise PrepareError(
            f"repo has uncommitted changes: {repo_root}\n"
            "stash/commit them (or use a clean clone) before creating a PR review worktree"
        )

    origin_repo = _git_origin_repo(repo_root)
    if origin_repo and origin_repo.lower() != repo.lower():
        raise PrepareError(
            f"repo mismatch: local origin is {origin_repo}, but requested PR repo is {repo}\n"
            f"pass the correct `--repo-dir` pointing at a clone of {repo}"
        )

    worktree_dir = repo_root.parent / worktree_name
    _run(
        [
            "wt",
            "pr",
            str(pr_number),
            "--path",
            str(worktree_dir),
            "--editor",
            "none",
        ],
        cwd=repo_root,
    )

    return worktree_dir.resolve()


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Prepare a dedicated worktree for reviewing a GitHub PR. Uses `wf` for openai/openai and "
            "`wt` for any other repo."
        )
    )
    parser.add_argument("--pr", required=True, help="PR number or GitHub PR URL")
    parser.add_argument(
        "--repo",
        help="Optional OWNER/REPO override (used when --pr is a number and repo can't be inferred)",
    )
    parser.add_argument(
        "--repo-dir",
        help="Local repo dir (required for non-openai/openai PRs unless running inside that repo)",
    )
    parser.add_argument(
        "--worktree-name",
        help="Override worktree name (default: pr-review-<number>)",
    )
    parser.add_argument("--json", action="store_true", help="Print machine-readable JSON to stdout")
    args = parser.parse_args(argv)

    parsed = _parse_pr(args.pr)
    pr_number = parsed.number

    repo = (args.repo or parsed.repo or "").strip() or None

    if repo is None:
        # Try to infer from local repo (if available); otherwise default to openai/openai.
        if args.repo_dir:
            repo = _git_origin_repo(_git_root(Path(args.repo_dir)))
        else:
            # If running inside a repo, infer from cwd.
            try:
                repo = _git_origin_repo(_git_root(Path.cwd()))
            except PrepareError:
                repo = None

    if repo is None:
        repo = "openai/openai"

    worktree_name = args.worktree_name or f"pr-review-{pr_number}"

    if repo.lower() == "openai/openai":
        worktree_dir = _wf_prepare(pr_number, worktree_name=worktree_name, repo=repo)
        worktree_type = "wf"
        repo_dir = None
    else:
        repo_dir = Path(args.repo_dir) if args.repo_dir else Path.cwd()
        worktree_dir = _wt_prepare(
            pr_number,
            worktree_name=worktree_name,
            repo=repo,
            repo_dir=repo_dir,
        )
        worktree_type = "wt"
        repo_dir = str(_git_root(repo_dir))

    pr_meta = _gh_pr_view(pr_number, repo)

    payload: dict[str, Any] = {
        "repo": repo,
        "pr_number": pr_number,
        "worktree_name": worktree_name,
        "worktree_type": worktree_type,
        "worktree_dir": str(worktree_dir),
        **pr_meta,
    }
    if repo_dir:
        payload["repo_dir"] = repo_dir

    if args.json:
        json.dump(payload, sys.stdout)
        sys.stdout.write("\n")
        return 0

    _eprint(f"Prepared PR worktree: {worktree_dir} ({worktree_type})")
    _eprint(f"PR: {repo}#{pr_number} {pr_meta.get('pr_url') or ''}".rstrip())
    _eprint(f"Base: {pr_meta.get('base_ref')}  Head: {pr_meta.get('head_ref')}")
    print(str(worktree_dir))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except PrepareError as exc:
        _eprint(f"prepare_pr_worktree.py: {exc}")
        raise SystemExit(2)
