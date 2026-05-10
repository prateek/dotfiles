---
status: active
doc_type: plan
owner: Prateek
related:
  - ../adr/0002-zsh-fresh-shell-validator.md
---

# zsh-fresh-shell-validator — plan

## Problem

The repo had two disconnected shell checks:

- a live current-session validator that only proved some hooks and widgets existed
- an experimental startup benchmark script that compared multiple prompt and plugin-manager lanes

Neither was the authoritative answer to “if Prateek opens a fresh shell, does it behave correctly, and how fast is it?”

## Goals

- One small authoritative harness for fresh-shell correctness and startup performance
- Real macOS PTY login-shell coverage, not `zsh -ic`
- `zsh-bench` as the only benchmark source of truth
- Minimal repo sprawl: one main script, one regression wrapper, light doc updates
- Keep a live-shell doctor mode available inside the same harness

## Non-goals

- Not a generic test framework or spec DSL
- Not a Linux/container truth harness
- Not a replacement for focused helper-specific tests such as `ghc` regressions
- Not a reimplementation of the older multi-lane prompt experiments

## Architecture

Decision details live in [../adr/0002-zsh-fresh-shell-validator.md](../adr/0002-zsh-fresh-shell-validator.md).

Implementation shape:

- Main harness: `scripts/audit/zsh-fresh-shells.zsh`
- Modes:
  - `verify` — fresh-shell correctness on a synthetic home via `zsh/zpty`
  - `bench` — fresh-shell startup benchmark via pinned external `zsh-bench`
  - `diagnose` — fresh-shell diagnostic dump
  - `doctor` — optional current-shell helper when sourced interactively
  - `selftest` — end-to-end regression coverage for the harness itself
- Make targets:
  - `test-zsh-fresh-shells`
  - `verify-zsh-fresh-shells`
  - `bench-zsh-startup`

The harness keeps its contracts inline as zsh data and functions. It does not add `subjects/`, `scenarios/`, or `suites/` trees.

## Fresh-shell contracts

`verify` checks:

- first prompt paints and startup output stays clean
- core env and option contracts from `zprofile`, `zshrc`, and `history.zsh`
- key bindings and widget ownership after deferred startup settles
- `direnv` enter/leave behavior
- `zoxide` first-use jump behavior
- safe helper behavior for `ghc` and `git-spice`

`bench` checks:

- pinned `zsh-bench` checkout exists
- checkout commit matches the pinned commit
- median values for:
  - `first_prompt_lag_ms`
  - `first_command_lag_ms`
  - `command_lag_ms`
  - `input_lag_ms`

## Implementation phases

### Phase 1 — harness
- Add the single-file zsh harness with `verify`, `bench`, `diagnose`, and `doctor`
- Materialize a synthetic home at runtime
- Use `zsh/zpty` to drive `/bin/zsh -il`
- Pin external `zsh-bench` metadata in the script and fail closed when missing or mismatched

### Phase 2 — repo wiring
- Add an in-harness selftest mode
- Point `bench-zsh-startup` at the authoritative harness
- Remove the separate current-session validator and focused keybinding wrapper
- Update `AGENTS.md` and `tests/README.md`

### Phase 3 — startup drift
- Fix shell drift the harness exposes when it is cheap and clearly in scope
- Current examples:
  - keep `~/bin` first even after deferred plugin path mutations
  - allow synthetic login-shell tests to skip `launchctl` mutation

## Success criteria

- `make test-zsh-fresh-shells` passes on Prateek’s host
- `make verify-zsh-fresh-shells` gives a stable fresh-shell correctness answer
- `make bench-zsh-startup` uses only `zsh-bench` and records a pinned dependency
- The harness exposes real startup drift instead of checking only internal hook names

## References

- ADR: [../adr/0002-zsh-fresh-shell-validator.md](../adr/0002-zsh-fresh-shell-validator.md)
- Benchmark guidance skill: `/Users/prateek/dotfiles/skills/benchmark-zsh-startup/SKILL.md`
