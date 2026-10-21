---
status: accepted
doc_type: adr
summary: "acpx-pane runs acpx in the caller's process and opens one pi viewer per Orca worktree that attaches to that worktree's acpx sessions; tmux leaves the delegation path."
owner: Prateek
created: 2026-10-20
updated: 2026-10-20
related:
  - 0058-acpx-shared-tmux-view.md
  - 0036-acpx-shared-herdr-pane.md
current_guidance: ../../agent-marketplace/src/utils-agent/skills/acpx/references/harness-lanes.md
---

# ADR 0061: Watch ACPX runs in a pi viewer

`acpx-pane` runs acpx in the caller's own process, writing the log and returning
acpx's exit status, and keeps one viewer open per Orca worktree. The viewer is a
pi extension (`viewer/acpx-viewer.ts` in the acpx skill) that attaches to every
open acpx session under that worktree with `acpx sessions watch`. It shows a
roster of runs and the selected run's transcript as dense rows that expand on
click or Enter. It never prompts a session; cancelling a run is its only
write. Each run's first prompt goes to a configurable summary command, by
default `claude -p` with Haiku, to label the run in the roster. Without Orca or
pi, `acpx-pane` runs acpx inline and opens nothing.

The tmux view of [ADR 0058](0058-acpx-shared-tmux-view.md) showed acpx's text
log, one tab per prompt. That kept runs visible, but the log is a wall of
text: a long delegation scrolled past before anyone could read it, and the tabs
said nothing about which run was which. Running acpx inside tmux also meant the
helper had to carry exit files, runner scripts, and window bookkeeping to hand
the status back to the caller. Parents still read acpx's `--format text` log;
the viewer is for Prateek to watch and steer.

pi hosts the viewer because its native transcript cannot be made dense (it has
no vertical-spacing setting) and the available compactors trade away
click-to-expand. The extension draws everything itself with pi-tui inside one
full-screen overlay, so pi supplies the terminal, mouse input, theme, and
packaging. A dedicated agent directory with no packages starts it in about 0.35
seconds. Orca-driven agents would make the helper unnecessary, but that depends
on agent hooks, which the work laptop's managed policy disables, and Orca lacks
exit status, receipts, permission policy, named follow-ups, timeouts, and the
shortcut routes.

The viewer sits in the worktree because runs belong to the code they work on:
one split per worktree replaces one split per calling terminal, and its roster
lists that worktree's open sessions until they close. The extension ships in
the acpx skill and loads only through `acpx-pane`'s `pi -ne -e` launch; a pi
package entry would load it into every pi session.
