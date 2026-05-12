# Applies to: TCA 1.25+, iOS 16+

# Destination Enum

## Contents

- [Use When](#use-when)
- [Guidance](#guidance)
- [Example](#example)
- [Pitfalls](#pitfalls)
- [Tests](#tests)

## Use When

Use this for sheets, full-screen covers, popovers, alerts, confirmation dialogs, and mutually exclusive presented child features.

## Guidance

- Put presented state in `@Presents var destination: Destination.State?`.
- Put presentation actions in `case destination(PresentationAction<Destination.Action>)`.
- Model destinations with `@Reducer enum Destination`.
- Compose with `.ifLet(\.$destination, action: \.destination)`.
- In views, scope with projected destination state:
  `$store.scope(state: \.$destination, action: \.destination).edit`.
- For `AlertState`, `ConfirmationDialogState`, or other non-feature associated values in a
  `Destination` reducer, use the TCA 1.25 explicit-action pattern described below.
- Let children report domain events upward with delegate actions.

## Example

```swift
@Reducer
struct ItemDetail {
  @ObservableState
  struct State {
    @Presents var destination: Destination.State?
    var item: Item
  }

  enum Action {
    case deleteButtonTapped
    case deleteResponse(Result<Void, Error>)
    case destination(PresentationAction<Destination.Action>)
    case editButtonTapped
  }

  @Dependency(\.itemClient.delete) var deleteItem

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

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .editButtonTapped:
        state.destination = .edit(EditItem.State(item: state.item))
        return .none

      case .deleteButtonTapped:
        state.destination = .alert(.deleteConfirmation)
        return .none

      case .destination(.presented(.edit(.delegate(.saved(let item))))):
        state.item = item
        state.destination = nil
        return .none

      case .destination(.presented(.alert(.confirmDeleteButtonTapped))):
        return .run { [deleteItem, id = state.item.id] send in
          await send(.deleteResponse(Result { try await deleteItem(id) }))
        }

      case .deleteResponse:
        state.destination = nil
        return .none

      case .destination:
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}
```

The alert can live next to the feature:

```swift
extension AlertState where Action == ItemDetail.Destination.Alert {
  static let deleteConfirmation = Self {
    TextState("Delete item?")
  } actions: {
    ButtonState(role: .destructive, action: .confirmDeleteButtonTapped) {
      TextState("Delete")
    }
    ButtonState(role: .cancel) {
      TextState("Cancel")
    }
  }
}
```

In the view:

```swift
.sheet(
  item: $store.scope(state: \.$destination, action: \.destination).edit
) { editStore in
  EditItemView(store: editStore)
}
.alert($store.scope(state: \.$destination, action: \.destination).alert)
```

## Pitfalls

- Do not keep separate booleans and optional child state for the same presentation.
- Do not let a child directly mutate parent state.
- Do not use the pre-1.25 `\.destination?.edit` view scope form in code that has adopted the
  projected destination-scope migration.
- Do not rely on synthesized actions for non-feature prompt cases with associated actions. In
  TCA 1.25+, annotate the case with `@ReducerCaseIgnored` and define the `Destination.Action` enum
  explicitly so alerts and dialogs still route their button actions.

## Tests

Test presentation by asserting destination state appears. Test delegate save/cancel by receiving the child action at the parent and asserting dismissal or parent state changes.
