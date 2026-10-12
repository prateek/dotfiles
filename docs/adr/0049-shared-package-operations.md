---
status: accepted
doc_type: adr
created: 2026-10-12
updated: 2026-10-12
related:
  - ../plans/package-helper-plan.md
  - ../references/dotpkgs.md
  - ../plans/dotpkgs-surface-plan.md
---

# Shared package status and operations

The shell banner and package audits separately queried package managers. They
could disagree about scope, pinned versions, and the meaning of outdated.
The [package helper plan](../plans/package-helper-plan.md) adds an interactive
management command covering the installation paths in this repository.

Use `dotpkgs` as the shared process boundary for inventory, version comparison,
and operation planning. Keep presentation/cache scheduling in the banner and
specialized usage/dependency analysis in the audits. Expose stable JSON and a
small TSV projection for shell consumers. Manager-specific adapters preserve
the owner's install/update semantics and declare unsupported operations.

Ship Python modules and a uv script entrypoint directly through chezmoi.
This follows existing Python/subprocess maintenance tooling and avoids adding
a compiled-artifact distribution lane. The runtime dependency pins also live
in a small locked tooling project for tests. The first call needs a provisioned
uv environment; cached shell rendering never starts that environment inline.

Source-changing operations edit owning declarations. Native state such as
Homebrew holds remains native. Standard updates preserve pins; an explicit
latest operation may change them. Planning is read-only, shared edits merge,
and failed planning prevents execution. Runtime failures stop execution while
retaining completed effects for inspection. Manager support does not imply
that every app has an unattended updater or version-pin API.

See the [operator reference](../references/dotpkgs.md) for command contracts,
provider limits, installation, and validation.
