# Applies to: TCA 1.25+, iOS 16+

# TestStore Basics

## Contents

- [Use When](#use-when)
- [Guidance](#guidance)
- [Example](#example)
- [Receive Styles](#receive-styles)
- [Pitfalls](#pitfalls)
- [Tests](#tests)

## Use When

Use this for any reducer behavior that changes state, returns effects, or coordinates children.

## Guidance

- Prefer `@MainActor` test suites or test functions for TestStore tests.
- Create the store with initial state and the reducer under test.
- Use `await store.send(...) { ... }` to assert state after a sent action.
- Use `await store.receive(...) { ... }` to assert effect feedback.
- Override dependencies before sending actions.
- Keep assertion closures concrete and simple.
- Use case-path `receive` overloads for non-Equatable actions and `Result<Success, any Error>` payloads.
- Assert the state after the reducer handles the response, not inside the dependency closure.

## Example

```swift
@MainActor
@Test
func searchDebouncesAndCancels() async {
  let clock = TestClock()
  let results: IdentifiedArrayOf<SearchResult> = [
    SearchResult(id: "swift", title: "Swift")
  ]

  let store = TestStore(initialState: Search.State()) {
    Search()
  } withDependencies: {
    $0.continuousClock = clock
    $0.searchClient.search = { @Sendable query in
      query == "swift" ? results : []
    }
  }

  await store.send(.queryChanged("s")) {
    $0.query = "s"
    $0.isLoading = true
  }
  await store.send(.queryChanged("swift")) {
    $0.query = "swift"
    $0.isLoading = true
  }

  await clock.advance(by: .milliseconds(300))

  await store.receive(\.searchResponse.success, results) {
    $0.results = results
    $0.isLoading = false
  }
}
```

That example does not require `Search.Action: Equatable`. The received action contains `Result<IdentifiedArrayOf<SearchResult>, any Error>`, so comparing the whole action would fail to compile. The case-path receive extracts the success payload and compares that payload instead.

For failure paths, receive the failure case without comparing the `any Error` value:

```swift
@MainActor
@Test
func searchFailureClearsLoading() async {
  struct SearchError: LocalizedError {
    var errorDescription: String? { "Search failed." }
  }

  let clock = TestClock()
  let store = TestStore(initialState: Search.State()) {
    Search()
  } withDependencies: {
    $0.continuousClock = clock
    $0.searchClient.search = { @Sendable _ in throw SearchError() }
  }

  await store.send(.queryChanged("swift")) {
    $0.query = "swift"
    $0.isLoading = true
  }

  await clock.advance(by: .milliseconds(300))

  await store.receive(\.searchResponse.failure) {
    $0.isLoading = false
    $0.errorMessage = "Search failed."
  }
}
```

## Receive Styles

- `await store.receive(.action)` requires `Action: Equatable`.
- `await store.receive(\.response)` matches the case and ignores its payload.
- `await store.receive(\.response.success, value)` matches an Equatable extracted payload.
- `await store.receive { action in ... }` is the escape hatch for custom matching.

Prefer the most specific style that still compiles naturally.

## Pitfalls

- Do not use live network, clocks, dates, UUIDs, or databases in reducer tests.
- Do not write assertion closures that recompute the same logic as the reducer.
- Do not ignore received actions unless using non-exhaustive mode intentionally.
- Do not add `Equatable` to `Action` just to compare an `any Error`.
- Do not receive a success action and forget to assert loading cleared when loading is part of the user contract.

## Tests

Cover success, failure, cancellation, navigation, and delegate events when the feature has those paths.
