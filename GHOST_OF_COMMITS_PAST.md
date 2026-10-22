# Ghost of Commits Past

Things a past agent landed or assumed that someone still has to verify. Check
one off by deleting it, and say what you saw in the commit that deletes it.

## 2026-10-20: Thaw layout, groups, triggers and grid (home/.chezmoitemplates/com.stonerl.Thaw.plist.tmpl)

- On a personal Mac on macOS 27 with Thaw 3.0 beta: the seeded `MenuBarItemGroups` (version 1) still loads and "Show as a Folder" works; if 3.0 writes version 2, gate folder fields per OS rather than in the shared fragment.
- On a fresh Mac after `chezmoi apply` and Thaw's first launch: both spacers land in hidden, and with all its apps running the Thaw Bar grid shows Often as row one.
- In a Tart VM, postflight passes `thaw_concealed_order`.

Skills: `chezmoi-management`, `peekaboo-vm-app-audit`.

## 2026-10-22: Orca shortcut focus capture and layouts lane (docs/plans/orca-shortcuts-plan.md)

- After `chezmoi apply` on the work Mac, with an Orca pane running native Claude focused, run `~/bin/orca-agent-session --json --agent-only` five times; each prints `{"agent": "claude"}`.
- In a tab of three agent splits, press ⌥F, then click another tab within a second; the fork split opens beside the original pane.
- From another app, Tuna ⌘-tap O f; Orca comes forward and forks the last-focused Orca pane.

Skills: `chezmoi-management`, `utils-agent:orca-cli`.

## 2026-10-22: lore skill (agent-marketplace/src/core/skills/lore/SKILL.md)

- On a machine with Codex, after apply, `codex` lists `core:lore`.
- Run an `agptx` adversarial review of the lore skill through `utils-agent:acpx`; findings fixed or answered.
- In a real repo, `/lore --depth quick <why question>` returns a tiered answer with a sources-checked line; a full run spawns investigators plus a synthesizer.

Skills: `agent-skill-management`, `utils-agent:acpx`, `skill-creator`.

## 2026-10-22: perf-views skill (agent-marketplace/src/utils-agent/skills/perf-views/)

- After apply, in Claude and Codex, `/perf-views` runs, and the skill is absent from the model's skill listing.
- From a sample span file, write all three exports; the trace opens in ui.perfetto.dev, the speedscope file in speedscope.app, and `inferno-flamegraph --countname ns` draws the folded file.
- Run the benchmark-zsh-startup Perfetto recipe through `open-perfetto`; the timeline shows `.zshrc` spans.

Skills: `utils-agent:perf-views`, `agent-skill-management`, `benchmark-zsh-startup`.
