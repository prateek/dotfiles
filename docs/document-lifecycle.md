---
status: current
doc_type: convention
created: 2026-05-10
updated: 2026-05-12
---

# Document Lifecycle

Every Markdown document under `docs/` starts with YAML frontmatter that includes
a canonical `status` value.

Use `docs/index.md` plus frontmatter so humans and scripts can answer the same
basic questions:

- Is this doc authoritative?
- Is it a proposal?
- Has it been replaced?
- What should supersede it?
- Is it closed history that should not be edited for current behavior?

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

- `doc_type`: `adr`, `plan`, `runbook`, `reference`, `research`,
  `convention`, or `index`.
- `owner`: person or team responsible for keeping the doc honest.
- `created`: ISO date when the doc was created.
- `updated`: ISO date for the last material content update.
- `related`: list of related docs, ADRs, plans, skills, or runbooks.
- `superseded_by`: successor doc when `status: superseded`.
- `current_guidance`: current docs, code, scripts, tests, or skills to use
  instead of this doc when it is historical.
- `closed`: ISO date when a doc became historical and stopped receiving
  body updates.
- `status_detail`: short freeform note for nuance that does not belong in
  `status`.

Do not invent ad hoc status values. Put nuance in `status_detail`.
Keep frontmatter simple enough for the repo validator: scalar values, inline
lists, or two-space list items. Do not use nested maps or block scalars.

## State Machine

Canonical states:

- `draft`: incomplete or exploratory. Use it while the shape is still changing;
  do not treat it as approved direction or ask agents to execute from it.
- `proposed`: ready for review, decision, or adoption. Use it when feedback is
  needed; do not use it for already-executed work unless the decision is still
  open.
- `accepted`: approved direction or decision record. Use it for ADRs and plans
  that have been chosen; do not treat it as the live operating manual unless a
  current or active guidance source points there.
- `active`: being executed or actively maintained as work changes. Use it for
  live plans, references, runbooks, research, and conventions; do not use it for
  closed history.
- `current`: stable routing or steady-state guidance that should be treated as
  authoritative until replaced. Use it sparingly; do not use it for plans.
- `superseded`: historical record replaced by another doc or source of truth.
  Use it when a successor exists, and set `superseded_by`; do not keep editing
  the body for current behavior.
- `rejected`: historical record closed without adoption. Use it when preserving
  the rejected rationale is useful; do not leave readers without
  `current_guidance` or `status_detail`.
- `archived`: historical record whose body is not maintained and may be stale.
  Use it when a doc no longer carries operational value; do not use it as
  current guidance.

Allowed transitions, as the ASCII lifecycle graph:

```text
draft -> proposed
draft -> active
draft -> superseded
draft -> rejected
draft -> archived

proposed -> accepted
proposed -> active
proposed -> superseded
proposed -> rejected

accepted -> active
accepted -> current
accepted -> superseded
accepted -> archived

active -> accepted
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

Use `proposed -> rejected` or `proposed -> superseded` to close a proposal that
did not proceed. Reserve `archived` for drafts, accepted or active work, and
current references that are no longer useful as guidance.

Moving to the same status is not a lifecycle transition. It is just a metadata
or content edit within the same state.

## Reading Docs As Guidance

Treat lifecycle status as routing metadata:

- Start with [docs/index.md](index.md). It is the maintained routing table for
  current guidance, proposed work, decision records, and historical records.
- `current` and `active` docs can guide current work.
- `accepted` ADRs explain why a decision was made. They are not the live
  implementation manual; see the ADR row in Type Guidance.
- `archived`, `superseded`, and `rejected` docs are archaeology. Use them to
  understand history, then follow `superseded_by` or `current_guidance`.

Frontmatter links in `related`, `superseded_by`, and `current_guidance` must
be repo-local relative paths that exist. Do not use `~/...`,
absolute paths, or web URLs in lifecycle routing metadata.

Use inline Markdown links for cross-references in doc bodies. The validator
checks repo-local inline links outside fenced code blocks.

## Docs Index

`docs/index.md` is required. Keep it short and update it when a doc is added,
renamed, closed, superseded, or reclassified.

The index should route readers to the right source of truth. It should not
duplicate detailed guidance from the docs it links to.

## Type Guidance

| Type | Usual statuses | Use when | Do not use when |
| --- | --- | --- | --- |
| `adr` | `proposed`, `active`, `accepted`, `superseded`, `rejected`, `archived` | Recording a decision, rationale, alternatives, and consequences. Use `active -> accepted` when active iteration ends. | Explaining the current procedure or implementation details that change often; put those in a reference or runbook. |
| `plan` | `draft`, `proposed`, `accepted`, `active`, `superseded`, `rejected`, `archived` | Proposing or executing a bounded initiative. Move durable guidance out before closure. | Representing steady-state behavior. Plans should never use `status: current`. |
| `runbook` | `active`, `current`, `superseded`, `archived` | Giving a repeatable procedure, validation path, recovery flow, or operator checklist. | Explaining broad architecture or preserving decision rationale. |
| `reference` | `active`, `current`, `superseded`, `archived` | Describing factual live system structure, ownership, configuration, or APIs. | Capturing a step-by-step workflow or one-time proposal. |
| `research` | `draft`, `active`, `current`, `superseded`, `archived` | Capturing evidence, landscape review, or investigation notes that future work may cite. | Acting as authoritative operating guidance unless it is deliberately maintained as `active` or `current`. |
| `convention` | `active`, `current`, `superseded`, `archived` | Defining durable repo or team rules that apply across many changes. | Storing one-off session notes, plans, or local scratch decisions. |
| `index` | `active`, `current` | Routing readers to the source of truth for current guidance, proposed work, decisions, and history. | Duplicating the full contents of the docs it links to. |

## Maintenance Rules

- Move existing `Status:` lines into frontmatter when editing a doc.
- Update `docs/index.md` when a doc's path, title, status, or current guidance
  changes.
- If a doc changes authority, update `status` in the same change.
- If a doc is replaced, set `status: superseded` and add `superseded_by`.
- If a doc is no longer useful as guidance, set `status: archived` and add
  `current_guidance`.
- If a doc is rejected, add `current_guidance` or a `status_detail` explaining
  that there is no successor.
- When closing a doc, set `closed` and keep body edits out of the closure
  change. Finish body edits first, then close the doc in a metadata-only
  change.
- Once a doc is `archived`, `superseded`, or `rejected`, only update
  frontmatter links or metadata. Do not refresh the body for current behavior.
- Keep the H1 title in the Markdown body after the frontmatter.
