# Applies to: TCA 1.25+, iOS 16+

# Cancellation Tests

## Use When

Use this for debounced search, polling, async streams, timers, subscriptions, and dismissed child features.

## Guidance

- Inject a `TestClock` for sleep-based effects.
- Use an async stream/test dependency for long-lived subscriptions.
- Assert no stale response arrives after a newer action cancels in-flight work.
- Assert TestStore finishes without running effects after dismissal or cancellation.
- Test explicit user cancellation separately from `cancelInFlight` replacement. They usually have different state changes.
- Keep the dependency cooperative with cancellation in tests unless you are intentionally testing stale-response defense.

## Example Contract

1. Send first query.
2. Send second query before debounce elapses.
3. Advance time.
4. Receive only the second response.

## Debounce Example

```swift
@MainActor
@Test
func changingQueryCancelsInFlightSearch() async {
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

## Clear Example

```swift
@MainActor
@Test
func clearingQueryCancelsSearchAndClearsLoading() async {
  let clock = TestClock()
  let store = TestStore(
    initialState: Search.State(query: "swift", isLoading: true)
  ) {
    Search()
  } withDependencies: {
    $0.continuousClock = clock
    $0.searchClient.search = { @Sendable _ in [] }
  }

  await store.send(.queryChanged("")) {
    $0.query = ""
    $0.results = []
    $0.isLoading = false
    $0.errorMessage = nil
  }
}
```

## Pitfalls

- Do not use real sleeps in tests.
- Do not mark a running effect as ignored unless the feature intentionally owns a process for the lifetime of the test.
- Do not clear loading state in the test unless the reducer actually does it on cancellation.
- Do not assert a stale response is absent by waiting on wall-clock time. Use `TestClock` or a controllable stream.
- Do not use non-exhaustive mode to hide effects that should have been cancelled.
