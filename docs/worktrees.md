# Worktrees (Worktrunk + centralized storage)

This dotfiles repo provides a fast workflow for creating Git worktrees across repos, using [Worktrunk](https://worktrunk.dev/) (`wt`).

## Prereqs

- `wt` (Worktrunk)
- `fzf`, `zoxide` (installed via Brewfile)
- Dotfiles bootstrap symlinks `repo-index` + hook scripts into `~/bin`

If `wt` isn’t installed:

```sh
cargo install worktrunk --locked
```

## Goals

- Create/switch worktrees quickly (one command)
- Keep all worktrees in one place: `~/code/wt`
- Preserve repo directory names (important for OpenAI monorepo tooling)
- Optional sparse checkout (cone mode) when requested
- “New worktree + agent” pattern (default agent: `codex`, overridable)

## Commands

### `w` — unified wrapper (recommended)

Create/switch a worktree for a branch (repo picker by default):

```sh
w feature-auth
```

Create/switch and run an agent command (default agent: `codex`):

```sh
w fix-bug -- 'Fix GH #322'
```

Override the agent command (and use Worktrunk template vars if you want):

```sh
w run fix-bug --agent claude -- 'Fix GH #322'
w run fix-bug --agent 'code {{ worktree_path }}'
```

Useful subcommands:

```sh
w new feature-auth --base origin/main
w new feature-auth --sparse api --sparse docs
w cd  feature-auth                # switch + cd into worktree
w switch                          # pick an existing centralized worktree and cd into it (alias: wsc)
w ls                              # fast list of centralized worktrees under ~/code/wt
w ls --dirty                      # include clean/dirty status (slower)
w rm                              # dry-run stale cleanup
w rm --yes                        # apply stale cleanup
```

Common workflows:

```sh
w feature-auth                    # idempotent: create if missing, else switch
w cd feature-auth                 # enter worktree (creates it if branch exists but no worktree yet)
w new feature-auth --no-cd        # create/switch without cd (automation)
w new feature-auth --no-verify    # create/switch without hooks

w ls                              # list centralized worktrees
wt remove feature-auth            # remove a worktree (Worktrunk; from any dir with -C /path/to/repo)
w rm                              # cleanup only *stale/broken* centralized dirs (safe)
```

Select repo:

```sh
w feature-auth --here              # current repo (no picker)
w feature-auth --repo openai/openai
w feature-auth --repo /path/to/repo
```

Change the default agent:

```sh
export WT_AGENT_CMD=claude   # or keep default: codex
```

Worktrunk docs-style shorthand:

```sh
alias wra='w run'
```

### When to use `w` vs `wt`

- Use `w` when you want **multi-repo** selection (repo picker / `--repo`), a **centralized root** (`~/code/wt`), or a quick **agent launch** pattern.
- Use `wt` directly when you want Worktrunk’s **rich per-repo UX** (`wt list --full`, `wt switch` picker, `wt merge`, `wt remove`, hooks, CI links).

### Back-compat

`wtn` and `wta` still exist as thin shims:

- `wtn …` → `w new …`
- `wta …` → `w run …`

## Centralized layout

Worktrees are created under:

`~/code/wt/<owner>-<repo>.<branch_sanitized>/<repo_dir>`

Override the root:

```sh
export W_WORKTREES_ROOT="$HOME/code/wt"   # default shown
```

Example:

- `~/code/wt/openai-openai.feature-auth/openai`

## Sparse checkout (opt-in)

Pass `--sparse <path>` to `w` (create/new/run) to apply sparse checkout (cone mode) on creation:

```sh
w new my-branch --sparse api --sparse docs
```

The sparse hook is a no-op unless `WT_SPARSE_PATHS` is set (only set by the wrappers).

Manage sparse checkout after creation (run inside the worktree):

```sh
git sparse-checkout list
git sparse-checkout add tools              # add a new folder (cone mode)
git sparse-checkout set --cone -- api docs tools
git sparse-checkout disable                # return to full checkout
```

## OpenAI monorepo hooks

For `github.com/openai/openai`, OpenAI guidance generally prefers:

- keeping checkouts under `~/code` (speed/security reasons)
- preserving the repo directory name (`openai`) so repo-special-cased tooling works
- a separate venv per worktree to avoid “which code am I running?” confusion

This dotfiles setup keeps worktrees under `~/code/wt` and preserves the repo directory name.

### Per-worktree venv

On worktree creation, a per-worktree venv is created:

- `~/.virtualenvs/openai-<branch_sanitized>`

It runs `venv_setup_build` from `monorepo_setup.sh` (does not modify shell startup files).

Activate it manually:

```sh
source ~/.virtualenvs/openai-<branch_sanitized>/bin/activate
```

Recreate it if you get into a confused state:

```sh
export MONOREPO_VENV="$HOME/.virtualenvs/openai-<branch_sanitized>"
source monorepo_setup.sh
venv_setup_build
source "$MONOREPO_VENV/bin/activate"
```

Skip hooks for a one-off creation:

```sh
w new my-branch --no-verify
```
