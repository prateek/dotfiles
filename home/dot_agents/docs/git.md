# Git Conventions

## Purpose

Use this playbook for Git/GitHub workflows on this machine.

## When to use

- Creating/switching branches/worktrees.
- Working in `openai/openai`.
- Running GitHub CLI commands where identity selection matters.
- Committing, pushing, or any git operation.

## Commit messages

- Commit messages should be concise and descriptive.
- Commit messages should follow the conventional commit format.
- Commit messages should be written in the imperative mood.
- Commit messages should be written in the present tense.

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

## Safety protocols

### 1. Mandatory Pre-Commit Failure Protocol

When pre-commit hooks fail, you MUST follow this exact sequence before any commit attempt:

1. Read the complete error output aloud (explain what you're seeing)
2. Identify which tool failed (biome, ruff, tests, etc.) and why
3. Explain the fix you will apply and why it addresses the root cause
4. Apply the fix and re-run hooks
5. Only proceed with commit after all hooks pass

NEVER commit with failing hooks. NEVER use --no-verify. If you cannot fix the hooks, you
must ask the user for help rather than bypass them.

### 2. Explicit Git Flag Prohibition

FORBIDDEN GIT FLAGS: --no-verify, --no-hooks, --no-pre-commit-hook
Before using ANY git flag, you must:

- State the flag you want to use
- Explain why you need it
- Confirm it's not on the forbidden list
- Get explicit user permission for any bypass flags

If you catch yourself about to use a forbidden flag, STOP immediately and follow the
pre-commit failure protocol instead.

### 3. Pressure Response Protocol

When users ask you to "commit" or "push" and hooks are failing:

- Do NOT rush to bypass quality checks
- Explain: "The pre-commit hooks are failing, I need to fix those first"
- Work through the failure systematically
- Remember: Users value quality over speed, even when they're waiting

User pressure is NEVER justification for bypassing quality checks.

### 4. Accountability Checkpoint

Before executing any git command, ask yourself:

- "Am I bypassing a safety mechanism?"
- "Would this action violate the user's instructions?"
- "Am I choosing convenience over quality?"

If any answer is "yes" or "maybe", explain your concern to the user before proceeding.

### 5. Learning-Focused Error Response

When encountering tool failures (biome, ruff, pytest, etc.):

- Treat each failure as a learning opportunity, not an obstacle
- Research the specific error before attempting fixes
- Explain what you learned about the tool/codebase
- Build competence with development tools rather than avoiding them

Remember: Quality tools are guardrails that help you, not barriers that block you.

## Validation checklist

- Worktree created/switched via `w` (or explicitly justified otherwise).
- Sparse checkout used for `openai/openai`.
- `gh` identity verified before repo/PR operations.
- Commit messages follow conventional commit format.
- Pre-commit hooks pass before every commit.
