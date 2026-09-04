# Git and GitHub Conventions

Use this document for branches, commits, worktrees, pull requests, issues,
reviews, and GitHub comments on this machine. Repository-local contribution
guidance takes precedence.

## Defaults

- Use an Orca worktree for isolated tasks. Read [worktrees.md](worktrees.md)
  before creating or configuring one.
- Use the real `gh` CLI for GitHub operations.
- Pass `-R <owner>/<repo>` when the current directory is not inside the target
  repository.
- Treat GitHub and remote Git mutations as authorized only when the current task
  requests them.
- Before changing GitHub state, verify the active identity with
  `gh api user -q .login`.
- Preserve uncommitted work you did not create. Use status and diffs as context,
  not permission to rewrite or revert it.

## Commits

- Commit only when Prateek asks.
- Inspect staged, unstaged, and untracked changes before selecting files.
- Follow the repository's commit style. When it expects conventional commits,
  use an imperative present-tense subject such as `fix: handle empty PR body`.
- Keep the subject concise; use the body for motivation or non-obvious context.
- Let hooks run and address their output before retrying.

## Pull requests and issues

Before writing a PR or issue:

1. Check `.github/` templates, `CONTRIBUTING.md`, `CODEOWNERS`, and contributor
   docs.
2. If no template exists, inspect a few recent accepted examples for the
   repository's de facto structure.
3. Match required sections, labels, reviewers, ticket syntax, and title format.
4. Use a heredoc for multiline `gh` bodies.

GitHub wraps rendered Markdown. Keep prose paragraphs on one line or use one
sentence per source line; do not hard-wrap them at a column boundary. Use
Markdown's explicit line-break syntax when a rendered break matters.

## GitHub comments on Prateek's behalf

A GitHub comment appears under Prateek's account, so attribution and reply
boundaries are part of the contract.

This section covers PR and issue comments, PR review bodies, inline review
replies, and any `gh api` write containing a comment body.

Within an authorized PR or issue task:

- Reply without another confirmation when addressing Prateek, a bot, or the PR
  author while Prateek is the reviewer.
- Treat accounts with `type: Bot` and comments carrying the marker below as
  bots.
- Draft replies to human reviewers for Prateek unless he named the comment,
  thread, reviewer, or URL and asked for the reply.
- A broad request to work a PR does not authorize replies to human reviewers.

Append this footer exactly once to every comment posted by an agent:

```md
<message>

---
_via Prateek's agent (`<tool-or-skill>`)_

<!-- agent-comment:v1 principal=prateek tool=<tool-or-skill> -->
```

Use a stable tool or skill name, not a model name. Keep the HTML marker because
other agents use it to distinguish agent-authored comments. If the host already
injects equivalent attribution, use the host footer rather than adding a
second one.

For images, logs, traces, and other artifacts, use the `github-attachments`
skill instead of inventing an upload path.

## Hook failures

When a commit hook fails:

1. Read the complete output and identify the failing tool and cause.
2. Explain the corrective change when it is not obvious.
3. Fix the cause and rerun the hook.
4. Commit only after the hooks pass.

Do not use hook-bypass flags such as `--no-verify`, `--no-hooks`, or
`--no-pre-commit-hook`. If the failure cannot be fixed within the task, report
the blocker instead of bypassing it.

## Completion

- The worktree and branch are the intended ones.
- The selected files contain only the authorized change.
- Repository contribution and commit conventions are satisfied.
- Hooks and requested checks pass with clean output.
- Every posted GitHub comment has exactly one attribution marker.
- No human reviewer received an unprompted agent reply.
