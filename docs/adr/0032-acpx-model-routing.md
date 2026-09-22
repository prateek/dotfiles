---
status: accepted
doc_type: adr
created: 2026-09-22
updated: 2026-09-22
current_guidance: ../references/acpx-routing.md
related:
  - ../plans/acpx-routing-plan.md
---

# Resolve model shortcuts independently of ACP harnesses

## Decision

Keep model-family selection rules and harness launch/discovery contracts in
separate configuration. Give acpx its own machine declarations; `agent_clis`
continues to govern installation and plugin activation. A declared route must
have its ACP dependencies and a readable model catalog. Undeclared routes
remain ineligible even when installed.

Order eligible routes by matching local inference, native subscription access,
direct provider APIs, then aggregators. Machine and model-family preferences
may refine that order. Resolve latest/previous generations inside the selected
route's catalog, and freeze exact model and effort selections during apply.
Never substitute another family to satisfy local preference or silently lower
an unsupported effort.

Work uses Claude Code through Vertex and Cursor. Non-work uses local inference,
Codex and Claude Code subscriptions, direct OpenAI/Anthropic/Cerebras APIs, and
OpenRouter, without Cursor.

## Rationale

The old template mixes model pins, machine policy, executable assumptions, and
backend precedence. It can hide installed clients or emit broken launches, and
native GPT shortcuts inherit mutable defaults. A catalog-derived, inspectable
resolution makes a shortcut's meaning explicit until the next apply.

## Consequences

Catalog access becomes an apply-time dependency. Diagnostics must distinguish
a broken declaration from a catalog lacking the requested family or generation.
Model naming and tier conventions remain explicit data; unknown formats cannot
be treated as the newest model by guesswork. Runtime use must not perform fresh
selection or choose a different provider after an inference failure.

Implementation and validation are tracked in the [plan](../plans/acpx-routing-plan.md).
