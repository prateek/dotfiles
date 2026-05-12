# Applies to: TCA 1.25+, iOS 16+

# Sheets, Alerts, and Dialogs

## Use When

Use this for SwiftUI presentation modifiers driven by TCA state.

## Guidance

- Use `@Bindable var store` in the view when binding presentation.
- Use `sheet(item:)`, `fullScreenCover(item:)`, `popover(item:)`, `alert`, and `confirmationDialog` against scoped store bindings.
- Keep alerts and dialogs in the destination enum when they are part of the feature flow.
- Use projected destination scopes for enum-based presentation:
  `$store.scope(state: \.$destination, action: \.destination).caseName`.
- For non-feature prompt state in reducer enums, TCA 1.25+ needs `@ReducerCaseIgnored` and an
  explicit `Destination.Action` enum when the prompt carries actions.

## Example

```swift
.sheet(
  item: $store.scope(state: \.$destination, action: \.destination).edit
) { editStore in
  EditView(store: editStore)
}

.alert($store.scope(state: \.$destination, action: \.destination).alert)

.confirmationDialog(
  $store.scope(state: \.$destination, action: \.destination).discardDialog
)
```

## Pitfalls

- Do not use legacy `sheet(store:)` APIs in modern TCA.
- Do not use old enum-case scopes such as `state: \.destination?.edit` once the codebase is on the
  1.25 projected-scope style.
- Do not model an alert with both a boolean and an alert state.
- Do not put irreversible destructive logic only in the view's button closure. Send an action.

## Tests

Assert alert/dialog state after the triggering action. Then send the presentation action for the tapped button and assert the resulting state or effect.
