"""Portable artifact validation; deliberately needs only the Python standard library."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import stat


RECEIPT = "release.json"


def contained(root: Path, relative: str) -> Path:
    path = Path(relative)
    if path.is_absolute() or ".." in path.parts or not relative:
        raise ValueError(f"unsafe path: {relative!r}")
    target = root / path
    for parent in (target, *target.parents):
        if parent.is_symlink():
            raise ValueError(f"symlink is not supported: {parent}")
        if parent == root:
            break
    return target


def tree_files(root: Path, *, skip: set[str] = frozenset()) -> dict[str, dict]:
    if root.is_symlink() or not root.is_dir():
        raise ValueError(f"expected ordinary directory: {root}")
    result = {}
    def skipped(path: Path) -> bool:
        relative = path.relative_to(root).as_posix()
        return relative in skip or any(item.startswith("**/") and path.name == item[3:] for item in skip)
    paths = []
    for directory, dirs, files in os.walk(root):
        dirs[:] = sorted(name for name in dirs if not skipped(Path(directory) / name))
        paths.extend(Path(directory) / name for name in [*dirs, *files] if not skipped(Path(directory) / name))
    for path in sorted(paths):
        relative = path.relative_to(root).as_posix()
        mode = path.lstat().st_mode
        if stat.S_ISLNK(mode):
            raise ValueError(f"symlink is not supported: {path}")
        if stat.S_ISREG(mode):
            result[relative] = {"sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "mode": stat.S_IMODE(mode)}
        elif not stat.S_ISDIR(mode):
            raise ValueError(f"unsupported file type: {path}")
    return result


def digest(files: dict) -> str:
    return hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest()


def source_files(root: Path) -> dict:
    return tree_files(root, skip={"build", ".venv", ".git", "**/__pycache__"})


def validate_artifact(root: Path) -> dict:
    receipt = json.loads(contained(root, RECEIPT).read_text())
    if receipt.get("schema") != 1 or not receipt.get("files"):
        raise ValueError(f"missing or unsupported release receipt: {root}")
    if tree_files(root, skip={RECEIPT}) != receipt["files"]:
        raise ValueError(f"artifact bytes or modes differ from release receipt: {root}")
    catalogs = [json.loads((root / path).read_text()) for path in
                (".claude-plugin/marketplace.json", ".agents/plugins/marketplace.json")]
    if catalogs[0]["name"] != catalogs[1]["name"]:
        raise ValueError("marketplace names differ")
    expected = {path.name for path in (root / "plugins").iterdir() if path.is_dir()}
    for catalog in catalogs:
        entries = catalog["plugins"]
        if len(entries) != len(expected) or {p["name"] for p in entries} != expected:
            raise ValueError("marketplace membership differs from plugin payload")
        for entry in entries:
            source = entry["source"]
            source = source["path"] if isinstance(source, dict) else source
            if contained(root, source) != root / "plugins" / entry["name"]:
                raise ValueError(f"invalid marketplace source: {source}")
    return receipt


if __name__ == "__main__":
    import sys
    print(digest(source_files(Path(sys.argv[1]))))
