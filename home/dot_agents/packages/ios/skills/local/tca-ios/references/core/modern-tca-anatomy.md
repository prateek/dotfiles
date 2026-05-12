# Applies to: TCA 1.25+, iOS 16+

# Modern TCA Anatomy

## Contents

- [Use When](#use-when)
- [Shape](#shape)
- [Guidance](#guidance)
- [Pitfalls](#pitfalls)
- [Tests](#tests)

## Use When

Use this when adding a feature, orienting around an unfamiliar feature, or replacing a legacy skeleton with modern TCA.

## Shape

A modern feature has one domain type with nested state, actions, dependencies, reducer logic, and any private support types:

```swift
import ComposableArchitecture
import Foundation

@Reducer
struct Search {
  @ObservableState
  struct State: Equatable {
    var query = ""
    var results: IdentifiedArrayOf<SearchResult> = []
    var isLoading = false
    var errorMessage: String?
  }

  enum Action {
    case queryChanged(String)
    case searchResponse(Result<IdentifiedArrayOf<SearchResult>, any Error>)
  }

  @Dependency(\.searchClient) var searchClient
  @Dependency(\.continuousClock) var clock

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .queryChanged(query):
        state.query = query
        state.errorMessage = nil

        guard !query.isEmpty else {
          state.results = []
          state.isLoading = false
          return .cancel(id: CancelID.search)
        }

        state.isLoading = true
        return .run { [query = state.query, clock, search = searchClient.search] send in
          try await clock.sleep(for: .milliseconds(300))
          await send(.searchResponse(Result { try await search(query) }))
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)

      case let .searchResponse(.success(results)):
        state.results = results
        state.isLoading = false
        state.errorMessage = nil
        return .none

      case let .searchResponse(.failure(error)):
        state.results = []
        state.isLoading = false
        state.errorMessage = error.localizedDescription
        return .none
      }
    }
  }

  enum CancelID { case search }
}
```

The corresponding view owns a store, observes state directly, and sends events:

```swift
struct SearchView: View {
  @Bindable var store: StoreOf<Search>

  var body: some View {
    List {
      TextField("Search", text: $store.query.sending(\.queryChanged))

      if store.isLoading {
        ProgressView()
      }

      ForEach(store.results) { result in
        Text(result.title)
      }
    }
  }
}
```

## Guidance

- Keep the reducer name short and domain-specific: `Search`, `Settings`, `SyncUpsList`.
- Use `@ObservableState` for state read by SwiftUI.
- Use `ReducerOf<Self>` when it improves readability. `some Reducer<State, Action>` is also fine when the surrounding code uses it.
- Add dependencies at reducer scope, not in state.
- Use event bindings such as `$store.query.sending(\.queryChanged)` when the reducer needs a named event.
- Use `BindableAction` and `BindingReducer()` when many fields are domain bindings and direct binding actions fit the local style.
- Compose child reducers after the parent `Reduce` unless local style puts composition first.
- Every async response that affects UI state should be handled explicitly. Loading state that turns on must have a response, cancel, or clear path that turns it off.
- Capture dependency functions and immutable state values in `.run` capture lists. This avoids implicit `self` captures and keeps Swift 6 sendability easier to reason about.

## Pitfalls

- Do not add `Reducer` suffixes to feature types.
- Do not conform `Action` to `Equatable` just to make `Result<any Error>` tests compile. Use TestStore case-path receives.
- Do not add Environment structs in modern code.
- Do not make views own domain state that reducers need for decisions.
- Do not leave `.searchResponse`, `.refreshResponse`, or similar cases as no-ops. That creates stuck spinners and hides failures.
- Do not start a new request for an empty search query. Clear state and cancel the previous request instead.

## Tests

Every new feature needs a `TestStore` test for the meaningful action path. If the feature returns effects, cover success, failure, and cancellation where those outcomes affect state. For actions carrying `Result<Success, any Error>`, receive with case paths such as `\.searchResponse.success` or `\.searchResponse.failure`.
