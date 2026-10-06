---
status: accepted
doc_type: adr
created: 2026-10-05
updated: 2026-10-05
current_guidance: ../references/acpx-routing.md
related:
  - ../plans/acpx-explicit-profiles-plan.md
  - 0032-acpx-model-routing.md
---

# Explicit ACPX model profiles

## Decision

Keep ADR 0032's model/harness separation, machine route eligibility, catalog
introspection, apply-time publication, and configuration ownership. Replace
its automatic latest/previous generation and effort-step shortcuts with
explicit profiles in `acpx_models.toml`.

The current GPT workhorse and writer use Sol 6.1 medium. The first escalation
uses Astra 6 medium; subsequent escalations use high and xhigh. Previous GPT
uses Sol 6. Current/previous Claude profiles use Opus 5.5/5 and Fable 5.1/5,
starting at medium. Current Gemini uses 3.8 Flash high; previous Gemini selects
the highest accessible generation below the pinned current target, then its
highest configured tier. The [reference](../references/acpx-routing.md) lists
each suffix's exact effort.

Preserve family-based route precedence: choose the first declared, usable
route advertising recognized models in the family before checking the target.
Missing targets and unsupported exact efforts reject; they cannot change
model, effort, or route. Provider prefixes, date snapshots, context decorations,
and accepted Claude generation spelling may identify the same target. Launch
uses the provider's full advertised ID.

## Rationale

A numeric generation is no longer a useful workhorse/flagship ordering:
Sol 6.1 is the preferred default while Astra 6 is the escalation. Writing
quality also has no established relationship to the smallest previous tier.
Explicit profiles make these choices reviewable and prevent a catalog refresh
from silently changing the default model or reasoning budget.

## Consequences

New defaults require a reviewed profile edit. The `a` and `p` prefixes identify
chosen current/previous profiles rather than following every release. The
`x` suffix is a configured escalation, including a model change for `agptx`.
Old suffix names remain managed, with exact unsupported efforts rejecting.
Hosts with stale catalogs may reject newly pinned profiles until their adapters
advertise those targets. Catalog resolution is not inference validation.

Implementation and validation are tracked in the
[plan](../plans/acpx-explicit-profiles-plan.md).
