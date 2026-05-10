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
import subprocess
import sys
from pathlib import Path
from typing import Any

from common import RepoInfo, eprint, safe_grep, write_json
from ux.workflow_matrix import normalize_device_matrix, summarize_device_coverage, validate_workflow_devices

SCRIPT_DIR = Path(__file__).resolve().parent
UX_DIR = SCRIPT_DIR.parent / "ux"
RUN_WORKFLOWS = UX_DIR / "run_workflows.py"

ADAPTIVE_LAYOUT_PATTERNS = [
    r"horizontalSizeClass",
    r"verticalSizeClass",
    r"NavigationSplitView",
    r"ViewThatFits",
    r"GeometryReader",
    r"userInterfaceIdiom",
    r"dynamicTypeSize",
    r"safeAreaInset",
]

SEMANTIC_SURFACE_PATTERNS = {
    "quality": [r"\bquality\b", r"\b4K\b", r"\bHDR\b", r"\bresolution\b"],
    "audio": [r"\baudio\b", r"selectedAudioLanguage", r"\blanguage(s)?\b"],
    "subtitles": [r"\bsubtitle(s)?\b", r"\bcaptions?\b"],
    "downloads": [r"\bdownload(s|ing)?\b", r"\boffline\b", r"resumeData"],
    "playback_preferences": [r"wifiQuality", r"cellularQuality", r"preferredSubtitle", r"playbackSpeed"],
}


def collect(
    *,
    repo: RepoInfo,
    output_dir: Path,
    workflows: Path | None,
    udid: str | None,
    sim_skill_dir: str | None,
) -> None:
    workflow_config = _load_workflow_config(workflows) if workflows else {}
    adaptive_layout_signals = safe_grep(ADAPTIVE_LAYOUT_PATTERNS, repo.root)
    out: dict[str, Any] = {
        "screen_inventory": _screen_inventory(repo.root),
        "navigation_graph": _navigation_graph(repo.root),
        "component_catalog": _component_catalog(repo.root),
        "gesture_usage": _gesture_usage(repo.root),
        "adaptive_layout_signals": adaptive_layout_signals,
        "semantic_surface_signals": _semantic_surface_signals(repo.root),
        "workflow_matrix": _workflow_matrix_summary(workflow_config, adaptive_layout_signals),
        "flows": None,
    }

    if workflows is None:
        out["flows"] = {"skipped": "no --workflows provided"}
    else:
        flow_output = output_dir / "ux_run"
        flow_output.mkdir(parents=True, exist_ok=True)
        # Pass the ORIGINAL workflow path — run_workflows.py expands env
        # vars in-memory so plaintext credentials never touch disk.
        out["flows"] = _run_flows(workflows, flow_output, udid, sim_skill_dir)
        out["workflow_matrix"] = _workflow_matrix_summary(
            workflow_config,
            adaptive_layout_signals,
            out["flows"],
        )
        validation_errors = out["workflow_matrix"].get("validation_errors") or []
        if validation_errors:
            raise RuntimeError("; ".join(validation_errors))

    # Also sanitize the flows output — strip any "Typed" step outputs
    # that might echo the value, just in case the underlying keyboard.py
    # ever changes to log the argument.
    _sanitize_flows(out.get("flows"))
    write_json(output_dir / "ux.json", out)


_TYPED_ECHO_RE = re.compile(r'Typed[:"]*\s*"[^"]*"')


def _sanitize_flows(flows: Any) -> None:
    """Belt-and-braces: walk flow results and redact any 'Typed: "..."' echo
    in step outputs. run_workflows.py already does this, but defense in depth.
    """
    if not isinstance(flows, dict):
        return
    results = flows.get("results")
    if not isinstance(results, dict):
        return
    for wf in results.get("workflows", []) or []:
        for step in wf.get("steps", []) or []:
            if step.get("action") == "type":
                out = step.get("output") or ""
                if _TYPED_ECHO_RE.search(out):
                    step["output"] = "Typed <redacted>"


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


def _load_workflow_config(workflows: Path) -> dict[str, Any]:
    try:
        import yaml
    except ImportError:
        return {}
    try:
        with workflows.open("r", encoding="utf-8") as f:
            return yaml.safe_load(f) or {}
    except OSError:
        return {}


def _semantic_surface_signals(root: Path) -> dict[str, list[dict[str, Any]]]:
    return {
        surface: safe_grep(patterns, root)
        for surface, patterns in SEMANTIC_SURFACE_PATTERNS.items()
    }


def _workflow_matrix_summary(
    workflow_config: dict[str, Any],
    adaptive_layout_signals: list[dict[str, Any]],
    flow_results: dict[str, Any] | None = None,
) -> dict[str, Any]:
    lanes = normalize_device_matrix(workflow_config)
    workflows = workflow_config.get("workflows") or []
    summary = summarize_device_coverage(
        lanes=lanes,
        workflows=workflows,
        flow_results=flow_results,
        adaptive_signals=adaptive_layout_signals,
    )
    summary["declared_lanes"] = lanes
    validation_errors = validate_workflow_devices(workflows, lanes)
    if flow_results is not None:
        validation_errors.extend(summary.get("coverage_gaps") or [])
    summary["validation_errors"] = validation_errors
    return summary


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
    return safe_grep([GESTURE_RE.pattern], root)
