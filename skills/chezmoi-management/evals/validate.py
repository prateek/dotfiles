#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "pyyaml",
# ]
# ///
"""Post-edit validator for the chezmoi-management skill.

Run from anywhere; resolves paths relative to the script location so it
works the same in this experiment repo and after migration to
home/dot_agents/skills/chezmoi-management/ in the dotfiles repo.

Exits 0 on success, 1 on any failure. Prints one line per check.
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

import yaml


SKILL_DIR = Path(__file__).resolve().parent.parent
FAILURES: list[str] = []


def _read(rel: str) -> str:
    return (SKILL_DIR / rel).read_text()


def check(label: str, ok: bool, detail: str = "") -> None:
    mark = "ok " if ok else "FAIL"
    suffix = f"  ({detail})" if detail else ""
    print(f"  [{mark}] {label}{suffix}")
    if not ok:
        FAILURES.append(label)


def check_skill_md_frontmatter() -> None:
    text = _read("SKILL.md")
    parts = text.split("---", 2)
    check("SKILL.md has frontmatter delimiters", len(parts) >= 3)
    if len(parts) < 3:
        return
    meta = yaml.safe_load(parts[1])
    check("SKILL.md frontmatter parses as YAML", isinstance(meta, dict))
    check("SKILL.md name == chezmoi-management", meta.get("name") == "chezmoi-management",
          detail=f"got {meta.get('name')!r}")
    desc = meta.get("description", "")
    check("SKILL.md description is a non-trivial string",
          isinstance(desc, str) and len(desc) > 100,
          detail=f"len={len(desc)}")


def check_openai_yaml() -> None:
    y = yaml.safe_load(_read("agents/openai.yaml"))
    check("openai.yaml has interface block", isinstance(y, dict) and "interface" in y)
    if "interface" not in y:
        return
    iface = y["interface"]
    for key in ("display_name", "short_description", "default_prompt"):
        check(f"openai.yaml interface.{key} present", key in iface and bool(iface[key]))


def check_evals_json() -> None:
    data = json.loads(_read("evals/evals.json"))
    check("evals.json has skill_name == chezmoi-management",
          data.get("skill_name") == "chezmoi-management")
    evals = data.get("evals", [])
    check("evals.json has at least 1 eval", len(evals) >= 1, detail=f"count={len(evals)}")
    for i, e in enumerate(evals):
        for key in ("id", "name", "prompt", "expected_output", "files", "expectations"):
            check(f"evals[{i}].{key} present", key in e)
        for f in e.get("files", []):
            fixture_path = SKILL_DIR / f
            check(f"evals[{i}] fixture exists: {f}", fixture_path.is_dir(),
                  detail=str(fixture_path))


def check_mode_router_consistency() -> None:
    skill_md = _read("SKILL.md")
    references_dir = SKILL_DIR / "references"
    on_disk = sorted(p.name for p in references_dir.glob("*.md"))
    referenced = sorted(set(re.findall(r"references/([a-z][a-z0-9-]+\.md)", skill_md)))
    check("Every references/*.md is mentioned in SKILL.md",
          set(on_disk).issubset(set(referenced)),
          detail=f"missing: {sorted(set(on_disk) - set(referenced))}")
    check("Every reference mentioned in SKILL.md exists on disk",
          set(referenced).issubset(set(on_disk)),
          detail=f"dangling: {sorted(set(referenced) - set(on_disk))}")


def check_setup_fixture_executable() -> None:
    path = SKILL_DIR / "evals" / "setup_fixture.sh"
    check("setup_fixture.sh is executable", os.access(path, os.X_OK))


def check_no_external_doc_links() -> None:
    """Self-contained rule: no chezmoi.io doc URLs in references/.

    Allowed: the get.chezmoi.io install endpoint, and bare mentions of the
    string `chezmoi.io` in meta-commentary about self-containment.
    Disallowed: actual doc URLs like https://www.chezmoi.io/... or
    https://chezmoi.io/...
    """
    doc_url = re.compile(r"https?://(?:www\.)?chezmoi\.io/")
    bad: list[str] = []
    for ref in (SKILL_DIR / "references").glob("*.md"):
        if doc_url.search(ref.read_text()):
            bad.append(ref.name)
    check("No external chezmoi.io doc URLs in references/", not bad,
          detail=f"offenders: {bad}")


def check_skill_md_size() -> None:
    lines = _read("SKILL.md").splitlines()
    check("SKILL.md <= 200 lines (router pattern)", len(lines) <= 200,
          detail=f"lines={len(lines)}")


def main() -> int:
    print("Validating chezmoi-management skill at:", SKILL_DIR)
    print()
    print("[SKILL.md]")
    check_skill_md_frontmatter()
    check_skill_md_size()
    print("[agents/openai.yaml]")
    check_openai_yaml()
    print("[evals/evals.json]")
    check_evals_json()
    print("[evals/setup_fixture.sh]")
    check_setup_fixture_executable()
    print("[Mode router consistency]")
    check_mode_router_consistency()
    print("[Self-containment]")
    check_no_external_doc_links()
    print()
    if FAILURES:
        print(f"FAILED: {len(FAILURES)} check(s) — {', '.join(FAILURES)}")
        return 1
    print("ALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
