# Applies to: TCA 1.25+, iOS 16+

# Cancellation

## Use When

Use this for search, polling, subscriptions, timers, in-flight refreshes, sheet-owned work, and any effect that can outlive the triggering action.

## Guidance

- Add a nested cancellation ID enum.
- Use `.cancellable(id:cancelInFlight:)` for repeatable effects.
- Return `.cancel(id:)` when the user cancels or the feature disappears.
- Scope cancellation IDs to the feature unless the work is intentionally global.
- Tie long-lived child effects to presentation lifetime when possible.
- Use `cancelInFlight: true` for search, refresh, validation, and any request where the newest action wins.
- Clear visible loading state when cancellation is triggered by an explicit user clear or dismissal. Do not clear it merely because an older in-flight request is superseded by a newer loading request.

## Example

```swift
enum CancelID { case search }

case .queryChanged(let query):
  state.query = query
  state.errorMessage = nil

  guard !query.isEmpty else {
    state.results = []
    state.isLoading = false
    return .cancel(id: CancelID.search)
  }

  state.isLoading = true
  return .run { [query, clock, search = searchClient.search] send in
    try await clock.sleep(for: .milliseconds(300))
    await send(.searchResponse(Result { try await search(query) }))
  }
  .cancellable(id: CancelID.search, cancelInFlight: true)

case .cancelButtonTapped:
  state.isLoading = false
  return .cancel(id: CancelID.search)
```

For long-lived streams, the effect should cooperate with cancellation:

```swift
case .task:
  return .run { [events = websocket.events] send in
    for try await event in events() {
      await send(.websocketEventReceived(event))
    }
  }
  .cancellable(id: CancelID.websocket)

case .onDisappear:
  return .cancel(id: CancelID.websocket)
```

## Pitfalls

- Search without `cancelInFlight` can show stale results.
- Dismissed optional children can keep sending actions if their long-lived effects are not cancelled.
- Cancellation should clear loading state only when product behavior says the operation visibly stopped.
- If a dependency ignores task cancellation, include a request ID or query in the response and drop stale responses in the reducer.
- Do not reuse one cancellation ID for unrelated work. Cancelling search should not cancel an upload.

## Tests

Use a controllable clock or async stream. Assert that a superseded effect does not send a stale response and that dismissal leaves no running effects. Also test the explicit clear path because it usually owns the loading reset.
