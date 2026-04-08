---
name: using-git-spice
description: Use when working with stacked branches, managing dependent PRs/CRs, or uncertain about git-spice commands (stack vs upstack vs downstack) - provides command reference, workflow patterns, and common pitfalls for the git-spice CLI tool.
---

# Using git-spice (gs/gsp)

## Pick the CLI name (`gs` vs `gsp`)

Prefer `gsp` if it exists (some setups rename git-spice to avoid clashing with Ghostscript’s `gs`):

```bash
command -v gsp >/dev/null && SPICE=gsp || SPICE=gs
$SPICE --version
```

Use `$SPICE` in all commands below.

## Key concepts (quick refresher)

- **Trunk**: main integration branch (usually `main` or `master`).
- **Stack**: branches connected to your current branch (parents + children).
- **Downstack**: branches between current branch and trunk (ancestors).
- **Upstack**: branches above current branch (descendants).
- **Restack**: rebase tracked branches onto updated bases to keep stack relationships intact.

Example:

```
main (trunk)
└── feature-a
    └── feature-b
        └── feature-c
```

When on `feature-b`:
- Upstack: `feature-c`
- Downstack: `feature-a`, `main`

## Safety checklist

- Require a clean working tree before `restack`, `submit`, `sync`, `edit`, or any delete.
- Avoid manual history surgery on tracked branches (`git rebase`, `git push --force`). Prefer git-spice `restack` + `submit`.
- Never run destructive commands (`stack delete`, `upstack delete`, `repo init --reset`) unless the user explicitly asked.

## Quick reference

| Task | Command | Notes |
|------|---------|-------|
| Init repo | `$SPICE repo init` | One-time per repo; set trunk/remote. |
| Track current branch | `$SPICE branch track` | Useful for the first branch in a stack. |
| Create stacked branch | `$SPICE branch create <name>` | Creates on top of current; commits staged changes; tracks it. |
| View stack | `$SPICE log short` | Add `--all` to show all tracked stacks. |
| Navigate | `$SPICE up` / `$SPICE down` | Also: `$SPICE top`, `$SPICE bottom`, `$SPICE trunk`. |
| Restack after mid-stack edit | `$SPICE upstack restack` | Rebase current + descendants on updated bases. |
| Restack entire current stack | `$SPICE stack restack` | Useful after squash merges or drift. |
| Restack all tracked branches | `$SPICE repo restack` | Full alignment for the whole repo. |
| Submit/update CRs (whole stack) | `$SPICE stack submit` | Add `--fill`, `--draft`, `--update-only`, `--web`. |
| Submit/update CRs (upstack only) | `$SPICE upstack submit` | Current + descendants. |
| Submit/update CRs (downstack only) | `$SPICE downstack submit` | Current + ancestors to trunk. |
| Sync trunk + prune merged | `$SPICE repo sync` | Add `--restack` to sync + restack. |
| Adopt existing stack | `$SPICE downstack track` | Run from the topmost branch. |
| Reorder stack | `$SPICE stack edit` | Interactive stack surgery. |

## Core workflows

### 1) Initialize repo (once per repo)

```bash
$SPICE repo init
# or explicit:
$SPICE repo init --trunk=main --remote=origin
```

Optional forge auth:

```bash
$SPICE auth status || $SPICE auth login
```

### 2) Start or extend a stack

Track the current branch (useful for the first branch in a stack):

```bash
git add -A
$SPICE branch track
```

Create a new branch on top of the current one (commits staged changes + tracks it):

```bash
git add -A
$SPICE branch create feat/foo-ui
```

Inspect stacks:

```bash
$SPICE log short
$SPICE log long
$SPICE log short --all
```

### 3) Navigate

```bash
$SPICE up
$SPICE down
$SPICE top
$SPICE bottom
$SPICE trunk
```

### 4) Edit in the middle of a stack (restack)

After modifying a lower branch, restack everything above it:

```bash
git add -A
git commit -m "…"
$SPICE upstack restack
```

Or do commit + restack in one step:

```bash
git add -A
$SPICE commit create -m "…"
# shorthand: $SPICE cc -m "…"
```

If conflicts happen, use the rebase helpers:

```bash
$SPICE rebase continue
$SPICE rebase abort
```

### 5) Submit PRs/MRs (“Change Requests”)

Submit/update:

```bash
$SPICE branch submit        # current only
$SPICE upstack submit       # current + descendants
$SPICE downstack submit     # current + ancestors to trunk
$SPICE stack submit         # whole stack
$SPICE stack submit --fill  # derive title/body from commits
$SPICE stack submit --update-only --fill
$SPICE stack submit --fill --draft --web
```

### 6) Sync with trunk + prune merged branches

```bash
$SPICE repo sync
$SPICE repo sync --restack
```

If the repo has many tracked branches and needs full alignment:

```bash
$SPICE repo restack
```

### 7) Adopt existing branches into a stack

Track a single existing branch:

```bash
git checkout feature/big
$SPICE branch track --base main
```

Track an existing chain of branches (run from the topmost branch):

```bash
git checkout <top-branch>
$SPICE downstack track
```

### 8) Stack surgery (reorder / delete)

Reorder branches:

```bash
$SPICE stack edit
```

Destructive (require explicit user confirmation):

```bash
$SPICE stack delete --force
$SPICE upstack delete --force
```

## When to use git vs git-spice

Use git-spice for:
- Creating/tracking stacked branches: `$SPICE branch create`, `$SPICE branch track`, `$SPICE downstack track`
- Keeping stacks aligned: `$SPICE upstack restack`, `$SPICE stack restack`, `$SPICE repo restack`
- PR/MR workflows: `$SPICE branch submit`, `$SPICE stack submit`, `$SPICE repo sync`
- Navigation & inspection: `$SPICE up`, `$SPICE down`, `$SPICE log short`

Use git for:
- Editing and committing: `git add`, `git commit`, `git status`, `git diff`
- One-off investigation: `git log`, `git blame`

## Common mistakes / red flags

| Mistake | Why it’s wrong | Correct approach |
|---------|----------------|------------------|
| Rebasing children onto trunk after a parent merges | Breaks tracked stack relationships and causes avoidable conflicts | `$SPICE repo sync --restack` (or `$SPICE repo sync` then `$SPICE repo restack`) |
| Using `git rebase` on tracked branches | git-spice won’t track the relationships the way you expect | Use `$SPICE upstack restack` / `$SPICE stack restack` |
| Force-pushing stacked branches | Bypasses git-spice’s submit/update workflow | Use `$SPICE upstack submit` / `$SPICE stack submit` |
| Using `stack submit` when you meant “just children” | Submits ancestors too (sometimes surprising) | Use `$SPICE upstack submit` |
| Forgetting to initialize the repo | Many commands fail with unclear “not initialized / trunk” errors | Run `$SPICE repo init` once per repo |
| Assuming restack happens automatically | Stacks can drift after edits to lower branches | Explicitly run `$SPICE upstack restack` after mid-stack edits |

Red flags:

- You’re about to run `git rebase` or `git push --force` on a tracked branch.
- You’re not sure whether you want `upstack` vs `stack` vs `downstack` scope.

When in doubt:

```bash
$SPICE log short
$SPICE <command> --help
```

## Handling conflicts (during restack)

If `restack` hits conflicts:
1. Resolve conflicts using normal git tools (`git status`, edit files, `git add …`).
2. Continue with either `$SPICE rebase continue` (preferred) or `git rebase --continue`.
3. After it finishes, update remotes with `$SPICE upstack submit` or `$SPICE stack submit`.

## Config knobs (`git config`)

```bash
git config spice.submit.draft true
git config spice.submit.label "stacked,foo"
git config spice.submit.navigationComment multiple
git config spice.repoSync.closedChanges ignore
```

## References

- Deep-dive guide and examples: `references/using-git-spice.md`
- Test prompts / scenarios: `test-scenarios.md`
- For a specific subtopic, search the deep-dive for: “Adopting”, “Stack surgery”, “Agent-friendly snippets”, “repo sync”.
