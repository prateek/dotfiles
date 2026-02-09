# Codex agent notes (local)

This machine uses Git worktrees heavily. Prefer the `w` wrapper (Worktrunk-powered) so worktrees stay centralized and discoverable.

- Worktrees guide: `~/dotfiles/docs/worktrees.md` (link: [docs/worktrees.md](../dotfiles/docs/worktrees.md))

## Quickstart (`w`)

Create/switch + cd (repo picker by default):

```sh
w feature/auth
```

Create/switch + run an agent command (default agent: `$WT_AGENT_CMD` or `codex`):

```sh
w fix-bug -- 'Fix GH #322'
w run fix-bug --agent claude -- 'Fix GH #322'
```

Operate on a specific repo:

```sh
w feature/auth --here                 # current repo
w feature/auth --repo openai/openai   # canonical repo
w feature/auth --repo /path/to/repo   # explicit path
```

Find/clean up centralized worktrees:

```sh
w ls
w rm            # dry-run stale cleanup
w rm --yes      # apply stale cleanup
```

## OpenAI monorepo (`openai/openai`)

When asked to create a worktree for `openai/openai`, **prefer a sparse checkout** and keep it minimal: only the project(s)/dirs you need.

If the needed project(s)/dirs aren’t clear, ask for clarification before creating the worktree.

Example (sparse on creation):

```sh
w new my-branch --repo openai/openai --sparse api --sparse codex
```

Add more after creation (inside the worktree):

```sh
git sparse-checkout add docs
git sparse-checkout list
```

Venv:
- On worktree creation, dotfiles installs a per-worktree venv hook for `openai/openai`.
- Venv path: `~/.virtualenvs/openai-<branch_sanitized>`

## Git worktrees (manual)

Create:

```sh
git worktree add -b my-branch ../my-branch/$(basename "$(pwd)")
```

List/remove/prune:

```sh
git worktree list
git worktree remove /path/to/worktree
git worktree prune
```

## Sparse checkout (git)

Cone mode basics:

```sh
git sparse-checkout init --cone
git sparse-checkout set --cone -- api docs
git sparse-checkout add tools
git sparse-checkout list
git sparse-checkout disable
```
