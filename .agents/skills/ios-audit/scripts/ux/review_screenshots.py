#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Organize captured screenshots for LLM-based visual/UX review.

Outputs a structured review manifest that an LLM agent can process image-by-image.
"""

import argparse
import json
import os
import sys


def build_review_manifest(results_path: str) -> dict:
    """Build a review manifest from workflow results.

    The manifest groups screenshots by workflow and provides context
    for each one (what action led to this screen, what's expected).
    An LLM agent reads this manifest, looks at each screenshot, and
    produces structured issue findings.
    """
    with open(results_path) as f:
        data = json.load(f)

    manifest = {
        "app": data.get("app", {}),
        "review_instructions": (
            "For each screenshot, evaluate:\n"
            "1. Layout: Is content properly aligned, sized, and not clipped?\n"
            "2. Typography: Is text readable, properly sized, and not truncated?\n"
            "3. Colors: Does the palette match a premium dark-theme streaming app?\n"
            "4. Images: Are images loading, properly scaled, and clipped?\n"
            "5. Navigation: Is the expected screen showing after the interaction?\n"
            "6. Empty states: Are blank areas intentional or missing content?\n"
            "7. Accessibility: Are interactive elements clearly tappable?\n"
            "\n"
            "Categorize issues as: critical, major, moderate, minor.\n"
            "Output structured JSON with: workflow, step, severity, description."
        ),
        "screens": [],
    }

    for wf in data.get("workflows", []):
        wf_name = wf.get("name", "Unknown")
        for step in wf.get("steps", []):
            screenshot = step.get("screenshot_path")
            if not screenshot or not os.path.exists(screenshot):
                continue

            manifest["screens"].append({
                "workflow": wf_name,
                "step_index": step.get("step_index", 0),
                "action": step.get("action", ""),
                "description": step.get("description", ""),
                "interaction_type": step.get("interaction_type", ""),
                "screenshot_path": os.path.abspath(screenshot),
                "success": step.get("success", True),
                "accessibility_summary": _summarize_accessibility(
                    step.get("accessibility", {})
                ),
            })

    return manifest


def _summarize_accessibility(tree: dict) -> str:
    """Create a brief summary of the accessibility tree for review context."""
    if not tree:
        return "No accessibility data"
    if "raw" in tree:
        # Take first 200 chars of raw output
        return tree["raw"][:200]
    buttons = tree.get("buttons", [])
    text_fields = tree.get("text_fields", [])
    summary_parts = []
    if buttons:
        summary_parts.append(f"Buttons: {', '.join(buttons[:5])}")
    if text_fields:
        summary_parts.append(f"TextFields: {len(text_fields)}")
    return "; ".join(summary_parts) if summary_parts else "No interactive elements"


def main():
    parser = argparse.ArgumentParser(
        description="Organize screenshots for LLM visual review"
    )
    parser.add_argument("--results", required=True, help="Path to results.json")
    parser.add_argument("--output", default=None, help="Output manifest JSON path")
    parser.add_argument("--json", action="store_true", help="Print manifest to stdout")
    args = parser.parse_args()

    manifest = build_review_manifest(args.results)

    if args.output:
        with open(args.output, "w") as f:
            json.dump(manifest, f, indent=2)
        print(f"Review manifest: {args.output} ({len(manifest['screens'])} screens)")

    if args.json:
        print(json.dumps(manifest, indent=2))

    if not args.output and not args.json:
        # Default: print summary
        print(f"App: {manifest['app'].get('name', 'Unknown')}")
        print(f"Screenshots to review: {len(manifest['screens'])}")
        for screen in manifest["screens"]:
            status = "OK" if screen["success"] else "FAIL"
            print(f"  [{status}] {screen['workflow']} > {screen['description']}")
            print(f"         {screen['screenshot_path']}")


if __name__ == "__main__":
    main()
