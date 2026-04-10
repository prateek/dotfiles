---
name: ios-project-scaffold
description: Scaffold a new iOS project with pinned Xcode toolchain, Tuist manifest, Makefile targets for build/test/run/audit/release, Fastlane lanes for TestFlight and App Store, and GitHub Actions workflows for cost-controlled CI. Also audits existing iOS projects against the same conventions and reports deviations with concrete fix commands. Use when the user asks to "start a new iOS project", "bootstrap an iOS app", "scaffold an iOS app", "set up Tuist for a new project", "add TestFlight to my iOS project", "add Fastlane", "audit my iOS project setup", "check my iOS project against conventions", "is this iOS project set up right", or "fix iOS project hygiene". Two modes — init for scaffolding a new project, audit for checking an existing one.
---

# iOS Project Scaffold

Scaffold a new iOS project with every convention baked in, or audit an existing project against the same conventions. One skill, two modes; same source of truth for both.

## Modes

### `init` — scaffold a new project

Drops these into a target directory:

- **Pinning files**: `.xcode-version`, `.ios-runtime`, `.tuist-version`, `mise.toml`
- **Project manifest**: `Project.swift` (Tuist 4.x) with a test-action environment-variables block that survives `tuist generate`
- **Makefile**: canonical targets for `generate`, `build`, `run`, `test-unit`, `test-ui`, `test`, `audit`, `beta`, `release`, `metadata`, `boot-lease`, `release-lease`, `kill-dev-processes`, `clean-dev-artifacts`, `check-xcode`
- **Gitignore**: Tuist-aware entries so the generated `*.xcworkspace` / `*.xcodeproj` tree never enters git
- **Fastlane**: `Fastfile` with `asc_auth`, `beta` (TestFlight), `release` (App Store), `metadata` lanes using ASC API key auth; `Appfile`; `.env.example`
- **GitHub Actions**: `build.yml` (push/PR, cost-controlled) and `testflight.yml` (tag-gated TestFlight upload with reviewer environment)
- **Flow audit placeholder**: `.audit/devices.yaml` so `ios-flow-audit` has a device set (no `primary.yaml` — users write their own)
- **Bootstrap README**: `README.bootstrap.md` documenting the one-time manual steps (ASC app record, ASC API key, CI secrets)

Run:

```bash
bash ~/.agents/skills/ios-project-scaffold/scripts/scaffold.sh \
  --target /path/to/new/app \
  --name MyApp \
  --bundle-id com.example.MyApp \
  --team-id ABCD123456
```

After it finishes, read the generated `README.bootstrap.md` and do the three one-time manual steps (create the ASC app record, generate the ASC API key, add CI secrets). Everything after those is automated.

### `audit` — check an existing project

Walks the convention set against a target directory and reports pass/fail per check. Non-destructive. Uses a hybrid script + LLM rubric:

1. **Deterministic prefilter** — `scripts/audit.sh` handles the cheap checks: file existence, gitignore entries, Makefile target names, grep patterns in committed files. Outputs `pass`/`fail` per check with a concrete fix command for each failure. `--json` mode emits structured output for LLM consumption.
2. **LLM judgment pass** — after the script runs, the agent reads the files the script flagged plus `Project.swift`, `Fastfile`, and the Makefile, and applies the rubric in this SKILL.md → Audit rubric section to catch the issues a pure grep cannot (is the Tuist 4 `environmentVariables:` shape correct? does the Fastfile use `app_store_connect_api_key` before every ASC call? are the Makefile targets sensibly scoped?).

Run the deterministic half:

```bash
bash ~/.agents/skills/ios-project-scaffold/scripts/audit.sh --target /path/to/app
# or, for LLM-consumable output:
bash ~/.agents/skills/ios-project-scaffold/scripts/audit.sh --target /path/to/app --json
```

Exit code is 0 on clean audit, 1 if any check failed.

## Audit rubric (for the LLM pass)

After the script runs, the agent checks these judgment-calls on top:

### Project.swift

- Does the manifest use `.target(...)` and `.scheme(...)` from Tuist 4, or the deprecated `Target(...)` initializer?
- Do test env vars live on `testAction: .targets(["MyAppTests"], arguments: .arguments(environmentVariables: [...]))` and not on a `Target(..., scheme:)` shape (that shape doesn't exist in Tuist 4)?
- Are env var values written as `$(VAR)` so Tuist expands them from the shell, or hardcoded strings that leak into git?
- Is there exactly one shared scheme per product target? Multiple overlapping schemes are a drift signal.
- Is the `deploymentTargets:` version matching the runtime in `.ios-runtime`?

### Makefile

- Does `build` / `test-unit` / `test-ui` pipe through `xcbeautify`?
- Does every `xcodebuild` call include `-destination "id=$(IOS_SIM_UDID)"` (never `name=iPhone 16`)?
- Does the `run` target read `BUILT_PRODUCTS_DIR` via `-showBuildSettings -json | jq` (not an unanchored `awk /BUILT_PRODUCTS_DIR/`)?
- Does each lane use its own `-derivedDataPath /tmp/$(PROJECT_NAME)-<lane>` so parallel builds don't collide?
- Is `.PHONY` declared for every non-file target?
- Does the `help` target use BSD-awk-compatible syntax (not GNU `.*?` lazy matching)?

### Fastfile

- Does every ASC-facing lane start with `asc_auth` (or call `app_store_connect_api_key` directly)?
- Are the three canonical env var names used: `APP_STORE_CONNECT_API_KEY_KEY_ID`, `APP_STORE_CONNECT_API_KEY_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_KEY_FILEPATH` (note the doubled `_KEY_`)?
- Does `create_app_in_asc` fail loudly with a user-friendly error, or does it silently pretend to work? (The correct behavior is to fail loudly — ASC API doesn't allow programmatic app creation.)
- Does `beta` use `skip_waiting_for_build_processing: true` to avoid hanging on Apple's processing queue?
- Are signing artifacts (`*.p8`, `*.p12`, `*.mobileprovision`) referenced via env vars or 1Password, not committed paths?

### CI workflows

- Does `build.yml` pin `macos-15` or `macos-26`, not `macos-latest`?
- Does every macOS job set explicit `timeout-minutes`?
- Is `concurrency:` set with `cancel-in-progress: true` on build workflows?
- Is `concurrency:` set with `cancel-in-progress: false` on deploy workflows (never cancel an in-flight release)?
- Does the TestFlight workflow require an `environment:` reviewer gate?
- Is the iOS runtime matched to what the GHA runner image ships (iOS 26.2 for macos-15/26), or is there a redundant `xcodes runtimes install` step?

### Gitignore

- Does it ignore the full `*.xcworkspace/` and `*.xcodeproj/` trees (Tuist regenerates them)?
- Does it ignore `fastlane/.env`, `.env.test`, and all signing asset extensions?
- Does it ignore `.ios-sim-udid` (per-worktree, never committed)?

## References

Load these for deeper detail when the audit needs to reason about a specific subsystem:

- [references/tuist.md](./references/tuist.md) — Tuist 4 patterns, env vars, SPM, Tuist Cloud, debugging `tuist generate`.
- [references/ci.md](./references/ci.md) — GitHub Actions macOS cost control, routing rules, xcresult handling.
- [references/release.md](./references/release.md) — Fastlane + TestFlight + App Store Connect, ASC API key auth, key rotation, match for signing.

## Assumptions and requirements

The skill assumes the target machine has:

- Xcode 26.3 installed (or whatever `.xcode-version` pins).
- `xcodes` CLI (`brew install xcodesorg/made/xcodes`).
- `xcbeautify` (`brew install xcbeautify`).
- `tuist` (`curl -Ls https://install.tuist.io | bash`, or `mise install tuist`).
- `mise` (`brew install mise`).
- `jq` on `PATH` (the Makefile uses it to read `-showBuildSettings -json`).
- Ruby 3.3+ for Fastlane (pinned via `mise.toml`).
- `perl` on `PATH` (scaffold.sh uses it for placeholder substitution; preinstalled on macOS).

The scaffold does not install or check for these; missing tools surface when a Make target first tries to use them. The `README.bootstrap.md` generated into the scaffolded project lists the prerequisites again.

## Relationship to `ios-audit`

This skill's `audit` mode is a **convention hygiene check**: does the project follow the scaffold's file layout, gitignore rules, Makefile targets, and Fastlane structure? It runs in seconds and outputs pass/fail per check with concrete fix commands.

The separate `ios-audit` skill is a **comprehensive quality audit** across four pillars (Code Health, UX, Runtime, Release & Compliance), involving LLM sub-agents, runtime simulator capture, and a rendered `docs/` tree. That is a much bigger operation.

Use this skill (`ios-project-scaffold audit`) when you want a fast "is this project set up right?" answer. Use `ios-audit` when you want a full quality report for ship decisions.

## What the skill does not do

- **Does not create an App Store Connect app record.** Apple's ASC API has no programmatic creation endpoint, and `fastlane produce` requires Apple-ID + 2FA as of April 2026. The scaffold generates a `create_app_in_asc` lane that fails loudly on purpose, pointing the user at the ASC web UI for the one-time 60-second manual step.
- **Does not generate app icons, launch screens, or localized metadata.** Those are human-curated.
- **Does not manage the `ios-sim-lease` helper.** See the `ios-sim-lease` skill and its `TODO.md` for the current status (design ready, bash helper not yet built).
- **Does not install Xcode, xcodes, or Tuist.** Assumes the host is set up.
- **Does not decide between SwiftUI and UIKit, TCA and plain Observable, or any other architectural choice.** Scaffold defaults to SwiftUI + Observation + a single module; edit `Project.swift` after scaffolding if you need something else.

## When this skill is the wrong tool

- You're adding a feature to an existing project that already follows these conventions → just edit code, don't re-scaffold.
- You want to audit non-conventions (code quality, architecture, HIG compliance) → use `simplify`, `hig-*` skills, or a code review tool instead.
- You want to run UI regression tests against a scaffolded project → use `ios-flow-audit` (which this scaffold is designed to integrate with).
- You need simulator concurrency across multiple agents → use `ios-sim-lease` when it exists; until then, the scaffold's Makefile uses a sentinel-file fallback.

## Layout

```
ios-project-scaffold/
  SKILL.md                      ← this file
  scripts/
    scaffold.sh                 ← init mode entrypoint
    audit.sh                    ← audit mode entrypoint (deterministic prefilter)
  references/
    tuist.md                    ← Tuist 4 patterns + Cloud + SPM
    ci.md                       ← GitHub Actions cost control
    release.md                  ← Fastlane + TestFlight + ASC
  assets/
    templates/
      xcode-version
      ios-runtime
      tuist-version
      mise.toml
      gitignore
      Makefile
      Project.swift.example
      devices.yaml
      README.bootstrap.md
      fastlane/
        Fastfile
        Appfile
        .env.example
      github-workflows/
        build.yml
        testflight.yml
```
