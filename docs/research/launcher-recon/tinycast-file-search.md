---
status: draft
doc_type: research
summary: "How Tinycast indexes and searches files compared with Alfred and Raycast, plus its snippet, clipboard, config and telemetry model, for a possible move off Raycast."
created: 2026-10-19
updated: 2026-10-19
related:
  - README.md
  - alfred.md
  - raycast.md
status_detail: "Source and docs read at abue-ammar/tinycast@ead1f770; Tinycast not installed or run."
---

# Tinycast file search

Prateek loved Alfred's file search: one prefix in the main box switched to file
search, and it found files fast and accurately. Raycast's file search has been worse.
He is considering [Tinycast](https://github.com/abue-ammar/tinycast) as the next
launcher. This note answers how Tinycast finds files and what it would take to get
Alfred's prefix behaviour back.

Tinycast citations are pinned to commit `ead1f770401b34f69065e279704a119d04609986`
(main, 2026-10-19). Alfred and Raycast claims come from their official help pages.
Nothing was installed or run.

## Version caveat

The stable release and main differ:

- **Stable v0.11.19 (2026-10-10)** searches files through Spotlight. The README at
  the pinned commit still says "through Spotlight, with no index of our own"
  (`README.md:47-48`).
- **Main and the betas** replaced that with Tinycast's own index on 2026-10-12
  (`9aea65b8`, #1537). It first shipped in v0.11.20-beta.119; the newest beta is
  v0.12.1-beta.123 (2026-10-19).

The rest of this note describes main.

## How Tinycast finds files

**Index.** A Swift port of the engine from
[fsearch](https://github.com/noahdunnagan/fsearch). A separate `FileIndexHelper`
process crawls the scopes with `getattrlistbulk` on up to eight workers and never
forces iCloud placeholders to download (`FileIndexCrawler.swift:138,165`). It
writes `~/Library/Application Support/<bundle id>/FileIndex/index.bin`, about nine
bytes per entry, which the app memory-maps. FSEvents keeps it current with about one
second of latency (`FileSystemWatcher.swift:32-47`); lost event history or more than
100k changes triggers a rebuild (`docs/features/file-search.md:113-134`). Spotlight
is not used.

**Matching.** File names only, not full paths or contents. Every typed word must
appear as a substring, in any order. Ranking adds bonuses for an exact name, a
prefix, a word or camel-case boundary, and words in typed order, weights by location
(home and cloud drives highest; hidden paths, `~/Library` and bundle contents
lowest), and subtracts for name length (`FileSearchQuery.swift:4-11,68-110`). An
empty query lists the 20 most recently modified files. Matching is not fuzzy, so
abbreviations do not match.

**Claimed speed.** 844,911 entries crawled in 5.2 s with a 103 MB helper peak and a
16.6 MB index; queries take 0.3 to 2.7 ms (`docs/features/file-search.md:108-111`).
These are the maintainer's numbers, not measured here.

**Scope and exclusions.** The default scope is `~` (`FileSearchScope.swift:6`).
Ignore patterns are names or `fnmatch` globs, with defaults for `node_modules`,
`.git`, `build`, `DerivedData`, `.venv` and noisy parts of `~/Library`
(`FileSearchIgnoreList.swift:7-12`). Hidden files are indexed but rank last. The
feature is off by default and needs Full Disk Access; #1652 (open) asks to require
it only for scopes that need it.

**Entry points.** The Search Files command, its own global shortcut, a "Search
Files" fallback row that carries the typed query, or an optional Files section in
root search showing the top five hits after three characters
(`docs/features/file-search.md:266-272`).

**Actions.** Open, Show in Finder (⌘↵), Share, Copy File, Copy Name, Copy Path, Paste
File to the front app, Move to Trash (⌃X), drag out, a preview pane and a ⌘P type
filter (`docs/features/file-search.md:233-242`). Main has no Quick Look action;
stable had ⌘Y.

**Extensions.** Tinycast runs Raycast extensions without Node
(`docs/features/extensions.md:1-4`). The third-party
[DigUp Launcher](https://github.com/Whiteknight07/digup-launcher) extension adds
Spotlight filename search and local semantic content search; it reports testing on
0.11.19.

## Comparison

| | Tinycast (main, beta) | Alfred | Raycast v2 |
| --- | --- | --- | --- |
| Index | Own filename index in a helper process | Spotlight metadata | Own index; Spotlight only for content search |
| Freshness | FSEvents, about 1 s | Spotlight's | Own watcher |
| Mode switch | Dedicated hotkey, fallback row, or inline Files section; no prefix | Leading space, or `open`, `find`, `in` keywords | Inline results or the Search Files command |
| Matching | All words as name substrings, location-weighted; not fuzzy | Spotlight name matching, wildcards | Own ranking, file names by default |
| Content search | No (DigUp extension) | `in` keyword | Optional |
| Browsing | No | `/` and `~` browse, File Buffer for multiple files | Typing a path browses |
| Scope control | Scope list plus glob ignores; Full Disk Access | Spotlight scope, privacy list, Alfred search scope, File Filters | Scopes, globs, `.gitignore`/`.ignore`/`.rayignore` |

Alfred's file search depends on the same metadata as Spotlight, so Spotlight's
categories and privacy list decide what it can find
([indexing help](https://www.alfredapp.com/help/troubleshooting/indexing/),
[file search help](https://www.alfredapp.com/help/features/file-search/)). Its
documented quick prefix is a leading space; the apostrophe trigger Prateek remembers
does not appear in Alfred's help, so it was probably a custom keyword. Raycast v2
builds its own index of `~` and `/Applications`, and its manual has a troubleshooting
section for results that feel worse than v1
([manual](https://manual.raycast.com/file-search)).

## Getting Alfred's prefix back

Tinycast will not add a prefix mode. The maintainer closed #1070 (space in an empty
box opens file search) and #1125 (Raycast's Tab-into-folder) as not planned. The
nearest equivalents:

1. Bind the Search Files global shortcut. This is the closest to Alfred's single
   gesture, though it is a chord rather than a typed prefix.
2. Enable Files in root search, which shows five hits after three characters.
3. Type the query, then pick the Search Files fallback row.
4. Give the Search Files command an alias such as `'`. Whether text typed after the
   alias carries into the search is unverified.

Alfred features with no Tinycast equivalent: content search, `/` and `~` browsing,
the File Buffer, and abbreviation matching. Content search could come from the DigUp
extension.

**Maturity.** About 8,700 stars, created 2026-06, betas every one or two days and
roughly weekly stables. The file index is a week old; #1599 (sustained background
CPU) was fixed on 2026-10-15. The maintainer declines many feature requests.

## Snippets, clipboard, config and telemetry

These matter for moving snippets and clipboard history out of Raycast.

- **Snippets** are one Markdown file each, with optional frontmatter (`name`,
  `keyword`, `enabled`, `show_confirmation`), in
  `~/Library/Application Support/<bundle id>/Snippets/`. The folder can be moved or
  symlinked (`docs/features/snippets.md:33-37,82-100`). Placeholders use Raycast's
  syntax. chezmoi could own this folder.
- **Clipboard history** is SQLite with a trigram full-text index in
  `clipboard.sqlite3`, plus PNGs for images (`docs/features/clipboard.md:98-103`).
- **Import and export** use a `.tinycast` archive (settings JSON, clipboard JSONL,
  snippets, notes; `docs/features/backup.md:63-71`). Tinycast also imports Raycast
  v2's encrypted `.rayconfig` export, including snippets and clipboard
  (`docs/features/raycast-import.md:3`). That is the migration path out of Raycast.
- **Config** can live in `~/.config/tinycast/settings.json`, off by default and
  applied live on edit, including the `fileSearch.*` keys
  (`SettingsFileKey.swift:66-71`). It never holds content, and capability switches
  such as Snippets or Extensions can only be enabled in the app
  (`docs/features/settings-file.md:1-30`).
- **Telemetry:** none claimed ("no telemetry", `README.md:22`) and no analytics SDK
  found. The only outbound call found is a daily GitHub Releases update check,
  disabled with `general.automaticallyCheckForUpdates` or in Settings → General
  (`docs/features/updates.md:3,53-56`).

## Open questions

- Does Tinycast's substring ranking feel as good as Alfred's in daily use? Only a
  hands-on trial on a beta answers this.
- Does an alias on Search Files pass the trailing query through?
- Is the beta file index stable enough to adopt before it reaches a stable release?
