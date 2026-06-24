# Worktrees (Worktrunk + centralized storage)

This dotfiles repo provides a fast workflow for creating Git worktrees across repos, using [Worktrunk](https://worktrunk.dev/) (`wt`).

## Prereqs

- `wt` (Worktrunk) — installed via Homebrew (`worktrunk` is in the `base` package group in `home/.chezmoidata/packages.toml`, so every machine type gets it).
- `fzf`, `zoxide` (installed via Brewfile)
- `w`, `wta`, `wtn` are zsh autoload functions shipped by these dotfiles (`home/dot_config/zsh/autoload/`); `init.sh` adds the autoload dir to `fpath` so they're available in any interactive shell after `chezmoi apply`.
- `chezmoi apply` symlinks `repo-index` + `wt-hook-sparse` into `~/bin` (via `home/bin/symlink_*.tmpl`)

Note: the `worktrunk` formula installs a `wt` binary that conflicts with `wiredtiger`. We don't ship `wiredtiger`, so this is only relevant if a future package addition pulls it in.

Manual install fallback if Homebrew isn't an option:

```sh
cargo install worktrunk --locked
```

## Goals

- Create/switch worktrees quickly (one command)
- Keep all worktrees in one place: `~/code/wt`
- Preserve repo directory names (useful for repo-local tooling and scripts)
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
w ls                              # fast compact list (repo/branch/status with relations)
w ls -l                           # long list with full absolute path column
w ls --no-relations               # fastest metadata-only status (`ok`)
w ls --dirty                      # show clean/dirty words, including untracked files (slower)
w ls --relations                  # explicit relation mode (default on)
w ls --dirty --relations          # show dirty+relation tuple (most expensive)
w rm feature-auth                 # remove a selected worktree (branch deleted if merged)
w rm --filter 'feature-auth'      # non-interactive substring selection (must match one)
w rm --yes --filter 'dirty/rm'    # required for dirty worktrees
w prune                           # dry-run stale cleanup
w prune --yes                     # apply stale cleanup
```

Common workflows:

```sh
w feature-auth                    # idempotent: create if missing, else switch
w cd feature-auth                 # enter worktree (creates it if branch exists but no worktree yet)
w new feature-auth --no-cd        # create/switch without cd (automation)
w new feature-auth --no-verify    # create/switch without hooks

w ls                              # list centralized worktrees
w rm feature-auth                 # remove a worktree via wrapper safety rules
w prune                           # cleanup only *stale/broken* centralized dirs (safe)
```

### `w ls` status legend

- Default (`w ls`): `<main><upstream>` (example: `↕|`, `=·`).
- `w ls --no-relations`: `ok` means metadata-only fast path.
- `w ls --dirty`: `clean` or `dirty` (includes untracked files).
- `w ls --relations`: explicit relation mode (same as default).
- `w ls --dirty --relations`: `<dirty><main><upstream>` (example: `!↕⇣`, `·_·`).
- `main` symbols: `^ = _ – ↑ ↓ ↕ ? ·`
- `upstream` symbols: `| ⇡ ⇣ ⇅ ·`

Select repo:

```sh
w feature-auth --here              # current repo (no picker)
w feature-auth --repo owner/repo
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

- `~/code/wt/test-owner-test-repo.feature-auth/test-repo`

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

## Repo-specific hooks

Worktrunk supports repo-specific hooks in `~/.config/worktrunk/config.toml`.

This dotfiles setup only enables the generic sparse hook by default:

```toml
[pre-start]
sparse = "wt-hook-sparse"
```

If a repo needs extra setup on worktree creation, add a repo-scoped hook in your Worktrunk config:

```toml
[projects."github.com/owner/repo".pre-start]
setup = "wt-hook-repo-setup"
```

Keep repo-specific hooks:

- idempotent
- fast
- limited to checkout-local setup

Worktrunk passes hook context JSON on stdin, including fields such as `worktree_path` and `branch`.

Skip hooks for a one-off creation:

```sh
w new my-branch --no-verify
```
