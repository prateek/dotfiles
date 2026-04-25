# Applies to: TCA 1.25+, iOS 16+

# Exhaustive vs Non-Exhaustive Tests

## Use When

Use this when tests are brittle, too long, or failing because they assert implementation details.

## Guidance

- Exhaustive TestStore is the default. It proves all state changes and effect feedback are handled.
- Use non-exhaustive mode only when the test should focus on a small contract in a large composed domain.
- Keep high-risk domain logic exhaustive.
- Do not use non-exhaustive mode to hide unknown effects.
- Prefer case-path receives before turning exhaustivity off. Many brittle tests only need a better receive style.
- Keep new feature tests exhaustive unless the feature is already embedded in a large integration test.

## Good Uses

- A parent integration test that only cares that a delegate action dismisses a child.
- A smoke test around a huge root reducer where asserting every unrelated state change would obscure the behavior.
- A routing test that proves a deep link opens one destination while other root state is noisy.

## Bad Uses

- A cancellation test that ignores the effect you meant to cancel.
- A failure-path test that ignores the error response.
- A new feature test that could be exhaustive with little cost.
- A search test that ignores `isLoading` because the reducer forgot to clear it.

## Example

```swift
let store = TestStore(initialState: AppFeature.State()) {
  AppFeature()
}
await store.withExhaustivity(.off) {
  await store.send(.destination(.presented(.settings(.delegate(.saved)))))
  await store.receive(\.destination.dismiss) {
    $0.destination = nil
  }
}
```

Use this shape when the contract is the parent route. Do not use it for the child reducer's own save behavior.

## Choosing a Level

Use `.on` for reducers under active development, effect lifecycles, persistence, and bug fixes. Exhaustive failures are useful because they show the behavior you forgot to assert.

Use `.off(showSkippedAssertions: true)` while tightening a large test. It lets the test pass while still showing skipped state and action assertions in the output.

Use `.off` for narrow smoke tests around a large root reducer when the skipped behavior is deliberately outside the contract. Put that contract in the test name or a short comment.

## Case Paths First

Before turning exhaustivity off, check whether a case-path receive solves the problem:

```swift
await store.receive(\.searchResponse.failure) {
  $0.isLoading = false
}
```

That handles non-Equatable error payloads without hiding unrelated actions.

## Tests

If turning exhaustivity off, add a comment in the test naming the contract being asserted. The test should still fail if that contract breaks.
