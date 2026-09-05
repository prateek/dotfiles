---
status: active
doc_type: runbook
owner: Prateek
created: 2026-09-05
updated: 2026-09-05
status_detail: "Removable-volume access and bounded uploads verified through launchd; hourly job restored."
related:
  - ../plans/agent-session-wiki-plan.md
---

# Session archive sync permissions

Moving `~/code` from the internal disk to an external SSD introduced macOS's
removable-volume privacy check. Mounting the SSD inside the home directory
does not remove that check. The previous plain-script launch agent could
access an ordinary internal code directory without this permission.

A read-only test in the user's `gui/501` launchd domain reproduced the failure
with the original script entry point. With the archive as its working
directory it exited 1, reporting `Current directory does not exist`. With
the internal home directory as its working directory it exited 2: `uv` could
not read the SSD-hosted script, reporting `Operation not permitted`. Merely
changing the working directory therefore does not fix access. The temporary
test job was unloaded afterward.

`Session Archive Sync.app` runs the existing archive script at
`~/code/github.com/prateek/wiki-agent-sessions/.agents/skills/session-sync/scripts/sync-sessions`.
It accepts no alternate command or script path and passes a small environment
to `uv`. The archive script retains its own lock and free-space guard.
Launchd still supplies the hourly schedule; the app supplies a distinct
identity for the removable-volume permission. It does not require root or
Full Disk Access for this setup.

Build or update the local app from the dotfiles checkout:

```sh
make install-session-sync-app
open -a "$HOME/Applications/Session Archive Sync.app" --args --check-access
```

Allow the app's removable-volume request. The access check runs the archive
script's read-only source listing through `uv` and Python. It does not sync or
push. Privacy & Security > Files & Folders contains the resulting permission.

Grant permission to the app, then use the access check to verify that `uv` and
Python inherit it. The permission applies to removable volumes generally;
the fixed command limits what the launcher runs, but this is not a per-folder
filesystem sandbox. A separate Full Disk Access grant to `uv` is not part of
this setup.

On September 5, 2026, the app's removable-volume grant was confirmed and
`--check-access` passed from a temporary job in the user's launchd GUI domain.
The hourly `com.prateek.wiki-sessions-sync` job is loaded again. Following the archive recovery below, a full run through this job completed successfully at 16:13 EDT, including mirroring, committing, and pushing. Its exit code was 0.

A read-only pack measurement found that bulk import `c7c1bd7` alone needs
2,689,104,315 bytes to push from `e7fc175` (about 2.50 GiB). GitHub's
[single-push limit](https://docs.github.com/en/get-started/using-git/troubleshooting-the-2-gb-push-limit)
is 2 GiB. Retrying or pushing those existing commits individually could not publish this import.

The unpublished import was recovered as ten batches capped at 500 MiB each. Git tree comparisons verified identical contents after each reconstructed original commit. All batches were published with normal fast-forward pushes; the largest measured pack was 318.7 MiB. The complete original history is preserved in `~/code/.storage/recovery/archive-20260905/before.bundle`, with a SHA-256 checksum beside it, and the local `recovery/pre-batched-sync-20260905` branch. The bundle was restored into a separate bare repository and passed `git fsck --full --strict`.

Archive commit `8454284` bounds future commits to 500 MiB, measures each outgoing pack, and stops above 1 GiB. It pushes each commit separately and clears pending uploads before mirroring more data. Server size rejections stop immediately rather than retrying, and the 75 GiB free-space guard runs before sync and again before each upload. Sixteen regression tests cover batching, retries, concurrent pushes, archive preservation, and free-space failures.

The launch-agent template points directly to the executable inside the app
bundle and starts from the home directory. The apply hook builds the app
before loading the job. An unchanged source digest preserves the installed
app and its signature.

Validate the scheduled context with the app's `--check-access` argument before
starting a full sync. Read the launchd log at
`~/.local/state/dotfiles/wiki-sessions-sync/sync.log`, then the archive's
`~/.local/state/wiki-agent-sessions/latest.json` for sync results. The archive's
session-sync skill defines the allowed recovery steps for Git failures.

Apple documents the [removable-volume usage description](https://developer.apple.com/documentation/bundleresources/information-property-list/nsremovablevolumesusagedescription)
and recommends an [app bundle for a launchd executable](https://developer.apple.com/forums/thread/758774?answerId=794648022)
so the system can identify the app for privacy controls.
