---
status: draft
doc_type: research
summary: "Recon map of the hotkey and trigger layer that summons Prateek's launchers: Hammerspoon, Karabiner and Goku, Kanata, BetterTouchTool, and Homerow, from git history."
created: 2026-10-19
updated: 2026-10-24
related:
  - README.md
  - ../../adr/0044-karabiner-sole-remapper.md
  - ../../adr/0009-goku-karabiner-codegen.md
---

# Recon: hotkey and trigger layer

This map covers the layer that sits under the launchers: the remappers and hotkey
daemons that turn a physical key into "open Tuna", "open Raycast", or "run this
script". The launchers themselves (Alfred, Raycast, Leader Key, Tuna) are covered
by sibling maps; they appear here only as targets.

Evidence labels: COMMITTED (in a commit), CURRENT (in the HEAD tree of
`a134f6e2` on the `prateek/tinycast` branch), LIVE (read-only check on this work Mac, M-D2N572TGQN, on
2026-10-19), INFERRED (my reading, not stated anywhere).

The short version: until 2026 the repo committed no trigger config at all, only
casks. From January 2026 the layer churned through Karabiner JSON, Kanata,
Hammerspoon, back to Karabiner, then Goku codegen. Since 2026-10-05 Karabiner is
the only remapper, and a tap of left ⌘ (Karabiner sends F18) is the leader key
for Tuna.

## Era and status

| Tool | First seen | Config committed | Retired | Current | Evidence |
|---|---|---|---|---|---|
| Karabiner (legacy, pre-Elements) | 2016-10-13, Brewfile `cask 'karabiner'` | never | 2023-01-21, replaced by `karabiner-elements` cask | retired | COMMITTED 049be18d, fd73e810 |
| Karabiner-Elements, hand JSON | cask 2023-01-21; JSON 2026-01-11 | `.config/karabiner/karabiner.json`, then `home/dot_config/private_karabiner/private_karabiner.json` | 2026-06-21 (JSON replaced by Goku) | superseded by Goku | COMMITTED 459aabb8, db003980, ff710b93, d97650e3 |
| Goku (EDN to Karabiner JSON) | 2026-06-21 | `home/dot_config/karabiner.edn.tmpl` + apply hook | | active, sole remapper | COMMITTED d97650e3, 6c549fcc; CURRENT |
| Kanata | 2026-01-17 | `.config/kanata/kanata.kbd`, then `home/dot_config/kanata/kanata.kbd` | 2026-10-05 | removed; `~/.config/kanata` in `.chezmoiremove` | COMMITTED e880ea5b, 6c549fcc; LIVE dir absent |
| Hammerspoon (Fennel) | 2026-01-17 | `.hammerspoon/init.fnl` + `init.lua` loader | 2026-09-07 | removed from repo and packages; app and `~/.hammerspoon` leftovers still on disk, not running | COMMITTED d51d75a3, 5c11b011; LIVE |
| BetterTouchTool | 2016-10-13 cask | 5 app prefs + license template since 2026-04-29; no triggers ever | | active (running), triggers unmanaged | COMMITTED 049be18d, 237c318d; CURRENT; LIVE |
| KeyPath (Kanata GUI) | never in packages | never | | app installed by hand; repo cites its source only as a TCC-onboarding design reference | COMMITTED 55dd9a28; LIVE |
| Homerow, Shortcat, skhd, Hyperkey, Superkey, Keyboard Maestro, LaunchBar, Quicksilver, Apptivate, Thor, Manico, rcmd | never | never | | never configured | `git log --all -i -G` returns nothing relevant |
| AeroSpace / WinMux (window managers, hotkey collisions only) | WinMux 2026-10-06 | `home/dot_config/winmux/winmux.ncl` | AeroSpace retired 2026-10-06 | WinMux active | COMMITTED 7220316b, ea3ca3cd, 74e4b7ca |

## Sources

| # | commit | date | path(s) | what it shows |
|---|---|---|---|---|
| 1 | 049be18d | 2016-10-13 | `Brewfile` | First Mac app list: `alfred`, `bettertouchtool`, `karabiner` casks. No config. |
| 2 | fd73e810 | 2023-01-21 | `Brewfile` | `karabiner` becomes `karabiner-elements`. |
| 3 | 27b45613, 3a24187f | 2025-11-11 | `osx-apps/alfred/.../hotkey/prefs.plist` | Alfred hotkey keycode 49 (Space) with ⌘. |
| 4 | d7af4b9c | 2026-01-11 | `Brewfile` | `leader-key` cask joins `alfred`, `bettertouchtool`, `karabiner-elements`, and `raycast` (in since 769a5e98, 2025-09-22). |
| 5 | 459aabb8 | 2026-01-11 | `.config/karabiner/karabiner.json`, `osx-apps/defaults/com.brnbw.Leader-Key.plist` | First committed Karabiner rules: Akimbo ⌘ to Fn+F12, Caps to Ctrl/Esc. Leader Key prefs captured without an activation key. |
| 6 | e880ea5b | 2026-01-17 | `.config/kanata/kanata.kbd`, `scripts/macos/apply.sh` | Kanata port of the Karabiner rules plus double-tap Shift one-shot Hyper. Feature branch 3752a496 also carried a launchd daemon; master did not. |
| 7 | d51d75a3, 2fe36aa9 | 2026-01-17 | `.hammerspoon/init.fnl`, `init.lua`, `Makefile` | Hammerspoon FuzzyOverlay repo/file picker in Fennel, Hyper+R rebuild. |
| 8 | 4acd76fe | 2026-02-12 | `.hammerspoon/init.fnl` | Gemini meeting-sync timer hosted in Hammerspoon. |
| 9 | db003980 | 2026-05-02 | `.config/karabiner/karabiner.json` | Karabiner back in charge: fn to ⌥, left Ctrl tap F19, left ⌥ to Hyper, double-tap left ⇧ one-shot Hyper. |
| 10 | 7598d906 | 2026-05-10 | `home/...` | Chezmoi migration: Hammerspoon apply hook, BTT plist merge stub and license, Kanata and Karabiner moved under `home/`. |
| 11 | ff710b93 | 2026-05-12 | `private_karabiner.json` | Remaps scoped to the internal keyboard; left Ctrl becomes Meh-on-hold, F19-on-tap; Akimbo and double-tap ⇧ dropped. |
| 12 | 9ed21885, 22652c02 | 2026-06-20 | `private_karabiner.json` | 8BitDo Zero 2 dictation pad: A to F19, d-pad arrows, bumpers scroll. |
| 13 | d97650e3 | 2026-06-21 | `karabiner.edn.tmpl`, `run_onchange_after_45-karabiner-goku.sh.tmpl`, `karabiner-base.json`, ADR 0009 | Goku codegen replaces the 580-line JSON; 25/25 manipulators equivalent. |
| 14 | 66816d3b, 9e9a61d0 | 2026-06-22/23 | `karabiner.edn.tmpl` | Pad mouse-mode toggle with notification; per-app bumper overlays for Orca and Arc. |
| 15 | 8b96b99c | 2026-07-04 | `karabiner.edn.tmpl`, `dot_config/leader-key/config.json`, `init.fnl` | Tap either ⌘ sends F18, Leader Key's activation hotkey. Ten left-hand app keys. Hammerspoon GhostPepper URL glue. |
| 16 | 9235fa6c | 2026-07-04 | `karabiner.edn.tmpl`, `dot_config/tuna/config.toml` | Leader Key to Tuna. Leader moves to tap either ⇧ (100 ms) sending F18, Tuna's comboMode hotkey. |
| 17 | b4225c7d | 2026-07-06 | `init.fnl` | Tuna drives `ghostpepper://` directly; Hammerspoon URL handlers removed. |
| 18 | 6c56155f | 2026-08-17 | `dot_config/tuna/config.toml` | Captures Tuna fuzzy mode on double-press of left ⌥. |
| 19 | 227c8446, 120a706a | 2026-08-30 | `karabiner.edn.tmpl` | Meh+D Claude `/q` macro added, then moved to the Tuna leader sequence the same day. |
| 20 | 82a47c37 | 2026-08-31 | `docs/plans/raycast-config-automation-plan.md` | Raycast `raycastGlobalHotkey = Command-49` (⌘Space) recorded as live but uncaptured. |
| 21 | 5c11b011 | 2026-09-07 | `home/dot_hammerspoon/*`, apply hook, `packages.toml` | Hammerspoon removed with its integrations. No commit body. |
| 22 | 6c549fcc | 2026-10-05 | `karabiner.edn.tmpl`, ADR 0044, `kanata.kbd` (deleted) | Left ⌘ tap (200 ms) is the leader; modal nav layer on ⌃Space; Kanata removed; Karabiner is the sole remapper. |
| 23 | 324d9e72 | 2026-10-06 | `karabiner.edn.tmpl`, `scripts/keyboard/` | NocFree Lite device group; firmware copy of the nav layer; F20 select-mode bridge. |
| 24 | ea3ca3cd, 74e4b7ca | 2026-10-06/08 | `winmux.ncl` | WinMux gives back plain Ctrl chords and every ⌘ chord its defaults claimed. |
| 25 | 4a3a803e | 2026-10-08 | `dot_config/tuna/config.toml` | Tuna leader regrouped: apps under `a`, WinMux under `w`. |
| 26 | 1a0501ad | 2026-10-17 | `karabiner.edn.tmpl` | ⌥Z in Orca runs `orca-zen-mode`. |

## Launcher-summon timeline

| Date | Key | Launcher | Tool owning the binding | Evidence |
|---|---|---|---|---|
| 2016-10 to 2025-11 | unknown (not committed) | Alfred | Alfred | COMMITTED 049be18d cask only |
| 2025-11-11 | ⌘Space (keycode 49). The `local/` copy adds two high flag bits I could not decode. | Alfred | Alfred | COMMITTED 27b45613, 3a24187f |
| 2025-09-22 onward | ⌘Space | Raycast | Raycast | LIVE `defaults read com.raycast.macos raycastGlobalHotkey` = `Command-49`; COMMITTED 82a47c37 says it was never captured. Start date of the binding is INFERRED. |
| 2025-11-12 to 2026-07-04 | unknown (activation key not in the captured plist) | Leader Key | Leader Key | COMMITTED 459aabb8 captures only `KeyboardShortcuts_navigate` (⌃A) |
| 2026-01-17 to 2026-09-07 | ⌃⌥⌘U (repo URL picker), ⌃⌥⌘T (repo file picker), ⌃⌥⌘⇧T (pick repo, then file) | Hammerspoon FuzzyOverlay (a custom launcher) | Hammerspoon | COMMITTED d51d75a3, removed 5c11b011 |
| 2026-07-04 | tap either ⌘ (200 ms, `:lazy`) to F18 | Leader Key | Karabiner (Goku) + Leader Key activation = F18 | COMMITTED 8b96b99c |
| 2026-07-04 | tap either ⇧ (100 ms, real modifier) to F18 | Tuna combo mode | Karabiner (Goku) + Tuna `hotkeys.app.comboMode` = keycode 79 | COMMITTED 9235fa6c |
| 2026-07-04 onward | ⌘Space (`hotkeys.app.activate`, keycode 49, mods 256) | Tuna main/fuzzy | Tuna | COMMITTED 9235fa6c; CURRENT `home/dot_config/tuna/config.toml`; LIVE same value. Collides with Raycast's ⌘Space; see Gaps. |
| 2026-08-17 onward | double-press left ⌥ | Tuna fuzzy mode | Tuna | COMMITTED 6c56155f; CURRENT |
| 2026-10-05 onward | tap left ⌘ only (200 ms, real modifier) to F18 | Tuna combo mode | Karabiner (Goku) | COMMITTED 6c549fcc; CURRENT `karabiner.edn.tmpl` lines 229-235 |

The leader changed twice in three months, across three modifiers: both ⌘ keys, then both ⇧ keys, then left ⌘.
6c549fcc gives the reason for the last move: "The Shift rule's 100ms window made it
both easy to fire by accident and unreliable on purpose."

## Surfaces

| ID | Surface | Tool | How invoked | Purpose | Evidence |
|---|---|---|---|---|---|
| TL-S01 | Leader tap | Karabiner | tap left ⌘ alone within 200 ms; sends F18 | Opens Tuna combo mode; held ⌘ stays a real modifier | CURRENT; COMMITTED 6c549fcc |
| TL-S02 | Caps Lock dual role | Karabiner (earlier Kanata) | Caps held = ⌃, tapped = Esc | Ctrl on home row, Esc for vim | COMMITTED 459aabb8, e880ea5b, ff710b93; CURRENT (internal keyboard) |
| TL-S03 | Hyper on left ⌥ | Karabiner | hold left ⌥ = ⌃⌥⇧⌘ (`:lazy`) | Hyper modifier for app hotkeys | COMMITTED db003980; CURRENT (internal keyboard) |
| TL-S04 | Meh on left ⌃ | Karabiner | hold left ⌃ = ⌃⌥⇧; tap = F19 | Meh modifier; tap toggles dictation | COMMITTED ff710b93; CURRENT (internal keyboard) |
| TL-S05 | fn to ⌥ | Karabiner | fn key emits left ⌥ | Restore a plain Option key after left ⌥ became Hyper | COMMITTED db003980; CURRENT. That fn's ⌥ is not re-mapped to Hyper is INFERRED (Karabiner does not chain manipulators). |
| TL-S06 | Nav layer | Karabiner variable `nav_mode` | ⌃Space (Caps+Space on internal) toggles; Esc, Caps tap, copy, leader tap leave | Left-hand WASD arrows, word/line/page moves, clipboard, editing; NAV notification | CURRENT; COMMITTED 6c549fcc |
| TL-S07 | Nav select mode | Karabiner variable `nav_select` | tap left ⇧ inside the nav layer | Moves extend the selection until cut, paste or delete | CURRENT |
| TL-S08 | Nav cheatsheet | Karabiner shell_command + Swift overlay | backtick inside the nav layer | Floats an SVG drawn from the compiled rules; separate NocFree sheet | CURRENT; COMMITTED 6c549fcc |
| TL-S09 | NocFree firmware select bridge | Karabiner | F20 from the NocFree's layer-1 left ⇧ | Same select mode on the firmware nav layer | CURRENT; COMMITTED 324d9e72 |
| TL-S10 | 8BitDo dictation pad, base layer | Karabiner | pad buttons | d-pad arrows, A = dictation (sidekick script + F19), B Enter, X Backspace, Y Esc | CURRENT; COMMITTED 9ed21885, d97650e3 |
| TL-S11 | 8BitDo mouse layer | Karabiner variable `pad_mouse_mode` | Start toggles, with notification | d-pad scrolls, face buttons move cursor, bumpers click | CURRENT; COMMITTED 66816d3b |
| TL-S12 | 8BitDo per-app bumpers | Karabiner, frontmost-app condition | bumpers in Orca or Arc | Orca: previous/next worktree; Arc: previous/next tab | CURRENT; COMMITTED 9e9a61d0 |
| TL-S13 | Orca Zen mode | Karabiner, frontmost-app condition | ⌥Z in Orca | Runs `~/.local/bin/orca-zen-mode` | CURRENT; COMMITTED 1a0501ad |
| TL-S14 | Akimbo ⌘ | Karabiner, then Kanata | press both ⌘ together | Sends Fn+F12; target app never recorded | COMMITTED 459aabb8, e880ea5b; dropped ff710b93 (Karabiner), 6c549fcc (Kanata) |
| TL-S15 | Double-tap ⇧ one-shot Hyper | Kanata, then Karabiner | double-tap left ⇧; next key gets ⌃⌥⇧⌘ | Hyper without holding a key | COMMITTED e880ea5b, db003980; dropped ff710b93 |
| TL-S16 | Hammerspoon FuzzyOverlay | Hammerspoon | ⌃⌥⌘U, ⌃⌥⌘T, ⌃⌥⌘⇧T | fzf-like webview picker for repo URLs and repo files; pastes the choice | COMMITTED d51d75a3; removed 5c11b011 |
| TL-S17 | Hammerspoon debug and log | Hammerspoon | ⌃⌥⌘⇧D, ⌃⌥⌘⇧L | Toggle overlay debug logging, show log | COMMITTED d51d75a3; removed 5c11b011 |
| TL-S18 | Hammerspoon rebuild | Hammerspoon | Hyper+R | Compile Fennel with `make hammerspoon`, reload | COMMITTED d51d75a3; removed 5c11b011 |
| TL-S19 | Hammerspoon URL events | Hammerspoon `hs.urlevent` | `hammerspoon://gp-copy`, `gp-record` from Leader Key | GhostPepper x-callback value sinks | COMMITTED 8b96b99c; removed b4225c7d |
| TL-S20 | Hammerspoon timer | Hammerspoon `hs.timer` | every `interval_seconds` (900) | Runs `gemini-meeting-sync` and notifies | COMMITTED 4acd76fe; removed 5c11b011 |
| TL-S21 | Meh+D Claude queue macro | Karabiner, frontmost Orca/Ghostty | Meh+D | Types Home, `/q `, End, ⌃X Enter | COMMITTED 227c8446; moved to Tuna 120a706a |
| TL-S22 | System shortcut release | macOS defaults script | apply time | Deletes symbolic hotkeys 18, 26, 28-31, 64, 65, 164, 184 so Raycast/BTT can bind them | CURRENT `home/.chezmoitemplates/macos-defaults.sh.tmpl` |
| TL-S23 | BetterTouchTool | BTT | its own trigger database | Clipboard manager via shortcuts enabled; triggers and gestures not captured | CURRENT plist fragment; LIVE running |
| TL-S24 | WinMux chord release | WinMux config | n/a | Removes WinMux's default ⌃Q/W/E/R/T/F/H/L and all ⌘ chords so shells, Claude Code and macOS keep them | CURRENT; COMMITTED ea3ca3cd, 74e4b7ca |

## App-launch and command hotkeys

None of the trigger tools ever held a direct key-to-app table. App launches have
always gone through a launcher reached by the leader. The richest table was Leader
Key on 2026-07-04 (8b96b99c), ten single keys after a ⌘ tap. Today Tuna holds
seven, one level deeper under `a` (4a3a803e).

| Key | Target | Tool | Era | Evidence |
|---|---|---|---|---|
| leader, t | Ghostty, then iTerm (2026-01-15), then Ghostty again | Leader Key | 2025-11-12 to 2026-07-04 | COMMITTED a72c0752, ff2d5a8a, 8b96b99c |
| leader, a t | Orca | Tuna | 2026-07-04 onward (`t` at top level until 4a3a803e) | CURRENT |
| leader, s / a s | Slack | Leader Key, Tuna | 2025-11 onward (see the Leader Key map) | COMMITTED 7598d906; CURRENT |
| leader, b / a b | Arc (Chrome before 2026-07-04) | Leader Key, Tuna | 2025-11 onward (see the Leader Key map) | COMMITTED 7598d906, 8b96b99c; CURRENT |
| leader, g | Google Chrome | Leader Key | 2026-07-04 only | COMMITTED 8b96b99c; dropped 9235fa6c |
| leader, c / a c | Cursor (`v` before 2026-07-04) | Leader Key, Tuna | 2025-11 onward (see the Leader Key map) | COMMITTED 7598d906, 8b96b99c; CURRENT |
| leader, o | Orca | Leader Key | 2026-07-04 only; moved to `t` in Tuna (9235fa6c), plus `o o` since 2026-10-17 | COMMITTED 8b96b99c; CURRENT |
| leader, w | Obsidian | Leader Key | 2025-11-12 to 2026-07-04; `w` now means WinMux | COMMITTED 7598d906, 8b96b99c, 4a3a803e |
| leader, m / a m | Spotify (Meet before 2026-07-04) | Leader Key, Tuna | 2025-11 onward (see the Leader Key map) | COMMITTED 7598d906, 8b96b99c; CURRENT |
| leader, p / a 1 | 1Password | Leader Key (`p`), Tuna (`1`) | 2026-07-04 onward | COMMITTED 8b96b99c; CURRENT |
| leader, f / a f | Finder | Leader Key, Tuna | 2026-07-04 onward | COMMITTED 8b96b99c; CURRENT |
| leader, z group | G95NC sharp, m4mini VNC, DAYJOB password paste, temp-admin, GhostPepper record/copy | Leader Key, Tuna | 2026-07-04 onward | COMMITTED 8b96b99c; CURRENT |
| leader, o group | Orca: open, new worktree (Raycast deeplink), reveal/fork agent session, Zen mode | Tuna | 2026-10 | CURRENT |
| leader, w group | WinMux move left/right, columns off/3, sidebar | Tuna | 2026-10-08 onward | COMMITTED 4a3a803e; CURRENT |
| ⌥Z (Orca frontmost) | `orca-zen-mode` script | Karabiner | 2026-10-17 onward | CURRENT |
| ⌃⌥⌘U / ⌃⌥⌘T | repo URL / repo file picker | Hammerspoon | 2026-01-17 to 2026-09-07 | COMMITTED d51d75a3, 5c11b011 |
| Hyper+R | rebuild Hammerspoon | Hammerspoon | 2026-01-17 to 2026-09-07 | COMMITTED d51d75a3 |
| Meh+D (Orca/Ghostty) | Claude `/q` queue macro | Karabiner | 2026-08-30, hours | COMMITTED 227c8446, 120a706a |
| left ⌃ tap, 8BitDo A | F19, dictation toggle | Karabiner | 2026-05-02 onward | COMMITTED db003980, 9ed21885; CURRENT. VoiceInk's `toggleMiniRecorder2` is keycode 80 (F19) in its plist template; GhostPepper per the pad comment. Which app answers F19 today is INFERRED. |
| ⌘⌥V | VoiceInk paste last transcription | VoiceInk | 2026-05-10 onward | CURRENT `com.prakashjoshipax.VoiceInk.plist.tmpl` (keycode 9, mods 2304) |

## Invocation flows

```text
TL-F01  Leader to app (current)
  left ⌘ down, up within 200 ms, no other key
  -> Karabiner (goku rule "Tap left ⌘") emits F18 after ⌘ releases
  -> Tuna comboMode hotkey (keycode 79) opens the cheatsheet after 1000 ms
  -> a -> t  ->  tuna.common-actions/open path:/Applications/Orca.app
  If the nav layer is on, the same tap first runs :nav_off, then F18.
```

```text
TL-F02  Leader to app (2026-07-04, Leader Key)
  either ⌘ tapped alone (lazy modifier, 200 ms)
  -> Karabiner emits F18
  -> Leader Key activation hotkey F18 -> single key (t, s, b, g, c, o, w, m, p, f)
```

```text
TL-F03  GhostPepper via Hammerspoon (2026-07-04 to 2026-07-06)
  leader -> z r
  -> Leader Key runs `open "hammerspoon://gp-record"`
  -> Hammerspoon hs.urlevent opens ghostpepper://x-callback-url/... with
     x-success=hammerspoon://gp-status-sink
  -> sink notifies or copies the transcript
  Replaced by Tuna opening ghostpepper:// directly (b4225c7d).
```

```text
TL-F04  Repo picker (2026-01-17 to 2026-09-07)
  ⌃⌥⌘T
  -> Hammerspoon FuzzyOverlay: borderless webview + eventtap captures typing
  -> bin/repo-index TSV feeds candidates; fuzzy filter
  -> Enter pastes the choice with ⌘V into the frontmost app
```

```text
TL-F05  Nav layer edit
  ⌃Space (Caps+Space on the laptop)   -> nav_mode=1, "NAV" notification
  w a s d / q e / 1 2 / t g           -> arrows, word, line, page moves
  tap left ⇧                          -> nav_select=1, "NAV · SELECT"
  x or v                              -> ⌘X / ⌘V and select mode ends
  c                                   -> ⌘C and the layer exits
  `                                   -> cheatsheet overlay toggles
  ⌃Space, Esc or a Caps tap           -> :nav_off (clears both vars, banner, overlay)
```

```text
TL-F06  Dictation from the pad
  8BitDo A (keycode g)
  -> Karabiner runs ~/.local/bin/dictation-sidekick (unmutes or re-mutes the mic)
  -> then emits F19 -> dictation app toggles recording
```

```text
TL-F07  Claude draft queue (2026-08-30)
  Morning: Meh+D in Orca/Ghostty -> Karabiner types Home "/q " End, ⌃X Enter
  Same day: leader -> a -> q -> ~/bin/claude-queue-draft (System Events types it)
  2026-10-08: the Tuna chord was removed with the "ai" group (4a3a803e);
  the script, /q command and ⌃X Enter pin remain.
```

## Customizations on top

- **Hammerspoon FuzzyOverlay (Fennel, ~1,800 lines).** A reusable fzf-style picker
  component in a borderless `hs.webview`, keyboard driven through an `hs.eventtap`,
  with async filtering, a file log at `~/Library/Logs/Hammerspoon/repoOverlay.log`,
  and debug toggles. `init.lua` was a small stable loader that enables `hs.ipc` and
  `dofile`s `init.generated.lua`; the Fennel compiled through `make hammerspoon`,
  later `just hammerspoon`, and at apply time through
  `run_onchange_after_25-hammerspoon.sh.tmpl`. Host for the Gemini sync timer and,
  briefly, GhostPepper x-callback sinks.
- **Goku EDN.** Named device groups (`:zero2`, `:internal`, `:nocfree` with both cable
  and dongle IDs), app groups (`:orca`, `:arc`), named `:tos` sequences (`:nav_off`,
  `:nav_select_off`, `:fw_select_off`) so every exit cleans up, and `[:condi ...]`
  block markers to state device and layer gates once per block. The file carries a
  standing instruction to agents to check Goku and Karabiner behaviour against source
  with `ask` instead of memory.
- **Apply-time cheatsheet.** `scripts/macos/render-keymap` draws SVG cheatsheets (ANSI
  and NocFree) from the compiled profile; a small Swift overlay
  (`home/.chezmoiassets/keymap-overlay.swift`) shows them non-activating with an
  opacity flag.
- **Kanata layers.** One base layer over four keys: tap-hold-press Caps, tap-dance
  left ⇧ into a one-shot Hyper built from four one-shot modifiers, and a `fork` plus
  virtual-key trick to detect both ⌘ keys within 50 ms (Akimbo). Comments say it
  was "Ported from Karabiner".
- **BetterTouchTool.** Only five preference booleans through the plist merge stub
  (clipboard manager from shortcuts on, legacy UI off, remote off, Touch Bar off,
  list view on) and a license template. No gestures or triggers in git.
- **Tests.** `tests/scenarios/config/karabiner.py` and `tests/bats/config/karabiner.bats`
  compile the EDN with `goku --dry-run-all` and assert the rule set; the Kanata
  parser test was removed with Kanata.

## What we're partial to / what carried forward

Carried through every tool switch:

- **Caps Lock = Esc on tap, Ctrl on hold.** In the first committed Karabiner JSON
  (459aabb8), in Kanata (e880ea5b), in Karabiner again (db003980), and in Goku today.
  The NocFree carries it in firmware as `MT(Ctrl, Esc)`. This is the most stable
  binding in the repo.
- **A bare modifier tap as the launcher key.** Leader Key, then Tuna, have been
  summoned by a lone modifier tap mapped to F18 since 2026-07-04; only the modifier
  changed. Earlier double-tap-⇧ Hyper (Kanata, Karabiner) is the same instinct.
- **Hyper.** ⌃⌥⇧⌘ existed as one-shot double-tap ⇧ (Kanata, early Karabiner), as
  Hammerspoon's `hyper` table, and as hold-left-⌥ (Karabiner since 2026-05-02, still
  current).
- **Left-hand reach.** Leader Key's app keys were described as "left-hand app
  launchers" (8b96b99c); the leader is "left hand only" (CURRENT rule comment); the nav
  layer is a "left-hand navigation layer". The same app letters (s Slack, b browser,
  c Cursor, m media, f Finder) survived the Leader Key to Tuna port.
- **Config as code, compiled at apply time.** Fennel to Lua, EDN to JSON, and Tuna's
  TOML with `tuna config reload` all follow the same "edit source, generate target"
  shape that ADR 0009 calls the repo's codegen idiom.

Dropped, with the stated or visible reason:

- **Akimbo ⌘ (Fn+F12)** dropped from Karabiner in ff710b93 when remaps were scoped to
  the internal keyboard. No reason given. Kanata kept it until removal.
- **Double-tap ⇧ one-shot Hyper** dropped in the same commit. Karabiner can only
  approximate tap-dance with variables (ADR 0044 lists this as a cost).
- **Tap ⇧ leader** dropped in 6c549fcc: the 100 ms window was "easy to fire by
  accident and unreliable on purpose".
- **Kanata** removed in 6c549fcc / ADR 0044: it could not run alongside the
  Karabiner app, never ran as a daemon on master, and the Mac needs to know layer
  state for the notification and cheatsheet.
- **Hammerspoon** removed in 5c11b011 with no commit body. Its jobs had already moved:
  GhostPepper glue to Tuna (b4225c7d), launcher shell actions to Tuna and Raycast
  (orcactl plan rewritten from a Hammerspoon example to "launcher shell command").
  The repo picker hotkeys were not replaced in this layer (INFERRED from the absence
  of any successor binding).
- **Meh+D macro** moved to Tuna within hours (120a706a): Tuna owns sequences,
  Karabiner owns remaps.

## Config and data model

| Tool | Source in repo | Generated target | Who owns the target | Apply step |
|---|---|---|---|---|
| Karabiner (2026-01 to 2026-06) | `.config/karabiner/karabiner.json`, later `home/dot_config/private_karabiner/private_karabiner.json` | same file | chezmoi | copy |
| Karabiner + Goku (current) | `home/dot_config/karabiner.edn.tmpl` (Go template; only `{{ .chezmoi.homeDir }}` is templated) | `~/.config/karabiner/karabiner.json`, `Default` profile's `complex_modifications` only | goku; the JSON is `.chezmoiignore`d | `run_onchange_after_45-karabiner-goku.sh.tmpl`: hash-triggered, seeds `karabiner-base.json` (Default profile, Keychron combo devices 13364/289 and 13364/1968 not ignored, ANSI virtual keyboard) or renames the active profile to `Default`, runs `goku`, renders cheatsheets |
| Kanata | `.config/kanata/kanata.kbd`, later `home/dot_config/kanata/kanata.kbd` | `~/Library/Application Support/kanata/kanata.kbd` (2026-01 apply script), later `~/.config/kanata/kanata.kbd` | chezmoi | none; no daemon on master |
| Hammerspoon | `home/dot_hammerspoon/init.fnl` + `init.lua` | `~/.hammerspoon/init.generated.lua` | apply hook | `fennel --compile` in `run_onchange_after_25-hammerspoon.sh.tmpl`, rerun on source hash |
| BetterTouchTool | `home/.chezmoitemplates/com.hegenberg.BetterTouchTool.plist.tmpl` + modify stub; license template | merged keys in the BTT plist | shared merge engine; gated on the `bettertouchtool` cask | plist merge |
| Tuna (target of the leader) | `home/dot_config/tuna/config.toml`, `com.brnbw.Tuna.plist.tmpl` | live config | chezmoi + `run_onchange_after_46-tuna-reload` | `tuna config reload` |
| macOS symbolic hotkeys | `home/.chezmoitemplates/macos-defaults.sh.tmpl` | `com.apple.symbolichotkeys.plist` | apply script | PlistBuddy disables IDs |

A short-lived Nix branch (ab244be1, b5cd8e6d, 2026-05-18, not on master) moved
Hammerspoon into `nix/modules/home/hammerspoon.nix` and Karabiner JSON into
`home/dot_config/karabiner/`. It never landed.

## Gaps and open questions

1. **⌘Space has two owners.** Raycast's live global hotkey is ⌘Space (LIVE) and
   Tuna's committed `hotkeys.app.activate` is also ⌘Space (CURRENT and LIVE). Both
   apps are running. Which one wins is not recorded anywhere. Earlier, Alfred also held
   ⌘Space (2025-11).
2. **Raycast's hotkey is not in git.** 82a47c37 lists `raycastGlobalHotkey` as a
   deferred TODO.
3. **Tuna's double-⌥ trigger versus Hyper.** On the internal keyboard left ⌥ is
   remapped to Hyper. Whether Tuna still sees a "double press of left Option" there
   is untested.
4. **What consumed Akimbo's Fn+F12** was never written down.
5. **Which dictation app answers F19 today** (VoiceInk mini recorder or GhostPepper)
   is ambiguous from the repo.
6. **Hyper and Meh barely have consumers.** Checked 2026-10-19: no Karabiner rule,
   Tuna bind or committed app hotkey uses Hyper. Meh's only committed consumer is
   WinMux's `ctrl-alt-shift-c` (column count 3); its shipped defaults could not be
   listed because WinMux was not running. Raycast hotkeys remain unreadable.
7. **BetterTouchTool has no triggers now.** Triggers and gestures were never in git.
   LIVE, read from a copy of its store: the current store
   (`version_6_937`) holds zero triggers, while the August store (`version_6_725`)
   held 120, all without Hyper or Meh. INFERRED: they were lost in a BTT upgrade
   around 2026-10-06.
8. **Pre-2025 history** has casks only (Alfred, BTT, legacy Karabiner from 2016),
   no hotkey config. The 2014-2015 commits contain nothing in this layer.
9. **Hammerspoon removal reason** is not stated; the app and `~/.hammerspoon` still
   exist on this Mac (LIVE), unmanaged.
10. **KeyPath** is installed (LIVE) but not in packages or config; its role, if any,
    is outside the repo.
11. **Leader Key's activation key before 2026-07-04** was not captured.
12. **Symbolic-hotkey labels:** the comment in `macos-defaults.sh.tmpl` mislabelled
    28-31 and 64/65; it was corrected alongside this corpus (28-31 screenshots, 64/65
    Spotlight and Finder search). The labels for 18, 26, 164 and 184 are unverified.
    Disabling 28-31 also removes the stock screenshot shortcuts; whether BTT or another
    tool rebinds them is not in git.
