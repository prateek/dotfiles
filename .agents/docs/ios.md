# iOS Conventions

## Purpose

Personal conventions for iOS and Apple-platform work on this machine. The executable details — scaffolding, Tuist patterns, Fastlane, CI workflows, simulator pooling — live in skills. This file is the policy layer on top.

## When to read this

- Starting or auditing an iOS project on this machine.
- Deciding which iOS skill to reach for.
- Checking what Xcode / iOS runtime / device versions are canonical right now.
- Choosing between two ways of doing the same thing when the skill offers both.

## Shared skills

Reach for these in order.

- **`~/.agents/skills/ios-project-scaffold/`** — bootstrap a new iOS project with every convention baked in (Tuist, pinned toolchain, Makefile, Fastlane, GitHub Actions), or audit an existing project against the same conventions. Two modes, one source of truth. Handles Tuist patterns, CI cost control, and TestFlight/App Store releases.
- **`~/.agents/skills/ios-flow-audit/`** — scripted end-to-end flows in the simulator with screenshot and accessibility-tree capture per step, plus an HTML flow report. Use for ship-gate regressions and agent-reviewable visual audits.
- **`~/.agents/skills/ios-simulator-skill/`** — low-level Python primitives (taps, typing, gestures, accessibility dumps, app launching). `ios-flow-audit` delegates into it; reach for it directly when you need one of its primitives.
- **`~/.agents/skills/ios-sim-lease/`** — simulator leasing for concurrent agents. **Design ready, helper not yet built**; see the skill's `TODO.md`. Until it lands, projects use a sentinel file at `.ios-sim-udid` (the `ios-project-scaffold` Makefile already reads from it).
- **`~/.agents/skills/trycycle/`** — multi-phase orchestration for large changes. Invoke only when asked by name.

Do not reinstall these dormant skills — each overlaps something above and went unused in real work:

- `XcodeBuildMCP` — MCP overhead wasted tokens without getting called.
- `ios-ux-scorecard`, `ios-ux-reviewer`, `ios-engineering-reviewer` — documentation-grade audits that never caught runtime bugs. Use `ios-flow-audit` for runtime verification and the `hig-*` skill family for design-time guidance.

## Canonical triple

The current canonical Xcode / iOS runtime / device triple lives in `~/.agents/state/ios-triple.json`. Read from it; do not hardcode values in templates:

```bash
jq -r .xcode_version          ~/.agents/state/ios-triple.json
jq -r .ios_runtime_primary    ~/.agents/state/ios-triple.json
jq -r .phone_device_type      ~/.agents/state/ios-triple.json
jq -r .tablet_device_type     ~/.agents/state/ios-triple.json
```

Review the file once per quarter. Bumping Xcode or the runtime mid-project costs more than it saves.

The runtime is pinned to whatever the current GitHub Actions `macos-15` / `macos-26` runner images bundle out of the box, so local dev and CI match without a download step. Local machines that need the latest runtime can still install it alongside the canonical one; projects that need backwards compatibility can pin `.ios-runtime` to an older runtime.

## Defaults

The iron rules. Every skill above is built on one of these.

- **Drive iOS projects through `make`.** Agents call Makefile targets; targets wrap `xcodebuild`, `xcrun simctl`, `tuist`, Fastlane, and Python helpers. Never raw tools from an agent session. Read-only probes (`xcodebuild -version`, `xcrun simctl list`, `tuist version`, `git status`) are exempt because they cannot mutate state.
- **Tuist always, nothing else.** No XcodeGen, no hand-edited `.xcodeproj`, no "I'll just open Xcode once". Tuist reads `.tuist-version` and refuses version drift.
- **Run `tuist generate` only with `--no-open`** (or `TUIST_GENERATE_OPEN=0` in the environment). Never let it open Xcode.
- **Never open `Xcode.app` or `Simulator.app` from an agent session** unless the human asks. No `open`, no `xed`, no `flowdeck simulator open`, no GUI launches.
- **Pin the simulator for every automated call by UDID.** Resolve the UDID from a lease (or the sentinel file until `ios-sim-lease` ships), not by name.
- **Pipe `xcodebuild` output through `xcbeautify`** in Makefile targets. Raw walls of output waste tokens and hide errors.
- **Never commit `*.xcworkspace/` or `*.xcodeproj/`.** Tuist regenerates them from `Project.swift`; committing them is perpetual regen noise.
- **Put test env vars in `Project.swift`, not in scheme files.** Tuist regenerates schemes on every `generate` and wipes manual edits. The `ios-project-scaffold` skill encodes the correct Tuist 4 API shape.
- **Pin Xcode, iOS runtime, and devices at the project level.** Match them in CI. See the canonical triple above.
- **SwiftUI previews are a human tool.** Agents never rely on previews for verification. Runtime verification goes through `ios-flow-audit` or XCUITest.
- **HIG skills are design-time guidance, not ship gates.** Ship gates live in `ios-flow-audit` (scripted flows, screenshots, accessibility trees) or XCUITest (hard assertions in CI).

## Starting a new iOS project

Run the scaffold skill:

```bash
bash ~/.agents/skills/ios-project-scaffold/scripts/scaffold.sh \
  --target /path/to/new/app \
  --name MyApp \
  --bundle-id com.example.MyApp \
  --team-id ABCD123456
```

Then follow `README.bootstrap.md` in the generated project for the one-time manual steps (create the App Store Connect app record, generate the ASC API key, wire secrets into GitHub Actions). After those, every subsequent build, test, and TestFlight push is automated.

## Auditing an existing iOS project

Run the audit mode of the same skill:

```bash
bash ~/.agents/skills/ios-project-scaffold/scripts/audit.sh \
  --target /path/to/existing/app
```

The script checks deterministic items (file existence, gitignore entries, Makefile target names, CI workflow shape) and reports pass/fail with a concrete fix command for each failure. After the script, an agent can run a judgment pass using the rubric in the skill's `SKILL.md` to catch the issues a grep cannot (Tuist API shape, Fastlane lane structure, scheme correctness).

## UI verification

Ranked by rigor:

1. **`ios-flow-audit`** — YAML flows, screenshots + accessibility trees per step, HTML report. Best for regression suites and agent-reviewable visual audits.
2. **XCUITest** — hard assertions inside the Xcode test runner. Best when CI needs a pass/fail gate.
3. **Manual simulator walkthrough** — exploratory, one-off. Useful during active debugging; never a ship gate.

Every ship-critical flow gets at least one `ios-flow-audit` YAML in the project's `.audit/` directory, wired into `make audit`.
