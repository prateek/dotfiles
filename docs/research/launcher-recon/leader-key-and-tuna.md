---
status: draft
doc_type: research
summary: "Recon map of Prateek's Leader Key and Tuna usage from git history: binding tree, invocations, customizations, config model, and what survived the migration."
created: 2026-10-19
updated: 2026-10-19
related:
  - README.md
  - ../../plans/prolo-ring-cheatsheet-plan.md
---

# Recon: Leader Key and Tuna

Evidence labels: COMMITTED (in a past commit), CURRENT (in the tree at `a134f6e2`), LIVE (read-only check on this machine, M-D2N572TGQN, the work MacBook, on 2026-10-19), INFERRED (my reading, not stated anywhere).

The Leader Key to Tuna migration plan was retired on 2026-10-17 (`3f9b35c1`). The last copy is at `4d707348:docs/plans/leader-key-to-tuna-migration-plan.md`, and the `docs/retired.md` ledger row points readers to `home/dot_config/tuna/config.toml`.

## Era and status

| Period | App | Trigger | Config home | Evidence |
| --- | --- | --- | --- | --- |
| 2025-11-12 to 2026-04-29 | Leader Key | Not captured in the repo | `osx-apps/leader-key/config.json`; the prefs `configDir` pointed straight at the repo checkout | COMMITTED `a72c0752`, `459aabb8` |
| 2026-04-29 to 2026-07-04 | Leader Key | Not captured | chezmoi `home/Library/Application Support/Leader Key/config.json(.tmpl)` | COMMITTED `fcc62bd6`, `e74ce011`, `6ab07200` |
| 2026-07-04 (morning) | Leader Key | Tap either ⌘, which Karabiner turns into F18 | `~/.config/leader-key/config.json` via plist `configDir` | COMMITTED `8b96b99c` |
| 2026-07-04 (evening) to 2026-10-05 | Tuna, URL-style binds | Tap either ⇧ within 100ms, sent as F18 | `~/.config/tuna/config.toml` set as Tuna's custom sync folder | COMMITTED `9235fa6c` |
| 2026-10-05 to now | Tuna 0.104, `destination` schema | Tap left ⌘ within 200ms, sent as F18 | same | COMMITTED `6c549fcc`, CURRENT |

Leader Key lasted about eight months, and only on its final day did it get anything beyond app launchers. That day (`8b96b99c`, 05:25) added the Cmd-tap trigger, the XDG config and the `z` misc group. The full move to Tuna landed the same evening (`9235fa6c`, 21:02). The archived plan says Leader Key "is frozen" and Tuna is "the maintained successor by the same developer".

Machine split:
- The personal Mac runs Tuna 0.104 with the current schema. The plan's closing `status_detail` says so: "Tuna 0.104 runs the binds, left-Cmd tap opens combo mode, Leader Key is uninstalled" (COMMITTED `6c549fcc`).
- The work Mac has Tuna 0.78 installed (LIVE, `Info.plist`). Its live `~/.config/tuna/config.toml` still has the pre-0.104 shape: `schemaVersion = 1`, a `[catalogs]` table, top-level app binds, and the retired `a q` queue bind. It differs from the source (LIVE). So the work Mac runs the August 30 to October 5 layout, and the current source has never landed there. Commit `6c549fcc` gives the risk: "Tuna 0.104 rejects the old `url = 'tuna://run/...'` binds: on upgrade it set the config aside and dropped all 14 bindings." The repo does not record why the work Mac stays on 0.78; the corp download filter is a plausible cause, but INFERRED.
- The `tuna` cask is in the shared macOS desktop package group in `packages.toml`, so it installs on both personal and work Macs (CURRENT).

## Sources

| # | commit | date | path(s) | what it shows |
| --- | --- | --- | --- | --- |
| 1 | `a72c0752` | 2025-11-12 | `osx-apps/leader-key/config.json` | First Leader Key config: `t` Ghostty, `s` Slack |
| 2 | `3e144b90` | 2025-11-12 | same | Adds `v` Cursor, `w` Obsidian, `b` Chrome |
| 3 | `3d5c8e05`, `ff2d5a8a` | 2026-01-02, 01-15 | same | Adds `m` Meet; `t` moves from Ghostty to iTerm |
| 4 | `459aabb8` | 2026-01-11 | `osx-apps/defaults/com.brnbw.Leader-Key.plist` | Captured prefs: `theme = cheater`, `configDir` set to the repo, a `KeyboardShortcuts_navigate` value |
| 5 | `fcc62bd6`, `7598d906`, `e74ce011`, `6ab07200` | 2026-04-29 to 05-18 | `home/Library/Application Support/Leader Key/config.json(.tmpl)` | Move into chezmoi; same six app binds |
| 6 | `8b96b99c` | 2026-07-04 | `home/dot_config/leader-key/config.json`, Leader Key plist template and modify stub, `karabiner.edn` | Most complete Leader Key tree: 10 apps plus the `z` group; F18 hotkey; "left-hand app launchers" |
| 7 | `9235fa6c` | 2026-07-04 | `home/dot_config/tuna/config.toml`, `com.brnbw.Tuna.plist.tmpl`, `run_onchange_after_46-tuna-reload`, `home/Library/Scripts/*`, migration plan | The move to Tuna: 7 apps and the `z` group, the sync folder, the reload hook, the trigger moved to ⇧ |
| 8 | `cd4aacfa` | 2026-07-06 | `config.toml` | GhostPepper binds go straight to `ghostpepper://` (no Hammerspoon shim) |
| 9 | `6c56155f` | 2026-08-17 | `config.toml` | Captures `activationDoublePressTrigger` and `fuzzyModeTriggerType`, which had been set in the app |
| 10 | `120a706a`, `a9382cc9` | 2026-08-30 | `config.toml` | Adds `a` (ai) group with `a q` (queue to Claude); label rewritten in Tuna's own serialization |
| 11 | `68fd3922` | 2026-09-02 | `config.toml` | `PANW password` relabelled `DAYJOB password` |
| 12 | `6c549fcc` | 2026-10-05 | `config.toml`, `karabiner.edn.tmpl`, plan | Rewrite for 0.104's `destination` schema; left-⌘ leader; nav-layer interaction; plan archived |
| 13 | `4a3a803e` | 2026-10-08 | `config.toml` | Regroup: apps move under `a`, new `w` WinMux group, ai group removed |
| 14 | `7579e277` | 2026-10-08 | `home/dot_config/prolo-ring/*`, `run_after_48`, `prolo-cheatsheet`, plan | Prolo Ring profile, labels and cheat-sheet render on apply |
| 15 | `22e43e7e` | 2026-10-17 | `config.toml` | Adds `o` Orca group |
| 16 | `a134f6e2` (HEAD) | 2026-10-19 | `tests/python/packages/test_config_gates.py` | Gate test pins the a/o/w/z layout and F18 hotkey |

## Core loop

Tap left ⌘ on its own, then type a one-letter group and a one-letter action. Karabiner sends F18, which opens Tuna combo mode, and the leaf launches an app, runs a shell line, or opens a URL. The cheat sheet appears after one second of hesitation.

## Surfaces

| ID | surface | how invoked | purpose | evidence |
| --- | --- | --- | --- | --- |
| LK-S1 | Activation hotkey | F18 (`carbonKeyCode 79`, no modifiers), sent by Karabiner on a clean tap of either ⌘ | Open the leader without a chord | COMMITTED `8b96b99c` |
| LK-S2 | Root app launchers | leader, then one key | Switch apps | COMMITTED `a72c0752` to `8b96b99c` |
| LK-S3 | `z` misc group | leader, `z`, key | Utilities: display mode, VNC, password paste, temp admin, GhostPepper | COMMITTED `8b96b99c` |
| LK-S4 | Cheat sheet theme | `theme = cheater` in prefs | Shows the available keys | COMMITTED `459aabb8` |
| LK-S5 | Config dir pointer | `configDir` pref | Keep the JSON in the repo, later in XDG | COMMITTED `459aabb8`, `8b96b99c` |
| TU-S1 | Combo mode hotkey | `[hotkeys.app.comboMode]` = F18, sent by Karabiner on a left ⌘ tap | Leader sequences | CURRENT |
| TU-S2 | Fuzzy launcher | `[hotkeys.app.activate]` = ⌘Space (`49`/`256`); also a double press of left ⌥ | Search-style launcher (a new capability compared with Leader Key) | CURRENT, COMMITTED `6c56155f` |
| TU-S3 | Groups `a`, `o`, `w`, `z` | leader, group key, action key | Apps, Orca, WinMux, misc | CURRENT |
| TU-S4 | Combo cheat sheet | `comboModeThemeStyle = cheatsheet`, 1000ms delay, details hidden | Only shows when he pauses | CURRENT |
| TU-S5 | Shelf | `shelfAutoCloseWhenTasksComplete = true`; `@tuna.mode background` scripts in `~/Library/Scripts` | Streamed output for background scripts | CURRENT; scripts are not bound to keys (see Gaps) |
| TU-S6 | CLI | `~/.local/bin/tuna config reload` from the apply hook | Load the repo config into the running app | CURRENT `run_onchange_after_46` |
| TU-S7 | `tuna://` URL scheme with shell | `URLSchemeAllowsShellCommandExecution = true` | Lets other tools script Tuna; the template calls this "a deliberate trust choice" | CURRENT plist template |
| PR-S1 | Apply-time render | `run_after_48-prolo-ring-cheatsheet`, gated by `prolo_ring` | Per-mode SVG cards, the Modstrip ladder, a four-mode tile, an HTML reference | COMMITTED `7579e277` |
| PR-S2 | Overlay toggle | `prolo-cheatsheet [mode\|all\|system\|html\|off]` or `just prolo-cheatsheet` | Show the current mode's card without taking focus, through `keymap-overlay` | CURRENT |
| PR-S3 | Flash bookkeeping | `just prolo-flashed` | Silences the "profile not flashed" reminder | CURRENT |

## Binding tree

The Leader Key column is the most complete tree, at `8b96b99c` (2026-07-04). The Tuna column is CURRENT. Earlier Leader Key binds that were gone by then are noted. In the Tuna column, "changed" means the action survived under a different sequence or target.

| sequence | action type | target | Leader Key | Tuna | notes |
| --- | --- | --- | --- | --- | --- |
| `t` | app | Ghostty (LK) / Orca (Tuna) | yes | changed: Ghostty dropped; `t` (later `a t`) → Orca | Was Ghostty, then iTerm (`ff2d5a8a`), back to Ghostty at `8b96b99c`. The Tuna port (`9235fa6c`, "t Orca") reused `t` for Orca and no terminal app kept a key. Ghostty restored as `a e` on 2026-10-19 |
| `s` | app | Slack | yes | changed: `a s` | Present since the first config |
| `b` | app | Arc | yes | changed: `a b` | Was Chrome until `8b96b99c` |
| `g` | app | Google Chrome | yes | restored: `a g` | Dropped in the move to Tuna; restored 2026-10-19 |
| `c` | app | Cursor | yes | changed: `a c` | Replaced `v` |
| `v` | app | VS Code, later Cursor | earlier (until `6ab07200`) | no | Became `c` at `8b96b99c` |
| `o` | app | Orca | yes | changed: `t` (later `a t`); also `o o` since `22e43e7e` | Moved to `t` in the port; root `o` became the Orca group on 2026-10-17, whose `o o` duplicates `a t` |
| `w` | app | Obsidian | yes | restored: `a w` | Dropped in the move; root `w` is WinMux; restored inside `a` 2026-10-19 |
| `m` | app | Spotify (LK) | yes | changed: `a m` | Was Meet (`3d5c8e05`) until `8b96b99c` |
| `p` | app | 1Password | yes | changed: `a 1` | Moved from `p` (right hand) to `1` (left hand) |
| `f` | app | Finder | yes | changed: `a f` | |
| `z` | group | misc | yes | yes | Icon `wrench.and.screwdriver` in Tuna |
| `z d` | shell | `"$HOME/bin/g95nc" set` (G95NC sharp mode) | yes | yes | |
| `z m` | URL | `vnc://m4mini._rfb._tcp.local?quality=high&numVirtualDisplays=1` | yes | yes | `m` for m4mini, where mnemonic beats hand position |
| `z z` | shell | `op read` the DAYJOB password, paste with ⌘V, restore the clipboard | yes | yes | Inline `op://` ref (a pointer, not a secret); relabelled `68fd3922` |
| `z t` | shell | `~/.config/raycast/scripts/temp-admin.sh` | yes | yes | Jamf temp admin |
| `z r` | URL | LK: `open hammerspoon://gp-record`; Tuna: `ghostpepper://start-meeting?x-error=…stop-meeting` | yes | changed | Toggle without stored state: start returns CONFLICT if already recording, so the x-error callback stops it (`cd4aacfa`) |
| `z g` | URL | LK: `hammerspoon://gp-copy`; Tuna: `ghostpepper://copy-last-recording` | yes | changed | Hammerspoon shim removed |
| `a` | group | apps (`square.grid.2x2`) | no | yes | Added `4a3a803e`; from `120a706a` to `4a3a803e` `a` was the "ai" group |
| `a q` | shell | `$HOME/bin/claude-queue-draft` (types `/q`, Ctrl+X Enter in Orca or Ghostty) | no | no (retired `4a3a803e`) | Lived 2026-08-30 to 10-08; LIVE on the work Mac |
| `o n` | URL | `raycast://extensions/prateek/orca-worktree/create-worktree` | no | yes | New, `22e43e7e` |
| `o e` | shell | activate Orca, then `~/bin/orca-agent-session` | no | yes | "reveal agent session" |
| `o f` | shell | activate Orca, then `orca-agent-session --fork` | no | yes | "fork agent session" |
| `o z` | shell | activate Orca, then `~/.local/bin/orca-zen-mode` | no | yes | "Zen mode" |
| `w h` / `w l` | shell | `winmux move left` / `right` | no | yes | Vim keys under a left-hand group key |
| `w c` / `w 3` | shell | `winmux column-count off` / `3` | no | yes | |
| `w s` | shell | `winmux open-sidebar` | no | yes | |

Counts:
- Leader Key at its most complete: 16 leaf actions (10 apps and 6 misc) in 1 group.
- Tuna now: 23 leaf binds (7 apps, 5 Orca, 5 WinMux, 6 misc) in 4 groups; 22 distinct actions, because `o o` and `a t` both open Orca.
- From the Leader Key tree, 13 of the 16 actions carried over: 7 apps and all 6 misc actions. Ghostty (`t`), Chrome (`g`) and Obsidian (`w`) were dropped (`9235fa6c`).
- Orca moved from `o` to `t`, and root `o` became the Orca group on 2026-10-17.
- On 2026-10-19 Prateek had Chrome (`a g`), Obsidian (`a w`) and Ghostty (`a e`) added back, bringing the `a` group to 10 apps and Tuna to 26 binds.

## Invocation flows

**LK-F1 Launch an app (Leader Key, July 2026)**
- Goal: switch to a core app.
- Trigger: tap either ⌘ → F18 → Leader Key opens → press the app key → app launches or comes to the front.
- Keystrokes: 2 (tap and key).
- Edge cases: holding ⌘ stays ⌘. Before `8b96b99c` the repo did not record how Leader Key was opened.

**LK-F2 Misc utility (Leader Key)**
- Goal: run a utility such as the m4mini VNC session or the password paste.
- Trigger: ⌘ tap → `z` → `d|m|z|t|r|g` → shell line or URL runs.
- Keystrokes: 3.
- Edge cases: the GhostPepper binds went through Hammerspoon x-callback handlers to read back status and transcript text.

**TU-F1 Launch an app (Tuna, now)**
- Goal: same as LK-F1.
- Trigger: left ⌘ tap (200ms, clean release) → F18 → combo mode → `a` → `t|b|c|s|m|f|1`.
- Keystrokes: 3. It was 2 from 2026-07-04 to 10-08, when the apps sat at the root.
- Edge cases: if the Karabiner nav layer is on, the leader tap turns it off first ("so the keys typed into Tuna combo mode are not" eaten, `karabiner.edn.tmpl` around line 158). The trigger moved off ⇧ because "the Shift rule's 100ms window made it both easy to fire by accident and unreliable on purpose" (`6c549fcc`).

**TU-F2 Orca actions**
- Goal: open a new worktree, reveal or fork an agent session, toggle Zen mode.
- Trigger: left ⌘ tap → `o` → `o|n|e|f|z`. The shell binds activate Orca by bundle id `com.stablyai.orca` before running the helper. `n` hands off to a Raycast extension deeplink.
- Keystrokes: 3.
- Edge cases: each shell bind sets its own PATH because Tuna's shell does not inherit the login PATH (INFERRED from the PATH prefix on every shell bind).

**TU-F3 WinMux tiling**
- Goal: move a window or change the column layout.
- Trigger: left ⌘ tap → `w` → `h|l|c|3|s` → `winmux …` CLI.
- Keystrokes: 3, and you re-enter the leader for every move (there is no sticky mode).

**TU-F4 Misc utility (Tuna)**
- Same keys as LK-F2: left ⌘ tap → `z` → key.
- Edge cases: `z z` pastes with System Events, so Tuna needs Accessibility and the target field must have focus. The unbound `dayjob-password.sh` Shelf script is `inline` for the same reason.

**TU-F5 Fuzzy launcher**
- Trigger: ⌘Space, or a double press of left ⌥. Neither is in Leader Key. Prateek set both in the app and they were captured into the repo later (`6c56155f`).

**TU-F6 Queue to Claude (retired)**
- Trigger: tap ⇧ → `a` → `q` → `claude-queue-draft` types Home, `/q `, End, Ctrl+X Enter, but only when Orca or Ghostty is frontmost.
- It replaced a Meh+D Karabiner macro (`120a706a`). It was removed when `a` became the apps group (`4a3a803e`). The script, the `/q` command and the Ctrl+X Enter pin stayed, but no leader chord reaches them any more.

**PR-F1 Prolo Ring card**
- Goal: see what the ring's gestures do in its current mode.
- Trigger: run `prolo-cheatsheet` (or `just prolo-cheatsheet`) → reads `~/.local/state/prolo-ring/mode` → floats the matching SVG card through `keymap-overlay`.
- Edge cases: no hotkey is bound yet. The plan says "A hotkey for the toggle (Karabiner or Tuna) is Prateek's call". The mode file is only written once `prolo-ring watch` exists (plan phase 3).

## Customizations on top

- **Trigger layer:** Karabiner through Goku. A bare-modifier tap sends F18, because Leader Key cannot activate on a bare modifier and Karabiner's docs recommend this mapping (`8b96b99c`). The trigger moved from either ⌘ to either ⇧ (100ms) to left ⌘ (200ms). Kanata was removed and ADR 0044 makes Karabiner the only remapper (`6c549fcc`). Another agent covers this layer in depth.
- **URL schemes:**
  - `vnc://` with screen-sharing query parameters for m4mini.
  - `ghostpepper://` with an `x-error` callback that gives a stateless toggle.
  - `raycast://extensions/prateek/orca-worktree/create-worktree`, a deeplink into his own Raycast extension.
  - `hammerspoon://gp-*`, now retired. Hammerspoon itself was removed in `5c11b011`.
- **Shell actions:**
  - `g95nc` (display sharp mode).
  - `op read` and paste for the DAYJOB password.
  - The Raycast-hosted `temp-admin.sh`.
  - The Orca helpers `orca-agent-session` and `orca-zen-mode`.
  - The `winmux` CLI.
  - The retired `claude-queue-draft`.
- **Native Tuna scripts:** `home/Library/Scripts/{g95-sharp,temp-admin,dayjob-password}.sh` with `@tuna.mode` headers. They show up in fuzzy search, but no combo key is bound to them, because the "combo→script subject id is app-generated and can't be hand-authored" (plan follow-up, COMMITTED `9235fa6c`).
- **Theming:**
  - Leader Key used the `cheater` theme.
  - Tuna uses `comboModeThemeStyle = cheatsheet`, a 1000ms delay and details hidden, with SF Symbol icons on groups and Orca leaves.
  - Before 0.104 there was an explicit `themeIdentifier`; the 0.104 rewrite dropped it. Dropping `[catalogs]` brought Emoji and Effects back to fuzzy search (`6c549fcc`).
- **Prolo Ring cheat sheet:**
  - The pipeline is built: profile, labels, render hook and overlay. It runs `prolo-ring v0.3.0` through `uvx` and keeps its own input hash.
  - It does not show Tuna bindings yet. `labels.toml` has an empty `[gestures]` table, and `profile.json` sends stock chords (arrows, Page Up/Down, `Meta+D`, `Ctrl+=`/`Ctrl+-`, `Ctrl+Meta`).
  - The plan postpones looking up chords in the Karabiner, Tuna or Raycast configs until hand-written labels show which lookups pay off (CURRENT).
  - `prolo_ring = true` is set for `prateek-personal-mbp` and the work Mac.

## What we're partial to / what carried forward

- **Left-hand single keys for the core apps.** `8b96b99c` calls them "left-hand app launchers". In the move to Tuna, 1Password went from `p` to `1` and Orca went from the right-hand `o` to the left-hand `t`, displacing Ghostty. Every app key under `a` (t, b, c, s, f, 1) is on the left half of QWERTY except `m`, Spotify (INFERRED from the moves). Mnemonics win when they conflict: `z m` for m4mini, `w h`/`w l` as vim directions, and since `22e43e7e` `o` for Orca.
- **The `z` misc group is the most stable part of either config.** All six leaves have kept their keys since 2026-07-04. Only the GhostPepper targets changed, which made them simpler.
- **Slack, Cursor, Finder, Arc, Spotify and an Orca terminal are the core app set.** Slack has been on `s` since the first commit (2025-11-12).
- **Every action is in the repo and loaded with a CLI reload.** The plan rejected the default config path because "a cold launch regenerates it ... and clobbers on-disk edits" and chose the sync folder.
- **The cheat sheet only shows on hesitation.** Leader Key had `cheater`; Tuna adds the 1000ms delay. Prolo Ring and the keyboard nav-layer sheet follow the same overlay pattern.

Dropped, and why:
- Root-level app keys moved under `a` on 2026-10-08. The commit gives no reason. Freeing `w` and `o` for groups is INFERRED.
- Ghostty (`t`), Chrome (`g`) and Obsidian (`w`) were not ported (`9235fa6c`). No reason is given.
- `a q` went because "the one-child 'ai' group holding the queue → claude macro is gone" (`4a3a803e`).
- The Hammerspoon GhostPepper shim went when `ghostpepper://` covered both flows (`cd4aacfa`).
- Pre-0.104 `tuna://run/...` URL binds were forced out by the schema change (`6c549fcc`).

## Config and data model

| Aspect | Leader Key | Tuna |
| --- | --- | --- |
| Format | JSON: a root `group` with `actions[]` of `{key, type: application\|command\|url\|group, value, label, actions}` | TOML. 0.78-era: `[[comboMode.bindings]]` with `url = 'tuna://run/<subject>/<action>'` (double URL-encoded) and `children`, plus `schemaVersion` and `[catalogs]`. 0.104: each bind has a `destination` table of `type = group\|command\|url`; commands are `savedCommand` with `actionIdentifier` (`tuna.common-actions/open`, `tuna.common-actions/run-text-as-shell-command`) and `subjectIdentifiers` (`path:…`, `text:…`) |
| Other sections | none (hotkey and theme live in the plist) | `[hotkeys.app.comboMode]`, `[hotkeys.app.activate]`, `[settings]` |
| Location | `~/.config/leader-key/config.json` through the `configDir` pref (earlier the repo path, then Application Support) | `~/.config/tuna/config.toml` through `ConfigSyncUsesCustomFolder` and `ConfigSyncCustomFolderPath` |
| Prefs management | `modify_private_com.brnbw.Leader-Key.plist.tmpl` → `scripts/macos/plist-merge` with the desired fragment (`configDir`, `KeyboardShortcuts_activate` as a JSON string) | Same merge engine: `ConfigSyncUsesCustomFolder`, `ConfigSyncCustomFolderPath`, `CLIEnabled`, `URLSchemeAllowsShellCommandExecution`. Hotkeys are left out of the plist because Tuna writes `KeyboardShortcuts_*` itself on import |
| Reload | Not handled in the repo | `run_onchange_after_46-tuna-reload` hashes `config.toml` and runs `tuna config reload`; it skips if the app or CLI is missing |
| Ownership quirks | Plain JSON, edited by hand | Tuna owns the format. It rewrites non-ASCII labels as escaped double-quoted strings (`a9382cc9`), it does not check action ids (`6c549fcc`), it rejects a skeleton config, and GUI edits drift until the next apply reverts them |
| Tests | `tests/karabiner-goku.zsh`, `package-gated-configs.zsh` (retired) | `test_tuna_combo_layout_apps_orca_winmux_misc_and_leader_hotkey` in `tests/python/packages/test_config_gates.py` |
| Prolo Ring | n/a | `profile.json` (Prolo Studio export format), `labels.toml` (gesture name → label and mnemonic). The render hook writes to `~/.local/share/prolo-ring`; state lives in `~/.local/state/prolo-ring/{rendered-hash,flashed-hash,mode}` |

## Gaps and open questions

1. **The work Mac's live Tuna is out of date** (LIVE: 0.78, old schema, still has `a q`, no `o` or `w` groups). The 0.104 upgrade path drops old binds, and the repo has no machine-specific handling or note about it. `chezmoi status` on the work Mac reports `MM` for `~/.config/tuna/config.toml` (LIVE): the live file changed after chezmoi last wrote it, and the 0.104 source is still pending. The next full apply would write the 0.104-schema file and reload it into the 0.78 app. What 0.78 does with it is untested.
2. **Leader Key's activation before July 2026 was never committed.** The captured `KeyboardShortcuts_navigate` value (`carbonModifiers 4096`, `keyCode 0`) is for something else, and I did not confirm what.
3. **The plan's fresh-machine checks were never run.** The final status says "Fresh-machine first-launch import was never exercised".
4. **The `~/Library/Scripts` Shelf scripts are not bound to keys.** The plan follow-up to bind `z d/z/t` to them is still open; the combo binds still run inline shell.
5. **Prolo Ring does not show leader bindings.** Labels are empty and chord lookup is postponed, so the ring cheat sheet has no Tuna content yet. The overlay toggle has no hotkey.
6. **There is no recorded reason for dropping Ghostty, Chrome and Obsidian**, or for putting the apps behind `a` at the cost of one extra keystroke.
7. **Usage frequency is unknown.** Git shows what is configured, not what gets pressed. Tuna does not export usage counts here, and this audit was barred from using session transcripts.
