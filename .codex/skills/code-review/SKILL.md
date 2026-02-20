---
name: code-review
description: Run `codex review` plus PAL `codereview` (via the `pal` skill) against a git base ref, then merge both outputs into one prioritized, actionable review.
---

# Code Review

## When to use

Use when you have a local git repo and a base ref to diff against (e.g. `upstream/main`, `origin/master`, or a commit SHA) and you want a single merged review from:

- `codex review`
- PAL `codereview` (run via `pal`)

## Inputs

- `path`: repo root directory (prefer absolute)
- `compare_to` (optional): git ref to compare against (e.g. `upstream/main`)
- If `compare_to` is omitted: review “pending/uncommitted changes” (staged + unstaged + untracked) instead.
- `extra` (optional): focus areas (perf, security, tests, API, etc.)
- `speed` (optional): `default` (thorough) or `quick` (faster/shallower)

## Workflow

### 1) Decide what you’re reviewing

- If the user says “pending changes” / “uncommitted changes”: the review target is `--uncommitted` (staged + unstaged + untracked). Compute `relevant_files` from `git status`.
- Otherwise: require `compare_to` and review `--base "<compare_to>"`.
- Note: `codex review` and `codex exec … review` both accept an optional custom review prompt (`[PROMPT]`).
- Prefer running the Codex pass via `codex exec … review …` so you can reliably:
  - run ephemerally (`--ephemeral`)
  - capture only the final review text (`--output-last-message`)
  - keep the focus prompt short and explicit (derived from `<extra>`)

### 2) Ensure the base ref exists locally (only when using `compare_to`)

- `cd <path>`
- If `compare_to` is a remote ref like `upstream/main`, ensure it’s present:
  - `git fetch <remote> <branch>`

### 3) Run Codex review + PAL codereview (parallel, via subagents)

These two passes are independent once `compare_to` exists locally. Run them in parallel using subagents/collab agents so each reviewer gets only the review prompt + the diff context (not the full parent conversation).

**About Codex `/review`:**

- Codex interactive `/review` is effectively the same underlying “review the current repo diff” flow as `codex review` / `codex exec … review`.
- The main differences are: `/review` runs inside the current interactive session (so it inherits the session’s config + any prior instructions), while this skill deliberately isolates reviewers (so you must pass a focused prompt + ensure config defaults match the parent).

**Context scoping (important):**

- When spawning review subagents, do **not** pass the full parent conversation.
- Pass only: `<path>`, the review target (`--uncommitted` or `--base <compare_to>`), a short review prompt (derived from `<extra>`), and (optionally) the changed file list.

**Subagent sandbox gotchas (important):**

- Subagents may be *more restricted* than the parent agent (filesystem/network). Do not assume subagents “inherit” the parent’s privileges.
- Some environments also block **nested Codex CLI invocations** (running `codex` from inside Codex). If `codex exec … review` is blocked, fall back to an LLM-only “Codex pass” that reads the diff via `git` and reviews the changes directly.
- Prefer a writable temp home (short path) for review subagents when you hit permission/path-length issues: `HOME="$(mktemp -d /tmp/codex-home.XXXXXX)"`.
  - This avoids failures writing to `~/.cache`, `~/.npm/_logs`, and avoids macOS unix-socket path-length issues (prefer `/tmp`, not `/var/folders/...`).
  - Tradeoff: changing `HOME` can break bootstrappers/caches (e.g. dotslash, `npx`, `uvx`) and force re-downloads.
- If you set `HOME` for a subagent, also copy the parent Codex config so model + reasoning defaults match the parent:
  - `mkdir -p "$HOME/.codex" && cp "<parent-home>/.codex/config.toml" "$HOME/.codex/config.toml"`
- If you set `HOME` for a subagent, consider pinning caches to stable shared paths to speed up tool startup:
  - `npm_config_cache=/tmp/npm-cache` (for `npx`)
  - `UV_CACHE_DIR=/tmp/uv-cache` (for `uvx`)
- Avoid wrappers that try to auto-download tools (common failure mode in sandboxes with no GitHub/npm access).
  - For Codex: prefer running a **real** Codex binary available on `PATH`. If `codex` on `PATH` is a bootstrapper, pass a real binary path into the subagent as `CODEX_BIN`.
    - On macOS, a reliable source is the dotslash cache, e.g.: `ls -t "<parent-home>/Library/Caches/dotslash"/*/*/codex | head -n1`.
    - If you changed `HOME` for the subagent, do **not** rely on the bootstrapper: its cache typically lives under `HOME`, so it will try to re-download.
  - For PAL: default to the generated `pal` skill wrapper (pinned `mcporter@${MCPORTER_VERSION}` via `npx`). Only set `MCPORTER_BIN=mcporter` if you’ve verified that your local `mcporter` can start the keep-alive daemon (run `bash "<path-to-pal-skill>/scripts/selftest"` first).
- If subagent execution still fails due to sandbox limits (common: no network), fall back to running both review commands in the parent agent in parallel (e.g. via `multi_tool_use.parallel`) and keep subagents only for reasoning/merging.

**Optional: compute changed files (recommended for PAL to constrain file reads):**

- `cd <path>`
- If using `compare_to`: `git diff --name-only "<compare_to>...HEAD"`
- If using `--uncommitted`: `git status --porcelain=v1 -uall`

**Spawn two review subagents in parallel:**

- Subagent A (Codex review, capture as `codex_review`):
  - Task: in `<path>`, run **`codex exec … review`** and capture the final review text:
    - If reviewing pending changes:
      - `"<CODEX_BIN>" exec --ephemeral -C "<path>" --output-last-message "<codex_review_file>" review --uncommitted "<focus prompt>"`
    - Else:
      - `"<CODEX_BIN>" exec --ephemeral -C "<path>" --output-last-message "<codex_review_file>" review --base "<compare_to>" "<focus prompt>"`
  - Notes:
    - Prefer `--output-last-message <file>` on `codex exec` to capture only the final review text (avoid interleaved tool logs).
  - Output requirement:
    - Return only the contents of `<codex_review_file>` (no extra commentary) so merging is deterministic.
- Subagent B (PAL codereview, capture as `pal_review`):
  - Task: in `<path>`, run PAL `codereview` as a **multi-step continuation flow** (external validation):
    - Step 1: call `codereview` with `step_number=1`, `total_steps=2`, `next_step_required=true`, `review_validation_type="external"`, and include:
      - required: `model` (use `auto` unless the user requested a specific model), `findings` (can start as `""`)
      - recommended: `relevant_files` + `focus_on="<extra>"` when provided
    - Read the repo diff + relevant files (based on `relevant_files`) and write up findings locally.
    - Step 2: call `codereview` again with `step_number=2`, `next_step_required=false`, pass `continuation_id` from step 1, and include your findings + `files_checked`.
    - Extract and return `expert_analysis.raw_analysis` (or the final summarized findings) as markdown/plaintext.
  - Suggested execution pattern (shell):
    - Use a longer timeout for `codereview` to avoid flakes: `MCPORTER_CALL_TIMEOUT=600000` (or pass `--timeout` if supported).
  - Notes:
    - Prefer passing `relevant_files` as absolute paths for the files changed vs `<compare_to>` (leave it empty/omit if you can’t compute it).
    - Keep the narrative in `step` short; don’t paste large code snippets.
    - Prefer writing tool outputs to files instead of capturing via `$(...)` when outputs may be large.
  - Output requirement: return only the final review text (no extra commentary) so merging is deterministic.

**Speed knobs (optional):**

- Prefer smaller context:
  - Pass only changed files as `relevant_files` to PAL.
  - Avoid pasting diffs; pass file paths and let reviewers read locally.
- Prefer faster settings:
  - Codex (only when `speed=quick`): override reasoning effort if acceptable (e.g. `-c model_reasoning_effort="high"` instead of `xhigh`).
  - PAL (only when `speed=quick`):
    - use `review_type="quick"` + `thinking_mode="low"`
    - consider `review_validation_type="internal"` + `total_steps=1` + `next_step_required=false` + `use_assistant_model=false` for fastest runs

Implementation note (when tool-parallelism is available): spawn both subagents concurrently, then wait for both to finish before proceeding.

**Alternative (often faster/more reliable):**

- Run the *command execution* in the parent agent in parallel (Codex review + PAL calls), write outputs to files, then spawn subagents only to (a) summarize/critique each output and (b) merge. This avoids subagent network/tooling restrictions while still keeping subagent context small.

**Suggested orchestration (Codex multi-agent):**

- Spawn two reviewer subagents (e.g. `explorer` agents) with minimal messages that include only: `<path>`, the review target (`--uncommitted` or `--base <compare_to>`), `<speed>`, `<extra>`, and optionally the changed file list.
- Wait for both to finish and capture their outputs as `codex_review` and `pal_review`.

### 4) Merge feedback into one review (via a worker)

After both `codex_review` and `pal_review` are available, spawn an additional **worker** subagent whose only job is to merge feedback:

- Input: `codex_review`, `pal_review`, plus the original `<extra>` prompt.
- Output: one merged review with the structure below.

- Deduplicate overlapping findings; reconcile disagreements (call them out explicitly).
- Prioritize into:
  - **Blockers (must fix)**: correctness, security, data loss, breaking API/ABI, missing tests, CI failures.
  - **High-signal improvements**: maintainability, performance, edge cases, observability.
  - **Nits**: style/consistency (only if low-noise).
- End with a short verification checklist (tests to run, manual steps, rollout risk).
