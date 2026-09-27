---
status: accepted
doc_type: plan
owner: Prateek
created: 2026-09-27
updated: 2026-09-27
related:
  - ../adr/0036-acpx-shared-herdr-pane.md
current_guidance: ../../agent-marketplace/packages/utils-agent/skills/acpx/SKILL.md
status_detail: "Implemented in source; live Orca terminal preview verified, host installation remains."
---

# ACPX shared pane

Replace one Orca split per ACPX invocation with one compact Herdr view per
calling Orca terminal. Keep the existing `acpx-pane --log ... -- ...` command as
the calling harness interface. Add `acpx-pane --view` to open or return to the
view without starting another run.

The helper names tabs by launch order, local time, and shortcut. Each invocation
gets its own tab and log. Completed tabs remain visible; stopping one helper
closes only its tab. The Herdr config hides the sidebar and pane decoration and
shows a session count in the bottom tab strip. Install Herdr through the
mac-desktop package group. See [ADR 0036](../adr/0036-acpx-shared-herdr-pane.md).

The pane shell execs the logging runner. After ACPX exits, the runner records
the status and waits for a close key, leaving output visible without a shell
prompt. An ordinary key or Ctrl+C closes that tab; the last ACPX tab closes the
Orca view. Herdr closes a tab when its main process exits, so the completed
runner stays until the key arrives. A stopped Herdr session is discarded before
reopening to avoid restoring completed tabs as blank shells.
Launches and completed-tab closes take the same file lock, so a close cannot
hide a run that starts in the shared view at the same time.

Verification covers inline behavior, shared view reuse, tab labels, argument
passing, and exit status in Bats, plus a local CLI smoke test with Herdr 0.9.1.
In a live Orca terminal, two `acpx --version` runs reused one pane; its preview
showed both labels and `sessions: 2`. A later run confirmed the completed tab
ends on its exit marker without a shell prompt. A live Ctrl+C closed the focused
tab, and another closed the last Orca view; reopening started with one clean tab.
Host installation and human interaction with the tab strip are separate follow-up gates.
