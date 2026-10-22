---
status: draft
doc_type: plan
summary: "Proposed repo layout by lifecycle: installed programs in src/, checkout-run machinery in scripts/, tests and runners in tests/, token-spending evaluations in evals/, sequenced as small reference-sized moves"
owner: Prateek
created: 2026-10-22
updated: 2026-10-22
related:
  - ../adr/0063-authored-programs-live-in-src.md
  - ../adr/0060-one-root-marketplace-manifest.md
  - agent-marketplace-layout-plan.md
---

# Repo layout

[ADR 0063](../adr/0063-authored-programs-live-in-src.md) settles where authored
programs live. This plan proposes the rest of the layout and the order of the
moves. Everything below except the ADR's decision is a proposal awaiting
Prateek's review.

## Problem

A path should tell a reader what owns the code and when it runs. Today:

- User-facing executables live in seven places: `bin/`, `home/bin/`,
  `home/dot_local/bin/`, `home/dot_agents/bin/`, `home/dot_local/libexec/`,
  `home/dot_config/dotfiles/shell-banner/bin/`, and `scripts/c`.
- `scripts/` (99 files) mixes apply-time code, operator audits (one of which,
  `scripts/audit/orca-settings.sh`, also applies), test runners, evaluations,
  and unreferenced one-offs.
- Apply-time plugin code lives in a repo-local skill,
  `.agents/skills/agent-skill-management/scripts/`, called from
  `home/.chezmoiscripts/run_onchange_after_{35,36,39}-*.sh.tmpl` and
  `home/.chezmoitemplates/work-overlay.tmpl`.
- Tests have no single placement rule: projects co-locate theirs, everything in
  `scripts/` is tested in `tests/`, runners live in `scripts/tests/`, and the
  `justfile` and CI shellcheck list some paths by hand.

## Proposed layout

```text
home/              chezmoi source state; thin entrypoints and build scripts for src/
agent-marketplace/ publishing project (unchanged)
src/<name>/        authored installed programs (ADR 0063)
scripts/<domain>/  checkout-run machinery: apply-time hooks, reconcilers, audits; tested in tests/
tests/             repo-behaviour tests and their runners (tests/runners/)
evals/             everything that spends model tokens
docs/              lifecycle-tracked docs
.agents/           repo-local skills: SKILL.md and references only
```

| Today | Proposed |
| --- | --- |
| `home/dot_local/lib/dotpkgs/` + `scripts/packages/dotpkgs/` | `src/dotpkgs/` |
| `scripts/macos/tcc-onboarding/` | `src/permissions/` |
| `home/.chezmoiassets/{mic,keymap-overlay}.swift` | `src/mic/`, `src/keymap-overlay/` |
| `scripts/agent-sessions/sync-app/` | `src/session-sync/` |
| `.agents/skills/agent-skill-management/scripts/` | `scripts/agents/` |
| `scripts/tests/` | `tests/runners/` |
| eval scripts in `scripts/` and root `evals/search-index/` | `evals/` |

The Raycast extension stays in `home/`, where Raycast reads it and
`run_after_21` builds it in place.

## Sequence

Each step lands alone and passes `just test-ci`, `chezmoi apply --dry-run
--verbose --exclude=scripts` for each machine type, and
`DOCS_LIFECYCLE_BASE=origin/master just test-docs-lifecycle`. Moved Markdown
stays byte-identical so locked documents see exact renames.

1. Record the program rule (ADR 0063), place `src/orcactl/`, delete the
   unreferenced `scripts/` one-offs, and fold `CONTEXT.md` into `GLOSSARY.md`.
2. Move the skill's apply-time code to `scripts/agents/`. Precondition: the
   console lanes run green first. Repoint chezmoi scripts 35, 36, and 39,
   `work-overlay.tmpl`, the skill's references, the agent tests, and any work
   overlay callers.
3. Consolidate dotpkgs into `src/dotpkgs/`; repoint its tests, reference doc,
   and marketplace callers; verify with a real `dotpkgs` run.
4. Move the Swift programs into `src/`; repoint the `include` paths in
   `run_onchange_after_{38,40,44}` and the `just test-tcc-*` recipes; verify
   that `chezmoi diff` shows only script-hash changes, then apply once.
5. Move test runners and evaluations into `tests/runners/` and `evals/`;
   repoint the `justfile`, `mise.toml`, Bats selection tests, ADR 0026's
   current-guidance links, the Orca validation runbook, and CI shellcheck.
6. Discover tests by glob (`src/*/`, `home/**/bin`) instead of hand-listed paths
   in the `justfile` and CI.

## Open decisions

- Installed programs run from the checkout through links (recommended, as
  `home/bin/` does) or are copied by chezmoi.
- Whether built programs get a catalog driving one generic build hook, in the
  spirit of `marketplace.toml`. Recommended after step 4, once the build paths
  can be compared.

## Progress

- 2026-10-22: Prateek chose `src/` for authored programs (ADR 0063) and approved
  step 1.
