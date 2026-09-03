---
status: active
doc_type: research
created: 2026-09-03
updated: 2026-09-03
related:
  - ../adr/0012-config-gating-convention.md
---

# macOS Defaults: Sources And Verified Facts

Background for the next rework of `home/.chezmoitemplates/macos-defaults.sh.tmpl`.
Sources to read first, then facts verified on real hardware so they do not
have to be re-derived. Most of the template descends from the 2014-era
dotfiles collections, and several of its keys predate Apple Silicon.

## Sources to investigate

- [joeyhoer/starter](https://github.com/joeyhoer/starter): per-app scripts
  with current key encodings. Its
  [`apps/activity-monitor.sh`](https://github.com/joeyhoer/starter/blob/master/apps/activity-monitor.sh)
  documents the `ShowCategory` mapping (100 All Processes, 101 All Processes
  Hierarchically, 102 My Processes, 103 System, 104 Other User, 105 Active,
  106 Inactive, 107 Windowed). Worth mining for the rest of the app layer.
- `man pmset` on the target machine, plus `pmset -g cap`, which lists the
  power settings the hardware actually supports. The man page is authoritative
  for `hibernatemode` (0 desktops, 3 portables, 25 hibernate only) and for
  `standbydelaylow` / `standbydelayhigh` / `highstandbythreshold`.
- Apple's Activity Monitor and Sound settings guides do not publish the
  integer encodings; community sources do. Verify each key by changing it in
  the UI and reading it back with `defaults read`.

## Verified 2026-09-03 on an M4 Pro MacBook (macOS 26)

- `com.apple.ActivityMonitor ShowCategory`: `100` shows All Processes. `0`
  also shows All Processes and the app rewrites it to `100` on quit, so `0` is
  a legacy value the app no longer recognises.
- `com.apple.ActivityMonitor OpenMainWindow`: app state, not a preference.
  The app rewrites it on quit (`1` if the main window was open). Pinning it
  achieves nothing; the template no longer sets it.
- `pmset -g cap` lists `standby` and `hibernatemode` but no `standbydelay`,
  `standbydelaylow`, `standbydelayhigh`, or `autopoweroff`. Apple Silicon
  hibernates only when the battery is low, and the delay is not tunable. The
  Intel-era `standbydelay 86400` line was a no-op and is gone.
- `hibernatemode`: Apple's defaults are 0 on desktops and 3 on portables.
  Forcing 0 on a laptop drops the sleep image (up to RAM size, 48 GB here)
  and loses open work if the battery empties during sleep. The template no
  longer forces it. A laptop already set to 0 returns to the default with
  `sudo pmset -a hibernatemode 3`.
- Startup chime: Apple Silicon reads `StartupMute` (`%01` muted, `%00`
  audible), which System Settings > Sound > "Play sound on startup" writes.
  `SystemAudioVolume` is the Intel key and is ignored. The template now writes
  `StartupMute`.
- `com.apple.TextEdit` container preferences are readable by the user without
  Full Disk Access; an empty dictionary means the keys are unset, not blocked.
- The `sleep 0 standby 0 autopoweroff 0` line is guarded to machines without an
  internal battery and never runs on a MacBook.
