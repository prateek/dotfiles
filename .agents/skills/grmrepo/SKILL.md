---
name: grmrepo
description: "Use git-repo-manager (GRM) on this machine via the `grmrepo` wrappers: refresh config from canonical clones, view status, and bootstrap a new machine by syncing repos."
---

# GRM on this machine (`grmrepo`)

This machine uses [git-repo-manager](https://github.com/hakoerber/git-repo-manager) (“GRM”) with a thin wrapper named `grmrepo` and a generated config file.

## Key conventions

- **Canonical clones** live under `~/code/github.com/<owner>/<repo>`
- **Exceptions**
  - `github.com/openai/openai` → `~/code/openai`
  - `github.com/chronosphereio/chronosphere-openai` → `~/code/chronosphere-openai`
- **Worktrees can be anywhere** and are *not* tracked by the GRM config here.

## Quick start

- Refresh the GRM config from local canonical clones:
  - `grmrepo refresh`
- Show status for all configured repos:
  - `grmrepo repos status`
- Bootstrap a new machine (clone everything in the config):
  - `grmrepo repos sync config`

## How it’s wired

- GRM binary: `~/.cargo/bin/grm`
- Wrapper: `~/bin/grmrepo` → `~/dotfiles/bin/grmrepo`
- Config: `~/.config/grm/config.toml` → `~/dotfiles/.config/grm/config.toml`
- Config generator: `~/dotfiles/bin/grmrepo-refresh`

### Why the config has one `[[trees]]` per owner

To keep `grm repos status` working with `owner/repo` naming, `grmrepo-refresh` emits one `[[trees]]` per GitHub owner and sets `name="<repo>"` inside that tree.

## Common workflows

### Add a new canonical repo

1. Clone into the canonical path (or use `ghc owner/repo`).
2. Run `grmrepo refresh`.

### Worktrees

- Create worktrees wherever you want (standard `git worktree add ...`).
- The repo’s *canonical clone* remains the thing tracked by GRM here.

### Keeping things in sync automatically

- Interactive shells trigger a best-effort background refresh (at most once/day).
- `git clone` / `git worktree {add,remove,prune}` trigger a background refresh.
- `gh repo clone/create` and `ghc` trigger a background refresh.

## Troubleshooting

- **Repo missing / “Run sync?”**
  - Your local clone isn’t in the canonical location *or* the config is stale.
  - Fix: move/standardize the clone, then `grmrepo refresh`.
- **`grmrepo repos status | head` panics**
  - `grm` currently panics on broken pipes; avoid piping to `head` (use a pager or redirect).
