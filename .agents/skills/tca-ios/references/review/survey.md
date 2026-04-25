# Applies to: TCA 1.25+, iOS 16+

# Repository Survey

## Use When

Use this as phase 0 of any review.

## Inspect

- Package manifests, project/workspace files, Tuist, XcodeGen, CocoaPods, or Cartfile.
- App targets, feature targets, shared modules, dependency modules, and test targets.
- Installed TCA version and sibling-library versions when visible.
- Modern markers: `@Reducer`, `@ObservableState`, `StoreOf`, `@Dependency`, `Effect.run`, `TestStore`, `StackState`, `@Presents`.
- Legacy markers: Environment structs, `ReducerProtocol`, `Reducer.combine`, `WithViewStore`, `ViewStore`, Combine-heavy effects, legacy navigation helpers.
- Directory layout, root reducer, app entry point, and major features.

## Output

Include:

- TCA version and API style: modern, transitional, or legacy.
- Module and target map.
- Major features.
- Likely hotspots: large reducers, effect-heavy clients, navigation roots, fragile tests.
- Suggested file groups for focused review passes.

## Guardrails

Keep this phase descriptive. Do not turn it into full findings unless the evidence is obvious and urgent.
