# Applies to: TCA 1.25+, iOS 16+

# Clocks and Time

## Use When

Use this for debounce, throttle, timers, polling, deadlines, delayed UI, and time-based tests.

## Guidance

- Inject clocks with `@Dependency(\.continuousClock)` or the local codebase's chosen clock dependency.
- Use `ContinuousClock` for elapsed-real-time waits (debounce, throttle, retry backoff). Use `SuspendingClock` for waits that should pause when the app suspends; use it sparingly because most product timing should be real-time.
- Use `clock.sleep(for:)` inside `.run`.
- Use `TestClock` in tests and advance time explicitly. Use `ImmediateClock` when a test or preview should resolve every wait synchronously without manual advancement.
- Use date dependencies for wall-clock values and clocks for waiting.
- Prefer cancellation over letting old delayed effects complete.
- Capture the clock in `.run` instead of implicitly capturing `self`.
- Keep debounce duration in one place so tests and behavior do not drift.

## Example

```swift
@Dependency(\.continuousClock) var clock
@Dependency(\.searchClient) var searchClient

return .run { [query = state.query, clock, search = searchClient.search] send in
  try await clock.sleep(for: .milliseconds(300))
  await send(.searchResponse(Result { try await search(query) }))
}
.cancellable(id: CancelID.query, cancelInFlight: true)
```

## Test Clock

```swift
let clock = TestClock()
let store = TestStore(initialState: Search.State()) {
  Search()
} withDependencies: {
  $0.continuousClock = clock
}

await store.send(.queryChanged("swift")) {
  $0.query = "swift"
  $0.isLoading = true
}

await clock.advance(by: .milliseconds(299))
await clock.advance(by: .milliseconds(1))
await store.receive(\.searchResponse.success) {
  $0.isLoading = false
}
```

Use two advances when the test needs to prove nothing arrives early. One exact advance is fine when the contract is only "after the debounce interval."

## Pitfalls

- Do not use `Task.sleep` directly in reducers.
- Do not use live clocks in tests.
- Do not compare `Date()` directly in reducer tests.
- Avoid Combine schedulers in code already on async/await TCA.
- Do not model wall-clock time with `ContinuousClock`. Use a date dependency for values displayed or persisted as dates.
- Do not use real sleeps to wait for TestStore effects. The test will be slow and flaky.

## Tests

Create a test clock, inject it, send the action, assert no response before advancing when that matters, advance by the exact duration, then assert the response.
