---
status: accepted
doc_type: adr
summary: "Authored programs installed onto PATH live in src/<name>/, each with its own build manifest and tests; chezmoi builds or links them. orcactl is the first."
owner: Prateek
created: 2026-10-22
updated: 2026-10-22
related:
  - 0060-one-root-marketplace-manifest.md
  - ../plans/repo-layout-plan.md
  - ../plans/orcactl-plan.md
current_guidance: ../references/chezmoi-architecture.md#source-layout
---

# Authored programs live in `src/<name>/`

## Context

Programs this repo writes and installs onto `PATH` have no shared home. Swift
CLIs sit in `home/.chezmoiassets/`, the permission-onboarding package and the
session-sync app sit under `scripts/`, dotpkgs is split between
`home/dot_local/lib/dotpkgs/` and `scripts/packages/dotpkgs/`, and the new Go
CLI needed a place. A reader cannot tell from a path whether code is an
installed program, apply-time machinery, a test, or an evaluation.

`agent-marketplace/` already shows the shape that works: a self-contained
project with its own manifest and tests next to the code they test
(ADR 0060).

## Decision

An authored program installed onto `PATH` lives in `src/<name>/`. Each one:

- carries its own build manifest (`go.mod`, `Package.swift`, `pyproject.toml`,
  or `package.json`);
- keeps its tests inside its directory, run through a root `justfile` recipe;
- is built or linked by chezmoi from `home/`, which keeps only the thin
  entrypoint or the build script.

`src/orcactl/` is the first. Existing programs move in as the
[layout plan](../plans/repo-layout-plan.md) sequences them. `agent-marketplace/`
stays a top-level publishing project.

## Alternatives

- **`tools/`.** Reads as "utilities"; `src/` matches the marketplace's
  authored-source directory.
- **One top-level directory per program**, as `orcactl/` started. Five or more
  siblings would bury `home/` at the root.
- **Keep programs where their build mechanism lives** (`.chezmoiassets/`,
  `scripts/`). That is today's ambiguity.

## Consequences

- New programs start in `src/<name>/`; there is one answer to "where does this
  go".
- Moving the existing programs costs a reference sweep per move, which the
  layout plan sizes step by step.
- `src/` names authored programs only. Hand-written config stays in `home/` and
  checkout-run machinery in `scripts/`.
