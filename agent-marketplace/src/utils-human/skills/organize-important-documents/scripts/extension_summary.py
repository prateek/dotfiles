#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""Summarize file extensions in a document tree."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path


def include_path(path: Path, include_hidden: bool) -> bool:
    if include_hidden:
        return True
    return not any(part.startswith(".") for part in path.parts)


def summarize_extensions(root: Path, include_hidden: bool = False) -> dict[str, object]:
    counter: Counter[str] = Counter()
    total_files = 0

    for path in root.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(root)
        if not include_path(relative, include_hidden):
            continue
        total_files += 1
        suffix = path.suffix.lower().lstrip(".") or "[no_ext]"
        counter[suffix] += 1

    extensions = [
        {"extension": extension, "count": count}
        for extension, count in sorted(counter.items(), key=lambda item: (-item[1], item[0]))
    ]
    return {
        "root": str(root.resolve()),
        "include_hidden": include_hidden,
        "total_files": total_files,
        "extensions": extensions,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", help="Root directory to analyze")
    parser.add_argument("--include-hidden", action="store_true", help="Include hidden files and folders")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    payload = summarize_extensions(Path(args.root), include_hidden=args.include_hidden)
    print(json.dumps(payload, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
