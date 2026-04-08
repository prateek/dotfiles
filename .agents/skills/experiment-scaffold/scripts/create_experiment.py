#!/usr/bin/env python3
from __future__ import annotations

import argparse
import dataclasses
import re
import shutil
import subprocess
import sys
import textwrap
from pathlib import Path
from urllib.parse import urlparse


@dataclasses.dataclass(frozen=True)
class RepoRef:
    raw: str
    host: str | None = None
    owner: str | None = None
    name: str | None = None

    @property
    def owner_repo(self) -> str | None:
        if self.owner and self.name:
            return f"{self.owner}/{self.name}"
        return None

    @property
    def https_url(self) -> str | None:
        if self.host and self.owner and self.name:
            return f"https://{self.host}/{self.owner}/{self.name}.git"
        return None

    @property
    def ssh_url(self) -> str | None:
        if self.host and self.owner and self.name:
            return f"git@{self.host}:{self.owner}/{self.name}.git"
        return None


@dataclasses.dataclass(frozen=True)
class CloneResult:
    repo: RepoRef
    dest_relpath: str
    status: str
    method: str | None = None
    detail: str | None = None


def _print_err(msg: str) -> None:
    print(msg, file=sys.stderr)


def _run(
    cmd: list[str], *, cwd: Path | None = None
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        text=True,
        capture_output=True,
        check=False,
    )


def parse_repo_ref(raw: str) -> RepoRef:
    raw = raw.strip()
    if not raw:
        return RepoRef(raw=raw)

    # owner/repo
    if re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", raw):
        owner, name = raw.split("/", 1)
        return RepoRef(
            raw=raw, host="github.com", owner=owner, name=name.removesuffix(".git")
        )

    # SSH URL: git@host:owner/repo(.git)
    ssh_match = re.fullmatch(r"git@([^:]+):([^/]+)/([^/]+)", raw)
    if ssh_match:
        host, owner, name = ssh_match.groups()
        return RepoRef(raw=raw, host=host, owner=owner, name=name.removesuffix(".git"))

    # HTTPS URL: https://host/owner/repo(.git)
    parsed = urlparse(raw)
    if parsed.scheme in {"http", "https"} and parsed.netloc:
        parts = [p for p in parsed.path.split("/") if p]
        if len(parts) >= 2:
            owner, name = parts[0], parts[1]
            return RepoRef(
                raw=raw, host=parsed.netloc, owner=owner, name=name.removesuffix(".git")
            )

    return RepoRef(raw=raw)


def ensure_empty_dir(path: Path) -> None:
    if not path.exists():
        return
    if path.is_dir() and not any(path.iterdir()):
        return
    raise FileExistsError(f"Path already exists and is not empty: {path}")


def _remove_if_exists(path: Path) -> None:
    if not path.exists():
        return
    shutil.rmtree(path)


def clone_repo(
    repo: RepoRef,
    *,
    dest: Path,
    depth: int,
    strict: bool,
) -> CloneResult:
    if dest.exists():
        return CloneResult(repo=repo, dest_relpath=dest.as_posix(), status="exists")

    dest.parent.mkdir(parents=True, exist_ok=True)

    git_flags: list[str] = []
    if depth > 0:
        git_flags.append(f"--depth={depth}")

    has_gh = shutil.which("gh") is not None
    has_git = shutil.which("git") is not None

    attempts: list[tuple[str, list[str]]] = []

    # Prefer SSH, but fall back to default gh config and HTTPS.
    if has_gh:
        attempts.extend(
            [
                ("gh:ssh", ["gh", "repo", "clone", repo.ssh_url, str(dest)]),
                ("gh:default", ["gh", "repo", "clone", repo.owner_repo, str(dest)]),
                ("gh:https", ["gh", "repo", "clone", repo.https_url, str(dest)]),
                ("gh:raw", ["gh", "repo", "clone", repo.raw, str(dest)]),
            ]
        )

        # Add depth flags to gh invocations.
        if git_flags:
            attempts = [
                (label, cmd + ["--", *git_flags])
                if cmd[:3] == ["gh", "repo", "clone"]
                else (label, cmd)
                for (label, cmd) in attempts
            ]

    if has_git:
        attempts.extend(
            [
                ("git:ssh", ["git", "clone", *git_flags, repo.ssh_url, str(dest)]),
                ("git:https", ["git", "clone", *git_flags, repo.https_url, str(dest)]),
                ("git:raw", ["git", "clone", *git_flags, repo.raw, str(dest)]),
            ]
        )

    attempts = [
        (label, cmd)
        for (label, cmd) in attempts
        if all(part is not None for part in cmd)
    ]

    # Collapse duplicate command-lines (after None filtering).
    unique_attempts: list[tuple[str, list[str]]] = []
    seen_cmds: set[tuple[str, ...]] = set()
    for label, cmd in attempts:
        cmd_key = tuple(cmd)
        if cmd_key in seen_cmds:
            continue
        seen_cmds.add(cmd_key)
        unique_attempts.append((label, cmd))

    if not unique_attempts:
        return CloneResult(
            repo=repo,
            dest_relpath=dest.as_posix(),
            status="failed",
            detail="Neither `gh` nor `git` was found on PATH.",
        )

    for label, cmd in unique_attempts:
        _remove_if_exists(dest)
        result = _run(cmd)
        if result.returncode == 0:
            return CloneResult(
                repo=repo, dest_relpath=dest.as_posix(), status="cloned", method=label
            )

        if strict:
            detail = (
                result.stderr or result.stdout or ""
            ).strip() or f"Command failed: {' '.join(cmd)}"
            return CloneResult(
                repo=repo,
                dest_relpath=dest.as_posix(),
                status="failed",
                method=label,
                detail=detail,
            )

    last_label, last_cmd = unique_attempts[-1]
    detail = (
        f"All clone attempts failed. If this is a private repo and you use multiple GitHub accounts, "
        f"check `gh auth status` and switch accounts with `gh auth switch -u <user>`.\n"
        f"Last attempt: {last_label}: {' '.join(last_cmd)}"
    )
    return CloneResult(
        repo=repo,
        dest_relpath=dest.as_posix(),
        status="failed",
        method=last_label,
        detail=detail,
    )


def format_notes_md(notes: list[str]) -> str:
    lines: list[str] = ["# Notes", ""]
    if notes:
        lines.extend([f"- {note}" for note in notes])
    else:
        lines.append("- (add notes here)")
    lines.append("")
    return "\n".join(lines)


def format_links_md(urls: list[str]) -> str:
    lines: list[str] = ["# Links", ""]
    if urls:
        lines.extend([f"- {url}" for url in urls])
    else:
        lines.append("- (add links here)")
    lines.append("")
    return "\n".join(lines)


def format_index_md(
    *,
    experiment_name: str,
    goal: str,
    repos_dir_relpath: str,
    clone_results: list[CloneResult],
) -> str:
    lines: list[str] = [
        "# References index",
        "",
        f"Experiment: `{experiment_name}`",
        "",
        "## Goal",
        "",
        goal.strip(),
        "",
        "## Contents",
        "",
        "- `index.md`: this file",
        "- `notes.md`: free-form notes and hypotheses",
        "- `links.md`: websites/blogs/docs/API pages",
        f"- `{repos_dir_relpath}`: cloned GitHub repos (gitignored)",
        "",
    ]

    if clone_results:
        lines.extend(["## Repos", ""])
        lines.append("| Repo | Local path | Status |")
        lines.append("| --- | --- | --- |")
        for r in clone_results:
            display = r.repo.owner_repo or r.repo.raw or "(unknown)"
            status = r.status if not r.method else f"{r.status} ({r.method})"
            lines.append(f"| `{display}` | `{r.dest_relpath}` | {status} |")
        lines.append("")

        failures = [r for r in clone_results if r.status == "failed"]
        if failures:
            lines.extend(["## Clone failures", ""])
            for r in failures:
                display = r.repo.owner_repo or r.repo.raw or "(unknown)"
                lines.append(f"### `{display}`")
                lines.append("")
                lines.append("```")
                lines.append((r.detail or "").strip() or "(no details)")
                lines.append("```")
                lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def format_agents_md(*, experiment_name: str, goal: str) -> str:
    body = f"""\
    # Experiment: {experiment_name}

    ## Goal

    {goal.strip()}

    ## Where to look first

    - See `references/index.md` for the inventory of repos, links, and notes.
    - Cloned repos live under `references/repos/` and are ignored by git.
    """
    return textwrap.dedent(body).rstrip() + "\n"


def format_gitignore() -> str:
    return (
        textwrap.dedent(
            """\
        # Cloned reference repositories (keep out of commits)
        references/repos/

        # OS / editor noise
        .DS_Store
        """
        ).rstrip()
        + "\n"
    )


def validate_dir_name(name: str) -> str:
    if not name.strip():
        raise ValueError("Experiment name must be non-empty.")
    if "/" in name or "\\" in name:
        raise ValueError(
            "Experiment name must be a single directory name (no path separators)."
        )
    if name in {".", ".."}:
        raise ValueError("Experiment name must not be '.' or '..'.")
    return name


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create a git-initialized experiment directory with a references/ index, notes, links, and cloned repos.",
    )
    parser.add_argument(
        "--root",
        default=".",
        help="Parent directory to create the experiment in (default: current dir).",
    )
    parser.add_argument(
        "--name",
        required=True,
        help="Experiment directory name (e.g. 'vector-search').",
    )
    parser.add_argument(
        "--goal", required=True, help="What you're trying to achieve / test / learn."
    )
    parser.add_argument(
        "--repo",
        action="append",
        default=[],
        help="GitHub repo reference (owner/repo or URL). Repeatable.",
    )
    parser.add_argument(
        "--url",
        "--link",
        dest="urls",
        action="append",
        default=[],
        help="Website/blog/doc page URL to stash in references/links.md. Repeatable.",
    )
    parser.add_argument(
        "--note",
        action="append",
        default=[],
        help="Note bullet to stash in references/notes.md. Repeatable.",
    )
    parser.add_argument(
        "--depth",
        type=int,
        default=0,
        help="Clone depth for reference repos (default: 0 for full clone).",
    )
    parser.add_argument(
        "--no-clone",
        action="store_true",
        help="Skip cloning repos (still writes index + files).",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Stop at first clone failure (otherwise continue and record failures in references/index.md).",
    )
    args = parser.parse_args()

    try:
        experiment_name = validate_dir_name(args.name)
    except ValueError as e:
        parser.error(str(e))

    root = Path(args.root).expanduser().resolve()
    exp_dir = root / experiment_name

    try:
        ensure_empty_dir(exp_dir)
    except FileExistsError as e:
        _print_err(f"[ERROR] {e}")
        return 1

    refs_dir = exp_dir / "references"
    repos_dir = refs_dir / "repos"

    exp_dir.mkdir(parents=True, exist_ok=True)
    refs_dir.mkdir(parents=True, exist_ok=True)
    repos_dir.mkdir(parents=True, exist_ok=True)

    (exp_dir / ".gitignore").write_text(format_gitignore())
    (refs_dir / "notes.md").write_text(format_notes_md(args.note))
    (refs_dir / "links.md").write_text(format_links_md(args.urls))

    repo_refs = [parse_repo_ref(raw) for raw in args.repo]

    clone_results: list[CloneResult] = []
    any_failures = False

    if not args.no_clone and repo_refs:
        for repo in repo_refs:
            if repo.owner and repo.name:
                dest = repos_dir / repo.owner / repo.name
            else:
                safe = re.sub(r"[^A-Za-z0-9_.-]+", "-", repo.raw).strip("-") or "repo"
                dest = repos_dir / safe

            res = clone_repo(repo, dest=dest, depth=args.depth, strict=args.strict)
            dest_relpath = dest.relative_to(refs_dir).as_posix()
            clone_results.append(dataclasses.replace(res, dest_relpath=dest_relpath))

            if res.status == "failed":
                any_failures = True
                _print_err(f"[WARN] Failed to clone: {repo.owner_repo or repo.raw}")
                if args.strict:
                    break
            else:
                print(
                    f"[OK] {res.status}: {repo.owner_repo or repo.raw} -> {dest_relpath}"
                )

    (refs_dir / "index.md").write_text(
        format_index_md(
            experiment_name=experiment_name,
            goal=args.goal,
            repos_dir_relpath="repos/",
            clone_results=clone_results,
        )
    )
    (exp_dir / "AGENTS.md").write_text(
        format_agents_md(experiment_name=experiment_name, goal=args.goal)
    )

    git_init = _run(["git", "init"], cwd=exp_dir)
    if git_init.returncode != 0:
        _print_err("[ERROR] Failed to run `git init`.")
        _print_err((git_init.stderr or git_init.stdout or "").strip())
        return 1

    print(f"[OK] Created experiment: {exp_dir}")
    print(
        "[OK] Wrote: AGENTS.md, .gitignore, references/index.md, references/notes.md, references/links.md"
    )
    if args.repo and not args.no_clone:
        print("[OK] Cloned repos under references/repos/ (gitignored)")

    return 2 if any_failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
