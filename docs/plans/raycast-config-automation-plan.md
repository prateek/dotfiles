---
status: proposed
doc_type: plan
owner: Prateek
created: 2026-08-31
updated: 2026-08-31
related:
  - ../references/chezmoi-architecture.md
status_detail: "Deferred backlog. Nothing in flight; pick items off as they start to hurt."
---

# Raycast Config Automation

Managed today: the `com.raycast.macos` plist fragment
(`home/.chezmoitemplates/com.raycast.macos.plist.tmpl`, 18 keys), the script
commands under `home/dot_config/raycast/scripts/`, and the `orca-worktree` dev
extension plus its build script.

## Deferred TODOs

Preference keys worth adding to the plist fragment:

- `raycastGlobalHotkey` = `Command-49` (⌘-Space). The one key that makes a fresh
  machine feel wrong until fixed by hand.
- `showFavoritesInCompactMode` = `0`
- `showGettingStartedLink` = `0`
- `command-extension_launchd-monitor.menubar__<uuid>_activated` = `1` and
  `NSStatusItem VisibleCC extension_launchd-monitor_menubar__<uuid>` = `1`.
  Blocked on knowing whether the extension UUID is stable across installs; if it
  is per-install, these cannot be templated.

Do not port: `NSStatusItem Preferred Position …` (drifts on every menu bar
reshuffle), `permissions.folders.read:*`, onboarding and migration flags, window
frames, `raycastAnonymousId`.

Not reachable from the defaults domain:

- Store-extension installs. Eight are installed; the on-disk
  `extensions/<uuid>/` directories hold only an opaque `com.raycast.api.cache`,
  and identity lives in the encrypted `raycast-enc.sqlite`. A port list has to be
  read off the Extensions UI by hand.
- Per-extension preferences, including Launchd Monitor's `launchdLabels`
  (currently `com.prateek.wiki-sessions-sync`). Same encrypted store. This stays
  a manual bootstrap step.

## Rejected

- Vendoring store extensions into the repo — Prateek declined; it makes us the
  maintainer of code we do not own.
- A chezmoi external for `raycast/extensions` — the monorepo is ~17 GB and
  neither `git-repo` nor `archive` externals support a subdirectory filter.
- An overlay fragment alone (no fetch) — there is nothing on disk to merge into.
- `.rayconfig` export/import — an opaque encrypted blob with a manual import
  step, so it buys no more than a Time Machine restore.
