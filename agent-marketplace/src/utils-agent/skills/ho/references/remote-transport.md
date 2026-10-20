# Remote transport

A remote receiver sees none of this machine's paths, and Orca's CLI carries only
text. This file covers remote transport in [SKILL.md](../SKILL.md). `<dir>` is
the resolved brief directory, `<state>` is
`${XDG_STATE_HOME:-$HOME/.local/state}`, and `<source-head>` is the source HEAD
recorded in the brief. `<base>` is the remote worktree's base: the repo default
base, the `--base` ref, or for `--stack`, `origin/<branch>`. `<scan-base>` is the
fetched repo default base ref, independent of whether `origin/<branch>` exists.
Run git commands from the source repo root unless the caller supplies a clean
staging checkout. Copy repo-relative source files from that same root. Copy
explicit `--attach` files from their named paths after inspection, including
untracked attachments inside the original repo. A receiver step says when to
switch to the receiving repo.

## Collect the bundle

Direct copy and the transport branch move the same bundle. Before building it,
fetch `<scan-base>` and inspect the paths in outgoing commits, tracked changes,
untracked files, and the brief's `Transfer files`. Use `git log --format= --name-only
HEAD --not <scan-base>`, `git diff --name-only HEAD`, and `git ls-files -o
--exclude-standard` for the Git paths. If a credential file such as `.env`, a
private key, or a token store would enter the bundle, stop remote transfer. Do
not make an incomplete patch or archive by silently omitting it. Redact
sensitive text in the brief and copied files.

Confirm that every dirty or untracked path belongs to the handoff. If
unrelated work remains, stop remote transfer or use a clean staging checkout
as `hop` describes.

Then build the bundle in `<dir>`:

- Copy only paths under the brief's `Transfer files` heading. Other paths in
  the brief are state metadata. For source files, map the path relative to the
  original worktree onto the transport root, then copy it under `files/` with
  that relative path. Copy explicit `--attach` files from their named paths;
  place external ones under `files/external/` and rename basename collisions.
- For an independent target, if `git rev-list HEAD --not <base>` is non-empty,
  add `work.bundle` with `git bundle create <dir>/work.bundle HEAD --not <base>`.
  The receiver has `<base>`, so `git bundle verify` succeeds there. Skip the
  bundle for `--stack`, whose commits reach the receiver on the pushed branch.
- If tracked files differ from HEAD, add `uncommitted.patch` with `git diff
  HEAD --binary`. If untracked files exist, add `untracked.tar` with `git
  ls-files -o --exclude-standard -z | tar --null -T - -cf
  <dir>/untracked.tar`. Omit either artifact when its input is empty.

Rewrite the brief's paths to bundle-relative ones. Put the applicable restore
and verification steps below before the original next work action, with
`<source-head>` and the real paths filled in. The receiver's first action is to
restore the source state. Before either remote route, run `gitleaks git
--log-opts="HEAD --not <scan-base>"` on the source repo and `gitleaks dir <dir>
--max-archive-depth 2` on the finished bundle. A finding blocks transfer until
the payload is scrubbed and scanned again. Verify `work.bundle` locally when
present. These scans supplement the file inspection above.

For an **independent** handoff, leave the receiver's Orca worktree on its chosen
base. If `work.bundle` exists, verify it in that repo and fetch its HEAD into
`refs/ho/source/<id>` with `git fetch "<dir>/work.bundle"
HEAD:refs/ho/source/<id>`. Confirm that the fetched ref equals
`<source-head>`. If there is no bundle, confirm that `<source-head>` is already
available. To give the receiver an exact source snapshot without changing its
new branch, create `<dir>/source/` with `git archive <source-head> | tar -x -C
"<dir>/source/"`. From that directory, run `git apply --check` and then `git
apply` on `uncommitted.patch` when present. Extract `untracked.tar` there when
present. Stop if the commit, patch, or extraction cannot be verified; keep the
bundle for a retry. The receiver uses this snapshot as source context and makes
changes on its new branch deliberately.

For **`--stack`**, confirm that the receiving worktree's HEAD equals
`<source-head>`. Apply `uncommitted.patch` there only after `git apply --check`
passes, then extract `untracked.tar` there. Stop on a mismatch rather than
applying source-HEAD changes to another commit. Record which restoration steps
finished so a retry does not apply them twice.

A remote `--stack` also pushes the current branch to `origin`, whichever route
carries the bundle. The scan above compares HEAD with `<scan-base>`, which
exists even for an unpublished source branch. Fast-forward-push HEAD to
`refs/heads/<branch>` after the scan. A finding or a push that needs force
blocks the handoff; report it rather than trying another route.

## Direct copy

Find an SSH destination for the host. For an SSH target, try its `name` from
`host list`, which is usually the `~/.ssh/config` alias Orca imported. For a
paired server, try the environment name, then the `machineName` that
`orca host name --environment <name> --json` reports. A destination qualifies when
`ssh -o BatchMode=yes -o ConnectTimeout=5 <dest> true` succeeds.

Then copy, and confirm the copy landed:

```sh
remote_state=$(ssh <dest> 'printf %s "${XDG_STATE_HOME:-$HOME/.local/state}"')
ssh <dest> mkdir -p "$remote_state/ho/<id>"
rsync -a "<dir>/" "<dest>:$remote_state/ho/<id>/"
ssh <dest> test -r "$remote_state/ho/<id>/brief.md"
```

The prompt points at `$remote_state/ho/<id>/brief.md`. The bundle stays on the
two machines. If no destination qualifies or any command fails, try the
transport branch. Confirm the brief is readable before launching the receiver.

## Transport branch

An orphan branch `ho/<id>` on `origin` carries the bundle. The receiver
fetches it, verifies it, and deletes it.

**Confirm the destination.** The sender must push to the repository the receiver
fetches from. Compare the canonical form of `git remote get-url --push origin`
with the `gitRemoteIdentity.canonicalKey` of the project in `orca project list
--json`. A mismatch rules out this route.

**Publish.** Build an orphan commit from `<dir>` without touching the working
tree or index: with a temporary `GIT_INDEX_FILE`, run `add -A -f` with
`--work-tree=<dir>` so ignore rules cannot drop bundle files, then `write-tree`,
then `commit-tree -m "ho bundle: <id> [skip ci]"`. Push with
`git push origin "${commit}:refs/heads/ho/<id>"`. Confirm with `git ls-remote`
that the remote branch equals `<commit>` before launching the receiver. Keep
the braces: in zsh, `$commit:r...` applies the `:r` modifier and corrupts the
refspec.

**Bootstrap.** The prompt gives this one line with `<id>` and `<commit>`
substituted, then tells the receiver to read `$d/brief.md`. It pins the commit
and deletes the branch only after extraction checks out. If any check fails, the
receiver stops and reports rather than guessing.

```sh
d="${XDG_STATE_HOME:-$HOME/.local/state}/ho/<id>" && git fetch origin ho/<id> && test "$(git rev-parse FETCH_HEAD)" = <commit> && mkdir -p "$d" && git archive FETCH_HEAD | tar -x -C "$d" && test -f "$d/brief.md" && { test ! -f "$d/work.bundle" || git bundle verify -q "$d/work.bundle"; } && { git push origin --delete ho/<id> || echo "ho/<id> left on origin for the user"; }
```

This route fails when the destination check fails, a push is rejected (branch
protection, hooks, no write access), or the receiver cannot fetch.

## Ask the user

Every route above has failed and the receiver needs files, so ask the user how to
move them. Show each route's failure evidence. Offer only the routes that apply,
such as another SSH destination or remote the user names, or sending the brief
alone with a note of what it lacks. Stop until the user chooses a route, then
execute and verify it before launching the receiver.
