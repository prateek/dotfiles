"""Render merged audit output.

Inputs (under `audit_root`):
  raw/meta.json               # from collect
  raw/<pillar>.json           # from collect
  findings/<pillar>.json      # from analyze (authored by the invoking agent)
  docs/**.md                  # from analyze (authored by the invoking agent)

Outputs:
  audit_root/audit.json       # merged baseline (see audit-schema.json)
  audit_root/audit.html       # self-contained HTML report
  <docs_dir>/                 # authored markdown copied over

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
FIXED_DOCS_BY_PILLAR: dict[str, tuple[str, ...]] = {
    "code_health": (
        "00-exec-brief.md",
        "architecture/01-overview.md",
        "architecture/02-module-graph.md",
        "architecture/03-state-management.md",
        "architecture/04-networking.md",
        "architecture/05-configuration.md",
        "quality/known-issues.md",
        "quality/concurrency-audit.md",
        "quality/code-smells.md",
        "quality/refactoring-opportunities.md",
    ),
    "ux": (
        "00-exec-brief.md",
        "ux/screen-inventory.md",
        "ux/navigation-graph.md",
        "ux/component-catalog.md",
        "ux/device-matrix.md",
        "ux/consistency-audit.md",
        "ux/layer-hierarchies.md",
        "ux/gesture-audit.md",
        "ux/accessibility-audit.md",
    ),
    "runtime": (
        "00-exec-brief.md",
        "operations/failure-modes.md",
        "operations/caching-strategy.md",
        "operations/resource-usage.md",
        "operations/storage-policy.md",
        "operations/observability.md",
    ),
    "release": (
        "00-exec-brief.md",
        "release/privacy-manifest.md",
        "release/permissions-and-plist.md",
        "release/localization.md",
        "release/signing-and-distribution.md",
        "release/app-store-readiness.md",
        "release/third-party-dependencies.md",
    ),
}


def render(
    *,
    audit_root: Path,
    docs_dir: Path,
    skill_root: Path,
) -> Path:
    raw_dir = audit_root / "raw"
    findings_dir = audit_root / "findings"
    authored_docs_dir = audit_root / "docs"

    meta = read_json(raw_dir / "meta.json") if (raw_dir / "meta.json").exists() else {}
    _validate_authored_audit(
        raw_dir=raw_dir,
        findings_dir=findings_dir,
        authored_docs_dir=authored_docs_dir,
        meta=meta,
    )
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

    # Copy authored docs into target docs_dir. Preserve is opt-in only and
    # discouraged because fresh audits should replace generated docs outright.
    if authored_docs_dir.exists():
        _apply_docs(
            authored=authored_docs_dir,
            target=docs_dir,
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


def _apply_docs(*, authored: Path, target: Path) -> None:
    """Replace target with authored contents."""
    target = target.resolve()
    authored = authored.resolve()

    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(authored, target)


def _validate_authored_audit(
    *,
    raw_dir: Path,
    findings_dir: Path,
    authored_docs_dir: Path,
    meta: dict[str, Any],
) -> None:
    """Fail fast when an audit run is incomplete.

    Render should only operate on a complete, freshly-authored audit set.
    """
    errors: list[str] = []
    pillars = _pillars_run(meta=meta, raw_dir=raw_dir)

    if not authored_docs_dir.exists():
        errors.append(f"missing authored docs directory: {authored_docs_dir}")
    if not findings_dir.exists():
        errors.append(f"missing findings directory: {findings_dir}")

    for pillar in pillars:
        findings_path = findings_dir / f"{pillar}.json"
        if not findings_path.exists():
            errors.append(f"missing findings file for pillar `{pillar}`: {findings_path}")
            continue
        try:
            payload = read_json(findings_path)
        except Exception as e:  # noqa: BLE001
            errors.append(f"unreadable findings file for pillar `{pillar}`: {findings_path} ({e!r})")
            continue
        if not isinstance(payload, (list, dict)):
            errors.append(f"findings file for pillar `{pillar}` must be a JSON array or object: {findings_path}")

        for rel in FIXED_DOCS_BY_PILLAR.get(pillar, ()):
            if not (authored_docs_dir / rel).exists():
                errors.append(f"missing required authored doc for pillar `{pillar}`: docs/{rel}")

    architecture_docs = sorted((authored_docs_dir / "architecture").glob("*.md")) if authored_docs_dir.exists() else []
    if "code_health" in pillars and len(architecture_docs) < 6:
        errors.append(
            "expected a full architecture section for `code_health` "
            f"(at least 6 markdown files under docs/architecture, found {len(architecture_docs)})"
        )

    runbooks = sorted((authored_docs_dir / "operations" / "runbooks").glob("*.md")) if authored_docs_dir.exists() else []
    if "runtime" in pillars and not runbooks:
        errors.append("expected at least one runbook under docs/operations/runbooks for the runtime pillar")

    if "ux" in pillars:
        flow_slugs = _expected_ux_flow_slugs(raw_dir)
        if not flow_slugs:
            errors.append("ux pillar ran but no workflows were found in raw/ux_run/results.json")
        for slug in flow_slugs:
            flow_doc = authored_docs_dir / "ux" / "flows" / f"{slug}.md"
            shots_dir = authored_docs_dir / "ux" / "flows" / "_screenshots" / slug
            if not flow_doc.exists():
                errors.append(f"missing required UX flow doc: docs/ux/flows/{slug}.md")
            if not shots_dir.exists() or not any(shots_dir.iterdir()):
                errors.append(
                    f"missing current-run screenshots for flow `{slug}` under "
                    f"docs/ux/flows/_screenshots/{slug}/"
                )

    if errors:
        bullets = "\n".join(f"- {error}" for error in errors)
        raise RuntimeError(
            "ios-audit render requires a complete fresh authored audit set before rendering.\n"
            "Missing or invalid audit artifacts:\n"
            f"{bullets}"
        )


def _pillars_run(*, meta: dict[str, Any], raw_dir: Path) -> tuple[str, ...]:
    configured = meta.get("pillars_run")
    if isinstance(configured, list) and configured:
        return tuple(str(p) for p in configured if str(p) in ALL_PILLARS)
    return tuple(
        pillar for pillar in ALL_PILLARS
        if (raw_dir / f"{pillar}.json").exists()
    )


def _expected_ux_flow_slugs(raw_dir: Path) -> list[str]:
    results_path = raw_dir / "ux_run" / "results.json"
    if not results_path.exists():
        return []
    try:
        data = read_json(results_path)
    except Exception:  # noqa: BLE001
        return []

    workflows = data.get("workflows")
    if not isinstance(workflows, list):
        workflows = (data.get("results") or {}).get("workflows")
    if not isinstance(workflows, list):
        return []

    slugs: list[str] = []
    for workflow in workflows:
        name = str((workflow or {}).get("name") or "unknown")
        slug = name.replace(" ", "_").lower()
        if slug not in slugs:
            slugs.append(slug)
    return slugs


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

    Requires Jinja2 + markdown. Missing renderer dependencies should fail
    the audit run instead of silently degrading the report.
    """
    template_path = skill_root / "scripts" / "render" / "templates" / "audit.html.j2"
    try:
        import jinja2
    except ImportError as e:
        raise RuntimeError(
            "ios-audit render requires the `jinja2` package. "
            "Re-run the skill through its uv-managed entrypoint so the declared dependencies are installed."
        ) from e
    except Exception as e:  # noqa: BLE001
        raise RuntimeError(f"ios-audit render failed to initialize Jinja2: {e!r}") from e

    try:
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
    except Exception as e:  # noqa: BLE001
        raise RuntimeError(f"ios-audit render failed while rendering audit.html: {e!r}") from e
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
    except ImportError as e:
        raise RuntimeError(
            "ios-audit render requires the `markdown` package. "
            "Re-run the skill through its uv-managed entrypoint so the declared dependencies are installed."
        ) from e


def _make_markdown_to_html_callable(md_module) -> Callable[[str], str]:
    """Return a `(markdown_source) -> html_string` callable using python-markdown."""
    def convert(text: str) -> str:
        return md_module.markdown(
            text,
            extensions=["tables", "fenced_code", "toc"],
            output_format="html5",
        )
    return convert


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
