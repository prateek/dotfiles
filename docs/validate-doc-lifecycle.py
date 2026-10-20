#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""Run the portable lifecycle validator with dotfiles defaults."""

import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
validator = runpy.run_path(str(
    ROOT / "agent-marketplace/src/core/skills/document-lifecycle/scripts/validate-doc-lifecycle.py"
))

if __name__ == "__main__":
    raise SystemExit(validator["main"](
        default_repo_root=ROOT,
        inventory_command="just docs-inventory",
        reject_legacy_dev=True,
        allowed_non_markdown=("validate-doc-lifecycle.py",),
    ))
