---
name: disk-usage-audit
description: Audit disk usage holistically, explain where storage is going, and rank cleanup candidates by size, reversibility, recency, and risk. Use when Codex needs to free space, investigate low disk warnings, map large directories or files, review cloud-sync policy, identify stale apps or app data, or distinguish safe-to-delete generated artifacts from active personal data on macOS, Linux, or similar environments.
---

# Disk Usage Audit

Build a storage map before deleting anything. Optimize for three outcomes:

1. Explain where the disk is actually going.
2. Identify the biggest low-risk wins.
3. Separate generated or synced data from active unique data.

Prefer harness-native shell tools for measurement. Adapt commands to the environment, but favor fast primitives such as `df`, `du`, `find`, `ls`, and `stat`.
On macOS, when APFS clones or snapshots can distort `du`, use [`scripts/apfs_usage_audit.py`](scripts/apfs_usage_audit.py) for clone-aware validation before recommending deletion.

Recommended commands on macOS/APFS:

- `uv run python scripts/apfs_usage_audit.py volume-summary /System/Volumes/Data --json`
  - true free and used bytes plus snapshot count
- `uv run python scripts/apfs_usage_audit.py validate-top ~/Library --depth 1 --top 8 --json`
  - fast hotspot discovery using `gdu` when available, followed by clone-aware validation for the top candidates
- `uv run python scripts/apfs_usage_audit.py path-summary ~/Library/Developer/CoreSimulator --json`
  - immediate reclaim lower-bound for a specific cleanup target

Read [references/common-buckets.md](references/common-buckets.md) when you need platform- or provider-specific search targets.

## Safety Rules

- Start non-destructively. Measure first, delete second.
- Verify current free space up front and again after each cleanup pass.
- Treat these as high risk unless the user explicitly approves removal:
  - Source trees and working directories
  - Personal documents, photos, recordings, and archives
  - Browser profiles and app state with unclear consequences
  - Anything that looks like the source of truth rather than a cache or mirror
- Favor these as low risk:
  - Caches
  - Build outputs
  - Simulator runtimes and derived data
  - Package caches
  - Container images, stopped containers, and build cache
  - Cloud-backed local copies that can be made online-only

## Measurement Model

Keep three measurement layers separate:

1. `True volume usage`
   - Use `df`, `diskutil`, or `scripts/apfs_usage_audit.py volume-summary`.
   - This is the source of truth for free and used bytes.
2. `Logical hotspot discovery`
   - Use `du` or `scripts/apfs_usage_audit.py validate-top`.
   - This is fast and good for ranking candidates, but APFS clones can overstate physical ownership.
   - Prefer `validate-top` over raw `du` on macOS because it preserves both the discovery size and the validated reclaim signal.
3. `Clone-aware reclaim validation`
   - Use `scripts/apfs_usage_audit.py path-summary` for a specific path, or `validate-top` to do a fast `du` pass followed by clone-aware validation.
   - Treat `reclaimable_bytes` as an immediate reclaim lower-bound.
   - If the tool reports `fully contained clone groups`, whole-path reclaim may be higher than the lower-bound because the entire clone group lives inside the candidate.

## Workflow

### 1. Establish the baseline

- Measure total free space on the relevant volume.
- On macOS, prefer `scripts/apfs_usage_audit.py volume-summary /target/path --json` so you also capture snapshot count and clone/snapshot support.
- Measure the largest top-level directories in the user home directory.
- Measure the largest system-level buckets that commonly hide storage usage, especially developer runtimes and container storage.
- Call out measurement blind spots when the OS blocks access.

### 2. Build a storage map

Group findings into categories instead of dumping one long file list.

- System and developer artifacts
- App bundles
- App support and container data
- Cloud-sync local copies
- Package-manager and tool caches
- User hidden directories
- Code and project trees
- Downloads, media, and archives

For each category, name the largest subpaths and sizes.

### 3. Classify each large item

Use these classes:

- `generated/rebuildable`
  - Caches, indexes, build products, simulators, package artifacts
- `synced but cold`
  - Dropbox, Google Drive, iCloud, OneDrive, mirrored folders, offline copies
- `dormant app + leftovers`
  - App bundle plus support data with weak evidence of recent use
- `active unique data`
  - Current project state, recordings, notes, archives, personal files
- `stateful but ambiguous`
  - Browser profiles, local LLM state, app databases, Electron storage

### 4. Rank candidates heuristically

Score each candidate on:

- `size`
- `reclaimable bytes`
- `reversibility`
- `recency`
- `offline need`
- `blast radius`

The best candidates are usually:

- Large
- Rebuildable or cloud-backed
- Not obviously recent
- Narrow in scope
- Easy to verify after removal

### 5. Inspect provider and harness policy

Do not treat cloud or agent tooling as ordinary files. Ask:

- Is this data mirrored locally or only partially cached?
- Can specific folders be made online-only?
- Can offline pinning be disabled?
- Is a large local cache owned by a package manager, container runtime, browser, editor, or agent harness?

When recommending provider settings or product-specific policy changes, verify current guidance from official docs.

### 6. Execute cleanup in passes

Use small, explainable passes rather than one giant deletion.

- Pass 1: caches and generated artifacts
- Pass 2: container and simulator cleanup
- Pass 3: dormant apps and orphaned support data
- Pass 4: sync-policy changes for mirrored folders
- Pass 5: ambiguous app state only with explicit user approval

Before each destructive pass:

- State exactly what will be removed.
- Name expected reclaim.
- Note any meaningful risk.
- On macOS, validate large APFS candidates with `scripts/apfs_usage_audit.py path-summary /path --json` or `validate-top` so you can distinguish logical size from immediate reclaim.

After each pass:

- Verify target paths are gone or reduced.
- Re-measure free space.
- Note leftovers that did not shrink because they require product-specific compaction or reset.

## Reporting Format

Always provide both:

1. A `cleanup candidates` view
2. A `where the space is` view

The `cleanup candidates` view should include:

- path
- size
- validated reclaim if available
- class
- why it is a candidate
- recommended action
- risk level

The `where the space is` view should describe the major buckets even if they are not cleanup targets.

Use language like:

- `safe generated data`
- `synced local copy`
- `likely stale`
- `active app state`
- `personal source-of-truth data`

## Good defaults

- Prefer policy changes over deletion for cloud-sync folders.
- Prefer uninstall plus leftover cleanup over deleting app data while leaving an unused app installed.
- Prefer category summaries over giant path dumps.
- On macOS, use the clone-aware tool before claiming that a large APFS path will free space.
- On macOS, let `validate-top` do the first pass because it already chooses `gdu` when available and avoids redundant nested candidate validation.
- Surface surprising hidden directories such as package caches, agent directories, editor extensions, and toolchain stores.
- Be explicit when a cleanup command targeted a different provider or context than expected.

## Common failure modes

- Deleting browser or app state just because it is large.
- Missing hidden directories in the user home directory.
- Confusing Docker Desktop, OrbStack, Colima, and other container providers.
- Treating cloud-sync folders as ordinary local folders without checking mirror or online-only policy.
- Reporting only deletable data and not the full storage picture.
- Assuming a sparse disk image shrinks automatically after in-guest deletion.
