#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Generate a self-contained HTML review viewer for skill eval results.

Walks an iteration directory containing eval-*/{with_skill,without_skill}/...
subdirs and emits a single static review.html with:
  - Left sidebar: list of evals (with pass-rate badges) + a Benchmark entry
  - Eval view: prompt on top, with_skill vs without_skill side-by-side,
    feedback textareas inline at the bottom
  - Benchmark view: per-eval paired bars + assertion discrimination table
  - Keyboard nav: j/k or arrows cycle sidebar, / focuses feedback,
    t toggles theme

Usage:
    python eval-review.py <iteration-dir> [--previous <other-iter>] [--output <path>]

Defaults:
    --output  <iteration-dir>/review.html
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

def safe_read_json(path: Path) -> dict | None:
    """Return parsed JSON or None if file is missing or invalid."""
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text())
    except (json.JSONDecodeError, OSError):
        return None


def safe_read_text(path: Path) -> str | None:
    """Return file text or None if missing / unreadable."""
    if not path.exists():
        return None
    try:
        return path.read_text(errors="replace")
    except OSError:
        return None


def load_config(eval_dir: Path, config: str) -> dict:
    """Load a single configuration (with_skill or without_skill) for one eval."""
    cfg_dir = eval_dir / config
    output_path = cfg_dir / "outputs" / "output.md"
    grading_path = cfg_dir / "grading.json"
    timing_path = cfg_dir / "timing.json"

    output_md = safe_read_text(output_path)
    grading = safe_read_json(grading_path)
    timing = safe_read_json(timing_path)

    return {
        "config": config,
        "output_md": output_md,  # None if missing
        "output_path_rel": str(output_path.relative_to(eval_dir.parent)),
        "grading": grading,
        "timing": timing,
    }


def load_eval(eval_dir: Path) -> dict:
    """Load an eval directory and return the normalized dict used by the viewer."""
    # Prefer the with_skill eval_metadata.json; fall back to without_skill.
    metadata = None
    for cfg in ("with_skill", "without_skill"):
        candidate = eval_dir / cfg / "eval_metadata.json"
        parsed = safe_read_json(candidate)
        if parsed:
            metadata = parsed
            break

    slug = eval_dir.name
    # Strip the "eval-<N>-" prefix for a friendly name.
    friendly = re.sub(r"^eval-\d+-", "", slug)

    eval_id = metadata.get("eval_id") if metadata else None
    eval_name = (metadata.get("eval_name") if metadata else None) or friendly
    prompt = metadata.get("prompt") if metadata else None
    assertions = metadata.get("assertions") if metadata else []

    with_skill = load_config(eval_dir, "with_skill")
    without_skill = load_config(eval_dir, "without_skill")

    return {
        "slug": slug,
        "eval_id": eval_id,
        "eval_name": eval_name,
        "prompt": prompt,
        "assertions": assertions or [],
        "with_skill": with_skill,
        "without_skill": without_skill,
    }


def load_iteration(iteration_dir: Path) -> dict:
    """Load all evals + benchmark + feedback for an iteration."""
    eval_dirs = sorted(
        (d for d in iteration_dir.glob("eval-*") if d.is_dir()),
        key=lambda p: _eval_sort_key(p.name),
    )
    evals = [load_eval(d) for d in eval_dirs]
    benchmark = safe_read_json(iteration_dir / "benchmark.json")
    feedback = safe_read_json(iteration_dir / "feedback.json")
    return {
        "iteration_dir": str(iteration_dir),
        "iteration_name": iteration_dir.name,
        "evals": evals,
        "benchmark": benchmark,
        "feedback": feedback,
    }


def _eval_sort_key(name: str) -> tuple[int, str]:
    """Sort 'eval-10-foo' after 'eval-2-bar' by numeric id."""
    m = re.match(r"^eval-(\d+)-", name)
    if m:
        return (int(m.group(1)), name)
    return (10**9, name)


# ---------------------------------------------------------------------------
# HTML generation
# ---------------------------------------------------------------------------

def build_previous_map(previous: dict | None) -> dict[str, dict]:
    """Map slug -> {with_skill: {output_md}, without_skill: {output_md}}."""
    if not previous:
        return {}
    out: dict[str, dict] = {}
    for ev in previous.get("evals", []):
        out[ev["slug"]] = {
            "with_skill": {"output_md": ev["with_skill"].get("output_md")},
            "without_skill": {"output_md": ev["without_skill"].get("output_md")},
        }
    return out


def generate_html(current: dict, previous: dict | None) -> str:
    skill_name = "write-for-humans"
    if current.get("benchmark") and current["benchmark"].get("metadata"):
        skill_name = current["benchmark"]["metadata"].get("skill_name", skill_name)

    payload = {
        "skill_name": skill_name,
        "iteration_name": current["iteration_name"],
        "evals": current["evals"],
        "benchmark": current.get("benchmark"),
        "feedback": current.get("feedback"),
        "previous_iteration_name": previous["iteration_name"] if previous else None,
        "previous_by_slug": build_previous_map(previous),
    }
    data_json = json.dumps(payload, ensure_ascii=False)
    # Escape </script> so the JSON can safely sit inside a <script> block.
    data_json = data_json.replace("</", "<\\/")

    return HTML_TEMPLATE.replace("__EMBEDDED_DATA__", data_json)


# ---------------------------------------------------------------------------
# HTML template
# ---------------------------------------------------------------------------

HTML_TEMPLATE = r"""<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Eval Review</title>
<style>
/* ---------- Design tokens ---------- */
:root[data-theme="dark"] {
  --bg:         #10131a;
  --bg-raised: #161a23;
  --bg-sunken: #0b0d13;
  --panel:     #1a1f2b;
  --panel-hi:  #222938;
  --border:    #262d3d;
  --border-hi: #33405a;
  --text:      #e6ebf4;
  --text-dim:  #9aa3b8;
  --text-mute: #606a83;
  --accent:       #7aa2ff;
  --accent-weak:  #7aa2ff22;
  --pass:         #4ade80;
  --pass-weak:    #4ade8022;
  --warn:         #fbbf24;
  --warn-weak:    #fbbf2422;
  --fail:         #f87171;
  --fail-weak:    #f8717122;
  --delta-pos:    #4ade80;
  --delta-neg:    #f87171;
  --with-skill:   #7aa2ff;
  --without-skill:#c792ea;
  --shadow: 0 8px 24px rgba(0,0,0,0.4);
}
:root[data-theme="light"] {
  --bg:         #f5f7fb;
  --bg-raised: #ffffff;
  --bg-sunken: #ebeef5;
  --panel:     #ffffff;
  --panel-hi:  #f0f3fa;
  --border:    #d8dde8;
  --border-hi: #b7c0d1;
  --text:      #1a2030;
  --text-dim:  #4a5266;
  --text-mute: #7a8398;
  --accent:       #3d68d8;
  --accent-weak:  #3d68d822;
  --pass:         #1d8b4b;
  --pass-weak:    #1d8b4b22;
  --warn:         #b4790a;
  --warn-weak:    #b4790a22;
  --fail:         #c43d3d;
  --fail-weak:    #c43d3d22;
  --delta-pos:    #1d8b4b;
  --delta-neg:    #c43d3d;
  --with-skill:   #3d68d8;
  --without-skill:#7e42a8;
  --shadow: 0 4px 16px rgba(30,40,80,0.1);
}

* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; background: var(--bg); color: var(--text); }
body {
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, sans-serif;
  font-size: 14px;
  line-height: 1.45;
  height: 100vh;
  overflow: hidden;
}
code, pre, .mono {
  font-family: "SF Mono", "JetBrains Mono", Menlo, Consolas, monospace;
  font-size: 13px;
}

/* ---------- Layout ---------- */
.app {
  display: grid;
  grid-template-columns: 300px 1fr;
  height: 100vh;
}
.sidebar {
  background: var(--bg-sunken);
  border-right: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.sidebar-header {
  padding: 16px;
  border-bottom: 1px solid var(--border);
}
.sidebar-header h1 {
  margin: 0;
  font-size: 14px;
  font-weight: 600;
  color: var(--text);
  display: flex;
  align-items: center;
  gap: 8px;
}
.sidebar-header .iter {
  font-size: 12px;
  color: var(--text-mute);
  margin-top: 2px;
}
.sidebar-summary {
  font-size: 12px;
  color: var(--text-dim);
  margin-top: 8px;
  display: grid;
  grid-template-columns: auto auto;
  gap: 4px 10px;
}
.sidebar-summary .lbl { color: var(--text-mute); }
.sidebar-summary .val { text-align: right; }

.eval-list {
  flex: 1;
  overflow-y: auto;
  padding: 4px 0;
}
.sidebar-sep {
  margin: 8px 14px;
  height: 1px;
  background: var(--border);
}
.eval-item {
  padding: 9px 14px 9px 16px;
  border-left: 3px solid transparent;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  transition: background 0.08s;
}
.eval-item:hover { background: var(--panel-hi); }
.eval-item.active {
  background: var(--accent-weak);
  border-left-color: var(--accent);
}
.eval-item .name {
  font-size: 13px;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
  flex: 1;
}
.eval-item .id {
  color: var(--text-mute);
  font-size: 11px;
  margin-right: 4px;
}
.eval-item.benchmark .name {
  font-weight: 600;
  color: var(--text);
}
.eval-item.benchmark .icon {
  margin-right: 6px;
}
.badge {
  font-family: "SF Mono", Menlo, monospace;
  font-size: 11px;
  font-weight: 600;
  padding: 2px 6px;
  border-radius: 4px;
  white-space: nowrap;
  flex-shrink: 0;
}
.badge.pair { padding: 0; background: transparent; display: inline-flex; gap: 2px; }
.badge.pair > span {
  padding: 2px 5px;
  border-radius: 3px;
  font-size: 10px;
}
.badge-pass { background: var(--pass-weak); color: var(--pass); }
.badge-warn { background: var(--warn-weak); color: var(--warn); }
.badge-fail { background: var(--fail-weak); color: var(--fail); }
.badge-dim  { background: var(--panel-hi);  color: var(--text-mute); }

.sidebar-footer {
  border-top: 1px solid var(--border);
  padding: 10px 16px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 11px;
  color: var(--text-mute);
}
.theme-toggle {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-dim);
  padding: 3px 8px;
  font-size: 11px;
  border-radius: 4px;
  cursor: pointer;
  font-family: inherit;
}
.theme-toggle:hover { border-color: var(--border-hi); color: var(--text); }

/* ---------- Main ---------- */
.main { display: flex; flex-direction: column; overflow: hidden; }
.pane {
  flex: 1;
  overflow-y: auto;
  padding: 20px 24px;
}
.pane h2 {
  margin: 0 0 4px 0;
  font-size: 20px;
  font-weight: 600;
}
.pane .sub { color: var(--text-dim); font-size: 13px; margin-bottom: 20px; }

/* ---------- Prompt card ---------- */
.prompt-card {
  background: var(--panel);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 14px 16px;
  margin-bottom: 20px;
  max-height: 400px;
  overflow-y: auto;
}
.prompt-card .label {
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--text-mute);
  margin-bottom: 6px;
  display: flex;
  align-items: center;
  gap: 8px;
}
.prompt-card .text {
  white-space: pre-wrap;
  line-height: 1.55;
}
.prompt-card.missing .text { color: var(--text-mute); font-style: italic; }

/* ---------- Side-by-side grid ---------- */
.sbs {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}
@media (max-width: 1100px) {
  .sbs { grid-template-columns: 1fr; }
}
.cfg-card {
  background: var(--panel);
  border: 1px solid var(--border);
  border-radius: 8px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}
.cfg-head {
  padding: 10px 14px;
  border-bottom: 1px solid var(--border);
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: var(--bg-raised);
}
.cfg-name {
  font-size: 12px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  display: flex;
  align-items: center;
  gap: 8px;
}
.cfg-name .dot {
  width: 8px; height: 8px; border-radius: 50%;
}
.cfg-name.with    .dot { background: var(--with-skill); }
.cfg-name.without .dot { background: var(--without-skill); }
.cfg-stats { font-size: 12px; color: var(--text-dim); display: flex; gap: 12px; }
.cfg-stats code { color: var(--text); }

.assertions {
  border-top: 1px solid var(--border);
  padding: 0;
}
.assertions summary.assertions-head {
  list-style: none;
  padding: 6px 14px;
  font-size: 11px;
  color: var(--text-mute);
  text-transform: uppercase;
  letter-spacing: 0.06em;
  display: flex;
  align-items: center;
  justify-content: space-between;
  cursor: pointer;
  user-select: none;
}
.assertions summary.assertions-head::-webkit-details-marker { display: none; }
.assertions[open] summary.assertions-head {
  border-bottom: 1px solid var(--border);
}
.assertion {
  padding: 6px 14px;
  display: flex;
  gap: 8px;
  align-items: flex-start;
  font-size: 12.5px;
  line-height: 1.4;
}
.assertion .mark {
  flex-shrink: 0;
  width: 16px;
  text-align: center;
  font-weight: 700;
}
.assertion.pass .mark { color: var(--pass); }
.assertion.fail .mark { color: var(--fail); }
.assertion.fail { background: var(--fail-weak); }
.assertion .text { color: var(--text); }
.assertion .evidence {
  color: var(--text-mute);
  font-size: 11.5px;
  margin-top: 2px;
  font-style: italic;
}

.output {
  padding: 14px 16px;
  flex: 1;
  overflow-x: auto;
}
.output.missing { color: var(--text-mute); font-style: italic; }
.output h1, .output h2, .output h3 { margin: 0.8em 0 0.4em; }
.output h1 { font-size: 18px; }
.output h2 { font-size: 16px; }
.output h3 { font-size: 14px; }
.output p { margin: 0.5em 0; }
.output ul, .output ol { margin: 0.4em 0; padding-left: 20px; }
.output li { margin: 0.1em 0; }
.output code {
  background: var(--bg-sunken);
  padding: 1px 5px;
  border-radius: 3px;
}
.output pre {
  background: var(--bg-sunken);
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 10px 12px;
  overflow-x: auto;
  margin: 0.6em 0;
}
.output pre code { background: transparent; padding: 0; }
.output blockquote {
  border-left: 3px solid var(--border-hi);
  margin: 0.5em 0;
  padding: 0 0 0 12px;
  color: var(--text-dim);
}
.output strong { font-weight: 600; }
.output hr { border: none; border-top: 1px solid var(--border); margin: 1em 0; }

.cfg-foot {
  padding: 8px 14px;
  border-top: 1px solid var(--border);
  background: var(--bg-raised);
  color: var(--text-mute);
  font-size: 11px;
  display: flex;
  gap: 12px;
}

.previous-block {
  margin-top: 12px;
}
.previous-block summary {
  cursor: pointer;
  font-size: 12px;
  color: var(--text-mute);
  padding: 6px 14px;
  user-select: none;
}
.previous-block summary:hover { color: var(--text-dim); }
.previous-block[open] summary { border-bottom: 1px solid var(--border); }

/* ---------- Benchmark ---------- */
.bench-summary {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12px;
  margin-bottom: 24px;
}
.bench-card {
  background: var(--panel);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 14px 16px;
}
.bench-card .label {
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--text-mute);
  margin-bottom: 6px;
}
.bench-card .stats {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 2px 10px;
  font-size: 13px;
}
.bench-card .stats .k { color: var(--text-mute); }
.bench-card .stats .v { text-align: right; font-family: "SF Mono", Menlo, monospace; }
.bench-card .delta {
  margin-top: 6px;
  padding-top: 6px;
  border-top: 1px dashed var(--border);
  display: flex;
  justify-content: space-between;
  font-size: 13px;
}
.delta-pos { color: var(--delta-pos); }
.delta-neg { color: var(--delta-neg); }

.bench-section { margin-bottom: 24px; }
.bench-section h3 {
  font-size: 13px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-dim);
  margin: 0 0 10px 0;
  font-weight: 600;
}
.bench-bars {
  background: var(--panel);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 14px 16px;
}
.bench-row {
  display: grid;
  grid-template-columns: 200px 1fr auto;
  gap: 10px;
  align-items: center;
  padding: 6px 0;
  border-bottom: 1px dashed var(--border);
}
.bench-row:last-child { border-bottom: none; }
.bench-row .rowname { font-size: 12.5px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.bench-bars-pair { display: flex; flex-direction: column; gap: 3px; min-width: 0; }
.bench-bar-line { display: flex; align-items: center; gap: 6px; font-size: 11px; }
.bench-bar-line .swatch {
  width: 8px; height: 8px; border-radius: 2px; flex-shrink: 0;
}
.bench-bar-line .swatch.with    { background: var(--with-skill); }
.bench-bar-line .swatch.without { background: var(--without-skill); }
.bench-bar-track {
  flex: 1;
  height: 14px;
  background: var(--bg-sunken);
  border-radius: 3px;
  position: relative;
  overflow: hidden;
}
.bench-bar-fill {
  position: absolute;
  top: 0; left: 0; bottom: 0;
  background: var(--pass);
  opacity: 0.85;
}
.bench-bar-fail {
  position: absolute;
  top: 0; bottom: 0;
  background: var(--fail);
  opacity: 0.7;
}
.bench-bar-line .pct {
  font-family: "SF Mono", Menlo, monospace;
  font-size: 11px;
  min-width: 44px;
  text-align: right;
  color: var(--text-dim);
}
.bench-row .rowdelta {
  font-family: "SF Mono", Menlo, monospace;
  font-size: 12px;
  min-width: 60px;
  text-align: right;
}

.assert-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 12.5px;
  background: var(--panel);
  border: 1px solid var(--border);
  border-radius: 8px;
  overflow: hidden;
}
.assert-table th, .assert-table td {
  padding: 8px 12px;
  text-align: left;
  border-bottom: 1px solid var(--border);
}
.assert-table th {
  background: var(--bg-raised);
  font-weight: 600;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-dim);
}
.assert-table tr:last-child td { border-bottom: none; }
.assert-table td.num {
  text-align: center;
  font-family: "SF Mono", Menlo, monospace;
  width: 80px;
}
.assert-table td.sig {
  width: 100px;
  text-align: center;
  font-size: 11px;
}
.sig-signal { color: var(--accent); background: var(--accent-weak); padding: 2px 6px; border-radius: 3px; }
.sig-noise  { color: var(--text-mute); }

.bench-notes {
  background: var(--panel);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 12px 16px;
}
.bench-notes li { margin: 4px 0; font-size: 12.5px; }

/* ---------- Feedback (inline, under outputs) ---------- */
.fb-section {
  margin-top: 24px;
  padding-top: 16px;
  border-top: 1px solid var(--border);
}
.fb-section h3 {
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--text-mute);
  margin: 0 0 10px 0;
  font-weight: 600;
}
.fb-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}
@media (max-width: 1100px) {
  .fb-grid { grid-template-columns: 1fr; }
}
.fb-card {
  background: var(--panel);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 12px 14px;
}
.fb-card .fb-label {
  font-size: 11px;
  color: var(--text-mute);
  margin-bottom: 6px;
  display: flex;
  align-items: center;
  gap: 6px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}
.fb-card .fb-label .dot {
  width: 7px; height: 7px; border-radius: 50%;
}
.fb-card .fb-label.with    .dot { background: var(--with-skill); }
.fb-card .fb-label.without .dot { background: var(--without-skill); }
.fb-card textarea {
  width: 100%;
  min-height: 110px;
  background: var(--bg-sunken);
  border: 1px solid var(--border);
  border-radius: 6px;
  color: var(--text);
  padding: 10px;
  font-family: inherit;
  font-size: 13px;
  resize: vertical;
}
.fb-card textarea:focus {
  outline: none;
  border-color: var(--accent);
  box-shadow: 0 0 0 2px var(--accent-weak);
}
.fb-actions {
  margin-top: 12px;
  display: flex;
  gap: 8px;
  align-items: center;
}
.fb-actions .saved {
  color: var(--text-mute);
  font-size: 11px;
  margin-left: auto;
}
.btn {
  background: var(--accent);
  color: white;
  border: none;
  padding: 6px 14px;
  border-radius: 4px;
  font-size: 12px;
  cursor: pointer;
  font-family: inherit;
}
.btn:hover { filter: brightness(1.1); }
.btn.secondary {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-dim);
}
.btn.secondary:hover { border-color: var(--border-hi); color: var(--text); }

/* ---------- Keyboard help ---------- */
.kbd-hint {
  position: fixed;
  bottom: 12px;
  right: 16px;
  background: var(--panel);
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 8px 12px;
  font-size: 11px;
  color: var(--text-mute);
  box-shadow: var(--shadow);
  z-index: 10;
}
.kbd-hint kbd {
  background: var(--panel-hi);
  border: 1px solid var(--border);
  border-radius: 3px;
  padding: 1px 5px;
  font-family: "SF Mono", Menlo, monospace;
  font-size: 10px;
  color: var(--text);
}
.empty-state {
  text-align: center;
  color: var(--text-mute);
  padding: 48px 16px;
  font-style: italic;
}
</style>
</head>
<body>

<div class="app">
  <aside class="sidebar">
    <div class="sidebar-header">
      <h1 id="skill-name"></h1>
      <div class="iter" id="iter-name"></div>
      <div class="sidebar-summary" id="sidebar-summary"></div>
    </div>
    <div class="eval-list" id="eval-list"></div>
    <div class="sidebar-footer">
      <span id="footer-count"></span>
      <button class="theme-toggle" id="theme-toggle">Light</button>
    </div>
  </aside>

  <main class="main">
    <div class="pane" id="pane"></div>
  </main>
</div>

<div class="kbd-hint">
  <kbd>j</kbd>/<kbd>k</kbd> nav &nbsp;
  <kbd>/</kbd> feedback &nbsp;
  <kbd>t</kbd> theme
</div>

<script type="application/json" id="embedded-data">__EMBEDDED_DATA__</script>

<script>
// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------
const DATA = JSON.parse(document.getElementById("embedded-data").textContent);

const LS_KEY = `eval-review:${DATA.iteration_name}`;

// Sidebar items: N evals followed by the synthetic benchmark entry.
// activeIdx in [0, DATA.evals.length] where DATA.evals.length means "benchmark".
const BENCH_IDX = DATA.evals.length;

// ---------------------------------------------------------------------------
// Tiny markdown renderer
// Handles: headings, paragraphs, bold/italic, inline code, fenced code,
// blockquotes, bullet + numbered lists, hr, links.
// ---------------------------------------------------------------------------
function escapeHtml(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
function renderInline(s) {
  // Escape first, then re-inject markup.
  let out = escapeHtml(s);
  // Inline code
  out = out.replace(/`([^`]+?)`/g, (_, c) => `<code>${c}</code>`);
  // Bold then italic (bold must run first to not eat ** via *).
  out = out.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  out = out.replace(/(^|[^*])\*([^*\n]+)\*/g, "$1<em>$2</em>");
  // Links [text](url)
  out = out.replace(/\[([^\]]+)\]\(([^)]+)\)/g,
    (_, t, u) => `<a href="${u}" target="_blank" rel="noreferrer">${t}</a>`);
  return out;
}
function renderMarkdown(src) {
  if (src == null) return "";
  const lines = src.replace(/\r\n/g, "\n").split("\n");
  const out = [];
  let i = 0;

  const flushPara = (buf) => {
    if (buf.length) {
      out.push(`<p>${renderInline(buf.join(" "))}</p>`);
    }
  };

  while (i < lines.length) {
    const line = lines[i];

    // Fenced code
    const fence = line.match(/^```(\w*)\s*$/);
    if (fence) {
      const lang = fence[1];
      i++;
      const code = [];
      while (i < lines.length && !/^```\s*$/.test(lines[i])) {
        code.push(lines[i]);
        i++;
      }
      i++; // consume closing fence
      const cls = lang ? ` class="lang-${lang}"` : "";
      out.push(`<pre><code${cls}>${escapeHtml(code.join("\n"))}</code></pre>`);
      continue;
    }

    // Horizontal rule
    if (/^\s*(---|\*\*\*|___)\s*$/.test(line)) {
      out.push("<hr>");
      i++;
      continue;
    }

    // Heading
    const h = line.match(/^(#{1,6})\s+(.*)$/);
    if (h) {
      const lvl = h[1].length;
      out.push(`<h${lvl}>${renderInline(h[2])}</h${lvl}>`);
      i++;
      continue;
    }

    // Blockquote (consecutive)
    if (/^>\s?/.test(line)) {
      const buf = [];
      while (i < lines.length && /^>\s?/.test(lines[i])) {
        buf.push(lines[i].replace(/^>\s?/, ""));
        i++;
      }
      out.push(`<blockquote>${renderInline(buf.join(" "))}</blockquote>`);
      continue;
    }

    // Unordered list
    if (/^\s*[-*+]\s+/.test(line)) {
      const items = [];
      while (i < lines.length && /^\s*[-*+]\s+/.test(lines[i])) {
        items.push(lines[i].replace(/^\s*[-*+]\s+/, ""));
        i++;
      }
      out.push("<ul>" + items.map((it) => `<li>${renderInline(it)}</li>`).join("") + "</ul>");
      continue;
    }

    // Ordered list
    if (/^\s*\d+\.\s+/.test(line)) {
      const items = [];
      while (i < lines.length && /^\s*\d+\.\s+/.test(lines[i])) {
        items.push(lines[i].replace(/^\s*\d+\.\s+/, ""));
        i++;
      }
      out.push("<ol>" + items.map((it) => `<li>${renderInline(it)}</li>`).join("") + "</ol>");
      continue;
    }

    // Paragraph (accumulate until blank)
    if (line.trim() === "") {
      i++;
      continue;
    }
    const buf = [];
    while (i < lines.length && lines[i].trim() !== "" && !/^(#{1,6})\s+/.test(lines[i])
           && !/^```/.test(lines[i]) && !/^>\s?/.test(lines[i])
           && !/^\s*[-*+]\s+/.test(lines[i]) && !/^\s*\d+\.\s+/.test(lines[i])) {
      buf.push(lines[i]);
      i++;
    }
    flushPara(buf);
  }
  return out.join("\n");
}

// ---------------------------------------------------------------------------
// Derived helpers
// ---------------------------------------------------------------------------
function passRate(grading) {
  if (!grading || !grading.summary) return null;
  const s = grading.summary;
  if (typeof s.pass_rate === "number") return s.pass_rate;
  if (s.total) return s.passed / s.total;
  return null;
}
function passSummary(grading) {
  if (!grading || !grading.summary) return null;
  const s = grading.summary;
  return { passed: s.passed ?? 0, failed: s.failed ?? (s.total - s.passed) ?? 0, total: s.total ?? 0 };
}
function rateClass(rate) {
  if (rate == null) return "badge-dim";
  if (rate >= 0.9) return "badge-pass";
  if (rate >= 0.7) return "badge-warn";
  return "badge-fail";
}
function fmtPct(r) {
  if (r == null) return "—";
  return (r * 100).toFixed(0) + "%";
}
function fmtSecs(s) {
  if (s == null) return "—";
  return s.toFixed(1) + "s";
}
function fmtTokens(t) {
  if (t == null) return "—";
  if (t >= 1000) return (t / 1000).toFixed(1) + "k";
  return String(t);
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
const state = {
  activeIdx: 0,
  feedback: loadFeedback(),
  theme: localStorage.getItem("theme") || "dark",
};

function loadFeedback() {
  // Merge localStorage over disk feedback (localStorage wins).
  const base = {};
  const disk = DATA.feedback?.reviews || [];
  for (const r of disk) {
    if (r.run_id) base[r.run_id] = r.feedback || "";
  }
  try {
    const saved = JSON.parse(localStorage.getItem(LS_KEY) || "{}");
    if (saved && typeof saved === "object") Object.assign(base, saved);
  } catch (_) {}
  return base;
}
function saveFeedback() {
  try { localStorage.setItem(LS_KEY, JSON.stringify(state.feedback)); } catch (_) {}
}

// ---------------------------------------------------------------------------
// Render: sidebar
// ---------------------------------------------------------------------------
function renderSidebar() {
  document.getElementById("skill-name").textContent = DATA.skill_name;
  document.getElementById("iter-name").textContent = DATA.iteration_name;

  // Summary stats
  const bench = DATA.benchmark;
  const sum = document.getElementById("sidebar-summary");
  sum.innerHTML = "";
  if (bench && bench.run_summary) {
    const r = bench.run_summary;
    const rows = [
      ["with_skill pass",    fmtPct(r.with_skill?.pass_rate?.mean)],
      ["without_skill pass", fmtPct(r.without_skill?.pass_rate?.mean)],
      ["Δ pass rate",        r.delta?.pass_rate ?? "—"],
    ];
    for (const [k, v] of rows) {
      const a = document.createElement("span"); a.className = "lbl"; a.textContent = k;
      const b = document.createElement("span"); b.className = "val"; b.textContent = v;
      sum.appendChild(a); sum.appendChild(b);
    }
  }

  const list = document.getElementById("eval-list");
  list.innerHTML = "";
  DATA.evals.forEach((ev, idx) => {
    const item = document.createElement("div");
    item.className = "eval-item" + (idx === state.activeIdx ? " active" : "");
    item.dataset.idx = idx;

    const withRate = passRate(ev.with_skill.grading);
    const withoutRate = passRate(ev.without_skill.grading);

    item.innerHTML = `
      <div class="name">
        <span class="id">${ev.eval_id ?? idx + 1}.</span>${escapeHtml(ev.eval_name)}
      </div>
      <div class="badge pair" title="with_skill / without_skill">
        <span class="${rateClass(withRate)}">${fmtPct(withRate)}</span>
        <span class="${rateClass(withoutRate)}">${fmtPct(withoutRate)}</span>
      </div>
    `;
    item.addEventListener("click", () => selectItem(idx));
    list.appendChild(item);
  });

  // Separator + Benchmark entry at the bottom of the list.
  const sep = document.createElement("div");
  sep.className = "sidebar-sep";
  list.appendChild(sep);

  const benchItem = document.createElement("div");
  benchItem.className = "eval-item benchmark" + (state.activeIdx === BENCH_IDX ? " active" : "");
  benchItem.dataset.idx = BENCH_IDX;
  benchItem.innerHTML = `
    <div class="name"><span class="icon">📊</span>Benchmark</div>
    ${bench ? '<div class="badge badge-dim">summary</div>' : '<div class="badge badge-dim">missing</div>'}
  `;
  benchItem.addEventListener("click", () => selectItem(BENCH_IDX));
  list.appendChild(benchItem);

  document.getElementById("footer-count").textContent =
    `${DATA.evals.length} eval${DATA.evals.length === 1 ? "" : "s"}`;
}

function selectItem(idx) {
  if (idx < 0 || idx > BENCH_IDX) return;
  state.activeIdx = idx;
  // Update sidebar highlight without full rerender
  document.querySelectorAll(".eval-item").forEach((el) => {
    el.classList.toggle("active", Number(el.dataset.idx) === idx);
  });
  const active = document.querySelector(".eval-item.active");
  if (active) active.scrollIntoView({ block: "nearest" });
  renderPane();
}

// ---------------------------------------------------------------------------
// Render: main pane
// ---------------------------------------------------------------------------
function renderPane() {
  const pane = document.getElementById("pane");
  pane.innerHTML = "";
  // Reset scroll so each selection starts at the top.
  pane.scrollTop = 0;

  if (!DATA.evals.length && state.activeIdx !== BENCH_IDX) {
    pane.innerHTML = '<div class="empty-state">No evals found in this iteration.</div>';
    return;
  }

  if (state.activeIdx === BENCH_IDX) {
    renderBenchmarkView(pane);
  } else {
    renderEvalView(pane);
  }
}

function renderEvalView(pane) {
  const ev = DATA.evals[state.activeIdx];

  // Header
  const head = document.createElement("div");
  head.innerHTML = `
    <h2>${escapeHtml(ev.eval_name)}</h2>
    <div class="sub">Eval ${ev.eval_id ?? "?"} · ${escapeHtml(ev.slug)}</div>
  `;
  pane.appendChild(head);

  // Prompt card
  const promptCard = document.createElement("div");
  promptCard.className = "prompt-card" + (ev.prompt ? "" : " missing");
  promptCard.innerHTML = `
    <div class="label">Prompt</div>
    <div class="text">${ev.prompt ? escapeHtml(ev.prompt) : "[eval_metadata.json missing or has no prompt]"}</div>
  `;
  pane.appendChild(promptCard);

  // Side by side outputs
  const sbs = document.createElement("div");
  sbs.className = "sbs";
  sbs.appendChild(renderConfigCard(ev, "with_skill"));
  sbs.appendChild(renderConfigCard(ev, "without_skill"));
  pane.appendChild(sbs);

  // Inline feedback below outputs
  pane.appendChild(renderFeedbackSection(ev));
}

function renderConfigCard(ev, cfgKey) {
  const cfg = ev[cfgKey];
  const card = document.createElement("div");
  card.className = "cfg-card";

  const grading = cfg.grading;
  const summary = passSummary(grading);
  const rate = passRate(grading);
  const tokens = cfg.timing?.total_tokens;
  const secs = cfg.timing?.total_duration_seconds ?? cfg.timing?.executor_duration_seconds;

  const head = document.createElement("div");
  head.className = "cfg-head";
  head.innerHTML = `
    <div class="cfg-name ${cfgKey === "with_skill" ? "with" : "without"}">
      <span class="dot"></span>${cfgKey.replace("_", " ")}
    </div>
    <div class="cfg-stats">
      ${summary
        ? `<span><code>${summary.passed}/${summary.total}</code> assertions <span class="badge ${rateClass(rate)}">${fmtPct(rate)}</span></span>`
        : `<span class="badge badge-dim">no grading</span>`}
    </div>
  `;
  card.appendChild(head);

  // Output (rendered prose — shown first so the reader forms an opinion before checking grades)
  const outWrap = document.createElement("div");
  outWrap.className = "output" + (cfg.output_md ? "" : " missing");
  if (cfg.output_md) {
    outWrap.innerHTML = renderMarkdown(cfg.output_md);
  } else {
    outWrap.textContent = "[output.md missing]";
  }
  card.appendChild(outWrap);

  // Previous (collapsed)
  const prev = DATA.previous_by_slug?.[ev.slug]?.[cfgKey]?.output_md;
  if (prev) {
    const det = document.createElement("details");
    det.className = "previous-block";
    det.innerHTML = `
      <summary>Previous iteration (${escapeHtml(DATA.previous_iteration_name || "prev")})</summary>
      <div class="output">${renderMarkdown(prev)}</div>
    `;
    card.appendChild(det);
  }

  // Footer (timing, sits between prose and assertions)
  const foot = document.createElement("div");
  foot.className = "cfg-foot";
  foot.innerHTML = `
    <span>tokens <code>${fmtTokens(tokens)}</code></span>
    <span>time <code>${fmtSecs(secs)}</code></span>
  `;
  card.appendChild(foot);

  // Assertions (collapsible, open by default — verification after reading the prose)
  if (grading?.expectations?.length) {
    const det = document.createElement("details");
    det.open = true;
    det.className = "assertions";

    const summary_el = document.createElement("summary");
    summary_el.className = "assertions-head";
    summary_el.innerHTML = `<span>Assertions</span><span class="mono">${summary.passed}/${summary.total}</span>`;
    det.appendChild(summary_el);

    for (const e of grading.expectations) {
      const row = document.createElement("div");
      row.className = "assertion " + (e.passed ? "pass" : "fail");
      row.innerHTML = `
        <div class="mark">${e.passed ? "✓" : "✗"}</div>
        <div>
          <div class="text">${escapeHtml(e.text || "")}</div>
          ${e.evidence ? `<div class="evidence">${escapeHtml(e.evidence)}</div>` : ""}
        </div>
      `;
      det.appendChild(row);
    }
    card.appendChild(det);
  }

  return card;
}

// ---------------------------------------------------------------------------
// Feedback (inline, lives inside the eval view)
// ---------------------------------------------------------------------------
function renderFeedbackSection(ev) {
  const section = document.createElement("section");
  section.className = "fb-section";
  section.innerHTML = `
    <h3>Feedback <span style="color:var(--text-mute);font-weight:normal;text-transform:none;letter-spacing:0">· autosaves to localStorage</span></h3>
  `;

  const grid = document.createElement("div");
  grid.className = "fb-grid";
  for (const cfgKey of ["with_skill", "without_skill"]) {
    const runId = `${ev.slug}-${cfgKey}`;
    const card = document.createElement("div");
    card.className = "fb-card";
    card.innerHTML = `
      <div class="fb-label ${cfgKey === "with_skill" ? "with" : "without"}">
        <span class="dot"></span>${cfgKey.replace("_", " ")}
      </div>
      <textarea id="fb-${cfgKey}" placeholder="Notes on this run… (autosaves)">${escapeHtml(state.feedback[runId] || "")}</textarea>
    `;
    grid.appendChild(card);
    const ta = card.querySelector("textarea");
    ta.addEventListener("input", () => {
      state.feedback[runId] = ta.value;
      saveFeedback();
      const saved = document.getElementById("fb-saved");
      if (saved) saved.textContent = "Saved " + new Date().toLocaleTimeString();
    });
  }
  section.appendChild(grid);

  const actions = document.createElement("div");
  actions.className = "fb-actions";
  actions.innerHTML = `
    <button class="btn" id="fb-download">Download feedback.json</button>
    <button class="btn secondary" id="fb-clear">Clear this iteration's drafts</button>
    <span class="saved" id="fb-saved"></span>
  `;
  section.appendChild(actions);

  // Wire the buttons after the elements exist.
  queueMicrotask(() => {
    const dl = document.getElementById("fb-download");
    const clr = document.getElementById("fb-clear");
    if (dl) dl.addEventListener("click", downloadFeedback);
    if (clr) clr.addEventListener("click", () => {
      if (!confirm("Clear all locally-saved feedback drafts for this iteration?")) return;
      state.feedback = {};
      saveFeedback();
      renderPane();
    });
  });

  return section;
}

// ---------------------------------------------------------------------------
// Benchmark view
// ---------------------------------------------------------------------------
function renderBenchmarkView(pane) {
  const bench = DATA.benchmark;
  const head = document.createElement("div");
  head.innerHTML = `
    <h2>Benchmark</h2>
    <div class="sub">${bench?.metadata?.timestamp ? "Run at " + escapeHtml(bench.metadata.timestamp) : "No benchmark.json"}</div>
  `;
  pane.appendChild(head);

  if (!bench) {
    pane.appendChild(Object.assign(document.createElement("div"),
      { className: "empty-state", textContent: "[benchmark.json missing]" }));
    return;
  }

  // Summary cards
  const summary = bench.run_summary || {};
  const cards = document.createElement("div");
  cards.className = "bench-summary";
  cards.appendChild(summaryCard("Pass rate", summary, "pass_rate", fmtPct, "higher is better"));
  cards.appendChild(summaryCard("Time (s)", summary, "time_seconds", (v) => v == null ? "—" : v.toFixed(1) + "s", "lower is better"));
  cards.appendChild(summaryCard("Tokens", summary, "tokens", fmtTokens, "lower is better"));
  pane.appendChild(cards);

  // Paired bar chart
  const barsSection = document.createElement("div");
  barsSection.className = "bench-section";
  barsSection.innerHTML = `<h3>Per-eval pass rate (with vs without)</h3>`;

  const bars = document.createElement("div");
  bars.className = "bench-bars";

  // Group runs by eval_id
  const byEval = new Map();
  for (const r of (bench.runs || [])) {
    const key = r.eval_id ?? r.eval_name;
    if (!byEval.has(key)) byEval.set(key, { name: r.eval_name, with_skill: [], without_skill: [] });
    const bucket = byEval.get(key);
    if (r.configuration === "with_skill") bucket.with_skill.push(r);
    else if (r.configuration === "without_skill") bucket.without_skill.push(r);
  }

  const mean = (arr, field) => {
    const vals = arr.map((r) => r.result?.[field]).filter((v) => typeof v === "number");
    if (!vals.length) return null;
    return vals.reduce((a, b) => a + b, 0) / vals.length;
  };

  for (const [, bucket] of byEval) {
    const row = document.createElement("div");
    row.className = "bench-row";
    const w = mean(bucket.with_skill, "pass_rate");
    const wo = mean(bucket.without_skill, "pass_rate");
    const delta = (w != null && wo != null) ? (w - wo) : null;
    const deltaStr = delta == null ? "—" :
      (delta >= 0 ? "+" : "") + (delta * 100).toFixed(0) + "%";
    const deltaCls = delta == null ? "" : (delta >= 0 ? "delta-pos" : "delta-neg");

    row.innerHTML = `
      <div class="rowname">${escapeHtml(bucket.name || "?")}</div>
      <div class="bench-bars-pair">
        ${barLine("with",    w)}
        ${barLine("without", wo)}
      </div>
      <div class="rowdelta ${deltaCls}">${deltaStr}</div>
    `;
    bars.appendChild(row);
  }
  barsSection.appendChild(bars);
  pane.appendChild(barsSection);

  // Assertion discrimination table
  const discrim = buildDiscrimination(bench);
  if (discrim.length) {
    const sec = document.createElement("div");
    sec.className = "bench-section";
    sec.innerHTML = `<h3>Assertion discrimination (which assertions reveal skill impact)</h3>`;
    const table = document.createElement("table");
    table.className = "assert-table";
    table.innerHTML = `
      <thead><tr>
        <th>Assertion</th>
        <th class="num">With ✓</th>
        <th class="num">Without ✓</th>
        <th class="num">Gap</th>
        <th class="sig">Signal</th>
      </tr></thead>
      <tbody></tbody>
    `;
    const tb = table.querySelector("tbody");
    for (const row of discrim) {
      const tr = document.createElement("tr");
      const gap = row.withRate - row.withoutRate;
      const gapStr = (gap >= 0 ? "+" : "") + (gap * 100).toFixed(0) + "%";
      const gapCls = Math.abs(gap) < 0.001 ? "" : (gap > 0 ? "delta-pos" : "delta-neg");
      // "Signal" = at least one config diverges from the other AND neither is a perfect tie at 100% on both.
      const isSignal = Math.abs(gap) > 0.0001 || (row.withRate < 1 && row.withoutRate < 1);
      tr.innerHTML = `
        <td>${escapeHtml(row.text)}</td>
        <td class="num">${row.withPass}/${row.withTotal}</td>
        <td class="num">${row.withoutPass}/${row.withoutTotal}</td>
        <td class="num ${gapCls}">${gapStr}</td>
        <td class="sig">${isSignal ? '<span class="sig-signal">signal</span>' : '<span class="sig-noise">noise</span>'}</td>
      `;
      tb.appendChild(tr);
    }
    sec.appendChild(table);
    pane.appendChild(sec);
  }

  // Notes
  if (bench.notes?.length) {
    const sec = document.createElement("div");
    sec.className = "bench-section";
    sec.innerHTML = `<h3>Analyzer notes</h3>`;
    const box = document.createElement("div");
    box.className = "bench-notes";
    const ul = document.createElement("ul");
    for (const n of bench.notes) {
      const li = document.createElement("li");
      li.textContent = n;
      ul.appendChild(li);
    }
    box.appendChild(ul);
    sec.appendChild(box);
    pane.appendChild(sec);
  }
}

function summaryCard(label, summary, field, fmt, hint) {
  const w = summary.with_skill?.[field];
  const wo = summary.without_skill?.[field];
  const delta = summary.delta?.[field] ?? null;
  let deltaClass = "";
  if (typeof delta === "string") {
    const sign = delta.startsWith("-") ? -1 : (delta.startsWith("+") ? 1 : 0);
    // For pass_rate positive is good; for time/tokens positive is bad.
    const positiveIsGood = field === "pass_rate";
    if (sign !== 0) {
      const good = (positiveIsGood && sign > 0) || (!positiveIsGood && sign < 0);
      deltaClass = good ? "delta-pos" : "delta-neg";
    }
  }
  const el = document.createElement("div");
  el.className = "bench-card";
  el.innerHTML = `
    <div class="label">${label} <span style="color:var(--text-mute);font-weight:normal;text-transform:none;letter-spacing:0">· ${hint}</span></div>
    <div class="stats">
      <span class="k">with_skill</span><span class="v">${fmt(w?.mean)}${w?.stddev != null ? ` <span style="color:var(--text-mute)">±${fmt(w.stddev).replace(/[a-z%]+$/,"")}</span>` : ""}</span>
      <span class="k">without_skill</span><span class="v">${fmt(wo?.mean)}${wo?.stddev != null ? ` <span style="color:var(--text-mute)">±${fmt(wo.stddev).replace(/[a-z%]+$/,"")}</span>` : ""}</span>
    </div>
    <div class="delta"><span>Δ</span><span class="${deltaClass}">${delta ?? "—"}</span></div>
  `;
  return el;
}

function barLine(cfg, rate) {
  if (rate == null) {
    return `
      <div class="bench-bar-line">
        <span class="swatch ${cfg}"></span>
        <div class="bench-bar-track"></div>
        <span class="pct">—</span>
      </div>`;
  }
  const w = Math.max(0, Math.min(1, rate)) * 100;
  return `
    <div class="bench-bar-line">
      <span class="swatch ${cfg}"></span>
      <div class="bench-bar-track">
        <div class="bench-bar-fill" style="width:${w}%; background:var(--${cfg === "with" ? "with-skill" : "without-skill"})"></div>
      </div>
      <span class="pct">${fmtPct(rate)}</span>
    </div>`;
}

function buildDiscrimination(bench) {
  // For each assertion text, count pass/fail in each configuration.
  const map = new Map();
  for (const r of (bench.runs || [])) {
    const cfg = r.configuration;
    if (cfg !== "with_skill" && cfg !== "without_skill") continue;
    for (const e of (r.expectations || [])) {
      const key = e.text;
      if (!map.has(key)) {
        map.set(key, { text: key, withPass: 0, withTotal: 0, withoutPass: 0, withoutTotal: 0 });
      }
      const row = map.get(key);
      if (cfg === "with_skill") {
        row.withTotal++;
        if (e.passed) row.withPass++;
      } else {
        row.withoutTotal++;
        if (e.passed) row.withoutPass++;
      }
    }
  }
  const rows = [];
  for (const [, row] of map) {
    row.withRate = row.withTotal ? row.withPass / row.withTotal : 0;
    row.withoutRate = row.withoutTotal ? row.withoutPass / row.withoutTotal : 0;
    rows.push(row);
  }
  // Sort by abs gap desc so the signal-bearing assertions surface first.
  rows.sort((a, b) => Math.abs(b.withRate - b.withoutRate) - Math.abs(a.withRate - a.withoutRate));
  return rows;
}

function downloadFeedback() {
  const reviews = Object.entries(state.feedback)
    .filter(([, v]) => v && v.trim())
    .map(([run_id, feedback]) => ({
      run_id,
      feedback,
      timestamp: new Date().toISOString(),
    }));
  const payload = { reviews, status: "in_progress" };
  const blob = new Blob([JSON.stringify(payload, null, 2) + "\n"], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "feedback.json";
  a.click();
  URL.revokeObjectURL(url);
}

// ---------------------------------------------------------------------------
// Keyboard
// ---------------------------------------------------------------------------
function isInputFocused() {
  const el = document.activeElement;
  if (!el) return false;
  const tag = el.tagName;
  return tag === "INPUT" || tag === "TEXTAREA" || el.isContentEditable;
}

document.addEventListener("keydown", (e) => {
  // Escape blurs inputs so navigation resumes
  if (e.key === "Escape") {
    if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
    return;
  }
  if (isInputFocused()) return;

  if (e.key === "j" || e.key === "ArrowDown") {
    e.preventDefault();
    selectItem(Math.min(BENCH_IDX, state.activeIdx + 1));
  } else if (e.key === "k" || e.key === "ArrowUp") {
    e.preventDefault();
    selectItem(Math.max(0, state.activeIdx - 1));
  } else if (e.key === "/") {
    e.preventDefault();
    // Feedback only exists on eval views.
    if (state.activeIdx === BENCH_IDX) return;
    const ta = document.querySelector(".fb-card textarea");
    if (ta) ta.focus();
  } else if (e.key === "t") {
    toggleTheme();
  }
});

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------
function toggleTheme() {
  state.theme = state.theme === "dark" ? "light" : "dark";
  document.documentElement.setAttribute("data-theme", state.theme);
  document.getElementById("theme-toggle").textContent = state.theme === "dark" ? "Light" : "Dark";
  localStorage.setItem("theme", state.theme);
}
document.getElementById("theme-toggle").addEventListener("click", toggleTheme);

// ---------------------------------------------------------------------------
// Boot
// ---------------------------------------------------------------------------
document.documentElement.setAttribute("data-theme", state.theme);
document.getElementById("theme-toggle").textContent = state.theme === "dark" ? "Light" : "Dark";
renderSidebar();
renderPane();
</script>
</body>
</html>
"""


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate a static HTML eval viewer for an iteration directory.",
    )
    parser.add_argument("iteration_dir", type=Path, help="Path to iteration directory")
    parser.add_argument("--previous", type=Path, default=None,
                        help="Path to previous iteration dir to show as context")
    parser.add_argument("--output", type=Path, default=None,
                        help="Output HTML path (default: <iteration>/review.html)")
    args = parser.parse_args()

    iteration_dir = args.iteration_dir.resolve()
    if not iteration_dir.is_dir():
        print(f"Error: {iteration_dir} is not a directory", file=sys.stderr)
        sys.exit(1)

    output_path = args.output.resolve() if args.output else (iteration_dir / "review.html")

    current = load_iteration(iteration_dir)
    previous = load_iteration(args.previous.resolve()) if args.previous else None

    html = generate_html(current, previous)
    output_path.write_text(html)

    n = len(current["evals"])
    print(f"Wrote {output_path} ({n} eval{'s' if n != 1 else ''})")


if __name__ == "__main__":
    main()
