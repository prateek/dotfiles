---
name: using-git-spice
description: Stack-aware Git workflows. Use when creating or adopting stacked branches, changing stack commits or dependencies, rebasing onto trunk, updating dependent PRs, splitting work into a stack, or choosing git-spice scope.
---

# Using git-spice

Use `git-spice`; `gs` is Ghostscript.

## Model

A tracked branch records its base; trunk is integration. Scopes: `branch` one,
`upstack` current and descendants, `downstack` current and ancestors, `stack`
all connected, and `repo` all tracked branches.

Choose the smallest scope. `(needs restack)` marks a stale branch.

## Workflow

1. Inspect the tree and current branch; preserve unrelated work, stage intended
   files, and use a checked-out branch.

   Check `git show-ref --verify --quiet refs/spice/data`; if absent, run step 2
   before any other git-spice command. Then inspect with
   `git-spice log short` or `git-spice log short --all`.

   Adopt an untracked Orca worktree branch against its known base:

   ```bash
   git-spice branch track --base=<base> --no-prompt
   ```

2. If uninitialized:

   ```bash
   git-spice repo init --trunk=<trunk> --remote=<remote> --no-prompt
   ```

   Resolve trunk and remote from Git state or ask. `--reset` is destructive.

3. Create a tracked branch. Config prepends `prateek/`; remove that prefix from
   user input and pass a bare name:

   ```bash
   git add <specific-files>
   git-spice branch create <bare-name> -m "<message>" --no-prompt
   ```

   With nothing staged, use `--no-commit`; use `-t <base>` when another branch
   is the intended base. Split and rename require full `prateek/...` names.

4. Commit on the layer that owns the change so descendants stay aligned:

   ```bash
   git add <specific-files>
   git-spice commit create -m "<message>" --no-prompt
   ```

   Before amending, verify the checked-out branch owns its top commit:

   ```bash
   git add <specific-files>
   git-spice commit amend --no-edit --no-prompt
   ```

   For a lower branch held elsewhere, amend there, then restack skipped
   descendants from their worktrees. Use `commit fixup` only when no worktree
   holds the owner.

5. Submit only on explicit request. Submit an unsubmitted base first; from a
   higher layer, submit bottom-up:

   ```bash
   git-spice downstack submit --fill --no-prompt
   ```

   Use `--update-only` for existing change requests. Config creates drafts; use
   `--no-draft` when ready-for-review was
   requested. Preview with `--dry-run`; run the same command without it only
   after the preview is correct.

   On `Branch X needs to be restacked` or `refusing to submit outdated branch`,
   restack and retry. `--force` force-pushes and bypasses safety; require
   explicit intent, a verified remote, and a pinned base.

6. After trunk changes or a parent merges, sync forge state and inspect again:

   ```bash
   git-spice repo sync --no-prompt
   git-spice log short
   ```

   Sync advances trunk even when another worktree holds it; direct
   `git fetch origin master:master` cannot. Config restacks descendants of
   branches sync merges or deletes. A trunk-only advance still needs one:

   ```bash
   git-spice upstack restack --no-prompt
   git-spice stack restack --no-prompt
   ```

   Sync skips branches held by another worktree. For a squash-merge SHA
   mismatch, confirm and delete the merged branch, then restack descendants.

7. When an operation stops on conflicts, resolve them, stage only the resolved
   files, and continue through git-spice:

   ```bash
   git add <resolved-files>
   git-spice rebase continue --no-edit --no-prompt
   ```

   Use `git-spice rebase abort` when resolution should be abandoned.

Run git-spice separately from long tests. Done means the requested operation
succeeded with only intended work and no unexplained stale branches.

## Guardrails

- Headless: supply required values and `--no-prompt`; suppress editors with
  `-m`, `--no-edit`, or `--fill`.
- Stack-aware: use git-spice commit, restack, onto, and submit on tracked
  branches so relationships and descendants stay aligned.
- Scoped: operate on the smallest branch set that satisfies the request.
- Keep local commits separate from remote submission; submit and merge only on
  request.
- Keep hooks and safety checks unless the user requests a bypass.
- For ambiguous outcomes such as "clean up this stack," inspect and ask before
  any restack, deletion, submission, or other rewrite.
- Run delete scopes or `repo init --reset` only after the user requests that
  destructive result and the targets are verified.

Before designing layers for work that should become a stack, read
[references/stack-design.md](references/stack-design.md).

For adoption chains, dependency moves, insertion, fixups, splitting,
squashing, folding, renaming, deletion, or editor-driven operations, read
[references/stack-surgery.md](references/stack-surgery.md).

For auth, submit metadata and previews, merging, or remote failure recovery,
read [references/change-requests.md](references/change-requests.md).
