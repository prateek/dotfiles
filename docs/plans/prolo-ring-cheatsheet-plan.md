---
status: draft
doc_type: plan
owner: Prateek
created: 2026-10-06
updated: 2026-10-06
related:
  - ../../home/dot_agents/docs/infra.md
status_detail: "Phase 1 (renderer) and phase 2 (dotfiles profile, labels, run_after_48 hook, prolo_ring flag, just recipes) are built. Phases 3-4 pending; the design assumptions below still need Prateek's confirmation."
---

# Prolo Ring cheat sheet — plan

## Problem

The Prolo Ring has four modes, a Modstrip with seven system commands, and a flashed profile that maps about forty gestures to keys, media actions, mouse actions, and macros. Prolo's PDF cheat sheet shows the factory mappings. Ours will differ, and a key chord like `Meta+Space` means nothing on a card; what matters is what that chord does on this machine (Raycast, a Tuna leader, a Karabiner layer). Nothing today shows which mode the ring is in, so the first gesture after a mode switch is a guess.

## Goals

- One cheat sheet generated from the profile we actually flash, grouped by mode, including the fixed built-in gestures and the Modstrip system commands.
- Every assignable gesture labelled by what it does here, not just the chord it sends.
- The profile and labels live in dotfiles; `chezmoi apply` regenerates the sheet when they change and says when the ring still needs a Studio Import and Flash.
- A live view that highlights the ring's current mode and the last gesture it recognized, when the ring can tell us.
- Printable, and good enough to pin next to the monitor.

## Non-goals

- Flashing profiles from this pipeline. Studio flashes; see [prolo-ring/docs/flashing.md](https://github.com/prateek/prolo-ring/blob/main/docs/flashing.md).
- Reproducing Prolo's PDF. The sheet describes the gestures in our own words from the manual and our profile.
- A general keybinding inventory for the machine. Labels for ring gestures only.

## Architecture

Two homes, split by audience:

- **`prateek/prolo-ring`** (public) owns everything that understands the ring: the profile schema, the gesture catalogue, the renderer, and the live telemetry command. New surface: `prolo-ring cheatsheet render` and `prolo-ring watch`, later `prolo-ring cheatsheet serve`.
- **dotfiles** (this repo) owns our configuration and its apply-time plumbing: the profile JSON in Studio's import format, a labels file, the render hook, and a machine flag that gates it.
- **`prateek/infra`** keeps the device record and links to the generated sheet; it does not render anything.

### Source of truth

`home/dot_config/prolo-ring/profile.json`, in Prolo Studio's export format, so the same file is what gets imported into Studio. `home/dot_config/prolo-ring/labels.toml` adds the human meaning per gesture, keyed by the CLI's gesture names (`cursor.two_finger_tap`, `navigation.long_hold`), for example `label = "Raycast"` or `label = "Push-to-talk (Wispr)"`. Studio's `gestureAlias` is the fallback label; the raw chord is the last resort. Automatic lookup of chords in the Karabiner, Tuna, or Raycast configs is a later step, once the manual labels show which lookups would pay off.

### Rendering

`prolo-ring cheatsheet render --profile profile.json --labels labels.toml --format html|md` emits one sheet with a section per mode (Cursor, Navigation and ModNav, Touch and ModTouch, Air and AirTouch, System). Built-in gestures that profiles cannot change (cursor movement, clicks, edge scroll, joystick assist, the tap-and-hold system commands) are a static catalogue in the CLI, written from the manual in our words and tagged with the firmware version they describe. Gestures disabled by the profile's mode and group flags are shown dimmed, not hidden, so a missing gesture is explainable. The HTML prints cleanly to one or two pages.

### Apply-time plumbing

A `run_onchange_after_` script in `home/.chezmoiscripts/` keyed on the hash of the profile and labels renders to `${XDG_DATA_HOME:-~/.local/share}/prolo-ring/cheatsheet.html` and records the profile hash it rendered. The script is gated by a `prolo_ring` machine flag in `home/.chezmoidata/machines.toml` so other machines skip it, and it runs the CLI through `uvx` pinned to a tag of `prateek/prolo-ring`. It cannot know whether the ring carries this profile, so it prints a reminder when the hash differs from the last flashed hash, which a `just prolo-flashed` recipe records after a Studio flash. On firmware 1.0.7 `prolo-ring profile read` can replace the honour system by diffing the ring against the file; that is a `just prolo-verify` recipe, not an apply step, because it needs the ring in App Status.

### Overlay, like the keyboard sheets

Decided 2026-10-06 after two outside critiques and Prateek's steer: the default surface is not the web page but a per-mode card shown the way the keyboard nav-layer sheet is shown. `prolo-ring cheatsheet render --format svg --mode <mode>` draws a 600×420 card (rects, circles, text only, so NSImage renders it) with that mode's trackpad map, its Modstrip actions, and a switch-mode strip; `system` is the tap ladder and `all` tiles the four modes. The apply hook renders all six beside the HTML, and `~/.local/bin/prolo-cheatsheet` toggles the current mode's card through `keymap-overlay` without taking focus; `all`, `system`, and `html` expand. A small amount of good information by default; the two-page HTML stays as the print and deep-reference view. A hotkey for the toggle (Karabiner or Tuna) is Prateek's call.

### Live mode

`prolo-ring watch` connects in App Status and streams JSON lines: keepalive telemetry (battery, mode) every few seconds and each gesture event, including the Modstrip swipes that change mode. It also writes the current mode to `~/.local/state/prolo-ring/mode`, which is what `prolo-cheatsheet` reads to pick the card, so the overlay follows the ring as soon as the watcher runs.

The constraint is that Studio only talks to the ring in App Status, where it is not a mouse. Whether the gesture characteristic also answers in Device Status is untested and decides how useful live mode is day to day. The first task in that phase is that experiment: with the ring paired as a mouse, connect to the same peripheral and try `start_notify` plus a keepalive. If it answers, the live view works during normal use; if not, the live view is a training and verification aid used with the ring in App Status.

## Phases

1. **Static renderer** in `prolo-ring`: gesture catalogue, `cheatsheet render` for HTML and Markdown, tests from the factory profile. Independent of the ring.
2. **Dotfiles integration**: profile and labels files, the `run_onchange_after_` hook, the machine flag, `just prolo-cheatsheet` to open the sheet, `just prolo-flashed` to record a flash. Test with the render check described in `tests/README.md`.
3. **Device Status experiment**, then `prolo-ring watch` and `cheatsheet serve`.
4. **Verification on 1.0.7**: `just prolo-verify` diffing the ring's readback against the file. Blocked on the firmware update.

## Assumptions to confirm

- The browser is an acceptable first surface for the live view.
- Labels are hand-written in `labels.toml`; automatic chord lookup waits.
- The profile stays in Studio's JSON format rather than a TOML of our own, so Import needs no conversion step.
- The sheet is per machine type only if profiles diverge per machine; start with one profile.

## Open questions

- Does the custom GATT characteristic answer in Device Status? (Decides the value of live mode.)
- Which gestures do we actually want remapped for macOS first? Known clashes in the factory profile: two-finger tap sends Cmd+D, pinch sends Ctrl+= and Ctrl+-, Navigation long hold sends Ctrl+Cmd.
