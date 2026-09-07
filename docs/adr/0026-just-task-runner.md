---
status: accepted
doc_type: adr
owner: Prateek
created: 2026-09-07
updated: 2026-09-07
related:
  - ../plans/justfile-migration-plan.md
  - 0022-bats-and-zsh-test-support.md
  - 0023-apm-agent-marketplace-packaging.md
  - ../../tests/README.md
---

# ADR 0026: Run repo tasks through just, and select tests through the runners

Replace both `Makefile`s with `justfile`s, and delete every per-file test target
in favour of arguments passed to the three test runners.

## Context

The root `Makefile` had grown to 434 lines and 97 rules. Sixty-four of those
rules were one-line selectors: 32 forwarded a single `.bats` path to
`test-shell`, 23 forwarded a single filename to Python discovery, and 9 forwarded
an app name to a bespoke `tests/config_merge/run.py`. Every new test file
required a new rule plus an entry on a 1322-character `.PHONY` line, which two
rules had already been omitted from.

[ADR 0022](0022-bats-and-zsh-test-support.md) established runners that discover
their own cases, and the [test suite rebuild plan](../plans/test-suite-rebuild-plan.md)
specified a four-target contract whose completion criterion was that "adding an
eligible case requires no per-file target or manifest". The runners delivered
that; the Makefile was never trimmed to match, so the roster kept growing and
`tests/README.md` carried a hand-synced copy of it.

Selection was the only thing the selectors bought, and it was available directly:
Bats already takes paths and `--filter`, and unittest already takes `-p` and
`-k`. The one exception was the plist suite, where all twelve apps ran inside a
single test method, so `-k` could not name one — which is why `run.py` existed.

## Decision

Task running moves to `just`, pinned at 1.58.0 in `mise.toml`:

- The root `justfile` holds 21 recipes. Each one encodes an environment, an
  ordering boundary, or an external contract; none exists only to pass an
  argument.
- `agent-marketplace/` keeps its own runner boundary per
  [ADR 0023](0023-apm-agent-marketplace-packaging.md), now as a `justfile`.
- `test-shell`, `test-python`, and `test-node` are variadic. Their arguments go
  straight to the runners, so focusing a run needs no recipe.
- `AppPlistTests` generates one test method per app, so `-k moom` selects a
  scenario through ordinary discovery. `tests/config_merge/run.py` is deleted.
- `scripts/tests/python` takes several roots in one invocation. The roots stay
  an explicit allowlist because `agent-marketplace/` also holds vendored
  third-party suites that must not be discovered.

## Consequences

`just --list` is now the recipe index, with parameters and defaults shown, which
replaces 93 `##` comments that fed nothing. `.PHONY` and its omission bug stop
existing. Recipe parameters replace `MODE=`/`VERB=`/`BATS_PATH=` variable
passing, so the seven Tart rules become `test-install-tart lane` plus
`warm-tart verb`, and three zsh rules become `zsh-fresh-shells mode`.

`just` becomes a build dependency where none existed; CI installs it through
mise before the first recipe. Test harnesses that drove make with `VAR=value`
overrides now use `just --set`, which removed a Makefile-copying hack in
`tests/python/agents/test_packages.py`.

Hammerspoon's Fennel compile loses make's timestamp check and recompiles on
every invocation. It is one file and the cost is immaterial.

## Alternatives

**Trim the Makefile without switching runners.** Reaches ~126 lines and keeps
most of the value with no new dependency, but leaves selection expressed as
`PYTHON_ARGS='-k moom'` and keeps `.PHONY` upkeep. Rejected because every
reference was being rewritten anyway, so doing it twice was the only extra cost
of switching.

**Move tasks into `mise.toml`.** Rejected: mise owns tool provisioning, and
relocating orchestration into it splits the command surface without deleting any
policy.
