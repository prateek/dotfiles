#!/usr/bin/env python3
"""Render a workflow summary page from captured step files."""

import json
import os
import re
import sys

H1_RE = re.compile(r"^# (.+)$", re.MULTILINE)
STEP_HEADER_RE = re.compile(r"^## Step (\d+): (.+)$", re.MULTILINE)

STATUS_OK = "ok"
STATUS_WARN = "warn"
STATUS_ERROR = "error"

PREFIXES = {
    STATUS_OK: "✓",  # ✓
    STATUS_WARN: "⚠",  # ⚠
    STATUS_ERROR: "✗",  # ✗
}

PAGE_TEMPLATE = """<!DOCTYPE html>
<html><head><title>{title}</title></head>
<body><h1>{title}</h1><p>{wf} workflows, {steps} steps</p>{body}
<script type="application/json">__DATA__</script></body></html>
"""


def _slug(name):
    """Slugify the name."""
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def render_workflow(workflow, index):
    status = workflow.get("status", STATUS_OK)
    prefix = PREFIXES.get(status, "?")
    return '<div id="wf-{}-{}">{} {}</div>'.format(
        index, _slug(workflow["name"]), prefix, workflow["name"]
    )


def render_page(body, workflows, out_dir):
    # Extract the document title
    h1 = H1_RE.search(body)
    title = h1.group(1) if h1 else "Untitled"

    # Find all step headers
    step_matches = list(STEP_HEADER_RE.finditer(body))

    # Render workflows
    wf_html = "".join(render_workflow(w, i) for i, w in enumerate(workflows))

    # Stats
    total_wf = len(workflows)
    total_steps = len(step_matches)

    page = PAGE_TEMPLATE.format(
        title=title, body=wf_html, wf=total_wf, steps=total_steps
    )
    payload = json.dumps({"title": title, "steps": total_steps})
    # Escape </script> so the JSON can safely sit inside a <script> block.
    payload = payload.replace("</", "<\\/")
    page = page.replace("__DATA__", payload)

    # Save results
    results_path = os.path.join(out_dir, "results.json")
    with open(results_path, "w") as f:
        f.write(payload)
    return page


def main():
    if len(sys.argv) != 3:
        print("usage: report.py <input.md> <out-dir>", file=sys.stderr)
        return 2
    with open(sys.argv[1]) as f:
        body = f.read()
    workflows = [{"name": m.group(2)} for m in STEP_HEADER_RE.finditer(body)]
    page = render_page(body, workflows, sys.argv[2])
    out_path = os.path.join(sys.argv[2], "index.html")
    with open(out_path, "w") as f:
        f.write(page)
    return 0


if __name__ == "__main__":
    sys.exit(main())
