---
status: accepted
doc_type: adr
created: 2026-09-05
owner: Prateek
related:
  - ../plans/test-suite-rebuild-plan.md
  - ../research/shell-testing-framework-comparison.md
  - 0002-zsh-fresh-shell-validator.md
  - 0005-mise-tool-management.md
status_detail: "Implemented through Bats, native Python, and Node discovery with shared local/CI commands. The complete local macOS lane passed; the execution plan retains the required remote CI gate."
---

# ADR 0022: Bats with repo-owned zsh test support

## Context

The dotfiles tests repeat fixture mechanics and mix behavioral guarantees with
preference snapshots. Local and CI selection are maintained separately. The
repository needs a cheaper way to add useful tests while preserving its real
zsh and macOS behavior.

The [framework comparison](../research/shell-testing-framework-comparison.md)
exercised equivalent Bats, ShellSpec, and ZUnit cases. All caught the injected
defects. Bats fits the owner's syntax preference and has stronger evidence of
ongoing maintenance and downstream adoption. The existing `bats-zsh` extension
does not cover the required PTY lifecycle or exact-output behavior.

## Decision

Use Bats for shell command suites, with small repo-owned support for isolated
zsh scenarios and PTY fixtures. Bats owns test discovery and reporting. Dependent
state observations stay inside the zsh process that performs the operation.
Use file capture where exact bytes matter.

Retain Python for structured-data verification where it fits and keep existing
native runners for other languages. Make composes suite commands. Do not add a
custom universal runner or per-test manifests. Retain comparison findings in the
research report and discard the experimental runners and fixtures. Select tools
through mise under ADR 0005.

Keep the authoritative fresh-shell validator and its single-file implementation
under ADR 0002. Shared support for other test scenarios does not replace its
real PTY correctness checks or its pinned `zsh-bench` performance lane.

Migrate incrementally, preserving named caller-visible guarantees. Independent
expected examples establish transformation and ownership. Config-derived checks
can verify that input is applied but cannot establish ownership by themselves.
Each removed assertion needs a replacement or a reason it protects no distinct
behavior. Test counts and feature counts do not determine coverage quality.

## Alternatives and consequences

ShellSpec's DSL is a poor authoring fit. ZUnit's direct zsh execution comes with
weaker maintenance evidence. TypedDevs bashunit and bash-unit/bash_unit are
credible Bash alternatives, but have not demonstrated an advantage on our cases.
Building support around ordinary zsh scenario scripts keeps that choice revisable.

We will own some fixture and PTY mechanics. Their scope is bounded by real cases,
and their failure behavior must be verified before broad migration. No framework
choice makes unchecked commands or self-comparison assertions useful tests.

The [single refactoring plan](../plans/test-suite-rebuild-plan.md) owns execution
steps, acceptance criteria, and remaining compatibility gates. Revisit this
decision if those gates show that Bats requires substantial custom machinery or
cannot faithfully exercise the required behavior.
