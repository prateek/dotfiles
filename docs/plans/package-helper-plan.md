---
status: archived
doc_type: plan
summary: "Archived implementation plan"
closed: 2026-10-12
current_guidance: ../references/dotpkgs.md
created: 2026-10-12
updated: 2026-10-12
related:
  - ../adr/0049-shared-package-operations.md
  - ../references/dotpkgs.md
---

# Package helper

Build `dotpkgs`, installed by chezmoi in `~/.local/bin`, following the
[CLI creator contract](https://github.com/openai/skills/tree/main/skills/.curated/cli-creator).
It owns package status and operation planning; the shell banner consumes its
results instead of implementing separate manager checks.

Scope includes Homebrew, mise, native Claude/Codex/Cursor installers, gh
extensions, zinit, agent marketplace, MAS, Setapp, Xcode, Raycast extensions,
chezmoi Git externals, and local Swift builds. Expose install/remove/update and
pin changes where the underlying owner supports them. Unsupported operations
must be explicit, never successful no-ops. Bulk latest must report every
selected provider, including failures and manual steps.

Status separates installed, requested, latest allowed, and latest upstream.
Unknown upstream state is not current. Ordinary updates preserve pins; bulk
latest explicitly changes them. Source edits must target owning declarations,
not generated config. Dry-run plans show commands and file changes before any
mutation; no package updates are executed while developing this helper.

Acceptance: command works outside the checkout, JSON success/errors are stable,
all providers are discoverable, meaningful fixture tests cover status and write
planning, and existing banner isolation/cache tests remain valid. Validate
scoped chezmoi installation and live read-only checks separately from fixture
coverage. No commit or landing is requested.


## Completion evidence

Implemented all fourteen provider inventories, explicit operation boundaries,
shared banner/audit consumers, durable supported pins, and bulk latest plans.
CLI help, manager discovery, and individual write steps describe sudo needs.
Fixture checks passed: 18 helper tests, 16 package/catalog tests, 18 banner/audit
shell tests, and 8 native installation hook tests. Live read-only inventories
and an all-provider latest dry run exercised native parsers. Actual package
upgrades were not executed; manual and unsupported operations remain explicit.
Current usage and scoped installation are in the reference above.
