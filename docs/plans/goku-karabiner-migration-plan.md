---
status: active
doc_type: plan
created: 2026-06-21
updated: 2026-06-22
owner: Prateek
related:
  - ../adr/0009-goku-karabiner-codegen.md
status_detail: "Implemented in this checkout; on-device pad verification is the remaining step."
---

# Goku Karabiner Migration Plan

Execution record for moving the Karabiner config from a hand-written 580-line
`karabiner.json` to a ~40-line Goku EDN source compiled at `chezmoi apply` time. The
decision, ownership-model change, and Goku syntax notes live in
[ADR 0009](../adr/0009-goku-karabiner-codegen.md); this plan is the change list and
verification trail.

## What changed

- **Source:** `home/dot_config/karabiner.edn.tmpl` — the full config in Goku EDN. Only the
  `dictation-sidekick` `shell_command` path is templated (`{{ .chezmoi.homeDir }}`).
- **Toolchain:** `goku` (tap `yqrashawn/goku`, formula `yqrashawn/goku/goku`) in the
  `base` package group in `home/.chezmoidata/packages.toml`.
- **Codegen:** `home/.chezmoiscripts/run_onchange_after_45-karabiner-goku.sh.tmpl` — hash-
  triggered on the EDN; ensures a `Default` profile exists (seed on a fresh machine, else
  rename the active profile), then runs `goku`. Skips cleanly without goku/jq/edn.
- **Seed:** `home/.chezmoiassets/karabiner-base.json` — base profile carrying the
  device-ignore + `virtual_hid_keyboard` settings, used only when no `karabiner.json` exists.
- **Ignore:** `home/.chezmoiignore` ignores the generated `.config/karabiner/karabiner.json`
  always, and `.config/karabiner.edn` when karabiner-elements is not in the profile.
- **Removed:** `home/dot_config/private_karabiner/private_karabiner.json` (retired).
- **Test:** `tests/karabiner-goku.zsh` + `make test-karabiner-goku` (+ README, `.PHONY`).
- **Docs:** [ADR 0009](../adr/0009-goku-karabiner-codegen.md); this plan; index updated.
- **Post-migration remap:** the pad was reorganized into a default base layer plus a
  Start-toggled mouse overlay (now 27 manipulators) — the face diamond drives the cursor,
  the d-pad scrolls, the bumpers click, and the always-on scroll was removed. The toggle
  is the manual `:set` + variable-condition pattern (goku has no native toggle layer; its
  `:layers`/`:simlayers` are hold-to-activate), and it fires a "🖱 Mouse mode" notification.
  The base layer is the unconditional default; the overlay is gated on `pad_mouse_mode` and
  listed first so it wins by order. Per-rule condition repetition is factored with Goku's
  in-rule `[:condi …]` marker (verified from goku source — `rules.clj`
  `add-current-in-rule-conditions`): each block states `:zero2` (and the layer gate) once,
  and goku merges it into every following rule, compiling to output byte-identical to the
  explicit form. The 25/25 equivalence below is the migration baseline, intentionally
  superseded by this change. Layout table lives in the `karabiner.edn.tmpl` header.

## Verification

- **Equivalence (done):** rendered the EDN, compiled with goku, and diffed the result
  against the pre-migration `karabiner.json` — 25/25 manipulators identical (`from`,
  `conditions`, `to`, `to_if_alone`, `parameters`). goku preserves `devices` /
  `virtual_hid_keyboard`.
- **Tooling (done):** apply script renders and passes shellcheck; `chezmoi status` shows
  `karabiner.edn` managed and `karabiner.json` ignored; `make test-karabiner-goku` parses
  and skips pre-apply, passes post-apply.
- **On-device (pending Prateek):** with the physical 8BitDo, held rotated 90° left (A up) —
  press Start to toggle the mouse layer (expect the "🖱 Mouse mode" notification on enter,
  cleared on exit). Mouse layer: face diamond moves the cursor (A=up, B=right, Y=down,
  X=left), d-pad scrolls, R = left click, L = right click. Base layer: d-pad arrows, A
  dictation, X backspace, B enter, Y escape, bumpers/select inert.

## Follow-ups

- Resolve the kanata/Karabiner overlap on the built-in keyboard (see ADR 0009 → Future
  work). Out of scope here.
