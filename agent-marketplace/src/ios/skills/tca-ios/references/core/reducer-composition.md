# Applies to: TCA 1.25+, iOS 16+

# Reducer Composition

## Use When

Use this when combining parent and child features, optional destinations, enum reducers, or list reducers.

## Guidance

- Use `body` with `Reduce`, `Scope`, `.ifLet`, and `.forEach`.
- Use `Scope(state:action:)` for always-present child features.
- Use `.ifLet(\.$destination, action: \.destination)` for presentation state.
- Use `.forEach(\.rows, action: \.rows)` for `IdentifiedArrayOf` child collections.
- Use `@Reducer enum Destination` and `@Reducer enum Path` for navigation domains.
- Use `CombineReducers` only when a group of reducers needs a shared modifier.
- Keep parent orchestration in the parent. Keep child-local business rules in the child.
- Route delegate actions through the parent instead of letting children mutate parent state directly.

## Ordering

Parent `Reduce` usually comes before child composition so the parent can react to child delegate actions. Follow local style when a codebase consistently does the opposite.

## Example

```swift
@Dependency(\.syncClient) var syncClient

var body: some ReducerOf<Self> {
  BindingReducer()
  Reduce { state, action in
    switch action {
    case .destination(.presented(.edit(.delegate(.saved)))):
      state.destination = nil
      state.isRefreshing = true
      return .run { [load = syncClient.load] send in
        await send(.refreshResponse(Result { try await load() }))
      }
      .cancellable(id: CancelID.refresh, cancelInFlight: true)

    case let .refreshResponse(.success(model)):
      state.model = model
      state.isRefreshing = false
      return .none

    case let .refreshResponse(.failure(error)):
      state.isRefreshing = false
      state.alert = AlertState { TextState(error.localizedDescription) }
      return .none

    default:
      return .none
    }
  }
  .ifLet(\.$destination, action: \.destination)
}
```

## Pitfalls

- Do not reach into child state from many unrelated parent cases.
- Do not duplicate child reducer logic in the parent.
- Do not leave long `switch` cases that hide unrelated features in one reducer.
- Do not use enum `Scope` forms deprecated by the installed version.
- Do not compose a child reducer and also manually run the same child logic in the parent.
- Do not start parent refresh effects from a child by passing parent clients into the child. Send a delegate action and let the parent decide.

## Tests

Test parent-child flows at the parent level when the parent coordinates navigation, shared state, or delegate actions. Test child-local behavior in the child target. For parent-owned effects started by child delegates, assert both the delegate route and the parent response path.
