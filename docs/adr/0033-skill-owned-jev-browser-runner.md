---
status: superseded
doc_type: adr
created: 2026-09-26
updated: 2026-09-27
closed: 2026-09-27
superseded_by: 0035-separate-experimental-jev-browser-skill.md
related:
  - ../plans/jev-browser-runner-plan.md
  - ../research/jev-browser-integrations.md
status_detail: "Runner and borrowed-browser architecture remain; ADR 0035 moves implementation into a separate experimental skill."
---

# Run Jev beneath the shared browser skill

## Decision

Own optional Jev execution in the portable `browser` skill in `utils-agent`.
Claude, Codex, and Pi invoke one local runner with a versioned JSON job/result
contract. The skill selects the browser identity and owns its resources. The
runner borrows an explicit page/session and returns verified evidence or a
handoff to the same parent and browser.

Build a small authored Node runner using built-in APIs. Provide Orca and
standalone agent-browser behind the same observation/action interface and
qualify each driver independently.
Use the existing Cloudflare credential through a distinct provider adapter.
Jev selects among eligible operations and targets; caller-supplied values
provide text. Authorization and outcome verification remain executable rules
outside model choice. Record uncertain effects and prohibit blind replay.

## Rationale

A skill that sends every click back to the parent model retains the latency
we want to reduce. A local loop can make several decisions while preserving
the shared skill as the integration surface. Orca already exposes the browser
commands that loop needs; mapping its commands and responses does not require
replacing its browser.

Forvela demonstrates an injectable browser object, but its completion and
retry semantics need changes. Jev Ultrafast creates its own Browser Harness
connection and Chrome tab. Reusing that runtime would require replacing its
driver and session assumptions. Its source remains useful for decision spaces
and execution bookkeeping. Pi-specific tool registration would narrow the
entry point without solving either integration problem.

## Consequences

We own a small execution loop and two driver adapters. Qualify each driver's
response shapes, freshness guarantees, and focus behavior on its exact runtime.
Cloudflare model access is a separate contract from TypeSafe's direct API.
The initial lane handles bounded tasks with inspected controls and independent
checks; open-ended or unsupported work returns to the parent.

Adoption depends on real Orca/Jev trials and a matched benchmark against the
current skill. A passing experiment enables an opt-in lane. Existing browser
routing remains authoritative until a later default-change decision.

The [completed experiment plan](../plans/jev-browser-runner-plan.md) records
the interfaces, test cases, and rollout gates. Its development comparison
rejected adoption because the candidate was slower and completed fewer tasks
autonomously. This does not change skill ownership. Current experimental
execution guidance lives in the [skill reference](../../agent-marketplace/packages/utils-agent/skills/browser-jev/references/jev.md).
