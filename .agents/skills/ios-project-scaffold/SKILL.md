---
name: ios-project-scaffold
description: Scaffold a new iOS project with a pinned Xcode toolchain, Tuist manifest, fast local hygiene defaults, Makefile targets for build/test/run/audit/release, Fastlane lanes for TestFlight and the App Store, and GitHub Actions workflows for CI. Also audits existing projects against the same conventions and reports drift with concrete fix commands. Use when the user asks to "start a new iOS project", "bootstrap an iOS app", "scaffold an iOS app", "set up Tuist for a new project", "add TestFlight to my iOS project", "add Fastlane", "audit my iOS project setup", "check my iOS project against conventions", "is this iOS project set up right", or "fix iOS project hygiene". Two modes — init for scaffolding a new project, audit for checking an existing one.
---

# iOS Project Scaffold

Scaffold a new iOS project with one clear default workflow, or audit an existing project against the same conventions.

Default local operations must stay fast. Generated hooks may only run staged-file checks and must never invoke `xcodebuild`, simulator-based tests, or deep static analysis.

## Modes

### `init` — scaffold a new project

Drops these into a target directory:

- **Pinning files**: `.xcode-version`, `.ios-runtime`, `.tuist-version`, `mise.toml`
- **Project manifest**: `Project.swift` (Tuist 4.x) with a test-action environment-variables block that survives `tuist generate`
- **Fast local hygiene**: `.swiftlint.yml`, `.swiftformat`, `.typos.toml`, `.githooks/pre-commit`
- **Makefile**: canonical targets for `setup-tools`, `bootstrap-local`, `format`, `lint`, `generate`, `build`, `run`, `test`, `test-unit`, `test-ui`, `beta`, `release`, `metadata`, `hooks-install`, `boot-lease`, `release-lease`, `kill-dev-processes`, `clean-dev-artifacts`, `check-xcode`
- **Gitignore**: Tuist-aware entries so the generated `*.xcworkspace` / `*.xcodeproj` tree never enters git
- **Fastlane**: `Fastfile` with `asc_auth`, `beta` (TestFlight), `release` (App Store), `metadata` lanes using ASC API key auth; `Appfile`; `.env.example`
- **GitHub Actions**: `ci.yml` (lint + unit/UI tests), `security.yml` (GitHub Actions security lint), and `testflight.yml` (tag-gated TestFlight upload with reviewer environment)
- **Bootstrap README**: `README.bootstrap.md` documenting the one-time manual steps (ASC app record, ASC API key, CI secrets)

Optional:

- `--with-analysis` adds `.periphery.yml`, pins `periphery` in `mise.toml`, and adds `make analyze` for deeper static analysis.

Run:

```bash
bash ~/.agents/skills/ios-project-scaffold/scripts/scaffold.sh \
  --target /path/to/new/app \
  --name MyApp \
  --bundle-id com.example.MyApp \
  --team-id ABCD123456
```

Strict analysis mode:

```bash
bash ~/.agents/skills/ios-project-scaffold/scripts/scaffold.sh \
  --target /path/to/new/app \
  --name MyApp \
  --bundle-id com.example.MyApp \
  --team-id ABCD123456 \
  --with-analysis
```

### `audit` — check an existing project

Walks the convention set against a target directory and reports pass/fail per check. Non-destructive. Uses a hybrid script + LLM rubric:

1. **Deterministic prefilter** — `scripts/audit.sh` handles the cheap checks: file existence, gitignore entries, Makefile target names, hook shape, and workflow structure. Outputs `pass`/`fail` per check with a concrete fix command for each failure. `--json` mode emits structured output for LLM consumption.
2. **LLM judgment pass** — after the script runs, the agent reads the files the script flagged plus `Project.swift`, `Fastfile`, and the Makefile, and applies the rubric below to catch the issues a pure grep cannot.

Run the deterministic half:

```bash
bash ~/.agents/skills/ios-project-scaffold/scripts/audit.sh --target /path/to/app
# or, for LLM-consumable output:
bash ~/.agents/skills/ios-project-scaffold/scripts/audit.sh --target /path/to/app --json
```

Exit code is 0 on clean audit, 1 if any check failed.

## Audit rubric

After the script runs, check these judgment-calls on top.

### Project.swift

- Does the manifest use `.target(...)` and `.scheme(...)` from Tuist 4, not the deprecated `Target(...)` initializer?
- Do test env vars live on `testAction: .targets([...], arguments: .arguments(environmentVariables: [...]))`?
- Are env var values written as `$(VAR)` so Tuist expands them from the shell, not hardcoded secrets?
- Is there exactly one shared scheme per product target?
- Is `deploymentTargets:` aligned with `.ios-runtime`?

### Local hygiene

- Is `.githooks/pre-commit` limited to staged-file checks?
- Does the hook format staged Swift files, re-stage them, and stop there?
- Does the hook avoid `xcodebuild`, simulator work, unit tests, UI tests, and Periphery?
- Does `lint` stay fast and deterministic?
- Does `bootstrap-local` stay local-only and avoid baking CI concerns into the developer path?

### Makefile

- Does `format` apply SwiftFormat and does `lint` run SwiftFormat lint, SwiftLint, and typos?
- Do `build`, `test-unit`, and `test-ui` pipe through `xcbeautify`?
- Does every `xcodebuild` call include `-destination "id=$(IOS_SIM_UDID)"`?
- Does the `run` target read `BUILT_PRODUCTS_DIR` via `-showBuildSettings -json | jq`?
- Does each lane use its own `-derivedDataPath /tmp/$(PROJECT_NAME)-<lane>` so parallel builds do not collide?
- Do `setup-tools` and `bootstrap-local` exist and compose cleanly?
- Is `hooks-install` the only generated hook-install path?
- If `.periphery.yml` exists, does `make analyze` exist and stay separate from the default local loop?

### Fastfile

- Does every ASC-facing lane start with `asc_auth` or call `app_store_connect_api_key` directly?
- Are the canonical env var names used: `APP_STORE_CONNECT_API_KEY_KEY_ID`, `APP_STORE_CONNECT_API_KEY_ISSUER_ID`, and either `APP_STORE_CONNECT_API_KEY_KEY_FILEPATH` or inline key content where documented?
- Does `create_app_in_asc` fail loudly with a user-friendly error?
- Does `beta` use `skip_waiting_for_build_processing: true`?

### CI workflows

- Does `ci.yml` split fast linting from simulator-based tests?
- Do macOS jobs set explicit `timeout-minutes`?
- Does `ci.yml` set `concurrency.cancel-in-progress: true`?
- Does `testflight.yml` set `concurrency.cancel-in-progress: false`?
- Does `testflight.yml` require an `environment:` reviewer gate?
- Does `security.yml` run `zizmor` against GitHub Actions workflows?
- Are workflow actions pinned to commit SHAs so the security check does not fail on unpinned refs?

### Gitignore

- Does it ignore the full `*.xcworkspace/` and `*.xcodeproj/` trees?
- Does it ignore `fastlane/.env`, `.env.test`, and signing asset extensions?
- Does it ignore `.ios-sim-udid`?

## References

Load these for deeper detail when the audit needs to reason about a specific subsystem:

- [references/tuist.md](./references/tuist.md) — Tuist 4 patterns, env vars, SPM, Tuist Cloud, debugging `tuist generate`
- [references/ci.md](./references/ci.md) — GitHub Actions macOS cost control, routing rules, xcresult handling
- [references/release.md](./references/release.md) — Fastlane + TestFlight + App Store Connect, ASC API key auth, key rotation, match for signing

## Assumptions and requirements

The skill assumes the target machine has:

- Xcode 26.3 installed (or whatever `.xcode-version` pins)
- `xcodes` CLI (`brew install xcodesorg/made/xcodes`)
- `mise` (`brew install mise`)
- `make bootstrap-local` run once in each freshly scaffolded repo after `git init`
- `jq` on `PATH`
- `perl` on `PATH` (used for placeholder substitution)

The scaffold does not install or check for these. Missing tools surface when a Make target first tries to use them. `README.bootstrap.md` lists the prerequisites again in the generated project.

## Relationship to `ios-audit`

This skill's `audit` mode is a **convention hygiene check**: does the project follow the scaffold's file layout, fast local loop, Makefile targets, hooks, and workflow structure? It runs in seconds and outputs pass/fail per check with concrete fix commands.

The separate `ios-audit` skill is a **comprehensive quality audit** across four pillars (Code Health, UX, Runtime, Release & Compliance), involving LLM sub-agents, runtime simulator capture, and a rendered `docs/` tree.

Use this skill when you want a fast "is this project set up right?" answer. Use `ios-audit` when you want a full quality report for ship decisions.

## What the skill does not do

- **Does not create an App Store Connect app record.** Apple's ASC API has no programmatic creation endpoint, and `fastlane produce` requires Apple-ID + 2FA as of April 2026.
- **Does not generate app icons, launch screens, or localized metadata.** Those are human-curated.
- **Does not manage the `ios-sim-lease` helper.** See that skill's `TODO.md` for the current status.
- **Does not install Xcode or xcodes.** Assumes the host is set up.
- **Does not make deep static analysis part of the default local loop.** Use `--with-analysis` if you want Periphery from day one.
- **Does not decide between SwiftUI and UIKit, TCA and plain Observation, or any other architectural choice.** Scaffold defaults to SwiftUI + a single module.

## When this skill is the wrong tool

- You're adding a feature to an existing project that already follows these conventions → edit code, do not re-scaffold.
- You want to audit non-conventions (code quality, architecture, HIG compliance) → use `ios-audit`, `hig-*`, or a code review workflow.
- You need simulator concurrency across multiple agents → use `ios-sim-lease` when it exists; until then, the scaffold's Makefile uses a sentinel-file fallback.

## Layout

```text
ios-project-scaffold/
  SKILL.md
  scripts/
    scaffold.sh
    audit.sh
  references/
    tuist.md
    ci.md
    release.md
  assets/
    templates/
      xcode-version
      ios-runtime
      tuist-version
      mise.toml
      gitignore
      Makefile
      swiftlint.yml
      swiftformat
      typos.toml
      periphery.yml
      Project.swift.example
      README.bootstrap.md
      githooks/
        pre-commit
      fastlane/
        Fastfile
        Appfile
        .env.example
      github-workflows/
        ci.yml
        security.yml
        testflight.yml
```
