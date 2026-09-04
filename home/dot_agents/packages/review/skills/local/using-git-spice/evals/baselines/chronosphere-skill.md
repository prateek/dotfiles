---
name: git-spice
user-invocable: false
description: Use git-spice instead of raw git for branch management and PR workflows. Use when creating branches, managing stacks, submitting PRs, rebasing, navigating branches, or any git branch/PR operation. TRIGGER when the user asks to create a branch, submit a PR, rebase, navigate branches, or manage stacks.
---

# git-spice Branch & PR Management

Use `git-spice` instead of raw git commands for all branch management and PR workflows. git-spice manages stacked branches with automatic rebasing and PR submission.

## Key Principle

**Always use `git-spice` commands instead of raw `git` equivalents for branch and PR operations.** Raw git is fine for `git status`, `git diff`, `git log`, `git add`, etc. — but for creating branches, committing with restack, switching branches, submitting PRs, and rebasing, use `git-spice`.

## Branch Naming

Branch naming is handled by the user's `spice.branchCreate.prefix` config setting.
When using `git-spice branch create`, the prefix is automatically applied.

To set up the prefix (replace `username` with the user's preferred prefix):
```bash
git config --global spice.branchCreate.prefix "username/"
```

## Quick Reference

| Instead of... | Use... |
|---|---|
| `git checkout -b branch` | `git-spice branch create branch` (or `git-spice bc branch`) |
| `git checkout branch` | `git-spice branch checkout branch` (or `git-spice bco branch`) |
| `git commit` | `git-spice commit create -m "msg"` (or `git-spice cc -m "msg"`) — commits and restacks upstack |
| `git commit --amend` | `git-spice commit amend` (or `git-spice ca`) — amends and restacks upstack |
| `git rebase` | `git-spice branch restack` (or `git-spice br`) / `git-spice upstack restack` (or `git-spice usr`) |
| `git push` + `gh pr create` | `git-spice branch submit` (or `git-spice bs`) / `git-spice stack submit` (or `git-spice ss`) |
| `git branch -d branch` | `git-spice branch delete branch` (or `git-spice bd branch`) |
| `git checkout main` | `git-spice trunk` |

## Initializing

Before using git-spice in a repo for the first time:

```bash
git-spice repo init
```

To authenticate with GitHub (needed for PR submission):

```bash
git-spice auth login
```

## Creating Branches

Always create branches with git-spice so they are automatically tracked:

```bash
# Create a new branch off current branch (prompts for name if omitted)
git-spice branch create my-feature

# Create with a commit message
git-spice branch create my-feature -m "initial commit message"

# Create without committing (when you have no staged changes)
git-spice branch create my-feature --no-commit

# Create off a specific base branch without checking it out
git-spice branch create my-feature -t other-branch

# Insert a branch mid-stack (moves upstack branches onto it)
git-spice branch create prereq --insert
```

If a branch already exists but isn't tracked:

```bash
git-spice branch track
```

## Committing

Use `git-spice commit create` / `git-spice commit amend` instead of `git commit` / `git commit --amend`. These automatically restack any branches stacked on top.

```bash
git add <specific files>
git-spice commit create -m "description of change"

# To amend the last commit, keeping the commit message:
git-spice commit amend --no-edit
# To amend the last commit but supply a new message:
git-spice commit amend --message  $'commit title\n\ncommit body' # or --message-file file_with_commit_message
# Or amend and stage all changes:
git-spice commit amend -a
```

**Shorthand**: `git-spice cc` = commit create, `git-spice ca` = commit amend.

## Navigating Stacks

```bash
git-spice trunk          # Go to main/master
git-spice up             # Move up one branch in the stack
git-spice down           # Move down one branch in the stack
git-spice top            # Jump to the top of the stack
git-spice bottom         # Jump to the bottom of the stack
git-spice branch checkout # Interactive branch picker (or git-spice bco <name>)
```

## Rebasing / Restacking

When a base branch changes, restack dependent branches:

```bash
git-spice branch restack      # Restack current branch (git-spice br)
git-spice upstack restack     # Restack current + all branches above (git-spice usr)
git-spice repo restack        # Restack ALL tracked branches
```

To move a branch onto a different base:

```bash
git-spice branch onto main        # Move current branch onto main
git-spice upstack onto other-branch  # Move current + upstack onto other-branch
```

## Submitting PRs

```bash
# Submit PR for current branch
git-spice branch submit            # or git-spice bs

# Submit PRs for the entire stack
git-spice stack submit             # or git-spice ss

# Submit current branch and everything above
git-spice upstack submit

# Submit current branch and everything below
git-spice downstack submit
```

Common flags for submit commands:

- `--fill` / `-c`: Auto-fill title/body from commit messages on first submission
  - does not update PR description on re-submit
- `--draft` / `--no-draft`: Set draft status
- `--reviewer <user>` / `-r <user>`: Request review
- `--label <label>` / `-l <label>`: Add labels
- `--web` / `-w`: Open PR in browser after creation

## Syncing with Remote

```bash
git-spice repo sync    # Pull latest trunk, restack all branches, delete merged branches
```

This is the equivalent of `git pull` + cleanup. It handles:
- Fetching and updating trunk
- Restacking all tracked branches
- Deleting branches whose PRs have been merged

## Handling Rebase Conflicts

When a restack hits a conflict:

```bash
# Fix the conflict in your editor, then:
git add <resolved files>
git-spice rebase continue    # or git-spice rbc

# Or abort:
git-spice rebase abort       # or git-spice rba
```

## Viewing Stack State

```bash
git-spice log short    # List branches in current stack (git-spice ls)
git-spice log long     # List branches with their commits (git-spice ll)
git-spice log short -a # Show ALL tracked branches across all stacks
```

## Other Branch Operations

```bash
git-spice branch rename old-name new-name   # Rename a branch
git-spice branch edit                        # Interactive rebase of branch commits
git-spice branch squash                      # Squash all branch commits into one
git-spice branch split                       # Split branch at specific commits
git-spice branch fold                        # Merge branch into its base
git-spice branch diff                        # Show changes vs. base branch
git-spice branch delete my-branch            # Delete branch, restack upstack
```

## Stack Operations

```bash
git-spice stack edit       # Reorder branches in the stack
git-spice stack delete --force  # Delete all branches in the stack
```

## Guardrails

- **Always stage specific files** with `git add <files>`, never `git add -A` or `git add .`
- **Use `git-spice cc` / `git-spice ca` instead of `git commit`** so upstack branches get restacked automatically
- **Use `git-spice bs` / `git-spice ss` instead of `git push` + `gh pr create`** for PR submission
- **Use `git-spice repo sync` instead of `git pull`** to keep everything in sync
- **Never force-push manually** — git-spice handles pushes during submit
- **Run `git-spice repo init` first** if the repo hasn't been initialized with git-spice yet
- **Always use `-m` flag for commits** — Claude cannot open editors, so provide commit messages inline with `git-spice cc -m "msg"` or `git-spice ca -m "msg"`
- **Always use `--fill` for submit commands** — Submit commands prompt for interactive input without `--fill`, which Claude cannot handle
- **Use `--no-prompt` when commands may prompt interactively** — Claude cannot handle interactive prompts; pass `--no-prompt` to prevent them (e.g., `git-spice repo sync --no-prompt`)
