# Applies to: TCA 1.25+, iOS 16+

# Effect.run

## Use When

Use this when returning async work from a reducer.

## Guidance

- Return `.run` for async work that sends results back into the reducer.
- Capture values and dependency functions explicitly in the capture list.
- Send a response action with `Result` when work can fail.
- Use `await send(..., animation:)` when the response should animate.
- Keep fire-and-forget effects rare and intentional.
- Mutate loading, error, and optimistic state before returning the effect. Mutate final state when the response action is received.
- Prefer one response action per request so tests can assert the whole request lifecycle.

## Example

```swift
@Dependency(\.syncClient) var syncClient

case .refreshButtonTapped:
  state.isLoading = true
  state.errorMessage = nil
  return .run { [id = state.id, refresh = syncClient.refresh] send in
    await send(.refreshResponse(Result {
      try await refresh(id)
    }))
  }
  .cancellable(id: CancelID.refresh, cancelInFlight: true)

case let .refreshResponse(.success(model)):
  state.model = model
  state.isLoading = false
  return .none

case let .refreshResponse(.failure(error)):
  state.isLoading = false
  state.errorMessage = error.localizedDescription
  return .none
```

## Capture Rules

Capture only what the effect needs:

```swift
return .run { [query = state.query, clock, search = searchClient.search] send in
  try await clock.sleep(for: .milliseconds(300))
  await send(.searchResponse(Result { try await search(query) }))
}
```

This shape avoids implicit `self` capture in Swift 6 mode, keeps the request tied to the query that triggered it, and makes dependency overrides clear in tests.

For fire-and-forget work, still capture dependencies explicitly:

```swift
return .run { [track = analytics.track] _ in
  await track(.saveTapped)
}
```

Use fire-and-forget only when no reducer state depends on the outcome.

## Pitfalls

- Do not mutate state inside the effect closure. Send an action instead.
- Do not capture all of `state` when one ID or query string is enough.
- Do not capture `self` implicitly when Swift 6 warns. Capture dependency functions or immutable dependency values.
- Avoid old Combine effect operators in new code.
- Do not start an effect that can fail without a response action unless the failure is intentionally invisible to the product.
- Do not turn loading on without a matching success, failure, cancel, or clear path.

## Tests

For each effect, assert the state change caused by the initiating action, then assert the received response action. Override dependencies to avoid real services. For `Result<Success, any Error>` responses, prefer `await store.receive(\.refreshResponse.success)` or `await store.receive(\.refreshResponse.failure)` over forcing `Action: Equatable`.
