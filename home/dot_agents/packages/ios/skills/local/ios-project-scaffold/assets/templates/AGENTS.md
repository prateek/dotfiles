# AGENTS.md

Start here if you are a coding agent working in this repository.

## Project Overview

__APP_NAME__ is a native iOS app generated from the `ios-project-scaffold` skill. This repo uses Tuist for project generation, a worktree-local execution helper for simulator/build state, and `make` as the public command surface for builds, tests, screenshots, cleanup, and trace collection.

## Quick Reference

### Build and Run

```bash
make build
make build-iphone
make build-ipad
make run-iphone
make run-ipad
make clean
```

### Testing

```bash
make test-unit
make test-unit-iphone
make test-unit-ipad
make test-snapshot
make test-ui
make test-visual
make test-all
make test-matrix
make trace-matrix
make record-snapshots
```

### Simulator and Build State

```bash
make screenshot-iphone
make screenshot-ipad
python3 scripts/__APP_SLUG___worktree.py doctor-state
```

### Project Generation

```bash
make generate
```

Never edit the generated `.xcodeproj` or `.xcworkspace` directly. `Project.swift` is the source of truth for targets, shared schemes, suite metadata, and execution topology. `TestPlans/__APP_NAME__.simprofile.toml` owns runtime-class and preferred-device policy for the worktree helper.

## Common Pitfalls

- Always go through `make` or `scripts/__APP_SLUG___worktree.py` for builds, tests, screenshots, and cleanup.
- `make generate` is the supported refresh path after manifest or package changes. It runs `tuist install && tuist generate`.
- Project topology comes from Tuist metadata tags in `Project.swift`, not handwritten lane maps in shell scripts.
- The `.simprofile` should stay limited to runtime-class and device-preference policy. Do not duplicate task names or scheme topology there.
- Each worktree owns one reusable iPhone simulator and one reusable iPad simulator. The helper creates them on demand and stores metadata under `build/simulators/`.
- All repo-generated mutable state lives under `build/`. Derived data, result bundles, screenshots, archives, exports, trace output, and lock state are worktree-local.
- `make clean` is a full worktree reset. Use `make clean-build` or `make clean-simulators` if you want a narrower cleanup.

## Read Order

1. `Project.swift`
2. `Tuist/Package.swift`
3. `Makefile`
4. `TestPlans/README.md`
5. `docs/operations/runbooks/worktree-execution.md`

## Rules

- Do not invent product behavior beyond documented capability.
- Do not hardcode credentials. Use environment variables loaded from `.env` or CI secrets.
- Keep `Project.swift` as the source of truth for suite structure and execution metadata.
- Keep repo-generated mutable state under `build/`.
