#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "pyyaml",
# ]
# ///
"""Post-edit validator for the yojam-config skill.

Run from anywhere; resolves paths relative to the script location so it
works from the repo-local .agents/skills location in the dotfiles repo.

Exits 0 on success, 1 on any failure. Prints one line per check.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import yaml


SKILL_DIR = Path(__file__).resolve().parent.parent
DESCRIPTION_MAX_CHARS = 1024
SKILL_MD_MAX_LINES = 200

# Each name must appear at least twice in SKILL.md prose: once as a
# trigger-summary inline mention, once in the Bisect workflow's canonical
# enumeration. Two unfenced occurrences is the contract; we don't pin which
# section, so structural edits to SKILL.md don't trip the validator.
SECURITY_PASS_TRIGGERS = (
    "bundleIdentifier",
    "targetBundleId",
    "customLaunchArgs",
    "ruleCustomLaunchArgs",
    "regex",
)

FAILURES: list[str] = []


def _read(rel: str) -> str:
    return (SKILL_DIR / rel).read_text(encoding="utf-8")


def check(label: str, ok: bool, detail: str = "") -> None:
    mark = "ok " if ok else "FAIL"
    suffix = f"  ({detail})" if detail else ""
    print(f"  [{mark}] {label}{suffix}")
    if not ok:
        FAILURES.append(label)


def extract_frontmatter(text: str) -> str | None:
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        return None
    for index, line in enumerate(lines[1:], start=1):
        if line == "---":
            return "\n".join(lines[1:index])
    return None


def check_skill_md_frontmatter() -> None:
    text = _read("SKILL.md")
    frontmatter = extract_frontmatter(text)
    check("SKILL.md starts with standalone frontmatter delimiters", frontmatter is not None)
    if frontmatter is None:
        return
    meta = yaml.safe_load(frontmatter)
    check("SKILL.md frontmatter parses as YAML", isinstance(meta, dict))
    if not isinstance(meta, dict):
        return
    check(
        "SKILL.md name == yojam-config",
        meta.get("name") == "yojam-config",
        detail=f"got {meta.get('name')!r}",
    )
    desc = meta.get("description", "")
    check(
        "SKILL.md description is a non-trivial string",
        isinstance(desc, str) and len(desc) > 100,
        detail=f"len={len(desc)}",
    )
    check(
        "SKILL.md description <= 1024 characters",
        isinstance(desc, str) and len(desc) <= DESCRIPTION_MAX_CHARS,
        detail=f"len={len(desc)}",
    )


def check_skill_md_size() -> None:
    lines = _read("SKILL.md").splitlines()
    check(
        f"SKILL.md <= {SKILL_MD_MAX_LINES} lines",
        len(lines) <= SKILL_MD_MAX_LINES,
        detail=f"lines={len(lines)}",
    )


def check_openai_yaml() -> None:
    y = yaml.safe_load(_read("agents/openai.yaml"))
    check("openai.yaml has interface block", isinstance(y, dict) and "interface" in y)
    if not isinstance(y, dict) or "interface" not in y:
        return
    iface = y["interface"]
    for key in ("display_name", "short_description", "default_prompt"):
        check(f"openai.yaml interface.{key} present", key in iface and bool(iface[key]))


def check_evals_json() -> None:
    data = json.loads(_read("evals/evals.json"))
    check(
        "evals.json has skill_name == yojam-config",
        data.get("skill_name") == "yojam-config",
    )
    evals = data.get("evals", [])
    check("evals.json has at least 1 eval", len(evals) >= 1, detail=f"count={len(evals)}")
    seen_ids: set[int] = set()
    seen_names: set[str] = set()
    for i, e in enumerate(evals):
        for key in ("id", "name", "prompt", "expected_output", "files", "expectations"):
            check(f"evals[{i}].{key} present", key in e)
        eval_id = e.get("id")
        if eval_id is not None:
            check(
                f"evals[{i}].id is unique",
                eval_id not in seen_ids,
                detail=f"id={eval_id}",
            )
            seen_ids.add(eval_id)
        name = e.get("name")
        if name is not None:
            check(
                f"evals[{i}].name is unique",
                name not in seen_names,
                detail=f"name={name}",
            )
            seen_names.add(name)
        for f in e.get("files", []):
            fixture_path = SKILL_DIR / f
            check(
                f"evals[{i}] fixture exists: {f}",
                fixture_path.is_dir(),
                detail=str(fixture_path),
            )


def check_no_discoverable_skill_fixtures() -> None:
    bad = sorted(
        str(path.relative_to(SKILL_DIR))
        for path in (SKILL_DIR / "evals").rglob("SKILL.md")
    )
    check(
        "No discoverable SKILL.md files under eval fixtures",
        not bad,
        detail=f"offenders: {bad}",
    )


def _strip_fenced_blocks(text: str) -> str:
    """Drop ```-fenced lines so word-boundary searches don't count code blocks
    as prose mentions. Fence lines themselves are also dropped."""
    out: list[str] = []
    in_fence = False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if not in_fence:
            out.append(line)
    return "\n".join(out)


def check_security_pass_consistency() -> None:
    """Each trigger name must appear at least twice in SKILL.md prose
    (outside fenced code blocks): once as an inline trigger summary, once
    in the canonical Bisect enumeration. Section-agnostic so structural
    edits don't trip the validator."""
    prose = _strip_fenced_blocks(_read("SKILL.md"))
    for trigger in SECURITY_PASS_TRIGGERS:
        hits = len(re.findall(rf"\b{re.escape(trigger)}\b", prose))
        check(
            f"security-pass trigger '{trigger}' mentioned >=2 times in SKILL.md prose",
            hits >= 2,
            detail=f"hits={hits}",
        )


def main() -> int:
    print("Validating yojam-config skill at:", SKILL_DIR)
    print()
    print("[SKILL.md]")
    check_skill_md_frontmatter()
    check_skill_md_size()
    print("[agents/openai.yaml]")
    check_openai_yaml()
    print("[evals/evals.json]")
    check_evals_json()
    print("[eval fixtures]")
    check_no_discoverable_skill_fixtures()
    print("[Security-pass consistency]")
    check_security_pass_consistency()
    print()
    if FAILURES:
        print(f"FAILED ({len(FAILURES)} check{'s' if len(FAILURES) != 1 else ''}):")
        for f in FAILURES:
            print(f"  - {f}")
        return 1
    print("ALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
