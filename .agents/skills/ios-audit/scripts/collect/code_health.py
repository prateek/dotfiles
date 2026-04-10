"""Code Health collector.

Captures:
- File inventory (Swift file tree, LOC per file)
- Module/target layout (Tuist graph if available)
- Lint output (SwiftLint JSON if available)
- Dead code candidates (Periphery JSON if available)
- Cyclomatic complexity heuristic (regex-based)
- Per-screen layer hierarchies (SwiftUI View → body tree parse)
- Concurrency smells (Task fire-and-forget, nonisolated(unsafe), @unchecked Sendable, etc.)
- TODO / FIXME / XXX markers

Output: <output_dir>/code_health.json
"""

from __future__ import annotations

import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any

from common import RepoInfo, eprint, safe_grep, tool_version, write_json

# Patterns we always grep for regardless of tool availability.
CONCURRENCY_SMELLS = [
    r"\bTask\s*\{",                       # every raw Task{} call
    r"Task\.detached\s*\{",               # detached Tasks
    r"nonisolated\(unsafe\)",             # unsafe nonisolated
    r"@unchecked\s+Sendable",             # unchecked Sendable
    r"DispatchQueue\.(main|global)\.async\s*\{",
    r"\.sync\s*\{",
    r"\bRunLoop\.current",
    r"semaphore|DispatchSemaphore",
    r"\bUnsafe\w+Pointer",
]

ERROR_HANDLING_SMELLS = [
    r"\btry\?",                           # silent try?
    r"catch\s*\{[\s\n]*\}",               # empty catch
    r"//\s*TODO",
    r"//\s*FIXME",
    r"//\s*XXX",
    r"//\s*HACK",
    r"fatalError\s*\(",
    r"preconditionFailure\s*\(",
]

FORCE_UNWRAP = [
    r"\w+!\.",                            # force unwrap chain
    r"\bas!\s+\w",                        # as! cast
    r"!\s*\)",                            # trailing force unwrap
]


def collect(*, repo: RepoInfo, output_dir: Path) -> None:
    root = repo.root
    out: dict[str, Any] = {
        "file_inventory": _file_inventory(root),
        "modules": _modules(root),
        "swiftlint": _run_swiftlint(root),
        "periphery": _run_periphery(root),
        "complexity_hotspots": _complexity_hotspots(root),
        "layer_hierarchies": _layer_hierarchies(root),
        "concurrency_smells": safe_grep(CONCURRENCY_SMELLS, root),
        "error_handling_smells": safe_grep(ERROR_HANDLING_SMELLS, root),
        "force_unwraps": safe_grep(FORCE_UNWRAP, root),
        "todo_markers": _todo_markers(root),
        "tool_versions": {
            "swiftlint": tool_version("swiftlint", "version"),
            "periphery": tool_version("periphery", "version"),
            "tuist": tool_version("tuist", "version"),
        },
    }
    write_json(output_dir / "code_health.json", out)


def _file_inventory(root: Path) -> dict[str, Any]:
    """Enumerate Swift files with line counts, grouped by top-level directory."""
    files: list[dict[str, Any]] = []
    exclude = {".git", ".build", "DerivedData", "Pods", "Carthage", ".audit", "Tuist", "build"}
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in exclude and not d.startswith(".")]
        for fn in filenames:
            if not fn.endswith(".swift"):
                continue
            full = Path(dirpath) / fn
            try:
                with full.open("r", encoding="utf-8", errors="replace") as f:
                    loc = sum(1 for _ in f)
            except OSError:
                continue
            files.append({
                "path": str(full.relative_to(root)),
                "loc": loc,
                "size_bytes": full.stat().st_size,
            })
    files.sort(key=lambda f: f["loc"], reverse=True)
    total_loc = sum(f["loc"] for f in files)
    return {
        "total_files": len(files),
        "total_loc": total_loc,
        "largest_files": files[:50],
        "by_top_level": _group_by_top_level(files),
    }


def _group_by_top_level(files: list[dict[str, Any]]) -> dict[str, dict[str, int]]:
    groups: dict[str, dict[str, int]] = {}
    for f in files:
        top = Path(f["path"]).parts[0]
        g = groups.setdefault(top, {"files": 0, "loc": 0})
        g["files"] += 1
        g["loc"] += f["loc"]
    return dict(sorted(groups.items(), key=lambda kv: kv[1]["loc"], reverse=True))


def _modules(root: Path) -> dict[str, Any]:
    """Detect Xcode targets / Tuist modules / SPM packages."""
    result: dict[str, Any] = {"xcodeproj": [], "xcworkspace": [], "tuist_graph": None, "spm": []}
    for p in root.glob("*.xcodeproj"):
        result["xcodeproj"].append(str(p.relative_to(root)))
    for p in root.glob("*.xcworkspace"):
        result["xcworkspace"].append(str(p.relative_to(root)))
    for p in root.rglob("Package.swift"):
        if any(part.startswith(".") for part in p.parts):
            continue
        result["spm"].append(str(p.relative_to(root)))

    if (root / "Tuist").exists() or (root / "Project.swift").exists():
        try:
            g = subprocess.run(
                ["tuist", "graph", "--format", "json", "--skip-open"],
                cwd=root, capture_output=True, text=True, timeout=60,
            )
            if g.returncode == 0 and g.stdout:
                try:
                    result["tuist_graph"] = json.loads(g.stdout)
                except json.JSONDecodeError:
                    result["tuist_graph"] = {"raw": g.stdout[:4000]}
            else:
                result["tuist_graph"] = {"error": g.stderr.strip() or "tuist failed"}
        except (FileNotFoundError, subprocess.TimeoutExpired) as e:
            result["tuist_graph"] = {"error": str(e)}
    return result


def _run_swiftlint(root: Path) -> dict[str, Any]:
    if not tool_version("swiftlint", "version"):
        return {"tool_missing": "swiftlint not on PATH"}
    try:
        r = subprocess.run(
            ["swiftlint", "lint", "--reporter", "json", "--quiet"],
            cwd=root, capture_output=True, text=True, timeout=300,
        )
        if r.stdout:
            try:
                return {"violations": json.loads(r.stdout)}
            except json.JSONDecodeError:
                return {"error": "swiftlint emitted non-JSON", "raw_head": r.stdout[:2000]}
        return {"violations": [], "stderr_head": r.stderr[:2000]}
    except subprocess.TimeoutExpired:
        return {"error": "swiftlint timed out"}


def _run_periphery(root: Path) -> dict[str, Any]:
    if not tool_version("periphery", "version"):
        return {"tool_missing": "periphery not on PATH"}
    # Periphery needs an Xcode project; detect.
    projects = list(root.glob("*.xcworkspace")) or list(root.glob("*.xcodeproj"))
    if not projects:
        return {"error": "no Xcode project/workspace at repo root"}
    try:
        r = subprocess.run(
            ["periphery", "scan", "--format", "json", "--quiet"],
            cwd=root, capture_output=True, text=True, timeout=600,
        )
        if r.stdout:
            try:
                return {"results": json.loads(r.stdout)}
            except json.JSONDecodeError:
                return {"error": "non-JSON output", "raw_head": r.stdout[:2000]}
        return {"results": [], "stderr_head": r.stderr[:2000]}
    except subprocess.TimeoutExpired:
        return {"error": "periphery timed out"}


COMPLEXITY_TOKENS = re.compile(
    r"\b(if|else if|for|while|case|catch|guard|&&|\|\|)\b|\?",
)


def _complexity_hotspots(root: Path, top_n: int = 30) -> list[dict[str, Any]]:
    """Heuristic cyclomatic complexity per Swift file.

    Counts branching tokens to approximate cyclomatic complexity (Swift-aware).
    Not a replacement for lizard/SwiftLint's cyclomatic_complexity rule, but
    portable and tool-free.
    """
    hotspots: list[dict[str, Any]] = []
    exclude = {".git", ".build", "DerivedData", "Pods", "Carthage", ".audit"}
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in exclude and not d.startswith(".")]
        for fn in filenames:
            if not fn.endswith(".swift"):
                continue
            full = Path(dirpath) / fn
            try:
                text = full.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            branch_count = len(COMPLEXITY_TOKENS.findall(text))
            func_count = text.count("func ")
            loc = text.count("\n") + 1
            score = branch_count + func_count * 0.2 + loc * 0.01
            hotspots.append({
                "path": str(full.relative_to(root)),
                "loc": loc,
                "branches": branch_count,
                "funcs": func_count,
                "score": round(score, 2),
            })
    hotspots.sort(key=lambda h: h["score"], reverse=True)
    return hotspots[:top_n]


VIEW_DECL = re.compile(
    r"(?m)^\s*(?:public\s+|internal\s+|private\s+|fileprivate\s+)?struct\s+(\w+)\s*:\s*View\b"
)


def _layer_hierarchies(root: Path, max_files: int = 80) -> list[dict[str, Any]]:
    """Parse SwiftUI `View` structs and extract their body's container stack.

    For each file containing a `struct XxxView: View`, walks the `var body`
    and emits a nested list of container type names in source order. Not
    a full AST, but enough to describe layer stacking for doc purposes.
    """
    views: list[dict[str, Any]] = []
    exclude = {".git", ".build", "DerivedData", "Pods", "Carthage", ".audit", "Tests"}
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in exclude and not d.startswith(".")]
        for fn in filenames:
            if not fn.endswith(".swift"):
                continue
            full = Path(dirpath) / fn
            try:
                text = full.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            for m in VIEW_DECL.finditer(text):
                name = m.group(1)
                body_start = text.find("var body", m.end())
                if body_start == -1:
                    continue
                open_brace = text.find("{", body_start)
                if open_brace == -1:
                    continue
                body = _balanced_block(text, open_brace)
                hierarchy = _extract_containers(body)
                views.append({
                    "path": str(full.relative_to(root)),
                    "view": name,
                    "container_stack": hierarchy,
                })
                if len(views) >= max_files:
                    return views
    return views


def _balanced_block(text: str, open_idx: int) -> str:
    depth = 0
    for i in range(open_idx, len(text)):
        c = text[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return text[open_idx + 1:i]
    return text[open_idx + 1:]


CONTAINER_RE = re.compile(
    r"\b(VStack|HStack|ZStack|LazyVStack|LazyHStack|LazyVGrid|LazyHGrid|Grid|"
    r"Group|List|ScrollView|NavigationStack|NavigationSplitView|NavigationView|"
    r"TabView|Form|Section|GeometryReader|TimelineView)\b"
)


def _extract_containers(body: str) -> list[dict[str, Any]]:
    """Return a flat ordered list of container tokens with depth approximation."""
    containers: list[dict[str, Any]] = []
    depth = 0
    i = 0
    while i < len(body):
        c = body[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth = max(0, depth - 1)
        m = CONTAINER_RE.match(body, i)
        if m:
            containers.append({"kind": m.group(1), "depth": depth})
            i = m.end()
            continue
        i += 1
    return containers


def _todo_markers(root: Path) -> list[dict[str, Any]]:
    return safe_grep([r"//\s*(TODO|FIXME|XXX|HACK)[:\s]"], root)
