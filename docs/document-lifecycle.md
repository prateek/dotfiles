---
status: current
doc_type: convention
created: 2026-05-10
updated: 2026-05-10
---

# Document Lifecycle

Every Markdown document under `docs/` starts with YAML frontmatter that includes
a canonical `status` value.

Use frontmatter so humans and scripts can answer the same basic questions:

- Is this doc authoritative?
- Is it a proposal?
- Has it been replaced?
- What should supersede it?

## Required Frontmatter

Minimum frontmatter:

```yaml
---
status: draft
---
```

Recommended frontmatter:

```yaml
---
status: active
doc_type: plan
owner: Prateek
created: 2026-05-10
updated: 2026-05-10
related:
  - ../adr/0006-chezmoi-migration-prototype.md
status_detail: "Accepted plan; implementation in progress."
---
```

Required fields:

- `status`: one of the canonical states below.

Recommended fields:

- `doc_type`: `adr`, `plan`, `runbook`, `reference`, `research`, or
  `convention`.
- `owner`: person or team responsible for keeping the doc honest.
- `created`: ISO date when the doc was created.
- `updated`: ISO date for the last material content update.
- `related`: list of related docs, ADRs, plans, skills, or runbooks.
- `superseded_by`: successor doc when `status: superseded`.
- `status_detail`: short freeform note for nuance that does not belong in
  `status`.

Do not invent ad hoc status values. Put nuance in `status_detail`.

## State Machine

Canonical states:

- `draft`: incomplete or exploratory. Do not treat as approved direction.
- `proposed`: ready for review or decision.
- `accepted`: approved direction or decision. Implementation may still be
  pending.
- `active`: being executed or actively maintained as work changes.
- `current`: steady-state reference or runbook. Treat as authoritative until
  replaced.
- `superseded`: replaced by another doc. Must set `superseded_by`.
- `rejected`: closed without adoption. Keep only if the rationale is useful.
- `archived`: historical record. Do not use as current guidance.

Allowed transitions:

```text
draft -> proposed
draft -> active
draft -> rejected

proposed -> accepted
proposed -> active
proposed -> rejected

accepted -> active
accepted -> current
accepted -> superseded

active -> current
active -> superseded
active -> archived

current -> active
current -> superseded
current -> archived

superseded -> archived
rejected -> archived
```

Use `current -> active` when a steady-state doc is reopened for material
revision. Use `active -> current` when execution ends and the doc becomes an
operator reference.

## Type Guidance

ADRs usually use:

```yaml
status: proposed | accepted | superseded | rejected
doc_type: adr
```

Plans usually use:

```yaml
status: draft | proposed | accepted | active | current | superseded | archived
doc_type: plan
```

Runbooks and references usually use:

```yaml
status: current | active | superseded | archived
doc_type: runbook | reference
```

Research docs usually use:

```yaml
status: draft | current | superseded | archived
doc_type: research
```

## Maintenance Rules

- Move existing `Status:` lines into frontmatter when editing a doc.
- If a doc changes authority, update `status` in the same change.
- If a doc is replaced, set `status: superseded` and add `superseded_by`.
- If a doc is no longer useful as guidance, set `status: archived`.
- Keep the H1 title in the Markdown body after the frontmatter.
