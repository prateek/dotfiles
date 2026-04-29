# Applies to: TCA 1.25+, iOS 16+

# Legacy Navigation to Destination

## Use When

Use this when migrating booleans, optional child state, `@PresentationState`, `IfLetStore`, or `NavigationStackStore`.

## Steps

1. Identify each presentation and whether it is mutually exclusive.
2. Introduce `@Presents var destination: Destination.State?` for tree presentation.
3. Introduce `@Reducer enum Destination` with cases for feature destinations and prompt state.
4. Replace presentation actions with `PresentationAction`.
5. For `AlertState`, `ConfirmationDialogState`, or other non-feature cases that carry actions,
   add `@ReducerCaseIgnored` and define `@CasePathable enum Destination.Action` explicitly.
6. Replace legacy view helpers with SwiftUI presentation modifiers bound to projected destination
   scopes.
7. Use `StackState` and path reducers for push navigation.

## Example

```swift
@Reducer
enum Destination {
  case edit(EditItem)

  @ReducerCaseIgnored
  case alert(AlertState<Alert>)

  @CasePathable
  enum Action {
    case edit(EditItem.Action)
    case alert(Alert)
  }

  enum Alert {
    case confirmDeleteButtonTapped
  }
}

.sheet(
  item: $store.scope(state: \.$destination, action: \.destination).edit
) { editStore in
  EditItemView(store: editStore)
}
.alert($store.scope(state: \.$destination, action: \.destination).alert)
```

## Pitfalls

- Do not migrate stack flows into modal destination state.
- Do not keep old booleans around after destination state owns presentation.
- Do not keep old `IfLetStore`, `NavigationStackStore`, `sheet(store:)`, or
  `state: \.destination?.caseName` scopes in migrated modern code.

## Tests

Add presentation, dismissal, delegate, and deep-link tests for migrated flows.
