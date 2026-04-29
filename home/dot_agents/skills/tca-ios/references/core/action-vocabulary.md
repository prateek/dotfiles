# Applies to: TCA 1.25+, iOS 16+

# Action Vocabulary

## Use When

Use this when adding actions, reviewing reducers, or untangling action ping-pong.

## Taxonomy

- User events: `saveButtonTapped`, `queryChanged(String)`, `rowSwiped`.
- Lifecycle events: `task`, `onAppear`, `onDisappear`, `scenePhaseChanged`.
- Effect responses: `searchResponse(Result<[Item], any Error>)`, `timerTicked`.
- Binding actions: `case binding(BindingAction<State>)`.
- Child routing: `case rows(IdentifiedActionOf<Row>)`, `case destination(PresentationAction<Destination.Action>)`.
- Delegate actions: `case delegate(Delegate)` with nested `enum Delegate { case saved(Item.ID) }`.

## Guidance

- Name actions as events that happened, not commands the reducer should perform.
- Keep internal sequencing actions rare. If an action only exists to bounce from one reducer to another, consider a helper method or a delegate action.
- Use delegate actions when a child reports a domain event to its parent.
- Use response actions for async outcomes, including failures that affect UI or retry behavior.
- Keep effect result payloads domain-specific. Avoid leaking raw SDK response types through many reducers.
- Prefer a single response action with `Result<Success, any Error>` when success and failure are two outcomes of the same request.
- Split response actions only when success and failure have different lifecycles or different callers.
- Include a correlation value in the response when the dependency cannot reliably cooperate with cancellation, for example `searchResponse(query: String, Result<...>)`.

## Search Example

```swift
enum Action {
  case queryChanged(String)
  case searchResponse(Result<IdentifiedArrayOf<SearchResult>, any Error>)
}
```

The action names describe what happened. `queryChanged` comes from the view. `searchResponse` comes from the effect. The reducer decides how to mutate state:

```swift
case let .searchResponse(.success(results)):
  state.results = results
  state.isLoading = false
  state.errorMessage = nil
  return .none

case let .searchResponse(.failure(error)):
  state.isLoading = false
  state.errorMessage = error.localizedDescription
  return .none
```

This shape deliberately does not require `Action: Equatable`. Tests can receive `\.searchResponse.success` or `\.searchResponse.failure`.

## Pitfalls

- `case update`, `case changed`, and `case didTap` are too vague once the feature grows.
- `case parentDidSomething` inside a child usually means the child knows too much about its parent.
- Actions should not embed closures, stores, tasks, or view objects.
- Avoid command names such as `performSearch` or `loadData`. Reducers react to events, then decide whether to start work.
- Avoid unhandled response actions. If an effect sends an action, the reducer should document the state transition even when the transition is intentionally empty.

## Tests

Tests should read like a user or system script: send an event, receive a result, assert state. If a test has many opaque internal actions, the vocabulary probably needs work.
