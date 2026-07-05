---
status: active
doc_type: plan
owner: Prateek
created: 2026-07-04
updated: 2026-07-04
related:
  - ../adr/0009-goku-karabiner-codegen.md
  - ../adr/0010-machine-type-package-selection.md
status_detail: "Applied on the migrate-tuna branch: repo swapped, files materialized to $HOME, config synced. Remaining: grant Tuna Accessibility, verify shell/URL bind execution, exercise fresh-machine bootstrap. Leader Key kept installed as fallback."
---

# Leader Key to Tuna Migration Plan

Full cutover from Leader Key (`com.brnbw.Leader-Key`) to Tuna
(`com.brnbw.Tuna`), the maintained successor by the same developer. Leader Key is
frozen; Tuna imports its config model (combo/leader binds) and adds a fuzzy
launcher, local dictation, clipboard history, and a config-as-code loop. This
plan lands the swap in one change; there is no coexistence window.

Behavior below was verified on the personal Mac (macOS 15.7) during a spike.
Open items are the gates before execution.

## Decisions taken

- **Full cutover in one change.** Remove Leader Key entirely (cask, config,
  plist, capture, tests, Karabiner description) and land Tuna in the same PR. No
  fallback path; risk is mitigated by the spike + open-item verification.
- **Config location: `~/.config/tuna/`** via Tuna's custom sync folder (XDG,
  chezmoi-managed), not the default `~/Library/Application Support/Tuna/`.
- **Apply semantics: A/B `tuna config reload` vs. quit+relaunch** live with
  Prateek, then pin the winner. Both are proven to import from the sync folder.

## Why the sync folder (not the default path)

The default `~/Library/Application Support/Tuna/config.toml` is an *export
mirror*: a cold launch regenerates it from Tuna's internal state and clobbers
on-disk edits. A **custom sync folder is authoritative** — a launch imports from
it (verified: an edit made while Tuna was stopped survived a clean restart, and
`tuna stage` confirmed the running app held it). The folder pointer is two plist
keys, both plain values (Tuna is not sandboxed, so no security-scoped bookmark):

- `ConfigSyncUsesCustomFolder = true`
- `ConfigSyncCustomFolderPath = ~/.config/tuna`

These are settable via the existing plist-merge engine — no GUI folder-pick
required once the CLI is enabled and one initial `tuna config reload` seeds the
sync.

## Bind translation

Source: `home/dot_config/leader-key/config.json`. Tuna combo binds live under
`[[comboMode.bindings]]` (nested groups use `[[comboMode.bindings.children]]`),
each an action expressed as a `tuna://run/<subject>/<action>` URL. Action URLs
are **double URL-encoded** and carry version-specific action identifiers, so the
reliable authoring path is: build each bind once in the Tuna GUI, then commit
the exported `config.toml` as the chezmoi source. The table below is the intent;
exact URL strings come from the export.

| Key | Today (Leader Key) | Tuna action shape |
| --- | --- | --- |
| `t s b g c o w m p f` | `application` launches (Ghostty, Slack, Arc, Chrome, Cursor, Orca, Obsidian, Spotify, 1Password, Finder) | `tuna://run/path.<enc-app-path>/Open` |
| `z` | group "misc" | `[[comboMode.bindings.children]]` under `key = 'z'`, `label = 'misc'` |
| `z d` | `command` `"$HOME/bin/g95nc" set` | `tuna://run/text.<enc-cmd>/Run Text as Shell Command` |
| `z m` | `url` `vnc://m4mini…` | `tuna://run/url.<enc-url>/…Open URL` |
| `z z` | `command` PANW password (`op read` + paste; op:// ref) | `tuna://run/text.<enc-cmd>/Run Text as Shell Command` |
| `z t` | `command` `~/.config/raycast/scripts/temp-admin.sh` | `tuna://run/text.<enc-cmd>/Run Text as Shell Command` |
| `z r` | `command` `open "hammerspoon://gp-record"` | `tuna://run/url.hammerspoon:%252F%252Fgp-record/…Open URL` |
| `z g` | `command` `open "hammerspoon://gp-copy"` | `tuna://run/url.hammerspoon:%252F%252Fgp-copy/…Open URL` |

Notes:
- The two GhostPepper binds become direct URL actions instead of `open "…"`
  shell wrappers. The Hammerspoon `gp-record` / `gp-copy` handlers
  (`home/dot_hammerspoon/init.fnl:1803-1854`) are unchanged.
- The PANW bind keeps the `op://` reference inline, exactly as the committed
  Leader Key JSON does today (an `op://` ref is a pointer, not a secret).
- `$HOME` expands because "Run Text as Shell Command" runs through a shell.

## Activation and cheatsheet

- **Hotkey:** set `[hotkeys.app.comboMode] = { carbonKeyCode = 79, carbonModifiers = 0 }`
  (F18) so the existing Karabiner ⌘-tap→F18 rule opens combo mode, mirroring
  Leader Key. The Karabiner rule (`home/dot_config/karabiner.edn.tmpl:118-123`)
  is unchanged; only its description comment is updated. Note the live config
  currently binds `hotkeys.app.activate` (fuzzy mode) to F18 — repoint F18 to
  `comboMode` and leave `activate` unset (or on a separate chord).
- **Cheatsheet** (superset of Leader Key's), in `[settings]`:
  `comboModeCheatsheetBehavior = 'auto'`, `comboModeCheatsheetDelayMS = 1000`,
  `comboModeCheatsheetExpandGroups = false`, `comboModeCheatsheetShowIcons = true`.

## Files to change

- `home/.chezmoidata/packages.toml:77` — replace cask `leader-key` with `tuna`
  (same `mac-desktop` group → personal + work).
- `home/.chezmoiignore:34-37` — retarget the gated paths to `~/.config/tuna`
  and `com.brnbw.Tuna.plist`.
- **Add** `home/dot_config/tuna/config.toml` — the ported binds (from GUI
  export). Committed plain TOML, not a template (Tuna owns the format).
- **Add** `home/.chezmoitemplates/com.brnbw.Tuna.plist.tmpl` +
  `home/Library/private_Preferences/modify_private_com.brnbw.Tuna.plist.tmpl` —
  plist-merge stub setting `ConfigSyncUsesCustomFolder`,
  `ConfigSyncCustomFolderPath`, `CLIEnabled` (auto-enables the `tuna` CLI so the
  reload hook works), and `URLSchemeAllowsShellCommandExecution` (allows
  external `tuna://` shell links; deliberate trust choice).
- **Add** an apply-time hook (`run_onchange_after_*`) that runs the chosen sync
  mechanism after `config.toml` changes (see Apply semantics).
- **Remove** `home/dot_config/leader-key/config.json`,
  `home/.chezmoitemplates/com.brnbw.Leader-Key.plist.tmpl`,
  `home/Library/private_Preferences/modify_private_com.brnbw.Leader-Key.plist.tmpl`.
- `home/dot_config/karabiner.edn.tmpl:5-8,118-123` — update the rule
  description (F18 now opens Tuna).
- `scripts/macos/capture.sh:66,112` — swap the captured defaults domain to
  `com.brnbw.Tuna`.
- `tests/package-gated-configs.zsh`, `tests/karabiner-goku.zsh` — retarget path
  and domain assertions.
- `docs/index.md` — add this plan under Open And Proposed Work.
- `docs/plans/chezmoi-migration-plan.md:240` — the stale Leader Key row (already
  historical); note or drop it.

## Apply semantics (A/B)

Both import from the sync folder; pick by feel:

- **`tuna config reload`** (recommended): apply hook runs the CLI; app stays up,
  imports live, sidesteps the first-launch bootstrap edge. Requires CLI enabled.
- **Quit + relaunch**: matches the "restart to apply, like every macOS app"
  pattern. Confirmed to import from the sync folder.

The hook should support either via a flag so the A/B is a one-line switch, then
delete the losing branch once chosen.

`config.toml` is app-owned — Tuna rewrites it on any in-app change. chezmoi is
the source of truth: GUI experiments are local drift that `chezmoi apply`
reverts and re-imports. Author binds in the GUI, export, commit; edit the repo
file for durable changes.

## One-time per machine (not chezmoi-automatable)

- Grant Tuna **Accessibility + Input Monitoring** (F18 capture; the PANW paste
  uses `keystroke … using command down`). Same class as existing Karabiner
  grants. This is the only unavoidable manual step.
- Initial `tuna config reload` to seed the sync folder (the reload hook does this
  once the CLI helper exists).

The CLI is enabled via the plist (`CLIEnabled`); Tuna self-installs
`~/.local/bin/tuna` on its next launch, so enabling it by hand is no longer needed.

## Open items (gates before execution)

1. **Shell + URL action execution.** Verified: combo-bind schema, nesting, and
   F18 hotkey import via reload. NOT yet verified: that
   `text.<cmd>/Run Text as Shell Command` actually runs shell and
   `url.<scheme>/…Open URL` opens `vnc://` and `hammerspoon://` on this build.
   Build one of each in the GUI, export, and fire it before porting all binds.
2. **First-launch bootstrap.** On a fresh machine (empty internal state, sync
   folder pre-populated by chezmoi), does the first launch import the folder or
   seed defaults over it? If it clobbers, the bootstrap must run
   `tuna config reload` before first interactive use. (Reload mechanism makes
   this moot.)
3. **Minimal valid `config.toml`.** The importer is strict — a hand-rolled
   skeleton failed with a decoder error. Confirm the smallest portable,
   reload-clean subset (binds + hotkeys + a few settings) so the committed file
   stays compact and machine-portable, and keep catalog global-scopes minimal to
   avoid the app-list bloat seen in the maintainer's config.

## Verification

- `chezmoi diff` / `chezmoi status`: `tuna` cask present, `leader-key` gone;
  `~/.config/tuna/config.toml` managed; `com.brnbw.Tuna.plist` sync keys merged.
- `chezmoi apply --dry-run` clean for `personal` and `work`.
- `scripts/packages/render-brewfile --machine-type personal|work` shows `tuna`,
  not `leader-key`.
- Tests retargeted and green (`tests/package-gated-configs.zsh`,
  `tests/karabiner-goku.zsh`).
- On-device: ⌘-tap opens Tuna combo mode on F18; cheatsheet shows after 1s;
  every ported bind fires (apps, shell, `vnc://`, `hammerspoon://`); cutover
  leaves no Leader Key process or hotkey.

## Follow-ups

- Native Shelf scripts for the shell binds live in `home/Library/Scripts/`
  (`g95-sharp`, `temp-admin` are `@tuna.mode background` → run in Tuna's Shelf with
  streamed output; `panw-password` is `inline` because its paste keystroke targets the
  focused field and must not run behind the Shelf). They index automatically from the
  free default `~/Library/Scripts`. Remaining: bind the z-group keys (d/z/t) to these
  script commands in the Tuna GUI, then re-capture `config.toml` — the combo→script
  subject id is app-generated and can't be hand-authored.
- Decide whether a fuzzy-mode / Spotlight-replacement hotkey is worth adding
  (new capability, out of parity scope).
- Consider whether local dictation (Talk Mode) overlaps the GhostPepper flow.
