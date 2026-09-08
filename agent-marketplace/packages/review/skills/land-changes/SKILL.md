---
name: land-changes
description: Land a finished branch as one commit, or manage repository landing defaults. Use for "land it", "ship this branch", or "push to main". Checks repository policy and recent human-review history before choosing direct landing or the review workflow.
argument-hint: "[--review-gate=auto|skip|confirm] [--tests=run|skip] [--deploy=true|false] [--save-defaults | --show-defaults | --reset-defaults]"
---

# Land changes

Publish the requested change as one commit on the destination's integration
branch. A landing request authorizes preparation and publication when the route
below permits it. Editing this skill does not authorize a land.

## 1. Resolve the destination and options

Read the repository's contribution/agent guidance and landing runbook. Discover:

- `WT`: `git rev-parse --show-toplevel` from the current directory; `BRANCH`:
  its symbolic branch. The worktree list below locates only the target checkout.
- `REMOTE`: the intended publishing remote. Inspect tracking, push configuration,
  and effective fetch/push URLs; both must resolve to the same destination repo.
  Resolve ambiguous, mirrored, or multiple push destinations before mutation.
- `TARGET`: the user's named branch, otherwise that destination's live default
  from `git ls-remote --symref "$REMOTE" HEAD` or hosting metadata.
- The destination's canonical host/repository identity, including SSH aliases.

Read [options](references/options.md) and run its helper with this identity and
`TARGET`. Report effective values and their sources. Show/reset requests finish
here, without requiring a clean worktree or preparing a landing.

## 2. Establish the change and local state

Require an existing remote target, a source branch distinct from `TARGET`, clean
worktrees (including untracked files), and no Git operation in progress. Finish
remaining authorized task edits first; preserve edits belonging to other work.
Find any target checkout by its `branch refs/heads/$TARGET` record in
`git worktree list --porcelain -z`, preserving paths with spaces. Check that
checkout too; leave `MAIN` unset if none exists. Record its branch and tip.

Fetch the target and keep its immutable starting point:

```sh
git -C "$WT" fetch "$REMOTE" "refs/heads/$TARGET"
BASE="$(git -C "$WT" rev-parse FETCH_HEAD)"
```

Any local target branch must equal or be an ancestor of `BASE`; investigate
local-only target commits before proceeding. Inspect `BASE..HEAD`, the full
proposed diff, and available stack/PR metadata. Account for every change against
the user's requested scope before rewriting. Branch refs are clues: deleted
refs can hide dependencies and stale refs can resemble them. Resolve unrequested
ancestral work through the user or the repo's stack workflow before including it.

When `deploy=true`, identify the repository's documented deployment command,
environment, and source checkout/artifact now. Resolve missing deployment scope
before publication; finish independent preparation while that decision remains.

## 3. Choose the landing route

Verify the authenticated publishing identity, destination write permission,
live branch policy, and any open PR for this source and target. On GitHub read
[GitHub evidence](references/github-review-evidence.md); on other hosts use their
native equivalents. Policy visibility failures remain unknown.

For `review_gate=auto` or `confirm`, inspect [review history](references/review-history.md).
For `review_gate=skip`, omit that scan and report the explicit/saved history waiver. The
waiver covers historical review only; policy, existing PRs, and scope still apply.

Use the first applicable route:

| Condition | Route |
| --- | --- |
| Mandatory PR/review/queue rules with no permitted direct path for this caller | Run the selected checks and report unmet requirements to the user. Stop this procedure with the PR/review work pending. |
| Direct push needs a protection bypass; this branch has an open PR; repository guidance requires review; or policy remains unknown | Resolve that specific direct-landing decision with the user. |
| Effective `review_gate=confirm` | Request a direct-landing decision for this invocation, even if history permits it. |
| Effective `review_gate=skip` | Direct landing is authorized by the history waiver. |
| Human-review signals, collaborative history, or incomplete review evidence | Resolve a direct-landing exception with the user. |
| Complete history sample, confirmed solo workflow, no human-review signals, and policy allows direct push without bypass | The landing request authorizes direct publication. |

Reuse explicit decisions that cover this repo, change, and current conditions,
including standing decisions. An explicit `confirm` requests a fresh decision.
A generic "land it" does not acknowledge newly discovered review or bypass facts.

## 4. Prepare the result before asking

For an accepted scope on a private branch, complete the preparation below. For
an active PR, run the selected checks on the current diff and use the decision presentation
at the end of this step before rewriting its history.

Record `ORIGINAL` as the source tip, then rebase onto `BASE`. Resolve conflicts
when the intended result is clear. If a conflict remains ambiguous, save useful
resolution edits outside the worktree, including conflicted file contents, then
`git rebase --abort`. Verify the original tip, clean status, and no remaining
operation. If saving or aborting fails, preserve the current state and report
recovery paths; do not reset away work.

After rebase, zero remaining commits means the change is already present. For
multiple commits, squash non-interactively with `git reset --soft "$BASE"` and
`git commit -F "$MESSAGE_FILE"`. Use the repository's commit style, preserve
required attribution/trailers, and retain signing and hooks. Require exactly one
commit whose sole parent is `BASE`.

For every route, select validation from the changed paths, repository test index,
task runner, and CI. With `tests=run` (default), run the relevant test suites.
With `tests=skip`, omit the skill's test-suite runs and identify them in the report;
use documented non-test components of combined check commands. Keep relevant
non-test checks, such as lint, type checking, and builds. Git hooks and required
CI remain in force even when they run tests; this option does not bypass them.
Always run `git diff --check "$BASE..HEAD"` against the final committed result.
Fix failures in checks that run, restore the one-commit invariant, and rerun
affected checks. Record `LAND` after selected checks pass and the worktree is
clean; `LAND` is the exact SHA proposed for publication.

Present the destination, scope, check results, and relevant review evidence,
unknowns, or bypass. Ask only for unresolved publication/deployment decisions,
identifying this skill's applicable gate; reuse decisions already established.
Continue after the required decisions are resolved.

## 5. Publish the exact commit

Recheck `LAND`, clean local state, destination URLs/identity, target checkout,
and live policy immediately before publication. Read the remote target again.
If it differs from `BASE`, refetch and repeat scope, route, preparation, and
checks against the new base. Reuse decisions only while their scope still fits.
Stop after two publication attempts if the target keeps moving.

```sh
git -C "$WT" push --no-follow-tags "$REMOTE" "$LAND:refs/heads/$TARGET"
git -C "$WT" ls-remote --exit-code "$REMOTE" "refs/heads/$TARGET"
```

Use a normal fast-forward push with hooks and protections intact, never a force
push. Verify the live remote, not just a tracking ref. Equality with `LAND`
confirms publication; if the remote advanced again, fetch and establish whether
it contains `LAND`. After a transport error, inspect remote state before retrying:
the push may have succeeded. Diagnose other rejections from their actual errors;
permission or policy failures are not concurrent updates.

## 6. Synchronize and report

Only after confirmed publication, recheck that `MAIN`, when present, is clean,
on `TARGET`, at its recorded tip, and has no Git operation in progress. Then
`git -C "$MAIN" merge --ff-only "$LAND"`. If that check or update fails, preserve
the checkout and report the successful remote land separately. With no target
checkout, leave the local target branch alone and report it as unsynchronized.
Keep worktrees and branches unless their cleanup was separately requested.

Run the repository's documented read-only post-landing preview. With
`deploy=true`, execute the agreed deployment after verifying its source matches
`LAND`; a failed local sync must be resolved before deploying from that checkout.
The explicit flag or saved default authorizes this documented deployment scope.
Report deployment failure separately from publication and inspect its state before
retrying. With `deploy=false`, finish after the preview; applying configuration
or releasing software requires its own request.

Report the commit and destination, review-gate conclusion, passed/failed/skipped
checks, observed remote/local state, and deployment outcome when enabled. Skipped
tests are not passing tests.
