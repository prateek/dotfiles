#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#   "pillow",
# ]
# ///
"""Generate an HTML flow document from ios-flow-audit results.

Shows each workflow as a horizontal flow of screenshots with interaction arrows and issue badges.
"""

import argparse
import base64
import json
import os
import sys
from pathlib import Path

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{app_name} — Workflow Audit</title>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{ background: #0D0F12; color: #F3F5F8; font-family: -apple-system, BlinkMacSystemFont, system-ui, sans-serif; padding: 40px 20px; }}
  h1 {{ font-size: 32px; font-weight: 700; margin-bottom: 8px; }}
  h1 .accent {{ color: #E11D2E; }}
  .subtitle {{ color: #A8B0BD; font-size: 14px; margin-bottom: 40px; }}
  .summary {{ background: #141820; border-radius: 16px; padding: 24px; margin-bottom: 40px; }}
  .summary h2 {{ font-size: 18px; margin-bottom: 16px; }}
  .summary-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 16px; }}
  .stat {{ text-align: center; padding: 16px; background: #1B2029; border-radius: 12px; }}
  .stat-number {{ font-size: 28px; font-weight: 700; }}
  .stat-number.red {{ color: #E11D2E; }}
  .stat-number.yellow {{ color: #fbbf24; }}
  .stat-number.green {{ color: #4ade80; }}
  .stat-number.blue {{ color: #7DA2FF; }}
  .stat-label {{ font-size: 12px; color: #A8B0BD; margin-top: 4px; }}
  .workflow {{ margin-bottom: 60px; border-bottom: 1px solid rgba(255,255,255,0.08); padding-bottom: 40px; }}
  .workflow:last-child {{ border-bottom: none; }}
  .wf-header {{ display: flex; align-items: center; gap: 12px; margin-bottom: 8px; }}
  .wf-number {{ background: #E11D2E; color: white; font-weight: 700; font-size: 14px; width: 32px; height: 32px; border-radius: 8px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }}
  .wf-title {{ font-size: 22px; font-weight: 600; }}
  .wf-status {{ font-size: 12px; padding: 4px 10px; border-radius: 12px; margin-left: auto; font-weight: 600; }}
  .status-pass {{ background: #1a3a1a; color: #4ade80; }}
  .status-fail {{ background: #3a1a1a; color: #E11D2E; }}
  .wf-desc {{ color: #A8B0BD; font-size: 13px; margin-bottom: 16px; margin-left: 44px; }}
  .flow {{ display: flex; align-items: flex-start; gap: 0; overflow-x: auto; padding: 10px 0 20px; }}
  .step {{ display: flex; align-items: flex-start; flex-shrink: 0; }}
  .step-card {{ width: 180px; text-align: center; }}
  .step-img {{ width: 140px; height: 280px; object-fit: cover; object-position: top; border-radius: 14px; border: 2px solid #1B2029; box-shadow: 0 4px 16px rgba(0,0,0,0.4); }}
  .step-img.failed {{ border-color: #E11D2E; }}
  .step-label {{ font-size: 11px; font-weight: 600; color: #F3F5F8; margin-top: 6px; }}
  .step-action {{ font-size: 10px; color: #A8B0BD; margin-top: 2px; }}
  .step-time {{ font-size: 9px; color: #555; margin-top: 2px; }}
  .arrow {{ display: flex; flex-direction: column; align-items: center; justify-content: center; min-width: 70px; padding-top: 120px; }}
  .arrow-line {{ width: 40px; height: 2px; background: #E11D2E; position: relative; }}
  .arrow-line::after {{ content: ''; position: absolute; right: -1px; top: -4px; border: 5px solid transparent; border-left-color: #E11D2E; }}
  .arrow-label {{ font-size: 9px; color: #7DA2FF; font-weight: 600; margin-top: 4px; text-transform: uppercase; letter-spacing: 0.3px; white-space: nowrap; max-width: 70px; overflow: hidden; text-overflow: ellipsis; }}
  .issues {{ margin-top: 12px; margin-left: 44px; }}
  .issue {{ display: flex; align-items: flex-start; gap: 8px; padding: 6px 10px; border-radius: 6px; margin-bottom: 4px; font-size: 12px; line-height: 1.4; }}
  .issue-fail {{ background: rgba(225,29,46,0.12); border-left: 3px solid #E11D2E; }}
  .issue-warn {{ background: rgba(251,191,36,0.1); border-left: 3px solid #fbbf24; }}
</style>
</head>
<body>

<h1>{app_name} <span class="accent">Workflow Audit</span></h1>
<p class="subtitle">{workflow_count} workflows tested &middot; {step_count} steps executed &middot; {run_date}</p>

<div class="summary">
  <h2>Summary</h2>
  <div class="summary-grid">
    <div class="stat"><div class="stat-number green">{passed}</div><div class="stat-label">Passed</div></div>
    <div class="stat"><div class="stat-number red">{failed}</div><div class="stat-label">Failed</div></div>
    <div class="stat"><div class="stat-number blue">{step_count}</div><div class="stat-label">Total Steps</div></div>
    <div class="stat"><div class="stat-number">{screenshot_count}</div><div class="stat-label">Screenshots</div></div>
  </div>
</div>

{workflow_html}

</body>
</html>"""


def image_to_data_uri(path: str, max_width: int = 300) -> str:
    """Convert an image file to a base64 data URI, optionally resizing."""
    if not path or not os.path.exists(path):
        return ""
    try:
        from PIL import Image
        import io
        img = Image.open(path)
        ratio = max_width / img.width
        new_size = (max_width, int(img.height * ratio))
        img = img.resize(new_size, Image.LANCZOS)
        buffer = io.BytesIO()
        img.save(buffer, format="PNG", optimize=True)
        b64 = base64.b64encode(buffer.getvalue()).decode()
    except ImportError:
        with open(path, "rb") as f:
            b64 = base64.b64encode(f.read()).decode()
    return f"data:image/png;base64,{b64}"


def image_src(path: str, embed: bool = False) -> str:
    """Return either a file:// URL or embedded data URI."""
    if not path or not os.path.exists(path):
        return ""
    if embed:
        return image_to_data_uri(path)
    return f"file://{os.path.abspath(path)}"


def render_workflow(wf: dict, index: int, embed_images: bool) -> str:
    """Render a single workflow as HTML."""
    name = wf.get("name", "Unknown")
    description = wf.get("description", "")
    steps = wf.get("steps", [])
    success = wf.get("success", True)
    status_class = "status-pass" if success else "status-fail"
    status_text = "PASS" if success else "FAIL"

    # Build step cards and arrows
    flow_parts = []
    failed_steps = []

    for i, step in enumerate(steps):
        screenshot = step.get("screenshot_path", "")
        img_src = image_src(screenshot, embed_images) if screenshot else ""
        action = step.get("action", "")
        desc = step.get("description", step.get("name", f"Step {i}"))
        duration = step.get("duration_ms", 0)
        step_success = step.get("success", True)
        img_class = "step-img" + (" failed" if not step_success else "")

        # Add arrow before step (except first)
        if i > 0:
            interaction = step.get("interaction_type", action)
            flow_parts.append(f'''
    <div class="arrow">
      <div class="arrow-line"></div>
      <div class="arrow-label">{interaction}</div>
    </div>''')

        # Add step card
        img_tag = f'<img class="{img_class}" src="{img_src}" alt="{desc}">' if img_src else f'<div class="{img_class}" style="background:#1B2029;display:flex;align-items:center;justify-content:center;"><span style="color:#555;">No screenshot</span></div>'

        flow_parts.append(f'''
    <div class="step">
      <div class="step-card">
        {img_tag}
        <div class="step-label">{desc[:30]}</div>
        <div class="step-action">{action}</div>
        <div class="step-time">{duration}ms</div>
      </div>
    </div>''')

        if not step_success:
            failed_steps.append(f'Step {i}: {step.get("output", "Failed")}')

    flow_html = "".join(flow_parts)

    # Issues
    issues_html = ""
    if failed_steps:
        issues_items = "".join(
            f'<div class="issue issue-fail">{msg}</div>' for msg in failed_steps
        )
        issues_html = f'<div class="issues">{issues_items}</div>'

    return f'''
<div class="workflow">
  <div class="wf-header">
    <div class="wf-number">{index + 1}</div>
    <div class="wf-title">{name}</div>
    <span class="wf-status {status_class}">{status_text}</span>
  </div>
  <div class="wf-desc">{description}</div>
  <div class="flow">{flow_html}
  </div>
  {issues_html}
</div>'''


def main():
    parser = argparse.ArgumentParser(description="Generate HTML workflow audit report")
    parser.add_argument("--results", required=True, help="Path to results.json from run_workflows.py")
    parser.add_argument("--output", default=None, help="Output HTML file path")
    parser.add_argument("--embed-images", action="store_true",
                        help="Embed images as base64 (larger file, but portable)")
    args = parser.parse_args()

    with open(args.results) as f:
        data = json.load(f)

    app_name = data.get("app", {}).get("name", "App")
    workflows = data.get("workflows", [])
    run_date = data.get("run_time", "Unknown")[:10]

    # Stats
    total_wf = len(workflows)
    passed = sum(1 for w in workflows if w.get("success", True))
    failed = total_wf - passed
    total_steps = sum(len(w.get("steps", [])) for w in workflows)
    screenshots = sum(
        1 for w in workflows for s in w.get("steps", []) if s.get("screenshot_path")
    )

    # Render workflows
    wf_html = "".join(render_workflow(w, i, args.embed_images) for i, w in enumerate(workflows))

    html = HTML_TEMPLATE.format(
        app_name=app_name,
        workflow_count=total_wf,
        step_count=total_steps,
        run_date=run_date,
        passed=passed,
        failed=failed,
        screenshot_count=screenshots,
        workflow_html=wf_html,
    )

    output_path = args.output or os.path.join(os.path.dirname(args.results), "report.html")
    with open(output_path, "w") as f:
        f.write(html)
    print(f"Report generated: {output_path}")


if __name__ == "__main__":
    main()
