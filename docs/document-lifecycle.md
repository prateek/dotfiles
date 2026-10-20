---
status: current
doc_type: convention
summary: "Frontmatter contract, statuses, retirement rule, ledger, inventory, and validator rules for every Markdown document under docs/."
created: 2026-05-10
updated: 2026-10-18
related:
  - adr/0052-retire-closed-docs-through-a-ledger.md
  - retired.md
  - inventory.md
  - runbooks/quarterly-review.md
---

# Document Lifecycle

This repo adopts the [document-lifecycle contract](../agent-marketplace/src/core/skills/document-lifecycle/references/contract.md).
Use the [skill workflow](../agent-marketplace/src/core/skills/document-lifecycle/SKILL.md)
when creating or updating documented work. Those files own the shared policy;
this page owns dotfiles paths, commands, and exceptions.

## Source and scope

The complete skill lives at
`agent-marketplace/src/core/skills/document-lifecycle/`. This repo authors
it, so work here uses the checkout's source for both policy and tooling, and
changes are validated with the version being written. There is no second copy
to synchronize. Installed plugins are discovery surfaces; this checkout's source
is authoritative for work here. Other repos follow the skill's
[adoption guide](../agent-marketplace/src/core/skills/document-lifecycle/references/adoption.md):
they use the environment's copy first and otherwise install the latest fallback.

The contract covers Markdown under `docs/`. The [index](index.md) routes to
current guidance, the [inventory](inventory.md) is generated, and the
[ledger](retired.md) records retirements. Terms live in the
[glossary](../GLOSSARY.md). [ADR 0052](adr/0052-retire-closed-docs-through-a-ledger.md)
records the adoption decision.

## Retiring a document

Follow the skill's [retirement workflow](../agent-marketplace/src/core/skills/document-lifecycle/SKILL.md#retire-in-one-change)
and [ledger contract](../agent-marketplace/src/core/skills/document-lifecycle/references/contract.md#navigation-and-retirement).
Regenerate with `just docs-inventory` and validate in the retiring change.

## Validation

`docs/validate-doc-lifecycle.py` is a thin adapter calling the skill's validator.
It supplies this repository's root, inventory command, and legacy-path checks.
Shared validator changes belong in the skill, not the adapter.

- `just test-docs-lifecycle` runs the fixtures and checks the checkout against
  `DOCS_LIFECYCLE_BASE` (default `HEAD`). Set
  `DOCS_LIFECYCLE_BASE=origin/master` for the whole branch.
- `just check-docs-lifecycle` checks only the checkout; pre-commit and the CI
  static lane run this check.
- `just docs-inventory` regenerates the inventory.
- `just docs-due` produces the advisory decision report. The landing and
  [quarterly review](runbooks/quarterly-review.md) runbooks invoke it.

## Local exceptions

The adapter rejects the retired legacy docs directory and stale references to
it. `docs/validate-doc-lifecycle.py` is allowed inside the Markdown documentation
tree for command compatibility. Research datasets follow the shared contract.
Research needing a consumer decision goes to Prateek at the quarterly review.
