# Applies to: TCA 1.25+, iOS 16+

# Dependency Overrides in Tests

## Use When

Use this when reducer tests need deterministic clients, clocks, UUIDs, dates, persistence, or async streams.

## Guidance

- Override dependencies in `TestStore` construction when the override is specific to that reducer test.
- Use `withDependencies` around code that constructs observable models or calls dependencies outside TestStore.
- Use failing test defaults so missing overrides fail fast.
- Keep dependency values scoped to the test.
- Override before the action that starts the effect. Effects capture dependency values when the reducer returns them.
- Prefer deterministic dependency values over test-only branches in production code.

## Example

```swift
let store = TestStore(initialState: Feature.State()) {
  Feature()
} withDependencies: {
  $0.uuid = .incrementing
  $0.date.now = Date(timeIntervalSinceReferenceDate: 0)
  $0.apiClient.fetch = { @Sendable in .fixture }
}
```

For dependencies used outside a TestStore:

```swift
let model = withDependencies {
  $0.uuid = .incrementing
  $0.searchClient.search = { @Sendable _ in [.fixture] }
} operation: {
  SearchModel()
}
```

For async streams, give the test control over emission:

```swift
let stream = AsyncStream.makeStream(of: WebSocketEvent.self)

let store = TestStore(initialState: Chat.State()) {
  Chat()
} withDependencies: {
  $0.webSocket.events = { @Sendable in stream.stream }
}

await store.send(.task)
stream.continuation.yield(.messageReceived("hello"))
await store.receive(\.messageReceived, "hello")
stream.continuation.finish()
```

## Pitfalls

- Do not override a dependency after the effect already captured it.
- Do not use a test-only interface that differs from the live dependency interface.
- Do not share mutable fake state across tests unless it is isolated per test.
- Do not call live dependency values from tests. If the default is harmless, make the test still prove the override was used.
- Do not put mutable counters in `@Sendable` closures without isolation. Use an actor or a dependency designed for testing.

## Tests

Prove the override is used by making the live/test default fail if called.
