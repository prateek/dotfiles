---
status: active
doc_type: plan
created: 2026-09-26
updated: 2026-10-07
status_detail: "Remote-session source repair and container validation complete; activation remains separate."
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
- [x] Reproduce remote panes being rejected by the local-only vault lookup.
- [x] Resolve remote conversations from their focused provider binding and report execution host.
- [x] Preserve remote Codex account homes and refuse unknown account or transcript locators.
- [x] Reproduce retained SSH terminal connectivity outliving an explicit disconnect; check host state before agent probes.
- [x] Honor Orca's runtime-path override and Linux CLI name.
- [x] Run packaged Orca, generated-agent SSH forks, a real Claude CLI against a fake API, and paired-server scenarios in disposable containers.
- [x] Route selected paired servers through Orca's packaged runtime client and refuse an unavailable server.
- [ ] Activate the scripts and rebuilt Raycast extension after landing.
- [ ] Verify the assigned hotkeys in Raycast and exercise them in each agent's pane.

## Audited controls

| Control | Finding and repair |
| --- | --- |
| Alt-F, Fork Orca Agent Session | OMP was unsupported; Codex lost `codexHome`. Both now use native fork commands with the explicit source. |
| Alt-A, Reveal Orca Agent Session | Shared lookup could miss older sessions or select another pane's newer session. The same identity repair covers reveal and fork. |
| `~/bin/claude-queue-draft` (formerly the Tuna A, Q bind) | Labeled Claude-only, but previously typed `/q` into any Orca agent. Now requires a positively identified Claude pane. Ghostty behavior remains the existing attended Claude workflow. |
| Create Orca Worktree in Raycast | Help examples yielded only Claude, Codex, and Gemini. The picker now reads `preflight.detectAgents` through the shared helper. |
| Tuna ⌘-tap, A, T | Opens Orca; no agent-specific behavior. |
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

## Remote-session repair

The original helper used the desktop runtime's `aiVault.listSessions`, which
scans that runtime's own filesystem. A remote pane's hook binding could identify
the right conversation, but the helper then rejected it because the transcript
was absent from the local vault. Removing the local-host filter alone would not
route the scan to another machine.

The repair reads host identity from `terminal.show`. Local panes keep the vault
lookup and ambiguity checks. SSH and paired-server panes use the authoritative
`providerSession` in the focused tab; an absent binding is an error. Codex's
remote account home comes from its bound rollout path. Pi and OMP forks require
their transcript path. The split uses the original terminal handle, so Orca owns
the execution route.

The container scenario exposed another failure: an explicitly disconnected SSH
target could still have a retained terminal marked connected. Process probes
could reconnect it before the fork. The helper now checks `ssh.getState` before
those probes and refuses unavailable hosts.

Paired servers require a separate connection from the desktop's own runtime.
The helper reads the active profile's server preference from SQLite in read-only
mode, then routes CLI calls and private RPCs to that server. The adjacent
`orca-agent-rpc.cjs` adapter uses Orca's packaged runtime client, including its
pairing authentication and encryption. Both helper files must be activated
together. Inherited CLI routing variables cannot override the desktop selection.

See the [integration runbook](../runbooks/orca-shortcut-validation.md) for the
repeatable lane and what generated agents establish separately from native
agent/API validation. This work repairs session resolution; the response editor
discussed on 2026-10-07 remains future work.
