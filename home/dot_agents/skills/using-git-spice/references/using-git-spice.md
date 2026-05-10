# Using git-spice (gs/git-spice)

## Table of contents
- [0 — Quick note: `gs` vs `git-spice`](#0--quick-note-gs-vs-git-spice)
- [1 — Repo setup & daily workflows](#1--repo-setup--daily-workflows)
- [2 — Core concepts (refresher)](#2--core-concepts-refresher)
- [3 — Stack surgery (reordering / deleting)](#3--stack-surgery-reordering--deleting)
- [4 — Useful config knobs](#4--useful-config-knobs)
- [5 — Gotchas to keep in mind](#5--gotchas-to-keep-in-mind)
- [6 — Agent-friendly snippets](#6--agent-friendly-snippets-updated-for-git-spice)

---

## 0 — Quick note: `gs` vs `git-spice`

Upstream docs and examples use `gs` as the git-spice CLI. ([GitHub][1])

Some setups rename the binary to **`git-spice`** (commonly to avoid clashing with Ghostscript’s `gs`), so:

- If your binary is `git-spice`, read `gs …` as `git-spice …`.
- If your binary is `gs`, read `git-spice …` in this guide as `gs …`.

Sanity check:

```bash
# Prefer git-spice if it exists, otherwise fall back to gs.
command -v git-spice >/dev/null && SPICE=git-spice || SPICE=gs

$SPICE --version     # verify git-spice binary
git --version        # verify git itself

# Optional: confirm auth to GitHub/GitLab
$SPICE auth status || $SPICE auth login
```

`auth status` and `auth login` use your system keychain to store forge creds. ([abhinav.github.io][2])

---

## 1 — Repo setup & daily workflows

### 1.1 One-time per repo: trunk + remote

Inside your repo:

```bash
# minimal: let git-spice autodetect trunk and remote
git-spice repo init

# explicit example (if trunk is develop instead of main)
git-spice repo init --trunk=develop --remote=origin

# change trunk/remote later:
git-spice repo init --trunk=main --remote=origin

# hard reset gsp’s metadata (not your git history):
git-spice repo init --reset
```

`git-spice repo init` stores which branch is “trunk” and which remote to use. All the stacking logic is local until you push or pull. ([GitHub][1])

---

### 1.2 Your first local stack (with `git-spice`)

```bash
mkdir gs-playground && cd gs-playground
git init
git commit --allow-empty -m "initial"
git-spice repo init
```

Now build a small stack:

```bash
# Branch 1: feat1 on main
git checkout -b feat1 main
echo "hello" > hello.txt
git add hello.txt
git-spice branch track          # mark feat1 as tracked in git-spice

# Branch 2: feat2 stacked on feat1
echo "this is cool" > README.md
git add README.md
git-spice branch create feat2   # creates branch, commits staged changes, tracks it

# Variant: auto-stage tracked files like `git commit -a`
git-spice branch create -a feat3
```

This gives you a stack like: **`main -> feat1 -> feat2 [-> feat3]`**. ([GitHub][1])

Inspect it:

```bash
git-spice log short        # branches-only view around current branch
git-spice log long         # branches + commits
git-spice log short --all  # every tracked stack in repo
```

All `log` variants can emit JSON via `--json` if you’re scripting. ([abhinav.github.io][3])

---

### 1.3 Navigation in a stack

Core navigation:

```bash
git-spice up        # go "up" one branch (further from trunk)
git-spice down      # go "down" one branch (closer to trunk)
git-spice top       # jump to topmost branch in this stack
git-spice bottom    # jump to branch closest to trunk
git-spice trunk     # jump to trunk (e.g. main)
```

- **Downstack** = branches between current branch and trunk.
- **Upstack** = branches above current branch. ([Claude Code Plugins][4])

Typical loop when you’re iterating on a feature stack:

```bash
git-spice down    # review / tweak something lower
# ...edit, commit...
git-spice up      # back up to your latest branch
git-spice trunk   # return to main when done
```

---

### 1.4 Editing mid-stack & keeping everything aligned

You often tweak a middle branch and want everything above it rebased automatically.

**Option A — normal git commit + explicit restack**

```bash
git-spice down                    # e.g. from feat2 → feat1

# ...edit some files...
git add hello.txt
git commit -m "feat1: tweak greeting"

# restack current + upstack
git-spice upstack restack
```

`git-spice upstack restack` rebases the current branch and all its descendants onto updated bases. ([abhinav.github.io][3])

**Option B — one-shot commit + restack**

```bash
# still on feat1
git add hello.txt
git-spice commit create -m "feat1: tweak greeting again"
# shorthand: git-spice cc -m "..."
```

`git-spice commit create` makes a commit _and_ restacks the upstack in one go. ([abhinav.github.io][5])

---

### 1.5 Submitting Change Requests (PRs/MRs)

git-spice calls PRs/MRs **Change Requests (CRs)**. Each tracked branch corresponds to one CR on GitHub/GitLab. ([abhinav.github.io][2])

You submit via:

```bash
git-spice branch submit       # current branch only         (git-spice bs)
git-spice downstack submit    # current + all below        (git-spice dss)
git-spice upstack submit      # current + all above        (git-spice uss)
git-spice stack submit        # entire stack               (git-spice ss)
```

- **Idempotent**: creates CRs for branches without one, updates existing ones. ([abhinav.github.io][2])

Interactive example:

```bash
# on feat1
git-spice branch submit
# → prompts for title/body/draft and prints the new CR URL
```

Non-interactive / agent-friendly examples:

```bash
# derive title/body from commit messages
git-spice stack submit --fill

# scriptable single-branch CR
git-spice branch submit \
  --title "feat: better logging" \
  --body "Explain motivation, details, and risks." \
  --draft

# update existing CRs, don’t create new ones
git-spice stack submit --update-only

# open submitted changes in browser
git-spice stack submit --fill --web
```

All the usual flags exist here: `--fill`, `--[no-]draft`, `--update-only`, `--web`, `--no-verify`, `--label`, etc. ([abhinav.github.io][3])

---

### 1.6 Syncing with trunk & cleaning up merged branches

Once some CRs are merged or closed:

```bash
git-spice repo sync               # pull trunk, delete merged branches
git-spice repo sync --restack     # same + restack current stack
```

This:

1. fetches / pulls trunk,
2. removes branches whose CRs are merged,
3. optionally prompts about closed-but-unmerged CRs. Behavior is controlled by `spice.repoSync.closedChanges`. ([abhinav.github.io][2])

To aggressively restack everything:

```bash
git-spice repo restack   # restack all tracked branches in repo
```

This is like a full repo rebase for tracked branches only. ([abhinav.github.io][5])

---

## 1.7 Adopting `git-spice` for an existing “big” branch

You asked for **how to take a single branch of commits you created _before_ using git-spice and turn it into a `git-spice` stack**.

There are two flavors:

1. Treat your existing branch as a **one-branch stack** (fastest).
2. Split it into **multiple stacked branches** using existing commits.

### 1.7.1 Fast path: treat existing branch as a 1-branch stack

Great if your branch is already a reasonable CR and you just want `git-spice`’s navigation/submit/sync goodies.

```bash
# Once per repo, if not already done:
git-spice repo init --trunk=main --remote=origin

# On your existing branch:
git checkout feature/big
git-spice branch track --base main   # `--base` optional; git-spice can guess
```

- `git-spice branch track` records this branch in git-spice’s metadata and associates a base. ([abhinav.github.io][3])
- You can now use **all** `git-spice` commands on it:

```bash
git-spice log short
git-spice branch submit
git-spice repo sync
```

It’s technically a stack of size 1 (trunk → feature/big). That’s already enough to use stack submit/sync flows later.

---

### 1.7.2 Turning one “big” branch into a multi-branch `git-spice` stack

This is the more interesting case: you’ve got a branch with several commits that should have been separate PRs.

Assume:

- Trunk: `main`
- Existing branch: `feature/big`
- Commit history (from oldest to newest above main):

```bash
git log --oneline main..
# e.g.
# 9c1a5b4 (HEAD -> feature/big) Add UI wiring for payments
# a3f9d01 Add Stripe integration
# 7e4dcdc Add payment provider interface
```

You’d like:

- `pay-core` = “Add payment provider interface”
- `pay-stripe` = “Add Stripe integration”
- `pay-ui` = “Add UI wiring for payments”

#### Step 1 — Make branches at the right commits

```bash
git checkout feature/big

# create branches pointing at each key commit
git branch pay-core   7e4dcdc
git branch pay-stripe a3f9d01
git branch pay-ui     9c1a5b4   # or: git branch pay-ui feature/big
```

Because these commits are already linearly stacked (main → 7e4dcdc → a3f9d01 → 9c1a5b4), the new branches naturally form a stack if you track them in the right order. ([Git][6])

#### Step 2 — Initialize `git-spice` (if you haven’t already)

```bash
git-spice repo init --trunk=main --remote=origin
```

#### Step 3 — Track the whole stack in one go

Git-spice has `downstack track` specifically for this: it walks down from a top branch, tracking everything below. ([abhinav.github.io][3])

```bash
git checkout pay-ui          # topmost branch
git-spice downstack track          # track pay-ui, pay-stripe, pay-core
```

Now check:

```bash
git-spice log short
# should show:
#   pay-ui
#   pay-stripe
#   pay-core
#   main (trunk)
```

You now have a **proper `git-spice` stack derived from your original branch**.

#### Step 4 — Retire or repurpose the original branch

Once you’re confident the new stack is correct:

```bash
# Option A: keep it around but clearly marked
git branch -m feature/big feature/big-old

# Option B: delete it (only when you’re sure)
git branch -D feature/big-old
```

If you already had a PR open for `feature/big`:

1. Close that PR or mark it superseded.
2. Run:

   ```bash
   git checkout pay-ui
   git-spice stack submit --fill --web
   ```

   That will create/update a CR for each stacked branch with navigation comments and correct bases. ([abhinav.github.io][2])

---

### 1.7.3 Optional: build a stack by cherry-picking (more control)

If your commit boundaries don’t line up with how you want to slice the stack, you can:

1. Create new branches from `main`.
2. Cherry-pick commits into them by hand, or use `git-spice commit pick` (experimental). ([abhinav.github.io][5])

Very rough sketch:

```bash
# 1. create first branch
git checkout main
git checkout -b pay-core
git cherry-pick <commit1a> <commit1b>   # only the commits for core

# 2. create second branch on top
git checkout -b pay-stripe
git cherry-pick <commit2a> <commit2b>   # only Stripe commits

# 3. third branch
git checkout -b pay-ui
git cherry-pick <commit3a> <commit3b>   # UI commits

# 4. track the stack
git-spice repo init --trunk=main --remote=origin
git-spice downstack track   # run from pay-ui
```

This gives you clean branch boundaries even if your original branch history was messy.

---

## 2 — Core concepts (refresher)

Short recap from the docs: ([GitHub][1])

- **Trunk** – your main integration branch (`main` / `master`).
- **Branch** – normal Git branch, but `git-spice` tracks its **base** (the branch it’s stacked on).
- **Stack** – trunk plus all branches connected via bases above/below the current branch.
- **Downstack** – everything between current branch and trunk.
- **Upstack** – everything above current.
- **Restack** – rebase branches onto updated bases to keep the stack linear.

---

## 3 — Stack surgery (reordering / deleting)

Inspect & debug:

```bash
git-spice log short
git-spice log short --all
git-spice log long
git-spice log short --json | jq '.'
```

Reorder branches:

```bash
git-spice stack edit
# text file opens; reorder lines & save; git-spice reshapes the stack
```

Delete:

```bash
git-spice stack delete --force       # delete entire stack for current branch
git-spice upstack delete --force     # delete everything above current branch
# synced cleanup:
git-spice repo sync                  # removes merged branches routinely
```

All destructive operations require `--force` for safety. ([abhinav.github.io][3])

---

## 4 — Useful config knobs

Examples (per-repo or `--global`):

```bash
# default new CRs to draft
git config spice.submit.draft true

# labels on every submit
git config spice.submit.label "stacked,observability"

# navigation comments: only if multiple CRs in stack
git config spice.submit.navigationComment multiple

# repo sync: ignore closed (unmerged) CRs instead of prompting
git config spice.repoSync.closedChanges ignore
```

([abhinav.github.io][2])

Shell completion:

```bash
# bash
eval "$(git-spice shell completion bash)"

# zsh
eval "$(git-spice shell completion zsh)"

# fish
eval "$(git-spice shell completion fish)"
```

Add whichever line fits your shell rc. ([GitHub][1])

---

## 5 — Gotchas to keep in mind

Summarizing the important ones: ([abhinav.github.io][2])

1. **You need write access to the main repo** for stacked PRs to work cleanly (bases are set via branch relationships in same repo).

2. **Squash merges** rewrite history; after one lands, run:

   ```bash
   git-spice repo sync
   git-spice stack restack
   git-spice stack submit --update-only --fill
   ```

3. **Repo policies may drop approvals** when bases change; stacking will trigger that if the policy is enabled.

4. **Rebases can still get messy**. Escape hatches:

   ```bash
   git-spice rebase abort
   git-spice rebase continue
   ```

---

## 6 — Agent-friendly snippets (updated for `git-spice`)

A few ready-to-paste workflows:

```bash
# New stacked feature on top of main
git-spice repo init --trunk=main --remote=origin || true
git checkout main

# branch 1
# ...edit...
git add .
git-spice branch create feat/api-auth

# branch 2
# ...edit...
git add .
git-spice branch create feat/api-auth-ui

# inspect + submit all as drafts
git-spice log short
git-spice stack submit --fill --draft --web
```

```bash
# Address review feedback in middle of stack
git-spice down                        # move to reviewed branch
# ...edit...
git add .
git-spice commit create -m "Address review feedback"
git-spice stack submit --update-only --fill --web
```

```bash
# Sync after some CRs merged
git-spice repo sync --restack
git-spice stack submit --update-only --fill
```

```bash
# Import existing CRs into git-spice
gh pr checkout 359          # or: glab mr checkout 8
git-spice branch track
git-spice branch submit --fill --web

# Or whole stack of PRs:
gh pr checkout 359
gh pr checkout 360
gh pr checkout 361
git-spice downstack track
git-spice stack submit --update-only --fill --web
```

## References

[1]: https://github.com/abhinav/git-spice?utm_source=chatgpt.com "abhinav/git-spice: Manage stacked Git branches"
[2]: https://abhinav.github.io/git-spice/guide/cr/?utm_source=chatgpt.com "git-spice - Submitting stacks - GitHub Pages"
[3]: https://abhinav.github.io/git-spice/cli/reference/?utm_source=chatgpt.com "CLI Reference - git-spice"
[4]: https://claude-plugins.dev/skills/%40arittr/spectacular/using-git-spice?utm_source=chatgpt.com "using-git-spice - Claude Skills - Claude Code Plugins"
[5]: https://abhinav.github.io/git-spice/changelog/?utm_source=chatgpt.com "Changelog - git-spice"
[6]: https://git-scm.com/docs/user-manual/2.30.0?utm_source=chatgpt.com "Git - user-manual Documentation"
