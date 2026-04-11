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

import json
import re
import shutil
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR.parent))
sys.path.insert(0, str(SCRIPT_DIR))

from common import eprint, read_json, write_json  # noqa: E402
from flow_scene import build_flow_scene  # noqa: E402

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

    # Reference raw inputs by path only — inlining them balloons audit.json
    # past 5 MB for even modest projects. Consumers who need the detail can
    # read them directly from .audit/raw/.
    audit["raw_inputs"] = {
        name: str((raw_dir / f"{name}.json").relative_to(audit_root))
        for name in ALL_PILLARS
        if (raw_dir / f"{name}.json").exists()
    }

    audit_json_path = audit_root / "audit.json"
    write_json(audit_json_path, audit)

    # Collect authored sections (now builds flow scenes inline for ux/flows/*).
    sections = _collect_sections(authored_docs_dir, audit_root=audit_root)

    # Cross-link pivot indexes (Proposal C)
    indexes = _build_indexes(audit, sections)

    # Overview / cover data (Proposal A)
    overview = _build_overview(audit, indexes, authored_docs_dir)

    # HTML report
    html_path = audit_root / "audit.html"
    _render_html(
        audit,
        html_path,
        skill_root=skill_root,
        authored_docs_dir=authored_docs_dir,
        sections=sections,
        indexes=indexes,
        overview=overview,
    )

    # Copy authored docs into target docs_dir, preserving listed subpaths.
    if authored_docs_dir.exists():
        _apply_docs(
            authored=authored_docs_dir,
            target=docs_dir,
            preserve=preserve,
            audit_root=audit_root,
        )
    else:
        eprint(f"[render] no authored docs at {authored_docs_dir}; skipping docs copy")

    # Do NOT copy audit.json into docs_dir here. The diff phase will do that
    # after successfully comparing against the prior baseline, so subsequent
    # runs can still auto-detect the previous docs/audit.json as baseline.
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


def _apply_docs(*, authored: Path, target: Path, preserve: list[str], audit_root: Path) -> None:
    """Replace target with authored contents, preserving listed subpaths.

    Strategy:
      1. Snapshot target → `<audit_root>/docs-prev` so the repo root stays clean.
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

    prev_snapshot = audit_root / "docs-prev"
    if target.exists():
        if prev_snapshot.exists():
            shutil.rmtree(prev_snapshot)
        prev_snapshot.parent.mkdir(parents=True, exist_ok=True)
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


def _render_html(
    audit: dict[str, Any],
    out_path: Path,
    *,
    skill_root: Path,
    authored_docs_dir: Path,
    sections: list[dict[str, Any]],
    indexes: dict[str, Any],
    overview: dict[str, Any],
) -> None:
    """Render a self-contained HTML report.

    The report embeds every authored markdown doc under a navigable sidebar
    alongside the findings table, so opening `audit.html` gives a complete
    picture of the audit without needing to chase individual files.

    Uses Jinja2 + markdown. Falls back to a minimal built-in template if
    jinja2 is unavailable.
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
        env.filters["tojson_script"] = lambda v: json.dumps(v, separators=(",", ":"))
        tmpl = env.get_template("audit.html.j2")
        html = tmpl.render(
            audit=audit,
            sections=sections,
            indexes=indexes,
            overview=overview,
            generated_at=datetime.now(timezone.utc).isoformat(timespec="seconds"),
        )
    except ImportError as e:
        eprint(f"[render] jinja2 unavailable ({e}); using fallback HTML")
        html = _fallback_html(audit)
    except Exception as e:  # noqa: BLE001
        eprint(f"[render] jinja2 template error ({e!r}); using fallback HTML")
        html = _fallback_html(audit)
    out_path.write_text(html, encoding="utf-8")


SECTION_ORDER = [
    ("architecture", "Architecture"),
    ("ux", "UX"),
    ("quality", "Quality"),
    ("operations", "Operations"),
    ("release", "Release & Compliance"),
]


def _collect_sections(authored_docs_dir: Path, *, audit_root: Path) -> list[dict[str, Any]]:
    """Walk authored docs and build the sidebar-friendly section list.

    Each section is {slug, title, docs: [{id, title, rel_path, html, ...}, ...]}.
    Docs are converted from markdown to HTML here (via `markdown` lib) so
    the Jinja template can inline them with `|safe`.

    UX flow docs (`ux/flows/*.md`) additionally get a `flow_scene` dict
    attached by `flow_scene.build_flow_scene()`, containing thumbnail paths,
    step layouts, and SVG arrow coordinates for the panzoom canvas.
    """
    md_module = _get_markdown_module()
    md_to_html = _make_markdown_to_html_callable(md_module)

    sections: list[dict[str, Any]] = []
    if not authored_docs_dir.exists():
        return sections

    for slug, title in SECTION_ORDER:
        section_dir = authored_docs_dir / slug
        if not section_dir.exists():
            continue
        docs: list[dict[str, Any]] = []
        # Sort: top-level docs first (by filename), then nested (runbooks/*)
        md_files = sorted(
            section_dir.rglob("*.md"),
            key=lambda p: (len(p.relative_to(section_dir).parts), str(p)),
        )
        for mdf in md_files:
            rel = mdf.relative_to(authored_docs_dir)
            raw = mdf.read_text(encoding="utf-8", errors="replace")
            stripped = _strip_frontmatter(raw)
            doc_title = _extract_title(stripped) or mdf.stem.replace("-", " ").title()
            html_content = md_to_html(stripped)
            # Transform ```mermaid blocks into <div class="mermaid"> elements
            # so the mermaid.js CDN include in the template can render them.
            html_content = _transform_mermaid_blocks(html_content)
            # Rewrite relative image paths so they resolve from audit.html's
            # location. Markdown like `![foo](./_screenshots/x.png)` comes
            # out as `<img src="./_screenshots/x.png">` — that's relative
            # to the flow doc, not to audit.html. Rewrite it to be relative
            # to `audit_root` (where audit.html lives).
            doc_dir = mdf.parent.relative_to(authored_docs_dir.parent)  # e.g. "docs/ux/flows"
            html_content = _rewrite_relative_assets(html_content, prefix=str(doc_dir))
            doc_id = str(rel).replace("/", "-").replace(".md", "")
            doc_entry: dict[str, Any] = {
                "id": doc_id,
                "title": doc_title,
                "rel_path": str(rel),
                "html": html_content,
                "is_flow": False,
            }
            # For UX flow docs, build the scene so the template can render
            # the interactive panzoom canvas instead of the raw image wall.
            if slug == "ux" and rel.parts[:2] == ("ux", "flows"):
                try:
                    scene = build_flow_scene(
                        markdown_path=mdf,
                        audit_root=audit_root,
                        markdown_to_html=md_to_html,
                    )
                    if scene is not None:
                        # Rewrite asset paths inside scene.intro_html / outro_html
                        # so any inline images resolve from audit.html's location.
                        scene_dict = scene.to_dict()
                        scene_dict["intro_html"] = _rewrite_relative_assets(
                            scene_dict["intro_html"], prefix=str(doc_dir)
                        )
                        scene_dict["outro_html"] = _rewrite_relative_assets(
                            scene_dict["outro_html"], prefix=str(doc_dir)
                        )
                        for step in scene_dict["steps"]:
                            step["prose_html"] = _rewrite_relative_assets(
                                step["prose_html"], prefix=str(doc_dir)
                            )
                        doc_entry["flow_scene"] = scene_dict
                        doc_entry["is_flow"] = True
                except Exception as e:  # noqa: BLE001
                    eprint(f"[render] flow_scene build failed for {rel}: {e!r}")
            docs.append(doc_entry)
        if docs:
            sections.append({"slug": slug, "title": title, "docs": docs})
    return sections


def _get_markdown_module():
    try:
        import markdown as md  # type: ignore
        return md
    except ImportError:
        return None


def _make_markdown_to_html_callable(md_module) -> Callable[[str], str]:
    """Return a `(markdown_source) -> html_string` callable using python-markdown
    when available, or a <pre>-wrapping fallback otherwise."""
    if md_module is not None:
        def convert(text: str) -> str:
            return md_module.markdown(
                text,
                extensions=["tables", "fenced_code", "toc"],
                output_format="html5",
            )
        return convert
    import html as _h
    return lambda text: f"<pre>{_h.escape(text)}</pre>"


FRONTMATTER_RE = re.compile(r"^---\s*\n.*?\n---\s*\n", re.DOTALL)
H1_RE = re.compile(r"^#\s+(.+?)\s*$", re.MULTILINE)

# Match ```mermaid fenced code blocks after markdown conversion:
#   <pre><code class="language-mermaid">graph LR ...</code></pre>
MERMAID_BLOCK_RE = re.compile(
    r'<pre><code class="language-mermaid">(.*?)</code></pre>',
    re.DOTALL,
)


def _transform_mermaid_blocks(html: str) -> str:
    """Convert mermaid code blocks to <div class="mermaid"> elements so
    the mermaid.js CDN script can render them as SVG diagrams on page load.

    Also sanitize common issues that trip mermaid v10:
    - literal `\\n` (backslash + n) inside labels → space (stateDiagram labels
      don't line-break cleanly anyway)
    - `< N` inside transition labels → `&lt; N` so it's not parsed as an HTML tag
    - `> N` inside transition labels → `&gt; N` (same)
    - trailing whitespace trimming per line
    """
    import html as _h
    def replace(match: re.Match[str]) -> str:
        raw = match.group(1)
        diagram = _h.unescape(raw)
        diagram = _sanitize_mermaid(diagram)
        return f'<div class="mermaid">{diagram}</div>'
    return MERMAID_BLOCK_RE.sub(replace, html)


def _sanitize_mermaid(diagram: str) -> str:
    """Fix common agent-authored mermaid quirks that trip mermaid v10 parsers."""
    # Collapse literal backslash-n sequences (not real newlines) to spaces.
    diagram = diagram.replace("\\n", " ")
    # Escape comparison operators inside labels so mermaid doesn't parse them
    # as HTML tags. Apply conservatively: only when the `<` or `>` is
    # surrounded by spaces (looks like an operator, not an arrow).
    diagram = re.sub(r" < (\d)", r" &lt; \1", diagram)
    diagram = re.sub(r" > (\d)", r" &gt; \1", diagram)
    diagram = re.sub(r" <= (\d)", r" &lt;= \1", diagram)
    diagram = re.sub(r" >= (\d)", r" &gt;= \1", diagram)
    return diagram

# Match src/href attrs with relative paths (./foo or foo but not http:// or /abs)
REL_ASSET_RE = re.compile(
    r'(?P<attr>src|href)\s*=\s*"(?!https?://|data:|/|#)(?P<path>\./[^"]*|[^":/][^"]*)"'
)


def _rewrite_relative_assets(html: str, *, prefix: str) -> str:
    """Rewrite relative src/href paths in HTML to be relative to a new prefix.

    `prefix` is the directory (relative to the HTML's new location) that the
    original markdown doc lived in. E.g. for a flow doc at
    `docs/ux/flows/sign_in.md`, prefix is `docs/ux/flows`, so
    `src="./_screenshots/sign_in/foo.png"` becomes
    `src="docs/ux/flows/_screenshots/sign_in/foo.png"`.
    """
    prefix = prefix.rstrip("/")
    def replace(match: re.Match[str]) -> str:
        path = match.group("path")
        if path.startswith("./"):
            path = path[2:]
        return f'{match.group("attr")}="{prefix}/{path}"'
    return REL_ASSET_RE.sub(replace, html)


def _strip_frontmatter(text: str) -> str:
    m = FRONTMATTER_RE.match(text)
    if m:
        return text[m.end():]
    return text


def _extract_title(text: str) -> str | None:
    m = H1_RE.search(text)
    return m.group(1).strip() if m else None


# ---- Overview / cross-link index builders (Proposals A + C) ----------------

FINDING_ID_SCAN = re.compile(r'\b(UX|CH|RT|RL)-(\d{3,4})\b')


def _build_indexes(audit: dict[str, Any], sections: list[dict[str, Any]]) -> dict[str, Any]:
    """Pre-compute reverse indexes for cross-linking.

    Returns a dict with:
      findings_by_file: {path: [finding_id, ...]}
      findings_by_tag:  {tag: [finding_id, ...]}
      docs_by_finding:  {finding_id: [{doc_id, section_slug, doc_title, rel_path}, ...]}
      file_tree:        sorted list of (path, count, max_severity, finding_ids)
    """
    findings = audit.get("findings", [])
    all_finding_ids = {f["id"] for f in findings if f.get("id")}
    finding_by_id = {f["id"]: f for f in findings if f.get("id")}

    findings_by_file: dict[str, list[str]] = defaultdict(list)
    findings_by_tag: dict[str, list[str]] = defaultdict(list)
    for f in findings:
        for e in (f.get("evidence") or []):
            p = e.get("path")
            if not p:
                continue
            # Normalize away leading ./ and .audit/
            p = p.lstrip("./")
            if p.startswith(".audit/"):
                continue
            if f["id"] not in findings_by_file[p]:
                findings_by_file[p].append(f["id"])
        for t in (f.get("tags") or []):
            if f["id"] not in findings_by_tag[t]:
                findings_by_tag[t].append(f["id"])

    # Scan authored doc HTML for literal finding IDs to build the back-reference.
    docs_by_finding: dict[str, list[dict[str, str]]] = defaultdict(list)
    for section in sections:
        for doc in section["docs"]:
            html_blob = doc.get("html", "") or ""
            # For flow docs, also scan the scene step prose
            if doc.get("flow_scene"):
                scene = doc["flow_scene"]
                html_blob += " " + (scene.get("intro_html", "") or "")
                html_blob += " " + (scene.get("outro_html", "") or "")
                for step in scene.get("steps", []):
                    html_blob += " " + (step.get("prose_html", "") or "")
                    for fid in step.get("findings", []) or []:
                        if fid in all_finding_ids:
                            entry = {
                                "doc_id": doc["id"],
                                "section_slug": section["slug"],
                                "doc_title": doc["title"],
                                "rel_path": doc.get("rel_path", ""),
                            }
                            if entry not in docs_by_finding[fid]:
                                docs_by_finding[fid].append(entry)
            seen_in_doc: set[str] = set()
            for m in FINDING_ID_SCAN.finditer(html_blob):
                fid = f"{m.group(1)}-{m.group(2)}"
                if fid in all_finding_ids and fid not in seen_in_doc:
                    seen_in_doc.add(fid)
                    entry = {
                        "doc_id": doc["id"],
                        "section_slug": section["slug"],
                        "doc_title": doc["title"],
                        "rel_path": doc.get("rel_path", ""),
                    }
                    if entry not in docs_by_finding[fid]:
                        docs_by_finding[fid].append(entry)

    # File tree: every source file that has ≥1 finding, sorted by count desc.
    sev_rank = {"critical": 3, "major": 2, "moderate": 1, "minor": 0}
    file_tree: list[dict[str, Any]] = []
    for path, fids in findings_by_file.items():
        max_sev = "minor"
        max_rank = -1
        for fid in fids:
            f = finding_by_id.get(fid, {})
            r = sev_rank.get(f.get("severity", "minor"), 0)
            if r > max_rank:
                max_rank = r
                max_sev = f.get("severity", "minor")
        file_tree.append({
            "path": path,
            "count": len(fids),
            "max_severity": max_sev,
            "finding_ids": fids,
        })
    file_tree.sort(key=lambda x: (-x["count"], -sev_rank.get(x["max_severity"], 0), x["path"]))

    return {
        "findings_by_file": dict(findings_by_file),
        "findings_by_tag": dict(findings_by_tag),
        "docs_by_finding": {k: v for k, v in docs_by_finding.items()},
        "file_tree": file_tree,
    }


def _build_overview(
    audit: dict[str, Any],
    indexes: dict[str, Any],
    authored_docs_dir: Path,
) -> dict[str, Any]:
    """Build the cover-page data (Proposal A).

    Returns:
      {
        exec_brief_html: str | None,
        top_rice: [finding],
        ship_blockers: [finding],
        file_hotspots: [{path, count, max_severity, finding_ids}],
        pillar_stats: [{slug, title, count, critical, major, moderate, minor}],
      }
    """
    findings = audit.get("findings", [])

    # Top 5 by RICE score
    sev_rank = {"critical": 0, "major": 1, "moderate": 2, "minor": 3}
    top_rice = sorted(
        findings,
        key=lambda f: (-(f.get("rice", {}).get("score") or 0), sev_rank.get(f.get("severity", "minor"), 3)),
    )[:10]

    # Ship blockers: critical + must
    ship_blockers = [
        f for f in findings
        if f.get("severity") == "critical" and f.get("priority") == "must"
    ]
    ship_blockers.sort(key=lambda f: -(f.get("rice", {}).get("score") or 0))

    # Pillar stats
    pillar_titles = {
        "code_health": "Code Health",
        "ux": "UX",
        "runtime": "Runtime",
        "release": "Release",
    }
    pillar_stats: list[dict[str, Any]] = []
    for slug in ("code_health", "ux", "runtime", "release"):
        in_pillar = [f for f in findings if f.get("pillar") == slug]
        if not in_pillar:
            continue
        pillar_stats.append({
            "slug": slug,
            "title": pillar_titles.get(slug, slug.title()),
            "count": len(in_pillar),
            "critical": sum(1 for f in in_pillar if f.get("severity") == "critical"),
            "major": sum(1 for f in in_pillar if f.get("severity") == "major"),
            "moderate": sum(1 for f in in_pillar if f.get("severity") == "moderate"),
            "minor": sum(1 for f in in_pillar if f.get("severity") == "minor"),
        })

    # File hotspots — top 10 by finding count
    file_hotspots = indexes.get("file_tree", [])[:10]

    # Exec brief: look for an authored `docs/00-exec-brief.md` or `docs/exec-brief.md`.
    # If absent, fall back to None — the template will generate a stub.
    exec_brief_html: str | None = None
    for candidate in ("00-exec-brief.md", "exec-brief.md"):
        brief_path = authored_docs_dir / candidate
        if brief_path.exists():
            md_module = _get_markdown_module()
            md_to_html = _make_markdown_to_html_callable(md_module)
            raw = brief_path.read_text(encoding="utf-8", errors="replace")
            exec_brief_html = md_to_html(_strip_frontmatter(raw))
            exec_brief_html = _transform_mermaid_blocks(exec_brief_html)
            break

    return {
        "exec_brief_html": exec_brief_html,
        "top_rice": top_rice,
        "ship_blockers": ship_blockers,
        "file_hotspots": file_hotspots,
        "pillar_stats": pillar_stats,
    }


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
