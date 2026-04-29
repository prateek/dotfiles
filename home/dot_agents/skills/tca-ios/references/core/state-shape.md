# Applies to: TCA 1.25+, iOS 16+

# State Shape

## Use When

Use this when modeling feature state, reviewing state ownership, or diagnosing impossible UI states.

## Guidance

- Store facts, not derived display strings. Format near the view unless formatting drives behavior.
- Prefer small domain types over parallel booleans.
- Use enums for mutually exclusive modes: loading, loaded, failed, editing, confirming.
- Use `@Presents var destination: Destination.State?` for sheet, alert, dialog, popover, and full-screen cover state.
- Use `StackState<Path.State>` for push navigation.
- Use `IdentifiedArrayOf<Child.State>` for editable child lists.
- Keep parent and child state from duplicating the same mutable source of truth. If multiple features must mutate one value, use a shared value or a parent-owned state path.
- Keep transient UI state in SwiftUI when the reducer does not need it. Focus, scroll position, and local animations usually belong in the view.
- Keep loading and error state close to the effect they describe. A global `isLoading` flag becomes ambiguous as soon as a feature has more than one effect.

## Common Shapes

```swift
enum Mode: Equatable {
  case idle
  case loading
  case failed(String)
  case loaded(IdentifiedArrayOf<Row.State>)
}
```

```swift
@Presents var destination: Destination.State?
var path = StackState<Path.State>()
var rows: IdentifiedArrayOf<Row.State> = []
```

For search-like features, parallel fields can be fine when each combination has a clear meaning:

```swift
@ObservableState
struct State: Equatable {
  var query = ""
  var results: IdentifiedArrayOf<SearchResult> = []
  var isLoading = false
  var errorMessage: String?
}
```

The reducer must then maintain the invariants:

- Empty query means `results` is empty and `isLoading` is false.
- Starting a non-empty query clears the previous error and sets `isLoading` true.
- Success replaces `results`, clears the error, and sets `isLoading` false.
- Failure sets an error message and sets `isLoading` false.

If those invariants feel hard to preserve, use an enum instead:

```swift
enum SearchStatus: Equatable {
  case idle
  case loading(query: String)
  case loaded(query: String, results: IdentifiedArrayOf<SearchResult>)
  case failed(query: String, message: String)
}
```

## Pitfalls

- Parallel fields like `isLoading`, `error`, and `items` can represent impossible combinations. Use them only when the combinations are valid.
- Global app state should not become a dumping ground for leaf state.
- Child state should not be reachable and mutated by unrelated siblings.
- Do not store `Store`, view models, tasks, publishers, or SDK objects in reducer state.
- Do not store raw `Error` values in state. Convert failures to stable user-facing state, such as a message, alert state, or retry token.
- Do not keep stale success data after a failure unless the product intentionally shows old data with an error banner.

## Tests

Assert transitions between states directly. A good state-shape test proves the invalid state cannot be reached, or proves the reducer normalizes it immediately. For search, test empty query, success, failure, and superseded requests because those are the paths that usually break the invariants.
