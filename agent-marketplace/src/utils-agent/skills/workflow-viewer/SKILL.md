---
name: workflow-viewer
description: Watch a Claude Code Workflow run (the Workflow tool's background orchestration) live in a terminal, or read one run as JSON. Use when asked to view, watch, monitor, or inspect a running or finished workflow, its phases, agents, transcripts, failures, or stalls, or to open the workflow viewer.
---

# Workflow viewer

`scripts/workflow-viewer` opens a full-screen pi view of one Claude Code Workflow
run: its agents grouped by phase on the left, the selected agent's transcript on
the right. It only reads files under `~/.claude/projects`; it never writes to a
run or a session.

## Open it for the user

Run the launcher in a terminal the user can see. Inside Orca, split the caller's
pane so the user's focus stays put:

```sh
orca terminal split --terminal "$ORCA_TERMINAL_HANDLE" --direction horizontal \
  --command "$HOME/.agents/plugins/plugins/utils-agent/skills/workflow-viewer/scripts/workflow-viewer"
```

With no argument it opens the most recently active run. Pass a run id or a
substring of the workflow's name to pick one (`workflow-viewer wf_0524a5a8`);
`r` inside the viewer lists every run. `--replay <speed>` plays a finished run
back as if live. `--mode tree|table|timeline` picks the starting list.

Tell the user `?` lists the keys and mouse gestures. Without pi the launcher
exits with an error; `--once` still works.

## Read a run yourself

```sh
scripts/workflow-viewer --once [run-id-or-name]
```

prints one JSON snapshot: run status and duration, then each phase's agents with
`state`, `durationMs`, `tools`, `failedTools`, `ctx`, the tool call running
`now`, and the `result` or error. States are `running`, `starting`, `stalled`
(no activity for 3 minutes and no open tool call), `done`, `cached`, `failed`,
and `abandoned` (the run finished without that agent's result, as after a
resume or retry).

## Where things live

- `viewer/workflow-model.ts`: the data model (journal, transcripts, completion
  record, agent states). No pi imports; `tests/node/workflow-model.test.mjs` in
  the dotfiles repo covers it.
- `viewer/workflow-viewer.ts`: the pi extension. It loads only through the
  launcher's `pi -ne -e`.
- `viewer/workflow-snapshot.ts`: the `--once` printer.
- Viewer preferences (list mode, widths, density) persist under
  `${XDG_STATE_HOME:-~/.local/state}/workflow-viewer/`.
