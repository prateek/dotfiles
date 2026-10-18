---
status: accepted
doc_type: adr
created: 2026-10-17
updated: 2026-10-17
current_guidance: ../../agent-marketplace/packages/utils-agent/skills/search/SKILL.md
related:
  - ../plans/search-skill-plan.md
  - ../research/search-skill-implementation.md
summary: "Shared retrieval adapters, budgets and provenance for search and specialized consumers."
---

# Share retrieval through a portable search engine

## Decision

Publish `utils-agent:search` with web, code, social and shopping references and a
Python standard-library engine. The host agent chooses evidence facets and judges
results. The engine resolves available routes, validates constraints, translates
adapter queries, accounts for calls and emits typed candidates with provenance.
Sources are optional; a missing required source leaves useful partial results.

API/native adapters and cooperative host jobs share one budget and deadline.
Host work is checkpointed before dispatch and reconciled by run/work/attempt ID.
Unknown usage consumes its reservation. Inspection jobs can be appended after
URLs are discovered without increasing the original budget or resetting time.
The sibling browser skill retains runtime, identity, interaction and cleanup.

Keep domain policy in specialized skills. `skills-searcher` retains query
construction, frontmatter interpretation, legacy metric merge/ranking and
preview/install output. It calls the sibling CLI with prepared jobs; its provider
transport and parsing move into search. Provider names or site filters alone do
not justify a specialized skill.

## Consequences

- A portable CLI works without a self-hosted index or mandatory provider keys.
- Pins, preferences and paid authorization are distinct; saving a preference
  grants no new access or spending permission.
- A provider response is candidate discovery. Completion requiring content,
  identity or availability needs an explicit host assessment with references.
- Native tools and opaque host tools may perform internal requests; the engine's
  operation budget is not a dollar guarantee.
- Derived-only providers do not persist result content in state. Callers still
  own stdout/transcript retention and benchmark eligibility.
- Skills-searcher now requires the sibling search skill from the same package.
  The shared engine caps concurrency at two and serializes GitHub operations;
  the legacy concurrency option remains an upper bound.

The [implementation plan](../plans/search-skill-plan.md) records acceptance and
remaining quality gates; the [qualification record](../research/search-skill-implementation.md)
separates contract checks, live access, model evaluation and activation.
