---
status: accepted
doc_type: plan
owner: Prateek
created: 2026-09-07
updated: 2026-09-07
related:
  - ../adr/0026-just-task-runner.md
  - ../adr/0022-bats-and-zsh-test-support.md
  - test-suite-rebuild-plan.md
  - ../../tests/README.md
status_detail: "Executed in one change: both justfiles, the runner and plist changes they depend on, and every consumer."
---

# Replace both Makefiles with justfiles and delete the per-file test targets

Rationale and alternatives live in [ADR 0026](../adr/0026-just-task-runner.md).
This plan records what changed and how it was validated.

## Scope

The root `Makefile` (434 lines, 97 rules) and `agent-marketplace/Makefile` (21
lines) are replaced by `justfile` (133 lines, 21 recipes) and
`agent-marketplace/justfile` (46 lines, 8 recipes).

`agent-marketplace/packages/ios/skills/ios-project-scaffold/assets/templates/Makefile`
is out of scope. It is payload shipped into scaffolded iOS projects, not a build
file for this repo.

## Prerequisites that had to land first

Three changes were required before the selectors could be deleted, because
without them the runners could not express what the selectors did.

**Per-app plist test methods.** `AppPlistTests` looped over all twelve apps
inside one `test_modifiers` method, so `-k moom` matched nothing. A metaclass now
generates `test_<app>` per scenario. Failures name the app instead of burying it
in a subtest, and `tests/config_merge/run.py` is deleted rather than aliased.

**Multi-root Python discovery.** `scripts/tests/python` took one `-s` root, so
spanning roots meant one process per root and an empty-selection failure from
every root that did not match the filter. It now takes roots positionally,
discovers them in one process under one guard, and accepts repeatable `-p` and
`-k`. Overlapping globs are de-duplicated by test id. Roots stay an explicit
allowlist: `agent-marketplace/` holds roughly fifteen vendored third-party test
files that must never be discovered.

**Bats library preflight.** `build/` is git-ignored, so a fresh worktree had Bats
but no assertion libraries, and the failure surfaced as an opaque
`bats_load_safe` error once per file. `scripts/tests/shell` now checks for them
and names the recovery recipe.

## Consumers updated

| Surface | Change |
| --- | --- |
| `.pre-commit-config.yaml` | Two hook entries call `just`. |
| `.github/workflows/install-smoke.yml` | `mise install just`, then `mise exec -- just test-tools` and `just test-ci`. |
| `skill_console/decisions.py` | `STAGED_MAKE_TARGETS` becomes `STAGED_CHECKS`, holding full argv. |
| `agent_skill_lib.py` | New `marketplace_build_command()` builds argv for a project copy; six test call sites use it. |
| `agent-marketplace/tests/test_marketplace.py` | `make()` becomes `recipe()`, using `just --set`; `PACKAGE=x` becomes a positional argument. |
| `tests/python/agents/test_packages.py` | `just --set` replaces prepending overrides to a copied Makefile. |
| `home/dot_hammerspoon/init.fnl` | The hyper-r rebuild hotkey calls `just hammerspoon`. |
| Repo-local skills, `AGENTS.md`, `home/dot_agents/docs/`, current references and runbooks | Commands rewritten to the recipe or runner selector that replaces them. |
| `tests/README.md` | The 45-line target roster is replaced by the selector forms that generate it. |

Historical `docs/plans/`, `docs/adr/`, `docs/research/`, and archived runbooks
keep their `make` references: they describe what was true when written.

## Validation

- `agent-marketplace` suite: 21 tests, pass, driven through the new `recipe()`
  helper and `just --set`.
- Plist parametrization: 12 per-app ids, pass.
- Selection matrix on the new runner: single `-p`, repeated `-p`, overlapping
  `-p` (de-duplicated), `-k`, repeated `-k`, and both no-match forms failing.
- `just test-ci` end to end, plus `just --list` on both files.

## Follow-ups

`just` is pinned in the repo's `mise.toml`. If it should also be present on
machines that never enter this checkout, add it to the machine-wide mise config
under `home/dot_config/mise/`.
