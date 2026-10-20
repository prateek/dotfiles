#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""Summarize directory structure for document-organization audits."""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable


@dataclass
class TreeEntry:
    path: str
    depth: int
    direct_file_count: int
    total_file_count: int
    child_dir_count: int
    total_size_bytes: int


def include_path(path: Path, include_hidden: bool) -> bool:
    if include_hidden:
        return True
    return not any(part.startswith(".") for part in path.parts)


def iter_files(root: Path, include_hidden: bool) -> Iterable[Path]:
    for path in root.rglob("*"):
        if path.is_file() and include_path(path.relative_to(root), include_hidden):
            yield path


def build_inventory(root: Path, max_depth: int = 2, include_hidden: bool = False) -> list[TreeEntry]:
    root = root.resolve()
    directories = [root]
    for path in root.rglob("*"):
        if not path.is_dir():
            continue
        relative = path.relative_to(root)
        if not include_path(relative, include_hidden):
            continue
        depth = len(relative.parts)
        if depth <= max_depth:
            directories.append(path)

    entries: list[TreeEntry] = []
    for directory in sorted(directories):
        relative = directory.relative_to(root)
        depth = len(relative.parts)
        direct_files = 0
        child_dirs = 0
        for child in directory.iterdir():
            child_relative = child.relative_to(root)
            if not include_path(child_relative, include_hidden):
                continue
            if child.is_file():
                direct_files += 1
            elif child.is_dir():
                child_dirs += 1

        total_files = 0
        total_size = 0
        for file_path in iter_files(directory, include_hidden):
            total_files += 1
            total_size += file_path.stat().st_size

        path_label = "." if directory == root else str(relative)
        entries.append(
            TreeEntry(
                path=path_label,
                depth=depth,
                direct_file_count=direct_files,
                total_file_count=total_files,
                child_dir_count=child_dirs,
                total_size_bytes=total_size,
            )
        )
    return entries


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", help="Root directory to summarize")
    parser.add_argument("--max-depth", type=int, default=2, help="Maximum directory depth to include")
    parser.add_argument("--include-hidden", action="store_true", help="Include hidden files and folders")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = Path(args.root)
    entries = build_inventory(root, max_depth=args.max_depth, include_hidden=args.include_hidden)
    payload = {
        "root": str(root.resolve()),
        "max_depth": args.max_depth,
        "include_hidden": args.include_hidden,
        "entries": [asdict(entry) for entry in entries],
    }
    print(json.dumps(payload, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
