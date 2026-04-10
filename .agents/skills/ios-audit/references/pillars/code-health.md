# Pillar: Code Health

## What it answers

- How is the code organized? What are the modules, targets, and their
  dependencies?
- Where are the smells, dead code, and concurrency bugs?
- Which files are too big, too complex, or carry too much responsibility?
- What is the per-screen layer hierarchy, and are there structural risks?
- Where does documentation drift from the code?

## Raw inputs

The collector at `scripts/collect/code_health.py` captures:

- **file_inventory** — every `.swift` file with LOC + grouping by top-level
  dir. Use this for the architecture overview and to spot bloated areas.
- **modules** — Xcode projects, workspaces, SPM packages, and (if Tuist is
  installed) the full `tuist graph --format json` output.
- **swiftlint** — JSON violations from `swiftlint lint --reporter json`.
  Missing tool is reported as `tool_missing`, not an error.
- **periphery** — dead code candidates from `periphery scan --format json`.
- **complexity_hotspots** — regex-based cyclomatic approximation (branches
  + guards + operators) per Swift file, top-30.
- **layer_hierarchies** — for each `struct XxxView: View`, a flat ordered
  list of container kinds inside the `var body` with depth approximation.
  Supported containers: `VStack`, `HStack`, `ZStack`, `LazyVStack`,
  `LazyHStack`, `LazyVGrid`, `LazyHGrid`, `Grid`, `Group`, `List`,
  `ScrollView`, `NavigationStack`, `NavigationSplitView`, `NavigationView`,
  `TabView`, `Form`, `Section`, `GeometryReader`, `TimelineView`.
- **concurrency_smells** — grep matches for `Task {}`, `Task.detached`,
  `nonisolated(unsafe)`, `@unchecked Sendable`, `DispatchQueue.main.async`,
  `.sync`, semaphores, unsafe pointers.
- **error_handling_smells** — `try?`, empty `catch {}`, TODO/FIXME/XXX/HACK
  markers, `fatalError`, `preconditionFailure`.
- **force_unwraps** — `x!.y` chain, `as!` casts, trailing `!)`.
- **todo_markers** — same as above but broken out for convenience.

## Required tools

**None** — every collector degrades gracefully. But for best results install:

- `swiftlint` (`brew install swiftlint`) — authoritative lint signals
- `periphery` (`brew install peripheryapp/periphery/periphery`) — dead code
- `tuist` (`curl -Ls https://install.tuist.io | bash`) — module graph

## Analyzer outputs

See `scripts/analyze/prompts/code_health.md`. The prompt produces:

- `architecture/01-overview.md`
- `architecture/02-module-graph.md`
- `architecture/03-state-management.md`
- `architecture/04-networking.md`
- `architecture/NN-feature.md` (per feature)
- `quality/known-issues.md`
- `quality/concurrency-audit.md`
- `quality/code-smells.md`
- `quality/refactoring-opportunities.md`

## Common findings patterns

| ID example | Pattern | Severity |
|---|---|---|
| CH-001 | `Task { }` that captures `self` and holds it past the view lifetime | critical |
| CH-002 | Empty `catch {}` in a save path — data loss possible | critical |
| CH-003 | Force unwrap in a flow users hit daily | major |
| CH-004 | View struct >1000 LOC doing network + state + layout | major |
| CH-005 | Duplicate pattern across 3+ viewmodels without a shared helper | moderate |
| CH-006 | SwiftLint `cyclomatic_complexity` over 15 | moderate |
| CH-007 | `FIXME` or `HACK` marker older than 90 days | moderate |
| CH-008 | Dead code flagged by Periphery — export or delete | minor |
| CH-009 | Undocumented public type | minor |
