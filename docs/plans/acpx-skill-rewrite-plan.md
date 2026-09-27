---
status: archived
doc_type: plan
created: 2026-09-26
updated: 2026-09-26
closed: 2026-09-26
current_guidance:
  - ../runbooks/acpx-skill-rewrite.md
superseded_by: acpx-native-skill-rewrite-plan.md
related:
  - ../runbooks/acpx-skill-rewrite.md
  - ../../scripts/acpx/rewrite-skills.flow.mjs
status_detail: "Flow authoring completed; six fixture tests and definition/syntax checks passed. No model sweep was executed."
---

# Authored skill rewrite flow

Deliver an acpx flow for every authored skill under
`agent-marketplace/packages/*/skills/`. Imported selections are excluded by the
user's scope choice. Each skill receives an Astra/high rewrite using
writing-for-agents, an Opus 5.5/high review, and an Astra/high correction pass.
Bound active workers, retain per-skill patches, and give one afablex invocation
the complete set for review and fixes before exporting one human-reviewable diff.

## Implementation boundary

- Use acpx action nodes for prepare, bounded workers, aggregate review, and
  validated export. Keep subprocess and artifact ownership in a Python driver.
- Snapshot pending source content without changing the source worktree or index.
  Give each worker its own Git checkout; assemble patches in a separate checkout.
- Pin the requested models, preserve route environment, and freeze afablex's
  resolved command. Report provider failures without falling back.
- Enforce complete file/review accounting, patch scope, one aggregate invocation,
  package version increments, validation, and patch applicability before export.
- Keep prompts beside the controller and operator instructions in the linked
  runbook. Preserve artifacts on failure; leave reruns explicit.

## Completion criteria

The flow, prompts, controller, and operator guide exist. Fixture checks establish
bounded concurrency, ordered stages, scope enforcement, patch integrity, source
preservation, version increments, and failure behavior. Syntax and documentation
checks pass. No real model invocation, skill rewrite, deployment, or publication
is part of completion; a live sweep requires a later execution request.
