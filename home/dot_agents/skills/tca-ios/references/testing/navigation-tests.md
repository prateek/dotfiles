# Applies to: TCA 1.25+, iOS 16+

# Navigation Tests

## Use When

Use this for sheets, alerts, stacks, deep links, dismissal, and delegate flows.

## Guidance

- Test presentation state appears after the triggering action.
- Test path mutations by asserting the whole stack shape.
- Test child delegate actions at the parent level.
- Test dismissal clears presentation state and cancels child-owned effects when relevant.
- Test deep links as route actions, not as view behavior.
- Test stack paths as domain state. Do not drive a `NavigationStack` in reducer tests.
- Test malformed routes when URLs or external inputs create navigation state.

## Sheet Delegate Example

```swift
@MainActor
@Test
func savingSettingsDismissesAndRefreshes() async {
  let store = TestStore(
    initialState: AppFeature.State(
      destination: .settings(Settings.State())
    )
  ) {
    AppFeature()
  } withDependencies: {
    $0.settingsClient.refresh = { @Sendable in .fixture }
  }

  await store.send(.destination(.presented(.settings(.delegate(.saved))))) {
    $0.destination = nil
    $0.isRefreshing = true
  }

  await store.receive(\.refreshResponse.success) {
    $0.isRefreshing = false
    $0.model = .fixture
  }
}
```

The parent test owns dismissal and refresh because the parent owns the destination and refresh dependency.

## Stack Example

```swift
await store.send(.resultTapped(result.id)) {
  $0.path.append(.detail(Detail.State(id: result.id)))
}

await store.send(.path(.element(id: 0, action: .detail(.delegate(.closed))))) {
  $0.path.removeLast()
}
```

## Pitfalls

- Do not test only that a button exists when reducer state drives navigation.
- Do not skip malformed link tests.
- Do not assert unrelated path internals when the contract is a single destination.
- Do not let a child dismiss itself by mutating parent state. The child sends a delegate or uses dismissal APIs; the parent owns parent state.
- Do not forget cancellation assertions when dismissal ends long-lived child work.

## Tests

For a sheet save flow: send open, send child edit actions if needed, send child delegate save, assert parent state, destination nil, and any refresh effect.
