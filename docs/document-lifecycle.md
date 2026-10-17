---
status: current
doc_type: convention
summary: "Frontmatter contract, statuses, retirement rule, ledger, inventory, and validator rules for every Markdown document under docs/."
created: 2026-05-10
updated: 2026-10-17
related:
  - adr/0052-retire-closed-docs-through-a-ledger.md
  - retired.md
  - inventory.md
  - runbooks/quarterly-review.md
---

# Document Lifecycle

Every Markdown document under `docs/` starts with YAML frontmatter that says
what it is, what it covers, and whether it is still guidance. A document that
stops being guidance leaves the tree; the [retirement ledger](retired.md)
records that it existed. ADRs are the exception and stay forever.

Terms used here are defined in the repo [glossary](../GLOSSARY.md).

## Required Frontmatter

```yaml
---
status: active
doc_type: plan
summary: "One line saying what the document covers, never where it stands."
owner: Prateek
created: 2026-05-10
updated: 2026-05-10
related:
  - ../adr/0006-chezmoi-migration-prototype.md
status_detail: "Nuance that does not fit in status."
---
```

Required fields:

- `status`: one of the canonical states below.
- `summary`: one sentence describing scope. The generated inventory shows it,
  so it must not carry progress, dates, or what remains.

Recommended fields:

- `doc_type`: `adr`, `plan`, `runbook`, `reference`, `research`,
  `convention`, or `index`.
- `owner`: person responsible for keeping the doc honest.
- `created`, `updated`: ISO dates. `updated` is informational; the validator
  and `just docs-due` read dates from git.
- `related`: related docs, ADRs, plans, skills, or runbooks. A research doc
  names the plan or ADR it informs here.
- `superseded_by`: successor when `status: superseded`.
- `current_guidance`: what to use instead when the doc is historical.
- `closed`: ISO date when a doc became historical.
- `status_detail`: short freeform note. A parked plan starts it with
  `Parked:` and a reason.

Do not invent ad hoc status values. Keep frontmatter simple enough for the
validator: scalar values, inline lists, or two-space list items. No nested
maps or block scalars.

## States

- `draft`: incomplete or exploratory. Not approved direction; agents do not
  execute from it. A parked plan is a `draft` with a `Parked:` detail.
- `proposed`: ready for review or decision.
- `accepted`: approved direction or decision record. For an ADR this locks
  the body.
- `active`: being executed or actively maintained.
- `current`: stable steady-state guidance, authoritative until replaced.
  Never for plans.
- `superseded`: replaced by another doc; `superseded_by` is required.
- `rejected`: closed without adoption; `current_guidance` or `status_detail`
  says why.
- `archived`: closed because it no longer carries operational value;
  `current_guidance` is required.

`superseded`, `rejected`, and `archived` are the closed states. There is no
transition graph: a doc moves between states as its situation changes, and
the validator checks only that the state is allowed for its type, that a
closed doc stays closed, and that an accepted ADR stays `accepted` or closes.
Revived work gets a new document that links the ledger.

| Type | Allowed statuses | Use when | Do not use when |
| --- | --- | --- | --- |
| `adr` | `proposed`, `active`, `accepted`, `superseded`, `rejected`, `archived` | Recording a decision that is hard to reverse, surprising without context, and the result of a real trade-off. All three, or no ADR. | Explaining current procedure; put that in a reference or runbook. |
| `plan` | `draft`, `proposed`, `accepted`, `active`, `superseded`, `rejected`, `archived` | Work that spans more than one landing or must hand off between sessions. | Work that fits one landing; its commit message is the plan. Prototypes and spikes stay in scratch. |
| `runbook` | `active`, `current`, `superseded`, `archived` | A repeatable procedure, validation path, or operator checklist. | Architecture or decision rationale. |
| `reference` | `active`, `current`, `superseded`, `archived` | Factual live system structure, ownership, configuration. | A step-by-step workflow or a proposal. |
| `research` | `draft`, `active`, `current`, `superseded`, `archived` | Evidence or investigation that a named plan or ADR will consume. | Operating guidance; move that to a reference. |
| `convention` | `active`, `current`, `superseded`, `archived` | Durable repo rules that apply across many changes. | One-off notes. |
| `index` | `active`, `current` | The router, the inventory, and the ledger. | Anything else. |

A `plan` may change type to `reference` or `runbook` when its durable
content becomes the steady-state doc; other type changes are new documents.

## Retiring a document

A closed document that is not an ADR leaves the tree. Do it in one change:

1. Move anything still true to its durable home: a reference, runbook, ADR,
   or the skill that owns the workflow. A fact that already lives only in a
   skill file stays there; do not copy it into a reference.
2. Repoint every editable doc that links the file to the durable home or to
   the ledger. Locked docs keep their links and frontmatter targets; the
   validator accepts a retired path there, so retiring a plan never touches
   the ADRs that cite it. The ledger's own links are not checked.
3. Append a row to [retired.md](retired.md): closed date, docs-relative path,
   title, closing status, and where the content went. The row is the record
   of the closure; the file's own frontmatter does not need to change first.
4. Delete the file and regenerate the inventory with `just docs-inventory`.

The validator refuses a deletion under `docs/` without a ledger row, refuses
a ledger edit that changes or removes an existing row, and refuses a file at
a path the ledger lists. Revived work gets a new file that links the ledger.

Plans close in the change that lands their last step. A plan whose work will
not land closes as `rejected`. A plan that is waiting on something is parked,
not left open: set `status: draft` and a `Parked:` detail.

Research retires when every plan or ADR it informs is accepted or closed and
cites what it used. Research with no consumer for a quarter is put to Prateek
at the quarterly review.

ADRs never retire. A withdrawn proposal closes as `rejected` so its number
stays taken. A superseded ADR keeps its body and may gain exactly one line
directly under its title, matching `superseded_by`:

```markdown
> Superseded by [ADR NNNN](NNNN-slug.md).
```

That is the only body edit a locked doc accepts.

## Locked bodies

Accepted ADRs and any closed doc still in the tree have locked bodies. Only
frontmatter changes, link-target repairs after a detected move, and the
supersession banner are accepted. Finish body edits before closing a doc;
the validator checks the closing change and the commits that follow it
against the branch base. ADRs are the only closed docs that stay in the tree,
so in practice this is an ADR rule.

Numbers in `docs/adr/NNNN-slug.md` are never reused or renumbered. The
validator rejects an added ADR whose number already exists.

## Router, inventory, and ledger

- [index.md](index.md) is the router: current references, runbooks, and
  conventions, the open plans by name, and pointers to the rest. Keep it
  short; its rows carry no status prose.
- [inventory.md](inventory.md) is generated from frontmatter by
  `just docs-inventory` and lists every doc with its status and summary. The
  validator fails when it is stale. Never edit it by hand.
- [retired.md](retired.md) is the append-only ledger of retired docs.

## Reading docs as guidance

- `current` and `active` docs guide current work.
- `accepted` ADRs explain why; the reference or runbook they point at says
  how.
- A `draft` with a `Parked:` detail is not direction.
- A closed doc still in the tree is history. Follow `superseded_by` or
  `current_guidance`.
- A retired doc is in the ledger and in git history. Read it only to
  understand the past.

Frontmatter links in `related`, `superseded_by`, and `current_guidance` must
be repo-local relative paths that exist, or retired paths in a locked doc.
Body links are checked in every doc that is not closed, outside fenced code
blocks, with the same allowance for locked docs.

## Validation

- `just test-docs-lifecycle` runs the validator's fixtures and checks this
  checkout against `DOCS_LIFECYCLE_BASE` (default `HEAD`); use
  `DOCS_LIFECYCLE_BASE=origin/master` for a whole branch. The pre-commit hook
  and the CI static lane run the checkout check.
- `just docs-inventory` regenerates the inventory.
- `just docs-due` lists parked plans and open plans with no commit in ninety
  days, research with no consumer, and research whose consumers are settled.
  The landing and [quarterly review](runbooks/quarterly-review.md) runbooks
  run it; it never fails a commit.

Keep `docs/` Markdown-only except for `docs/validate-doc-lifecycle.py` and
research datasets under `docs/research/<topic>/data/`. Captures, screenshots,
and generated byproducts belong outside `docs/`.
