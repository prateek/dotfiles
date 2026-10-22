# Ghost of Commits Past

Things a past agent landed or assumed that someone still has to verify. Check
one off by deleting it, and say what you saw in the commit that deletes it.

## 2026-10-20: marketplace layout (docs/plans/agent-marketplace-layout-plan.md)

- On a personal machine: `mise run test-tools`, `just test-python -p 'test_console_*.py'`, `just test-shell tests/bats/agents`; green.
- With `CODEX_HOME=$(mktemp -d)`: `codex plugin marketplace add raintree-technology/apple-hig-skills`, then `codex plugin add apple-hig-skills@apple-hig-skills`; the plugin lists its skills, and `.agents/skills/agent-skill-management/scripts/reconcile-upstream-agent-plugins --apply --agent codex` leaves it disabled.

Skills: `agent-skill-management`.

## 2026-10-20: ask skill replaced by src (docs/plans/src-skill-plan.md)

- On a personal machine, reconcile utils-agent for Codex; `codex` lists `utils-agent:src`, not `ask`.
- On the Linux devbox, `just -f agent-marketplace/justfile -d agent-marketplace test`; `test_src_fresh` passes, exercising GNU `stat`/`date`.

Skills: `agent-skill-management`.

## 2026-10-20: Cursor gets local skills via ~/.cursor/skills (docs/plans/src-skill-plan.md)

- In Cursor's editor, open the skills list; each prateek-local skill (for example `src`) appears once.
- On the devbox, after `chezmoi apply`, `ls ~/.cursor/skills`; it holds links into `~/.agents/plugins/plugins/`.

Skills: `agent-skill-management`.

## 2026-10-20: Thaw layout, groups, triggers and grid (home/.chezmoitemplates/com.stonerl.Thaw.plist.tmpl)

- On a personal Mac on macOS 27 with Thaw 3.0 beta: the seeded `MenuBarItemGroups` (version 1) still loads and "Show as a Folder" works; if 3.0 writes version 2, gate folder fields per OS rather than in the shared fragment.
- On a fresh Mac after `chezmoi apply` and Thaw's first launch: both spacers land in hidden, and with all its apps running the Thaw Bar grid shows Often as row one.
- In a Tart VM, postflight passes `thaw_concealed_order`.

Skills: `chezmoi-management`, `peekaboo-vm-app-audit`.

## 2026-10-20: acpx pi viewer replaces the tmux view (docs/adr/0061-acpx-pi-viewer.md)

- After apply, from an Orca agent terminal, `~/.agents/plugins/plugins/utils-agent/skills/acpx/scripts/acpx-pane --view`; a pi viewer split opens.
- Delegate once through a Claude route (`aopus`/`afable`) via acpx-pane; the viewer header shows a dollar cost.
- From Orca Mobile on a phone, tap a run in the viewer list; its detail opens.
- On a personal machine, repeat the first item.

Skills: `utils-agent:acpx`, `utils-agent:orca-cli`.

## 2026-10-21: workflow viewer (docs/adr/0062-claude-workflow-viewer.md)

- After apply, while a Claude Code workflow runs, open `~/.agents/plugins/plugins/utils-agent/skills/workflow-viewer/scripts/workflow-viewer` in an Orca terminal; it opens on that run and agents move from ● to ✓ as they finish.
- In that viewer, move the mouse over list rows; they highlight (hover was only tested under tmux, which drops motion events).
- On a personal machine, `workflow-viewer --once`; it prints JSON for the latest run.

Skills: `utils-agent:workflow-viewer`.

## 2026-10-22: Orca shortcut focus capture and layouts lane (docs/plans/orca-shortcuts-plan.md)

- After `chezmoi apply` on the work Mac, with an Orca pane running native Claude focused, run `~/bin/orca-agent-session --json --agent-only` five times; each prints `{"agent": "claude"}`.
- In a tab of three agent splits, press ⌥F, then click another tab within a second; the fork split opens beside the original pane.
- From another app, Tuna ⌘-tap O f; Orca comes forward and forks the last-focused Orca pane.

Skills: `chezmoi-management`, `utils-agent:orca-cli`.
