#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""Executor for the setup-downstream-fork skill, Mode 1 (greenfield).

Takes an upstream repo and a target fork name, clones upstream, scaffolds
a ``.fork/`` subdir from ``templates/``, creates the GitHub repo, configures
secrets and branch protection, and triggers the first sync workflow.

Stdlib-only. Targets Python 3.11+.

See ``SKILL.md`` for the full flow and ``docs/adr/0001-downstream-fork-architecture.md``
for the architectural rationale.
"""
from __future__ import annotations

import argparse
import dataclasses
import json
import os
import re
import shutil
import string
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urlparse


SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
TEMPLATES_DIR = SKILL_DIR / "templates"

# Shared LLM-CI-gate plumbing lives in ``_ci_gates.py`` so ``doctor.py`` and
# this module stay in lockstep on prompt / parsing / fork-specific gates.
# ``_secrets.py`` is the pluggable secret resolver (env + config file +
# providers). Neither import makes a network call.
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))
import _ci_gates  # noqa: E402
import _secrets  # noqa: E402


# Module-level resolver, populated once at the top of ``main()``. Keeping
# this off ``SetupContext`` avoids accidentally serializing secret
# references into the debug log that ``_write_debug_log`` dumps.
_RESOLVER: _secrets.SecretResolver | None = None


def _resolver() -> _secrets.SecretResolver:
    """Return the module resolver, lazily constructing a default one."""
    global _RESOLVER
    if _RESOLVER is None:
        _RESOLVER = _secrets.build_default_resolver()
    return _RESOLVER


def _resolve_opt(key: str) -> str | None:
    """Return the resolved secret or None. Logs resolver errors at WARN level.

    Used for optional secrets where a miss is not fatal — the caller decides
    whether to continue without the value.
    """
    try:
        return _resolver().resolve(key)
    except _secrets.SecretResolutionError as exc:
        _log(f"secret resolver failed for {key}: {exc}", level="WARN")
        return None

MIN_GIT_VERSION = (2, 39)
MAX_UPSTREAM_SIZE_KB = 2 * 1024 * 1024  # 2GB

REQUIRED_GH_SCOPES = ("repo", "admin:repo_hook", "workflow")

# Files generated at the repo root rather than under .fork/.
ROOT_LEVEL_TEMPLATE_DIRS = {"workflows", "mergify"}


# --------------------------------------------------------------------------- #
# Logging helpers                                                             #
# --------------------------------------------------------------------------- #


def _log(msg: str, *, level: str = "INFO") -> None:
    ts = datetime.now(timezone.utc).strftime("%H:%M:%S")
    print(f"[{ts}] [{level}] {msg}", file=sys.stderr, flush=True)


def _phase(name: str) -> None:
    _log(f"=== phase: {name} ===", level="PHASE")


# --------------------------------------------------------------------------- #
# Subprocess plumbing                                                         #
# --------------------------------------------------------------------------- #


class CommandFailed(RuntimeError):
    """Raised when a subprocess call exits non-zero."""

    def __init__(self, cmd: list[str], returncode: int, stderr: str, stdout: str):
        self.cmd = cmd
        self.returncode = returncode
        self.stderr = stderr
        self.stdout = stdout
        super().__init__(
            f"command failed ({returncode}): {' '.join(cmd)}\nstderr: {stderr.strip()}"
        )


def run(
    cmd: list[str],
    *,
    cwd: Path | None = None,
    check: bool = True,
    dry_run: bool = False,
    input_text: str | None = None,
) -> subprocess.CompletedProcess[str]:
    """Run a subprocess with captured output and explicit failure surfacing."""

    pretty = " ".join(cmd)
    _log(f"$ {pretty}" + (f"  (cwd={cwd})" if cwd else ""))
    if dry_run:
        return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")

    proc = subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        capture_output=True,
        text=True,
        check=False,
        input=input_text,
    )
    if check and proc.returncode != 0:
        raise CommandFailed(cmd, proc.returncode, proc.stderr, proc.stdout)
    return proc


# --------------------------------------------------------------------------- #
# Data                                                                        #
# --------------------------------------------------------------------------- #


@dataclasses.dataclass
class SetupContext:
    """Mutable blob passed through the setup phases.

    Populated progressively — early phases fill in what they resolve,
    later phases read it. Serialized to a JSON log at the end so a
    failed run can be inspected.
    """

    # User inputs
    upstream_raw: str
    fork_name: str
    fork_owner: str | None = None
    local_path: Path | None = None
    upstream_branch_override: str | None = None
    llm_provider: str = "claude"
    llm_model: str | None = None
    visibility: str = "private"
    sync_cron: str = "0 6 * * *"
    build_command_override: str | None = None
    smoke_test_command_override: str | None = None
    language_override: str | None = None
    dry_run: bool = False
    keep_on_fail: bool = False

    # Resolved upstream
    upstream_host: str = "github.com"
    upstream_owner: str | None = None
    upstream_repo: str | None = None
    upstream_url: str | None = None
    upstream_default_branch: str | None = None
    upstream_head_sha: str | None = None
    upstream_size_kb: int | None = None

    # Resolved fork
    fork_owner_resolved: str | None = None
    fork_full_name: str | None = None  # owner/name
    fork_url: str | None = None

    # Detected
    build_command: str | None = None
    smoke_test_command: str | None = None
    language: str | None = None

    # Runtime
    sync_tag: str | None = None
    sync_date: str | None = None
    mergify_installed: bool | None = None
    # Upstream CI checks chosen (by the LLM + user confirmation) as merge gates
    # on the fork's main branch. Empty list = only the fork-specific checks apply.
    required_ci_checks: list[str] = dataclasses.field(default_factory=list)
    # Whether FORK_SYNC_TOKEN was set as a repo secret during configure_gh.
    fork_sync_token_set: bool = False
    phases_completed: list[str] = dataclasses.field(default_factory=list)
    timings: dict[str, float] = dataclasses.field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        out = dataclasses.asdict(self)
        if self.local_path is not None:
            out["local_path"] = str(self.local_path)
        return out


# --------------------------------------------------------------------------- #
# Upstream parsing                                                            #
# --------------------------------------------------------------------------- #


def parse_upstream(raw: str) -> tuple[str, str, str, str]:
    """Return (host, owner, repo, clone_url) for a raw ``owner/repo`` or URL."""

    raw = raw.strip()
    if re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", raw):
        owner, name = raw.split("/", 1)
        name = name.removesuffix(".git")
        return "github.com", owner, name, f"https://github.com/{owner}/{name}.git"

    m = re.fullmatch(r"git@([^:]+):([^/]+)/([^/]+)", raw)
    if m:
        host, owner, name = m.groups()
        name = name.removesuffix(".git")
        return host, owner, name, f"git@{host}:{owner}/{name}.git"

    parsed = urlparse(raw)
    if parsed.scheme in {"http", "https"} and parsed.netloc:
        parts = [p for p in parsed.path.split("/") if p]
        if len(parts) >= 2:
            owner = parts[0]
            name = parts[1].removesuffix(".git")
            return (
                parsed.netloc,
                owner,
                name,
                f"https://{parsed.netloc}/{owner}/{name}.git",
            )

    raise ValueError(f"cannot parse upstream reference: {raw!r}")


# --------------------------------------------------------------------------- #
# Phase 1 — preflight                                                         #
# --------------------------------------------------------------------------- #


def _check_git_version() -> tuple[int, int]:
    proc = run(["git", "--version"], check=True)
    m = re.search(r"(\d+)\.(\d+)", proc.stdout)
    if not m:
        raise RuntimeError(f"could not parse git version: {proc.stdout!r}")
    return int(m.group(1)), int(m.group(2))


def _check_gh_auth() -> list[str]:
    proc = run(["gh", "auth", "status"], check=False)
    if proc.returncode != 0:
        raise RuntimeError(
            "gh is not authenticated (run `gh auth login`):\n" + proc.stderr.strip()
        )

    # gh writes scope info to stdout (modern gh) or stderr (older gh). Check both.
    scope_line = ""
    for stream in (proc.stdout, proc.stderr):
        for line in stream.splitlines():
            if "Token scopes" in line or "token scopes" in line:
                scope_line = line
                break
        if scope_line:
            break
    scopes = re.findall(r"'([^']+)'", scope_line)
    missing = [s for s in REQUIRED_GH_SCOPES if s not in scopes]
    if missing:
        raise RuntimeError(
            f"gh token is missing required scopes: {', '.join(missing)}. "
            f"Re-authenticate with: gh auth refresh -s {','.join(REQUIRED_GH_SCOPES)}"
        )
    return scopes


def _check_upstream_reachable(url: str) -> str:
    """Return upstream HEAD SHA by ``git ls-remote``."""

    proc = run(["git", "ls-remote", url, "HEAD"], check=True)
    line = proc.stdout.strip().splitlines()[0] if proc.stdout.strip() else ""
    if not line:
        raise RuntimeError(f"upstream returned no HEAD: {url}")
    sha = line.split()[0]
    return sha


def _check_upstream_size_kb(host: str, owner: str, repo: str) -> int | None:
    if host != "github.com":
        return None
    proc = run(
        ["gh", "api", f"repos/{owner}/{repo}", "-q", ".size"],
        check=False,
    )
    if proc.returncode != 0:
        _log(f"could not read upstream size via GitHub API: {proc.stderr.strip()}", level="WARN")
        return None
    try:
        return int(proc.stdout.strip())
    except ValueError:
        return None


def _check_fork_name_free(owner: str, name: str) -> bool:
    """Return True if ``owner/name`` does NOT yet exist on GitHub."""

    proc = run(["gh", "repo", "view", f"{owner}/{name}"], check=False)
    return proc.returncode != 0


def _check_workflow_collision(url: str) -> dict[str, str]:
    """Shallow-clone upstream, fail on ``fork-*.yml`` collisions, return workflow contents.

    Returns a mapping ``{filename: file_contents}`` for every ``*.yml``/``*.yaml``
    file under ``.github/workflows/`` in upstream. Callers use this to drive
    downstream CI analysis without cloning twice. An empty dict means upstream
    ships no workflows (or no workflows dir).
    """

    workflows: dict[str, str] = {}
    with tempfile.TemporaryDirectory(prefix="fork-preflight-") as tmp:
        tmp_path = Path(tmp)
        run(
            [
                "git",
                "clone",
                "--depth=1",
                "--filter=blob:none",
                "--no-checkout",
                url,
                str(tmp_path / "probe"),
            ],
            check=True,
        )
        probe = tmp_path / "probe"
        # Sparse-checkout .github/workflows only.
        run(
            ["git", "sparse-checkout", "init", "--cone"],
            cwd=probe,
            check=True,
        )
        run(
            ["git", "sparse-checkout", "set", ".github/workflows"],
            cwd=probe,
            check=False,
        )
        run(["git", "checkout"], cwd=probe, check=False)

        workflows_dir = probe / ".github" / "workflows"
        if not workflows_dir.exists():
            return workflows
        for entry in sorted(workflows_dir.iterdir()):
            if not entry.is_file():
                continue
            if entry.name.startswith("fork-"):
                raise RuntimeError(
                    f"upstream ships a workflow named {entry.name!r}, which would "
                    f"collide with our fork-*.yml prefix. Refusing to proceed."
                )
            if entry.suffix.lower() in {".yml", ".yaml"}:
                try:
                    workflows[entry.name] = entry.read_text(encoding="utf-8")
                except (OSError, UnicodeDecodeError) as exc:
                    _log(f"could not read {entry.name}: {exc}", level="WARN")
    return workflows


# Fork-specific gates we always require on top of whatever upstream gates we inherit.
# Fork-specific gates and the CI-auditor LLM plumbing live in _ci_gates.py so
# that doctor.py can run the same analysis for drift detection.
FORK_SPECIFIC_CHECKS = _ci_gates.FORK_SPECIFIC_CHECKS


def _prompt_confirm_ci_picks(
    picks: list[str], reasoning: str, optional: list[str]
) -> list[str]:
    """Show the LLM's picks and let the user confirm, edit, or abort.

    Returns the accepted list. Non-interactive environments (no tty) auto-accept.
    """

    print("", file=sys.stderr)
    print("  LLM-proposed required upstream CI checks:", file=sys.stderr)
    for name in picks:
        print(f"    - {name}", file=sys.stderr)
    if optional:
        print("  Optional (informational only):", file=sys.stderr)
        for name in optional:
            print(f"    - {name}", file=sys.stderr)
    print(f"  Reasoning: {reasoning}", file=sys.stderr)
    print(
        "  [enter]=accept  edit=open $EDITOR  no=abort",
        file=sys.stderr,
    )

    if not sys.stdin.isatty():
        _log("non-interactive stdin; auto-accepting LLM picks", level="INFO")
        return picks

    try:
        answer = input("> ").strip().lower()
    except EOFError:
        return picks

    if answer in {"", "y", "yes", "accept"}:
        return picks
    if answer in {"n", "no", "abort"}:
        raise RuntimeError("user aborted at CI-check confirmation")
    if answer == "edit":
        editor = os.environ.get("EDITOR", "vi")
        with tempfile.NamedTemporaryFile(
            prefix="fork-ci-checks-", suffix=".txt", mode="w", delete=False
        ) as fh:
            fh.write("# one check name per line. Lines starting with # are ignored.\n")
            fh.write("\n".join(picks) + "\n")
            tmpname = fh.name
        subprocess.call([editor, tmpname])
        edited = Path(tmpname).read_text(encoding="utf-8").splitlines()
        Path(tmpname).unlink(missing_ok=True)
        out = [ln.strip() for ln in edited if ln.strip() and not ln.lstrip().startswith("#")]
        if not out:
            raise RuntimeError("edited CI-check list was empty; aborting")
        return out

    _log(f"unrecognized answer {answer!r}; accepting picks as-is", level="WARN")
    return picks


def _analyze_upstream_ci(
    workflows: dict[str, str], ctx: SetupContext
) -> list[str]:
    """Ask the configured LLM which upstream job names should gate fork merges.

    Delegates the fetch/prompt/parse plumbing to ``_ci_gates.analyze_workflows``.
    This wrapper adds the interactive confirmation step (not part of the
    shared module because ``doctor.py`` runs non-interactively) and the
    ``ctx.dry_run`` short-circuit. On any hard error (no SDK, no key,
    malformed response), logs a warning and returns ``[]`` so the caller
    can fall back to the fork-specific-only check set.
    """

    if not workflows:
        _log("upstream has no detectable workflows; skipping CI audit", level="INFO")
        return []

    if ctx.dry_run:
        _log("[dry-run] skipping LLM-driven upstream CI audit", level="INFO")
        return []

    provider = os.environ.get("LLM_PROVIDER", ctx.llm_provider).lower()

    key_name = "openai_api_key" if provider == "openai" else "anthropic_api_key"
    try:
        api_key = _resolver().resolve(key_name)
    except _secrets.SecretResolutionError as exc:
        _log(f"secret resolver failed for {key_name}: {exc}", level="WARN")
        api_key = None

    try:
        payload = _ci_gates.analyze_workflows(
            workflows, provider=provider, model=ctx.llm_model, api_key=api_key
        )
    except _ci_gates.LLMUnavailable as exc:
        _log(f"CI audit LLM call failed: {exc}", level="WARN")
        return []
    except ValueError as exc:
        _log(f"CI audit response was unusable: {exc}", level="WARN")
        return []

    required = payload["required_checks"]
    if not required:
        _log("CI audit returned an empty required_checks list", level="WARN")
        return []

    optional = payload.get("optional_checks") or []
    reasoning = payload.get("reasoning") or ""
    accepted = _prompt_confirm_ci_picks(
        list(required), str(reasoning), [o for o in optional if isinstance(o, str)]
    )
    return accepted


def _check_mergify_installed(owner: str) -> bool | None:
    """Best-effort probe for the Mergify GitHub App on the target org/user.

    Returns True/False if we could tell, None if the probe was inconclusive.
    The caller treats None and False the same (warn, don't block).
    """

    proc = run(
        [
            "gh",
            "api",
            f"users/{owner}/installation",
            "-H",
            "Accept: application/vnd.github+json",
        ],
        check=False,
    )
    if proc.returncode != 0:
        return None
    try:
        payload = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError:
        return None
    account = payload.get("account") or {}
    # We can't enumerate apps this way; just report that an installation exists.
    return bool(account)


def preflight(args: argparse.Namespace) -> SetupContext:
    """Validate environment and resolve the SetupContext.

    Every check here is read-only — no state on disk or on GitHub changes.
    """

    _phase("preflight")
    t0 = time.monotonic()

    # Parse upstream.
    host, u_owner, u_repo, u_url = parse_upstream(args.upstream)

    # Fork owner defaults to the authenticated gh user.
    fork_owner = args.fork_owner
    if not fork_owner:
        proc = run(["gh", "api", "user", "-q", ".login"], check=True)
        fork_owner = proc.stdout.strip()
        if not fork_owner:
            raise RuntimeError("could not determine authenticated gh user")

    fork_full = f"{fork_owner}/{args.fork_name}"

    # Local path defaults to $GHPATH/<fork-owner>/<fork-name> if GHPATH is set,
    # else ~/code/github.com/<fork-owner>/<fork-name>.
    if args.local_path:
        local_path = Path(args.local_path).expanduser().resolve()
    else:
        base = Path(
            os.environ.get("GHPATH", str(Path.home() / "code" / "github.com"))
        ).expanduser()
        local_path = (base / fork_owner / args.fork_name).resolve()

    ctx = SetupContext(
        upstream_raw=args.upstream,
        fork_name=args.fork_name,
        fork_owner=fork_owner,
        local_path=local_path,
        upstream_branch_override=args.upstream_branch,
        llm_provider=args.llm_provider,
        llm_model=args.llm_model,
        visibility=args.visibility,
        sync_cron=args.sync_cron,
        build_command_override=args.build_command,
        smoke_test_command_override=args.smoke_test_command,
        language_override=args.language,
        dry_run=args.dry_run,
        keep_on_fail=args.keep_on_fail,
        upstream_host=host,
        upstream_owner=u_owner,
        upstream_repo=u_repo,
        upstream_url=u_url,
        fork_owner_resolved=fork_owner,
        fork_full_name=fork_full,
    )

    # gh auth + scopes
    _check_gh_auth()

    # git version
    maj, min_ = _check_git_version()
    if (maj, min_) < MIN_GIT_VERSION:
        raise RuntimeError(
            f"git {MIN_GIT_VERSION[0]}.{MIN_GIT_VERSION[1]}+ required, found {maj}.{min_}"
        )

    # Upstream reachable.
    ctx.upstream_head_sha = _check_upstream_reachable(u_url)

    # Local path must not exist.
    if ctx.local_path and ctx.local_path.exists():
        raise RuntimeError(f"target local path already exists: {ctx.local_path}")

    # Fork name must be free on GitHub.
    if not _check_fork_name_free(fork_owner, args.fork_name):
        raise RuntimeError(
            f"GitHub repo {fork_full} already exists. Pick a new fork name "
            f"or delete the existing repo first."
        )

    # Workflow name collision. The same shallow clone gives us back the full
    # workflow file contents so we can audit upstream CI without cloning twice.
    upstream_workflows = _check_workflow_collision(u_url)

    # Phase: analyze_upstream_ci — LLM picks which upstream checks to require.
    # RuntimeError from here (e.g. user abort, empty edit) propagates up so the
    # caller fails fast before any side effects are committed.
    _phase("analyze_upstream_ci")
    ctx.required_ci_checks = _analyze_upstream_ci(upstream_workflows, ctx)
    if ctx.required_ci_checks:
        _log(
            f"upstream CI gates to require: {', '.join(ctx.required_ci_checks)}",
            level="INFO",
        )
    elif upstream_workflows and not getattr(args, "allow_empty_ci_gates", False):
        # Fail closed: upstream ships workflows but we could not derive a
        # gate list (missing SDK/key, malformed model output, ...). Generating
        # a fork here would wire auto-merge on only the fork-specific
        # bookkeeping checks, silently dropping every upstream build/test
        # signal. Force an explicit operator opt-in.
        raise RuntimeError(
            "upstream has CI workflows but the gate list is empty — refusing to "
            "generate a fork that would auto-merge without upstream signal. Fix the "
            "LLM configuration (ANTHROPIC_API_KEY / OPENAI_API_KEY / LLM_PROVIDER) "
            "and re-run, or pass --allow-empty-ci-gates to accept fork-specific-only "
            "gating explicitly."
        )
    else:
        _log(
            "no upstream CI gates selected; fork-specific checks only",
            level="INFO",
        )

    # Upstream size.
    size_kb = _check_upstream_size_kb(host, u_owner, u_repo)
    ctx.upstream_size_kb = size_kb
    if size_kb is not None and size_kb > MAX_UPSTREAM_SIZE_KB:
        _log(
            f"upstream is {size_kb / 1024 / 1024:.1f}GB — exceeds the 2GB soft limit. "
            f"Consider the patch-stack-only variant (Option D) instead. Proceeding anyway.",
            level="WARN",
        )

    # Mergify install probe.
    ctx.mergify_installed = _check_mergify_installed(fork_owner)
    if not ctx.mergify_installed:
        _log(
            f"Mergify app install not detected on {fork_owner}. After setup, "
            f"install it at https://github.com/apps/mergify.",
            level="WARN",
        )

    ctx.phases_completed.append("preflight")
    ctx.timings["preflight"] = time.monotonic() - t0
    _log(f"preflight OK: upstream={u_owner}/{u_repo}@{ctx.upstream_head_sha[:12]}")
    return ctx


# --------------------------------------------------------------------------- #
# Phase 2 — clone_upstream                                                    #
# --------------------------------------------------------------------------- #


def clone_upstream(ctx: SetupContext) -> None:
    """Create the fork on GitHub, then clone it locally and wire up upstream.

    Unlike the earlier approach (``gh repo create`` from a local clone of
    upstream), this flow uses ``gh repo fork`` so GitHub records a real parent
    relationship. Sequence:

    1. ``gh repo fork <upstream> --clone=false --fork-name <name> --org <owner>``
    2. If caller asked for ``--visibility private`` and the fork is public
       (because upstream is public), follow up with ``gh repo edit --visibility private``.
    3. Clone ``<fork>`` locally; origin is the fork.
    4. Add ``upstream`` as a separate remote and fetch it.
    5. Tag ``upstream-sync/<date>-<sha>`` at upstream's HEAD.
    """

    _phase("clone_upstream")  # phase name kept for backwards compat with snapshot logs
    t0 = time.monotonic()
    assert ctx.local_path is not None and ctx.upstream_url is not None
    assert ctx.fork_full_name is not None
    assert ctx.upstream_owner is not None and ctx.upstream_repo is not None

    ctx.local_path.parent.mkdir(parents=True, exist_ok=True)

    # 1. Fork on GitHub.
    #   - If fork_owner matches the authenticated user, forking goes to your
    #     own account and `--org` is rejected by gh.
    #   - If fork_owner is a different user or an org, pass `--org` (works for
    #     orgs; for other users, gh rejects — this is a GitHub limitation,
    #     you can only fork into yourself or an org you belong to).
    auth_user_proc = run(["gh", "api", "user", "-q", ".login"], check=True, dry_run=ctx.dry_run)
    auth_user = (auth_user_proc.stdout.strip() if not ctx.dry_run else ctx.fork_owner) or ctx.fork_owner

    fork_cmd = [
        "gh",
        "repo",
        "fork",
        f"{ctx.upstream_owner}/{ctx.upstream_repo}",
        "--clone=false",
    ]
    if ctx.fork_owner != auth_user:
        fork_cmd += ["--org", ctx.fork_owner]
    # Only pass --fork-name if it differs from upstream's name; gh rejects
    # the flag when the name would be identical.
    if ctx.fork_name != ctx.upstream_repo:
        fork_cmd += ["--fork-name", ctx.fork_name]
    run(fork_cmd, check=True, dry_run=ctx.dry_run)

    # 2. Enforce visibility if requested. gh repo fork inherits upstream's.
    if ctx.visibility == "private":
        run(
            [
                "gh",
                "repo",
                "edit",
                ctx.fork_full_name,
                "--visibility",
                "private",
                "--accept-visibility-change-consequences",
            ],
            check=False,  # may be a no-op if already private; don't hard-fail
            dry_run=ctx.dry_run,
        )

    # Fork creation is async on GitHub's side. Poll until visible.
    for attempt in range(10):
        probe = run(
            ["gh", "repo", "view", ctx.fork_full_name],
            check=False,
            dry_run=ctx.dry_run,
        )
        if probe.returncode == 0 or ctx.dry_run:
            break
        time.sleep(2 * (attempt + 1))
    else:
        raise RuntimeError(
            f"fork {ctx.fork_full_name} did not become visible in time"
        )

    # 3. Clone the fork locally. origin is the fork.
    fork_url = f"https://github.com/{ctx.fork_full_name}.git"
    run(
        ["git", "clone", fork_url, str(ctx.local_path)],
        check=True,
        dry_run=ctx.dry_run,
    )

    # 4. Add upstream as a separate remote and fetch everything.
    run(
        ["git", "remote", "add", "upstream", ctx.upstream_url],
        cwd=ctx.local_path,
        check=True,
        dry_run=ctx.dry_run,
    )
    run(
        ["git", "fetch", "upstream"],
        cwd=ctx.local_path,
        check=True,
        dry_run=ctx.dry_run,
    )

    # Resolve upstream's default branch from the remote (don't trust local HEAD,
    # which comes from the fork and may lag upstream briefly).
    proc = run(
        ["git", "symbolic-ref", "refs/remotes/upstream/HEAD"],
        cwd=ctx.local_path,
        check=False,
        dry_run=ctx.dry_run,
    )
    if proc.returncode == 0 and proc.stdout.strip():
        default_branch = proc.stdout.strip().rsplit("/", 1)[-1]
    else:
        default_branch = ctx.upstream_branch_override or "main"
    ctx.upstream_default_branch = default_branch

    # 5. Record the durable sync tag at upstream's HEAD.
    now = datetime.now(timezone.utc)
    sha = ctx.upstream_head_sha or "unknown"
    short_sha = sha[:12]
    date = now.strftime("%Y-%m-%d")
    tag = f"upstream-sync/{date}-{short_sha}"
    ctx.sync_tag = tag
    ctx.sync_date = date
    run(
        [
            "git",
            "tag",
            "-a",
            tag,
            "-m",
            f"initial upstream sync of {ctx.upstream_owner}/{ctx.upstream_repo}@{short_sha}",
            sha,
        ],
        cwd=ctx.local_path,
        check=True,
        dry_run=ctx.dry_run,
    )

    ctx.fork_url = f"https://github.com/{ctx.fork_full_name}"
    ctx.phases_completed.append("clone_upstream")
    ctx.timings["clone_upstream"] = time.monotonic() - t0


# --------------------------------------------------------------------------- #
# Phase 3 — create_branches                                                   #
# --------------------------------------------------------------------------- #


def create_branches(ctx: SetupContext) -> None:
    _phase("create_branches")
    t0 = time.monotonic()
    assert ctx.local_path is not None

    # Ensure the working branch is 'main'. Fork may use 'master'; rename if so.
    run(
        ["git", "branch", "-M", "main"],
        cwd=ctx.local_path,
        check=True,
        dry_run=ctx.dry_run,
    )
    # Create the pristine-mirror 'upstream' branch pointing at upstream's HEAD.
    # It's a *separate* branch from the fork's main so we can force-update it on
    # every sync without touching main.
    upstream_branch = ctx.upstream_default_branch or "main"
    run(
        ["git", "branch", "upstream", f"upstream/{upstream_branch}"],
        cwd=ctx.local_path,
        check=True,
        dry_run=ctx.dry_run,
    )

    ctx.phases_completed.append("create_branches")
    ctx.timings["create_branches"] = time.monotonic() - t0


# --------------------------------------------------------------------------- #
# Phase 4 — render_templates                                                  #
# --------------------------------------------------------------------------- #


def _template_variables(ctx: SetupContext) -> dict[str, str]:
    """Variables substituted into ``templates/``-rendered files."""

    # Combined gate set = LLM-selected upstream checks + fork-specific checks.
    # Exposed as JSON-array strings so workflow/mergify templates can drop them
    # into YAML lists without extra shell-quoting dance.
    all_required = list(ctx.required_ci_checks) + list(FORK_SPECIFIC_CHECKS)

    return {
        "upstream_owner": ctx.upstream_owner or "",
        "upstream_repo": ctx.upstream_repo or "",
        "upstream_url": ctx.upstream_url or "",
        "upstream_branch": ctx.upstream_default_branch or "main",
        "upstream_sha": ctx.upstream_head_sha or "",
        "upstream_sha_short": (ctx.upstream_head_sha or "")[:12],
        "fork_owner": ctx.fork_owner_resolved or "",
        "fork_name": ctx.fork_name,
        "fork_full_name": ctx.fork_full_name or "",
        "llm_provider": ctx.llm_provider,
        "llm_model": ctx.llm_model or "",
        "llm_secret_name": "ANTHROPIC_API_KEY"
        if ctx.llm_provider == "claude"
        else "OPENAI_API_KEY",
        "visibility": ctx.visibility,
        "sync_cron": ctx.sync_cron,
        "build_command": ctx.build_command or "# TODO: set a build command",
        "smoke_test_command": ctx.smoke_test_command
        or "# TODO: set a smoke-test command",
        "language": ctx.language or "",
        "sync_tag": ctx.sync_tag or "",
        "sync_date": ctx.sync_date or "",
        "iso_now": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        # JSON arrays so templates can splice them into YAML lists verbatim.
        "required_ci_checks": json.dumps(ctx.required_ci_checks),
        "all_required_checks": json.dumps(all_required),
    }


def _target_path_for_template(template_rel: Path, ctx: SetupContext) -> Path:
    """Map a template's path under ``templates/`` to its path inside the fork repo.

    Conventions:
    - ``templates/.mergify.yml.tmpl``          -> ``<fork>/.mergify.yml`` (root)
    - ``templates/root/X-notice.md.tmpl``      -> ``<fork>/X.md``       (prepend if exists)
    - ``templates/fork/gitignore.tmpl``        -> ``<fork>/.gitignore`` (append if exists)
    - ``templates/fork/patches-README.md``     -> ``<fork>/.fork/patches/README.md``
    - ``templates/fork/...``                   -> ``<fork>/.fork/...``
    - ``templates/workflows/...``              -> ``<fork>/.github/workflows/...``
    - ``templates/tools/...``                  -> ``<fork>/.fork/tools/...``
    - ``templates/repo-skills/...``            -> ``<fork>/.fork/skills/...``
    - Everything else keeps its relative path under ``.fork/``.
    """

    parts = template_rel.parts
    assert ctx.local_path is not None
    fork = ctx.local_path

    # Top-level templates (no subdir).
    if len(parts) == 1:
        name = parts[0]
        if name == ".mergify.yml.tmpl":
            return fork / ".mergify.yml"
        # Unknown top-level; drop under .fork/.
        return fork / ".fork" / name

    first, *rest = parts
    relname = "/".join(rest)

    if first == "root":
        # root/AGENTS-notice.md.tmpl -> <fork>/AGENTS.md
        # root/CLAUDE-notice.md.tmpl -> <fork>/CLAUDE.md
        # root/README-notice.md.tmpl -> <fork>/README.md
        stem = Path(relname).name.removesuffix(".md.tmpl")
        if stem.endswith("-notice"):
            stem = stem[: -len("-notice")]
        return fork / f"{stem}.md"
    if first == "fork":
        if relname == "gitignore.tmpl":
            return fork / ".gitignore"
        if relname == "patches-README.md.tmpl":
            return fork / ".fork" / "patches" / "README.md"
        return fork / ".fork" / relname
    if first == "workflows":
        return fork / ".github" / "workflows" / relname
    if first == "tools":
        return fork / ".fork" / "tools" / relname
    if first == "repo-skills":
        return fork / ".fork" / "skills" / relname
    # Fallback: drop it into .fork/ under its relative path.
    return fork / ".fork" / template_rel.as_posix()


# Root-level files we integrate with (prepend) instead of overwriting. Keyed by
# target path relative to the fork root.
_PREPEND_TARGETS = {"AGENTS.md", "CLAUDE.md", "README.md"}
_FORK_NOTICE_MARKER = "<!-- fork-notice:begin"


def _render_template(text: str, vars_: dict[str, str]) -> str:
    return string.Template(text).safe_substitute(vars_)


def _should_be_executable(path: Path) -> bool:
    return path.suffix in {".sh", ".py"} and "tools" in path.parts


def render_templates(ctx: SetupContext) -> None:
    _phase("render_templates")
    t0 = time.monotonic()
    assert ctx.local_path is not None

    if not TEMPLATES_DIR.exists():
        _log(f"no templates dir at {TEMPLATES_DIR}; skipping render", level="WARN")
        ctx.phases_completed.append("render_templates")
        ctx.timings["render_templates"] = time.monotonic() - t0
        return

    vars_ = _template_variables(ctx)

    for src in sorted(TEMPLATES_DIR.rglob("*")):
        if not src.is_file():
            continue
        rel = src.relative_to(TEMPLATES_DIR)
        target = _target_path_for_template(rel, ctx)

        # Strip .tmpl if present.
        if target.suffix == ".tmpl":
            target = target.with_suffix("")

        if ctx.dry_run:
            _log(f"[dry-run] render {rel} -> {target}")
            continue

        target.parent.mkdir(parents=True, exist_ok=True)
        try:
            text = src.read_text(encoding="utf-8")
            rendered = _render_template(text, vars_)

            # The Mergify template embeds a ``# >>> required_check_conditions <<<``
            # sentinel that scalar substitution cannot expand. Replace each
            # sentinel block with one ``- "check-success=<name>"`` line per
            # entry of ``all_required_checks``.
            if target.name == ".mergify.yml":
                all_required = list(ctx.required_ci_checks) + list(FORK_SPECIFIC_CHECKS)
                rendered = _ci_gates.expand_mergify_sentinels(rendered, all_required)

            # Respect upstream's files at the fork root. Three merge strategies:
            #   - .gitignore: append our entries below a clear header.
            #   - AGENTS.md / CLAUDE.md / README.md: prepend our fork-notice,
            #     keep upstream content below, mark our block with a begin/end
            #     marker so re-runs don't double-prepend.
            target_rel_str = target.name
            if target.name == ".gitignore" and target.exists():
                existing = target.read_text(encoding="utf-8").rstrip() + "\n"
                merged = existing + "\n# ----- fork additions (managed by setup-downstream-fork) -----\n" + rendered.lstrip()
                target.write_text(merged, encoding="utf-8")
            elif target_rel_str in _PREPEND_TARGETS and target.exists():
                existing = target.read_text(encoding="utf-8")
                if _FORK_NOTICE_MARKER in existing:
                    _log(f"fork-notice already present in {target_rel_str}; skipping prepend", level="INFO")
                else:
                    merged = rendered.rstrip() + "\n\n" + existing.lstrip()
                    target.write_text(merged, encoding="utf-8")
            else:
                target.write_text(rendered, encoding="utf-8")
        except UnicodeDecodeError:
            # Binary blob — copy as-is.
            shutil.copy2(src, target)

        if _should_be_executable(target):
            mode = target.stat().st_mode
            target.chmod(mode | 0o111)

    # Always materialize the directories the runtime expects, even if no
    # template provided them.
    for d in (
        ".fork/patches",
        ".fork/snapshots",
        ".fork/.llm-cache",
        ".fork/skills",
        ".fork/tools",
        ".fork/references",
        ".github/workflows",
    ):
        (ctx.local_path / d).mkdir(parents=True, exist_ok=True)

    # Persist the chosen CI gates so downstream workflows + doctor runs can
    # read back the same list without re-prompting the LLM.
    ci_gates = {
        "upstream_required": list(ctx.required_ci_checks),
        "fork_specific": list(FORK_SPECIFIC_CHECKS),
        "all_required": list(ctx.required_ci_checks) + list(FORK_SPECIFIC_CHECKS),
    }
    ci_gates_path = ctx.local_path / ".fork" / "ci-gates.json"
    if ctx.dry_run:
        _log(f"[dry-run] would write {ci_gates_path}")
    else:
        ci_gates_path.write_text(
            json.dumps(ci_gates, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )

    # Append .llm-cache/ to .gitignore.
    gitignore = ctx.local_path / ".gitignore"
    gitignore_lines = (
        gitignore.read_text(encoding="utf-8").splitlines()
        if gitignore.exists()
        else []
    )
    needed = [".fork/.llm-cache/", ".fork/.llm-cache/**"]
    for entry in needed:
        if entry not in gitignore_lines:
            gitignore_lines.append(entry)
    if not ctx.dry_run:
        gitignore.write_text("\n".join(gitignore_lines).rstrip() + "\n", encoding="utf-8")

    ctx.phases_completed.append("render_templates")
    ctx.timings["render_templates"] = time.monotonic() - t0


# --------------------------------------------------------------------------- #
# Phase 5 — preserve_upstream_agents_md                                       #
# --------------------------------------------------------------------------- #


def preserve_upstream_agents_md(ctx: SetupContext) -> None:
    """No-op retained for backwards compat of the phase list.

    Previous behavior moved upstream's root AGENTS.md into ``.fork/upstream-AGENTS.md``,
    which is destructive. The render step now prepends a fork-notice to upstream's
    file in place, so nothing to do here. Kept as a stub so recorded phase order
    in old setup logs still resolves.
    """

    _phase("preserve_upstream_agents_md")
    ctx.phases_completed.append("preserve_upstream_agents_md")


# --------------------------------------------------------------------------- #
# Phase 6 — write_symlinks                                                    #
# --------------------------------------------------------------------------- #


def _make_symlink(link: Path, target: str, *, dry_run: bool) -> None:
    if dry_run:
        _log(f"[dry-run] symlink {link} -> {target}")
        return
    link.parent.mkdir(parents=True, exist_ok=True)
    if link.exists() or link.is_symlink():
        link.unlink()
    os.symlink(target, link)


def write_symlinks(ctx: SetupContext) -> None:
    _phase("write_symlinks")
    t0 = time.monotonic()
    assert ctx.local_path is not None

    root = ctx.local_path
    # Root CLAUDE.md is handled by the prepend-template render (not a symlink)
    # so that upstream's own CLAUDE.md, if any, is preserved beneath our notice.
    #
    # Skill discovery for Claude Code / Codex: symlink each conventional path to
    # .fork/skills. Only create if the target doesn't already exist at that
    # path (upstream shouldn't ship .claude/skills, but don't clobber if so).
    for link_rel, target in (
        (".claude/skills", "../.fork/skills"),
        (".agents/skills", "../.fork/skills"),
    ):
        link = root / link_rel
        if link.exists() or link.is_symlink():
            # Existing upstream content at this path — refuse to overwrite.
            _log(f"{link_rel} already exists; skipping symlink", level="WARN")
            continue
        _make_symlink(link, target, dry_run=ctx.dry_run)

    ctx.phases_completed.append("write_symlinks")
    ctx.timings["write_symlinks"] = time.monotonic() - t0


# --------------------------------------------------------------------------- #
# Phase 7 — autodetect_build                                                  #
# --------------------------------------------------------------------------- #


def autodetect_build(ctx: SetupContext) -> None:
    """Fill in ``build_command``, ``smoke_test_command``, and ``language``.

    Overrides from CLI always win; otherwise we sniff the upstream working tree
    for common build-system signals and pick a sensible default.
    """

    _phase("autodetect_build")
    t0 = time.monotonic()
    assert ctx.local_path is not None

    root = ctx.local_path

    def exists(rel: str) -> bool:
        return (root / rel).exists()

    detected_build: str | None = None
    detected_smoke: str | None = None
    detected_lang: str | None = None

    if exists("Cargo.toml"):
        detected_lang = "rust"
        detected_build = "cargo build --release"
        detected_smoke = "cargo test"
    elif exists("go.mod"):
        detected_lang = "go"
        detected_build = "go build ./..."
        detected_smoke = "go test ./..."
    elif exists("pyproject.toml") or exists("setup.py"):
        detected_lang = "python"
        detected_build = "uv sync" if shutil.which("uv") else "pip install -e ."
        detected_smoke = "pytest -q"
    elif exists("package.json"):
        detected_lang = "javascript"
        detected_build = "npm ci && npm run build --if-present"
        detected_smoke = "npm test --if-present"
    elif any(exists(p) for p in ("Makefile", "makefile", "GNUmakefile")):
        detected_lang = detected_lang or "make"
        detected_build = "make"
        detected_smoke = "make test"
    elif exists("meson.build"):
        detected_lang = "meson"
        detected_build = "meson setup build && meson compile -C build"
        detected_smoke = "meson test -C build"
    elif any(root.glob("*.xcodeproj")) or any(root.glob("*.xcworkspace")):
        detected_lang = "swift"
        detected_build = "xcodebuild build"
        detected_smoke = "xcodebuild test"

    ctx.build_command = ctx.build_command_override or detected_build or "# TODO: set build command"
    ctx.smoke_test_command = (
        ctx.smoke_test_command_override
        or detected_smoke
        or "# TODO: set smoke-test command"
    )
    ctx.language = ctx.language_override or detected_lang

    _log(
        f"build={ctx.build_command!r} smoke={ctx.smoke_test_command!r} "
        f"lang={ctx.language!r}"
    )

    ctx.phases_completed.append("autodetect_build")
    ctx.timings["autodetect_build"] = time.monotonic() - t0


# --------------------------------------------------------------------------- #
# Phase 8 — initial_commit                                                    #
# --------------------------------------------------------------------------- #


def initial_commit(ctx: SetupContext) -> None:
    _phase("initial_commit")
    t0 = time.monotonic()
    assert ctx.local_path is not None

    short_sha = (ctx.upstream_head_sha or "")[:12]
    # NOTE: intentionally NO `Fork-Patch:` trailer. The scaffold commit is
    # plumbing (adds .fork/, workflows, .mergify.yml), not a feature patch
    # against upstream. Only user-authored feature commits carry the trailer;
    # that keeps `.fork/patches/` meaningful (one file per real patch).
    msg = (
        f"fork: initial scaffold targeting {ctx.upstream_owner}/{ctx.upstream_repo}@{short_sha}\n"
        f"\n"
        f"Fork-Setup: initial-scaffold\n"
        f"Reason: initial fork-maintainer scaffold targeting "
        f"{ctx.upstream_owner}/{ctx.upstream_repo}@{short_sha}\n"
    )

    run(["git", "add", "-A"], cwd=ctx.local_path, check=True, dry_run=ctx.dry_run)
    run(
        ["git", "commit", "-m", msg],
        cwd=ctx.local_path,
        check=True,
        dry_run=ctx.dry_run,
    )

    ctx.phases_completed.append("initial_commit")
    ctx.timings["initial_commit"] = time.monotonic() - t0


# --------------------------------------------------------------------------- #
# Phase 9 — create_gh_repo                                                    #
# --------------------------------------------------------------------------- #


def create_gh_repo(ctx: SetupContext) -> None:
    """Push our scaffolded branches + tags up to the fork.

    The fork was created earlier by ``clone_upstream`` via ``gh repo fork``.
    This phase just pushes what we built locally: ``main`` (which has our
    scaffold commit on top of upstream), ``upstream`` (the pristine mirror),
    and all tags.
    """
    _phase("create_gh_repo")
    t0 = time.monotonic()
    assert ctx.local_path is not None and ctx.fork_full_name is not None

    run(
        ["git", "push", "origin", "main"],
        cwd=ctx.local_path,
        check=True,
        dry_run=ctx.dry_run,
    )
    run(
        ["git", "push", "origin", "upstream"],
        cwd=ctx.local_path,
        check=True,
        dry_run=ctx.dry_run,
    )
    run(
        ["git", "push", "origin", "--tags"],
        cwd=ctx.local_path,
        check=True,
        dry_run=ctx.dry_run,
    )

    ctx.phases_completed.append("create_gh_repo")
    ctx.timings["create_gh_repo"] = time.monotonic() - t0


# --------------------------------------------------------------------------- #
# Phase 10 — configure_gh                                                     #
# --------------------------------------------------------------------------- #


def configure_gh(ctx: SetupContext) -> None:
    _phase("configure_gh")
    t0 = time.monotonic()
    assert ctx.fork_full_name is not None and ctx.local_path is not None

    # Enable auto-merge + actions + delete branch on merge.
    run(
        [
            "gh",
            "repo",
            "edit",
            ctx.fork_full_name,
            "--enable-auto-merge",
            "--delete-branch-on-merge",
        ],
        check=False,
        dry_run=ctx.dry_run,
    )

    # Actions are enabled by default on new repos, but be explicit.
    run(
        [
            "gh",
            "api",
            "-X",
            "PUT",
            f"repos/{ctx.fork_full_name}/actions/permissions",
            "-f",
            "enabled=true",
            "-f",
            "allowed_actions=all",
        ],
        check=False,
        dry_run=ctx.dry_run,
    )

    # Allow Actions to use a write-capable GITHUB_TOKEN and create PRs.
    # Needed because fork-upstream-sync.yml opens a PR via `gh pr create`.
    # Without this the default is read-only and the workflow fails with
    # "GitHub Actions is not permitted to create or approve pull requests".
    run(
        [
            "gh",
            "api",
            "-X",
            "PUT",
            f"repos/{ctx.fork_full_name}/actions/permissions/workflow",
            "-F",
            "default_workflow_permissions=write",
            "-F",
            "can_approve_pull_request_reviews=true",
        ],
        check=False,
        dry_run=ctx.dry_run,
    )

    # Secret for the LLM resolver.
    secret_name = (
        "ANTHROPIC_API_KEY" if ctx.llm_provider == "claude" else "OPENAI_API_KEY"
    )
    secret_value = os.environ.get(secret_name)
    if secret_value:
        run(
            [
                "gh",
                "secret",
                "set",
                secret_name,
                "--repo",
                ctx.fork_full_name,
                "--body",
                secret_value,
            ],
            check=True,
            dry_run=ctx.dry_run,
        )
    else:
        # Build a paste-ready multi-line instruction so the user doesn't have to
        # figure out the right flag combo for `gh secret set` on the fly.
        where = {
            "ANTHROPIC_API_KEY": "https://console.anthropic.com/settings/keys",
            "OPENAI_API_KEY": "https://platform.openai.com/api-keys",
        }.get(secret_name, "")
        instructions = (
            f"\n\n  ACTION REQUIRED — set the LLM API key secret before the first sync runs.\n"
            f"  Get a key: {where}\n"
            f"  Then pick one of:\n"
            f"    (a) interactive prompt, no key on command line:\n"
            f"        gh secret set {secret_name} --repo {ctx.fork_full_name} --body - \n"
            f"        # then paste the key and press Ctrl-D\n"
            f"    (b) from a file:\n"
            f"        gh secret set {secret_name} --repo {ctx.fork_full_name} < /path/to/key.txt\n"
            f"    (c) from env (exports the key to the process, less safe in shell history):\n"
            f"        export {secret_name}=sk-...\n"
            f"        gh secret set {secret_name} --repo {ctx.fork_full_name} --body \"${secret_name}\"\n"
            f"\n  Pre-flight setup_fork.py will also use {secret_name} from your local env on future\n"
            f"  runs — `export {secret_name}=...` before running this script to skip this step.\n"
        )
        _log(
            f"{secret_name} not set in the local env — skipped `gh secret set`."
            + instructions,
            level="WARN",
        )

    # Sync workflow auth — two mutually-exclusive paths:
    #   (a) GitHub App (preferred): FORK_APP_ID + FORK_APP_PRIVATE_KEY pushed
    #       as repo secrets; the App is installed on this repo so workflows
    #       can mint an installation token. No PAT, no 90-day expiry.
    #   (b) PAT fallback: FORK_SYNC_TOKEN pushed as a repo secret.
    # Either way GITHUB_TOKEN is not used, because GitHub suppresses
    # workflow_run events for pushes authed by it — Mergify auto-merge
    # never sees green without this.
    app_id = _resolve_opt("fork_app_id")
    app_private_key = _resolve_opt("fork_app_private_key")
    app_installation_id = _resolve_opt("fork_app_installation_id")
    app_configured = bool(app_id and app_private_key and app_installation_id)

    if app_configured:
        # Install the App on the newly created fork so the workflow's
        # create-github-app-token step can mint tokens scoped to this repo.
        repo_id_proc = run(
            ["gh", "api", f"repos/{ctx.fork_full_name}", "--jq", ".id"],
            check=False,
            dry_run=ctx.dry_run,
        )
        repo_id = repo_id_proc.stdout.strip() if repo_id_proc else ""
        if repo_id:
            run(
                [
                    "gh",
                    "api",
                    "-X",
                    "PUT",
                    f"/user/installations/{app_installation_id}/repositories/{repo_id}",
                ],
                check=False,
                dry_run=ctx.dry_run,
            )
        run(
            ["gh", "secret", "set", "FORK_APP_ID", "--repo", ctx.fork_full_name, "--body", app_id],
            check=True,
            dry_run=ctx.dry_run,
        )
        run(
            [
                "gh",
                "secret",
                "set",
                "FORK_APP_PRIVATE_KEY",
                "--repo",
                ctx.fork_full_name,
                "--body",
                app_private_key,
            ],
            check=True,
            dry_run=ctx.dry_run,
        )
        ctx.fork_sync_token_set = True  # the App path satisfies the same invariant
        _log(
            f"App-auth configured: installed on {ctx.fork_full_name} and pushed "
            "FORK_APP_ID + FORK_APP_PRIVATE_KEY as repo secrets.",
            level="INFO",
        )

    try:
        fork_sync_pat = _resolver().resolve("fork_sync_pat")
    except _secrets.SecretResolutionError as exc:
        _log(f"secret resolver failed for fork_sync_pat: {exc}", level="WARN")
        fork_sync_pat = None
    if app_configured:
        # App path already covers auth; skip pushing the PAT even if one is
        # resolved locally. The operator can still add it later as a fallback.
        fork_sync_pat = None
    if fork_sync_pat:
        run(
            [
                "gh",
                "secret",
                "set",
                "FORK_SYNC_TOKEN",
                "--repo",
                ctx.fork_full_name,
                "--body",
                fork_sync_pat,
            ],
            check=True,
            dry_run=ctx.dry_run,
        )
        ctx.fork_sync_token_set = True
    else:
        _log(
            "FORK_SYNC_PAT not set in env — FORK_SYNC_TOKEN secret was NOT pushed.\n"
            "  Sync PRs opened with GITHUB_TOKEN will not trigger CI, which "
            "means Mergify auto-merge will never see green checks.\n"
            "  Create a fine-grained PAT scoped to this fork with "
            "`contents:write`, `pull-requests:write`, `workflows:write` at\n"
            "  https://github.com/settings/tokens?type=beta then:\n"
            f"    gh secret set FORK_SYNC_TOKEN --repo {ctx.fork_full_name} --body -",
            level="WARN",
        )

    # Branch protection on main. Required contexts = LLM-picked upstream gates
    # plus our own fork-specific checks. Empty upstream list falls back to
    # fork-specific-only so the protection call still succeeds.
    # drift-recheck stays included only on sync/* PRs via Mergify rules; at the
    # branch-protection level it would block every human feature PR, so the
    # fork-specific set intentionally skips it here.
    branch_contexts = list(ctx.required_ci_checks) + [
        c for c in FORK_SPECIFIC_CHECKS if c != "drift-recheck"
    ]
    protection = {
        "required_status_checks": {
            "strict": True,
            "contexts": branch_contexts,
        },
        "enforce_admins": False,
        "required_pull_request_reviews": None,
        "restrictions": None,
        "allow_auto_merge": True,
        "required_linear_history": False,
        "allow_force_pushes": False,
        "allow_deletions": False,
    }
    if not ctx.dry_run:
        run(
            [
                "gh",
                "api",
                "-X",
                "PUT",
                f"repos/{ctx.fork_full_name}/branches/main/protection",
                "--input",
                "-",
            ],
            input_text=json.dumps(protection),
            check=False,
        )
    else:
        _log(f"[dry-run] would apply branch protection: {json.dumps(protection)}")

    ctx.phases_completed.append("configure_gh")
    ctx.timings["configure_gh"] = time.monotonic() - t0


# --------------------------------------------------------------------------- #
# Phase 11 — trigger_first_sync                                               #
# --------------------------------------------------------------------------- #


def trigger_first_sync(ctx: SetupContext) -> None:
    _phase("trigger_first_sync")
    t0 = time.monotonic()
    assert ctx.fork_full_name is not None

    run(
        [
            "gh",
            "workflow",
            "run",
            "fork-upstream-sync.yml",
            "--repo",
            ctx.fork_full_name,
        ],
        check=False,
        dry_run=ctx.dry_run,
    )

    ctx.phases_completed.append("trigger_first_sync")
    ctx.timings["trigger_first_sync"] = time.monotonic() - t0


# --------------------------------------------------------------------------- #
# Phase 12 — handoff                                                          #
# --------------------------------------------------------------------------- #


def handoff(ctx: SetupContext) -> None:
    _phase("handoff")
    t0 = time.monotonic()

    print("")
    print("=" * 72)
    print(f"  Downstream fork ready: {ctx.fork_full_name}")
    print("=" * 72)
    print(f"  Local path:  {ctx.local_path}")
    if ctx.fork_url:
        print(f"  GitHub URL:  {ctx.fork_url}")
    print(f"  Upstream:    {ctx.upstream_owner}/{ctx.upstream_repo}@{(ctx.upstream_head_sha or '')[:12]}")
    print(f"  Sync tag:    {ctx.sync_tag}")
    print(f"  Cron:        {ctx.sync_cron}  (next tick on GitHub's schedule)")
    print(f"  LLM:         provider={ctx.llm_provider} model={ctx.llm_model or '(default)'}")
    print("")
    print("  Day-to-day commands:")
    print(f"    cd {ctx.local_path} && .fork/tools/sync.sh     # manual sync")
    print(f"    cd {ctx.local_path} && claude                  # open an agent")
    print("")
    # Surface any outstanding manual steps so the user doesn't miss them.
    todo: list[str] = []
    secret_name = "ANTHROPIC_API_KEY" if ctx.llm_provider == "claude" else "OPENAI_API_KEY"
    if not os.environ.get(secret_name):
        key_url = {
            "ANTHROPIC_API_KEY": "https://console.anthropic.com/settings/keys",
            "OPENAI_API_KEY": "https://platform.openai.com/api-keys",
        }.get(secret_name, "")
        todo.append(
            f"Push the LLM API key secret (required for the conflict resolver):\n"
            f"      get a key: {key_url}\n"
            f"      gh secret set {secret_name} --repo {ctx.fork_full_name} --body -\n"
            f"      # paste the key then Ctrl-D\n"
            f"      # (or pipe from a file: gh secret set {secret_name} --repo {ctx.fork_full_name} < key.txt)"
        )
    if not ctx.mergify_installed:
        todo.append(
            "Install the Mergify app on your account/org to enable auto-merge:\n"
            "      https://github.com/apps/mergify\n"
            "      (one-time; after install it applies to every fork this skill generates)"
        )
    if not ctx.fork_sync_token_set:
        todo.append(
            "Push FORK_SYNC_TOKEN so sync PRs actually trigger CI:\n"
            "      GitHub suppresses workflow_run events when a push is authed by\n"
            "      the default GITHUB_TOKEN. Without FORK_SYNC_TOKEN, sync PRs\n"
            "      come up with zero checks and Mergify auto-merge never fires.\n"
            "      1. create a fine-grained PAT scoped to this fork:\n"
            f"         https://github.com/settings/tokens?type=beta\n"
            f"         target repo: {ctx.fork_full_name}\n"
            f"         scopes: contents:write, pull-requests:write, workflows:write\n"
            "      2. store it as a repo secret:\n"
            f"         gh secret set FORK_SYNC_TOKEN --repo {ctx.fork_full_name} --body -\n"
            "         # paste the PAT then Ctrl-D\n"
            "      3. for future setup_fork.py runs, export FORK_SYNC_PAT=... to skip this step.\n"
            "      Note: this unlock is REQUIRED for Mergify auto-merge to work on sync PRs."
        )
    if todo:
        print("  TODO before the first sync can auto-merge on green:")
        for i, item in enumerate(todo, start=1):
            print(f"    {i}. {item}")
        print("")

    ctx.phases_completed.append("handoff")
    ctx.timings["handoff"] = time.monotonic() - t0


# --------------------------------------------------------------------------- #
# CLI + orchestration                                                         #
# --------------------------------------------------------------------------- #


def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="setup_fork.py",
        description=(
            "Scaffold a new downstream fork (Mode 1). Clones upstream, writes "
            "`.fork/` scaffolding, creates the GitHub repo, configures secrets "
            "and branch protection, and triggers the first sync workflow."
        ),
    )
    p.add_argument(
        "--upstream",
        default=None,
        help=(
            "Upstream repo reference: `owner/repo` or URL (HTTPS/SSH). "
            "Required for setup mode; not used by --init-config or --validate-config."
        ),
    )
    p.add_argument(
        "--fork-name",
        default=None,
        help=(
            "Name for the new fork repo on GitHub. Required for setup mode; "
            "not used by --init-config or --validate-config."
        ),
    )
    p.add_argument(
        "--fork-owner",
        default=None,
        help="GitHub user or org to create the fork under. Defaults to authenticated gh user.",
    )
    p.add_argument(
        "--local-path",
        default=None,
        help="Local path to clone into. Defaults to $GHPATH/<fork-owner>/<fork-name>.",
    )
    p.add_argument(
        "--upstream-branch",
        default=None,
        help="Upstream branch to track. Defaults to upstream's default branch.",
    )
    p.add_argument(
        "--llm-provider",
        choices=["claude", "openai"],
        default="claude",
        help="LLM provider for the conflict resolver (default: claude).",
    )
    p.add_argument(
        "--llm-model",
        default=None,
        help="LLM model id (provider-specific). Omit to let the resolver pick a default.",
    )
    p.add_argument(
        "--visibility",
        choices=["public", "private"],
        default="private",
        help="Visibility for the created GitHub repo (default: private).",
    )
    p.add_argument(
        "--sync-cron",
        default="0 6 * * *",
        help="Cron expression for the sync workflow (default: daily 06:00 UTC).",
    )
    p.add_argument(
        "--build-command",
        default=None,
        help="Override the auto-detected build command.",
    )
    p.add_argument(
        "--smoke-test-command",
        default=None,
        help="Override the auto-detected smoke-test command.",
    )
    p.add_argument(
        "--language",
        default=None,
        help="Override the auto-detected primary language.",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate every phase. No git/gh side effects.",
    )
    p.add_argument(
        "--keep-on-fail",
        action="store_true",
        help="If a phase fails after cloning, leave the local directory on disk for inspection.",
    )
    p.add_argument(
        "--log-json",
        default=None,
        help="Write the final SetupContext JSON log to this path (default: alongside the fork).",
    )
    p.add_argument(
        "--allow-empty-ci-gates",
        action="store_true",
        help=(
            "Proceed when upstream has workflows but LLM gate discovery produced "
            "an empty list. Without this, setup aborts to avoid generating a fork "
            "that auto-merges with zero upstream build/test signal."
        ),
    )
    p.add_argument(
        "--init-config",
        action="store_true",
        help=(
            "Bootstrap the secret resolver config at "
            "~/.config/setup-downstream-fork/config.toml, then exit. Interactive."
        ),
    )
    p.add_argument(
        "--validate-config",
        action="store_true",
        help="Resolve every known secret and report status. No side effects.",
    )
    p.add_argument(
        "--config-path",
        default=None,
        help=(
            "Override the resolver config path. Defaults to "
            "~/.config/setup-downstream-fork/config.toml."
        ),
    )
    p.add_argument(
        "--from-env",
        action="store_true",
        help=(
            "With --init-config, skip the interactive prompts and write a "
            "config that points every known secret at its env var."
        ),
    )
    p.add_argument(
        "--force",
        action="store_true",
        help="With --init-config, overwrite an existing config file.",
    )
    return p


def _cleanup(ctx: SetupContext) -> None:
    if ctx.keep_on_fail:
        _log("--keep-on-fail set; leaving local directory for inspection")
        return
    if "clone_upstream" not in ctx.phases_completed:
        return
    if ctx.local_path and ctx.local_path.exists():
        _log(f"cleaning up {ctx.local_path}")
        try:
            shutil.rmtree(ctx.local_path)
        except OSError as exc:
            _log(f"cleanup failed: {exc}", level="WARN")


def _write_debug_log(ctx: SetupContext, path: Path | None) -> None:
    target = path
    if target is None and ctx.local_path is not None:
        target = ctx.local_path.parent / f".{ctx.fork_name}-setup.log.json"
    if target is None:
        return
    try:
        target.write_text(
            json.dumps(ctx.to_dict(), indent=2, sort_keys=True, default=str) + "\n",
            encoding="utf-8",
        )
        _log(f"wrote setup log to {target}")
    except OSError as exc:
        _log(f"could not write setup log: {exc}", level="WARN")


def main() -> int:
    global _RESOLVER
    parser = _build_parser()
    args = parser.parse_args()

    # Resolve the config path override once, before any mode branch.
    config_path = (
        Path(args.config_path).expanduser() if args.config_path else _secrets.DEFAULT_CONFIG_PATH
    )
    _RESOLVER = _secrets.build_default_resolver(config_path)

    # --init-config and --validate-config are self-contained modes: no
    # upstream, no fork name, no GitHub calls. Handle them before the
    # setup flow requires those args.
    if args.init_config:
        try:
            _secrets.init_config(config_path, force=args.force, from_env=args.from_env)
            return 0
        except (RuntimeError, _secrets.SecretResolutionError) as exc:
            _log(f"FATAL: {exc}", level="ERROR")
            return 1
    if args.validate_config:
        try:
            _secrets.validate_config(config_path)
            return 0
        except _secrets.SecretResolutionError as exc:
            _log(f"FATAL: {exc}", level="ERROR")
            return 1

    # Setup mode — these are required now that argparse no longer enforces it.
    if not args.upstream or not args.fork_name:
        parser.error("--upstream and --fork-name are required for setup mode")

    ctx: SetupContext | None = None
    try:
        ctx = preflight(args)
        clone_upstream(ctx)
        preserve_upstream_agents_md(ctx)
        create_branches(ctx)
        autodetect_build(ctx)
        render_templates(ctx)
        write_symlinks(ctx)
        initial_commit(ctx)
        create_gh_repo(ctx)
        configure_gh(ctx)
        trigger_first_sync(ctx)
        handoff(ctx)
    except CommandFailed as exc:
        _log(f"FATAL: {exc}", level="ERROR")
        if exc.stderr:
            _log(f"stderr: {exc.stderr.strip()}", level="ERROR")
        if ctx is not None:
            _cleanup(ctx)
            _write_debug_log(ctx, Path(args.log_json) if args.log_json else None)
        return 1
    except Exception as exc:  # noqa: BLE001 — want to log + clean up
        _log(f"FATAL: {exc}", level="ERROR")
        if ctx is not None:
            _cleanup(ctx)
            _write_debug_log(ctx, Path(args.log_json) if args.log_json else None)
        return 1

    _write_debug_log(ctx, Path(args.log_json) if args.log_json else None)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
