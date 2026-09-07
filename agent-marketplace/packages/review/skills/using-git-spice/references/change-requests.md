# Change requests

Use this reference for forge-facing work. Submission and merge are remote
operations; run them only when the user asks.

## Authentication

Check login before the first remote operation:

```bash
git-spice auth status --no-prompt
```

A non-zero result means the forge is logged out. Stop and ask the user to run
the interactive `git-spice auth login` once. When the user chooses a
session-only fallback, prefix commands with
`GITHUB_TOKEN="$(gh auth token)"`; do not make that the default.

## Preview and submit

Inspect the stack and clear every relevant `(needs restack)` marker before
submission. Preview the narrowest intended scope:

```bash
git-spice branch submit --fill --dry-run --no-prompt
git-spice upstack submit --fill --dry-run --no-prompt
git-spice downstack submit --fill --dry-run --no-prompt
git-spice stack submit --fill --dry-run --no-prompt
```

Dry-run still resolves a real forge repository; a local file remote cannot
exercise submission.

Use `--fill` to derive first-submit titles and bodies from commits. For one
branch, `--title` and `--body` override them. Add `--label`, `--reviewer`, and
`--assign` only when requested. Managed config makes new change requests
drafts. Without an explicit draft flag, updating an existing change request
does not alter its draft status.

Use `--update-only` when every targeted branch must already have a change
request. Use `--no-publish` only when the user requests a push without
creating one. Submit bases before their descendants; `downstack submit`
provides bottom-up scope from a higher layer.

After the preview is correct, repeat the same command without `--dry-run`.
Treat `--force` as both a force-push and a bypass of safety checks. Keep the
restack check enabled; use force only on explicit request after verifying the
remote and deliberately pinned base.

## Merge

Choose the smallest requested queue:

```bash
git-spice branch merge --method=<method> --ready-timeout=<duration> --merge-timeout=<duration> --no-prompt
git-spice downstack merge --method=<method> --ready-timeout=<duration> --merge-timeout=<duration> --no-prompt
git-spice stack merge --method=<method> --ready-timeout=<duration> --merge-timeout=<duration> --fail-fast --no-prompt
```

Methods are `merge`, `squash`, and `rebase`. A zero ready timeout checks once;
otherwise the command waits up to the chosen duration for each change request.
The merge timeout bounds completion after each request is sent.

Branch scope can take repeated `--branch` values. Downstack merges bottom-up
and updates each next change request after its base lands. Stack scope
continues independent sibling branches after a failure by default;
`--fail-fast` stops the queue at the first failure. Keep stale-base validation
enabled.

## Read state

For machine-readable inspection:

```bash
git-spice log short --json
git-spice log short --all --json
```

Stdout is a stream of JSON objects in unspecified order. Parse records rather
than relying on line order. Human-readable `WRN` lines are informational when
the operation succeeds; verify the requested end state before treating a
warning as harmless.

## Observed failures

| Failure text or state | Recovery |
| --- | --- |
| `Branch X needs to be restacked`; `refusing to submit outdated branch` | Restack the intended scope, verify the marker is gone, then resubmit. |
| `base branch has not been submitted yet` | Submit bottom-up with `downstack submit` or start from the base. |
| `No commits between X and Y` | Inspect branch order and commits; retarget or ask before deleting an empty branch. |
| Merged change request but local SHA does not match | Confirm the merge, explicitly delete the skipped branch, then restack its descendants. |
| Detached HEAD | Check out the intended branch before running a branch-sensitive operation. |
| Branch is checked out in another worktree | Run the operation there; restack any skipped descendants from the worktrees that hold them. |
| Repository cannot initialize under `--no-prompt` | Resolve trunk and remote, then run explicit `repo init`. |
| Authenticator selection cannot prompt | Run `auth status`; ask for one-time login or the user-approved session token fallback. |
| Change-template listing times out with `WRN` | Check command success and resulting change requests; a warning alone is not failure. |
