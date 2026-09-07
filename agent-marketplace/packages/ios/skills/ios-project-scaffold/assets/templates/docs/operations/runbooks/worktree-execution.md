# Worktree Execution Runbook

This repo uses a worktree-local execution helper for Tuist, Xcode, Fastlane, and simulator state.

## Core Rules

- Go through `make` for builds, tests, screenshots, cleanup, and trace collection.
- All repo-generated mutable state lives under `build/`.
- Each worktree owns one reusable iPhone simulator and one reusable iPad simulator.
- The helper enforces one live worktree owner and one live Xcode, Tuist, or Fastlane operation at a time.

## Command Surface

Build and run:

```bash
make build
make build-iphone
make build-ipad
make run-iphone
make run-ipad
make screenshot-iphone
make screenshot-ipad
```

Tests:

```bash
make test-unit-iphone
make test-unit-ipad
make test-unit
make test-snapshot-iphone
make test-snapshot-ipad
make test-snapshot
make record-snapshots-iphone
make record-snapshots-ipad
make record-snapshots
make test-ui-iphone
make test-ui-ipad
make test-ui
make test-visual-iphone
make test-visual-ipad
make test-visual
make test-all
make test-matrix
make trace-matrix
```

State and cleanup:

```bash
make doctor-state
make release-owner
make clean-build
make clean-simulators
make reset-simulators
make reap-orphan-simulators
make clean
```

## Artifact Layout

The helper uses stable repo-local paths:

- `build/derived/iphone`
- `build/derived/ipad`
- `build/derived/archive`
- `build/results/*.xcresult`
- `build/screenshots/`
- `build/archives/`
- `build/exports/`
- `build/state/`
- `build/simulators/`
- `build/traces/`

## Ownership and Locks

- The first live shell or agent process that enters the worktree through the helper becomes the owner.
- If the owner process dies, the next helper invocation reclaims the owner lock lazily.
- A separate build lock protects Xcode, Tuist, and Fastlane operations so overlapping operations cannot share the same worktree state.
- Use `make doctor-state` to inspect the current owner, build lock, and simulator metadata.

## Simulator Policy

- Simulators are named deterministically from the repo name, worktree path hash, and device family.
- The helper reuses the existing worktree simulators when they match the configured device type and runtime.
- If a simulator is missing, broken, or mismatched, the helper recreates it.
- Use `make reset-simulators` to rebuild the worktree-owned simulators.
- Use `make reap-orphan-simulators` to delete abandoned repo-owned simulators whose originating worktree no longer exists.

## Tuist Conventions and Profiles

- `Project.swift` is the source of truth for targets, schemes, suite topology, and metadata tags.
- The helper reads `tuist dump project` and infers execution lanes from target naming plus those metadata tags.
- Cross-tool simulator runtime policy lives in `TestPlans/__APP_NAME__.simprofile.toml`.
- The `.simprofile` should stay limited to runtime classes and device preferences. It should not duplicate task names or scheme topology.
- `make generate` is the supported regeneration path after manifest changes.

## Cleanup Semantics

- `make clean-build` removes repo-owned derived data, result bundles, screenshots, archives, exports, logs, and traces.
- `make clean-simulators` removes only the worktree-owned simulators.
- `make clean` is the full reset for the worktree. It removes repo-owned build outputs, lock state, and worktree-owned simulators.

## Trace Semantics

- `make trace-matrix` runs the clean waterfall sequence and writes telemetry under `build/traces/<timestamp>/`.
- The primary outputs are `summary.json`, `summary.md`, and `logs/`.
- The trace runner exists to analyze build and test bottlenecks without mixing trace state into the day-to-day dev loop.

## What Not To Do

- Do not rely on `booted` simulator selection.
- Do not write new workflows that glob `~/Library/Developer/Xcode/DerivedData`.
- Do not write screenshots or test outputs to `/tmp` when the repo-owned path is available.
- Do not freehand `xcodebuild`, `xcrun simctl`, `tuist`, or `fastlane` when you expect the helper to manage ownership, artifact paths, or simulators for you.
