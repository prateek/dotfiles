---
status: archived
doc_type: plan
created: 2026-10-12
updated: 2026-10-12
closed: 2026-10-12
current_guidance: ../references/dotpkgs.md
related:
  - ../references/dotpkgs.md
  - ../adr/0049-shared-package-operations.md
---

# Dotpkgs command surface repair

Repair the audited inventory, selection, reporting, and command contracts within
the shared package architecture in [ADR 0049](../adr/0049-shared-package-operations.md).
No real package upgrades are part of implementation validation.

Acceptance criteria:

- Explicit unavailable inventories fail in text, JSON, and TSV. Filtered update
  views retain counts and explanations for unresolved packages.
- Inventories distinguish desired missing packages from disabled packages.
  A selected package is isolated from unrelated package probes and validation.
- Write results distinguish applied source edits, completed native steps,
  failed steps, and operations not started. Recovery destinations are visible.
- Xcode validates package IDs and rejects unsupported continuous unpinning.
  Help and option validation agree with provider capabilities.
- Human inventory, status, doctor, capability, and operation output have distinct
  presentations; existing scoped TSV and banner protocols remain compatible.
- Native passthrough preserves streams and exit codes; JSON errors stay structured.
- Regression tests, consumer tests, live read-only checks, and dry runs verify
  the contracts. Update the operator reference and land under saved repo choices.

Implementation completed in the shared helper, with separate modules for
capability contracts, offline readiness checks, and human presentation. Desired
Brew and MAS inventory follows the existing rendered Brewfile policy. Writes
retain source and per-step outcomes, recovery destinations, and a fresh installed
inventory observation. Operator contracts are maintained in the
[package helper reference](../references/dotpkgs.md).

Validation used isolated fixtures for native execution and failure cases:
67 Python checks covering dotpkgs, Brewfile rendering, and agent selection;
19 shell-consumer checks for inventory, fork reconciliation, and banners; and
38 documentation lifecycle tests. Live read-only inventory/status, doctor,
and the bulk-latest dry run also succeeded. No real package operations ran.
