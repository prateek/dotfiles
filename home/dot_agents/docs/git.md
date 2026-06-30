# Git and GitHub

Use this playbook for Git and GitHub work on this machine: worktrees, commits,
pull requests, issue comments, reviews, and safety checks.

## Defaults

- Prefer a worktree-first workflow. Create worktrees with Orca through `ohc`, the
  Orca UI, or `orca worktree create`; see [worktrees.md](worktrees.md).
- Use the real `gh` CLI directly for GitHub operations.
- Verify the active GitHub identity before changing repository state:

  ```sh
  gh api user -q .login
  ```

## Worktrees

Start new tasks in an Orca worktree:

```sh
ohc <owner>/<repo> [orca worktree create options]
```

`ohc` clones through `ghc`, registers the repo in Orca, and creates the
worktree. Existing Orca-registered repos can also use the Orca UI or
`orca worktree create`.

Worktrees land at:

```text
~/code/worktrees/<repo>/<name>
```

Use [worktrees.md](worktrees.md) for the full workflow, including `orca.yaml`
setup hooks and `.orca/` overrides.

## Commits

- Use conventional commit format when the repo expects it, for example
  `fix: handle empty PR body`.
- Write the subject in the imperative mood and present tense.
- Keep the subject concise. Put context in the body when the change needs it.
- Inspect staged and unstaged changes before committing.
- Let hooks run. If a hook fails, follow the safety protocol below.

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

## GitHub CLI

Use `gh` for GitHub reads and writes from the terminal. Prefer explicit repo
arguments when you are not already inside the target repo.

Common reads:

```sh
gh pr view <number> -R <owner>/<repo> --json title,state,author,baseRefName,headRefName
gh pr checks <number> -R <owner>/<repo>
gh issue view <number> -R <owner>/<repo>
```

Common writes:

```sh
gh pr create --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"

gh pr comment <number> -R <owner>/<repo> --body "$(cat <<'EOF'
<comment>
EOF
)"
```

Use heredocs for multi-line bodies so Markdown stays readable in shell history
and command transcripts.

#### Attaching files with `gh attach`

To attach an image, screenshot, log, trace, or other artifact to a PR or issue (or share one inline instead of a gist), use the `github-attachments` skill, which wraps the `gh attach` extension and covers the commands, cleanup, and agent footguns.

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

- Worktree created/switched via Orca (`ohc`), or explicitly justified otherwise.
- `gh` identity verified before repo/PR operations.
- Commit messages follow conventional commit format.
- Pre-commit hooks pass before every commit.
