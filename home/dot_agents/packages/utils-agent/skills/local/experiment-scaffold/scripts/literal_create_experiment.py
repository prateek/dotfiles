#!/usr/bin/env python3
from __future__ import annotations

import argparse
import dataclasses
import os
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
    sparse_paths: tuple[str, ...] = ()


@dataclasses.dataclass(frozen=True)
class SeedSource:
    path: Path
    kind: str
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


def parse_repo_sparse_specs(raw_specs: list[str]) -> dict[str, list[str]]:
    sparse_by_repo: dict[str, list[str]] = {}
    for raw_spec in raw_specs:
        if "=" not in raw_spec:
            raise ValueError(
                "Sparse checkout specs must use REPO=PATH[,PATH...] syntax."
            )

        repo_key, raw_paths = raw_spec.split("=", 1)
        repo_key = repo_key.strip()
        paths = [
            normalize_sparse_path(path)
            for path in raw_paths.split(",")
            if path.strip()
        ]

        if not repo_key:
            raise ValueError("Sparse checkout repo key must be non-empty.")
        if not paths:
            raise ValueError(
                f"Sparse checkout spec for {repo_key!r} must include at least one path."
            )

        sparse_by_repo.setdefault(repo_key, []).extend(paths)

    return sparse_by_repo


def normalize_sparse_path(raw_path: str) -> str:
    path = raw_path.strip()
    while path.startswith("./"):
        path = path[2:]
    path = path.rstrip("/")

    if not path or path == ".":
        raise ValueError("Sparse checkout paths must be repo-relative paths.")
    if path.startswith("/") or "\\" in path:
        raise ValueError(f"Sparse checkout path must be repo-relative: {raw_path!r}")
    if ".." in Path(path).parts:
        raise ValueError(f"Sparse checkout path must not contain '..': {raw_path!r}")

    return path


def repo_sparse_match_keys(repo: RepoRef) -> list[str]:
    keys = [
        repo.raw,
        repo.owner_repo,
        repo.https_url,
        repo.https_url.removesuffix(".git") if repo.https_url else None,
        repo.ssh_url,
    ]

    deduped: list[str] = []
    for key in keys:
        if key and key not in deduped:
            deduped.append(key)
    return deduped


def sparse_paths_for_repo(
    repo: RepoRef,
    sparse_by_repo: dict[str, list[str]],
    consumed_keys: set[str],
) -> tuple[str, ...]:
    paths: list[str] = []
    for key in repo_sparse_match_keys(repo):
        repo_paths = sparse_by_repo.get(key)
        if not repo_paths:
            continue
        consumed_keys.add(key)
        paths.extend(repo_paths)

    deduped: list[str] = []
    for path in paths:
        if path not in deduped:
            deduped.append(path)
    return tuple(deduped)


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


def grm_is_available() -> bool:
    return shutil.which("grm") is not None


def default_canonical_root() -> Path:
    return Path(
        os.environ.get("GHPATH", str(Path.home() / "code" / "github.com"))
    ).expanduser()


def default_cache_root() -> Path:
    return Path(
        os.environ.get(
            "EXPERIMENT_SCAFFOLD_CACHE_ROOT",
            str(Path.home() / "code" / "experiments" / "reference-cache"),
        )
    ).expanduser()


def canonical_repo_path(repo: RepoRef, canonical_root: Path) -> Path | None:
    if repo.host != "github.com" or not repo.owner or not repo.name:
        return None
    return canonical_root / repo.owner / repo.name


def cache_repo_path(repo: RepoRef, cache_root: Path) -> Path:
    host = repo.host or "unknown-host"
    if repo.owner and repo.name:
        return cache_root / host / repo.owner / repo.name

    safe = re.sub(r"[^A-Za-z0-9_.-]+", "-", repo.raw).strip("-") or "repo"
    return cache_root / host / safe


def git_fetch_prune(repo_dir: Path) -> tuple[bool, str | None]:
    result = _run(["git", "fetch", "--prune"], cwd=repo_dir)
    detail = (result.stderr or result.stdout or "").strip() or None
    return result.returncode == 0, detail


def resolve_default_branch(repo_dir: Path) -> str | None:
    origin_head = _run(
        ["git", "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD"],
        cwd=repo_dir,
    )
    if origin_head.returncode == 0:
        ref = origin_head.stdout.strip()
        if ref.startswith("origin/"):
            return ref.split("/", 1)[1]

    branch = _run(["git", "branch", "--show-current"], cwd=repo_dir).stdout.strip()
    return branch or None


def copy_repo_tree(source: Path, dest: Path) -> tuple[bool, str, str | None]:
    if shutil.which("fastcp") is not None:
        result = _run(["fastcp", "-R", "-p", str(source), str(dest)])
        detail = (result.stderr or result.stdout or "").strip() or None
        return result.returncode == 0, "fastcp", detail

    try:
        shutil.copytree(source, dest, symlinks=True, copy_function=shutil.copy2)
    except OSError as exc:
        return False, "copytree", str(exc)

    return True, "copytree", None


def normalize_repo_copy(repo_dir: Path) -> tuple[bool, str | None]:
    branch = resolve_default_branch(repo_dir)
    detail_bits: list[str] = []

    if branch:
        remote_ref = f"origin/{branch}"
        remote_exists = _run(
            ["git", "show-ref", "--verify", "--quiet", f"refs/remotes/{remote_ref}"],
            cwd=repo_dir,
        )
        if remote_exists.returncode == 0:
            checkout = _run(
                ["git", "checkout", "--force", "-B", branch, remote_ref], cwd=repo_dir
            )
            if checkout.returncode != 0:
                detail = (checkout.stderr or checkout.stdout or "").strip() or None
                return False, detail

            reset = _run(["git", "reset", "--hard", remote_ref], cwd=repo_dir)
            if reset.returncode != 0:
                detail = (reset.stderr or reset.stdout or "").strip() or None
                return False, detail
            detail_bits.append(f"reset={remote_ref}")
        else:
            checkout = _run(["git", "checkout", "--force", branch], cwd=repo_dir)
            if checkout.returncode != 0:
                detail = (checkout.stderr or checkout.stdout or "").strip() or None
                return False, detail
            detail_bits.append(f"checkout={branch}")

    clean = _run(["git", "clean", "-fdx"], cwd=repo_dir)
    if clean.returncode != 0:
        detail = (clean.stderr or clean.stdout or "").strip() or None
        return False, detail

    detail_bits.append("cleaned")
    return True, ", ".join(detail_bits)


def find_existing_seed_source(
    repo: RepoRef,
    *,
    canonical_root: Path,
    cache_root: Path,
    use_grm: bool,
) -> SeedSource | None:
    canonical_path = canonical_repo_path(repo, canonical_root)
    if use_grm and canonical_path and canonical_path.exists():
        fetched, fetch_detail = git_fetch_prune(canonical_path)
        detail = None if fetched else f"fetch_failed: {fetch_detail}"
        return SeedSource(path=canonical_path, kind="canonical", detail=detail)

    cache_path = cache_repo_path(repo, cache_root)
    if cache_path.exists():
        fetched, fetch_detail = git_fetch_prune(cache_path)
        detail = None if fetched else f"fetch_failed: {fetch_detail}"
        return SeedSource(path=cache_path, kind="cache", detail=detail)

    return None


def ensure_seed_source(
    repo: RepoRef,
    *,
    canonical_root: Path,
    cache_root: Path,
    depth: int,
    strict: bool,
    use_grm: bool,
) -> tuple[SeedSource | None, CloneResult | None]:
    seed_source = find_existing_seed_source(
        repo,
        canonical_root=canonical_root,
        cache_root=cache_root,
        use_grm=use_grm,
    )
    if seed_source is not None:
        return seed_source, None

    cache_path = cache_repo_path(repo, cache_root)

    cache_path.parent.mkdir(parents=True, exist_ok=True)
    clone_result = clone_repo(repo, dest=cache_path, depth=depth, strict=strict)
    if clone_result.status == "failed":
        return None, clone_result

    return (
        SeedSource(
            path=cache_path,
            kind="cache",
            detail=f"created_via={clone_result.method or 'clone'}",
        ),
        None,
    )


def materialize_repo(
    repo: RepoRef,
    *,
    dest: Path,
    depth: int,
    strict: bool,
    canonical_root: Path,
    cache_root: Path,
    use_grm: bool,
    sparse_paths: tuple[str, ...] = (),
) -> CloneResult:
    if sparse_paths:
        return materialize_sparse_repo(
            repo,
            dest=dest,
            depth=depth,
            strict=strict,
            canonical_root=canonical_root,
            cache_root=cache_root,
            use_grm=use_grm,
            sparse_paths=sparse_paths,
        )

    if dest.exists():
        return CloneResult(repo=repo, dest_relpath=dest.as_posix(), status="exists")

    if not repo.owner or not repo.name:
        return clone_repo(repo, dest=dest, depth=depth, strict=strict)

    seed_source, failure = ensure_seed_source(
        repo,
        canonical_root=canonical_root,
        cache_root=cache_root,
        depth=depth,
        strict=strict,
        use_grm=use_grm,
    )
    if failure is not None:
        return failure
    assert seed_source is not None

    dest.parent.mkdir(parents=True, exist_ok=True)
    copied, copy_method, copy_detail = copy_repo_tree(seed_source.path, dest)
    if not copied:
        return CloneResult(
            repo=repo,
            dest_relpath=dest.as_posix(),
            status="failed",
            method=copy_method,
            detail=copy_detail,
        )

    normalized, normalize_detail = normalize_repo_copy(dest)
    if not normalized:
        _remove_if_exists(dest)
        return CloneResult(
            repo=repo,
            dest_relpath=dest.as_posix(),
            status="failed",
            method=copy_method,
            detail=normalize_detail,
        )

    detail_parts = [f"seed={seed_source.kind}:{seed_source.path}"]
    if seed_source.detail:
        detail_parts.append(seed_source.detail)
    if copy_detail:
        detail_parts.append(copy_detail)
    if normalize_detail:
        detail_parts.append(normalize_detail)

    return CloneResult(
        repo=repo,
        dest_relpath=dest.as_posix(),
        status="seeded",
        method=f"{copy_method}:{seed_source.kind}",
        detail=" | ".join(detail_parts),
    )


def materialize_sparse_repo(
    repo: RepoRef,
    *,
    dest: Path,
    depth: int,
    strict: bool,
    canonical_root: Path,
    cache_root: Path,
    use_grm: bool,
    sparse_paths: tuple[str, ...],
) -> CloneResult:
    if dest.exists():
        return CloneResult(
            repo=repo,
            dest_relpath=dest.as_posix(),
            status="exists",
            sparse_paths=sparse_paths,
        )

    seed_source = None
    if repo.owner and repo.name:
        seed_source = find_existing_seed_source(
            repo,
            canonical_root=canonical_root,
            cache_root=cache_root,
            use_grm=use_grm,
        )

    if seed_source is not None:
        cloned, clone_method, clone_detail = clone_sparse_from_seed(
            seed_source, dest=dest
        )
        if not cloned:
            return CloneResult(
                repo=repo,
                dest_relpath=dest.as_posix(),
                status="failed",
                method=clone_method,
                detail=clone_detail,
                sparse_paths=sparse_paths,
            )

        base_method = f"{clone_method}:{seed_source.kind}"
        detail_parts = [f"seed={seed_source.kind}:{seed_source.path}"]
        if seed_source.detail:
            detail_parts.append(seed_source.detail)
        if clone_detail:
            detail_parts.append(clone_detail)
    else:
        clone_result = clone_sparse_repo(repo, dest=dest, depth=depth, strict=strict)
        if clone_result.status == "failed":
            return dataclasses.replace(clone_result, sparse_paths=sparse_paths)

        base_method = clone_result.method or "git-sparse"
        detail_parts = ["seed=direct-sparse-clone"]

    initialized, init_detail = initialize_sparse_checkout(dest)
    if not initialized:
        _remove_if_exists(dest)
        return CloneResult(
            repo=repo,
            dest_relpath=dest.as_posix(),
            status="failed",
            method=base_method,
            detail=init_detail,
            sparse_paths=sparse_paths,
        )

    normalized, normalize_detail = normalize_repo_copy(dest)
    if not normalized:
        _remove_if_exists(dest)
        return CloneResult(
            repo=repo,
            dest_relpath=dest.as_posix(),
            status="failed",
            method=base_method,
            detail=normalize_detail,
            sparse_paths=sparse_paths,
        )

    sparse_set, sparse_detail = set_sparse_checkout_paths(dest, sparse_paths)
    if not sparse_set:
        _remove_if_exists(dest)
        return CloneResult(
            repo=repo,
            dest_relpath=dest.as_posix(),
            status="failed",
            method=base_method,
            detail=sparse_detail,
            sparse_paths=sparse_paths,
        )

    if init_detail:
        detail_parts.append(init_detail)
    if normalize_detail:
        detail_parts.append(normalize_detail)
    if sparse_detail:
        detail_parts.append(sparse_detail)

    return CloneResult(
        repo=repo,
        dest_relpath=dest.as_posix(),
        status="seeded" if seed_source is not None else "cloned",
        method=base_method,
        detail=" | ".join(detail_parts),
        sparse_paths=sparse_paths,
    )


def clone_sparse_from_seed(
    seed_source: SeedSource,
    *,
    dest: Path,
) -> tuple[bool, str, str | None]:
    dest.parent.mkdir(parents=True, exist_ok=True)
    result = _run(
        ["git", "clone", "--no-checkout", "--shared", str(seed_source.path), str(dest)]
    )
    detail = (result.stderr or result.stdout or "").strip() or None
    if result.returncode != 0:
        return False, "git-sparse-shared", detail

    origin = _run(["git", "config", "--get", "remote.origin.url"], cwd=seed_source.path)
    origin_url = origin.stdout.strip()
    if origin.returncode == 0 and origin_url:
        set_url = _run(["git", "remote", "set-url", "origin", origin_url], cwd=dest)
        if set_url.returncode != 0:
            set_url_detail = (set_url.stderr or set_url.stdout or "").strip() or None
            return False, "git-sparse-shared", set_url_detail

    return True, "git-sparse-shared", detail


def clone_sparse_repo(
    repo: RepoRef,
    *,
    dest: Path,
    depth: int,
    strict: bool,
) -> CloneResult:
    if dest.exists():
        return CloneResult(repo=repo, dest_relpath=dest.as_posix(), status="exists")

    dest.parent.mkdir(parents=True, exist_ok=True)

    git_flags = ["--no-checkout", "--filter=blob:none", "--sparse"]
    if depth > 0:
        git_flags.append(f"--depth={depth}")

    if shutil.which("git") is None:
        return CloneResult(
            repo=repo,
            dest_relpath=dest.as_posix(),
            status="failed",
            detail="`git` was not found on PATH.",
        )

    attempts = [
        ("git-sparse:ssh", ["git", "clone", *git_flags, repo.ssh_url, str(dest)]),
        ("git-sparse:https", ["git", "clone", *git_flags, repo.https_url, str(dest)]),
        ("git-sparse:raw", ["git", "clone", *git_flags, repo.raw, str(dest)]),
    ]
    attempts = [
        (label, cmd)
        for (label, cmd) in attempts
        if all(part is not None for part in cmd)
    ]

    if not attempts:
        return CloneResult(
            repo=repo,
            dest_relpath=dest.as_posix(),
            status="failed",
            detail="No sparse clone URL could be resolved.",
        )

    for label, cmd in attempts:
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

    last_label, last_cmd = attempts[-1]
    detail = f"All sparse clone attempts failed. Last attempt: {last_label}: {' '.join(last_cmd)}"
    return CloneResult(
        repo=repo,
        dest_relpath=dest.as_posix(),
        status="failed",
        method=last_label,
        detail=detail,
    )


def initialize_sparse_checkout(repo_dir: Path) -> tuple[bool, str | None]:
    result = _run(["git", "sparse-checkout", "init", "--cone"], cwd=repo_dir)
    detail = (result.stderr or result.stdout or "").strip() or None
    return result.returncode == 0, detail


def set_sparse_checkout_paths(
    repo_dir: Path, sparse_paths: tuple[str, ...]
) -> tuple[bool, str | None]:
    cone = _run(["git", "sparse-checkout", "set", "--cone", *sparse_paths], cwd=repo_dir)
    cone_detail = (cone.stderr or cone.stdout or "").strip() or None
    if cone.returncode == 0:
        return True, f"sparse=cone:{', '.join(sparse_paths)}"

    init_no_cone = _run(["git", "sparse-checkout", "init", "--no-cone"], cwd=repo_dir)
    if init_no_cone.returncode != 0:
        init_detail = (init_no_cone.stderr or init_no_cone.stdout or "").strip()
        return False, init_detail or cone_detail

    no_cone = _run(
        ["git", "sparse-checkout", "set", "--no-cone", *sparse_paths], cwd=repo_dir
    )
    no_cone_detail = (no_cone.stderr or no_cone.stdout or "").strip() or None
    if no_cone.returncode == 0:
        return True, f"sparse=no-cone:{', '.join(sparse_paths)}"

    return False, no_cone_detail or cone_detail


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
        f"- `{repos_dir_relpath}`: local repo copies for reference (gitignored)",
        "",
    ]

    if clone_results:
        has_sparse_paths = any(r.sparse_paths for r in clone_results)
        lines.extend(["## Repos", ""])
        if has_sparse_paths:
            lines.append("| Repo | Local path | Sparse paths | Status |")
            lines.append("| --- | --- | --- | --- |")
        else:
            lines.append("| Repo | Local path | Status |")
            lines.append("| --- | --- | --- |")
        for r in clone_results:
            display = r.repo.owner_repo or r.repo.raw or "(unknown)"
            status = r.status if not r.method else f"{r.status} ({r.method})"
            if has_sparse_paths:
                sparse = ", ".join(f"`{path}`" for path in r.sparse_paths) or "-"
                lines.append(
                    f"| `{display}` | `{r.dest_relpath}` | {sparse} | {status} |"
                )
            else:
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
        "--repo-sparse",
        action="append",
        default=[],
        metavar="REPO=PATH[,PATH...]",
        help="Sparse-checkout paths for a repo from --repo. Repeatable.",
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
    parser.add_argument(
        "--canonical-root",
        default=str(default_canonical_root()),
        help="Canonical GitHub clone root (default: ~/code/github.com or $GHPATH).",
    )
    parser.add_argument(
        "--cache-root",
        default=str(default_cache_root()),
        help="Shared experiment reference cache root (default: ~/code/experiments/reference-cache).",
    )
    parser.add_argument(
        "--grm-mode",
        choices=["auto", "on", "off"],
        default="auto",
        help="Whether canonical reuse should require GRM (default: auto).",
    )
    args = parser.parse_args()

    try:
        experiment_name = validate_dir_name(args.name)
    except ValueError as e:
        parser.error(str(e))

    try:
        sparse_by_repo = parse_repo_sparse_specs(args.repo_sparse)
    except ValueError as e:
        parser.error(str(e))

    root = Path(args.root).expanduser().resolve()
    canonical_root = Path(args.canonical_root).expanduser().resolve()
    cache_root = Path(args.cache_root).expanduser().resolve()
    use_grm = {
        "auto": grm_is_available(),
        "on": True,
        "off": False,
    }[args.grm_mode]
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
    consumed_sparse_keys: set[str] = set()
    repo_sparse_paths = [
        sparse_paths_for_repo(repo, sparse_by_repo, consumed_sparse_keys)
        for repo in repo_refs
    ]
    unused_sparse_keys = set(sparse_by_repo) - consumed_sparse_keys
    if unused_sparse_keys:
        unused = ", ".join(sorted(unused_sparse_keys))
        parser.error(f"--repo-sparse specified for repo not listed by --repo: {unused}")

    clone_results: list[CloneResult] = []
    any_failures = False

    if not args.no_clone and repo_refs:
        for repo, sparse_paths in zip(repo_refs, repo_sparse_paths, strict=True):
            if repo.owner and repo.name:
                dest = repos_dir / repo.owner / repo.name
            else:
                safe = re.sub(r"[^A-Za-z0-9_.-]+", "-", repo.raw).strip("-") or "repo"
                dest = repos_dir / safe

            res = materialize_repo(
                repo,
                dest=dest,
                depth=args.depth,
                strict=args.strict,
                canonical_root=canonical_root,
                cache_root=cache_root,
                use_grm=use_grm,
                sparse_paths=sparse_paths,
            )
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
        print("[OK] Materialized repos under references/repos/ (gitignored)")

    return 2 if any_failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
