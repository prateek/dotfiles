# Applies to: TCA 1.25+, iOS 16+

# Observable vs TCA

## Use When

Use this in decide mode or when a feature may not need a reducer.

## Guidance

Choose plain SwiftUI `@State` for local, visual, single-view state.

Choose an `@Observable` model when a small feature has reference-type state, modest side effects, and no strong need for exhaustive reducer tests.

Choose TCA when state transitions, effects, navigation, cancellation, dependency control, or cross-feature composition need to be explicit and testable.

## Heuristic

- Three-screen utility, no shared domain state: plain SwiftUI or `@Observable`.
- Single feature with a bit of async work: `@Observable` plus Dependencies may be enough.
- Multi-screen product flow with deep links and cancellation: TCA.
- Team standardizes on reducer tests: TCA.
- Existing TCA app, tiny visual subview: local SwiftUI state inside the view.
- Existing `@Observable` app, one workflow needs testable effects and routing: introduce TCA at that workflow boundary, not everywhere.

## Decision Table

| Need | Prefer |
| --- | --- |
| Button highlight, focus, scroll position, animation toggle | SwiftUI `@State` |
| Small screen model with one async load | `@Observable` model |
| Exhaustive state/effect tests | TCA reducer |
| Deep links, stack routing, sheet cancellation | TCA reducer |
| UIKit screen with state-driven navigation | TCA + UIKit tools |
| Shared persisted preference | `@Shared` |
| Relational persisted data | SQLiteData |

## Boundary Pattern

```swift
@Observable
@MainActor
final class SearchModel {
  @ObservationIgnored @Dependency(\.searchClient) var searchClient
  var query = ""
  var results: [ResultRow] = []

  func searchButtonTapped() async {
    results = (try? await searchClient.search(query)) ?? []
  }
}
```

This is enough when the feature is isolated. Move to TCA when the same behavior needs cancellation IDs, dependency overrides in `TestStore`, navigation effects, or child reducer composition.

## Pitfalls

- Do not adopt TCA as a badge of seriousness for simple UI.
- Do not mix `@Observable` models and TCA reducers for the same source of truth.
- Do not call TCA wrong because it has ceremony; decide whether the ceremony buys testability and coordination.
- Do not use `@Observable` as a way to bypass TCA action naming inside a TCA feature.
- Do not keep old `ObservableObject`/Combine patterns when modern Observation or TCA direct store observation fits the deployment target.

## Tests

In decide mode, no code edits. If the choice is TCA, name the first reducer test that justifies the architecture. If the choice is `@Observable`, name the model method tests and dependency overrides that keep it honest.
