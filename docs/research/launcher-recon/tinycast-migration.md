---
status: draft
doc_type: research
summary: "Self-contained summary of the research toward replacing Raycast and Tuna with Tinycast: what must move, how Tinycast handles files, config, snippets and sync, the open risks, and a handoff for further research."
created: 2026-10-19
updated: 2026-10-19
related:
  - README.md
  - tinycast-file-search.md
  - raycast.md
  - leader-key-and-tuna.md
  - trigger-layer.md
  - alfred.md
  - ../crdt-sync-atop-git.md
  - ../../plans/raycast-config-automation-plan.md
status_detail: "Desk research only: Tinycast read at abue-ammar/tinycast@ead1f770 and never installed or run. No migration plan exists yet."
---

# Migrating to Tinycast

Prateek runs Raycast and Tuna day to day and is considering
[Tinycast](https://github.com/abue-ammar/tinycast) as the launcher that owns ⌘Space.
This document gathers everything researched toward that move on 2026-10-19 so a
reader, human or agent, can continue without the sessions that produced it. The
evidence lives in the sibling documents it links; this page states the conclusions
and what is still unknown.

## Where things stand

Tinycast is a plausible replacement for Raycast's launcher, snippets and clipboard
history. Its snippets are plain Markdown files and its settings can live in a
dotfile, both of which fit this repo. Three things are not yet known: whether
Tinycast can run the repo's Raycast script commands and its `orca-worktree`
extension, whether it can replace Tuna's leader sequences, and whether its file
search matches Alfred's. Nothing has been installed. The next step is a hands-on
trial of a beta build, described in the [handoff](#handoff-further-research).

## Decisions and proposals

Accepted by Prateek on 2026-10-19:

- Neither Raycast nor Tuna should own ⌘Space; Tinycast is the candidate. The move
  itself is under consideration, not decided.
- Snippets and clipboard history move out of Raycast.
- Alfred is dropped. Its cask, license template and refs, and capture entry were
  removed from the repo on the same day.
- Chrome (`a g`), Obsidian (`a w`) and Ghostty (`a e`) return to the Tuna leader,
  inside the `a` group. Done on the same day.

Proposed in this document and not yet accepted: the
[migration sequence](#proposed-migration-sequence) and the sync options for
clipboard history.

## What Tinycast would have to replace

The [launcher recon](README.md) reconstructed what is actually used from git history.
The items that matter for a move:

| Today | Owner | Tinycast equivalent | Status |
| --- | --- | --- | --- |
| ⌘Space fuzzy launcher | Raycast's live hotkey; Tuna's committed config also claims it, and which wins is unrecorded | Global hotkey and root search | Supported |
| File search, ideally Alfred-style prefix | Raycast (disliked) | Own filename index; no prefix mode | Partial; see [file search](#file-search) |
| Snippets, including the LLM prompt library | Raycast encrypted store | One Markdown file per snippet | Supported; import path exists |
| Clipboard history | Raycast encrypted store | Local SQLite with full-text index | Supported; no sync |
| Script commands in `home/dot_config/raycast/scripts/`: Temp Admin, G95NC Display, Reveal Orca Agent Session (documented as ⌥A) and Fork Orca Agent Session (documented as ⌥F; neither hotkey verified) | Raycast, repo-managed | Unknown | Unverified |
| `orca-worktree` custom extension (`home/dot_local/share/raycast-extensions/orca-worktree/`) | Raycast dev extension, repo-managed | Tinycast runs Raycast extensions without Node | Unverified for this extension |
| Store extensions: 1Password, Kill Process, Launchd Monitor and others | Raycast | Same extension runtime | Unverified per extension |
| Leader sequences: left ⌘ tap → F18 → `a`/`o`/`w`/`z` groups, 26 binds | Tuna, fed by Karabiner | Per-app hotkeys, `hyper+` hotkeys, aliases; leader sequences not found | Gap unless confirmed |
| Window moves and columns | WinMux (Tuna `w` group, Meh chord) | Built-in window management | Overlap; pick one owner |

The recon's strongest preference signals should survive the move: ⌘Space for a fuzzy
launcher, a bare-modifier leader with one-letter groups, launchers as thin triggers
over repo-owned scripts, and config generated or reloaded from the repo. The Tuna
leader is the hardest to replace; keeping Tuna for sequences alongside Tinycast is a
valid end state.

## File search

Full detail, with source citations, is in [Tinycast file search](tinycast-file-search.md).

- **Version split.** Stable v0.11.19 searches through Spotlight. Main and the betas
  (from v0.11.20-beta.119) use Tinycast's own filename index, a port of fsearch,
  crawled by a helper process and kept current from FSEvents.
- **Matching.** File names only; every typed word must appear as a substring, with
  location weighting. Not fuzzy, no content search, Full Disk Access required.
- **No prefix mode.** The maintainer closed requests for space-to-file-search (#1070)
  and Tab-into-folder (#1125) as not planned. The nearest equivalents are a dedicated
  Search Files hotkey, inline Files results, or an alias on the command.
- **Alfred's prefix.** Alfred's documented quick prefix is a leading space; the `'`
  Prateek remembers was probably a custom keyword. Alfred searched through Spotlight's
  metadata.

## Config, content and sync

These findings come from a separate Claude Code session on 2026-10-19, titled
"Tinycast config sync", that read the same commit. Its transcript is not part of
the repo, so every claim below was rechecked against the Tinycast repository.

- **Settings file.** `~/.config/tinycast/settings.json` is an opt-in two-way mirror of
  the app's preferences (Settings → Backup → Settings File;
  `docs/features/settings-file.md`). Edits apply within about 150 ms. It follows a
  symlink and keeps it, so a chezmoi-managed file works. It ignores
  `$XDG_CONFIG_HOME`, and the app rewrites the file, so comments do not survive.
  Missing keys keep their values, and shortcuts for absent apps are preserved, which
  suits one file shared across Macs.
- **What the file holds.** Preferences, hotkeys as text (`cmd+shift+v`, `hyper+k`),
  aliases, and all of window management. It never holds content (snippets, notes,
  quicklinks, custom commands, MCP servers) or capability grants: Snippets,
  Extensions and similar switches can only be turned on in the app.
- **Snippets and notes** are Markdown files in folders that can be moved with
  `snippets.folder` and `notes.folder`, so chezmoi or git can own them.
- **Clipboard history** is an unencrypted local SQLite file (`clipboard.sqlite3`).
  Pointing a sync tool at the live database is unsafe.
- **Backups.** A `.tinycast` archive exports settings, clipboard history (JSONL plus
  PNGs), snippets, notes and launcher learning. Import merges clipboard and snippets,
  renames clashing notes, and replaces launcher learning.
- **Import from Raycast.** Tinycast imports Raycast v2's encrypted `.rayconfig`
  export, including snippets and clipboard history (`docs/features/raycast-import.md`).
  This is the route out of Raycast's store.
- **No cross-machine sync.** An iCloud sync PR (#1255) was closed unmerged on
  2026-10-01 because CloudKit needs a notarized Developer ID the maintainer cannot
  get. Issue #886 (iCloud clipboard sync, "Already Implemented") is open, though the
  PR's category list omits clipboard history. Self-hosted sync (#477) is closed, labelled
  completed on GitHub, but the maintainer's closing comment defers it: "i have
  plans for sync support but not this early."
- **Telemetry.** None claimed and no analytics SDK found. A daily GitHub Releases
  update check can be turned off with `general.automaticallyCheckForUpdates`.
- **Platform.** macOS 26 or newer; separate casks for Apple silicon and Intel.

### Sync options for clipboard history (proposed)

Snippets and settings sync cleanly as files under chezmoi. Clipboard history does
not. The [CRDT-on-git survey](../crdt-sync-atop-git.md) bears on this: it found that
append-only data merges correctly in git as a grow-only set of lines, as
[chronicle](https://github.com/geekmuse/chronicle), a tool that syncs agent session
JSONL through git, does. Tinycast already exports clipboard history as JSONL, so
one option is to export per machine, merge the JSONL as a set in git, and import,
relying on Tinycast's skip-duplicates import. That is untested, and deletions would
not propagate. The simpler option is to keep clipboard history per machine until
Tinycast ships sync.

## Proposed migration sequence

Not accepted; a starting point for a plan.

1. Install a Tinycast beta beside Raycast on one Mac. Before first launch, confirm
   the version-matched telemetry claim and turn off the update check if unwanted, per
   the repo's telemetry rule in `AGENTS.md`. Enable the settings file.
2. Export Raycast's `.rayconfig`, import it into Tinycast, and check that snippets
   and clipboard history arrive intact.
3. Move the snippets folder under chezmoi and the settings file into the repo.
4. Test each repo-owned Raycast command and the `orca-worktree` extension in
   Tinycast; record which work.
5. Bind file search and compare it with Raycast on real queries.
6. Decide the ⌘Space owner and Tuna's future, then retire Raycast pieces in the same
   way Alfred was retired.

## Risks

- The file index and the extension runtime are young: the index landed on
  2026-10-12 and ships only in betas.
- The maintainer declines many feature requests, including the prefix mode.
- No sync means each Mac drifts unless the repo carries the files.
- The work Mac is stuck on Tuna 0.78, plausibly because a corporate download filter
  blocks Tuna's site (inferred, not recorded in the repo). Tinycast downloads may face
  the same filter there. Untested.

## Handoff: further research

This section is for a fresh agent continuing the work with no other context.
Treat every item as a lead to verify against primary sources.

### What was searched

- Tinycast source, docs and issues at `ead1f770401b34f69065e279704a119d04609986`,
  read through `gh api` and a shallow clone: file search, snippets, clipboard,
  settings file, backup, Raycast import, updates, extensions.
- Alfred's and Raycast's official file-search documentation.
- This repo's git history for every launcher and hotkey tool, recorded in the
  [launcher recon](README.md).
- CRDT and auto-sync tools that use git, in the [survey](../crdt-sync-atop-git.md).

### What was not searched

- **Hands-on behavior.** Tinycast was never installed. Nothing about speed, ranking
  quality, extension compatibility or import fidelity has been observed.
- **Script commands.** Whether Tinycast runs Raycast script commands (the
  `@raycast` header scripts in `home/dot_config/raycast/scripts/`) or offers an
  equivalent custom-command format.
- **Leader sequences.** Whether Tinycast supports multi-key sequences comparable to
  Tuna's combo mode, or a hotkey that opens a command group.
- **Extension compatibility.** Which Raycast APIs the Tinycast runtime supports, and
  whether the repo's `orca-worktree` extension and the 1Password, Kill Process and
  Launchd Monitor store extensions run.
- **Window management.** How Tinycast's window features compare with WinMux and
  Moom, and whether its default hotkeys collide with Karabiner's Hyper, Meh and nav
  layer.
- **Community evidence.** Hacker News threads were seen as titles only; Reddit and
  other forums were not read. Direct page fetches are blocked on the work Mac.
- **Personal Mac.** All live checks ran on the work Mac.

### Next steps, in priority order

1. Read Tinycast's extension and custom-command docs at a current commit and list
   supported Raycast APIs; check script-command support.
2. Search Tinycast's docs and issues for leader, sequence, chord or group hotkeys.
3. Install a beta on the personal Mac and run the
   [proposed sequence](#proposed-migration-sequence) steps 1, 2, 4 and 5, recording
   results here or in a sibling note.
4. Check whether a Tinycast alias on Search Files passes the trailing query.
5. Check whether the corporate filter blocks Tinycast's cask or update downloads on
   the work Mac.
6. If clipboard sync matters, prototype the JSONL set-merge option above with two
   machines.

### Decisions still open

- Whether Tuna stays for leader sequences or Tinycast replaces it.
- Which tool owns window management: WinMux, Moom or Tinycast.
- Whether to adopt a beta build or wait for the file index to reach a stable release.
- Whether clipboard history needs to sync at all.

### Suggested skills

- `search` for Tinycast issues, docs and community discussion.
- `ask` for version-matched Tinycast source, pinned to a commit.
- `browser` or `peekaboo-vm-app-audit` to drive and screenshot a Tinycast trial.
- `chezmoi-management` to bring the settings file and snippets folder under the repo.
- `prototype` for the clipboard set-merge experiment.
- `doc-coauthoring` and `document-lifecycle` when this research becomes a plan.
