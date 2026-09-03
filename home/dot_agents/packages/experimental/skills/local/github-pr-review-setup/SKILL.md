---
name: github-pr-review-setup
description: Prepare a clean local checkout for a GitHub PR (worktree-first via `ohc`/Orca), fetch the PR base ref, and emit PR context (CI checks + PR comments/reviews) as JSON for downstream review.
---

# GitHub PR Review Setup

Use this skill to prepare a local checkout for reviewing a GitHub PR. The script
prints one JSON payload with the checkout path, base ref, PR metadata, CI checks,
and discussion threads.

## Inputs

- `pr`: PR number or URL (preferred)
- `repo` (optional): `OWNER/REPO` (used when `pr` is a number and repo can’t be inferred)
- `repo-dir` (optional): local clone path (required when you aren’t already in the target repo)
- `checkout-mode` (optional): `worktree` (default) or `inplace`
- `worktree-name` (optional): override worktree/branch name (default: `pr-review-<number>`)
- `out` (optional): path to also write the JSON payload

## Quick start

Prepare a PR review workspace and print JSON:

```sh
python "<path-to-skill>/scripts/prepare_github_pr_review.py" --pr "<number-or-url>"
```

Add `--repo "<owner/repo>"` when `--pr` is only a number and the repo cannot be
inferred. Add `--repo-dir "<path-to-local-clone>"` when not running inside the
target repo.

Use the default checkout mode for a clean Orca worktree:

```sh
python "<path-to-skill>/scripts/prepare_github_pr_review.py" \
  --pr "<number-or-url>" \
  --checkout-mode worktree
```

Use in-place checkout only when the current clone is clean and you want to check
out the PR branch there:

```sh
python "<path-to-skill>/scripts/prepare_github_pr_review.py" \
  --pr "<number-or-url>" \
  --checkout-mode inplace
```

## Output (JSON)

The script prints one JSON object to stdout containing at least:

- `worktree_dir`: local checkout path (worktree or in-place)
- `repo_dir`: underlying clone path, when known
- `compare_to`: fetched base ref suitable for review tools, for example `upstream/main`
- `pr`: `gh pr view` JSON for the PR
- `checks`: `gh pr checks` JSON
- `issue_comments`, `reviews`, `review_comments`: all PR discussion content pulled via `gh api --paginate`

## Workflow

### 1) Create / reuse a clean checkout (default: worktree)

Default mode is `--checkout-mode worktree`. The script resolves `ohc`, requires
`zsh`, `orca`, and `gh`, then asks `ohc` to create a clean Orca worktree named
`pr-review-<number>` unless `--worktree-name` is set. `ohc` clones through `ghc`,
registers the repo in Orca, and creates the worktree.

After Orca creates the worktree, the script runs `gh pr checkout` inside it with
`--branch <worktree-name> --force`. That path handles same-repo PRs and fork PRs
the same way.

For `--checkout-mode inplace`, the script uses `gh pr checkout` directly in the
existing clone. The clone must be clean, and the local `origin` must match the
requested repo when `origin` can be detected. This mode does not require Orca.

### 2) Fetch the PR base ref (shared prerequisite)

The script chooses a remote for the base branch: `upstream` when present,
otherwise `origin`, otherwise the first configured remote. It fetches the PR's
base ref so `compare_to` exists locally.

### 3) Pull CI + discussion context (JSON only)

- CI checks come from `gh pr checks`.
- PR metadata comes from `gh pr view`.
- Issue comments, reviews, and inline review comments come from paginated
  `gh api` calls.

### 4) Run the actual review

Use the review tool with:

- `path = worktree_dir`
- `compare_to = compare_to`
