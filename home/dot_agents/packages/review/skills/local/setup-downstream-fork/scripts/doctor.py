#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""Executor for the setup-downstream-fork skill, Mode 2 (doctor).

Audits an existing downstream fork for drift against the layout this skill
generates, reports per-check status (``ok | warn | error``), and optionally
applies narrow, targeted fixes.

Stdlib-only. Targets Python 3.11+.

Architecture reference: ``docs/adr/0001-downstream-fork-architecture.md``.
The doctor never converts a non-``.fork/`` layout to this one — SKILL.md
flags that as an explicit human decision.
"""
from __future__ import annotations

import argparse
import dataclasses
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

# Shared CI-gates helpers live next to this script. Import lazily inside the
# check functions where needed so the doctor still imports on systems that
# haven't set up the LLM SDKs yet.
_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))


STATUS_OK = "ok"
STATUS_WARN = "warn"
STATUS_ERROR = "error"
STATUS_SKIP = "skip"

PREFIXES = {
    STATUS_OK: "✓",       # ✓
    STATUS_WARN: "⚠",     # ⚠
    STATUS_ERROR: "✗",    # ✗
    STATUS_SKIP: "-",
}

REQUIRED_FORK_SUBDIRS = (
    "tools",
    "skills",
    "references",
    "patches",
    "snapshots",
)

REQUIRED_WORKFLOWS = (
    "fork-upstream-sync.yml",
    "fork-build-release.yml",
    "fork-conflict-resolve.yml",
)

REQUIRED_SNAPSHOT_FIELDS = (
    "upstream_sha",
    "pre_sync_main_sha",
    "merged_commit_sha",
    "ci_result",
    "llm_resolutions",
)


# --------------------------------------------------------------------------- #
# Data                                                                        #
# --------------------------------------------------------------------------- #


@dataclasses.dataclass
class CheckResult:
    status: str
    detail: str


@dataclasses.dataclass
class Check:
    id: str
    description: str
    check_fn: Callable[[Path], CheckResult]
    fix_fn: Callable[[Path], CheckResult] | None = None
    severity_on_fail: str = STATUS_WARN  # mapped from "fixable"
    severity_on_error: str = STATUS_ERROR  # mapped from "broken"


# --------------------------------------------------------------------------- #
# Subprocess helper                                                           #
# --------------------------------------------------------------------------- #


def _git(
    args: list[str], *, cwd: Path, check: bool = False
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=str(cwd),
        capture_output=True,
        text=True,
        check=check,
    )


# --------------------------------------------------------------------------- #
# Checks                                                                      #
# --------------------------------------------------------------------------- #


def _branch_exists(repo: Path, name: str) -> bool:
    proc = _git(["show-ref", "--verify", "--quiet", f"refs/heads/{name}"], cwd=repo)
    return proc.returncode == 0


def check_branches_upstream(repo: Path) -> CheckResult:
    if _branch_exists(repo, "upstream"):
        return CheckResult(STATUS_OK, "upstream branch present")
    return CheckResult(STATUS_ERROR, "upstream branch missing — this repo isn't shaped like a fork")


def check_branches_main(repo: Path) -> CheckResult:
    if not _branch_exists(repo, "main"):
        return CheckResult(STATUS_ERROR, "main branch missing")
    if not _branch_exists(repo, "upstream"):
        return CheckResult(STATUS_WARN, "main exists but upstream is missing; can't verify ancestry")
    proc = _git(["merge-base", "--is-ancestor", "upstream", "main"], cwd=repo)
    if proc.returncode == 0:
        return CheckResult(STATUS_OK, "main descends from upstream")
    return CheckResult(
        STATUS_ERROR,
        "main does not descend from upstream — patches may have been applied off a different base",
    )


def check_fork_dir(repo: Path) -> CheckResult:
    fork = repo / ".fork"
    if not fork.is_dir():
        return CheckResult(
            STATUS_ERROR,
            ".fork/ is missing — this fork uses a different layout; doctor will NOT auto-convert",
        )
    missing = [d for d in REQUIRED_FORK_SUBDIRS if not (fork / d).is_dir()]
    if missing:
        return CheckResult(STATUS_WARN, f"missing .fork/ subdirs: {', '.join(missing)}")
    if not (fork / "AGENTS.md").is_file():
        return CheckResult(STATUS_WARN, ".fork/AGENTS.md missing")
    return CheckResult(STATUS_OK, ".fork/ layout looks right")


def check_root_agents_md(repo: Path) -> CheckResult:
    agents = repo / "AGENTS.md"
    if not agents.exists():
        return CheckResult(STATUS_WARN, "root AGENTS.md missing")
    if agents.is_symlink():
        return CheckResult(STATUS_WARN, "root AGENTS.md is a symlink; expected a small pointer file")
    try:
        text = agents.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return CheckResult(STATUS_ERROR, "root AGENTS.md is not UTF-8")

    lines = text.splitlines()
    points_to_fork = ".fork/AGENTS.md" in text or ".fork/agents.md" in text.lower()
    if len(lines) > 50 and not points_to_fork:
        return CheckResult(
            STATUS_WARN,
            "root AGENTS.md looks like upstream's original, not a pointer to .fork/AGENTS.md",
        )
    if not points_to_fork:
        return CheckResult(
            STATUS_WARN,
            "root AGENTS.md does not reference .fork/AGENTS.md; it should be a short pointer",
        )
    if len(lines) > 80:
        return CheckResult(STATUS_WARN, "root AGENTS.md is unexpectedly long for a pointer file")
    return CheckResult(STATUS_OK, "root AGENTS.md is a pointer to .fork/AGENTS.md")


def check_root_claude_md(repo: Path) -> CheckResult:
    """Root CLAUDE.md must carry the fork-notice header (prepended) or be absent.

    We no longer symlink CLAUDE.md → AGENTS.md; since upstream may ship its own
    CLAUDE.md, we prepend a fork-notice instead. Pass if the file exists and
    begins with the fork-notice marker; warn otherwise.
    """
    claude = repo / "CLAUDE.md"
    if not claude.exists() and not claude.is_symlink():
        return CheckResult(STATUS_WARN, "CLAUDE.md missing")
    # Read through symlinks; a legacy symlink-to-AGENTS.md fork is still valid.
    try:
        text = claude.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        return CheckResult(STATUS_ERROR, f"cannot read CLAUDE.md: {exc}")
    if "<!-- fork-notice:begin" in text:
        return CheckResult(STATUS_OK, "CLAUDE.md has fork-notice header")
    if claude.is_symlink() and os.readlink(claude) == "AGENTS.md":
        return CheckResult(STATUS_OK, "CLAUDE.md symlinks to AGENTS.md (legacy)")
    return CheckResult(STATUS_WARN, "CLAUDE.md present but missing fork-notice header")


def _symlink_ok(link: Path, expected_target: str) -> tuple[bool, str]:
    if not link.exists() and not link.is_symlink():
        return False, "missing"
    if not link.is_symlink():
        return False, "present but not a symlink"
    actual = os.readlink(link)
    if actual != expected_target:
        return False, f"points to {actual!r}, expected {expected_target!r}"
    return True, "ok"


def check_skill_discovery_symlinks(repo: Path) -> CheckResult:
    problems: list[str] = []
    for rel, target in (
        (".claude/skills", "../.fork/skills"),
        (".agents/skills", "../.fork/skills"),
    ):
        ok, detail = _symlink_ok(repo / rel, target)
        if not ok:
            problems.append(f"{rel}: {detail}")
    if problems:
        return CheckResult(STATUS_WARN, "; ".join(problems))
    return CheckResult(STATUS_OK, ".claude/skills and .agents/skills both point at .fork/skills")


def _parse_yaml_shallow(text: str) -> bool:
    """Shallow YAML sanity: indentation is consistent, no tab characters,
    and at least one top-level key looks present. We avoid a PyYAML dep."""

    if "\t" in text:
        return False
    top_level = 0
    for line in text.splitlines():
        if not line or line.lstrip().startswith("#"):
            continue
        if line[0].isalpha() and ":" in line:
            top_level += 1
    return top_level > 0


def check_workflows_present(repo: Path) -> CheckResult:
    wf_dir = repo / ".github" / "workflows"
    if not wf_dir.is_dir():
        return CheckResult(STATUS_ERROR, ".github/workflows/ missing")
    missing: list[str] = []
    invalid: list[str] = []
    for name in REQUIRED_WORKFLOWS:
        path = wf_dir / name
        if not path.is_file():
            missing.append(name)
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            invalid.append(name)
            continue
        if not _parse_yaml_shallow(text):
            invalid.append(name)
    parts: list[str] = []
    if missing:
        parts.append(f"missing: {', '.join(missing)}")
    if invalid:
        parts.append(f"invalid YAML: {', '.join(invalid)}")
    if parts:
        return CheckResult(STATUS_ERROR, "; ".join(parts))
    return CheckResult(STATUS_OK, "all three fork-*.yml workflows present and shallowly valid")


def check_mergify_yml(repo: Path) -> CheckResult:
    path = repo / ".mergify.yml"
    if not path.is_file():
        return CheckResult(STATUS_WARN, ".mergify.yml missing")
    text = path.read_text(encoding="utf-8")
    if "fork-sync" not in text:
        return CheckResult(STATUS_WARN, ".mergify.yml present but 'fork-sync' queue rule missing")
    return CheckResult(STATUS_OK, ".mergify.yml has the fork-sync queue rule")


def _format_patch_files(repo: Path) -> list[str]:
    """Return the sorted filenames ``git format-patch`` would produce for
    ``upstream..HEAD --grep='Fork-Patch:'``.

    We run the command with ``--stdout`` to count patches without writing
    files to disk, then synthesize the expected filenames from the commit
    subjects. If that's too fragile for a given repo, callers fall back to
    "regenerate via export-patches.sh and compare counts."
    """

    # Simpler and more stable: just list commit subjects.
    proc = _git(
        [
            "log",
            "upstream..HEAD",
            "--grep=Fork-Patch:",
            "--format=%H",
        ],
        cwd=repo,
    )
    if proc.returncode != 0:
        return []
    return [line.strip() for line in proc.stdout.splitlines() if line.strip()]


def check_patches_synced(repo: Path) -> CheckResult:
    patches_dir = repo / ".fork" / "patches"
    if not patches_dir.is_dir():
        return CheckResult(STATUS_WARN, ".fork/patches/ missing")

    patch_files = sorted(p for p in patches_dir.glob("*.patch"))
    commits = _format_patch_files(repo)
    if not commits and not patch_files:
        return CheckResult(STATUS_OK, "no fork patches and no patch files — in sync")

    if len(patch_files) != len(commits):
        return CheckResult(
            STATUS_WARN,
            f".fork/patches/ has {len(patch_files)} files but {len(commits)} Fork-Patch commits — regenerate",
        )
    return CheckResult(
        STATUS_OK,
        f"patch count matches Fork-Patch commits ({len(commits)})",
    )


def check_recent_sync(repo: Path) -> CheckResult:
    proc = _git(
        ["for-each-ref", "--sort=-creatordate", "--format=%(refname:short) %(creatordate:iso-strict)", "refs/tags/upstream-sync/*"],
        cwd=repo,
    )
    if proc.returncode != 0 or not proc.stdout.strip():
        return CheckResult(STATUS_WARN, "no upstream-sync/* tags found")
    top = proc.stdout.strip().splitlines()[0]
    parts = top.split(" ", 1)
    if len(parts) != 2:
        return CheckResult(STATUS_WARN, f"could not parse tag date: {top!r}")
    tag, iso = parts
    try:
        when = datetime.fromisoformat(iso)
    except ValueError:
        return CheckResult(STATUS_WARN, f"could not parse tag ISO date: {iso!r}")
    age = datetime.now(timezone.utc) - when.astimezone(timezone.utc)
    if age.days > 14:
        return CheckResult(
            STATUS_WARN,
            f"most recent sync tag {tag} is {age.days}d old (>14d threshold)",
        )
    return CheckResult(STATUS_OK, f"most recent sync tag {tag} is {age.days}d old")


def check_snapshots_valid(repo: Path) -> CheckResult:
    snaps_dir = repo / ".fork" / "snapshots"
    if not snaps_dir.is_dir():
        return CheckResult(STATUS_WARN, ".fork/snapshots/ missing")
    problems: list[str] = []
    count = 0
    for entry in snaps_dir.glob("*.json"):
        count += 1
        try:
            payload = json.loads(entry.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            problems.append(f"{entry.name}: parse error ({exc})")
            continue
        missing = [f for f in REQUIRED_SNAPSHOT_FIELDS if f not in payload]
        if missing:
            problems.append(f"{entry.name}: missing fields {', '.join(missing)}")
    if problems:
        return CheckResult(STATUS_WARN, "; ".join(problems))
    if count == 0:
        return CheckResult(STATUS_WARN, "no snapshot files yet (fork may be brand new)")
    return CheckResult(STATUS_OK, f"{count} snapshot file(s) validated")


def check_release_tags(repo: Path) -> CheckResult:
    proc = _git(["tag", "-l", "sync/*-merged"], cwd=repo)
    tags = [t for t in proc.stdout.splitlines() if t.strip()]
    if not tags:
        return CheckResult(
            STATUS_WARN,
            "no sync/*-merged tags yet — first sync may not have completed",
        )
    return CheckResult(STATUS_OK, f"{len(tags)} sync/*-merged tag(s) present")


def check_llm_cache_gitignored(repo: Path) -> CheckResult:
    gitignore = repo / ".gitignore"
    if not gitignore.is_file():
        return CheckResult(STATUS_WARN, ".gitignore missing")
    text = gitignore.read_text(encoding="utf-8")
    if ".fork/.llm-cache" in text:
        return CheckResult(STATUS_OK, ".fork/.llm-cache/ is gitignored")
    return CheckResult(STATUS_WARN, ".fork/.llm-cache/ is not gitignored")


def check_ci_gates_file_valid(repo: Path) -> CheckResult:
    """``.fork/ci-gates.json`` exists, parses, and has a non-empty ``required_checks`` list."""

    path = repo / ".fork" / "ci-gates.json"
    if not path.is_file():
        return CheckResult(
            STATUS_WARN,
            ".fork/ci-gates.json missing — run `doctor.py --update-ci-gates` to generate it",
        )
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return CheckResult(STATUS_ERROR, f"ci-gates.json parse error: {exc}")
    if not isinstance(payload, dict):
        return CheckResult(STATUS_ERROR, "ci-gates.json is not a JSON object")
    required = payload.get("required_checks")
    if not isinstance(required, list) or not required:
        return CheckResult(STATUS_ERROR, "ci-gates.json missing a non-empty required_checks list")
    if not all(isinstance(x, str) and x for x in required):
        return CheckResult(STATUS_ERROR, "ci-gates.json required_checks must be non-empty strings")
    return CheckResult(STATUS_OK, f"ci-gates.json has {len(required)} required check(s)")


def _repo_full_name(repo: Path) -> str | None:
    """Best-effort ``owner/name`` for the fork via ``gh repo view --json nameWithOwner``."""

    proc = subprocess.run(
        ["gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"],
        cwd=str(repo),
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        return None
    val = proc.stdout.strip()
    return val or None


def check_fork_sync_token_secret(repo: Path) -> CheckResult:
    """``FORK_SYNC_TOKEN`` is set as a repo Actions secret on the fork."""

    full = _repo_full_name(repo)
    if not full:
        return CheckResult(
            STATUS_WARN,
            "could not determine fork repo via gh — skipping FORK_SYNC_TOKEN probe",
        )
    proc = subprocess.run(
        [
            "gh",
            "api",
            f"repos/{full}/actions/secrets",
            "--jq",
            ".secrets[].name",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        return CheckResult(
            STATUS_WARN,
            f"gh api failed probing secrets for {full}: {proc.stderr.strip() or proc.stdout.strip()}",
        )
    names = {line.strip() for line in proc.stdout.splitlines() if line.strip()}
    if "FORK_SYNC_TOKEN" in names:
        return CheckResult(STATUS_OK, "FORK_SYNC_TOKEN secret is set on the fork")
    return CheckResult(
        STATUS_WARN,
        "FORK_SYNC_TOKEN not found among Actions secrets — sync workflow may lack permissions",
    )


def check_mergify_app_installed(repo: Path) -> CheckResult:
    """Mergify GitHub App is installed on the fork's owning namespace."""

    full = _repo_full_name(repo)
    if not full or "/" not in full:
        return CheckResult(
            STATUS_WARN,
            "could not determine fork owner via gh — skipping Mergify install probe",
        )
    owner = full.split("/", 1)[0]
    proc = subprocess.run(
        [
            "gh",
            "api",
            f"users/{owner}/installation",
            "-H",
            "Accept: application/vnd.github+json",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        # 404 shows up as a non-zero return. Distinguish from "transient gh error".
        if "HTTP 404" in (proc.stderr or "") or "Not Found" in (proc.stderr or ""):
            return CheckResult(
                STATUS_WARN,
                f"Mergify app not installed on {owner} (install at https://github.com/apps/mergify)",
            )
        return CheckResult(
            STATUS_WARN,
            f"could not probe Mergify install on {owner}: {proc.stderr.strip()}",
        )
    return CheckResult(STATUS_OK, f"a GitHub App installation is present on {owner}")


def check_architecture_mismatch(repo: Path) -> CheckResult:
    """Flag hard mismatches the doctor cannot auto-fix.

    If both ``.fork/`` and one of the expected branches are missing at the
    same time, this isn't a forkish repo or it's using a completely
    different layout. The doctor refuses to guess; SKILL.md Step 2 says
    conversion is an explicit human decision.
    """

    fork_dir = (repo / ".fork").is_dir()
    upstream = _branch_exists(repo, "upstream")
    main = _branch_exists(repo, "main")

    if not fork_dir and not upstream:
        return CheckResult(
            STATUS_ERROR,
            "neither .fork/ nor an `upstream` branch exists; this doesn't look like a fork-shaped repo",
        )
    if not fork_dir and (upstream or main):
        return CheckResult(
            STATUS_ERROR,
            "fork-shaped branches exist but .fork/ is missing — likely a different fork layout; refusing to auto-convert",
        )
    return CheckResult(STATUS_OK, "architecture broadly matches this skill's layout")


# --------------------------------------------------------------------------- #
# Fixers                                                                      #
# --------------------------------------------------------------------------- #


def fix_llm_cache_gitignored(repo: Path) -> CheckResult:
    gitignore = repo / ".gitignore"
    lines = gitignore.read_text(encoding="utf-8").splitlines() if gitignore.exists() else []
    if ".fork/.llm-cache/" in lines:
        return CheckResult(STATUS_OK, "already present")
    lines.append(".fork/.llm-cache/")
    gitignore.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
    return CheckResult(STATUS_OK, "appended .fork/.llm-cache/ to .gitignore")


def fix_skill_discovery_symlinks(repo: Path) -> CheckResult:
    fixed: list[str] = []
    for rel, target in (
        (".claude/skills", "../.fork/skills"),
        (".agents/skills", "../.fork/skills"),
    ):
        link = repo / rel
        link.parent.mkdir(parents=True, exist_ok=True)
        if link.is_symlink() or link.exists():
            link.unlink()
        os.symlink(target, link)
        fixed.append(rel)
    return CheckResult(STATUS_OK, f"recreated symlinks: {', '.join(fixed)}")


def fix_root_claude_md(repo: Path) -> CheckResult:
    claude = repo / "CLAUDE.md"
    if claude.is_symlink() or claude.exists():
        claude.unlink()
    os.symlink("AGENTS.md", claude)
    return CheckResult(STATUS_OK, "recreated CLAUDE.md -> AGENTS.md")


def fix_patches_synced(repo: Path) -> CheckResult:
    script = repo / ".fork" / "tools" / "export-patches.sh"
    if not script.is_file():
        return CheckResult(
            STATUS_WARN,
            f"{script.relative_to(repo)} missing; cannot regenerate patches automatically",
        )
    proc = subprocess.run(
        [str(script)],
        cwd=str(repo),
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return CheckResult(
            STATUS_WARN,
            f"export-patches.sh exited {proc.returncode}: {proc.stderr.strip() or proc.stdout.strip()}",
        )
    return CheckResult(STATUS_OK, "re-ran .fork/tools/export-patches.sh")


def _load_current_required_checks(repo: Path) -> list[str] | None:
    """Return the ``required_checks`` list in ``.fork/ci-gates.json`` or ``None`` if absent/invalid."""

    path = repo / ".fork" / "ci-gates.json"
    if not path.is_file():
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    val = payload.get("required_checks") if isinstance(payload, dict) else None
    if not isinstance(val, list):
        return None
    return [str(x) for x in val if isinstance(x, str)]


def _reanalyze_upstream_ci(repo: Path) -> tuple[str, dict[str, Any] | None, str]:
    """Run the shared CI-gates analysis for ``repo``.

    Returns a triple ``(status, payload, detail)``:
      - status is STATUS_OK when we got a valid payload, STATUS_SKIP when the
        LLM provider isn't configured, STATUS_WARN for other soft failures.
      - payload is the ``analyze_workflows`` dict (may be ``None`` on non-ok).
      - detail is a human-readable message.
    """

    try:
        import _ci_gates  # type: ignore
    except ImportError as exc:
        return STATUS_WARN, None, f"_ci_gates module missing: {exc}"

    url = _ci_gates.resolve_upstream_url(repo)
    if not url:
        return (
            STATUS_WARN,
            None,
            "could not resolve upstream URL (no upstream_url in .fork/revision.txt and no `upstream` remote)",
        )

    try:
        workflows = _ci_gates.fetch_upstream_workflows(url)
    except subprocess.CalledProcessError as exc:
        return STATUS_WARN, None, f"failed to fetch upstream workflows from {url}: {exc}"
    except Exception as exc:  # noqa: BLE001
        return STATUS_WARN, None, f"upstream fetch raised: {exc}"

    if not workflows:
        return (
            STATUS_WARN,
            {"required_checks": [], "optional_checks": [], "reasoning": "no workflows"},
            "upstream has no .github/workflows/*.yml files",
        )

    # Pull the API key through the same resolver setup_fork.py uses so
    # 1Password / config-file / env all work here too. Provider selection
    # follows LLM_PROVIDER env (default claude) to match _ci_gates.
    api_key: str | None = None
    try:
        import _secrets  # type: ignore
        resolver = _secrets.build_default_resolver()
        provider = os.environ.get("LLM_PROVIDER", "claude").lower()
        key_name = "openai_api_key" if provider == "openai" else "anthropic_api_key"
        api_key = resolver.resolve(key_name)
    except Exception:  # noqa: BLE001 — resolver issues must not hard-fail doctor
        api_key = None

    try:
        payload = _ci_gates.analyze_workflows(workflows, api_key=api_key)
    except _ci_gates.LLMUnavailable as exc:
        return STATUS_SKIP, None, f"LLM provider not configured: {exc}"
    except ValueError as exc:
        return STATUS_WARN, None, f"LLM response was not usable: {exc}"

    return STATUS_OK, payload, f"analysis returned {len(payload['required_checks'])} required check(s)"


def report_ci_gates_drift(repo: Path) -> tuple[CheckResult, dict[str, Any] | None]:
    """Re-run the upstream CI analysis and report drift vs ``.fork/ci-gates.json``.

    Returns ``(CheckResult, payload)``. ``payload`` is the raw analyze result
    when we were able to run the LLM; callers use it to apply the fix.
    """

    status, payload, detail = _reanalyze_upstream_ci(repo)
    if status == STATUS_SKIP:
        return CheckResult(STATUS_SKIP, f"ci_gates: {detail}"), None
    if status != STATUS_OK or payload is None:
        return CheckResult(status, f"ci_gates: {detail}"), None

    new_required = sorted(set(payload["required_checks"]))
    current = _load_current_required_checks(repo)
    if current is None:
        return (
            CheckResult(
                STATUS_WARN,
                f"ci_gates: no .fork/ci-gates.json yet — LLM suggests {len(new_required)} gates: {new_required}",
            ),
            payload,
        )

    current_sorted = sorted(set(current))
    additions = sorted(set(new_required) - set(current_sorted))
    removals = sorted(set(current_sorted) - set(new_required))
    if not additions and not removals:
        return CheckResult(STATUS_OK, f"ci_gates: up to date ({len(current_sorted)} gates)"), payload
    parts = []
    if additions:
        parts.append(f"add: {additions}")
    if removals:
        parts.append(f"remove: {removals}")
    return (
        CheckResult(STATUS_WARN, f"ci_gates: drift detected ({'; '.join(parts)})"),
        payload,
    )


# --------------------------------------------------------------------------- #
# CI gates: rewrite ci-gates.json + .mergify.yml + branch protection.        #
# --------------------------------------------------------------------------- #


def _rewrite_ci_gates_json(repo: Path, payload: dict[str, Any]) -> None:
    """Persist the analyze-workflows payload to ``.fork/ci-gates.json``."""

    path = repo / ".fork" / "ci-gates.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    out = {
        "required_checks": list(payload.get("required_checks") or []),
        "optional_checks": list(payload.get("optional_checks") or []),
        "reasoning": str(payload.get("reasoning") or ""),
        "updated": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    path.write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")


def _rewrite_mergify_yml(repo: Path, required_checks: list[str]) -> str:
    """Rewrite ``.mergify.yml`` so its check-success list matches ``required_checks``.

    Handles both shapes:
      - Fresh template shape (``# >>> required_check_conditions <<<``
        sentinels): expand them first so the ``default`` queue block
        actually gets populated.
      - Post-expansion shape (real ``check-success=*`` lines): rewrite
        in place via ``render_mergify_yml``.

    Returns a short status string for the report.
    """

    path = repo / ".mergify.yml"
    if not path.is_file():
        return ".mergify.yml missing; skipped"
    try:
        import _ci_gates  # type: ignore
    except ImportError as exc:
        return f"_ci_gates unavailable: {exc}"
    original = path.read_text(encoding="utf-8")

    all_required = list(required_checks)
    for extra in _ci_gates.FORK_SPECIFIC_CHECKS:
        if extra not in all_required:
            all_required.append(extra)

    rewritten = original
    if "# >>> required_check_conditions <<<" in rewritten:
        rewritten = _ci_gates.expand_mergify_sentinels(rewritten, all_required)
    rewritten = _ci_gates.render_mergify_yml(rewritten, required_checks)

    if rewritten == original:
        return ".mergify.yml already in sync"
    path.write_text(rewritten, encoding="utf-8")
    return ".mergify.yml rewritten"


def _update_branch_protection(repo: Path, required_checks: list[str]) -> str:
    """Update only the ``required_status_checks`` contexts on ``main``.

    Uses the narrow ``PATCH .../protection/required_status_checks`` endpoint
    so review, admin, and restriction settings are left untouched. A full
    ``PUT .../protection`` would clobber fields we didn't intend to change.

    ``drift-recheck`` is intentionally excluded from the branch-protection
    contexts list because it only runs on ``sync/*`` PRs; Mergify enforces
    it via its own queue rule instead. This matches setup_fork.py's default.
    """

    full = _repo_full_name(repo)
    if not full:
        return "could not resolve repo via gh; skipped branch-protection update"

    contexts = [c for c in required_checks if c != "drift-recheck"]
    body = {"strict": True, "contexts": contexts}
    proc = subprocess.run(
        [
            "gh",
            "api",
            "-X",
            "PATCH",
            f"repos/{full}/branches/main/protection/required_status_checks",
            "-H",
            "Accept: application/vnd.github+json",
            "--input",
            "-",
        ],
        input=json.dumps(body),
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        return f"gh api failed: {proc.stderr.strip() or proc.stdout.strip()}"
    return f"branch protection required_status_checks updated ({len(contexts)} context(s))"


def fix_ci_gates_file_valid(repo: Path) -> CheckResult:
    """Re-run the LLM analysis and rewrite ``.fork/ci-gates.json``, ``.mergify.yml``, and branch protection."""

    result, payload = report_ci_gates_drift(repo)
    if payload is None:
        # No usable payload — cannot fix, just pass the drift-report status through.
        return result

    required = sorted(set(payload.get("required_checks") or []))
    _rewrite_ci_gates_json(repo, payload)
    merg_msg = _rewrite_mergify_yml(repo, required)
    prot_msg = _update_branch_protection(repo, required)
    detail = f"wrote .fork/ci-gates.json ({len(required)} gates); {merg_msg}; {prot_msg}"
    return CheckResult(STATUS_OK, detail)


def fix_root_agents_md(repo: Path) -> CheckResult:
    """Rewrite a non-pointer root AGENTS.md as a short pointer.

    If the existing root AGENTS.md looks like upstream's original (no
    reference to .fork/AGENTS.md, >50 lines), move it to
    ``.fork/upstream-AGENTS.md`` and replace root AGENTS.md with a small
    pointer block.
    """

    agents = repo / "AGENTS.md"
    fork_dir = repo / ".fork"
    fork_dir.mkdir(exist_ok=True)

    original = agents.read_text(encoding="utf-8") if agents.exists() else ""
    if ".fork/AGENTS.md" in original:
        return CheckResult(STATUS_OK, "already a pointer")

    upstream_copy = fork_dir / "upstream-AGENTS.md"
    if original.strip():
        upstream_copy.write_text(original, encoding="utf-8")

    pointer = (
        "# AGENTS.md (root pointer)\n"
        "\n"
        "This repository is a downstream fork. The full fork contract lives at\n"
        "`.fork/AGENTS.md` — read it before making changes.\n"
        "\n"
        "- Source edits go at the repo root (paths match upstream).\n"
        "- Patches are tracked via `Fork-Patch:` commit trailers.\n"
        "- Playbooks live in `.fork/skills/`.\n"
        "- Upstream's original AGENTS.md (if any) is preserved at "
        "`.fork/upstream-AGENTS.md`.\n"
    )
    agents.write_text(pointer, encoding="utf-8")
    return CheckResult(STATUS_OK, "rewrote root AGENTS.md as a pointer")


# --------------------------------------------------------------------------- #
# Registry                                                                    #
# --------------------------------------------------------------------------- #


CHECKS: list[Check] = [
    Check(
        id="branches_upstream",
        description="`upstream` branch exists",
        check_fn=check_branches_upstream,
    ),
    Check(
        id="branches_main",
        description="`main` branch exists and descends from `upstream`",
        check_fn=check_branches_main,
    ),
    Check(
        id="fork_dir",
        description=".fork/ directory present with required subdirs",
        check_fn=check_fork_dir,
    ),
    Check(
        id="root_agents_md",
        description="root AGENTS.md is a pointer to .fork/AGENTS.md",
        check_fn=check_root_agents_md,
        fix_fn=fix_root_agents_md,
    ),
    Check(
        id="root_claude_md",
        description="CLAUDE.md carries fork-notice header (or legacy symlink)",
        check_fn=check_root_claude_md,
        fix_fn=fix_root_claude_md,
    ),
    Check(
        id="skill_discovery_symlinks",
        description=".claude/skills and .agents/skills -> ../.fork/skills",
        check_fn=check_skill_discovery_symlinks,
        fix_fn=fix_skill_discovery_symlinks,
    ),
    Check(
        id="workflows_present",
        description="all three fork-*.yml workflows are present and parse",
        check_fn=check_workflows_present,
    ),
    Check(
        id="mergify_yml",
        description=".mergify.yml present with fork-sync queue rule",
        check_fn=check_mergify_yml,
    ),
    Check(
        id="patches_synced",
        description=".fork/patches/ matches Fork-Patch: commits",
        check_fn=check_patches_synced,
        fix_fn=fix_patches_synced,
    ),
    Check(
        id="recent_sync",
        description="most recent upstream-sync/* tag is within 14 days",
        check_fn=check_recent_sync,
    ),
    Check(
        id="snapshots_valid",
        description="every .fork/snapshots/*.json parses with required fields",
        check_fn=check_snapshots_valid,
    ),
    Check(
        id="release_tags",
        description="at least one sync/*-merged tag exists",
        check_fn=check_release_tags,
    ),
    Check(
        id="llm_cache_gitignored",
        description=".fork/.llm-cache/ is in .gitignore",
        check_fn=check_llm_cache_gitignored,
        fix_fn=fix_llm_cache_gitignored,
    ),
    Check(
        id="ci_gates_file_valid",
        description=".fork/ci-gates.json exists and has required_checks",
        check_fn=check_ci_gates_file_valid,
        fix_fn=fix_ci_gates_file_valid,
    ),
    Check(
        id="fork_sync_token_secret",
        description="FORK_SYNC_TOKEN Actions secret is set on the fork",
        check_fn=check_fork_sync_token_secret,
    ),
    Check(
        id="mergify_app_installed",
        description="Mergify GitHub App is installed on the fork owner",
        check_fn=check_mergify_app_installed,
    ),
    Check(
        id="architecture_mismatch",
        description="repo layout matches this skill's architecture",
        check_fn=check_architecture_mismatch,
    ),
]


# --------------------------------------------------------------------------- #
# Rendering                                                                   #
# --------------------------------------------------------------------------- #


def _render_row(result: dict[str, Any], id_width: int, desc_width: int) -> str:
    prefix = PREFIXES.get(result["status"], "?")
    id_col = result["id"].ljust(id_width)
    desc_col = result["description"]
    if len(desc_col) > desc_width:
        desc_col = desc_col[: desc_width - 1] + "…"
    desc_col = desc_col.ljust(desc_width)
    return f"  {prefix} {id_col}  {desc_col}  {result['detail']}"


def _print_report(results: list[dict[str, Any]], repo: Path) -> None:
    print(f"Doctor report for: {repo}")
    print("-" * 72)
    id_width = max((len(r["id"]) for r in results), default=0)
    desc_width = 48
    for r in results:
        print(_render_row(r, id_width=id_width, desc_width=desc_width))
    counts = {s: sum(1 for r in results if r["status"] == s) for s in (STATUS_OK, STATUS_WARN, STATUS_ERROR, STATUS_SKIP)}
    print("-" * 72)
    print(
        f"  summary: ok={counts[STATUS_OK]}  warn={counts[STATUS_WARN]}  "
        f"error={counts[STATUS_ERROR]}  skip={counts[STATUS_SKIP]}"
    )


# --------------------------------------------------------------------------- #
# CLI                                                                         #
# --------------------------------------------------------------------------- #


def _run_checks(repo: Path, checks: list[Check]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for c in checks:
        try:
            res = c.check_fn(repo)
        except Exception as exc:  # noqa: BLE001 — want to surface, not crash
            res = CheckResult(STATUS_ERROR, f"check raised: {exc}")
        out.append(
            {
                "id": c.id,
                "description": c.description,
                "status": res.status,
                "detail": res.detail,
                "fixable": c.fix_fn is not None,
            }
        )
    return out


def _run_fixes(
    repo: Path, checks: list[Check], results: list[dict[str, Any]], only_id: str | None
) -> list[dict[str, Any]]:
    by_id = {c.id: c for c in checks}
    fixes: list[dict[str, Any]] = []
    for r in results:
        if only_id and r["id"] != only_id:
            continue
        if r["status"] == STATUS_OK:
            continue
        check = by_id.get(r["id"])
        if check is None or check.fix_fn is None:
            continue
        try:
            outcome = check.fix_fn(repo)
        except Exception as exc:  # noqa: BLE001
            outcome = CheckResult(STATUS_ERROR, f"fix raised: {exc}")
        fixes.append(
            {
                "id": check.id,
                "status": outcome.status,
                "detail": outcome.detail,
            }
        )
    return fixes


def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="doctor.py",
        description=(
            "Audit an existing downstream fork for drift against the layout this "
            "skill generates. Optionally apply narrow fixes. Will NOT convert a "
            "fork using a different architecture — that's an explicit human call."
        ),
    )
    p.add_argument(
        "--path",
        default=".",
        help="Fork repo path to audit (default: current directory).",
    )
    p.add_argument(
        "--fix",
        action="store_true",
        help="Run fixers for every non-ok check that has one.",
    )
    p.add_argument(
        "--fix-item",
        default=None,
        help="Run the fixer for a single check id (e.g. `skill_discovery_symlinks`).",
    )
    p.add_argument(
        "--json",
        action="store_true",
        help="Emit a machine-readable JSON report instead of the human table.",
    )
    p.add_argument(
        "--update-ci-gates",
        action="store_true",
        help=(
            "Re-run the LLM analysis of upstream CI and surface drift. With --fix, "
            "rewrite .fork/ci-gates.json, .mergify.yml, and main branch protection. "
            "Equivalent to `--fix-item ci_gates_file_valid` but also runs the drift "
            "report so a read-only pass surfaces additions/removals."
        ),
    )
    return p


def main() -> int:
    parser = _build_parser()
    args = parser.parse_args()

    repo = Path(args.path).expanduser().resolve()
    if not repo.is_dir():
        print(f"not a directory: {repo}", file=sys.stderr)
        return 2
    if not (repo / ".git").exists():
        print(f"not a git repository: {repo}", file=sys.stderr)
        return 2

    results = _run_checks(repo, CHECKS)

    # Surface the drift report up front when the user asked about CI gates.
    # This runs the LLM re-analysis regardless of --fix so the user sees what
    # *would* change before opting in.
    ci_gates_drift: dict[str, Any] | None = None
    if args.update_ci_gates:
        drift_result, _payload = report_ci_gates_drift(repo)
        ci_gates_drift = {
            "status": drift_result.status,
            "detail": drift_result.detail,
        }

    fixes: list[dict[str, Any]] = []
    # `--update-ci-gates` is a convenience alias that scopes the fix run to the
    # CI-gates check unless the user has already supplied `--fix-item`.
    fix_target = args.fix_item
    if args.update_ci_gates and args.fix and fix_target is None:
        fix_target = "ci_gates_file_valid"

    if args.fix or args.fix_item:
        fixes = _run_fixes(repo, CHECKS, results, only_id=fix_target)
        if fixes:
            # Re-run checks so the report reflects post-fix state.
            results = _run_checks(repo, CHECKS)

    if args.json:
        payload = {
            "path": str(repo),
            "timestamp": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "results": results,
            "fixes_applied": fixes,
        }
        if ci_gates_drift is not None:
            payload["ci_gates_drift"] = ci_gates_drift
        print(json.dumps(payload, indent=2))
    else:
        _print_report(results, repo)
        if ci_gates_drift is not None:
            prefix = PREFIXES.get(ci_gates_drift["status"], "?")
            print("")
            print(f"  {prefix} {ci_gates_drift['detail']}")
        if fixes:
            print("")
            print("Fixes applied:")
            for f in fixes:
                prefix = PREFIXES.get(f["status"], "?")
                print(f"  {prefix} {f['id']}: {f['detail']}")

    # Exit code: 0 if all ok, 1 if any warn, 2 if any error.
    statuses = {r["status"] for r in results}
    if STATUS_ERROR in statuses:
        return 2
    if STATUS_WARN in statuses:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
