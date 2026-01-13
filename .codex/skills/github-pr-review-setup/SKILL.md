---
name: github-pr-review-setup
description: Prepare a clean local checkout for a GitHub PR (worktree-first via `wf`/`wt`), fetch the PR base ref, and emit PR context (CI checks + PR comments/reviews) as JSON for downstream review.
---

# GitHub PR Review Setup

## Inputs

- `pr`: PR number or URL (preferred)
- `repo` (optional): `OWNER/REPO` (used when `pr` is a number and repo can’t be inferred)
- `repo-dir` (optional): local clone path (required for non-`openai/openai` PRs if you aren’t already in that repo)
- `checkout-mode` (optional): `worktree` (default) or `inplace`
- `worktree-name` (optional): override worktree/branch name (default: `pr-review-<number>`)
- `out` (optional): path to also write the JSON payload

## Quick start

- Prepare a PR review workspace + print JSON:
  - `python "<path-to-skill>/scripts/prepare_github_pr_review.py" --pr "<number-or-url>"`
  - Add `--repo "<owner/repo>"` when `--pr` is just a number and repo inference isn’t possible.
  - Add `--repo-dir "<path-to-local-clone>"` for non-`openai/openai` PRs when needed.

## Output (JSON)

The script prints one JSON object to stdout containing at least:

- `worktree_dir`: local checkout path (worktree or in-place)
- `compare_to`: base ref suitable for `codex review --base` and PAL `compare_to` (e.g. `upstream/main`)
- `checks`: `gh pr checks` JSON
- `issue_comments`, `reviews`, `review_comments`: all PR discussion content pulled via `gh api --paginate`

## Workflow

### 1) Create / reuse a clean checkout (default: worktree)

- Uses `wf` for `openai/openai` and `wt` for all other repos.
- For `--checkout-mode inplace`, checks out the PR branch directly in the target clone (requires a clean repo).

### 2) Fetch the PR base ref (shared prerequisite)

- Chooses remote: prefer `upstream` if present, else `origin`.
- Fetches `<base_ref>` so `compare_to` exists locally.

### 3) Pull CI + discussion context (JSON only)

- CI checks: `gh pr checks`
- PR conversation: issue comments
- Reviews + inline review comments

### 4) Run the actual review

Use the `code-review` skill with:

- `path = worktree_dir`
- `compare_to = compare_to`
