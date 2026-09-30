---
status: accepted
doc_type: adr
owner: Prateek
created: 2026-09-30
updated: 2026-09-30
related:
  - 0040-devbox-machine-type.md
  - 0041-agent-clis-single-declaration.md
  - ../plans/linux-devbox-plan.md
---

# ADR 0043 — Gate the devbox by OS, not by an allowlist

## Decision

Retire the `managed_allowlist` feature from [ADR 0040](0040-devbox-machine-type.md).
The devbox takes the whole source state, like any other machine type. Three
gates keep off it what does not belong:

- `.chezmoiignore` ignores macOS-only targets off macOS: `Library`, the GUI
  app config under `.config/` (borders, kanata, karabiner, raycast, tuna), the
  Mac-only helpers in `bin` and `.local/bin`, `~/.zshrc`, and the macOS apply
  scripts by target name. Those scripts also exit off Darwin at run time; the
  ignore keeps a Linux apply from listing them.
- `.chezmoiremove` renders only on macOS. Its orphans were only ever deployed
  there, and chezmoi applies removals even to ignored targets.
- A new `agent_assets_synced` feature, on for the devbox, ignores targets
  under the harness asset directories another tool replaces wholesale. Today
  that is `~/.claude/commands`.

## Rationale

The allowlist made every devbox path an explicit choice, but it also kept the
agent surface off the box. `~/.agents` docs, the built plugins (script 36), the
skill-root maintenance (script 35), and the Claude settings merge were all
ignored, so the devbox ran without Prateek's skills and plugins. Each fix meant
growing an allowlist that mirrored most of the source tree.

The collisions that justified the allowlist turned out to be few:

- Bootstrap-owned files the dotfiles also write (`~/.gitconfig`, `~/.bashrc`,
  `~/.tmux.conf`) were already handled: git renders to the XDG path, and the
  others are not dotfiles targets.
- `~/.claude/settings.json`, `~/.ssh/config`, the Cursor, pi and agentsview
  configs are `modify_` merges that keep keys they do not own.
- The asset sync owns `~/.claude/{skills,commands,rules,agents}`. Only
  `~/.claude/commands/q.md` lands inside one of those; script 35 removes
  `~/.claude/skills` only when it carries the dotfiles' own
  `README.generated.md` marker, so it leaves the synced copy alone.
- `~/.zshrc` exists on Macs only for history; elsewhere another owner writes
  it.

With those gated, a denylist of macOS targets is smaller than the allowlist and
fails in a visible direction: a new macOS target that reaches Linux shows up in
the devbox render and its test, where a missing allowlist entry silently kept a
wanted file away.

## Consequences

- A new macOS-only target or script needs a line in the non-darwin block of
  `.chezmoiignore`, unless it already skips itself off Darwin and renders
  nothing harmful. The devbox render test in `tests/python/config/test_chezmoi.py`
  pins the known cases.
- The Mac renders do not change. Scripts that hash `machines.toml` as a
  change trigger rerun once after this change, as after any edit to that file.
- The devbox runs scripts 35 and 36, so an apply builds the agent marketplace
  and installs the enabled Claude plugins. It needs `just` and `omp` on the
  login PATH (Homebrew and mise provide them).
- The desired `statusLine` in `~/.claude/settings.json` replaces whatever the
  bootstrap or Orca set, as it already does on the Macs.
