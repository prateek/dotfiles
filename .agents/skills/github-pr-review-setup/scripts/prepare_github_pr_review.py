#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


class PrepareError(RuntimeError):
    pass


def _eprint(*args: object) -> None:
    print(*args, file=sys.stderr)


def shutil_which(cmd: str) -> str | None:
    # Tiny shim to avoid importing shutil (keeps script ultra-portable).
    paths = os.environ.get("PATH", "").split(os.pathsep)
    for p in paths:
        candidate = Path(p) / cmd
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def _require_cmd(cmd: str) -> None:
    if not shutil_which(cmd):
        raise PrepareError(f"missing required command: {cmd}")


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
    repo: str | None  # OWNER/REPO (or HOST/OWNER/REPO)


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


def _split_repo(repo: str) -> tuple[str | None, str, str]:
    parts = [p for p in repo.strip().split("/") if p]
    if len(parts) == 2:
        return None, parts[0], parts[1]
    if len(parts) == 3:
        return parts[0], parts[1], parts[2]
    raise PrepareError(f"invalid repo format: {repo!r} (expected OWNER/REPO or HOST/OWNER/REPO)")


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


def _git_remotes(repo_dir: Path) -> list[str]:
    proc = _run(["git", "-C", str(repo_dir), "remote"], capture=True, check=False)
    if proc.returncode != 0:
        return []
    return [r.strip() for r in proc.stdout.splitlines() if r.strip()]


def _git_preferred_remote(repo_dir: Path) -> str | None:
    remotes = _git_remotes(repo_dir)
    if not remotes:
        return None
    if "upstream" in remotes:
        return "upstream"
    if "origin" in remotes:
        return "origin"
    return remotes[0]


def _git_rev_parse(repo_dir: Path, ref: str) -> str:
    proc = _run(["git", "-C", str(repo_dir), "rev-parse", ref], capture=True)
    return proc.stdout.strip()


def _git_ref_exists(repo_dir: Path, ref: str) -> bool:
    proc = _run(["git", "-C", str(repo_dir), "rev-parse", "--verify", ref], capture=True, check=False)
    return proc.returncode == 0


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
            ",".join(
                [
                    "url",
                    "title",
                    "body",
                    "state",
                    "isDraft",
                    "author",
                    "baseRefName",
                    "baseRefOid",
                    "headRefName",
                    "headRefOid",
                    "additions",
                    "deletions",
                    "changedFiles",
                    "files",
                    "labels",
                    "assignees",
                    "createdAt",
                    "updatedAt",
                    "mergeable",
                    "mergeStateStatus",
                    "reviewDecision",
                    "statusCheckRollup",
                ]
            ),
        ],
        capture=True,
    )
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise PrepareError("failed to parse `gh pr view` output as JSON") from exc


def _gh_pr_checks(pr_number: int, repo: str) -> list[dict[str, Any]]:
    proc = _run(
        [
            "gh",
            "pr",
            "checks",
            str(pr_number),
            "-R",
            repo,
            "--json",
            ",".join(
                [
                    "bucket",
                    "completedAt",
                    "description",
                    "event",
                    "link",
                    "name",
                    "startedAt",
                    "state",
                    "workflow",
                ]
            ),
        ],
        capture=True,
        check=False,
    )
    # Exit code 8 means "checks pending" per gh help; still a successful payload.
    if proc.returncode not in (0, 8):
        raise PrepareError(f"`gh pr checks` failed:\n{(proc.stderr or proc.stdout).strip()}")
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise PrepareError("failed to parse `gh pr checks` output as JSON") from exc
    if not isinstance(data, list):
        raise PrepareError("unexpected `gh pr checks --json` output (expected a JSON list)")
    return data


def _gh_api_paginate_json(endpoint: str) -> Any:
    proc = _run(
        [
            "gh",
            "api",
            "--paginate",
            "-H",
            "Accept: application/vnd.github+json",
            endpoint,
        ],
        capture=True,
    )
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise PrepareError(f"failed to parse `gh api` output as JSON for {endpoint!r}") from exc


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


def _inplace_prepare(pr_number: int, *, branch_name: str, repo: str, repo_dir: Path) -> Path:
    _require_cmd("gh")

    repo_root = _git_root(repo_dir.expanduser().resolve())
    if not _git_is_clean(repo_root):
        raise PrepareError(
            f"repo has uncommitted changes: {repo_root}\n"
            "stash/commit them (or use a clean clone) before doing an in-place PR checkout"
        )

    origin_repo = _git_origin_repo(repo_root)
    if origin_repo and origin_repo.lower() != repo.lower():
        raise PrepareError(
            f"repo mismatch: local origin is {origin_repo}, but requested PR repo is {repo}\n"
            f"pass the correct `--repo-dir` pointing at a clone of {repo}"
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
            branch_name,
            "--force",
        ],
        cwd=repo_root,
        capture=True,
    )
    return repo_root


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Prepare a local checkout for reviewing a GitHub PR and emit review context as JSON. "
            "Defaults to a clean worktree checkout (wf for openai/openai, wt otherwise)."
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
        "--checkout-mode",
        choices=["worktree", "inplace"],
        default="worktree",
        help="Checkout strategy (default: worktree)",
    )
    parser.add_argument("--worktree-name", help="Override worktree/branch name (default: pr-review-<number>)")
    parser.add_argument("--out", help="Also write the JSON payload to this file path")
    args = parser.parse_args(argv)

    _require_cmd("git")
    _require_cmd("gh")

    parsed = _parse_pr(args.pr)
    pr_number = parsed.number

    repo = (args.repo or parsed.repo or "").strip() or None

    if repo is None:
        # Try to infer from local repo (if available); otherwise default to openai/openai.
        if args.repo_dir:
            repo = _git_origin_repo(_git_root(Path(args.repo_dir)))
        else:
            try:
                repo = _git_origin_repo(_git_root(Path.cwd()))
            except PrepareError:
                repo = None

    if repo is None:
        repo = "openai/openai"

    worktree_name = args.worktree_name or f"pr-review-{pr_number}"

    pr_view = _gh_pr_view(pr_number, repo)
    base_ref = pr_view.get("baseRefName")
    head_ref = pr_view.get("headRefName")
    if not base_ref or not head_ref:
        raise PrepareError("`gh pr view` did not return baseRefName/headRefName")

    checkout_mode = args.checkout_mode
    if checkout_mode == "worktree":
        if repo.lower() == "openai/openai":
            worktree_dir = _wf_prepare(pr_number, worktree_name=worktree_name, repo=repo)
            worktree_type = "wf"
            repo_dir: str | None = None
        else:
            repo_path = Path(args.repo_dir) if args.repo_dir else Path.cwd()
            worktree_dir = _wt_prepare(
                pr_number,
                worktree_name=worktree_name,
                repo=repo,
                repo_dir=repo_path,
            )
            worktree_type = "wt"
            repo_dir = str(_git_root(repo_path))
    else:
        repo_path = Path(args.repo_dir) if args.repo_dir else Path.cwd()
        worktree_dir = _inplace_prepare(pr_number, branch_name=worktree_name, repo=repo, repo_dir=repo_path)
        worktree_type = "inplace"
        repo_dir = str(_git_root(repo_path))

    if not _git_is_clean(worktree_dir):
        raise PrepareError(
            f"checkout is not clean: {worktree_dir}\n"
            "clean it up (or recreate the worktree) before running a review"
        )

    remote = _git_preferred_remote(worktree_dir)
    if remote:
        _run(["git", "-C", str(worktree_dir), "fetch", remote, str(base_ref)], capture=True)
        compare_to = f"{remote}/{base_ref}"
    else:
        if not _git_ref_exists(worktree_dir, str(base_ref)):
            raise PrepareError(
                f"no git remotes found and base ref {base_ref!r} does not exist locally in {worktree_dir}"
            )
        compare_to = str(base_ref)

    base_oid = _git_rev_parse(worktree_dir, compare_to)
    head_oid = _git_rev_parse(worktree_dir, "HEAD")

    checks = _gh_pr_checks(pr_number, repo)
    checks_summary = dict(Counter((c.get("bucket") or "unknown") for c in checks))

    _, owner, repo_name = _split_repo(repo)
    issue_comments = _gh_api_paginate_json(f"repos/{owner}/{repo_name}/issues/{pr_number}/comments")
    reviews = _gh_api_paginate_json(f"repos/{owner}/{repo_name}/pulls/{pr_number}/reviews")
    review_comments = _gh_api_paginate_json(f"repos/{owner}/{repo_name}/pulls/{pr_number}/comments")

    payload: dict[str, Any] = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "repo": repo,
        "pr_number": pr_number,
        "pr_url": pr_view.get("url"),
        "title": pr_view.get("title"),
        "base_ref": base_ref,
        "head_ref": head_ref,
        "worktree_name": worktree_name,
        "checkout_mode": checkout_mode,
        "worktree_type": worktree_type,
        "worktree_dir": str(worktree_dir),
        "repo_dir": repo_dir,
        "remote": remote,
        "compare_to": compare_to,
        "git": {"base_oid": base_oid, "head_oid": head_oid},
        "pr": pr_view,
        "checks_summary": checks_summary,
        "checks": checks,
        "issue_comments": issue_comments,
        "reviews": reviews,
        "review_comments": review_comments,
    }

    if args.out:
        out_path = Path(args.out).expanduser()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        _eprint(f"Wrote: {out_path}")

    json.dump(payload, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except PrepareError as exc:
        _eprint(f"prepare_github_pr_review.py: {exc}")
        raise SystemExit(2)
