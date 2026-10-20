# Direct Git landing

Use this branch for a normal fast-forward update. The entrypoint's selected checks,
hook choices, policy decisions, and follow-up scope govern this procedure.

## Prepare the candidate

Resolve `WT`, `REMOTE`, and `TARGET` to the chosen preparation checkout, publishing
remote, and existing target. Verify every effective fetch/push URL belongs to the
intended destination; resolve mirrored or multiple destinations before mutation.
Use braced variable expansions in refspecs: zsh interprets `$LAND:r` as a modifier.

Resolve hook controls before any hook-triggering operation, including rebase and
checkout. `--no-verify` does not disable every hook: `prepare-commit-msg` still
runs. When the user explicitly skips all local Git hooks, use command-scoped
`git -c core.hooksPath=/dev/null ...` for the relevant operations on macOS/Linux.
For an individual hook, use its supported narrower control or report coupling.
Keep repository/global configuration and signing unchanged. Consult native
[hook semantics](https://git-scm.com/docs/githooks) and
[core.hooksPath](https://git-scm.com/docs/git-config#Documentation/git-config.txt-corehooksPath)
when resolving a control on another platform or hook manager.

Account for the scoped change and dependencies before rewriting. Starting on the
target or with unrelated edits is allowed: create isolated preparation when needed,
carrying only the requested change. Rewriting requires a clean preparation checkout
and a private source branch, distinct from the target, with no Git operation active.
Use the repository's stack/PR procedure for a shared branch instead of resetting it.

Locate any target checkout by its exact branch record in `git worktree list
--porcelain -z`, preserving paths with spaces. Record its branch and tip as `MAIN`
and its original state. Preserve a dirty or independently changing target checkout.

```sh
git -C "$WT" fetch "$REMOTE" "refs/heads/${TARGET}"
BASE="$(git -C "$WT" rev-parse FETCH_HEAD)"
```

An existing local target must equal or be an ancestor of `BASE`; account for any
local-only commits before changing that ref. Record `ORIGINAL` as the preparation
tip. Inspect `BASE..HEAD`, the full diff, and PR/stack metadata; branch names alone
do not prove that all ancestral work belongs to the request.

Rebase the private candidate onto `BASE`. Resolve clear conflicts. For ambiguous
conflicts, preserve useful resolution edits, including conflicted file contents,
outside the checkout before aborting. Verify the original tip and cleared operation
after abort. If preservation or abort fails, retain state and report recovery paths.

When no requested change remains, verify it is already present and return to the
entrypoint for any remaining authorized outcomes. Otherwise squash multiple commits
on this private candidate with `git reset --soft "$BASE"` and a prepared commit
message. Preserve attribution and signing; use only the hook controls selected in
the plan. Require one commit whose sole parent is `BASE` and whose diff matches scope.

Run the selected checks on the prepared revision. If repairs change it, restore
the one-commit invariant and refresh affected evidence under the resolved choices.
Record the final SHA as `LAND` only when publication's gates are satisfied or
covered by usable authorized exceptions. Retain recoverable original refs.

## Publish and verify

Recheck the candidate, destination identity/URLs, policy, and target checkout state.
Read the live target. A changed target requires refetching, rebuilding the candidate,
and refreshing affected evidence. Use at most two publication attempts per invocation;
a restart caused by target movement consumes an attempt even before a push is sent.
After repeated races, preserve the candidate and report the moving target.

```sh
git -C "$WT" push --no-follow-tags "$REMOTE" "${LAND}:refs/heads/${TARGET}"
git -C "$WT" ls-remote --exit-code "$REMOTE" "refs/heads/${TARGET}"
```

Apply any authorized local hook control through its supported command-scoped
mechanism; leave other controls intact. This procedure never force-pushes. Exact
refspec and `--no-follow-tags` keep publication limited to the intended branch.

Remote equality with `LAND` confirms publication. If the target advanced again,
fetch and establish whether it contains `LAND`. After a transport error, inspect
remote state before retrying: the push may have succeeded. Diagnose policy and
permission failures from their actual errors; they are not target races. A new
route must satisfy the entrypoint's existing authorization and gate requirements.

## Synchronize without overwriting

After confirmed publication, update `MAIN` only if it is clean, still on `TARGET`,
at the recorded tip, and has no Git operation in progress. Use `git -C "$MAIN"
merge --ff-only "$LAND"`. If those conditions or the update fail, preserve it and
report publication separately from unsynchronized local state. With no target
checkout, leave the local target branch alone.

Return the published SHA and local state to the entrypoint. Follow-ups must use
the verified revision or artifact; a failed sync cannot justify applying stale
checkout contents. Branch/worktree cleanup requires its own request.
