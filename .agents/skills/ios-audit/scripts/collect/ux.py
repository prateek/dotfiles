"""UX collector.

Runs the ported `run_workflows.py` against the workflow YAML, captures
screenshots + accessibility trees, then also scans the repo for SwiftUI
screen declarations to build a static screen inventory + navigation graph.

Output: <output_dir>/ux.json
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

from common import RepoInfo, expand_env, eprint, write_json

SCRIPT_DIR = Path(__file__).resolve().parent
UX_DIR = SCRIPT_DIR.parent / "ux"
RUN_WORKFLOWS = UX_DIR / "run_workflows.py"


def collect(
    *,
    repo: RepoInfo,
    output_dir: Path,
    workflows: Path | None,
    udid: str | None,
    sim_skill_dir: str | None,
) -> None:
    out: dict[str, Any] = {
        "screen_inventory": _screen_inventory(repo.root),
        "navigation_graph": _navigation_graph(repo.root),
        "component_catalog": _component_catalog(repo.root),
        "gesture_usage": _gesture_usage(repo.root),
        "flows": None,
    }

    if workflows is None:
        out["flows"] = {"skipped": "no --workflows provided"}
    else:
        flow_output = output_dir / "ux_run"
        flow_output.mkdir(parents=True, exist_ok=True)
        # Materialize a resolved YAML with env vars expanded
        resolved_yaml = _resolve_workflows(workflows, flow_output)
        out["flows"] = _run_flows(resolved_yaml, flow_output, udid, sim_skill_dir)

    write_json(output_dir / "ux.json", out)


def _resolve_workflows(src: Path, dest_dir: Path) -> Path:
    try:
        import yaml
    except ImportError:
        eprint("pyyaml not installed — copying workflow YAML verbatim")
        dest = dest_dir / src.name
        shutil.copy(src, dest)
        return dest

    with src.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    resolved = expand_env(data, strict=True)
    dest = dest_dir / f"resolved_{src.name}"
    with dest.open("w", encoding="utf-8") as f:
        yaml.safe_dump(resolved, f, sort_keys=False)
    return dest


def _run_flows(
    workflows: Path,
    output_dir: Path,
    udid: str | None,
    sim_skill_dir: str | None,
) -> dict[str, Any]:
    cmd = [
        sys.executable, str(RUN_WORKFLOWS),
        "--workflows", str(workflows),
        "--output-dir", str(output_dir),
        "--json",
    ]
    if udid:
        cmd += ["--udid", udid]
    if sim_skill_dir:
        cmd += ["--sim-skill-dir", sim_skill_dir]

    eprint(f"[ux] running flows: {' '.join(cmd)}")
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=3600)
    except subprocess.TimeoutExpired:
        return {"error": "flow run timed out"}

    results_path = output_dir / "results.json"
    out: dict[str, Any] = {
        "returncode": r.returncode,
        "results_path": str(results_path),
    }
    if results_path.exists():
        with results_path.open("r", encoding="utf-8") as f:
            out["results"] = json.load(f)
    else:
        out["stderr_tail"] = r.stderr[-2000:]
    return out


VIEW_STRUCT_RE = re.compile(
    r"(?m)^\s*(?:public\s+|internal\s+|private\s+|fileprivate\s+)?struct\s+(\w+)\s*:\s*View\b"
)
NAV_DESTINATION_RE = re.compile(r"NavigationLink\s*\([^)]*destination\s*:\s*(\w+)")
NAV_VALUE_RE = re.compile(r"NavigationLink\s*\(\s*(?:value|destination)\s*:\s*([.\w]+)")
SHEET_RE = re.compile(r"\.sheet\s*\([^)]*\)\s*\{[^}]*?(\w+View)")
FULL_SCREEN_COVER_RE = re.compile(r"\.fullScreenCover\s*\([^)]*\)\s*\{[^}]*?(\w+View)")

GESTURE_RE = re.compile(
    r"\.(onTapGesture|onLongPressGesture|gesture|simultaneousGesture|"
    r"highPriorityGesture|swipeActions|contextMenu|onDrag|onDrop)\s*[\({]"
)


def _screen_inventory(root: Path) -> list[dict[str, Any]]:
    inventory: list[dict[str, Any]] = []
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
            for m in VIEW_STRUCT_RE.finditer(text):
                name = m.group(1)
                # Only keep things that "look like screens" not every tiny View.
                is_screen = any(
                    kw in text[max(0, m.start()-200):m.end()+400]
                    for kw in ("NavigationStack", "TabView", ".navigationTitle", ".toolbar", "var body: some View")
                )
                if not is_screen and not name.endswith("View"):
                    continue
                inventory.append({
                    "view": name,
                    "path": str(full.relative_to(root)),
                    "line": text.count("\n", 0, m.start()) + 1,
                    "is_screen_candidate": is_screen,
                })
    return inventory


def _navigation_graph(root: Path) -> list[dict[str, Any]]:
    edges: list[dict[str, Any]] = []
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
            rel = str(full.relative_to(root))
            container_match = VIEW_STRUCT_RE.search(text)
            from_view = container_match.group(1) if container_match else fn
            for rx, kind in (
                (NAV_DESTINATION_RE, "NavigationLink destination"),
                (NAV_VALUE_RE, "NavigationLink value"),
                (SHEET_RE, "sheet"),
                (FULL_SCREEN_COVER_RE, "fullScreenCover"),
            ):
                for m in rx.finditer(text):
                    edges.append({
                        "from": from_view,
                        "to": m.group(1),
                        "kind": kind,
                        "path": rel,
                        "line": text.count("\n", 0, m.start()) + 1,
                    })
    return edges


CUSTOM_VIEW_RE = re.compile(r"struct\s+(\w+)\s*:\s*View\b")


def _component_catalog(root: Path) -> list[dict[str, Any]]:
    """Non-screen reusable Views (heuristic: small, no NavigationStack)."""
    catalog: list[dict[str, Any]] = []
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
            for m in CUSTOM_VIEW_RE.finditer(text):
                name = m.group(1)
                end = text.find("\nstruct", m.end())
                snippet = text[m.start():end if end > 0 else m.end() + 600]
                if "NavigationStack" in snippet or "TabView" in snippet:
                    continue
                if len(snippet) > 4000:
                    continue
                catalog.append({
                    "component": name,
                    "path": str(full.relative_to(root)),
                    "line": text.count("\n", 0, m.start()) + 1,
                    "loc": snippet.count("\n"),
                })
    return catalog


def _gesture_usage(root: Path) -> list[dict[str, Any]]:
    """Call sites of SwiftUI gesture modifiers — useful for conflict detection."""
    from common import safe_grep
    return safe_grep([GESTURE_RE.pattern], root)
