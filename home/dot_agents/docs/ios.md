# iOS Conventions

Use this document for iOS and Apple-platform work on this machine. It records
local policy; the skills in the `ios` package own executable workflows and
tool details. The package is disabled by default for Claude and Codex; Cursor
exposes rendered packages independently of that setting. If a required skill
is unavailable, report it. Change project plugin activation only when the task
authorizes configuration changes. Use
`.agents/skills/agent-skill-management/SKILL.md` from the active dotfiles
checkout, or resolve the configured chezmoi source when outside one.

## Skill routing

- `ios-project-scaffold`: create a Tuist-based project or audit an existing
  project's scaffold, build targets, CI, and release setup.
- `ios-audit`: run a broader code-health, UX, runtime, and release-readiness
  audit, including scripted simulator workflows. For UX collection, pass a
  simulator UDID owned by the current worktree helper.
- `ios-simulator-skill`: use low-level simulator build, launch, input,
  screenshot, and accessibility primitives.
- `ios-sim-lease`: reference for planned cross-agent simulator coordination.
  Its helper is not built. Scaffolded projects use their repository-owned
  worktree helper; report missing coordination instead of introducing
  `.ios-sim-udid`.
- `swiftui-expert-skill` and `swift-patterns`: use for implementation and
  design-time SwiftUI guidance.
- `hig-*`: use the skills in `design@prateek-local` for design-time Apple HIG
  guidance when that package is available. They inform design; runtime ship
  gates remain `ios-audit` workflows or XCUITest.
- `trycycle`: use only when Prateek invokes it by name and the `experimental`
  package is enabled.

Use skill names rather than hardcoded generated-plugin paths.

## Rejected tooling

Do not reinstall `XcodeBuildMCP`; its MCP overhead did not earn its cost. Do not
reintroduce `ios-ux-scorecard`, `ios-ux-reviewer`, or
`ios-engineering-reviewer`; use `ios-audit` for runtime evidence and the HIG
skills for design-time guidance.

## Canonical toolchain

Read the current Xcode, iOS runtime, phone, and tablet choices from
`~/.agents/state/ios-triple.json`:

```sh
jq -r .xcode_version       ~/.agents/state/ios-triple.json
jq -r .ios_runtime_primary ~/.agents/state/ios-triple.json
jq -r .phone_device_type   ~/.agents/state/ios-triple.json
jq -r .tablet_device_type  ~/.agents/state/ios-triple.json
```

Review the triple quarterly rather than upgrading in the middle of a project.
Prefer the runtime bundled by the matching GitHub Actions macOS image so local
and CI builds do not require different downloads.

## Defaults

- Drive project mutations through repository `make` targets. Read-only probes
  may call `xcodebuild`, `xcrun simctl`, `tuist`, or Git directly.
- Generate projects with Tuist. Keep its version pinned and run generation
  without opening Xcode.
- Keep Xcode and Simulator closed unless Prateek asks for GUI interaction.
- Provision every automated simulator through the repository-owned worktree
  helper. Pass its resolved UDID to tools that run outside the helper.
- Pipe `xcodebuild` output through `xcbeautify` in repository targets.
- Generate `.xcodeproj` and `.xcworkspace` artifacts from Tuist; keep them out
  of version control.
- Put test environment settings in `Project.swift`, where Tuist owns the
  generated schemes.
- Pin Xcode, runtime, and device policy in the project and match it in CI.
- Verify runtime behavior through `ios-audit` workflows or XCUITest rather than
  SwiftUI previews.

## New projects and scaffold audits

Invoke `ios-project-scaffold` in `init` mode for a new project and follow the
generated `README.bootstrap.md` for App Store Connect and secret provisioning.

Invoke the same skill in `audit` mode for a deterministic check of an existing
project's files, ignores, Makefile targets, Tuist configuration, and CI shape.
Use `ios-audit` when the task asks for broader engineering or UX evidence.

## Runtime verification

Choose the strongest lane the task supports:

1. `ios-audit` scripted workflows for screenshots, accessibility evidence, and
   an agent-reviewable report.
2. XCUITest for assertions that must gate CI.
3. A manual simulator walkthrough for active exploration, not a ship gate.

Keep project-specific workflow definitions in the repository and expose them
through a repository command.

For an `ios-audit` UX run in a scaffolded project, provision the simulator
through the repository helper, read its UDID from
`build/simulators/<family>.json`, and pass that value with `--udid`. Do not run
another helper-managed simulator task in the same worktree concurrently. In an
unscaffolded project, use an explicitly assigned UDID and verify that no other
agent owns it; never select an arbitrary booted device.

## Completion

- The project and CI use the same pinned toolchain and runtime policy.
- Every automated simulator command targets a resolved UDID.
- Generated Xcode artifacts remain untracked.
- Build and test output is filtered but preserves failures.
- Runtime claims are backed by an audit workflow or XCUITest evidence.
