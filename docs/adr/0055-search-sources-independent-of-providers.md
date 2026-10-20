---
status: accepted
doc_type: adr
summary: "Separate evidence sources and areas from executable providers while admitting explicit public site scopes."
created: 2026-10-18
updated: 2026-10-18
related:
  - ../plans/search-source-selection-plan.md
  - 0054-shared-search-engine.md
  - ../research/search-source-selection-qualification.md
  - ../../agent-marketplace/src/utils-agent/skills/search/references/extending.md
---

# Separate search sources from provider capabilities

## Context

The 1.15.0 engine declares a closed source map containing one area and domain per
source. General web adapters copy that list; validation rejects new sources and
cross-area uses. This couples source knowledge to implementation availability and
turns source expansion into package changes even when an existing web route could
retrieve the evidence. Area-only requests silently choose particular platforms.

The [source-selection plan](../plans/search-source-selection-plan.md) broadens
community, multilingual and shopping-channel discovery. A permanent list of every
site is unsuitable; treating every unknown source as a supported native integration
would also be misleading. This decision changes a public request and capability
boundary, with compatibility and identity consequences.

## Decision

Keep known source aliases and admit an explicit, validated data-only site scope
such as `site:zenn.dev` or `site:example.org/community`. A shared resolver owns
normalization and constraints for planning, query translation, result filtering
and identity. Provider endpoints, executable commands and credentials remain in
trusted adapter/host configuration, outside source references.

An area describes the facet's evidence need; a source can serve several areas.
Validate area/operation compatibility independently, then require a provider's
actual source-scope and operation support. Generic web routes declare their
qualified public-web operations; native and vertical routes retain explicit
capabilities. Awareness of a platform never establishes comments, transcripts,
offers or complete search access.

The host chooses source families, languages and markets through conditional
guidance and existing reasoning. The planner resolves concrete jobs without a new
model service. Source profiles describe usefulness and limitations; adapters own
executable support and prerequisites. Runtime observations own current access.
The seed catalogue guides exploration and does not limit admissible sources.

New area-only requests require explicit source selection unless a pinned route
is unambiguous. Bare general-web queries and explicit source/prepared-job calls
retain their useful shorthand. Global source and area choices remain restrictions; exploratory seeds are facets.
Existing runs preserve their legacy identity policy, resolved work, identities,
budgets and exactly-once settlement; unexecuted plans that no longer resolve fail
with a re-plan instruction. New request fields are additive under schema 1;
a representation change requires a separately specified versioned migration before
implementation. The matching engine and consumers ship in one package.

Reuse the 1.15.0 candidate pool, relevance assessment and XDG diagnostics. Add only
bounded context/source decisions and their links to existing facets. Extend the
same run for additional discovery or inspection. Retention rules cover new prose
and metadata, and the compact receipt remains derived from structured facts.

## Alternatives and trade-offs

| Alternative | Trade-off |
| --- | --- |
| Add every platform to the fixed source enum | Simple initially; requires releases for ordinary new sites and keeps the area/source coupling |
| Treat arbitrary source strings as platform IDs | Flexible but hides typos, scope meaning and capability limits |
| Use general web for everything without source identity | Easy transport reuse; loses scoped coverage, provenance and source-specific evidence checks |
| One native adapter or model router per platform | Higher maintenance and access requirements before source usefulness has been demonstrated |
| Explicit site scopes with qualified routes | Requires careful filtering, identity and compatibility work; supports new evidence sources through existing transports |

Unknown sites use conservative URL identity until a qualified platform rule exists.
This may retain duplicates that a specialized parser could resolve, which is
preferable to merging distinct offers, revisions or federated resources. A known
platform reached by alias or site scope should still share established identity.

Source profiles can become stale. Keep volatile facts dated, discover alternatives
when useful, and qualify route health separately. Provider ranking remains a route
policy; semantic task fit remains the host's assessment.

## Acceptance

Accepted with the 1.16.0 implementation. The [qualification record](../research/search-source-selection-qualification.md)
records 91 passing portable tests, baseline-generated checkpoint compatibility,
new domains without registration, cross-area source use with operation limits,
scope filtering and stable identity. Compatibility exceptions are explicit:
contradictory source/required-source pins now fail, and native GitHub qualification
is limited to github.com; Enterprise hosts need a separately qualified route.
Literal path scopes preserve case rather than guessing server-specific aliases.
The linked plan owns broader source guidance and task-quality qualification,
which this architectural acceptance does not establish. This ADR does not supersede
the shared-engine ownership decision in ADR 0054.
