---
name: ci-autofix-loop
description: >
  End-to-end CI fixer loop for the current git branch/PR (GitHub Actions + Buildkite).
  Use when asked to “fix CI”, “make checks green”, or “address failing checks”, and the workflow should:
  (1) discover failing checks via `gh pr checks`,
  (2) diagnose failures via provider logs (Buildkite log tooling/API or `gh run view --log-failed`),
  (3) apply minimal code fixes,
  (4) run `code-simplifier` + `code-review`,
  (5) commit + push, and
  (6) iterate until remaining failures are unfixable via code change.
---

# CI Autofix Loop

## Assumptions

- Work in a git repo with a PR (preferred) or a branch pushed to a remote.
- `gh` is authenticated for the repo.
- If Buildkite checks exist, Buildkite access is available via `BUILDKITE_TOKEN`.

## Workflow

### 0) Identify PR + base

- Prefer PR context:
  - `gh pr view --json number,baseRefName,headRefName,url`
- If no PR, operate on the current branch and upstream tracking ref:
  - `git status -sb`
  - `git rev-parse --abbrev-ref --symbolic-full-name @{u}` (if set)

### 1) Enumerate failing checks

- `gh pr checks --json name,state,link,description`
- If check entries are missing a URL, fall back to:
  - `gh pr view --json statusCheckRollup`
- Group checks into:
  - **Buildkite**: `link` is a buildkite.com URL (often `buildkite/<pipeline>` contexts).
  - **GitHub Actions**: `link` is a github.com/actions URL.
  - **Manual/unfixable-by-code**: e.g. `codeownerous` (review requirements), org policy checks, or anything that is purely approval-gated.

### 2) Diagnose + fix (one failure at a time)

#### Buildkite failures

1) Normalize to a base build URL:
   - `https://buildkite.com/<org>/<pipeline>/builds/<num>`
2) Prefer local log tooling when available:
   - If the repo contains `.codex/skills/buildkite-fetch-logs/scripts/get_buildkite_logs.py`, use it to download failed logs to a temp dir and inspect the failing job(s).
   - If it isn’t there, search for it in the workspace or CODEX_HOME before falling back to the API.
   - Otherwise, use the Buildkite API (`curl -H "Authorization: Bearer $BUILDKITE_TOKEN" ...`) to inspect job state + logs.
3) Common “not a code bug” pattern: **stale branch / merge base check**
   - Symptom: log contains “Your PR is too stale” / “must include commit <sha>”.
   - Fix:
     - `git fetch <remote> <baseBranch>`
     - `git rebase <remote>/<baseBranch>` (resolve conflicts if any)
     - `git push --force-with-lease`
4) Otherwise, map the error to code, implement the smallest fix, and run the exact test command(s) mentioned in the failing logs when feasible.

#### GitHub Actions failures

1) Extract the run/job IDs from the check URL if present:
   - Run URL: `.../actions/runs/<run_id>`
   - Job URL: `.../actions/runs/<run_id>/job/<job_id>`
2) Pull failing logs and identify the exact failing command:
   - Run-level: `gh run view <run_id> --log-failed`
   - Job-level (when you have `<job_id>`): `gh run view <run_id> --job <job_id> --log-failed`
3) Map failure → code:
   - Find referenced files/commands; run the smallest local equivalent (formatter/typecheck/unit test) if feasible.
4) Implement the minimal fix and rely on the push-triggered workflow re-run for validation.
5) If failures appear flaky or infra-only (no deterministic repro / no actionable logs), treat as unfixable-by-code and stop with a summary + links.

### 3) Simplify and review before committing

- Run `code-simplifier` on the current diff (keep behavior identical; avoid unrelated refactors).
- Run `code-review` against the PR base (or upstream branch) and address any blockers.

### 4) Commit + push

- Prefer one focused commit per logical CI fix (or squash related changes if they’re tightly coupled).
- Push to the PR branch.
- If you rebased or rewrote history, use `git push --force-with-lease` (never plain `--force`).

### 5) Iterate until done

- Re-check:
  - `gh pr checks`
- Stop when:
  - All CI checks are green **or**
  - Remaining items are not addressable via code changes (review-required gates, infra “broken” steps with no logs, external scanners, etc.).
- If you hit repeated failures with no new signal after 2–3 iterations, stop and summarize what’s blocking (with concrete URLs).

## Guardrails

- Never print or persist secrets (Buildkite token, GitHub tokens).
- Clean up temp log directories after use.
- Prefer minimal, reviewable diffs; avoid “drive-by” refactors.
