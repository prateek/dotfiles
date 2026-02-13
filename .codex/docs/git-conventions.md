# Git Conventions (Skill-like)

## Purpose

Use this playbook for Git/GitHub workflows on this machine.

## When to use

- Creating/switching branches/worktrees.
- Working in `openai/openai`.
- Running GitHub CLI commands where identity selection matters.

## Defaults

- Prefer worktree-first workflow via `w` (Worktrunk wrapper).
- Prefer sparse checkout for `openai/openai`.
- Use wrapped `gh` and verify identity before sensitive operations.

## Authentication and remotes

- For OpenAI-owned repos, prefer SSH remotes (`git@github-openai:openai/<repo>.git` or `git@github.com:openai/<repo>.git`).
- Use Secretive + `am keysign` for OpenAI GitHub SSH auth.
- For device-code auth flows, use `oai_gh` (not manual browser/device-code URL flows).
- For non-OpenAI repos, OpenAI SSH certs do not apply by default.
- `chronosphere-openai` convention:
  - Default `origin` to `https://github.com/chronosphereio/chronosphere-openai.git`.
  - Keep optional `origin-ssh` only if using a separate non-OpenAI SSH key setup.
  - Do not add an `openai` remote by default.

## Workflow

### 1) Create/switch worktree (`w`)

- Create/switch + `cd` (repo picker by default):
  - `w feature/auth`
- Create/switch + run an agent command:
  - `w fix-bug -- 'Fix GH #322'`
  - `w run fix-bug --agent claude -- 'Fix GH #322'`
- Target a specific repo:
  - `w feature/auth --here`
  - `w feature/auth --repo openai/openai`
  - `w feature/auth --repo /path/to/repo`
- Worktree maintenance:
  - `w ls`
  - `w rm <branch>` (remove a selected worktree)
  - `w prune` (dry-run stale cleanup)
  - `w prune --yes` (apply stale cleanup)

Worktree reference:
- `~/dotfiles/docs/worktrees.md`

### 2) For `openai/openai`, keep sparse checkout minimal

When creating a worktree for `openai/openai`, prefer sparse checkout and keep it minimal.

- Create sparse worktree:
  - `w new my-branch --repo openai/openai --sparse api --sparse codex`
- Add dirs later (inside worktree):
  - `git sparse-checkout add docs`
  - `git sparse-checkout list`

Venv notes:
- Per-worktree venv is auto-installed by dotfiles hook.
- Path pattern: `~/.virtualenvs/openai-<branch_sanitized>`.

### 3) Use the `gh` wrapper correctly

This machine wraps `gh` to select GitHub identity automatically.

- Wrapper path: `~/bin/gh` -> `~/dotfiles/bin/gh`
- Identity signals (priority):
  - `-R/--repo`
  - current repo `origin`
  - some positional repo args (for example `gh repo clone owner/repo`)
- Force identity when needed:
  - `GH_WRAPPER_USER=prateek-oai gh ...`
  - `GH_WRAPPER_USER=prateek gh ...`
- Check active identity:
  - `gh api user -q .login`

Common failure:
- If you see `GraphQL: Could not resolve to a Repository ...`, retry with:
  - `GH_WRAPPER_USER=prateek-oai`

## Validation checklist

- Worktree created/switched via `w` (or explicitly justified otherwise).
- Sparse checkout used for `openai/openai`.
- `gh` identity verified before repo/PR operations.
