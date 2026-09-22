---
status: accepted
doc_type: adr
created: 2026-09-22
updated: 2026-09-22
related:
  - ../plans/land-changes-workflow-plan.md
  - ../runbooks/dotfiles-landing.md
---

# Discover landing workflows and persist scoped choices

## Decision

The land-changes skill discovers the destination's publication methods, actions,
gates, and automatic effects. Natural language and named selectors have equal
authority. Inspection explains available controls without making changes; an
ordinary landing inspects the selected route and its dependencies.

Persist explicit choices separately from observed capabilities. Saved choices
retain their native identity, semantic fingerprint, and authorized scope. Groups
save concrete members unless the user explicitly selects dynamic membership.
Changes of meaning invalidate the affected preference. Existing v1 settings are
read without mutation and require deliberate migration before v2 persistence.

The helper resolves and stores data; the agent owns discovery, authorization,
and execution. Follow-ups require a covering instruction or saved choice. A
completed change-specific action does not authorize the next change's action.
Standing instructions and unfinished authorized work remain effective in scope.

## Reasons and consequences

The fixed deploy boolean hid environment and effect scope. Test flags depended
on inconsistent classifications and could not express hook or CI gate choices.
A universal workflow executor or vendor catalogue would add another source of
truth; native procedures and conditional references retain repository flexibility.

Exact direct-Git recovery stays in a method reference. Required and informational
checks remain distinct, as do running, gating, and waiting. Explicit bypasses use
existing caller capabilities; changing shared policy is a separate operation.

The [implementation plan](../plans/land-changes-workflow-plan.md) records evidence
and validation. Current operation belongs to the
[skill](../../agent-marketplace/packages/review/skills/land-changes/SKILL.md) and
[dotfiles runbook](../runbooks/dotfiles-landing.md).
