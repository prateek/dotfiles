#!/usr/bin/env python3
"""Report duplicate basenames in a document tree."""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path


def include_path(path: Path, include_hidden: bool) -> bool:
    if include_hidden:
        return True
    return not any(part.startswith(".") for part in path.parts)


def duplicate_name_report(
    root: Path,
    include_hidden: bool = False,
    min_occurrences: int = 2,
) -> dict[str, object]:
    groups: dict[str, list[dict[str, object]]] = defaultdict(list)

    for path in root.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(root)
        if not include_path(relative, include_hidden):
            continue
        key = path.name.lower()
        groups[key].append(
            {
                "name": path.name,
                "path": str(relative),
                "size_bytes": path.stat().st_size,
            }
        )

    duplicates = [
        {"basename": occurrences[0]["name"], "occurrences": sorted(occurrences, key=lambda item: item["path"])}
        for occurrences in groups.values()
        if len(occurrences) >= min_occurrences
    ]
    duplicates.sort(key=lambda item: (-len(item["occurrences"]), item["basename"].lower()))

    return {
        "root": str(root.resolve()),
        "include_hidden": include_hidden,
        "min_occurrences": min_occurrences,
        "duplicate_groups": duplicates,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", help="Root directory to analyze")
    parser.add_argument("--include-hidden", action="store_true", help="Include hidden files and folders")
    parser.add_argument("--min-occurrences", type=int, default=2, help="Minimum duplicate count to report")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    payload = duplicate_name_report(
        Path(args.root),
        include_hidden=args.include_hidden,
        min_occurrences=args.min_occurrences,
    )
    print(json.dumps(payload, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
