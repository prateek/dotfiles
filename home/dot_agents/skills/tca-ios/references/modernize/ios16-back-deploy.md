# Applies to: TCA 1.25+, iOS 16+

# iOS 16 Back-Deploy

## Use When

Use this while modernizing a TCA view to direct store observation when the app still supports iOS 16.

TCA 1.25+ already excludes iOS 15. Do not preserve iOS 15-era migration work, alternate view layers, or conditional code paths unless the local project has a separate explicit requirement outside this skill.

## Steps

1. Add `@ObservableState` to feature state if it is missing.
2. Replace `WithViewStore`, `ViewStore`, `IfLetStore`, `ForEachStore`, and `NavigationStackStore` with direct store observation and modern navigation helpers.
3. Wrap the state-reading SwiftUI body in `WithPerceptionTracking` while iOS 16 is supported.
4. Wrap lazy state-reading closures independently, including rows, navigation destinations, sheets, popovers, and task bodies that read store state.
5. Use `@Perception.Bindable` instead of SwiftUI `@Bindable` for bindings that must run on iOS 16.
6. Keep the behavior-preserving tests green before removing legacy compatibility scaffolding.

## Pitfalls

- Do not remove Perception wrappers until the minimum OS target is iOS 17+.
- Do not leave a half-modernized view with direct observation in one branch and `WithViewStore` in another.
- Do not add iOS 15 conditionals or deployment checks for this skill target.
- Do not rely on parent wrappers to cover closures evaluated later by SwiftUI.

## Tests

Run the migrated path on an iOS 16 simulator. Add or update view-level and reducer tests around bindings, navigation, and effects touched by the migration.
