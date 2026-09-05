---
status: active
doc_type: plan
owner: Prateek
created: 2026-09-05
updated: 2026-09-05
status_detail: "Code, Tart, and WinMux storage migrated; GhostPepper retained in place. Arq configuration deferred by Prateek."
related:
  - wiki-ingest-revisit-plan.md
  - ../runbooks/session-sync-permissions.md
---

# SSD layout and Arq coverage

The Samsung 990 PRO is one 2 TB physical SSD. Its `Code` and `TartVMs` APFS
volumes share that capacity. They mount at `~/code` and `/Volumes/TartVMs`,
respectively; their displayed capacities must not be added together.

## Current Arq selection

The active Arq 7.48 plan, “Back up to Arq Cloud Storage,” selects `/Users`
on the internal drive. `includeNewVolumes` is false, and neither SSD volume
has a separate selection. It runs every two hours with APFS snapshots,
`retainAll = true`, and a 500 GB budget. The last inspected backup finished
at 06:01 EDT on September 5 with zero reported errors, before the native
code-folder mount.

At 08:06 EDT, `arqc stats` reported 748 backup records and 474.4 GB stored,
about 25.6 GB below the plan's budget. The 08:00 backup was still running.

A successful internal-drive backup does not establish coverage of the new
SSD. Add the SSD explicitly and verify a restore from it. The session archive's oversized upload was recovered and published on September 5; GitHub publication does not replace Arq coverage of uncommitted work and other SSD data. Retain the recovery bundle under `~/code/.storage/recovery/archive-20260905/` until backup coverage and a restore have been verified.

## Agreed layout

Keep the native `~/code` mount and its existing volume UUID. Prefer supported
application paths and environment variables over symlinks.

[Host storage setup](../runbooks/host-storage.md) now reconciles the existing
code mount at the start of apply before target computation and destination
updates.

Code, Tart, and retained WinMux evidence now share the code volume. Prateek
chose to leave GhostPepper's models at their existing location, so `TartVMs`
remains mounted for that app.

```text
Code (APFS volume, mounted at ~/code)
├── github.com/…                       repositories and session archive
└── .storage/
    ├── artifacts/winmux/              retained test evidence
    └── vms/tart/                      disposable VM/cache storage
```

The machine's `tart_home` is
`/Users/prateek/code/.storage/vms/tart`. `TART_HOME` is exported in
`$ZDOTDIR/.zshenv`, which the home-directory bootstrap also sources. Preserve
an explicit caller override, but keep the configured SSD default even when
the drive is absent: unsetting it would make Tart try its internal `~/.tart`
default. VM scripts retain their external-volume guard and the internal code
mount point is protected. The `~/.tart` symlink has been removed.

GUI apps and launch agents do not read shell startup files. Tartelet already
has a native `tartHomeFolderURL` setting sourced from the same machine fact;
that setting now points at the new store. Fresh login, interactive, and
non-interactive zsh sessions were checked with `TART_HOME` cleared and
`ZDOTDIR` both set and unset.

`WINMUX_E2E_ARTIFACT_ROOT` is exported as
`/Users/prateek/code/.storage/artifacts/winmux`. The WinMux worktree's
`script/e2e/artifact-path` resolves historical `artifacts/e2e` citations through
this root. Its Make targets and evidence scripts use the same resolver.
The 5,459 retained files and links were copied and checked before removing
the original copy and the workspace symlink. Recordings, reviews, and
manifests retain their original bytes. Existing acceptance-check failures
remain historical issues, including stale source revisions and command formats.

GhostPepper remains at `/Volumes/TartVMs/prateek/models/GhostPepper`, with
its existing link from `~/Library/Application Support/GhostPepper`. This is
the agreed exception to the symlink preference. The app can create personal
state beside downloaded models, so exclude specific model subdirectories
from backups rather than its entire app-data root. The two APFS volumes
still share one physical 2 TB pool.

## Arq configuration

Keep the existing internal `/Users` selection and add the SSD volume rooted
at `~/code`, tracked by UUID `8C16DA8F-1B9B-4ADC-9C7D-EFA8FF8B15D7`.
Use Arq's folder selection UI to exclude `.storage/vms` and any named cache
directories added during the final migration.
Retain the existing standard generated-file exclusions for this selection.

| Data | Backup policy |
| --- | --- |
| Repository contents, uncommitted work, and `.git` | Include |
| Raw session archive and local unpublished commits | Include |
| Retained WinMux evidence | Include |
| Downloaded models and disposable VM/cache storage | Exclude their specific directories |

Add the retained `TartVMs` volume explicitly if GhostPepper contains personal
data, and apply model exclusions within it. Do not rely on
the internal `/Users` selection to cover a mounted external filesystem.

Use the existing two-hour schedule and review the plan's storage budget after
estimating the first SSD backup. Arq deduplicates data, so the new selection's
logical size is not its additional cloud-storage cost. The current budget is
close enough that its effect on retained history needs review before the
first backup. Configure a missing SSD to surface as a backup failure;
do not silently treat an absent code drive as an empty successful backup.

Arq supports [specific folder selections](https://www.arqbackup.com/documentation/arq7/English.lproj/createBackupPlan.html)
and [unchecking folders within a selection](https://www.arqbackup.com/documentation/arq7/English.lproj/excludeFiles.html).
Its [backup metadata](https://www.arqbackup.com/documentation/arq7/English.lproj/dataFormat.html)
records both mount points and disk identifiers.

## Validation

- [x] Copy and checksum retained Tart metadata and WinMux evidence before removing their original copies.
- [x] Resolve WinMux evidence paths and preserve GhostPepper's agreed location.
- [x] Verify shell paths, Tartelet's store setting, and missing-SSD behavior in isolated tests.
- [x] Verify native code mount and retained app paths.
- [ ] Add and reread Arq's explicit SSD selection and exclusions through its UI.
- [ ] Run an SSD backup and confirm the new selection appears in its records.
- [ ] Restore a source file, an archive file, and a WinMux evidence file into a temporary folder; compare their checksums.
- [ ] Confirm Arq snapshots are released and remeasure internal free space.
