---
status: accepted
doc_type: adr
summary: "Calling agents select capability-ranked models from machine harness catalogs, cache evidence, and prefer included native delegation."
created: 2026-10-18
updated: 2026-10-18
related:
  - 0045-acpx-explicit-model-profiles.md
  - 0041-agent-clis-single-declaration.md
  - ../references/acpx-routing.md
---

# Agent-selected machine model routing

## Decision

Use `agent_clis` as the sole harness eligibility declaration. Discover accessible
models and producer descriptions/defaults within those harnesses. The calling
agent interprets the evidence, consulting producer guidance or Artificial Analysis
when necessary, then commits a validated machine cache with its sources.
No maintained capability ranking or model-generation pins select shortcuts.

The `a` prefix chooses the strongest eligible model in its family. The `p` prefix
chooses the newest model in the next lower capability tier. `agptw` aliases `pgpt`.
Unsuffixed names use harness default thinking; each `x` advances one supported
level without changing models. Unknown defaults and excessive increments reject
modifiers. Missing or ambiguous capability tiers reject explicitly.

Included subscription/employer access and family-compatible local inference form
the default pool. Paid APIs require an explicit override. Within that pool choose
model capability before harness preference; prefer included access for equivalent
models. Prefer a native subagent when the calling session can honor the exact
model, effective thinking, access, and write authority. Otherwise use external
acpx for the same request. Session and flow requests remain external.

Cache selections for 24 hours from catalog discovery and invalidate them when
machine routing configuration changes. After a temporary refresh failure, permit
a reported last-successful selection up to seven days old. Failed launches never
trigger silent model or paid-provider fallback. The calling agent refreshes the
cache; apply only installs guarded commands. Standalone shell execution does not
launch a selection model.

## Rationale

Model release numbers, picker order, and price cannot reliably establish maximum
intelligence. Producer metadata contains descriptions and default effort signals
that the old adapters discarded. Letting the calling model interpret that evidence
avoids hand-maintained rankings while preserving explicit, inspectable decisions.
Machine catalogs and runtime native-tool schemas are different authorities: a
cached model roster cannot prove what the current session can spawn.

## Consequences

Catalog discovery and deterministic validation are automated; semantic selection
quality remains the calling agent's responsibility. Cached evidence makes a
selection reviewable but does not establish benchmark accuracy or inference quota.
A cold cache requires an agent using the skill. Pi-native candidates can be useful
without an ACP adapter, but external-only callers must reject them. New harness
adapters may be added without adding another per-machine eligibility list.

This supersedes ADR 0045's pinned profiles and separate route declarations.
The [routing reference](../references/acpx-routing.md) owns operational details.
