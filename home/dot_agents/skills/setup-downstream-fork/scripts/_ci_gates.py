"""Shared CI-gates helpers: fetch upstream workflows + LLM analysis.

Both ``setup_fork.py`` (greenfield setup) and ``doctor.py`` (audit/repair)
need to answer the same question: *given upstream's GitHub Actions
workflow files, which job names should gate fork merges?* This module
holds the fetch-upstream-workflows and LLM-call pieces so both callers
share one implementation.

The module is stdlib-only at import time. The LLM SDKs (``anthropic``,
``openai``) are imported lazily inside ``call_llm_for_ci_audit`` so a
stdlib-only consumer can still import this module.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Any


# Fork-specific gates we always require on top of whatever upstream gates we inherit.
FORK_SPECIFIC_CHECKS = ("patches-in-sync", "fork-contract-audit", "drift-recheck")

# Truncation cap for any single workflow file when fed into the LLM prompt.
_WORKFLOW_MAX_CHARS = 8_000

CI_AUDITOR_SYSTEM = (
    "You are a CI auditor. Given these GitHub Actions workflow files from an "
    "upstream repo, identify which *job names* (the string after the top-level "
    "`jobs:` key and also the `name:` if present — GitHub uses whichever is set) "
    "are the canonical merge gates a downstream fork should require. Exclude "
    "platform-specific matrix jobs (`darwin-cgo-build`, `windows`) that our "
    "cheap Linux fork CI can't reproduce. Exclude `deploy`, `release`, "
    "`publish`, `dependabot` style jobs. Exclude anything that requires special "
    "secrets the fork won't have. Return JSON: {\"required_checks\": [\"name1\", "
    "\"name2\"], \"optional_checks\": [\"name3\"], \"reasoning\": \"one paragraph\"}."
)


class LLMUnavailable(RuntimeError):
    """Raised when no LLM provider SDK/key is configured.

    Callers surface this as a SKIP rather than a hard failure so the
    doctor/setup flow can still proceed with sensible defaults.
    """


# --------------------------------------------------------------------------- #
# Upstream workflow fetch                                                     #
# --------------------------------------------------------------------------- #


def fetch_upstream_workflows(url: str) -> dict[str, str]:
    """Shallow-clone ``url`` and return ``{filename: contents}`` under ``.github/workflows``.

    Mirrors the pattern ``setup_fork.py`` uses at setup time: ``--depth=1
    --filter=blob:none --no-checkout`` then sparse-checkout just
    ``.github/workflows``. Ignores ``fork-*.yml`` (our own scaffolding,
    if it got into upstream somehow we don't want to loop on it).
    Returns an empty dict if upstream has no workflows dir.
    """

    workflows: dict[str, str] = {}
    with tempfile.TemporaryDirectory(prefix="fork-ci-gates-") as tmp:
        tmp_path = Path(tmp)
        probe = tmp_path / "probe"
        subprocess.run(
            [
                "git",
                "clone",
                "--depth=1",
                "--filter=blob:none",
                "--no-checkout",
                url,
                str(probe),
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        subprocess.run(
            ["git", "sparse-checkout", "init", "--cone"],
            cwd=str(probe),
            check=True,
            capture_output=True,
            text=True,
        )
        subprocess.run(
            ["git", "sparse-checkout", "set", ".github/workflows"],
            cwd=str(probe),
            check=False,
            capture_output=True,
            text=True,
        )
        subprocess.run(
            ["git", "checkout"],
            cwd=str(probe),
            check=False,
            capture_output=True,
            text=True,
        )

        workflows_dir = probe / ".github" / "workflows"
        if not workflows_dir.exists():
            return workflows
        for entry in sorted(workflows_dir.iterdir()):
            if not entry.is_file():
                continue
            if entry.name.startswith("fork-"):
                # Our own scaffolding — never a gate candidate.
                continue
            if entry.suffix.lower() not in {".yml", ".yaml"}:
                continue
            try:
                workflows[entry.name] = entry.read_text(encoding="utf-8")
            except (OSError, UnicodeDecodeError):
                continue
    return workflows


# --------------------------------------------------------------------------- #
# LLM analysis                                                                #
# --------------------------------------------------------------------------- #


def call_llm_for_ci_audit(
    provider: str,
    model: str | None,
    user_prompt: str,
    *,
    api_key: str | None = None,
) -> str:
    """Dispatch one bounded LLM call. Raises :class:`LLMUnavailable` on missing SDK/key.

    When ``api_key`` is provided, it's used directly. Otherwise the
    function falls back to ``OPENAI_API_KEY`` / ``ANTHROPIC_API_KEY``
    from the environment — preserving the pre-resolver behavior for
    callers that haven't migrated yet.
    """

    if provider == "openai":
        try:
            import openai  # type: ignore
        except ImportError as exc:
            raise LLMUnavailable(
                "openai SDK not installed; `pip install openai` or set LLM_PROVIDER=claude"
            ) from exc
        key = api_key or os.environ.get("OPENAI_API_KEY")
        if not key:
            raise LLMUnavailable("OPENAI_API_KEY is not set and no api_key passed")
        client = openai.OpenAI(api_key=key)
        resp = client.chat.completions.create(
            model=model or "gpt-4o-mini",
            max_tokens=1000,
            messages=[
                {"role": "system", "content": CI_AUDITOR_SYSTEM},
                {"role": "user", "content": user_prompt},
            ],
        )
        return resp.choices[0].message.content or ""

    # default: claude
    try:
        import anthropic  # type: ignore
    except ImportError as exc:
        raise LLMUnavailable(
            "anthropic SDK not installed; `pip install anthropic` or set LLM_PROVIDER=openai"
        ) from exc
    key = api_key or os.environ.get("ANTHROPIC_API_KEY")
    if not key:
        raise LLMUnavailable("ANTHROPIC_API_KEY is not set and no api_key passed")
    client = anthropic.Anthropic(api_key=key)
    resp = client.messages.create(
        model=model or "claude-sonnet-4-5",
        max_tokens=1000,
        system=CI_AUDITOR_SYSTEM,
        messages=[{"role": "user", "content": user_prompt}],
    )
    return "".join(
        block.text for block in resp.content if getattr(block, "type", None) == "text"
    )


def extract_json_blob(raw: str) -> dict[str, Any]:
    """Pull the first JSON object out of the model response, tolerating code fences."""

    raw = raw.strip()
    if raw.startswith("```"):
        raw = re.sub(r"^```(?:json)?\s*", "", raw)
        raw = re.sub(r"\s*```\s*$", "", raw)
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        m = re.search(r"\{.*\}", raw, flags=re.DOTALL)
        if not m:
            raise
        return json.loads(m.group(0))


def build_ci_prompt(workflows: dict[str, str]) -> str:
    """Build the user-message prompt from a workflows dict, truncating any outsize files."""

    sections: list[str] = []
    for name, body in workflows.items():
        if len(body) > _WORKFLOW_MAX_CHARS:
            body = body[:_WORKFLOW_MAX_CHARS] + "\n# ... [truncated] ...\n"
        sections.append(f"### {name}\n```yaml\n{body}\n```")
    return (
        "Upstream GitHub Actions workflow files follow. Identify the canonical "
        "merge-gate job names for a downstream fork to require.\n\n"
        + "\n\n".join(sections)
    )


def analyze_workflows(
    workflows: dict[str, str],
    *,
    provider: str = "claude",
    model: str | None = None,
    api_key: str | None = None,
) -> dict[str, Any]:
    """Run the CI-auditor LLM pass and return ``{"required_checks", "optional_checks", "reasoning"}``.

    Raises :class:`LLMUnavailable` when no provider SDK or key is configured.
    Raises ``ValueError`` when the response isn't a usable JSON payload.
    Returns ``{"required_checks": [], ...}`` when upstream has no workflows
    (the LLM call is skipped entirely in that case).
    """

    if not workflows:
        return {"required_checks": [], "optional_checks": [], "reasoning": "upstream has no workflows"}

    provider = (os.environ.get("LLM_PROVIDER") or provider).lower()
    user_prompt = build_ci_prompt(workflows)
    raw = call_llm_for_ci_audit(provider, model, user_prompt, api_key=api_key)

    try:
        payload = extract_json_blob(raw)
    except (json.JSONDecodeError, ValueError) as exc:
        raise ValueError(f"CI audit response was not valid JSON: {exc}") from exc

    if not isinstance(payload, dict):
        raise ValueError("CI audit response was not a JSON object")

    required = payload.get("required_checks")
    if not isinstance(required, list) or not all(isinstance(x, str) for x in required):
        raise ValueError("CI audit response missing a valid required_checks list")

    optional = payload.get("optional_checks") or []
    if not isinstance(optional, list):
        optional = []

    return {
        "required_checks": [str(x) for x in required],
        "optional_checks": [str(x) for x in optional if isinstance(x, str)],
        "reasoning": str(payload.get("reasoning") or ""),
    }


# --------------------------------------------------------------------------- #
# Revision / remote discovery                                                 #
# --------------------------------------------------------------------------- #


def read_revision_file(repo: Path) -> dict[str, str]:
    """Parse ``.fork/revision.txt`` into a dict.

    Recognizes ``key = value`` lines (matching the template format). Returns an
    empty dict if the file is missing or unreadable.
    """

    rev = repo / ".fork" / "revision.txt"
    if not rev.is_file():
        return {}
    try:
        text = rev.read_text(encoding="utf-8")
    except OSError:
        return {}
    out: dict[str, str] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        k, _, v = line.partition("=")
        out[k.strip()] = v.strip()
    return out


def resolve_upstream_url(repo: Path) -> str | None:
    """Return the pinned upstream URL for ``repo``.

    Priority:
      1. ``upstream_url`` key in ``.fork/revision.txt`` (future-compat: not
         in the current template, but honored if a fork adds it).
      2. ``git remote get-url upstream`` in the repo.
    Returns ``None`` if neither is available.
    """

    rev = read_revision_file(repo)
    # Accept several likely keys — the template ships `upstream = <sha>` only,
    # but some forks may persist the URL too.
    for key in ("upstream_url", "upstream.url", "url"):
        if rev.get(key):
            return rev[key]

    proc = subprocess.run(
        ["git", "remote", "get-url", "upstream"],
        cwd=str(repo),
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode == 0 and proc.stdout.strip():
        return proc.stdout.strip()
    return None


def resolve_upstream_branch(repo: Path, fallback: str = "main") -> str:
    """Return the pinned upstream branch for ``repo``.

    Priority: ``branch`` key in ``.fork/revision.txt``, else ``fallback``.
    """

    rev = read_revision_file(repo)
    return rev.get("branch") or fallback


# --------------------------------------------------------------------------- #
# Mergify rendering                                                           #
# --------------------------------------------------------------------------- #


# The canonical list of fork-specific gates that the Mergify config is allowed
# to reference in addition to whatever upstream gates we inherit. The `default`
# queue (human PRs) drops ``drift-recheck`` because it only runs on sync/*.
_DEFAULT_QUEUE_EXTRA = ("drift-recheck",)


def render_mergify_yml(template_text: str, required_checks: list[str]) -> str:
    """Rewrite the ``check-success=*`` lines inside a Mergify template to use ``required_checks``.

    Strategy: replace the ``check-success=...`` conditions inside the
    ``fork-sync`` and ``default`` queue blocks, plus the two
    ``pull_request_rules`` blocks that mirror them, with one line per
    entry in ``required_checks``. ``drift-recheck`` is always appended to
    the ``fork-sync`` queue because upstream may have advanced while the
    PR was open; it is NOT added to the ``default`` queue.

    The rewrite is textual. It preserves indentation, comments, and every
    unrelated field.
    """

    if not required_checks:
        # Nothing to rewrite — leave the template alone.
        return template_text

    lines = template_text.splitlines()
    out: list[str] = []

    # The template uses 6-space indentation for queue-rule conditions
    # and 6-space indentation for pull_request_rule conditions too. We
    # detect runs of consecutive ``^( *)- check-success=`` lines and
    # replace them with a generated block of the same indent.
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r"^(\s*)- check-success=", line)
        if not m:
            out.append(line)
            i += 1
            continue

        indent = m.group(1)
        # Collect the run of contiguous check-success= lines at this indent.
        block_start = i
        while i < len(lines) and re.match(
            rf"^{re.escape(indent)}- check-success=", lines[i]
        ):
            i += 1
        # We just consumed lines[block_start:i]. Decide whether this block
        # lives under fork-sync or default by scanning backwards for the
        # most recent queue rule / pull_request rule heading.
        is_sync_block = _block_is_sync_block(lines, block_start)

        rewritten = list(required_checks)
        if is_sync_block:
            for extra in _DEFAULT_QUEUE_EXTRA:
                if extra not in rewritten:
                    rewritten.append(extra)

        for name in rewritten:
            out.append(f"{indent}- check-success={name}")
        # Do NOT advance ``i``; it already points past the original block.

    return "\n".join(out) + ("\n" if template_text.endswith("\n") else "")


_SENTINEL_MARKER = "# >>> required_check_conditions <<<"


def expand_mergify_sentinels(text: str, all_required_checks: list[str]) -> str:
    """Expand ``# >>> required_check_conditions <<<`` blocks in a rendered Mergify template.

    Called by ``setup_fork.py`` after ``string.Template.safe_substitute``.
    The sentinel comment introduces a block that must be replaced, at
    setup time, with one ``- "check-success=<name>"`` line per entry in
    ``all_required_checks``. Replacement continues until the first
    non-comment, non-empty line at the same indent, which is the fallback
    ``- check-names-source: $all_required_checks`` line in the template
    (and which would otherwise be a Mergify-validator tripwire).

    Queue-context aware: the ``default`` queue drops ``drift-recheck``
    (non-sync heads don't run it) while the ``fork-sync`` queue keeps it.
    The caller passes the full check list; this function handles the
    drop.
    """

    if not all_required_checks:
        return text

    lines = text.splitlines()
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.lstrip()
        if not stripped.startswith(_SENTINEL_MARKER):
            out.append(line)
            i += 1
            continue

        indent = line[: len(line) - len(stripped)]
        sentinel_line_index = i
        # Emit the sentinel comment itself so the rendered file still
        # carries a breadcrumb of where the expansion happened.
        out.append(line)
        i += 1
        # Skip comments and blank lines at or deeper than indent. Then
        # consume the first non-comment line at the same indent (the
        # fallback ``- check-names-source`` line) and drop it too.
        while i < len(lines):
            peek = lines[i]
            peek_stripped = peek.lstrip()
            if peek_stripped.startswith("#") or not peek_stripped:
                # Retain author comments — they document the contract for
                # future readers and don't affect YAML parsing.
                out.append(peek)
                i += 1
                continue
            peek_indent = peek[: len(peek) - len(peek_stripped)]
            if peek_indent == indent and peek_stripped.startswith("- "):
                # Consume and discard the fallback line.
                i += 1
            break

        drop_drift = _sentinel_is_in_default_queue(lines, sentinel_line_index)
        expanded = [c for c in all_required_checks if not (drop_drift and c == "drift-recheck")]
        for name in expanded:
            out.append(f'{indent}- "check-success={name}"')

    trailing = "\n" if text.endswith("\n") else ""
    return "\n".join(out) + trailing


def _sentinel_is_in_default_queue(lines: list[str], idx: int) -> bool:
    """Scan upward from ``idx`` for the nearest ``- name:`` inside ``queue_rules``.

    Returns True when the enclosing queue is named ``default``. A missing
    or ambiguous context defaults to False (include drift-recheck) — the
    conservative choice, since adding a check that never fires is less
    harmful than omitting one we needed.
    """

    for j in range(idx - 1, max(-1, idx - 60), -1):
        m = re.match(r"^\s*-\s*name:\s*(\S+)", lines[j])
        if m:
            return m.group(1).strip() == "default"
    return False


def _block_is_sync_block(lines: list[str], block_start: int) -> bool:
    """Heuristic: scan upwards from ``block_start`` for the nearest ``name:`` and
    ``head~=^sync/`` marker to decide if this check-success block is under the
    sync queue/rule or the default queue/rule."""

    # Walk back up to 30 lines looking for a ``head~=^sync/`` marker or a queue
    # name.
    saw_sync_head = False
    name_value: str | None = None
    for j in range(block_start - 1, max(0, block_start - 30), -1):
        line = lines[j]
        # Only positive sync-head markers count. A negated form
        # (``"-head~=^sync/"``) indicates the *default*-queue rule.
        stripped = line.strip()
        if "head~=^sync/" in stripped and not stripped.startswith(("-head", "- \"-")) \
                and '"-head' not in stripped:
            saw_sync_head = True
        m = re.match(r"^\s*-\s*name:\s*(\S+)", line)
        if m and name_value is None:
            name_value = m.group(1).strip()
            # Stop once we hit the rule/queue heading.
            break
    if saw_sync_head:
        return True
    if name_value == "fork-sync":
        return True
    return False
