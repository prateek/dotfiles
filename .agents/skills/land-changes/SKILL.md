---
name: land-changes
description: Land a finished dotfiles branch onto master the way Prateek does it — no PRs, linear history, one commit per change. Use when the user says "land", "ship it", "land this branch", "merge into master", "ff-only merge", or "push to master". Rebases the branch onto the latest master, squashes to one commit, runs the checks for that diff, fast-forward-only merges into the `~/dotfiles` checkout, and pushes. Then confirms chezmoi's source is `~/dotfiles` and summarizes what a `chezmoi apply` would change — it does not apply chezmoi unless asked. Not for GitHub PRs (this repo lands locally), creating worktrees (Orca owns those), or landing in other repos.
---

# Land Changes (dotfiles)

## What landing means here

This repo lands locally: no pull requests, no merge commits, one commit per change, linear history.

- Work happens on a worktree branch. The canonical checkout is `~/dotfiles` on `master`, which is also chezmoi's source (`chezmoi source-path` → `~/dotfiles/home`).
- To land: rebase the branch onto the latest master, squash to a single commit, run the checks for that diff, fast-forward-only merge into `master`, and push.
- Landing touches git only. Applying the change into `$HOME` with `chezmoi apply` is a separate step that runs only when the user asks.

## When to use

Use when the branch is finished and the user wants it on master ("land it", "ship it", "merge into master"). Finish unfinished work first. Do not use to open or merge a GitHub PR (this repo has none), to create or remove worktrees (Orca owns those), or to land in another repo.

## Rules

- **One commit per land.** Rebase onto the latest `origin/master` and squash before merging.
- **Fast-forward only.** Never a merge commit; never `git merge` without `--ff-only`.
- **`chezmoi apply` runs only when the user asks**, and only from `~/dotfiles`.
- **Never** force-push, `--no-verify`, or bypass hooks. See `~/.agents/docs/git.md`.
- The canonical checkout must be clean before you merge into it.
- Checks pass before landing, not after.
- If anything is unexpected, stop and surface it — a pushed master is hard to undo.

## Procedure

Resolve the paths (run from the worktree):

```sh
WT="$(git rev-parse --show-toplevel)"
BRANCH="$(git -C "$WT" rev-parse --abbrev-ref HEAD)"
MAIN="$(git worktree list --porcelain | sed -n '1s/^worktree //p')"  # canonical checkout (~/dotfiles)
```

### 1. Preflight

```sh
gh api user -q .login                                        # confirm the expected identity
[ "$BRANCH" != master ]                    || { echo "STOP: on master"; exit 1; }
[ -z "$(git -C "$WT" status --short)" ]    || { echo "STOP: worktree has uncommitted work"; exit 1; }
[ "$(git -C "$MAIN" rev-parse --abbrev-ref HEAD)" = master ] || { echo "STOP: ~/dotfiles not on master"; exit 1; }
[ -z "$(git -C "$MAIN" status --short)" ]  || { echo "STOP: ~/dotfiles dirty"; exit 1; }
```

### 2. Rebase onto latest master and squash to one commit

```sh
git -C "$WT" fetch origin
git -C "$WT" rebase origin/master
```

If the branch has more than one commit, squash to one:

```sh
git -C "$WT" reset --soft origin/master
git -C "$WT" commit -m "<type>(<scope>): <subject>"          # single message; use -F - for a body
```

Confirm exactly one commit: `git -C "$WT" log --oneline origin/master..HEAD`. If the rebase conflicts and you can't cleanly resolve it, stop and hand back.

### 3. Run the checks for the diff

List the changed paths (`git -C "$WT" diff --name-only origin/master..HEAD`) and run the checks that cover them:

- `git -C "$WT" diff --check` always.
- `shellcheck -x` on changed shell scripts.
- For changed `home/` files, dry-run chezmoi against the worktree source: `make test-chezmoi-apply` (run from `$WT`).
- The `make test-*` target that names the changed area. The `Makefile` and `.github/workflows/install-smoke.yml` are the source of truth for which checks apply.

Fix failures on the branch and re-run. Never land red.

### 4. Merge fast-forward and push

```sh
git -C "$MAIN" merge --ff-only "$BRANCH"
git -C "$MAIN" push origin master
git -C "$MAIN" rev-parse --short origin/master HEAD          # both must match
```

If the merge refuses, master moved while you worked — refetch and redo step 2.

### 5. Confirm chezmoi's source and summarize the apply

Landing is done; do not apply. Confirm the source, then preview what an apply would change:

```sh
chezmoi source-path                                          # must resolve under ~/dotfiles
chezmoi diff                                                 # what a chezmoi apply would change in $HOME
```

If `chezmoi source-path` is not under `~/dotfiles`, stop and surface it. Otherwise summarize for the user which targets an apply would change and how they map to what you landed. Apply only if asked — from `~/dotfiles`, scoped to those targets, then `chezmoi verify`.

## Report

Say what landed (the one commit now on master), that the push matched, which checks passed, and the pending chezmoi changes. State that `chezmoi apply` did not run unless the user asked. Leave worktree cleanup to Orca.
