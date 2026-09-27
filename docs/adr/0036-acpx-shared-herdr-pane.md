---
status: accepted
doc_type: adr
owner: Prateek
created: 2026-09-27
updated: 2026-09-27
related:
  - ../plans/acpx-shared-pane-plan.md
current_guidance: ../../agent-marketplace/packages/utils-agent/skills/acpx/SKILL.md
---

# ADR 0036: Share one Herdr view for ACPX runs

Use a named Herdr session inside one Orca split per calling terminal. Put each
ACPX invocation in a tab and keep the caller's `acpx-pane` command unchanged.
The helper owns view creation, tab selection, log capture, exit status, and
per-run cancellation. A separate `--view` command switches back to that pane.

The [plan](../plans/acpx-shared-pane-plan.md) records the implementation and
verification boundary. Herdr provides an in-terminal tab strip and a CLI for
creating tabs; its built-in status command supports the count. No Herdr plugins
or agent integrations are required. The dedicated config keeps the sidebar and
other decoration hidden. This avoids opening a new Orca pane for every run
while preserving an independent process and log for each invocation.

The named session survives a client detach. Completed tabs remain until the
user closes them. The pane shell execs a logging runner that waits quietly
after recording ACPX's exit status; directly execing ACPX would close the
Herdr tab on exit. A terminated helper closes only its own tab. When Herdr or
Orca is unavailable, a launch runs inline and still writes the requested log.
The close key exits a completed runner; when no other ACPX tab exists, the
runner closes its Orca view. A stopped Herdr session is discarded on the next
launch because its completed runners cannot be restored as live processes.
