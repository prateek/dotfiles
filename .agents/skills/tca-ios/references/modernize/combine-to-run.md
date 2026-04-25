# Applies to: TCA 1.25+, iOS 16+

# Combine to Effect.run

## Use When

Use this for `Effect.publisher`, `Effect.task`, Combine schedulers, old debounce/throttle operators, or 1.25 Combine deprecation warnings.

## Steps

1. Replace publisher effects with async dependency operations or `AsyncSequence`.
2. Use `.run` and send typed response actions.
3. Replace scheduler-based sleep/debounce with an injected clock and `clock.sleep`.
4. Add cancellation IDs for repeated work.
5. Move animation/transaction sends into the `.run` body when required by the installed version.

## Example

```swift
@Dependency(\.continuousClock) var clock
@Dependency(\.searchClient) var searchClient

case .queryChanged(let query):
  state.query = query
  return .run { [clock, query, search = searchClient.search] send in
    try await clock.sleep(for: .milliseconds(300))
    await send(.searchResponse(Result { try await search(query) }), animation: .default)
  }
  .cancellable(id: CancelID.search, cancelInFlight: true)
```

## Pitfalls

- Do not remove cancellation when replacing Combine operators.
- Do not translate a stream into a one-shot async call if the product expects updates.
- Do not use `Task.sleep` directly.
- Do not keep `Effect.animation`, `Effect.transaction`, `Effect.debounce`, or `Effect.throttle`
  in TCA 1.25+ code. Move animation and transaction arguments to `send` inside `.run`.

## Tests

Use `TestClock` for debounce/throttle and async streams for publisher-like dependencies. Assert stale effects do not send.
