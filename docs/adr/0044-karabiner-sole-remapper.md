---
status: accepted
doc_type: adr
owner: Prateek
created: 2026-10-05
updated: 2026-10-05
related:
  - 0009-goku-karabiner-codegen.md
  - 0043-devbox-os-gating.md
  - ../plans/goku-karabiner-migration-plan.md
  - ../research/nocfree-lite-firmware.md
  - ../research/go60-layout-patterns.md
---

# ADR 0044 — Karabiner is the only keyboard remapper

## Context

[ADR 0009](0009-goku-karabiner-codegen.md) moved the Karabiner config to Goku EDN and
left one question open under "Future work": `home/dot_config/kanata/kanata.kbd` and the
Apple-internal rules in `karabiner.edn` both remapped the built-in keyboard, and the two
grabbers cannot run at once. Kanata stayed in the repo, chezmoi-ignored on other systems
and never started on macOS, with its own package entry and parser test.
[ADR 0043](0043-devbox-os-gating.md) still names kanata in its list of macOS-only app
config.

Two things settled it. The keyboard work that followed needed layers that behave the same
on the built-in keyboard and on external ones, with an on-screen indicator and a cheatsheet
that reflect the layer's state. And the firmware research for the external split keyboard
found that the Mac cannot ask a keyboard which layer is active, so a layer the Mac needs to
know about has to live on the Mac.

## Decision

Karabiner-Elements, compiled from `home/dot_config/karabiner.edn.tmpl`, is the only
keyboard remapper this repo manages.

- Kanata is removed: its config, its Homebrew formula entry, and its parser test. The
  deployed `~/.config/kanata` is listed in `.chezmoiremove`.
- Layers that the Mac must know about are Karabiner variables, defined once and ungated by
  device unless a rule is specific to one keyboard. The navigation layer is the first.
- Keyboard firmware may still carry its own layers, but nothing in this repo depends on
  them, and a firmware layer is not a substitute for the Karabiner one.

This closes the "Future work" item in ADR 0009 and makes the kanata entry in ADR 0043's
`.chezmoiignore` list obsolete. Both records are otherwise unchanged.

## Consequences

- One grabber, one source file, one compile step, and one host-tagged test
  (`tests/bats/config/karabiner.bats`).
- Layer behavior needs Karabiner on the machine. A keyboard plugged into a machine without
  this config has only its firmware layout.
- Features kanata has and Karabiner lacks, such as one-shot layers and tap-dance, have to be
  built from variables and conditions or done without.
