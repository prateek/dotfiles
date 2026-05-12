#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "jinja2",
#   "markdown",
#   "pillow",
#   "pyyaml",
# ]
# ///
"""ios-audit top-level orchestrator.

Subcommands:
    collect   Run all deterministic collectors → .audit/raw/*.json
    analyze   Print ANALYZE instructions (the invoking agent does the work)
    render    Merge findings + docs → audit.json, audit.html, <docs-dir>/
    diff      Compare current audit.json to baseline → audit-diff.md
    all       Run collect → analyze (interactive pause) → render → diff in order
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from common import detect_repo, eprint, now_iso, read_json, tool_version, write_json  # noqa: E402

SKILL_ROOT = SCRIPT_DIR.parent
ALL_PILLARS = ("code_health", "ux", "runtime", "release")


def cmd_collect(args: argparse.Namespace) -> int:
    repo = detect_repo(args.repo)
    output = Path(args.output).resolve()
    _reset_audit_output(output=output, repo_root=repo.root)
    raw_dir = output / "raw"
    raw_dir.mkdir(parents=True, exist_ok=True)

    pillars = _resolve_pillars(args.pillars, args.no_ux)
    eprint(f"collecting pillars: {', '.join(pillars)}")

    from collect import code_health, ux, runtime, release  # noqa: E402

    collectors = {
        "code_health": lambda: code_health.collect(repo=repo, output_dir=raw_dir),
        "ux": lambda: ux.collect(
            repo=repo,
            output_dir=raw_dir,
            workflows=Path(args.workflows).resolve() if args.workflows else None,
            udid=args.udid,
            sim_skill_dir=args.sim_skill_dir,
        ),
        "runtime": lambda: runtime.collect(repo=repo, output_dir=raw_dir),
        "release": lambda: release.collect(repo=repo, output_dir=raw_dir),
    }

    meta = {
        "schema_version": "1.0",
        "generated_at": now_iso(),
        "skill_version": _skill_version(),
        "repo": repo.as_meta(),
        "pillars_run": list(pillars),
        "tools": {
            "swiftlint": tool_version("swiftlint", "version"),
            "periphery": tool_version("periphery", "version"),
            "tuist": tool_version("tuist", "version"),
            "xcrun": tool_version("xcrun", "--version"),
            "plutil": tool_version("plutil", "-p"),
        },
    }
    app_override = _load_app_override(args.workflows) if args.workflows else {}
    if app_override:
        meta["app"] = app_override

    for name in pillars:
        eprint(f"[collect] {name}")
        try:
            collectors[name]()
        except Exception as e:  # noqa: BLE001
            eprint(f"[collect] {name} FAILED: {e!r}")
            if not args.keep_going:
                return 1

    write_json(raw_dir / "meta.json", meta)

    (output / "docs").mkdir(parents=True, exist_ok=True)
    (output / "findings").mkdir(parents=True, exist_ok=True)
    eprint(f"\nCollect complete. Raw inputs at: {raw_dir}")
    eprint(f"Next: ANALYZE each pillar (see {SKILL_ROOT}/scripts/analyze/prompts/)")
    return 0


def cmd_analyze(args: argparse.Namespace) -> int:
    output = Path(args.output).resolve()
    raw_dir = output / "raw"
    docs_dir = output / "docs"
    findings_dir = output / "findings"
    if not raw_dir.exists():
        eprint(f"ERROR: no raw inputs at {raw_dir}. Run `audit.py collect` first.")
        return 1

    prompts_dir = SKILL_ROOT / "scripts" / "analyze" / "prompts"
    pillars = _resolve_pillars(args.pillars, args.no_ux)

    print("\nANALYZE phase instructions for the invoking agent:\n")
    print(f"Output root:      {output}")
    print(f"Raw inputs:       {raw_dir}")
    print(f"Docs output:      {docs_dir}")
    print(f"Findings output:  {findings_dir}")
    print()
    print("For each pillar below, read the raw input + prompt, then write:")
    print("  1) authored markdown under .audit/docs/ per the prompt's doc outline")
    print("  2) a findings JSON file at .audit/findings/<pillar>.json matching audit-schema.json")
    print("  3) a complete fresh doc set for every pillar that ran — render now fails if required docs are missing")
    print()
    for name in pillars:
        raw = raw_dir / f"{name}.json"
        prompt = prompts_dir / f"{name}.md"
        print(f"  • {name}")
        print(f"      raw:     {raw}")
        print(f"      prompt:  {prompt}")
        print(f"      findings:{findings_dir}/{name}.json")
    print()
    return 0


def cmd_render(args: argparse.Namespace) -> int:
    from render import render  # noqa: E402

    output = Path(args.audit).resolve()
    docs_dir = Path(args.docs_dir).resolve()

    audit_json_path = render.render(
        audit_root=output,
        docs_dir=docs_dir,
        skill_root=SKILL_ROOT,
    )
    print(f"\nRender complete.")
    print(f"  audit.json:  {audit_json_path}")
    print(f"  audit.html:  {audit_json_path.parent / 'audit.html'}")
    print(f"  docs:        {docs_dir}")
    return 0


def cmd_diff(args: argparse.Namespace) -> int:
    from diff import diff  # noqa: E402
    import shutil as _sh

    current = Path(args.current).resolve()
    baseline = Path(args.baseline).resolve() if args.baseline else None
    if baseline is None:
        # Auto-detect: look for a prior audit.json next to the docs dir
        guess = current.parent.parent / "docs" / "audit.json"
        if guess.exists():
            baseline = guess

    if baseline is None or not baseline.exists():
        print("First audit — no baseline found. Skipping diff.")
    else:
        out_path = Path(args.output).resolve() if args.output else current.parent / "audit-diff.md"
        diff.diff(current=current, baseline=baseline, output=out_path)
        print(f"\nDiff complete: {out_path}")

    # Promote current audit.json to docs/audit.json so the NEXT run can
    # auto-detect this one as the baseline.
    docs_dir_guess = current.parent.parent / "docs"
    if docs_dir_guess.exists() or args.baseline is None:
        target = docs_dir_guess / "audit.json"
        target.parent.mkdir(parents=True, exist_ok=True)
        _sh.copy(current, target)
        print(f"Promoted current audit.json → {target}")

    return 0


def cmd_all(args: argparse.Namespace) -> int:
    rc = cmd_collect(args)
    if rc != 0:
        return rc

    rc = cmd_analyze(args)
    if rc != 0:
        return rc

    print("\n>>> ANALYZE phase is manual.")
    print(">>> Complete the steps above, then press Enter to continue to RENDER <<<")
    try:
        input()
    except EOFError:
        eprint("No interactive stdin — skipping render/diff. Run them explicitly when ready.")
        return 0

    args.audit = args.output
    rc = cmd_render(args)
    if rc != 0:
        return rc

    args.current = str(Path(args.output) / "audit.json")
    return cmd_diff(args)


# ---------- helpers ----------

def _resolve_pillars(requested: str | None, no_ux: bool) -> tuple[str, ...]:
    if requested:
        pillars = tuple(p.strip() for p in requested.split(",") if p.strip())
    else:
        pillars = ALL_PILLARS
    if no_ux:
        pillars = tuple(p for p in pillars if p != "ux")
    unknown = [p for p in pillars if p not in ALL_PILLARS]
    if unknown:
        eprint(f"ERROR: unknown pillars: {unknown}. Allowed: {ALL_PILLARS}")
        sys.exit(2)
    return pillars


def _skill_version() -> str:
    version_file = SKILL_ROOT / "VERSION"
    if version_file.exists():
        return version_file.read_text().strip()
    return "dev"


def _load_app_override(workflows_path: str) -> dict:
    try:
        import yaml
    except ImportError:
        return {}
    try:
        with Path(workflows_path).open("r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}
    except OSError:
        return {}
    app = data.get("app") or {}
    return {
        "name": app.get("name", ""),
        "bundle_id": app.get("bundle_id", ""),
    }


def _reset_audit_output(*, output: Path, repo_root: Path) -> None:
    """Ensure every collect run starts from a clean audit root.

    The audit output directory is treated as disposable generated state.
    This prevents stale docs, screenshots, thumbnails, or findings from a
    prior run from satisfying the render phase by accident.
    """
    output = output.resolve()
    protected = {repo_root.resolve(), repo_root.parent.resolve(), Path.home().resolve(), Path("/")}
    if output in protected:
        raise RuntimeError(
            f"refusing to reset unsafe audit output path: {output}. "
            "Use a dedicated audit directory such as `<repo>/.audit` or `<repo>/.audit-runs/<stamp>`."
        )
    if output.exists():
        shutil.rmtree(output)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="ios-audit", description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    # common arg sets
    def add_repo(p: argparse.ArgumentParser) -> None:
        p.add_argument("--repo", required=True, help="Path to iOS repo root")
        p.add_argument("--output", required=True, help="Audit output dir (e.g. .audit/)")
        p.add_argument("--pillars", help=f"Comma list (default all): {','.join(ALL_PILLARS)}")
        p.add_argument("--no-ux", action="store_true", help="Skip UX pillar (no simulator needed)")

    c = sub.add_parser("collect", help="Run collectors")
    add_repo(c)
    c.add_argument("--workflows", help="Path to UX flow YAML (required unless --no-ux)")
    c.add_argument("--udid", help="Target simulator UDID (default: booted)")
    c.add_argument("--sim-skill-dir", help="Override ios-simulator-skill location")
    c.add_argument("--keep-going", action="store_true", help="Don't abort on per-collector failure")
    c.set_defaults(func=cmd_collect)

    a = sub.add_parser("analyze", help="Print ANALYZE instructions for the invoking agent")
    a.add_argument("--output", required=True, help="Audit output dir (e.g. .audit/)")
    a.add_argument("--pillars", help="Comma list (default all)")
    a.add_argument("--no-ux", action="store_true")
    a.set_defaults(func=cmd_analyze)

    r = sub.add_parser("render", help="Build audit.json + audit.html + docs/")
    r.add_argument("--audit", required=True, help="Audit output dir containing raw/ docs/ findings/")
    r.add_argument("--docs-dir", required=True, help="Target docs directory to replace")
    r.set_defaults(func=cmd_render)

    d = sub.add_parser("diff", help="Compare current audit.json to baseline")
    d.add_argument("--current", required=True, help="Path to current audit.json")
    d.add_argument("--baseline", help="Path to previous audit.json (auto-detected if omitted)")
    d.add_argument("--output", help="Output path for audit-diff.md")
    d.set_defaults(func=cmd_diff)

    x = sub.add_parser("all", help="Run collect → analyze prompt → render → diff")
    add_repo(x)
    x.add_argument("--workflows")
    x.add_argument("--udid")
    x.add_argument("--sim-skill-dir")
    x.add_argument("--docs-dir", required=True)
    x.add_argument("--baseline")
    x.add_argument("--keep-going", action="store_true")
    x.set_defaults(func=cmd_all)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
