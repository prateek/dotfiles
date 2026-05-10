# Applies to: TCA 1.25+, iOS 16+

# Version Probe

## Use When

Use this before any modernization recommendation or edit.

## Steps

1. Detect package versions from `Package.resolved`, `Package.swift`, project files, and generated manifests.
2. Search for API markers:
   - `ReducerProtocol`
   - `WithViewStore`, `ViewStore`
   - `IfLetStore`, `ForEachStore`, `SwitchStore`, `NavigationStackStore`
   - `@PresentationState`
   - Environment structs
   - `Effect.publisher`, `Effect.task`, Combine schedulers
   - `@Reducer`, `@ObservableState`, `@Presents`
3. Classify each touched feature as legacy, transitional, or modern.
4. Choose the smallest recipe that moves the feature toward the codebase's target style.

## Pitfalls

- Do not migrate every old file because one prompt asked for a narrow change.
- For this plugin target, assume iOS 16+ unless the local project proves otherwise. Keep iOS 16
  observation backport requirements separate from legacy iOS 15 support.
- Do not enable 1.25 deprecation traits in a broad branch without warning about compile churn.

## Tests

Record the baseline test/build status before a migration when failure origin is unclear.
