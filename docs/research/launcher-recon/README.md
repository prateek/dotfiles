---
status: draft
doc_type: research
summary: "Entry point for the launcher recon corpus: how Prateek has used Alfred, Raycast, Leader Key, Tuna, and the hotkey layer beneath them, reconstructed from git history."
created: 2026-10-19
updated: 2026-10-19
related:
  - alfred.md
  - raycast.md
  - leader-key-and-tuna.md
  - trigger-layer.md
  - tinycast-file-search.md
  - tinycast-migration.md
  - ../../plans/raycast-config-automation-plan.md
status_detail: "Git-history recon with read-only live checks on the work Mac. No consumer plan yet; no usage-frequency data."
---

# Launcher recon

This corpus records how Prateek has used keyboard launchers on the Mac from 2016 to
2026: what he invoked, what he configured, what he built on top, and what survived
each switch of tool. It covers four maps:

| Map | Covers |
| --- | --- |
| [Alfred and Spotlight](alfred.md) | Alfred 2016 to 2026, its workflows, snippets, web searches and clipboard history; Spotlight cut down to an indexer |
| [Raycast](raycast.md) | Raycast since 2025-09, the repo's script commands, the `orca-worktree` extension, pinned prefs, and the encrypted-store boundary |
| [Leader Key and Tuna](leader-key-and-tuna.md) | The leader-sequence launchers, the full binding tree before and after the migration, and the Prolo Ring cheat sheet |
| [Hotkey and trigger layer](trigger-layer.md) | Karabiner and Goku, Kanata, Hammerspoon, BetterTouchTool, and which key summoned which launcher over time |
| [Tinycast file search](tinycast-file-search.md) | How Tinycast indexes files versus Alfred and Raycast, and its snippet, clipboard and config model |
| [Migrating to Tinycast](tinycast-migration.md) | Self-contained summary of the Tinycast move: what must be replaced, config and sync, risks, and a research handoff |

Each map has a feature matrix in [`data/`](data/):
`features-alfred.csv`, `features-raycast.csv`, `features-leader-key-and-tuna.csv`
and `features-trigger-layer.csv`. The columns are
`feature,area,priority,app,our_status,evidence,notes`. `priority` records how
attached Prateek has been to a feature (`must`, `should`, `could`, `skip`), not how
the vendor ranks it.

## Method

The maps adapt the `replica-recon` skill from
[Jakeschincariol/replica-skill](https://github.com/Jakeschincariol/replica-skill)
at `77c9436`. That skill maps an app into screens, flows, components, a data model
and a feature matrix so it can be cloned. Here the subject is our usage rather
than the vendor's product, so:

- screens became **surfaces**: hotkeys, keywords, groups, script commands and
  extensions;
- flows are **invocations** we actually configured, with their keystroke counts;
- a **customizations** section records what we built or pinned;
- **what carried forward** treats a feature that was rebuilt in the next tool as the
  strongest evidence of preference.

Evidence is this repo's git history across all refs. Session transcripts and
agentsview were deliberately not used. Two Raycast claims (the `prv` replacement
and the Raycast 2 Cloud Sync clobber) come from agent memory notes and are marked
as such. Each claim carries a label: COMMITTED (seen in a past commit), CURRENT (at
HEAD `a134f6e2`), LIVE (a read-only check on the work Mac on 2026-10-19; the
personal Mac was not checked), or INFERRED. Git records configuration, not use, so
nothing here measures how often a binding is pressed.

The audit also corrected the symbolic-hotkey labels in
`home/.chezmoitemplates/macos-defaults.sh.tmpl`, which the maps mention. That fix
ships in the same change as this corpus.

## The stack today

```text
physical key
  ├─ ⌘Space ───────────────────────────► Raycast root search (Tuna's activate hotkey too; owner unrecorded)
  ├─ left ⌘ tap (200 ms) ─ Karabiner ─ F18 ─► Tuna combo mode ─► a / o / w / z groups
  ├─ double left ⌥ ────────────────────► Tuna fuzzy mode (left ⌥ is also Hyper on hold; untested together)
  └─ Caps, left ⌥, left ⌃, ⌃Space ─ Karabiner ─► Esc/Ctrl, Hyper, Meh/F19, nav layer
                                                     │
launcher actions ──────────────────────────────────► repo-owned scripts and CLIs
  (temp-admin, g95nc, orca-agent-session, winmux, orca-zen-mode, op read, ghostpepper://)
```

Karabiner, configured through Goku, has been the only remapper since 2026-10-05.
Tuna holds 26 leader binds in four groups (25 distinct actions; `o o` and `a t`
both open Orca). Raycast hosts four repo-managed script
commands and one custom extension, and Tuna reaches the extension through a
`raycast://` deeplink. Alfred was dropped on 2026-10-19.

## What Prateek is partial to

These patterns hold across tools. The per-map "carried forward" sections hold the
evidence.

1. **⌘Space opens a fuzzy launcher.** Alfred held it on all eight machines in its
   sync folder. On the work Mac Raycast's live hotkey is ⌘Space, though Tuna's
   committed config claims it too ([conflicts](#conflicts-and-losses)). The repo disables Spotlight's hotkey so a
   third-party launcher can take it.
2. **A bare modifier tap opens a leader, then one-letter groups.** This started on
   2026-07-04. The modifier changed twice (either ⌘, then either ⇧, then left ⌘),
   but the F18 bridge and the one-letter tree stayed. Keys favour the left hand, and
   mnemonics win when they conflict (`z m` for m4mini, `w h`/`w l` as vim
   directions).
3. **Logic lives in repo-owned scripts; launchers are thin triggers.** Alfred never
   had a workflow Prateek wrote. Every Raycast script command is also a plain CLI,
   which let Leader Key and then Tuna bind the same paths unchanged. Tuna's Orca
   group now calls the helper directly.
4. **Config is code, generated or reloaded on apply.** Goku compiles EDN to
   Karabiner JSON, Tuna reloads its TOML through `tuna config reload`, and
   Hammerspoon compiled Fennel. Opaque stores were refused: Alfred's prefs left the
   repo because the sync folder could not be redacted, and Raycast's encrypted store
   stays unmanaged.
5. **Caps Lock is Esc on tap and Ctrl on hold.** It is the most stable binding in
   the repo and survived Karabiner, Kanata, Karabiner again, Goku, and the NocFree
   firmware.
6. **Cheat sheets appear only on hesitation.** Leader Key used its `cheater` theme,
   Tuna waits 1000 ms, and the nav layer and Prolo Ring use the same overlay pattern.
7. **Snippets and clipboard history were used heavily in Alfred.** The LLM prompt
   collection (prefix `,`) was still growing in January 2026. Git shows no successor.

## Conflicts and losses

- **⌘Space has two owners.** Raycast's live hotkey and Tuna's committed
  `hotkeys.app.activate` are both ⌘Space, and nothing records which wins.
- **Snippets and clipboard history live in Raycast's encrypted store** (confirmed by
  Prateek on 2026-10-19), outside the repo.
- **The work Mac runs Tuna 0.78 with the pre-0.104 config**, including the retired
  `a q` bind. The source targets 0.104, which drops old-schema binds on upgrade.
  `chezmoi status` shows the file `MM`, so the next full apply would write the
  0.104 config and reload it into 0.78, with untested results.
- **Raycast's global hotkey, store extensions, aliases and quicklinks are not in
  git.** The ⌥A and ⌥F script hotkeys have never been verified.
- **Hyper drives nothing; Meh drives one WinMux chord** (`ctrl-alt-shift-c`). The
  Hammerspoon repo and file picker (⌃⌥⌘U, ⌃⌥⌘T) was never replaced.
- **BetterTouchTool is running with zero triggers.** None were ever in git, and the
  120 in its August store are gone from the current one.

## Decisions (2026-10-19)

Prateek's answers to the first pass, and what followed:

1. **⌘Space:** neither Raycast nor Tuna. Prateek is considering a move to Tinycast;
   see [Migrating to Tinycast](tinycast-migration.md).
2. **Snippets and clipboard history:** move them out of Raycast. Tinycast stores
   snippets as one Markdown file each, which chezmoi can manage. Not yet planned.
3. **Alfred:** dropped. The cask, license template and refs, and capture entries
   were removed in the same change as this update.
4. **Leader apps:** Chrome (`a g`), Obsidian (`a w`) and Ghostty (`a e`) were added
   back inside the `a` group.
5. **Hyper and Meh:** answered from the repo and BTT store; see the
   [trigger-layer gaps](trigger-layer.md#gaps-and-open-questions).

Day to day, Prateek uses Raycast and Tuna.
