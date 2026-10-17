---
status: accepted
doc_type: adr
summary: "Closed plans, research, references, and runbooks leave the tree through an append-only retirement ledger; ADRs stay; the index becomes a router over a generated inventory."
owner: Prateek
created: 2026-10-17
updated: 2026-10-17
related:
  - ../document-lifecycle.md
  - ../research/documentation-maintenance-review.md
  - ../research/skill-pack-doc-lifecycles.md
  - ../retired.md
current_guidance:
  - ../document-lifecycle.md
  - ../runbooks/quarterly-review.md
status_detail: "Policy adopted after the 2026-10-17 documentation review; the first sweep followed in the next change."
---

# Retire closed docs through a ledger, keep ADRs, generate the inventory

## Decision

A document under `docs/` that is not an ADR leaves the tree when it closes.
The retiring change records it in `docs/retired.md`, an append-only ledger
that names the path, the closing status, and where any durable content went.
Git history holds the body. ADRs never leave: once accepted they are locked,
superseded only by a newer ADR, and numbers are never reused.

Plans are the main case. A plan exists only when work spans more than one
landing or must hand off between sessions. It closes in the same change that
lands its last step: durable content moved to a reference, runbook, or ADR,
a ledger row naming the closing status, file deleted. Research names the plan or ADR it
informs and retires once that consumer is settled and cites what it used.
Closed references and runbooks retire the same way. A closed doc never
reopens; revived work is a new document that links the ledger. A plan can be
parked as a `draft` with a `Parked:` detail; nothing retires it without a
decision.

`docs/index.md` becomes a short router over current guidance and open work.
`docs/inventory.md` is generated from frontmatter by `just docs-inventory`
and checked for staleness; every doc carries a required one-line `summary`.
The validator keeps its shape, link, and body-lock checks, drops the status
transition graph, and gains the ledger, inventory, summary, ADR-number, and
supersession-banner rules. `just docs-due` reports what needs a decision; the
landing and quarterly runbooks run it.

## Context

The [documentation maintenance review](../research/documentation-maintenance-review.md)
measured the tree on 2026-10-17:

| Measure | Value |
| --- | ---: |
| Docs under `docs/`, words | 164, 260k |
| Genuine deletions in the tree's history | 3 |
| Open plans whose index row already said implemented | 19 of 24 |
| Post-reorg guidance reads, archived plans vs active plans | 101 vs 64 sessions |
| Reads of a closed doc that never reached its pointer target | 56% |
| Docs never read for guidance | 34 (45k words) |
| Sessions that opened the index first | 7.6% |
| Validator transition-rule rejections, ever | 0 in about 120 eligible runs |

Closed plans were read as live specs more often than live plans, and the
lifecycle's "cannot be deleted" rule guaranteed they would keep being read.
The index's status column had become the changelog, which is why closure
never happened. The [skill-pack survey](../research/skill-pack-doc-lifecycles.md)
found that the three skill packs this repo installs say when to create a doc
and nothing about ending one, and each has open issues from users hitting
exactly that gap.

## Alternatives

- **Keep everything with status metadata.** The practice this replaces. It
  works for multi-contributor governance records such as PEPs and KEPs, where
  the record is the product. Here the measured cost was reads of stale plans
  and 1.35M tokens on one archived plan, with no corresponding benefit.
- **Delete with no ledger.** Chromium, Shape Up, and several agent-first
  repos do this and lean on git. It loses the one thing a reader needs
  without archaeology: that a doc existed and where its content went.
- **Keep work artifacts out of the tree from the start.** The largest camp
  among agent-first practitioners and what the Pocock and pstack packs do.
  Rejected for now because in-tree plans are how sessions hand off here, and
  the retirement rule gives them the exit the out-of-tree approach assumes.

## Choices made along the way

- ADRs of any status cannot be deleted, stricter than "accepted and closed
  ADRs stay". A proposed ADR that is withdrawn closes as `rejected` so its
  number stays taken.
- The ledger has no commit column. The retiring commit is not known when the
  row is written; `git log --diff-filter=D -- docs/<path>` finds it.
- The ledger is a table, so a row has no anchor. A doc that revives retired
  work links the ledger file and names the path in its text.
- A retired path is accepted in a locked doc's links and frontmatter, so
  retiring a plan does not touch the ADRs that cite it. An editable doc
  repoints to the durable home or the ledger. The ledger's own links are not
  checked, since its rows cannot be edited.
- The `doc_type` transition rule stays. It is a shape check, not part of the
  status graph that never fired.
- Naming a research consumer in `related` is reported by `just docs-due`
  rather than enforced.

## Consequences

- The first sweep retires the closed plans, research without a live
  consumer, and closed references and runbooks; the ledger records each one.
- The body lock on closed docs is in practice an ADR rule, since no other
  closed doc stays in the tree.
- Frontmatter on 166 docs gains `summary`; the generated inventory replaces
  the hand-maintained index tables and the missing-index-entry failure class.
- A plan with nothing left to do and no terminal status is now a validator
  warning at landing time rather than a row that quietly says "implemented".
