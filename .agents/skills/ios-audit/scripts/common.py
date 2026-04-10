#!/usr/bin/env python3
"""Shared helpers for ios-audit collectors, renderers, and diff script.

Conventions:
- Repo-root paths are always absolute.
- JSON files are written with 2-space indentation and trailing newline.
- Env-var interpolation is performed on any string matching ${NAME} or $NAME.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

ENV_RE = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}|\$([A-Za-z_][A-Za-z0-9_]*)")


@dataclass(frozen=True)
class RepoInfo:
    root: Path
    git_rev: str
    git_branch: str
    git_dirty: bool

    def as_meta(self) -> dict[str, Any]:
        return {
            "root": str(self.root),
            "git_rev": self.git_rev,
            "git_branch": self.git_branch,
            "git_dirty": self.git_dirty,
        }


def detect_repo(path: str | Path) -> RepoInfo:
    """Detect repository root and current git state for the given path."""
    p = Path(path).resolve()
    if not p.exists():
        raise FileNotFoundError(f"repo path does not exist: {p}")

    try:
        root_out = subprocess.run(
            ["git", "-C", str(p), "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        rev = subprocess.run(
            ["git", "-C", str(p), "rev-parse", "HEAD"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        branch = subprocess.run(
            ["git", "-C", str(p), "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        status = subprocess.run(
            ["git", "-C", str(p), "status", "--porcelain"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        raise RuntimeError(f"not a git repo or git unavailable: {p}") from e

    return RepoInfo(
        root=Path(root_out),
        git_rev=rev,
        git_branch=branch,
        git_dirty=bool(status),
    )


def expand_env(value: Any, *, strict: bool = True) -> Any:
    """Recursively expand ${VAR} and $VAR references inside strings.

    When strict=True, missing env vars raise KeyError.
    Dicts and lists are traversed; other types pass through.
    """
    if isinstance(value, str):
        def replace(match: re.Match[str]) -> str:
            name = match.group(1) or match.group(2)
            if name not in os.environ:
                if strict:
                    raise KeyError(f"env var ${{{name}}} is not set")
                return ""
            return os.environ[name]
        return ENV_RE.sub(replace, value)
    if isinstance(value, dict):
        return {k: expand_env(v, strict=strict) for k, v in value.items()}
    if isinstance(value, list):
        return [expand_env(v, strict=strict) for v in value]
    return value


def tool_version(tool: str, version_flag: str = "--version") -> str | None:
    """Return the version string for a CLI tool, or None if not installed."""
    path = shutil.which(tool)
    if not path:
        return None
    try:
        result = subprocess.run(
            [path, version_flag],
            capture_output=True, text=True, timeout=5,
        )
        output = (result.stdout or result.stderr).strip().splitlines()
        return output[0] if output else path
    except (subprocess.TimeoutExpired, OSError):
        return path


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, sort_keys=False, default=_json_default)
        f.write("\n")


def read_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def _json_default(obj: Any) -> Any:
    if isinstance(obj, Path):
        return str(obj)
    if isinstance(obj, (datetime,)):
        return obj.isoformat()
    raise TypeError(f"not JSON-serializable: {type(obj).__name__}")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def safe_grep(
    patterns: Iterable[str],
    root: Path,
    *,
    include: Iterable[str] = ("*.swift",),
    exclude_dirs: Iterable[str] = (
        ".build", "DerivedData", "Pods", "Carthage",
        ".audit", ".git", "Tuist", "build",
    ),
) -> list[dict[str, Any]]:
    """Regex-grep Swift files under `root` for the given patterns.

    Uses pure Python (no ripgrep dependency). Returns list of
    {path, line, column, pattern, match, context} dicts.
    """
    include_tuple = tuple(include)
    exclude_set = set(exclude_dirs)
    compiled = [(p, re.compile(p)) for p in patterns]
    results: list[dict[str, Any]] = []

    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in exclude_set and not d.startswith(".")]
        for fn in filenames:
            if not any(_matches_glob(fn, g) for g in include_tuple):
                continue
            full = Path(dirpath) / fn
            try:
                with full.open("r", encoding="utf-8", errors="replace") as f:
                    for lineno, line in enumerate(f, start=1):
                        for raw, rx in compiled:
                            m = rx.search(line)
                            if m:
                                results.append({
                                    "path": str(full.relative_to(root)),
                                    "line": lineno,
                                    "column": m.start() + 1,
                                    "pattern": raw,
                                    "match": m.group(0),
                                    "context": line.rstrip("\n"),
                                })
            except OSError:
                continue
    return results


def _matches_glob(name: str, pattern: str) -> bool:
    import fnmatch
    return fnmatch.fnmatch(name, pattern)


def find_swift_project_root(repo: Path) -> Path:
    """Return the first dir under repo that contains *.xcodeproj, *.xcworkspace, or Package.swift."""
    candidates = [repo]
    for sub in repo.iterdir() if repo.is_dir() else []:
        if sub.is_dir():
            candidates.append(sub)
    for c in candidates:
        if any(c.glob("*.xcworkspace")) or any(c.glob("*.xcodeproj")) or (c / "Package.swift").exists():
            return c
    return repo


def eprint(*args: Any, **kwargs: Any) -> None:
    print(*args, file=sys.stderr, **kwargs)
