---
status: proposed
doc_type: plan
created: 2026-04-30
related: []
status_detail: "Proposal only; no displayctl code, config, apply script, or tests exist in this checkout yet."
---

# BetterDisplay Display Modes Plan

## Problem

The Samsung Odyssey Neo G9 57" needs a repeatable BetterDisplay setup that works with a single DisplayPort cable.

The desired daily modes are:

- one full-width HiDPI desktop with the "goldilocks" scale;
- two-column split mode;
- optional three-column split mode after the two-column path proves stable.

BetterDisplay can create virtual screens, mirror them to the physical display, and show virtual screens as PIP windows. Its app state also keeps old display identities for prior monitor modes and connections. A whole-plist import would risk overwriting local BetterDisplay state and would not prevent duplicate virtual screens.

## Goals

- Give the user a small config that describes display modes, not BetterDisplay bookkeeping.
- Make repeated applies idempotent.
- Upsert managed virtual screens by stable generated identity.
- Keep old physical display records alone unless an explicit cleanup command targets managed resources.
- Validate config silently in normal chezmoi runs.
- Detect when a connected display cannot support the requested mode.
- Start with the single and two-pane modes.

## Non-goals

- Manage every BetterDisplay preference.
- Import or own the full `pro.betterdisplay.BetterDisplay.plist` domain.
- Delete old BetterDisplay physical display history.
- Solve every ultrawide layout shape in the first pass.
- Depend on a mock BetterDisplay implementation for tests.

## Command Name

Use `displayctl`.

The name is short, tool-like, and broad enough that BetterDisplay stays an adapter behind the command.

## CLI Surface

Use the mode name as the command for the common path:

```sh
displayctl
displayctl default
displayctl single
displayctl split2
displayctl --dry-run split2
displayctl check
displayctl check split2
displayctl prune split2
```

Rules:

- `displayctl` with no arguments is read-only status.
- `displayctl default` switches to the configured default mode.
- `displayctl <mode>` switches to a configured mode.
- `displayctl --dry-run <mode>` prints the plan and mutates nothing.
- `displayctl check [mode]` validates the config and, when possible, live support for the selected mode.
- `displayctl prune [mode]` deletes only duplicate managed virtual screens for the selected mode.
- `--config <path>` overrides the default config path.
- `--json` makes status and check output machine-readable for scripts.
- `--quiet` suppresses success output.

This keeps the pit of success small: the normal operation is `displayctl single` or `displayctl split2`. Validation and planning are flags or query commands, not mandatory ceremony.

Principles from `code-principles`:

- CQS: `status`/`check` style calls are read-only; mode names mutate.
- POLA: no-argument `displayctl` does not change display state.
- YAGNI: avoid a full verb hierarchy until there are more real operations.
- Idempotency: running `displayctl split2` twice produces the same managed resources.
- Fail Fast: duplicate managed resources stop the switch and point to `prune`.

Exit behavior:

- `displayctl` exits `0` when the config can be read, even if the target display is disconnected. Status output reports `connected: false`.
- `displayctl check` exits `0` if offline validation passes and the target display is disconnected. It should report that live checks were skipped.
- `displayctl check <mode>` exits nonzero when the target display is connected and the selected mode is unsupported.
- `displayctl <mode>` exits nonzero when the target display is disconnected.
- `displayctl prune` is the only command that deletes managed virtual screens.

## Config Model

The config should stay close to how Prateek thinks about the monitor: display, defaults, named modes.

```json
{
  "display": {
    "name": "Odyssey G95NC",
    "serial": "HNTX901039"
  },
  "default": "single",
  "defaults": {
    "refreshRate": "120Hz",
    "hiDPI": true
  },
  "modes": {
    "single": "4096x1152",
    "split2": {
      "panes": 2,
      "resolution": "2560x1440"
    },
    "split3": {
      "panes": 3,
      "resolution": "1920x1440"
    },
    "presentation": {
      "resolution": "3200x900",
      "refreshRate": "60Hz",
      "hiDPI": true
    },
    "work": {
      "widths": [70, 30],
      "resolution": "2560x1440"
    }
  }
}
```

Rules:

- A string mode means one full-width mirrored virtual screen.
- An object mode without `panes` or `widths` means one full-width mirrored virtual screen with overrides.
- `panes` means equal-width columns.
- `widths` means custom-width columns and implies the pane count.
- Mode-level `refreshRate` and `hiDPI` override `defaults`.
- Object modes must include `resolution`.
- `display` may be a string for the common case or an object when serial matching matters.
- The command owns generated virtual-screen names, serial numbers, model numbers, PIP geometry, and cleanup boundaries.

## Internal Expansion

The command expands user modes into managed BetterDisplay resources.

For `single`:

```text
managed display: Odyssey G95NC / single / pane 1
layout: mirror virtual screen to the physical Neo G9
mode: 4096x1152 HiDPI @ 120Hz
```

For `split2`:

```text
managed displays:
  Odyssey G95NC / split2 / pane 1
  Odyssey G95NC / split2 / pane 2
physical display: native full panel, kept as the non-main host display
layout: two fixed PIP windows over the physical Neo G9
mode per pane: 2560x1440 HiDPI @ 120Hz
```

Split layout defaults:

- The physical display is set to the safest full-panel host mode available, preferring the current native mode when it is already usable.
- Each pane is a managed virtual screen shown as a PIP window on the physical display.
- PIP coordinates are percentages of the physical display frame.
- Equal-column `split2` uses `{x: 0, y: 0, width: 50, height: 100}` and `{x: 50, y: 0, width: 50, height: 100}`.
- Equal-column `split3` uses widths `[33.33, 33.34, 33.33]`.
- PIP windows are titlebarless, shadowless, fixed-position, and topmost if BetterDisplay supports those options.
- The leftmost pane is the main display unless a later config option says otherwise.
- The physical desktop behind the PIP windows is not a workspace target; it is a host surface for the PIP layout.

Generated identities must be deterministic:

```text
name:   BD Managed - Odyssey G95NC - split2 - pane 1
serial: stable hash of display + mode + pane
vendor: BetterDisplay virtual-screen vendor
model:  stable hash of mode + pane, constrained to a safe numeric range
```

The user config never needs to name `neo_left` or `neo_right`.

## Mode Switch Behavior

`displayctl <mode>` reconciles one selected mode:

1. Load and validate the config offline.
2. If BetterDisplay is unavailable, exit with a clear error for direct command use. In chezmoi, the wrapper may skip when the cask is absent.
3. Resolve exactly one physical display.
4. Compute every managed identity needed for the selected mode.
5. Read live managed virtual screens for those identities.
6. Fail if any managed identity has more than one live screen. This happens before any create or apply step.
7. Create missing managed virtual screens.
8. Ensure the virtual refresh list includes the requested refresh rate.
9. Apply resolution, refresh rate, and HiDPI.
10. Apply mirror or PIP layout.
11. Disconnect or hide managed screens from other modes.
12. Verify the resulting mode.

The command should not touch unmanaged displays. Old disconnected `Odyssey G95NC` entries in BetterDisplay's plist are outside the managed set.

## Prune Behavior

`displayctl prune [mode]` is a narrow repair command for duplicate managed virtual screens.

Prune candidate rules:

- only consider virtual screens whose name, serial, vendor, and model all match a generated managed identity;
- when a mode is provided, only consider identities for that mode;
- when no mode is provided, consider identities for all configured modes;
- never consider physical displays;
- never consider virtual screens that match only by display name;
- never call BetterDisplay `discard` without a tag ID or UUID;
- print the candidate list before deletion unless `--quiet` is set.

If duplicate candidates differ in current connection state, keep the connected one. If several are connected, keep the oldest stable generated identity match and delete the rest. If the command cannot pick a survivor confidently, it should fail and ask for manual cleanup.

## Refresh Rate Handling

The live machine currently shows this shape:

- the physical Neo G9 exposes `4096x1152 HiDPI 120Hz`;
- the physical connection reports a preferred `7680x2160 120Hz 10bit SDR RGB Full` mode;
- the active virtual screen only exposes `60Hz`, because `refreshRates@VirtualScreen:<id>` contains `[60]`;
- the physical display follows the virtual mirror master, so the whole setup lands at 60Hz.

The command should first try the public CLI:

```sh
betterdisplaycli set --tagID "$virtual_tag" --resolution=4096x1152 --refreshRate=120 --hiDPI=on
```

If the virtual screen does not expose 120Hz, the command may patch only the managed virtual screen refresh list. That path must stop BetterDisplay first, update the one owned key, restart BetterDisplay, and verify that `120Hz` appears before applying the mode.

Do not patch unrelated plist keys.

## Validation

Validation has two tiers.

Offline validation runs everywhere:

- `display` is a string or an object with `name` and optional `serial`;
- `default` exists in `modes`;
- each mode is a string resolution or an object;
- mode objects have at most one of `panes` or `widths`;
- mode objects include `resolution`;
- `panes` is `1`, `2`, or `3` for the first version;
- `widths` are positive and sum to `100`;
- resolutions use `WIDTHxHEIGHT`;
- refresh rates use `60Hz`, `120Hz`, etc.;
- generated managed identities are unique.

Live validation runs only when BetterDisplay and the target display are available:

- exactly one physical display matches;
- BetterDisplay Pro is available when the selected mode needs Pro features;
- the requested resolution, refresh rate, and HiDPI mode are available or can be made available for the managed virtual screen;
- PIP support is present before applying split modes;
- duplicate managed virtual screens fail the run unless `prune` is explicitly requested;
- applying the plan twice would not create more screens.

`displayctl check` checks the whole config offline. For live checks, bare `check` checks only the default mode in Phase 1 and Phase 2. `displayctl check <mode>` checks that specific mode. Once split modes are implemented, bare `check` may include every implemented mode, but it should not fail because a future-mode example is present in the config.

If the target display is disconnected during `chezmoi apply`, the wrapper should skip live validation and avoid changing state. A direct `displayctl <mode>` should report that the target display is not connected.

## Chezmoi Shape

Use the existing app-config convention:

```text
home/dot_config/displayctl/config.json
home/bin/symlink_displayctl.tmpl
home/.chezmoiscripts/run_onchange_after_35-betterdisplay-displayctl.sh.tmpl
tests/displayctl-config.zsh
```

Package gating:

- add the `betterdisplay` cask to the `dev` package group if needed;
- ignore the BetterDisplay config and onchange script when the cask is absent;
- keep `displayctl` available as a repo tool, but make the apply script no-op without BetterDisplay.

The onchange script should run:

```sh
status_json="$(displayctl --json)"
if ! printf '%s\n' "$status_json" | jq -e '.connected == true' >/dev/null; then
  exit 0
fi

displayctl --quiet check default
displayctl --quiet default
```

If the target display is disconnected, the script should skip the mode switch without warning.

## Testing

Tests should cover the planner without mutating the real display.

Offline tests:

- parse the example config;
- reject invalid modes;
- reject duplicate generated identities;
- prove string, equal-column, and custom-width modes expand correctly;
- prove mode-switch plans are idempotent from fixture inputs;
- prove duplicate managed virtual screens fail unless the command is `prune`.

Live tests should be manual or host-gated:

```sh
displayctl check
displayctl --dry-run single
displayctl single
displayctl check single
```

The first implementation should record the real command outputs needed to diagnose unsupported modes, without printing secret or license data.

## Implementation Phases

### Phase 1: Config and Offline Planner

- Add the JSON config.
- Add `displayctl` read-only status.
- Add `displayctl check`.
- Add `displayctl --dry-run <mode>`.
- Add fixture-based tests.

### Phase 2: Single Mode Apply

- Implement BetterDisplay CLI adapter.
- Upsert one managed virtual screen.
- Switch to `single` with `displayctl single`.
- Fix the 120Hz virtual refresh-list issue if the CLI cannot.
- Make `displayctl check single` verify the live result.

### Phase 3: Split Two

- Add PIP layout support.
- Switch to `split2` with `displayctl split2`.
- Validate behavior after sleep, reconnect, and BetterDisplay restart.

### Phase 4: Split Three and Custom Widths

- Enable `split3`.
- Enable `widths`.
- Add manual acceptance notes for any BetterDisplay drift after sleep.

## Open Questions

- What numeric range should generated virtual-screen model numbers use?
- Does BetterDisplay CLI expose a supported way to update virtual-screen refresh lists, or do we need the focused plist patch path?
- Should split modes disconnect the single-mode virtual screen or leave it connected but hidden?
- Should `displayctl` stay standalone, or should `bin/dotfiles display` wrap it later?
- Are PIP split modes good enough for daily use, or should they remain opt-in until proven after sleep and reconnect cycles?

## Success Criteria

- `displayctl single` creates at most one managed virtual screen.
- Re-running `displayctl single` does not create duplicate BetterDisplay profiles.
- `single` verifies as `4096x1152 HiDPI @ 120Hz` when the monitor supports it.
- Invalid configs fail offline validation before BetterDisplay is touched.
- Disconnected-display chezmoi applies stay quiet and do not mutate state.
- Split mode is explicit, reversible, and does not delete unmanaged BetterDisplay state.

## References

- BetterDisplay CLI and integration docs: https://github.com/waydabber/BetterDisplay/wiki/Integration-features%2C-CLI
- BetterDisplay scalable HiDPI virtual-screen docs: https://github.com/waydabber/BetterDisplay/wiki/Fully-scalable-HiDPI-desktop
- BetterDisplay settings import/export caveats: https://github.com/waydabber/BetterDisplay/wiki/Export-and-import-app-settings
- Samsung Neo G9 57 discussion: https://github.com/waydabber/BetterDisplay/discussions/4129
- Ultrawide split/PIP discussion: https://github.com/waydabber/BetterDisplay/discussions/2376
