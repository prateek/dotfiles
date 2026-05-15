# Git Conventions

## Purpose

Use this playbook for Git/GitHub workflows on this machine.

## When to use

- Creating/switching branches/worktrees.
- Running GitHub CLI commands.
- Committing, pushing, or any git operation.

## Commit messages

- Commit messages should be concise and descriptive.
- Commit messages should follow the conventional commit format.
- Commit messages should be written in the imperative mood.
- Commit messages should be written in the present tense.

## Writing prose for GitHub

GitHub renders markdown in PR descriptions, PR/issue/review comments, and issue bodies, and it word-wraps prose to the reader's viewport. **Do not hard-wrap text at a column boundary (80/100/120) when writing prose for these surfaces.**

- Write each paragraph as one long line, or one-sentence-per-line. Either is fine.
- Column wraps make the source ugly to edit and do not improve the rendered output.
- Applies to `gh pr create --body`, `gh pr comment --body`, `gh issue create --body`, `gh pr review --body`, and any heredoc piped into them.
- If you need a literal line break inside a paragraph, use Markdown's line-break syntax (two trailing spaces, or a trailing `\`) — not a column wrap.

## Templates and idioms

Before creating an issue, PR, or review comment, check whether the repo already has a convention to follow. Matching the local style beats inventing your own.

- Look for `.github/ISSUE_TEMPLATE/`, `.github/PULL_REQUEST_TEMPLATE.md` (or `pull_request_template.md`), and `.github/PULL_REQUEST_TEMPLATE/` for templates. Use them.
- If no template file exists, scan a few recent merged PRs or issues for the de facto shape (sections, checklist, labels, linked-issue syntax) and follow it.
- Check `CONTRIBUTING.md`, `.github/CODEOWNERS`, and any `docs/` contributor guide for required reviewers, labels, or commit/PR title rules (e.g. conventional-commit prefixes, ticket IDs).
- For `gh pr create` / `gh issue create`, pass `--template <name>` when a specific template applies; otherwise pre-fill `--body` to match the template structure rather than submitting an empty body.

## Defaults

- Prefer worktree-first workflow via `w` (Worktrunk wrapper).
- Use the wrapped `gh` (see below).

## Workflow

### 1) Create/switch worktree (`w`)

- Create/switch + `cd` (repo picker by default):
  - `w feature/auth`
- Create/switch + run an agent command:
  - `w fix-bug -- 'Fix GH #322'`
  - `w run fix-bug --agent claude -- 'Fix GH #322'`
- Target a specific repo:
  - `w feature/auth --here`
  - `w feature/auth --repo chronosphereio/monorepo`
  - `w feature/auth --repo /path/to/repo`
- Worktree maintenance:
  - `w ls`
  - `w rm <branch>` (remove a selected worktree)
  - `w prune` (dry-run stale cleanup)
  - `w prune --yes` (apply stale cleanup)

Worktree reference:
- [worktrees.md](worktrees.md)

### 2) Use the `gh` wrapper

This machine wraps `gh` via `~/bin/gh` → `~/dotfiles/bin/gh`. The wrapper passes through to the real `gh` and triggers a background `grmrepo-refresh` after successful `gh repo clone/create`.

- Wrapper path: `~/bin/gh` -> `~/dotfiles/bin/gh`
- Check active identity:
  - `gh api user -q .login`

If this machine ever needs multiple authenticated `gh` users again, the recommended shape lives in `docs/grmrepo.md` (section "Extending Back To Multiple `gh` Users").

#### Attaching files with `gh attach`

Use [`gh attach`](https://github.com/enthus-appdev/gh-attach) (a `gh` extension installed by this dotfiles repo) when a PR or issue benefits from a screenshot, mockup, log file, or other binary. Uploads land on auth-protected refs (`refs/uploads/issues/<N>` for PR/issue uploads, `refs/uploads/misc/<key>` for ad-hoc).

- Reach for it when:
  - Opening or commenting on a PR/issue and the prose needs an image (UI change, repro screenshot, before/after, design mockup).
  - Sharing a small artifact (log snippet, JSON dump, captured trace) inline rather than as a gist.
- Default behavior is print-markdown-to-stdout. It does **not** post a comment unless you pass `--comment`.
  - `gh attach <pr-or-issue> path/to/file.png` — print the markdown image tag for paste.
  - `gh attach path/to/file.png` — auto-detects the PR from the current branch.
  - `gh attach --comment <pr> screenshot.png` — upload and post as a comment.
  - `gh attach --title "<label>" <pr> file.png` — group uploads under a label (flags must precede the number).
  - `gh attach --key <slug> banner.png` — ad-hoc upload not tied to a PR/issue.
  - `gh attach --json <pr> file.png | jq -r '.files[0].url'` — script-friendly URL extraction (`--json` suppresses stderr on success; failures still write a plain-text error to stderr).
- Inspecting and reversing uploads:
  - `gh attach list` — show every upload ref in the current repo (use `--issues` / `--misc` to filter).
  - `gh attach get <pr> --output ./restored` — round-trip the uploaded files back to disk.
- Composing with the rest of the `gh` flow:
  - `screencapture -i -t png - | gh attach --name shot.png <pr> -` to grab and upload (`--name` is required when reading from stdin).
  - `gh attach <pr> file.png | gh pr comment <pr> --body-file -` to embed inside a longer comment body.
- Cleanup: PR/issue uploads can be auto-purged on close by copying `.github/workflows/cleanup-gh-attach.yml` from the upstream repo into the target repo's `.github/workflows/`; ad-hoc `--key` uploads need `gh attach delete --key <slug> --yes` (the `--yes` is required for non-interactive use, including any agent-driven invocation).
- Footgun for agents verifying their own uploads: on **private** repos the `blob/<sha>/<file>?raw=true` embed URL only resolves with a browser session cookie. PATs do not authenticate against it; use the parallel `gh api repos/<owner>/<name>/contents/<file>?ref=<sha>` endpoint instead.

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
- `gh` identity verified before repo/PR operations.
- Commit messages follow conventional commit format.
- Pre-commit hooks pass before every commit.
