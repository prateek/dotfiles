---
status: active
doc_type: plan
created: 2026-09-26
updated: 2026-09-26
status_detail: "Source fixes and focused validation complete; activation and attended hotkey verification remain."
---

# Orca shortcut repair

Make the existing Orca session shortcuts resolve the focused agent correctly
across Claude, Codex, pi, and OMP. Audit the other repo-defined Orca controls
for assumptions specific to Claude.

## Work

- [x] Reproduce the OMP fork rejection and inspect the running Orca metadata.
- [x] Use the focused pane's provider session binding; refuse ambiguous matches.
- [x] Remove the global 100-session cutoff and exclude remote copies from local lookup.
- [x] Preserve Codex's session home and use OMP's native `--fork` command.
- [x] Guard the Claude queue shortcut before it types into another agent.
- [x] Populate the worktree form from Orca's installed-agent detection.
- [x] Run regression tests, native pi/OMP fork checks, and scoped chezmoi previews.
- [ ] Activate the scripts and rebuilt Raycast extension after landing.
- [ ] Verify the assigned hotkeys in Raycast and exercise them in each agent's pane.

## Audited controls

| Control | Finding and repair |
| --- | --- |
| Alt-F, Fork Orca Agent Session | OMP was unsupported; Codex lost `codexHome`. Both now use native fork commands with the explicit source. |
| Alt-A, Reveal Orca Agent Session | Shared lookup could miss older sessions or select another pane's newer session. The same identity repair covers reveal and fork. |
| Tuna tap-Shift, A, Q | Labeled Claude-only, but previously typed `/q` into any Orca agent. Now requires a positively identified Claude pane. Ghostty behavior remains the existing attended Claude workflow. |
| Create Orca Worktree in Raycast | Help examples yielded only Claude, Codex, and Gemini. The picker now reads `preflight.detectAgents` through the shared helper. |
| Tuna tap-Shift, T | Opens Orca; no agent-specific behavior. |
| 8BitDo bumpers in Orca | Send Command-Shift-Up/Down for worktree navigation; no agent-specific behavior. |
| Orca custom keybindings | The managed and live files contain no overrides; native defaults own these controls. |

Alt-F and Alt-A are the bindings documented by the scripts. Raycast's encrypted
settings store could not be inspected through the available Orca desktop API,
so the assigned keys themselves were not verified. No existing conversation
received input during this audit.

## Evidence and limits

The [session tests](../../tests/python/agents/test_orca_shortcuts.py),
[queue tests](../../tests/bats/agents/claude-queue-draft.bats), and
[worktree tests](../../home/dot_local/share/raycast-extensions/orca-worktree/tests/orca.test.mjs)
cover the repaired behavior. The prior help-parser assertion was replaced by
structured catalog examples, including pi/OMP and malformed-response rejection.

Installed pi 0.85.1 and OMP 18.2.6 both forked disposable JSONL transcripts
through their native CLIs: new IDs, preserved history, unchanged source files.
Only RPC state queries were sent; no model prompts ran. OMP's installed help
omits `--fork`; its [18.2.6 parser](https://github.com/can1357/oh-my-pi/blob/v18.2.6/packages/coding-agent/src/cli/flag-tables.ts)
and the native check establish support.

Live Codex and OMP workspaces produced fork plans. These checks do not establish
an end-to-end keyboard-triggered fork or AgentsView navigation. The shared
helper still depends on private Orca RPCs. See the
[test index](../../tests/README.md) and
[Raycast extension guide](../../home/dot_local/share/raycast-extensions/orca-worktree/README.md)
for validation and build commands.
