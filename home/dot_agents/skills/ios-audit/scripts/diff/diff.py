"""DIFF two audit.json baselines.

Compares a current audit.json to a previous baseline and writes a
markdown report listing:
  - Fixed findings (present in baseline, absent in current)
  - New findings (absent in baseline, present in current)
  - Regressed findings (severity increased)
  - Demoted findings (severity decreased)
  - RICE delta

Finding identity is based on the stable `id` field. If two runs have
different ID schemes (e.g. collector renamed), the diff will look like
a mass fix + mass new; the invoking agent should reconcile by hand.
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR.parent))

from common import read_json  # noqa: E402

SEVERITY_RANK = {"critical": 3, "major": 2, "moderate": 1, "minor": 0}


def diff(*, current: Path, baseline: Path, output: Path) -> None:
    cur_audit = read_json(current)
    base_audit = read_json(baseline)

    cur = {f["id"]: f for f in cur_audit.get("findings", [])}
    base = {f["id"]: f for f in base_audit.get("findings", [])}

    fixed_ids = sorted(set(base) - set(cur))
    new_ids = sorted(set(cur) - set(base))
    shared_ids = sorted(set(cur) & set(base))

    regressed: list[tuple[str, str, str]] = []
    demoted: list[tuple[str, str, str]] = []
    for fid in shared_ids:
        bs = base[fid].get("severity", "")
        cs = cur[fid].get("severity", "")
        if bs != cs:
            if SEVERITY_RANK.get(cs, -1) > SEVERITY_RANK.get(bs, -1):
                regressed.append((fid, bs, cs))
            else:
                demoted.append((fid, bs, cs))

    rice_cur = cur_audit.get("summary", {}).get("rice_total", 0) or 0
    rice_base = base_audit.get("summary", {}).get("rice_total", 0) or 0
    rice_delta = round(rice_cur - rice_base, 2)

    cur_audit.setdefault("trends", {}).update({
        "baseline_commit": base_audit.get("meta", {}).get("repo", {}).get("git_rev", ""),
        "baseline_generated_at": base_audit.get("meta", {}).get("generated_at", ""),
        "fixed_since_baseline": fixed_ids,
        "new_since_baseline": new_ids,
        "regressed": [x[0] for x in regressed],
        "demoted": [x[0] for x in demoted],
        "rice_delta": rice_delta,
    })

    # Persist trends back into current audit.json
    from common import write_json
    write_json(current, cur_audit)

    lines: list[str] = []
    app_name = (cur_audit.get("meta", {}).get("app") or {}).get("name", "Unknown")
    lines.append(f"# Audit Diff — {app_name}")
    lines.append("")
    lines.append(f"- Current commit: `{cur_audit.get('meta', {}).get('repo', {}).get('git_rev', '')[:12]}`")
    lines.append(f"- Baseline commit: `{base_audit.get('meta', {}).get('repo', {}).get('git_rev', '')[:12]}`")
    lines.append(f"- Baseline generated: {base_audit.get('meta', {}).get('generated_at', '')}")
    lines.append(f"- Current generated: {cur_audit.get('meta', {}).get('generated_at', '')}")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append(f"- Fixed: **{len(fixed_ids)}**")
    lines.append(f"- New: **{len(new_ids)}**")
    lines.append(f"- Regressed: **{len(regressed)}**")
    lines.append(f"- Demoted: **{len(demoted)}**")
    lines.append(f"- RICE delta: **{'+' if rice_delta > 0 else ''}{rice_delta}**")
    lines.append("")

    def dump_section(title: str, items: list[Any]) -> None:
        lines.append(f"## {title}")
        lines.append("")
        if not items:
            lines.append("_None._")
            lines.append("")
            return
        lines.append("| ID | Pillar | Severity | Title |")
        lines.append("|----|--------|----------|-------|")
        for item in items:
            if isinstance(item, str):
                fid = item
                f = base.get(fid) or cur.get(fid) or {}
            else:
                fid = item[0]
                f = cur.get(fid, {})
            lines.append(
                f"| `{fid}` | {f.get('pillar', '')} | {f.get('severity', '')} | {f.get('title', '')} |"
            )
        lines.append("")

    dump_section("Fixed since baseline", fixed_ids)
    dump_section("New since baseline", new_ids)

    lines.append("## Regressed (severity increased)")
    lines.append("")
    if not regressed:
        lines.append("_None._")
        lines.append("")
    else:
        lines.append("| ID | Baseline | Current | Pillar | Title |")
        lines.append("|----|----------|---------|--------|-------|")
        for fid, bs, cs in regressed:
            f = cur.get(fid, {})
            lines.append(f"| `{fid}` | {bs} | **{cs}** | {f.get('pillar', '')} | {f.get('title', '')} |")
        lines.append("")

    lines.append("## Demoted (severity decreased)")
    lines.append("")
    if not demoted:
        lines.append("_None._")
        lines.append("")
    else:
        lines.append("| ID | Baseline | Current | Pillar | Title |")
        lines.append("|----|----------|---------|--------|-------|")
        for fid, bs, cs in demoted:
            f = cur.get(fid, {})
            lines.append(f"| `{fid}` | {bs} | {cs} | {f.get('pillar', '')} | {f.get('title', '')} |")
        lines.append("")

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
