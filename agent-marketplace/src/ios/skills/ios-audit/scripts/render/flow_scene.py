"""Flow canvas builder for ios-audit UX flow docs.

Parses `docs/ux/flows/<slug>.md` into a structured scene object the Jinja
template can render as an interactive panzoom canvas (Proposal B).

A "step" is a block delimited by `### Step N · Title` headers. Inside the
block we extract prose, the single screenshot reference, and any UX-NNN /
CH-NNN / RT-NNN / RL-NNN finding IDs mentioned (surfaced as badges on the
step card).

We also generate 2x retina thumbnails at 240×520 CSS-px via Pillow and
cache them under `<flow_dir>/_thumbs/<slug>/`, regenerating only when the
source PNG is newer than the existing thumb.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

# ---- step parsing -----------------------------------------------------------

STEP_HEADER_RE = re.compile(r"^###\s+Step\s+(\d+)\s*·\s*(.+?)\s*$", re.MULTILINE)
IMAGE_RE = re.compile(r"!\[([^\]]*)\]\(([^)]+)\)")
FINDING_ID_RE = re.compile(r"\*\*(UX|CH|RT|RL)-(\d{3,4})\*\*|\b(UX|CH|RT|RL)-(\d{3,4})\b")
H1_RE = re.compile(r"^#\s+(.+?)\s*$", re.MULTILINE)
FRONTMATTER_RE = re.compile(r"^---\s*\n.*?\n---\s*\n", re.DOTALL)


@dataclass
class FlowStep:
    idx: int
    title: str
    caption: str
    thumb_src: str  # path relative to audit.html (i.e. docs/ux/flows/_thumbs/<slug>/<file>)
    full_src: str   # path relative to audit.html
    full_w: int
    full_h: int
    prose_html: str
    findings: list[str] = field(default_factory=list)
    # layout, filled in by _layout_steps
    x: int = 0
    y: int = 0


@dataclass
class FlowScene:
    slug: str
    title: str
    intro_html: str            # prose before the first step (happy path etc.)
    outro_html: str            # prose after the last step (edge cases, findings, related)
    steps: list[FlowStep]
    edges: list[dict[str, int]]
    canvas_width: int
    canvas_height: int

    def to_dict(self) -> dict[str, Any]:
        return {
            "slug": self.slug,
            "title": self.title,
            "intro_html": self.intro_html,
            "outro_html": self.outro_html,
            "canvas_width": self.canvas_width,
            "canvas_height": self.canvas_height,
            "steps": [step.__dict__ for step in self.steps],
            "edges": self.edges,
        }


# ---- public entry -----------------------------------------------------------

def build_flow_scene(
    *,
    markdown_path: Path,
    audit_root: Path,
    markdown_to_html,  # callable: (str) -> str
) -> FlowScene | None:
    """Parse a flow markdown doc and return a scene.

    Returns None if the file isn't a recognizable flow doc (no Step headers).
    """
    raw = markdown_path.read_text(encoding="utf-8", errors="replace")
    body = _strip_frontmatter(raw)

    h1 = H1_RE.search(body)
    title = h1.group(1).strip() if h1 else markdown_path.stem.replace("_", " ").title()

    step_matches = list(STEP_HEADER_RE.finditer(body))
    if not step_matches:
        return None

    slug = markdown_path.stem  # e.g. "sign_in"
    flow_dir = markdown_path.parent  # .audit/docs/ux/flows
    authored_docs_dir = audit_root / "docs"  # .audit/docs

    # Intro = everything before the first Step header (minus the "Step-by-step
    # walkthrough" sub-header that immediately precedes them)
    intro_raw = body[: step_matches[0].start()].rstrip()
    intro_raw = re.sub(r"##\s+Step-by-step walkthrough\s*$", "", intro_raw, flags=re.MULTILINE).rstrip()

    # Outro = everything after the last step. The last step extends until the
    # next ## header at level 2 (e.g. "## Edge cases observed") or EOF.
    last_step_start = step_matches[-1].end()
    outro_match = re.search(r"^##\s+", body[last_step_start:], re.MULTILINE)
    if outro_match:
        outro_start = last_step_start + outro_match.start()
        outro_raw = body[outro_start:]
    else:
        outro_raw = ""

    # Parse each step block
    steps: list[FlowStep] = []
    for i, m in enumerate(step_matches):
        idx = int(m.group(1))
        step_title = m.group(2).strip()

        block_start = m.end()
        if i + 1 < len(step_matches):
            block_end = step_matches[i + 1].start()
        else:
            # last step extends to the outro boundary
            if outro_match:
                block_end = last_step_start + outro_match.start()
            else:
                block_end = len(body)
        block = body[block_start:block_end].strip()

        # Extract the screenshot reference
        img_match = IMAGE_RE.search(block)
        if not img_match:
            # Skip steps without a screenshot — should not happen for canonical flows
            continue
        caption = img_match.group(1)
        rel_src = img_match.group(2)  # e.g. "./_screenshots/sign_in/sign_in_step0.png"

        # Resolve to an absolute path on disk
        screenshot_path = (flow_dir / rel_src).resolve()
        if not screenshot_path.exists():
            # Try one-level normalization (handle ./ prefix stripped)
            alt = flow_dir / rel_src.lstrip("./")
            if alt.exists():
                screenshot_path = alt.resolve()
            else:
                continue

        # Generate / reuse thumbnail
        try:
            thumb_rel, full_w, full_h = _ensure_thumbnail(
                screenshot=screenshot_path,
                flow_dir=flow_dir,
                slug=slug,
            )
        except Exception as e:  # noqa: BLE001
            # On any thumbnail failure, fall back to using the full-res as-is
            full_w, full_h = _get_image_size_fallback(screenshot_path)
            thumb_rel = _relative_to_authored_docs(screenshot_path, authored_docs_dir)

        # Prose inside the step block, minus the image reference itself
        prose_md = IMAGE_RE.sub("", block).strip()
        prose_html = markdown_to_html(prose_md) if prose_md else ""

        # Finding IDs mentioned in this step
        finding_ids = _extract_finding_ids(block)

        # Build the paths the template will consume (relative to audit.html)
        full_rel = _relative_to_authored_docs(screenshot_path, authored_docs_dir)

        steps.append(
            FlowStep(
                idx=idx,
                title=step_title,
                caption=caption,
                thumb_src=f"docs/{thumb_rel}",
                full_src=f"docs/{full_rel}",
                full_w=full_w,
                full_h=full_h,
                prose_html=prose_html,
                findings=finding_ids,
            )
        )

    if not steps:
        return None

    # Layout the steps in a wrapping grid
    canvas_w, canvas_h = _layout_steps(steps)

    # Build arrow edges between consecutive steps
    edges = _build_edges(steps)

    return FlowScene(
        slug=slug,
        title=title,
        intro_html=markdown_to_html(intro_raw) if intro_raw else "",
        outro_html=markdown_to_html(outro_raw) if outro_raw else "",
        steps=steps,
        edges=edges,
        canvas_width=canvas_w,
        canvas_height=canvas_h,
    )


# ---- helpers ----------------------------------------------------------------

def _strip_frontmatter(text: str) -> str:
    m = FRONTMATTER_RE.match(text)
    return text[m.end():] if m else text


def _extract_finding_ids(text: str) -> list[str]:
    """Extract UX-NNN / CH-NNN / RT-NNN / RL-NNN IDs from step prose, deduped and sorted."""
    ids: set[str] = set()
    for m in FINDING_ID_RE.finditer(text):
        prefix = m.group(1) or m.group(3)
        number = m.group(2) or m.group(4)
        if prefix and number:
            ids.add(f"{prefix}-{number}")
    return sorted(ids)


# Thumbnail target dimensions (CSS px). Retina 2x for sharpness.
THUMB_W_CSS = 120
THUMB_H_CSS = 260
THUMB_W_PX = THUMB_W_CSS * 2
THUMB_H_PX = THUMB_H_CSS * 2


def _ensure_thumbnail(*, screenshot: Path, flow_dir: Path, slug: str) -> tuple[str, int, int]:
    """Generate a thumbnail for `screenshot` if needed. Returns (relative_path, full_w, full_h)."""
    try:
        from PIL import Image
    except ImportError as e:
        raise RuntimeError("Pillow is not installed in the audit venv") from e

    thumb_dir = flow_dir / "_thumbs" / slug
    thumb_dir.mkdir(parents=True, exist_ok=True)
    thumb_path = thumb_dir / screenshot.name

    with Image.open(screenshot) as img:
        full_w, full_h = img.size

        if thumb_path.exists() and thumb_path.stat().st_mtime >= screenshot.stat().st_mtime:
            # Cached and fresh
            pass
        else:
            thumb = img.copy()
            thumb.thumbnail((THUMB_W_PX, THUMB_H_PX), Image.Resampling.LANCZOS)
            # Normalize to RGB for consistent JPEG/PNG save
            if thumb.mode in ("RGBA", "LA", "P"):
                thumb_rgb = Image.new("RGB", thumb.size, (255, 255, 255))
                thumb_rgb.paste(thumb, mask=thumb.split()[-1] if thumb.mode in ("RGBA", "LA") else None)
                thumb = thumb_rgb
            thumb.save(thumb_path, "PNG", optimize=True)

    # Path relative to the authored docs root (i.e. `ux/flows/_thumbs/<slug>/name.png`)
    flows_root = flow_dir.parent  # .audit/docs/ux
    rel = thumb_path.relative_to(flows_root.parent)  # relative to .audit/docs
    return str(rel), full_w, full_h


def _get_image_size_fallback(screenshot: Path) -> tuple[int, int]:
    """Get image dimensions without Pillow (for the thumbnail failure path)."""
    try:
        from PIL import Image
        with Image.open(screenshot) as img:
            return img.size
    except Exception:  # noqa: BLE001
        return (1179, 2556)  # iPhone 16 Pro default


def _relative_to_authored_docs(screenshot: Path, authored_docs_dir: Path) -> str:
    """Return screenshot path relative to the authored docs root, forward-slashed."""
    try:
        rel = screenshot.resolve().relative_to(authored_docs_dir.resolve())
        return str(rel).replace("\\", "/")
    except ValueError:
        # Fallback: best-effort relative
        return str(screenshot.name)


# Grid layout tuning
STEP_CARD_W = 140   # thumb width + 20px padding
STEP_CARD_H = 320   # thumb height + 60px label band
GUTTER_X = 40
GUTTER_Y = 40
CANVAS_PADDING = 32
MAX_CANVAS_W = 1400  # max auto-wrap width before we start a new row


def _layout_steps(steps: list[FlowStep]) -> tuple[int, int]:
    """Lay out steps in an auto-wrapping grid. Returns (canvas_w, canvas_h)."""
    if not steps:
        return (0, 0)

    cols_per_row = max(1, (MAX_CANVAS_W - CANVAS_PADDING * 2 + GUTTER_X) // (STEP_CARD_W + GUTTER_X))
    cols_per_row = min(cols_per_row, len(steps))  # don't over-pad short flows

    for i, step in enumerate(steps):
        row = i // cols_per_row
        col = i % cols_per_row
        step.x = CANVAS_PADDING + col * (STEP_CARD_W + GUTTER_X)
        step.y = CANVAS_PADDING + row * (STEP_CARD_H + GUTTER_Y)

    rows = (len(steps) + cols_per_row - 1) // cols_per_row
    canvas_w = CANVAS_PADDING * 2 + cols_per_row * STEP_CARD_W + (cols_per_row - 1) * GUTTER_X
    canvas_h = CANVAS_PADDING * 2 + rows * STEP_CARD_H + (rows - 1) * GUTTER_Y
    return (canvas_w, canvas_h)


def _build_edges(steps: list[FlowStep]) -> list[dict[str, int]]:
    """Build arrow edges connecting consecutive steps."""
    edges: list[dict[str, int]] = []
    for a, b in zip(steps, steps[1:]):
        # Right-center of card A to left-center of card B
        ax = a.x + STEP_CARD_W
        ay = a.y + STEP_CARD_H // 2
        bx = b.x
        by = b.y + STEP_CARD_H // 2
        edges.append({"x1": ax, "y1": ay, "x2": bx, "y2": by})
    return edges
