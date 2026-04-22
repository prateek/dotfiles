# ADR 0002 — Fresh-shell validator architecture

- Status: Accepted
- Date: 2026-04-17
- Deciders: Prateek
- Related: `/Users/prateek/dotfiles/dev/docs/zsh-fresh-shell-validator-plan.md`

## Context

The dotfiles repo needed one trustworthy answer for shell behavior and startup performance.

The existing surfaces were split:

- `validate-current-zsh-session.zsh` checked a live shell, but mostly by looking for internal functions, hook names, and bindings
- `bench-zsh-startup.zsh` was an experiment harness for comparing prompt and plugin-manager lanes, not an authoritative benchmark gate

That left three problems:

- no fresh-shell correctness gate
- no single startup benchmark of record
- too much harness sprawl relative to the size of the repo

## Options considered

### Option A — Multi-directory harness with external executor

Use a host-side framework with separate subjects, scenarios, suites, baselines, and an executor such as `tui-use` or Python PTY orchestration.

- **Pros:** Most extensible. Easy to add profiles and richer reporting.
- **Cons:** Too much repo sprawl for dotfiles. Adds a second framework to maintain for a shell problem that zsh can already drive.

### Option B — Container or VM first

Make OrbStack or Tart the primary test substrate.

- **Pros:** Better isolation. Easier to reason about side effects.
- **Cons:** Linux containers are the wrong truth surface for this macOS shell. Tart is better, but too heavy for v1. Both push complexity ahead of correctness.

### Option C — Single-file zsh harness on the macOS host (chosen)

Use one zsh script as the harness, inline the contracts as zsh data and functions, drive `/bin/zsh -il` with `zsh/zpty`, and use external pinned `zsh-bench` for startup performance.

- **Pros:** Small, local, and easy to keep in sync. Uses the real host shell path. Keeps the truth surface honest. No extra runtime beyond zsh itself.
- **Cons:** Less extensible than a separate framework. Some output parsing is rougher than a richer harness would be.

## Decision

Choose Option C.

Specific decisions:

- Fresh-shell correctness truth is the macOS host, driven through a real PTY login shell
- Startup performance truth is `zsh-bench` only
- The harness stays in one file: `scripts/audit/zsh-fresh-shells.zsh`
- Live-shell doctor/debug support stays inside the same harness as `doctor`, not as a separate validator
- `zsh-bench` is required and pinned, but not vendored

## Consequences

### Positive

- The repo now has one authoritative fresh-shell correctness path and one authoritative startup benchmark path.
- The implementation stays small enough to understand in one read.
- The harness can expose real shell drift, not just missing hook names.
- Startup regressions stay tied to the same shell shape users actually run.
- End-to-end regression coverage stays in the same harness via `selftest`, not in a second wrapper file.

### Negative

- The host is still the truth surface, so v1 is less isolated than a VM-based design.
- The single-file script trades extensibility for simplicity.
- Benchmark baselines are local to this harness and host shape, not a portable cross-machine contract.

### Neutral

- The harness still uses a synthetic home, so it intentionally measures a colder shell than Prateek’s long-lived interactive session.
- The repo keeps one validator surface for truth, plus one older experiment harness for multi-lane comparison.

## Revisit criteria

Re-open this ADR if any of these happen:

- the single-file zsh harness becomes hard to extend or debug
- host-side testing proves too stateful or flaky and Tart becomes worth the extra cost
- the repo genuinely needs multi-profile execution beyond one small script
- `zsh-bench` changes enough upstream that the pinned external dependency model becomes brittle
