---
status: accepted
doc_type: adr
summary: "ACPX runs share one tmux session on a private socket inside a single Orca split per calling terminal, one window per invocation, replacing Herdr."
owner: Prateek
created: 2026-10-20
updated: 2026-10-20
related:
  - 0036-acpx-shared-herdr-pane.md
current_guidance: ../../agent-marketplace/src/utils-agent/skills/acpx/references/harness-lanes.md
---

# ADR 0058: Share one tmux view for ACPX runs

Host the shared ACPX view in tmux instead of Herdr. Everything else
[ADR 0036](0036-acpx-shared-herdr-pane.md) decided stays: one Orca split per
calling terminal, one tab per invocation labelled by order, time, and shortcut,
completed tabs that wait for a close key, the unchanged `acpx-pane` interface,
and the helper's ownership of logs, exit status, and per-run cancellation.
Herdr leaves every machine through the retired-package list.

Herdr stopped being usable on the work Mac. Information Security announced a
Cortex XDR block on 2026-09-24, effective 2026-09-29. Its BIOC rule
`process_start_1046` ("SOC - AI Apps BTP Mac - Herdr") matches Herdr's process
start and terminates its whole causality group, which is rooted at Orca's
terminal host, so one `acpx-pane` launch closed every open Orca terminal. The
local agent's `trapsd.log` recorded the matches on 2026-10-20. Keeping Herdr on
personal machines would have left the helper with two view backends and work
runs with no view at all. Going back to one plain Orca split per run would
bring back the clutter ADR 0036 removed. tmux is already in the core package
group on every machine, and its windows, status line, and attach-or-create
session cover what the view used from Herdr. The tmux view ran on the work Mac
under XDR on 2026-10-20, and every Orca terminal survived.

Each calling terminal gets its own tmux server on a socket in the helper's
state directory, so the view never touches a tmux server of the user's own and
can open from inside one. Windows are tabs; the status line shows the tab
strip and the run count. Unlike Herdr, tmux keeps no state after its server
exits, so there is no stopped session to discard. A view whose Orca pane
closed reattaches to the live session, and runs still in progress keep their
windows. The helper runs inline whenever tmux, Orca, or Python 3 is missing or
the view fails to open. That fallback does not survive a block like Herdr's:
a rule that terminates tmux's causality group kills the Orca terminals before
the helper can react. If tmux is blocked, remove it from that machine so the
helper takes the inline path.
