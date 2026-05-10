---
name: ios-project-scaffold
description: "Scaffold a new iOS project with a pinned Xcode toolchain, Tuist manifest, repo-owned worktree execution helper, simprofile-driven simulator policy, Makefile targets for build/test/run/trace/release, Fastlane lanes for TestFlight and the App Store, and GitHub Actions workflows for CI. Also audits existing projects against the same conventions and reports drift with concrete fix commands. Use when the user asks to start or bootstrap an iOS app, set up Tuist and Makefile automation, add worktree-local simulator/build structure, or audit an iOS repo's scaffold and agent-facing build hygiene. Two modes: init for scaffolding, audit for checking drift."
---

# iOS Project Scaffold

Scaffold a new iOS project with one clear default workflow, or audit an existing project against the same conventions.

The generated repo contract is opinionated:

- `make` is the public API for local builds, tests, screenshots, cleanup, and trace collection.
- A repo-owned worktree helper manages simulators, ownership locks, and all mutable state under `build/`.
- `Project.swift` is the source of truth for targets, schemes, and suite metadata tags.
- `TestPlans/<App>.simprofile.toml` owns runtime-class and preferred-device policy only.
- `AGENTS.md` and the worktree runbook tell future agents not to freehand `xcodebuild`, `simctl`, `tuist`, or `fastlane` when the helper already owns that state.

Generated hooks must stay fast. They may format staged files and run lightweight lint, but must never run simulator-based tests, `xcodebuild`, or deep analysis.

## Modes

### `init`

Scaffolds:

- Tool pins: `.xcode-version`, `.tuist-version`, `mise.toml`, `.envrc`
- Tuist source of truth: `Project.swift`, `Tuist/Package.swift`
- Repo contract docs: `AGENTS.md`, `docs/operations/runbooks/worktree-execution.md`, `TestPlans/README.md`
- Runtime policy: `TestPlans/<App>.simprofile.toml`
- Helper-driven automation: `Makefile`, `scripts/<app>_worktree.py`, `scripts/trace_execution.py`
- Fast local hygiene: `.swiftlint.yml`, `.swiftformat`, `.typos.toml`, `.githooks/pre-commit`
- Release plumbing: `fastlane/Fastfile`, `fastlane/Appfile`, `fastlane/.env.example`
- CI workflows: `.github/workflows/ci.yml`, `.github/workflows/beta.yml`, `.github/workflows/security.yml`
- Starter app shell: a minimal SwiftUI app under `<App>/`

Optional:

- `--with-analysis` adds `.periphery.yml`, pins `periphery`, and wires `make analyze`.

Run:

```bash
bash ~/.agents/skills/ios-project-scaffold/scripts/scaffold.sh \
  --target /path/to/new/app \
  --name MyApp \
  --bundle-id com.example.MyApp \
  --team-id ABCD123456
```

### `audit`

Runs the deterministic convention pass from `scripts/audit.sh`, then read the flagged files and apply the judgment rubric below.

Run:

```bash
bash ~/.agents/skills/ios-project-scaffold/scripts/audit.sh --target /path/to/app
bash ~/.agents/skills/ios-project-scaffold/scripts/audit.sh --target /path/to/app --json
```

Exit code is 0 on clean audit, 1 if any check failed.

## Audit rubric

After the script runs, check these judgment calls.

### Repo contract

- Does `AGENTS.md` clearly tell agents that `make` is the public command surface?
- Does the runbook explain ownership, simulator reuse, cleanup, and `build/` artifact layout?
- Does the repo keep all mutable generated state under `build/` rather than `/tmp` or global DerivedData paths?

### Project.swift and Tuist

- Does `Project.swift` define shared schemes and suite topology directly rather than depending on generated scheme edits?
- Do targets carry metadata tags for role, suite kind, runtime class, device support, and data mode?
- Is `Project.swift` the only place encoding target and suite topology?
- Does `Tuist/Package.swift` carry the external package dependencies the manifest expects?

### Worktree helper

- Does the helper infer topology from `tuist dump project` and target metadata instead of handwritten lane maps?
- Does it own one reusable iPhone simulator and one reusable iPad simulator per worktree?
- Does it keep locks under `build/state/` and simulator metadata under `build/simulators/`?
- Does it expose a stable command surface for `doctor-state`, `clean-build`, `clean-simulators`, `reset-simulators`, `release-owner`, and `clean`?

### Makefile

- Do `build`, `run`, `test-*`, `record-snapshots-*`, and screenshot targets go through the helper?
- Does `generate` also go through the helper so ownership and state stay consistent?
- Does the Makefile consume helper-exported environment such as derived-data paths, simulator names, and result-bundle paths?
- Do build and test commands still flow through `xcbeautify`?
- Are grouped targets split by device family so agents can run a single lane intentionally?

### Simprofile

- Does `TestPlans/<App>.simprofile.toml` restrict itself to runtime classes and preferred device identifiers?
- Does it avoid duplicating task names, suite topology, or scheme names?

### Local hygiene

- Is `.githooks/pre-commit` limited to staged-file operations?
- Does it avoid `xcodebuild`, simulator work, and deep analysis?
- Do `setup-tools` and `bootstrap-local` stay local-only rather than mixing CI concerns into the developer loop?

### CI and release

- Does `ci.yml` run through `make` instead of hand-rolled `xcodebuild` commands?
- Are macOS jobs time-bounded with `timeout-minutes`?
- Does `ci.yml` cancel stale runs while `beta.yml` preserves in-flight releases?
- Does the beta/TestFlight workflow use an approval-gated environment?

## References

Load these only when needed:

- [references/tuist.md](./references/tuist.md)
- [references/ci.md](./references/ci.md)
- [references/release.md](./references/release.md)

## Assumptions and requirements

The skill assumes:

- Xcode 26.3 is installed and selected
- `xcodes`, `mise`, `jq`, and `perl` are available
- `make bootstrap-local` is run once after `git init`

The scaffold does not install Xcode itself.

## Relationship to `ios-audit`

This skill checks scaffold and repo-hygiene conventions quickly. Use `ios-audit` for a broader engineering and UX audit.

## What this skill does not do

- It does not create the App Store Connect app record for you.
- It does not create product architecture, feature modules, or backend contracts.
- It does not decide app design or HIG-specific UX choices.
- It does not replace project-specific release, secrets, or API workflows beyond the scaffold baseline.
