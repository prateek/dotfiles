---
status: draft
doc_type: research
summary: "Recon map of Prateek's Raycast usage from git history: surfaces, invocations, custom scripts and extensions, config model, and what carried forward."
created: 2026-10-19
updated: 2026-10-19
related:
  - README.md
  - ../../plans/raycast-config-automation-plan.md
---

# Recon: Raycast

Evidence labels: **COMMITTED** (in git history), **CURRENT** (in the tree at
HEAD `a134f6e2`), **LIVE** (read-only check on this machine, 2026-10-19),
**INFERRED** (my reading, not stated anywhere).

## 1. Era and status

- **Adoption.** Raycast is in the earliest repo snapshot of this era:
  `769a5e98` (2025-09-22) has `cask "raycast"` in the Brewfile and a Claude
  permission for `manual.raycast.com`. It has been installed continuously
  since then, through the Brewfile era, the chezmoi migration (`7598d906`,
  2026-05-10) and the machine-type package refactors (`88ce0d83`, `6b4014fb`).
  COMMITTED.
- **Machines.** The `raycast` cask sits in the `mac-desktop` group of
  `home/.chezmoidata/packages.toml`, which both `personal` and `work` machine
  types include. `homelab` and `ci` don't get it, so Raycast config is
  unmanaged there (`6b4014fb` flips those test expectations to
  `expect_unmanaged`). Temp Admin only does real work on the work Mac. On a
  personal Mac it reports that you're already admin. CURRENT.
- **Coexisting launchers.** Alfred is installed next to it (`alfred` cask
  right after `raycast` in the same group, re-added to shared apps in
  `813394f5`, 2026-06-30). Leader Key ran as the chord launcher until Tuna
  replaced it (`9235fa6c`, 2026-07-04). CURRENT.
- **State at HEAD.** The repo manages an 18-key plist fragment, five files
  under `~/.config/raycast/scripts/` (four script commands plus a Node RPC
  adapter), one custom dev extension (`orca-worktree`), and its build hook.
  Store extensions, hotkeys and per-extension prefs are not managed. The
  config-automation plan is `proposed` and deferred. CURRENT.
- **LIVE:** Raycast 2.8.2.0 is installed. `raycastGlobalHotkey = Command-49`
  (⌘Space) is set but not in the repo. The deployed scripts dir holds all five
  files, `~/.local/share/raycast-extensions/orca-worktree` exists,
  `~/.config/raycast/extensions` has 28 entries, and an `ai/` dir exists.

## 2. Sources

| # | commit | date | path(s) | what it shows |
|---|---|---|---|---|
| 1 | `769a5e98` | 2025-09-22 | Brewfile, Claude settings | Raycast cask present at start of era |
| 2 | `3a24187f`, `27b45613` | 2025-11-11 | `osx-apps/alfred/…` | Alfred owned snippets (`LLM` collection), clipboard and hotkey prefs in a dotfiles sync folder |
| 3 | `459aabb8` | 2026-01-11 | `scripts/macos/capture.sh` | First Raycast plist capture; strips `raycastAnonymousId` and PostHog IDs |
| 4 | `c54beaf4` | 2026-01-11 | audit scripts | Notes Raycast is "better synced via its own account/cloud" |
| 5 | `01ed35cf` | 2026-04-28 | macOS provisioning | Disables system hotkeys that conflict with Raycast/BTT |
| 6 | `237c318d` | 2026-04-29 | `home/.chezmoiassets/…/com.raycast.macos.json` (branch) | First readable desired-prefs JSON (19 keys incl. `showGettingStartedLink`) |
| 7 | `7598d906` | 2026-05-10 | `home/.chezmoitemplates/com.raycast.macos.plist.tmpl`, `modify_private_…plist.tmpl` | Chezmoi migration lands; plist fragment + 3-line modify stub |
| 8 | `e74ce011` | 2026-05-10 | `home/Library/private_Preferences/…` | Stub moved to `private_Preferences` |
| 9 | `ab244be1`, `b5cd8e6d` | 2026-05-18 | nix flake (branch `origin/claude/migrate-chezmoi-to-nix-a1pMX`) | Abandoned nix port treated Raycast as a partial-merge plist; never merged |
| 10 | `1e4bc99d` | 2026-06-15 | `scripts/executable_temp-admin.sh` | First script command: Temp Admin (Jamf elevation) |
| 11 | `288c0fb9` → `9f1b1bba` | 2026-06-20 | `scripts/executable_g95nc.sh` | G95NC display switcher; nine commits that day add, then strip, fast/dual-cable modes |
| 12 | `3abf28f9` | 2026-06-21 | `dot_config/raycast/extensions/orca-worktree/` | Custom extension "Create Orca Worktree" |
| 13 | `1ff6bc3c` | 2026-06-21 | `dot_local/share/raycast-extensions/orca-worktree/` | Relocation (Raycast rejects dev sources in its own dir), React double-instance fix |
| 14 | `306ec77a`, `c8277067` | 2026-07-02/04 | g95nc | Unplug survival; "Raycast/Tuna binds" call `g95nc set` |
| 15 | `9235fa6c` | 2026-07-04 | `dot_config/tuna/config.toml`, `Library/Scripts/temp-admin.sh` | Tuna binds reuse `~/.config/raycast/scripts/temp-admin.sh` |
| 16 | `6c56155f` | 2026-08-17 | plist fragment | Drops `showGettingStartedLink` (app turns it off after onboarding) |
| 17 | `e93aafee`, `4108734b`, `f7027b15` | 2026-08-25 | `scripts/executable_orca-agent-session.py` | Reveal Orca Agent Session (⌥A); agentsview daemon start added then reverted |
| 18 | `e89f9a19` | 2026-08-25 | `scripts/executable_orca-fork-agent-session.sh` | Fork Orca Agent Session (⌥F) |
| 19 | `82a47c37` | 2026-08-31 | `docs/plans/raycast-config-automation-plan.md` | Deferred backlog: global hotkey, store extensions, Launchd Monitor, rejected approaches |
| 20 | `035cca93`, `5b1f1420` | 2026-08-31, 10-01 | LaunchAgents | Launchd Monitor extension watches `com.prateek.*` agents |
| 21 | `916a35a4` | 2026-09-03 | `run_after_21-raycast-extensions.sh.tmpl` | Digest-based rebuild of local extensions |
| 22 | `d8a9b75f`, `30f50801`, `843a6051` | 2026-09-26 → 10-07 | session helper, `orca-agent-rpc.cjs` | Multi-agent and remote-host fixes for ⌥A/⌥F and the worktree picker |
| 23 | `87b070f7` | 2026-10-06 | temp-admin | Admin-wait timeout raised to 120s for browser sign-in |
| 24 | `c8071b9a`, `cb669308`, `dc74d744` | 2026-10-12/15 | dotpkgs, orca-worktree `package.json` | dotpkgs `raycast` provider; exact dep pins after a TypeScript bump broke peer ranges |
| 25 | `22e43e7e` | 2026-10-17 | `dot_config/tuna/config.toml` | Tuna Orca group: `raycast://extensions/prateek/orca-worktree/create-worktree` plus direct reveal/fork |
| 26 | `cd29deee` | 2026-10-17 | `evals/search-index/cases.jsonl` | Eval cases: Raycast alternatives, clipboard/snippets API, Tuna vs Raycast callbacks, PR-dashboard host |

## 3. Core loop

⌘Space opens Raycast. Prateek runs a repo-owned script command or the Orca
worktree form by name or hotkey, and the command shells out to a CLI he
maintains (Orca, BetterDisplay, Jamf, agentsview), then reports back in a HUD
or compact output.

## 4. Surfaces

| ID | surface | how invoked | purpose | evidence |
|---|---|---|---|---|
| RC-S01 | Root search / main window | ⌘Space (`raycastGlobalHotkey=Command-49`) | Entry to everything; compact mode, vim nav, large text | LIVE hotkey; fragment keys CURRENT (`7598d906`); plan lists hotkey as unmanaged TODO (`82a47c37`) |
| RC-S02 | Script command: Temp Admin | Root search "Temp Admin"; also Tuna `z t`, earlier Leader Key | Trigger Jamf Self Service temp-admin and poll for `admin` group | `1e4bc99d`, `8b96b99c`, `9235fa6c`, `87b070f7` |
| RC-S03 | Script command: G95NC Display | Root search, dropdown arg (sharp / butter / reset / check) | BetterDisplay CLI mode switch for the Samsung G95NC | `288c0fb9`, `1c7c2ca7`, `b082028b` |
| RC-S04 | Script command: Reveal Orca Agent Session | ⌥A (documented binding) when Orca is frontmost | Copy focused pane's agent session ID, open agentsview at it | `e93aafee`, `f7027b15`, `d8a9b75f` |
| RC-S05 | Script command: Fork Orca Agent Session | ⌥F (documented binding) | Fork the focused agent session into a new Orca split | `e89f9a19`, `d8a9b75f`, `843a6051` |
| RC-S06 | Custom extension: Create Orca Worktree | Root search; deep link `raycast://extensions/prateek/orca-worktree/create-worktree` (Tuna `o n`) | Form: repo, name, agent, prompt (+ advanced) → `ohc` clone + Orca worktree + agent | `3abf28f9`, `1ff6bc3c`, `22e43e7e` |
| RC-S07 | Store extension: Launchd Monitor (menu bar) | Menu bar item | Watch `com.prateek.wiki-sessions-sync` and `com.prateek.devbox-orca-tunnel` | `82a47c37`, LaunchAgent comments (`035cca93`, `5b1f1420`); LIVE status item visible |
| RC-S08 | Store extensions (others) | Root search | Plan says eight installed; LIVE plist names `1password`, `kill-process`, `launchd-monitor` | `82a47c37`; LIVE |
| RC-S09 | Emoji picker | Root search | Skin tone pinned to `standard` | fragment CURRENT |
| RC-S10 | File search | Root search | Scope pinned to whole computer | fragment CURRENT |
| RC-S11 | Floating Notes | Root search | Format bar and autoresize turned off | fragment CURRENT |
| RC-S12 | Raycast AI | Unknown | `~/.config/raycast/ai` and `AI_*` plist keys exist; nothing in repo | LIVE only |
| RC-S13 | Menu bar icon | n/a | Raycast's own icon hidden (`NSStatusItem VisibleCC raycastIcon=false`) | fragment CURRENT |

No quicklinks, snippets, aliases, window-management commands, fallback
commands or clipboard-history settings appear anywhere in git for Raycast.
Snippets and clipboard history show up only under Alfred (`3a24187f`,
`27b45613`).

## 5. Invocation flows

**RC-F01: Temp admin on demand**
- Goal: get temporary admin on the work Mac without running `chezmoi apply`.
- Trigger: Raycast "Temp Admin" (later also Tuna `z t`) → script exits early
  if already admin → sources `~/.config/dotfiles/elevation.sh` for method and
  policy ID → opens the Self Service deep link → polls `id -Gn` → outcome:
  compact "admin" or timeout message.
- Keystrokes: ⌘Space, "temp", ↵. Or the Tuna chord.
- History: the policy ID is never committed and is read at runtime
  (`1e4bc99d`). The timeout went from 30s to 120s because the browser sign-in
  takes longer (`87b070f7`). Leader Key and then Tuna call the Raycast script
  path directly (`8b96b99c`, `9235fa6c`), so the Raycast scripts dir is the
  canonical home even when Raycast isn't the trigger.

**RC-F02: Switch G95NC display mode**
- Goal: flip the ultrawide between sharp HiDPI 60Hz and butter HiDPI 120Hz,
  or recover it.
- Trigger: Raycast "G95NC Display" → dropdown (sharp / butter / reset / check)
  → BetterDisplay CLI creates or tears down the virtual screen → compact
  status.
- Edge cases: on 2026-06-20 alone the script gained fast mode, dual-cable/PBP
  awareness and RGB Full normalisation, then lost all of them (`a32f7d8a`,
  `9f1b1bba`). Unplugging orphaned virtual screens until the EDID identity
  was pinned (`306ec77a`). The default resolution moved to 4864x1368
  (`c8277067`). A verified butter mode came later (`1c7c2ca7`), and reset now
  clears BetterDisplay completely (`b082028b`). The same file is also the
  `g95nc` CLI via a `~/bin` symlink, and Tuna binds `g95nc set`.

**RC-F03: Reveal the focused agent's session**
- Goal: jump from an Orca terminal to that agent's transcript in agentsview.
- Trigger: ⌥A with Orca frontmost → gate on Orca frontmost → resolve the
  focused pane via the public `orca` CLI and the private
  `session.tabs.list` provider-session binding → copy the session ID → open
  `agentsview://` (web UI as fallback) → silent HUD.
- Edge cases: a down agentsview daemon first auto-started (`4108734b`), then
  was reverted to "report and still copy the ID" because the daemon lifecycle
  belongs to the app (`f7027b15`). Lookup used to pick another pane's newer
  session or miss older ones past a 100-session cutoff (`d8a9b75f`). Remote
  panes were rejected by the local-only vault until `843a6051`. The
  storage move required setting the agentsview data dir explicitly because
  Raycast doesn't read shell startup files (`c2253d08`).

**RC-F04: Fork the focused agent's session**
- Goal: branch the conversation in a new split without disturbing the
  original.
- Trigger: ⌥F → same resolver as RC-F03 → per-agent native fork:
  `claude --resume --fork-session`, `codex fork`, `pi --fork`, `droid --fork`,
  OMP `--fork` → new Orca split.
- Edge cases: cursor-agent and gemini can only resume, which would mean two
  live writers, so they fail and leave the ID copied (`e89f9a19`). OMP
  support and preserving Codex's home came in `d8a9b75f`. Remote sessions fork
  on their execution host via `orca-agent-rpc.cjs` (`843a6051`). Per the
  plan, the hotkeys themselves have never been verified, because Raycast's
  store is encrypted.

**RC-F05: Create an Orca worktree from a form**
- Goal: clone a GitHub repo and start an agent in a new Orca worktree.
- Trigger: Raycast "Create Orca Worktree" (or Tuna `o n` deep link) → form
  with repo, name, agent and prompt, plus a "Show advanced options" toggle →
  `execFile` the `ohc` zsh autoload, which returns JSON → result view.
- Edge cases: the first location under `~/.config/raycast/extensions` was
  rejected as "Invalid development sources location". NodeNext module
  resolution loaded two copies of React, so every hook threw. `ray build`
  stripped `"type": module` on every apply and caused permanent chezmoi drift
  (all in `1ff6bc3c`). Source-only edits never triggered a rebuild until the
  digest hook (`916a35a4`). The agent picker was hard-coded to three agents
  until it read Orca's `preflight.detectAgents` (`d8a9b75f`).

**RC-F06: Watch launch agents from the menu bar**
- Goal: see at a glance whether the wiki session sync and devbox tunnel
  agents are alive.
- Trigger: the Launchd Monitor menu bar item, configured with `launchdLabels`.
- Edge cases: the labels live in Raycast's encrypted store, so they have to be
  set by hand on each machine (`82a47c37`).

## 6. Customizations on top

**Script commands** (`home/dot_config/raycast/scripts/`, deployed to
`~/.config/raycast/scripts/`, gated on the raycast cask in `.chezmoiignore`):

| Script | Mode | Inputs | Calls | Output |
|---|---|---|---|---|
| `temp-admin.sh` | compact | none | `~/.config/dotfiles/elevation.sh`, Jamf Self Service URL, `id -Gn` | status line |
| `g95nc.sh` (547 lines) | compact | dropdown arg | BetterDisplay CLI and prefs | status line; also `~/bin/g95nc` |
| `orca-agent-session.py` (527 lines, PEP 723 uv script) | silent | flags `--fork`, `--json`, `--copy`, `--dry-run`, `--worktree` | `orca` CLI, Orca private runtime RPCs, agent CLIs, `agentsview://` | HUD and clipboard; also `~/bin/orca-agent-session` |
| `orca-fork-agent-session.sh` | silent | none | `exec orca-agent-session.py --fork` | HUD |
| `orca-agent-rpc.cjs` | n/a | JSON on stdin | Orca's packaged `runtime-client.js` | JSON (paired-server adapter) |

Pattern: every script is both a Raycast command and a plain CLI, with a
shebang that adds Homebrew paths because Raycast starts scripts with a minimal
PATH (`e93aafee`). That design is what let Tuna reuse them without changes.

**Custom extension:** `orca-worktree`. Source lives in
`home/dot_local/share/raycast-extensions/orca-worktree/` and is
unpublished. Its one view command, `create-worktree`, depends on
`@raycast/api` and has `node --test` tests wired into `just test-node`.
`run_after_21-raycast-extensions.sh.tmpl` runs `npm ci` and `ray build` on a
digest change. Registration stays manual: run `npm run dev` once per machine.
dotpkgs manages it as the `raycast` provider (install and update only;
removal must be manual) (`c8071b9a`).

**Store extensions:** none installed by automation. The plan's rejected list
covers vendoring, a chezmoi external against the ~17 GB monorepo, and
`.rayconfig` (`82a47c37`).

**Pinned plist keys** (fragment, 18 keys). The why is INFERRED except where
noted.
- Navigation: `navigationCommandStyleIdentifierKey=vim`, page keys `arrows`.
  This fits a vim-first keyboard setup.
- Window: `raycastPreferredWindowMode=compact`, `raycastUI_preferredTextSize=large`,
  `popToRootTimeout=15`.
- Theme: `bundled-sky` and Raycast light/dark, following system appearance.
- Clutter: menu bar icon hidden, `useHyperKeyIcon=false`. Settings show only
  customized commands.
- Feature defaults: file search across the whole computer, emoji skin tone,
  Floating Notes chrome.
- Removed: `showGettingStartedLink`, because asserting `true` fought the app
  (`6c56155f`).
- Never captured: `raycastAnonymousId` and PostHog IDs, which were stripped
  as early as `459aabb8`.

**Hotkeys:** ⌘Space global (LIVE, unmanaged). ⌥A and ⌥F are documented in the
script headers but unverified (orca-shortcuts plan). macOS symbolic hotkeys
18, 26, 28–31, 64, 65, 164 and 184 are disabled for Raycast/BTT
(`macos-defaults.sh.tmpl`). No aliases are recorded anywhere.

## 7. What we're partial to / what carried forward

- **Scripts that double as CLIs.** This is the strongest pattern. Each Raycast
  command ships as a file other launchers can call. Leader Key (`8b96b99c`)
  and then Tuna (`9235fa6c`, `22e43e7e`) bind the same paths, so the trigger
  moved and the logic stayed.
- **Orca agent workflow.** The newest and most iterated surface: 3 commands
  and ~10 commits between 2026-08 and 2026-10. Raycast is where the
  focused-pane resolver started. Tuna's `o` group now calls the same helper
  directly, and reaches Raycast only for the worktree form via deep link
  (`22e43e7e`).
- **Hardware and admin utilities.** G95NC and Temp Admin are small personal
  tools that ended up as Raycast commands first.
- **Moved out of Raycast to other tools.**
  - Chorded app and shell launching went to Leader Key and then Tuna. Both
    act as a second launcher next to Raycast, not a replacement.
  - Hammerspoon integrations were removed (`5c11b011`), which takes
    Hammerspoon out of the "external triggers" list in the Orca docs.
  - Prateek's agent memory notes (outside git) say the store "pull-requests"
    extension was retired on 2026-09-03 in favour of `prv`. Git has no record
    of this. The only trace
    is eval case SEARCH-074 (`cd29deee`), which compares Raycast, Alfred,
    Hammerspoon, SwiftBar, Tauri and others as hosts for a keyboard-first PR
    dashboard. INFERRED link.
- **Never in Raycast (per git).** Snippets and clipboard history were Alfred
  features (`3a24187f`, `27b45613`). The October 2026 eval cases ask whether
  Raycast's clipboard and snippets are scriptable and what the alternatives
  are (`cd29deee`). That suggests these features are being reconsidered, but
  nothing has been committed. INFERRED.
- **Dropped.** G95NC fast and dual-cable modes. The original
  `~/.config/raycast/extensions` location. The JSON-asset prefs format
  (branch `237c318d`), replaced by the plist fragment. The nix port of the
  Raycast plist (unmerged branch).

## 8. Config and data model

| Store | Owner | Repo-managed? |
|---|---|---|
| `~/Library/Preferences/com.raycast.macos.plist` | Raycast | Partly: an 18-key desired fragment merged by `scripts/macos/plist-merge` through a 3-line `modify_` stub, which leaves unclaimed keys alone |
| `~/.config/raycast/scripts/` | Repo | Yes (chezmoi). Raycast's script-directory registration is manual, and per the Jamf reference it isn't in the readable plist |
| `~/.local/share/raycast-extensions/<name>/` | Repo | Yes (source + build). Import into Raycast is manual once per machine; build stamps live under `$XDG_STATE_HOME/dotfiles/` |
| `~/.config/raycast/extensions/<uuid>/` | Raycast | No. Opaque `com.raycast.api.cache` only (plan) |
| `raycast-enc.sqlite` (store-extension identity, per-extension prefs, hotkeys, aliases) | Raycast | No. Encrypted |
| Cloud Sync | Raycast account | No. Treated as the sync path since `c54beaf4`. Per agent memory notes (outside git), Raycast 2 Cloud Sync overwrote `searchDirectories` with the other Mac's absolute home path. Git doesn't record this |

The boundary: the repo owns readable UI prefs, script files and extension
source. Raycast owns registration, bindings and anything per-extension. Each
new machine therefore needs three manual steps: add the script directory,
import the dev extension, and assign hotkeys and set Launchd Monitor labels.

## 9. Gaps and open questions

- `raycastGlobalHotkey` is still unmanaged, even though the plan calls it
  "the one key that makes a fresh machine feel wrong". LIVE shows it set by
  hand.
- ⌥A and ⌥F have never been verified (orca-shortcuts plan, two open items).
- The eight store extensions are unnamed in git. LIVE shows only three by
  plist key.
- Raycast AI: LIVE artifacts exist, but there is no repo evidence of use or
  configuration.
- The `prv` replacement and the Raycast 2 migration come only from agent
  memory notes. Commits record neither, so their dates and causes aren't
  evidence-backed here.
- Unclear whether Raycast quicklinks, snippets, aliases or window management
  were ever used. Everything there sits in the encrypted store.
- The `macos-defaults.sh.tmpl` comment mislabelled IDs 28–31 and 64/65; it was
  corrected alongside this corpus. See the [trigger-layer gaps](trigger-layer.md#gaps-and-open-questions).
