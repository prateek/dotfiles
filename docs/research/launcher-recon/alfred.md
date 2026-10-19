---
status: draft
doc_type: research
summary: "Recon map of Prateek's Alfred and Spotlight usage from git history: surfaces, invocations, customizations, config model, and what carried forward."
created: 2026-10-19
updated: 2026-10-19
related:
  - README.md
---

# Recon: Alfred and Spotlight

Evidence comes from this repo's git history (all refs). Labels: COMMITTED (seen in a past commit), CURRENT (at HEAD), LIVE (read-only check on this machine on 2026-10-19), INFERRED. Secret values and snippet bodies were not read into this doc. A former employer's internal hostnames appear in the committed web searches; they are described here by function only.

## Era and status

- **2016-10-13: adopted.** `cask 'alfred'` appears in the first Brewfile (`049be18d`). It stays in every Brewfile rewrite after that (`e947ece2` 2020, `fd73e810` and `f12b31ed` 2023). COMMITTED.
- **2016-10-13: Spotlight cut back.** The Mathias-style `.macos` adds a Spotlight block (`35d41b80`) that excludes `/Volumes` from indexing and trims `com.apple.spotlight orderedItems` to apps, system prefs, directories, PDF and fonts, with web and suggestion results turned off. That block survives, nearly unchanged, at HEAD. COMMITTED, CURRENT.
- **2024-02-25: Cmd-Space named as Alfred's.** A bootstrap TODO reads "command+space to alfred, not spotlight (disable via Settings -> Keyboard)" next to "remove spotlight" from the menu bar (`3aade3e8`). It was carried into `78d9b7b0` (2025-09-24). COMMITTED.
- **2025-09-22: Raycast arrives.** The Raycast cask lands in the Brewfile (`769a5e98`). Alfred stays installed. COMMITTED.
- **2025-11-11 to 2026-04-22: Alfred's live prefs in the repo.** Alfred's sync folder pointed straight at `~/dotfiles/osx-apps/alfred`, as the captured `syncfolder` default in `459aabb8` shows. The first commit was titled "alfred prefs" (`3a24187f`, 604 files at peak). Later commits were Alfred writing into the repo: clipboard and hotkey prefs for a new machine (`27b45613`, `a72c0752`), new snippets (`3d5c8e05` 2026-01-02, `bfacd69a` 2026-01-03), and a default-results scope change (`d51ddcc2` 2026-04-22). Raycast was already installed for all of this, so Alfred was still being tuned in April 2026. COMMITTED.
- **2026-04-29 to 2026-05-10: prefs removed from source.** The chezmoi migration plan first planned to classify the sync folder and exclude private subtrees (`e7e70ce6`). It then reversed: "keep preferences and workflows out of source until there is an explicit redaction/adoption path" (`fcc62bd6`, landed on master as `7598d906`). The same commit added the secret-backed license template. COMMITTED.
- **2026-06-30: kept as a cask on purpose.** `6b4014fb` dropped `alfred` from package groups without comment. About two hours later `813394f5` put it back into the shared `mac-desktop` group as one of the "daily-driver apps across work and personal". COMMITTED.
- **2026-10-19: dropped.** Prateek decided to drop Alfred. The cask, the license template, the `alfred_license` refs in `secrets.toml` and `licenses.toml`, and the `capture.sh` domain were removed in the same change as this corpus update. Homebrew does not uninstall on apply; the app is removed per host.
- **Before the drop (HEAD `a134f6e2`).** `{ name = "alfred" }` sits next to `raycast` and `tuna` in `home/.chezmoidata/packages.toml` under "Input, window, launcher, and browser-routing tools". The license template `home/Library/Application Support/Alfred/License/private_Alfred.alfredlicense.tmpl` exists, but `secrets.toml` has an empty `alfred_license` ref (`02c164a3` notes "Moom and Alfred refs stay empty"). `scripts/macos/capture.sh` still knows the `com.runningwithcrayons.Alfred-Preferences` domain. `docs/references/chezmoi-architecture.md` states the policy: cask plus license, with prefs left to Alfred's own sync. CURRENT.
- **LIVE (this machine).** `/Applications/Alfred 5.app` is installed but not running. The `syncfolder` default is unset and `~/Library/Application Support/Alfred` does not exist. Raycast is running with `raycastGlobalHotkey = Command-49` (Cmd-Space). Spotlight symbolic hotkey 64 is `enabled = false`.
- **Machines.** The committed sync folder holds 8 per-machine `preferences/local/<hash>/` directories, so at least 8 Alfred installs shared it over its lifetime. Three of them carry Yosemite-era theme ids and the old 1Password feature toggle. INFERRED: the sync folder predates 2025 and was copied into the repo from an older location.

## Sources

| # | commit | date | path(s) | what it shows |
|---|---|---|---|---|
| 1 | `049be18d` | 2016-10-13 | `Brewfile` | First `cask 'alfred'` |
| 2 | `35d41b80` | 2016-10-13 | `.macos` | Spotlight block: `/Volumes` exclusion, pruned `orderedItems`, web results off |
| 3 | `f12b31ed` | 2023-03-26 | `Brewfile` | Alfred pinned to `/Applications` |
| 4 | `3aade3e8` | 2024-02-25 | `bootstrap.sh` | TODO: Cmd-Space to Alfred, not Spotlight; remove Spotlight from menu bar |
| 5 | `769a5e98` | 2025-09-22 | `Brewfile` | Raycast cask added |
| 6 | `3a24187f` | 2025-11-11 | `osx-apps/alfred/Alfred.alfredpreferences/**` | Full sync folder: prefs, 8 workflows, snippets, web searches, themes, Remote pages |
| 7 | `27b45613`, `a72c0752` | 2025-11-11/12 | `preferences/local/d4c658…/` | New machine's hotkey, clipboard, appearance |
| 8 | `3d5c8e05`, `bfacd69a` | 2026-01-02/03 | `snippets/global`, `snippets/LLM` | Snippets still being added in 2026 |
| 9 | `459aabb8` | 2026-01-11 | `osx-apps/defaults/com.runningwithcrayons.Alfred-Preferences.plist`, `scripts/macos/apply.sh` | `syncfolder` = repo path; apply script points Alfred at the repo |
| 10 | `c54beaf4`, `7168658d` | 2026-01-11 | `scripts/audit/settings-coverage.sh`, `README.md` | Alfred listed as a managed config |
| 11 | `406b7801` | 2026-01-12 | `osx-apps/gui-apps.yaml`, `scripts/macos/*` | `apply_config_alfred`: sync mode vs seed-copy mode; accessibility and automation permissions |
| 12 | `d51ddcc2` | 2026-04-22 | `preferences/features/defaultresults`, `local/e14024…/defaultresults/scope` | Last Alfred tuning: Homebrew Cellar in scope, home excluded |
| 13 | `01ed35cf` | 2026-04-28 | `.macos` | Disables symbolic hotkeys `18 26 28-31 64 65 164 184` "that conflict with Raycast/BTT/Hammerspoon" |
| 14 | `e7e70ce6`, `fcc62bd6` | 2026-04-27/29 | `dev/docs/chezmoi-migration-plan.md` | Plan to classify the sync folder, then reversal to "not managed" |
| 15 | `7598d906` | 2026-05-10 | whole tree | Sync folder deleted; license template and `licenses.toml` added |
| 16 | `813394f5` | 2026-06-30 | `home/.chezmoidata/packages.toml` | Alfred re-added as a shared daily-driver cask |
| 17 | `02c164a3` | 2026-09-18 | `licenses.toml`, `secrets.toml`, license template | License target path declared; ref left empty |
| 18 | HEAD | 2026-10-19 | `home/.chezmoitemplates/macos-defaults.sh.tmpl` | Current Spotlight `orderedItems`, reindex gate, disabled hotkeys |

## Core loop

Cmd-Space to launch apps by fuzzy name. The same box ran a handful of third-party workflows (1Password, fzf file search, time zones, units, dates, process kill). Comma-prefixed snippets expanded LLM prompts and reference text, and Cmd-Shift-C opened clipboard history. Spotlight was demoted to a trimmed indexer behind it.

## Surfaces

| ID | surface | how invoked | purpose | evidence |
|---|---|---|---|---|
| AL-S01 | Main search box | Cmd-Space (all 8 machine hashes; one with extra side-specific modifier bits) | Launch apps (fuzzy, app keywords on), open files and folders | `3a24187f` `local/*/hotkey/prefs.plist`; `3aade3e8` TODO |
| AL-S02 | Fallback searches | Enter on a query with no match | Google, Wikipedia, then four custom fallbacks | `features/defaultresults/prefs.plist` (`3a24187f`) |
| AL-S03 | Custom web searches | keywords `s`, `e`, `uown`, `g`, `sub` (`ub` disabled) | Work code search, metrics explorer, ownership lookup, Glean, Feedbin subscribe | `features/websearch/prefs.plist` `customSites` |
| AL-S04 | Clipboard history | Cmd-Shift-C | Text, image and file history; fast-append; remote clipboard ignored | `features/clipboard/prefs.plist`; `local/*/features/clipboard` |
| AL-S05 | Snippets viewer and auto-expansion | Opt-G viewer; typed keywords with collection prefixes `,` `g` `t` | Expand LLM prompts and reference blobs, date stamp, canned reply, email | `features/snippets/prefs.plist`; `snippets/*/info.plist` |
| AL-S06 | File actions panel | Tab on a result (right arrow off); Cmd-. for Finder selection | Act on files; 14 default actions disabled, sorted by usage | `features/filesearch/actions/prefs.plist` |
| AL-S07 | File navigation | `prev` keyword | Jump back to the previous path | `features/filesearch/navigation/prefs.plist` |
| AL-S08 | Terminal prefix | `>` prefix (Alfred default) into iTerm | Run a shell command in iTerm through a custom AppleScript | `features/terminal/prefs.plist` (application=1, vitorgalvao script) |
| AL-S09 | Large Type | Alfred default Cmd-L | Show text huge on the mouse screen, auto-hide | `appearance/largetype/prefs.plist` |
| AL-S10 | 1Password workflow | `1p`; `:1pextras`; `!1pdiagnostic`; also a fallback | Search vault items and open-and-fill; modifier keys copy fields | `workflows/user.workflow.BB4E1CC9…` |
| AL-S11 | fzf workflow | `fzf`, `fzf-history`, `fzf-edit-history`; file action "FZF Search from Here"; fallback | fd plus fzf file and directory search from `~`, excluding `Library` | `workflows/user.workflow.04BE9BD1…` |
| AL-S12 | TimeZones workflow | `tz`; `timezone add|update|move` | World clock | `workflows/user.workflow.5C023506…` |
| AL-S13 | Units workflow | `u` | Unit conversion | `workflows/user.workflow.2E0FB445…` |
| AL-S14 | Date Formats workflow | `df` | Timestamp and date-format conversion | `workflows/user.workflow.EC358F62…` |
| AL-S15 | Top workflow | `top`, `kill` | List and kill processes | `workflows/user.workflow.CBD7F618…` |
| AL-S16 | TerminalFinder workflow | `fi` (Finder to iTerm), `if` (iTerm to Finder) | Open the current Finder folder in iTerm and back | `workflows/user.workflow.A529FBAA…` |
| AL-S17 | Send to Yoink | File action "Add to Yoink" | Park files on the Yoink shelf | `workflows/user.workflow.38BB6DA8…` |
| AL-S18 | Alfred Remote | iOS app | Default page set only (Applications, Folders, System, Music, Bookmarks, Preferences) | `remote/pages/*`; `preferences/remote` `performedInitialSetup` |
| AL-S19 | Spotlight search | Cmd-Space, then nothing: hotkey 64 is disabled at HEAD | Displaced by Alfred, then Raycast | `01ed35cf`; LIVE hotkey 64 false |
| AL-S20 | Spotlight index and categories | none; feeds Finder, mdfind and other launchers | Index kept on; categories trimmed; web and suggestions off; reindexed on apply | `35d41b80`; CURRENT `macos-defaults.sh.tmpl` |

## Invocation flows

**AL-F01 Launch an app**
- Goal: open an app without the Dock.
- Trigger: Cmd-Space, then type a few letters (fuzzy match, app keywords on), then Enter.
- Outcome: app opens; the window opens on the mouse's screen at a saved position, without the menu bar icon, cog or hat.
- Happy-path keys: Cmd-Space, 2 to 4 letters, Enter.
- Edge cases: the default-results scope gained `/usr/local/Cellar` and `/opt/homebrew/Cellar` and dropped `~` on one machine (`d51ddcc2`), so Homebrew-installed `.app` bundles show up but home-folder noise does not.

**AL-F02 Search the web or work tools from the box**
- Goal: query a work tool or the web without opening a browser first.
- Trigger: Cmd-Space, then `s <query>` (code search), `e <query>` (metrics explore), `g <query>` (Glean), `uown <query>` (ownership) or `sub <url>` (Feedbin). Anything else falls through to the Google and Wikipedia fallbacks.
- Outcome: browser opens the search URL.
- Edge cases: every bundled web search except Google was disabled. `wa` (Wolfram) and `yt` (YouTube) got custom keywords and were later disabled anyway. Four fallback ids point at custom sites that no longer exist in `customSites` (dangling, INFERRED stale).

**AL-F03 Paste from clipboard history**
- Goal: re-paste something copied earlier.
- Trigger: Cmd-Shift-C, filter, Enter.
- Outcome: the item is pasted into the frontmost app.
- Edge cases: images and files are recorded on newer machines, remote (Universal) clipboard is ignored, sounds are off. `persistFor=3` and `limit=3` are Alfred enum values (INFERRED: a 3-month retention tier).

**AL-F04 Expand an LLM prompt or reference blob**
- Goal: drop a stock prompt, spec scaffold or `llms.txt` dump into a chat or editor.
- Trigger: type `,` plus a keyword (for example `,uvh` or `,stackeddiff`) and auto-expansion replaces it. Alternatively Opt-G to browse.
- Outcome: snippet text is inserted in place.
- Edge cases: one snippet is about 198k characters (a full library `llms.txt`), so the snippet store was doubling as a context-paste library. Collection prefixes keep the keywords from colliding: `,` for LLM, `g` for GTD, `t` for Support, none for the global email expander.

**AL-F05 Get a 1Password item**
- Goal: log in or copy a credential.
- Trigger: Cmd-Space, `1p <name>`, then Enter to open and fill. Cmd views the item in 1Password, Opt copies the username, Ctrl the password, Shift the OTP.
- Outcome: the browser opens and fills, or the field lands on the clipboard.
- Edge cases: the workflow defaults were left alone (no committed per-workflow `prefs.plist`). Older machines also had Alfred's native 1Password feature enabled.

**AL-F06 Find a file with fzf**
- Goal: fuzzy-find a file or directory anywhere under `~`.
- Trigger: `fzf <query>`, or the file action "FZF Search from Here" on a folder.
- Outcome: matching paths are listed, and the chosen one opens or is revealed.
- Edge cases: `fd --exclude Library`; history of up to 1000 queries.

**AL-F07 Bounce between Finder and terminal**
- Goal: open the folder in front of you in iTerm, or reveal the shell's cwd in Finder.
- Trigger: `fi` or `if`, then Enter. `> cmd` runs a command in iTerm in a new tab.
- Outcome: a new iTerm tab or Finder window at that path.

**AL-F08 Quick utilities**
- Goal: answer a conversion question inline.
- Trigger: `tz` (world clock), `u 5 km in mi`, `df now` or `df <epoch>`, `top` or `kill <proc>`.
- Outcome: the result shows in the list, and Enter copies it or acts on it.

**AL-F09 Keep Spotlight out of the way**
- Goal: Cmd-Space must reach the third-party launcher, and Spotlight must not leak queries.
- Trigger: `chezmoi apply` runs `macos-defaults.sh.tmpl`.
- Steps: write `orderedItems` (5 categories on, web and suggestions off), disable symbolic hotkeys 64 and 65, `killall mds`, `mdutil -i on /`, `mdutil -E /` unless `DOTFILES_SKIP_SPOTLIGHT_REINDEX=1`.
- Outcome: Spotlight's hotkey is dead and its index rebuilt. Raycast (earlier Alfred) gets Cmd-Space.
- Edge cases: before `01ed35cf` (2026-04-28) the hotkey hand-off was manual (the 2024 TODO). The reindex costs "minutes of fan noise", hence the gate.

## Customizations on top

**Workflows.** Eight, all third-party, none authored by Prateek. Workflow auto-update was on and the workflow palette was shown (`preferences/workflows/tasks`).

| workflow | author | keywords | notes |
|---|---|---|---|
| 1Password 25.1 | Vítor Galvão (`com.alfredapp.vitor.1password`) | `1p`, `:1pextras`, `!1pdiagnostic` | Official Alfred-team workflow; fallback-enabled |
| fzf-alfred-workflow 1.7.1 | Yoichiro Hasebe | `fzf`, `fzf-history`, `fzf-edit-history`, file action | Search path `~`, `fd --exclude Library` |
| TimeZones 1.61 | Carl Smith | `tz`, `timezone add/update/move` | Ships 224 flag icons |
| Units 3.4 | Thijs de Jong (Design and Such) | `u` | PHP converter |
| Date Formats Rust 1.5.0 | Dean Karn | `df` | Rust binary |
| Top | Patrick Stadler | `top`, `kill` | |
| TerminalFinder | LeEnno | `fi`, `if` | Packal-era workflow |
| Send to Yoink 3.5.3 | Matthias Gansrigler | file action | Yoink is still a CURRENT cask |

No workflow had a hotkey assigned; every `trigger.hotkey` slot is empty. Everything was reached by keyword.

**Snippets.** Four collections, 14 snippets, auto-expansion on, expansion sounds off. Categories only:
- LLM (prefix `,`, 10 snippets): MCP and library `llms.txt` reference dumps, prompt templates (idea honing, spec writing, stacked-diff restructuring, testing an MCP server), and code scaffolds (uv script header, simple JS artifact, single-markdown output).
- GTD (prefix `g`, 2): date stamp and document-metadata header.
- Support (prefix `t`, 1): canned recruiter reply.
- global (no prefix, 1): email-address expander (`@@`).
- The legacy `clipboard/snippets.alfdb` SQLite store is empty (0 rows).

**Web searches.** Six custom sites, five enabled: three former-employer internal tools (code search, metrics explore, ownership), a go-link service (disabled), Glean, and Feedbin subscribe. Every bundled search except Google was disabled, including Wikipedia, which nevertheless stays in the fallback list.

**Appearance.** Custom themes "Big Dark and Smooth" and "Yosemite", with bundled OS X Dark on newer machines. The menu bar icon, cog and hat are hidden. The window saves its position and opens on the mouse screen, with a per-machine vertical offset (`yPoint` 3 to 6).

**Behavior toggles.** Fuzzy app matching. App keywords on. Image, folder, text, archive and document results on. File actions open on Tab, not right arrow, and are sorted by usage. 14 default file actions disabled (Open With, Email, Get Info, Browse Folder, Copy/Move-replace, Find Similar, and others). Copied paths are escaped. Notifications go to output 1. The Chrome bookmarks profile is `Default` on one machine.

**Integrations.** The iTerm custom AppleScript (vitorgalvao's custom-alfred-iterm-scripts) is the terminal target, and the native 1Password feature was enabled on older machines. Alfred Remote finished setup but kept the stock pages.

**Spotlight customizations.** Categories trimmed (`35d41b80`, CURRENT). `/Volumes` excluded from indexing (2016 only). Menu bar icon removal was a TODO (2024). Hotkeys 64 and 65 disabled (`01ed35cf`, CURRENT). Reindex gate `DOTFILES_SKIP_SPOTLIGHT_REINDEX` (ADR 0012, `dfac6c0e`). Spotlight metadata is also reused by `scripts/audit/brewfile-usage.sh`, which reads cask last-used dates through `mdls`.

## What we were partial to / what carried forward

The strongest signals are things that survived the switch to Raycast, or that kept getting edits after Raycast arrived:

- **Cmd-Space as the launcher chord.** Alfred held it on all 8 machines, and the 2024 TODO names it explicitly. Raycast holds it now (LIVE `Command-49`), and the repo disables Spotlight's binding so a third-party launcher can take it (`01ed35cf`). Carried forward. must.
- **Snippets, especially LLM prompts and context dumps.** Added as late as 2026-01-03, after Raycast was installed. The sibling Raycast recon finds no Raycast snippet config in git. Not carried into any managed tool. INFERRED: still served by Alfred or lost; see Gaps. must.
- **Clipboard history.** Configured carefully (images, files, fast-append, remote ignored). No successor shows up in git. should.
- **Custom work web searches with short keywords.** Five enabled, each with a one- or two-letter keyword. They were tied to a former employer and did not carry forward. Raycast quicklinks are not visible in git. should.
- **1Password from the launcher.** Workflow installed plus the native feature. 1Password and its CLI remain CURRENT casks; whether Raycast's 1Password extension replaced the workflow is not in git. should.
- **Terminal and file ergonomics** (fzf workflow, TerminalFinder, iTerm `>` prefix, Send to Yoink). Yoink is still a CURRENT cask. The rest are not visible as Raycast config. could.
- **Utility workflows** (TimeZones, Units, Date Formats, Top). Raycast covers most of these natively (INFERRED). could.
- **Own automation.** Alfred never got a Prateek-authored workflow. Raycast did: script commands (Temp Admin, Orca agent session, g95nc) and a local `orca-worktree` extension under `home/dot_config/raycast` and `home/dot_local/share/raycast-extensions` (CURRENT). Building on top moved to Raycast, not Alfred.
- **Dropped: Alfred prefs in source.** Removed because the sync folder mixed per-machine hashes, clipboard DBs, Remote assets, employer URLs and personal snippets. The plan said "until there is an explicit redaction/adoption path" (`fcc62bd6`, `7598d906`). The app itself stayed (`813394f5`).
- **Dropped: Spotlight as a launcher.** Its hotkey has been off since `01ed35cf`. Its indexer stays on, because everything else (Finder, `mdls`, Raycast file search with `kMDQueryScopeComputer`) depends on it.

## Config and data model

- **Alfred.alfredpreferences bundle.** A plain directory synced by Alfred, with these subtrees:
  - `preferences/` holds synced feature prefs: `features/{clipboard,snippets,defaultresults,filesearch,websearch/<site>,terminal,1password,system}` and `appearance/`.
  - `preferences/local/<machine-hash>/` holds per-Mac overrides: hotkey, theme choice, clipboard enablement, default-results scope, and the 1Password toggle.
  - `workflows/user.workflow.<UUID>/` holds one directory per workflow, with `info.plist` as the object graph of triggers, inputs and actions plus user-config defaults.
  - `snippets/<collection>/` holds an `info.plist` for prefix and suffix, plus one JSON file per snippet.
  - `clipboard/snippets.alfdb` is a legacy SQLite snippet store.
  - `resources/` holds custom web-search icons.
  - `remote/` holds Alfred Remote pages and images.
- **Pointer.** `defaults com.runningwithcrayons.Alfred-Preferences syncfolder` points Alfred at that bundle's parent. The license lives separately at `~/Library/Application Support/Alfred/License/Alfred.alfredlicense`.
- **How the repo managed it.**
  1. 2016 to 2025: the cask only, prefs unmanaged.
  2. 2025-11 to 2026-01: the sync folder pointed at the repo, so Alfred committed itself, with no redaction.
  3. 2026-01-11/12: `scripts/macos/apply.sh` wrote `syncfolder`. `406b7801` split this into a `sync` mode (point at the repo) and a `seed` mode (copy into a seed dir), plus a `defaults import` of the Alfred-Preferences domain.
  4. 2026-05-10 onward: chezmoi manages the cask and a private license template rendered from an `op://` ref, and the prefs are explicitly unmanaged (`7598d906`, `docs/references/chezmoi-architecture.md`).
  5. The Nix experiment (`ab244be1`/`b5cd8e6d`, 2026-05-18) carried the same license-only model, then was not landed on master.
- **Spotlight.** `com.apple.spotlight orderedItems` via `defaults write`, the hotkey via PlistBuddy into `com.apple.symbolichotkeys.plist`, and indexing via `mdutil`. All are in `home/.chezmoitemplates/macos-defaults.sh.tmpl` and run by `run_onchange_after_30-macos-defaults.sh.tmpl`.

## Older Alfred history outside this repo

Prateek used Alfred heavily from about 2014 to 2023, with more workflows than the
eight above, including some of his own. None of that library reached this repo:
before 2025-11 the dotfiles installed only the cask. A second sweep on 2026-10-19
covered every ref, the stash, the reflog, unreachable commits, blobs and trees,
`~/.local/share/chezmoi`, `dotfiles-private`, the home folder and `~/Library`,
iCloud and CloudStorage, and 91 gists. It found three GitHub forks:

- `prateek/alfred-datetime-format-converter`, a fork of Michael Waterfall's
  workflow (`com.michaelwaterfall.datetime-format-converter`, keyword `df`). Prateek
  added three commits on 2017-06-24, including a millisecond and nanosecond
  timestamp fix in `workflow/process.py`. "Date Formats Rust" later took the same
  `df` keyword.
- `prateek/MyAlfred` (raguay's Alfred 2 workflows) and `prateek/alfred-python`
  (nikipore's library), both forked 2014-01-12, carry none of his commits.

A February 2023 talk in `prateek/presentations` calls Alfred "my jam" and demos
snippets (`gcanthelp`, `gdate`), clipboard history, the calculator, units and a
timestamp converter. The 2025-11 snapshot has an empty legacy snippet store and
current workflow versions, so it was a fresh setup rather than the older library.
INFERRED: the older sync folder lived in Dropbox or iCloud on earlier Macs; only a
backup or an old machine could still hold it.

## Gaps and open questions

- **Where do snippets and clipboard history live now?** On this machine Alfred is not running, and git shows no Raycast or other snippet or clipboard config. Either the Raycast snippet and clipboard features are configured by hand (unmanaged), or the LLM snippet library was lost in the switch. Checking Raycast's local database read-only, or asking Prateek, would settle it.
- **Why reinstall Alfred in June 2026 if it is idle?** `813394f5` deliberately re-added it to both work and personal machines, but nothing configures or launches it. It could be a fallback, the snippet engine on the personal Mac, or a license already paid. Not answerable from git.
- **Dangling fallbacks.** Four `features.websearch.custom.*.fallback` ids have no matching `customSites` entry. They are probably sites deleted after being set as fallbacks.
- **Alfred version history.** Alfred 5 is installed (LIVE). Earlier major versions are visible only through theme ids and workflow vintages (Packal). There is no record of when the Powerpack license was bought, and the `op://` ref is empty in `secrets.toml`.
- **The odd hotkey modifier.** Machine `19b21e1a…` stores Cmd-Space with `mod=3222274048` (Cmd plus high bits). INFERRED: a side-specific Cmd (for example right-Cmd only) or a double-tap variant. Unverified.
- **Spotlight menu bar icon.** The 2024 TODO to remove it never landed as config.
