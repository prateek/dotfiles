---
status: current
doc_type: runbook
summary: "Quarterly pass over docs that need a decision and over recent agent-session friction, with what to do for each finding."
owner: Prateek
created: 2026-10-17
updated: 2026-10-17
related:
  - ../document-lifecycle.md
  - ../adr/0052-retire-closed-docs-through-a-ledger.md
  - ../plans/periodic-session-review-plan.md
  - ../plans/agent-friction-remediation-plan.md
  - ../../home/dot_agents/docs/agentsview.md
---

# Quarterly review

Run this once a quarter, or whenever `just docs-due` at landing time lists
more than a handful of items. Nothing schedules it; the landing runbook is
the nudge.

## Docs that need a decision

```sh
just docs-due
```

The report has three sections. Each item gets one of the outcomes below in
the same session, and the outcome is a change, not a note.

| Section | Outcomes |
| --- | --- |
| Parked plans past a quarter | Resume it (set `status: active`, drop the `Parked:` detail) or close it as `rejected` and retire it. Leaving it parked is allowed, but say so to Prateek; the default when nobody answers is to leave it parked, never to retire it. |
| Open plans with no commit in a quarter | Finish it, park it with a `Parked:` detail and a reason, or close it. A plan whose work has already landed closes now: move anything durable, add the ledger row, delete the file. |
| Research due for a decision | A doc with no consumer names the plan or ADR it informs in `related`, or retires. A doc whose consumers are all settled retires once the consumer cites the findings it used. |

Retirement steps are in [Document Lifecycle](../document-lifecycle.md#retiring-a-document).

Then regenerate the inventory and validate the result:

```sh
just docs-inventory
just test-docs-lifecycle
```

## Session friction

Agent sessions record every failed command, retry, and repeated prompt, and
nobody reads them in aggregate. The [periodic session review plan](../plans/periodic-session-review-plan.md)
proposed scheduled retrospectives with promoted scripts; none of that is
built or scheduled. Until it is, the quarterly pass is manual and bounded:

1. Take a read-only snapshot of the AgentsView store as described in
   [agentsview](../../home/dot_agents/docs/agentsview.md). Never query the
   live file, prune it, or start its daemon.
2. Pick one host and one harness for the quarter. Count failed commands and
   tool errors by shape (an unknown flag on one CLI, an unmatched glob, an
   untrusted config), not by raw regex.
3. For each shape that recurs across sessions, reproduce it against the
   current tool before proposing a fix. Prefer a tested helper over a longer
   instruction.
4. Re-check every open acceptance item in the
   [agent friction remediation plan](../plans/agent-friction-remediation-plan.md)
   against the snapshot and record its status there.
5. Keep the report private under `~/.local/state/session-review/<date>/`.
   Aggregate counts can go into a research doc or a plan; transcript
   excerpts, account identifiers, and work content cannot.

Cursor sessions have no tool results in the store, so their failures are
invisible to this pass.
