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
- Let hooks run by default and address their output before retrying. Honor an
  explicit scoped hook override as described below.

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

### Writing the description

The reader is a senior engineer you respect who has no context on this work
and little time. Every rule below follows from that.

- Say what the change is trying to achieve and why. Describe how only when the
  code does not show it.
- Lead with a summary the reader can check at a glance, then the detail for
  those who want to dig in.
- Include only what the review needs. Leave out investigation history, agent
  narration, and dead ends.
- Back performance and behavior claims with evidence: numbers, before and
  after screenshots, and links to traces, dashboards, or the incident that
  motivated the change.
- When asked to update a PR, rewrite the title and description from the
  current diff instead of patching the old text.

## Reviewing pull requests

Terms: the *review verdict* is the top-level body of a review; an *inline
comment* is attached to a line; a *draft comment* is either, before it is
posted, including crit comments.

Feedback goes to the same reader as a description: a respected engineer who
has not seen your investigation.

- Keep the verdict to a brief summary of what you think of the PR and at most
  one or two asks of the author. Do not retell the inline comments.
- Add a tl;dr to any comment longer than a paragraph.
- Ask politely instead of directing, and avoid harsh or judgmental wording.
- State a fact only after checking it. When in doubt, ask instead of telling.
- Link factual claims to permalinks or other citations so the author can
  verify them.
- Use GitHub suggestion blocks when proposing a concrete code change.
- Every posted comment carries the attribution footer described in the next
  section.

### Fresh-reader check

A *fresh reader* is a subagent started with none of this session's context,
briefed to read as the audience. Before delivering PR feedback anywhere
(chat, GitHub, or crit), run one:

1. Give it the draft comments, the diff, and the reader description above.
2. Ask it, as the PR author, which comments help and which do not, why, and
   what is unclear or unnecessary in each.
3. Apply its verdicts, then deliver.

Skip the check only when Prateek says to post as is, and say that it was
skipped. For other text that leaves the session (descriptions, docs, Slack
messages, handoffs), the check is available on request.

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

A user instruction or saved standing choice may explicitly skip hooks within its
recorded scope. Use only the supported command-scoped mechanism for that choice;
report exactly which hooks were skipped. Skipping test suites alone does not skip
hooks, signing, or required CI. If a control also skips unrequested hooks, resolve
that expansion before using it. Retain known failures; a skip never makes them pass.
Without a covering override, report an unresolved hook failure as a blocker.

## Completion

- The worktree and branch are the intended ones.
- The selected files contain only the authorized change.
- Repository contribution and commit conventions are satisfied.
- Required hooks/checks pass or have a recorded scoped exception; skipped and
  informational outcomes are reported separately.
- Every posted GitHub comment has exactly one attribution marker.
- PR feedback went through a fresh-reader check, or Prateek waived it and the
  handoff says so.
- No human reviewer received an unprompted agent reply.
