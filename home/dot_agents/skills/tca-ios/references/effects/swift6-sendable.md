# Applies to: TCA 1.25+, iOS 16+

# Swift 6 Sendable

## Use When

Use this when Swift 6 language mode, strict concurrency, `.run`, `onChange`, `ifLet`, bindings, or dependency clients produce Sendable warnings.

## Guidance

- Treat `.run` closures as Sendable boundaries.
- Capture dependency functions and value IDs explicitly.
- Mark reducer types `Sendable` when their stored dependencies and fields can support it.
- Make dependency client structs `Sendable` and function properties `@Sendable`.
- Keep UI-only store usage on the main actor.
- Use unchecked wrappers only as a documented local bridge, not as the first answer.
- Prefer moving non-Sendable live objects behind actors over weakening concurrency checks throughout the feature.
- Build the touched target in Swift 6 language mode when the task is a Swift 6 migration.

## Common Fixes

- Replace implicit `self` captures with dependency function captures: `[refresh = syncClient.refresh]`, `[search = searchClient.search]`, `[clock]`.
- Move mutable shared state inside an actor, lock, or isolated dependency.
- Split non-Sendable SDK adapters behind Sendable client functions.
- Prefer value payloads in actions.
- Extract large mutable state before returning `.run`: `[id = state.id, query = state.query]`.
- Convert callback APIs to `AsyncStream` or `AsyncThrowingStream` in a dependency, then iterate the stream in the reducer effect.

## Capture Example

Use explicit captures at the effect boundary:

```swift
return .run { [query = state.query, clock, search = searchClient.search] send in
  try await clock.sleep(for: .milliseconds(300))
  await send(.searchResponse(Result { try await search(query) }))
}
```

If the reducer stores only Sendable dependencies and no non-Sendable fields, adding `Sendable` to the reducer can be reasonable:

```swift
@Reducer
struct Search: Sendable {
  @Dependency(\.searchClient) var searchClient
  @Dependency(\.continuousClock) var clock
}
```

Do this to satisfy real compiler diagnostics, not as decoration.

## Pitfalls

- `@preconcurrency import` hides warnings and should be temporary.
- `Task.detached` often makes isolation worse.
- Capturing a `Store` in a Sendable closure is usually the wrong shape.
- Capturing an entire dependency client can still be fine when the client is `Sendable`, but capturing the function documents the effect boundary better.
- Adding `@unchecked Sendable` to SDK wrappers without an isolation story moves the bug to runtime.

## Tests

Build the affected target in Swift 6 mode when possible. Add reducer tests around any migration that changes action timing or cancellation.
