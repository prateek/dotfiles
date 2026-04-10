"""Render merged audit output.

Inputs (under `audit_root`):
  raw/meta.json               # from collect
  raw/<pillar>.json           # from collect
  findings/<pillar>.json      # from analyze (authored by the invoking agent)
  docs/**.md                  # from analyze (authored by the invoking agent)

Outputs:
  audit_root/audit.json       # merged baseline (see audit-schema.json)
  audit_root/audit.html       # self-contained HTML report
  <docs_dir>/                 # authored markdown copied over, preserving
                              # paths listed in `preserve`
  <docs_dir>-prev/            # snapshot of prior docs_dir (if it existed)

The render step is deterministic and safe to re-run.
"""

from __future__ import annotations

import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR.parent))

from common import eprint, read_json, write_json  # noqa: E402

ALL_PILLARS = ("code_health", "ux", "runtime", "release")


def render(
    *,
    audit_root: Path,
    docs_dir: Path,
    preserve: list[str],
    skill_root: Path,
) -> Path:
    raw_dir = audit_root / "raw"
    findings_dir = audit_root / "findings"
    authored_docs_dir = audit_root / "docs"

    meta = read_json(raw_dir / "meta.json") if (raw_dir / "meta.json").exists() else {}
    findings = _load_findings(findings_dir)

    audit: dict[str, Any] = {
        "meta": meta,
        "findings": findings,
        "summary": _summarize(findings),
    }

    # Attach raw inputs for offline consumers
    audit["raw_inputs"] = {}
    for name in ALL_PILLARS:
        raw_path = raw_dir / f"{name}.json"
        if raw_path.exists():
            audit["raw_inputs"][name] = read_json(raw_path)

    audit_json_path = audit_root / "audit.json"
    write_json(audit_json_path, audit)

    # HTML report
    html_path = audit_root / "audit.html"
    _render_html(audit, html_path, skill_root=skill_root)

    # Copy authored docs into target docs_dir, preserving listed subpaths.
    if authored_docs_dir.exists():
        _apply_docs(
            authored=authored_docs_dir,
            target=docs_dir,
            preserve=preserve,
        )
    else:
        eprint(f"[render] no authored docs at {authored_docs_dir}; skipping docs copy")

    # Drop audit.json into the target docs dir so diff can auto-detect it next run.
    target_baseline = docs_dir / "audit.json"
    target_baseline.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(audit_json_path, target_baseline)

    return audit_json_path


def _load_findings(findings_dir: Path) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    if not findings_dir.exists():
        return out
    for p in sorted(findings_dir.glob("*.json")):
        data = read_json(p)
        if isinstance(data, list):
            out.extend(data)
        elif isinstance(data, dict) and "findings" in data:
            out.extend(data["findings"])
        else:
            eprint(f"[render] WARN: {p} is not a list or {{findings:...}}; ignoring")
    # Stable sort: severity, priority, rice score desc, id
    sev_order = {"critical": 0, "major": 1, "moderate": 2, "minor": 3}
    pri_order = {"must": 0, "should": 1, "could": 2, "wont": 3}
    out.sort(key=lambda f: (
        sev_order.get(f.get("severity", "minor"), 3),
        pri_order.get(f.get("priority", "could"), 3),
        -(f.get("rice", {}).get("score") or 0),
        f.get("id", "ZZZ"),
    ))
    return out


def _summarize(findings: list[dict[str, Any]]) -> dict[str, Any]:
    by_sev: dict[str, int] = {}
    by_pillar: dict[str, int] = {}
    by_pri: dict[str, int] = {}
    rice_total = 0.0
    ship_blockers = 0
    for f in findings:
        by_sev[f.get("severity", "minor")] = by_sev.get(f.get("severity", "minor"), 0) + 1
        by_pillar[f.get("pillar", "unknown")] = by_pillar.get(f.get("pillar", "unknown"), 0) + 1
        by_pri[f.get("priority", "could")] = by_pri.get(f.get("priority", "could"), 0) + 1
        rice_total += (f.get("rice", {}) or {}).get("score") or 0
        if f.get("severity") == "critical" and f.get("priority") == "must":
            ship_blockers += 1
    return {
        "by_severity": by_sev,
        "by_pillar": by_pillar,
        "by_priority": by_pri,
        "rice_total": round(rice_total, 2),
        "ship_blockers": ship_blockers,
    }


def _apply_docs(*, authored: Path, target: Path, preserve: list[str]) -> None:
    """Replace target with authored contents, preserving listed subpaths.

    Strategy:
      1. Snapshot target → target.parent / f"{target.name}-prev".
      2. For each path in preserve, copy it OUT of the current target (if present)
         into a temp area.
      3. Remove target, copy authored → target.
      4. Restore preserved paths back into target.

    `preserve` entries may be repo-relative (e.g. "docs/plans") or absolute.
    They are normalized relative to target.parent so "docs/plans" under a
    --docs-dir of "/repo/docs" resolves to "/repo/docs/plans".
    """
    target = target.resolve()
    authored = authored.resolve()

    prev_snapshot = target.parent / f"{target.name}-prev"
    if target.exists():
        if prev_snapshot.exists():
            shutil.rmtree(prev_snapshot)
        shutil.copytree(target, prev_snapshot)

    # Resolve preserves relative to target.parent
    preserved_paths: list[tuple[Path, Path]] = []  # (orig_inside_target, saved_path)
    tmp_root = target.parent / f".{target.name}.preserve-tmp"
    if tmp_root.exists():
        shutil.rmtree(tmp_root)
    tmp_root.mkdir(parents=True, exist_ok=True)

    for rel in preserve:
        rel_path = Path(rel)
        if rel_path.is_absolute():
            resolved = rel_path
        else:
            # Support "docs/plans" (relative to target.parent) and "plans" (relative to target)
            if rel_path.parts and rel_path.parts[0] == target.name:
                resolved = target.parent / rel_path
            else:
                resolved = target / rel_path
        if resolved.exists():
            rel_in_target = resolved.relative_to(target) if resolved.is_relative_to(target) else None
            saved = tmp_root / resolved.name
            if resolved.is_dir():
                shutil.copytree(resolved, saved)
            else:
                shutil.copy(resolved, saved)
            preserved_paths.append((resolved, saved))

    # Clobber target
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(authored, target)

    # Restore preserves
    for orig, saved in preserved_paths:
        orig.parent.mkdir(parents=True, exist_ok=True)
        if saved.is_dir():
            if orig.exists():
                shutil.rmtree(orig)
            shutil.copytree(saved, orig)
        else:
            shutil.copy(saved, orig)

    shutil.rmtree(tmp_root, ignore_errors=True)


def _render_html(audit: dict[str, Any], out_path: Path, *, skill_root: Path) -> None:
    """Render a self-contained HTML report.

    Uses Jinja2 if available; otherwise falls back to a minimal built-in
    template so the skill works without optional deps.
    """
    template_path = skill_root / "scripts" / "render" / "templates" / "audit.html.j2"
    try:
        import jinja2
        env = jinja2.Environment(
            loader=jinja2.FileSystemLoader(str(template_path.parent)),
            autoescape=jinja2.select_autoescape(["html", "xml"]),
            undefined=jinja2.ChainableUndefined,
        )
        env.filters["severity_class"] = lambda s: f"sev-{s or 'unknown'}"
        env.filters["priority_class"] = lambda p: f"pri-{p or 'unknown'}"
        tmpl = env.get_template("audit.html.j2")
        html = tmpl.render(audit=audit, generated_at=datetime.now(timezone.utc).isoformat(timespec="seconds"))
    except ImportError as e:
        eprint(f"[render] jinja2 unavailable ({e}); using fallback HTML")
        html = _fallback_html(audit)
    except Exception as e:  # noqa: BLE001
        eprint(f"[render] jinja2 template error ({e!r}); using fallback HTML")
        html = _fallback_html(audit)
    out_path.write_text(html, encoding="utf-8")


def _fallback_html(audit: dict[str, Any]) -> str:
    import html as _h
    meta = audit.get("meta", {})
    findings = audit.get("findings", [])
    summary = audit.get("summary", {})
    lines = [
        "<!doctype html>",
        "<html><head><meta charset='utf-8'><title>iOS Audit</title>",
        "<style>body{font-family:-apple-system,sans-serif;max-width:960px;margin:2em auto;padding:0 1em}"
        ".sev-critical{color:#b91c1c;font-weight:600}.sev-major{color:#c2410c}"
        ".sev-moderate{color:#a16207}.sev-minor{color:#475569}"
        "table{border-collapse:collapse;width:100%}td,th{border-bottom:1px solid #e5e7eb;padding:6px;text-align:left}"
        "</style></head><body>",
        f"<h1>iOS Audit — {_h.escape(str(meta.get('app', {}).get('name', 'Unknown')))}</h1>",
        f"<p>Generated: {_h.escape(str(meta.get('generated_at', '')))}</p>",
        f"<p>Commit: <code>{_h.escape(str(meta.get('repo', {}).get('git_rev', '')))}</code></p>",
        "<h2>Summary</h2>",
        "<ul>",
        f"<li>Findings: {len(findings)}</li>",
        f"<li>Ship blockers (critical+must): {summary.get('ship_blockers', 0)}</li>",
        f"<li>RICE total: {summary.get('rice_total', 0)}</li>",
        "</ul>",
        "<h2>Findings</h2>",
        "<table><tr><th>ID</th><th>Pillar</th><th>Severity</th><th>Priority</th><th>Title</th></tr>",
    ]
    for f in findings:
        sev = f.get("severity", "")
        lines.append(
            f"<tr><td>{_h.escape(f.get('id', ''))}</td>"
            f"<td>{_h.escape(f.get('pillar', ''))}</td>"
            f"<td class='sev-{sev}'>{_h.escape(sev)}</td>"
            f"<td>{_h.escape(f.get('priority', ''))}</td>"
            f"<td>{_h.escape(f.get('title', ''))}</td></tr>"
        )
    lines.append("</table></body></html>")
    return "\n".join(lines)
