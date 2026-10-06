---
status: accepted
doc_type: adr
owner: Prateek
created: 2026-10-06
updated: 2026-10-06
related:
  - 0044-karabiner-sole-remapper.md
  - ../research/nocfree-lite-firmware.md
  - ../research/nocfree-community-usage.md
status_detail: "Keymap stored and applied to both connections on 2026-10-06; on-keyboard use of firmware layer 1 and its select mode not yet confirmed."
---

# ADR 0048 — The repo owns the NocFree keymap

## Context

[ADR 0044](0044-karabiner-sole-remapper.md) made Karabiner the only remapper
and said nothing in this repo depends on keyboard firmware layers. The NocFree
Lite still needs a firmware keymap: its Caps key has to send ⌃ when held and
Esc when tapped for the Karabiner nav layer's Caps+Space toggle, and its
top-left key has to send `` ` `` and not Grave-Escape, or the cheatsheet key
leaves the layer.

The keyboard keeps two keymaps, one on the halves for the cable and one on the
2.4G dongle. On 2026-10-06 the cable keymap had Prateek's edits and the
dongle's base layer was still stock, so the nav layer worked on the cable and
broke over 2.4G. Nothing recorded either keymap, and the Vial app edits one
connection at a time.

Prateek also wants the nav layer usable on a Mac without this repo's Karabiner
config, which only firmware can provide.
[NocFree Lite Firmware](../research/nocfree-lite-firmware.md) records why a
custom firmware build is not practical, which rules out firmware-driven layer
lighting; the keymap is the only thing that can change.

## Decision

- `scripts/keyboard/nocfree-lite.vil` is the source of truth for both
  keymaps. It uses Vial's `.vil` layout schema with QMK keycode names.
  `scripts/keyboard/nocfree-keymap apply` writes it over Vial raw HID to every
  attached connection and reads each key back; `--dry-run` prints the diff,
  `dump` captures a change made in the Vial app, and the tool fails when no
  NocFree is attached. It touches only the keymap. Applying is a manual step,
  not part of `chezmoi apply`.
- Firmware layer 1, held with right ⌃ (`MO(1)`), is a left-hand copy of the
  Karabiner nav layer for Macs without this config. The key right of the
  right Space is right ⌘.
- Select mode stays in Karabiner. Layer 1's left ⇧ is `LSFT_T(KC_F20)`, and a
  NocFree-scoped Karabiner rule turns the F20 tap into a select-mode variable
  that adds ⇧ to the moves the firmware layer sends.

This refines ADR 0044 and does not replace it. The Karabiner nav layer stays
primary, with the cheatsheet and lighting-free indicator it already has. The
firmware layer is a fallback that Karabiner does not need, except that F20 is
how its select mode reaches the Mac.

## Consequences

- Both connections carry one keymap, and a drift between them shows up as a
  dry-run diff instead of a broken nav layer.
- Firmware layer 1 has no select mode on a Mac without this config, because
  F20 does nothing there.
- Right ⌃ is gone: holding it gives layer 1, and Caps held is the board's ⌃.
- Keys moved to make room: F1 and F2 sit on layer 1's Y and U, and layer 1's
  left Space is Return, which leaves layer 2 and its bootloader key
  unreachable.
- Per-layer lighting stays out of scope until NocFree publishes the Lite's
  firmware source.
