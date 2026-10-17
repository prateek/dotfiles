---
status: superseded
updated: 2026-10-16
closed: 2026-10-16
status_detail: "ADR 0050 replaces sibling publication in utils-agent with the default-disabled experimental plugin."
superseded_by: 0050-suspend-jev-in-experimental-plugin.md
current_guidance:
  - 0050-suspend-jev-in-experimental-plugin.md
doc_type: adr
summary: "Jev moves into a `browser-jev` skill published beside `browser` in `utils-agent`, restoring the regular skill and linking to its references."
created: 2026-09-27
related:
  - ../plans/jev-deterministic-preparation-plan.md
  - 0033-skill-owned-jev-browser-runner.md
  - 0034-discover-jev-controls-in-the-browser-skill.md
---

# Keep Jev in a separate experimental browser skill

## Decision

Publish `browser-jev` as a sibling of `browser` in the `utils-agent` plugin.
Move the Jev runner, launcher, and trial reference into `browser-jev`. Restore
the regular `browser` skill to its pre-Jev content. The new skill reads the
regular skill's entrypoint, policy, and driver references through relative
links rather than copying them.

`browser-jev` is selected for an explicitly requested Jev experiment. It
borrows a page chosen under the regular browser workflow and returns control
to that workflow on handoff. The regular skill remains the default browser
route. The runner's job/result contract and dynamic discovery behavior do not
change as part of this move.

## Rationale and consequences

The Jev candidate is not ready for general adoption. A separate skill keeps
its experimental instructions and scripts out of the default browser skill
while preserving one source for browser authorization, focus, driver choice,
and cleanup rules. The two sibling skills must be published together in the
same plugin so their relative links resolve.

The [active plan](../plans/jev-deterministic-preparation-plan.md) retains the
qualification and paired evaluation gates. This decision supersedes the
placement in [ADR 0033](0033-skill-owned-jev-browser-runner.md); it does not
reverse the dynamic-action decision in
[ADR 0034](0034-discover-jev-controls-in-the-browser-skill.md).
