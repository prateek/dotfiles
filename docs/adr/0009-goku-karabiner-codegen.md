---
status: accepted
doc_type: adr
created: 2026-06-21
updated: 2026-06-21
owner: Prateek
related:
  - ../plans/goku-karabiner-migration-plan.md
  - 0006-chezmoi-migration-prototype.md
status_detail: "Accepted and implemented: karabiner.edn + goku codegen replace the hand-written karabiner.json."
---

# ADR 0009 — Karabiner config via Goku codegen

## Context

`home/dot_config/private_karabiner/private_karabiner.json` had grown to 580 lines for
what is conceptually a small mapping table. The 8BitDo Zero 2 setup (a sticky "mouse
mode" plus dictation/arrow/scroll rules) and the Apple-internal modifier remaps together
are ~25 manipulators, but **21 of them re-stamp an identical 10-line `device_if` block**,
and the two-layer (normal vs mouse) gating duplicates the d-pad/face rows. Karabiner JSON
has no DRY mechanism — conditions are per-manipulator, with no rule-level or shared
condition — so the file cannot be slimmed in place. Every future button change meant
hand-editing several near-identical stanzas.

[Goku](https://github.com/yqrashawn/GokuRakuJoudo) is an EDN DSL that compiles to
Karabiner JSON. It has first-class device conditions, variable-based layers, and the
`to`-event shortcuts this config needs. The same behavior collapses to ~40 lines of EDN.

Alternatives weighed: a chezmoi Go-template generator (no new dependency, but templating
JSON with correct commas is its own maintenance tax, and the source stays JSON-shaped);
and consolidating onto kanata (already in the repo) — rejected because kanata and the
Karabiner-Elements **app** cannot both grab input at once (they share only the
DriverKit driver), so that is a full migration off Karabiner, not a simplification.

## Decision

Author the Karabiner config as Goku EDN at `~/.config/karabiner.edn` (chezmoi-managed,
rendered from `home/dot_config/karabiner.edn.tmpl`) and compile it to
`~/.config/karabiner/karabiner.json` with `goku` at `chezmoi apply` time, via
`home/.chezmoiscripts/run_onchange_after_45-karabiner-goku.sh.tmpl`. This reuses the
repo's existing apply-time codegen idiom (the Swift CLIs, Hammerspoon Fennel, macOS
defaults). `goku` installs from a custom tap (`yqrashawn/goku/goku`), added to the core
and full package profiles next to `karabiner-elements`.

This flips the ownership model. Verified against goku 0.8.0: goku reads the existing
`karabiner.json`, replaces only the target profile's `complex_modifications` (preserving
`devices`, `virtual_hid_keyboard`, and other profiles), and **fails if the profile is
missing**. Its default target is a profile named `Default`. So:

- **chezmoi owns** `karabiner.edn` (the source). The only templated value is the
  `dictation-sidekick` `shell_command` path, rendered with `{{ .chezmoi.homeDir }}` so
  nothing under `/Users/<user>` is hardcoded.
- **goku owns** `karabiner.json` — generated, and `.chezmoiignore`d so chezmoi never
  manages or clobbers it.
- The apply script guarantees a `Default` profile exists: it seeds a base
  (`home/.chezmoiassets/karabiner-base.json`, carrying our device-ignore +
  `virtual_hid_keyboard` settings) on a fresh machine, or renames the active profile to
  `Default` on an existing one.

Behavioral equivalence with the retired JSON was confirmed manipulator-for-manipulator
(25/25 identical: `from`, `conditions`, `to`, `to_if_alone`, `parameters`).

## Consequences

- The hand-written `private_karabiner/private_karabiner.json` is removed; the source of
  truth is ~40 lines of EDN. Adding a button is one EDN rule, not several JSON stanzas.
- New runtime dependency: `goku` (pulls `joker` + `watchexec`) from a custom tap, plus an
  apply-time generation step. Consistent with existing codegen scripts.
- The Karabiner profile is renamed `"Default profile"` → `"Default"` (goku keys profiles
  by a space-less keyword). Idempotent, cosmetic, no behavioral effect.
- **Edit the `.edn`, never `karabiner.json`** — and avoid the Karabiner GUI for complex
  modifications, since the next apply regenerates the rules.
- A local test (`tests/karabiner-goku.zsh`, `make test-karabiner-goku`) compiles the EDN
  with `goku --dry-run-all` and asserts the expected rule set. It skips without goku / a
  `Default` profile, so it is not wired into CI (CI has neither), matching the
  `test-kanata-config` precedent.

## Goku syntax notes (verified from source, not memory)

- `to` shortcuts: `:set`→set_variable, `:shell`→shell_command, `:noti {:id :text}`→
  set_notification_message, `:mkey {…}`→mouse_key, `:pkey`→pointing_button, `:lazy`,
  `:modi`, `:alone`→to_if_alone.
- `:mkey` keys are abbreviated: `:x :y :vwheel :hwheel :speed`.
- Conditions: keyword `:foo` = `*_if` value 1; `!`-prefix `:!foo` = `*_unless` value 1;
  `:devices` entries pass through verbatim (so `is_built_in_keyboard` works).
- Per-rule parameters use `:params` with the same shortcut keys as the profile block:
  `{:params {:alone 200}}` emits `basic.to_if_alone_timeout_milliseconds: 200`. (Top-level
  `:alone` in the options map is the to_if_alone *action*, not the timeout.)

## Future work

The kanata/Karabiner overlap is still unresolved: `home/dot_config/kanata/kanata.kbd` and
the Apple-internal rules now in `karabiner.edn` both remap the built-in keyboard, and the
two grabbers cannot run at once. Picking one tool for the Apple keyboard is a separate
decision.
