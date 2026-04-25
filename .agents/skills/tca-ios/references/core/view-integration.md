# Applies to: TCA 1.25+, iOS 16+

# View Integration

## Use When

Use this when wiring SwiftUI views to stores, replacing `ViewStore`, or diagnosing broad observation.

## Guidance

- Pass `let store: StoreOf<Feature>` into the feature view.
- Read state directly from `store` in modern TCA.
- Send actions directly with `store.send(.event)`.
- Use `@Bindable var store` when deriving bindings or presentation bindings.
- Use scoped stores for child views instead of passing the whole parent store.
- Keep view-local `@State` for focus, transient animation, scroll position, and other purely visual state.
- Let reducers own work that affects domain state. Views can trigger `task`, `refreshable`, and binding events, but dependencies stay in reducers or observable models.
- Scope stores at the boundary where a child view starts. This keeps observation narrow and makes previews easier.

## Bindings

For domain bindings, make `Action` conform to `BindableAction`, add `case binding(BindingAction<State>)`, add `BindingReducer()`, and use `$store.field`.

For explicit event bindings, use `.sending`:

```swift
@Bindable var store: StoreOf<Settings>

Toggle(
  "Notifications",
  isOn: $store.notificationsEnabled.sending(\.notificationsToggled)
)
```

For search fields, prefer a named event when changing text starts cancellable work:

```swift
TextField("Search", text: $store.query.sending(\.queryChanged))
  .textInputAutocapitalization(.never)
  .autocorrectionDisabled()
```

The reducer handles `queryChanged`, sets loading state, and returns the debounced effect. The view does not call a client directly.

## Presentation

Modern presentation APIs use bindable stores:

```swift
.sheet(
  item: $store.scope(state: \.$destination, action: \.destination).edit
) { store in
  EditView(store: store)
}
```

Use the exact presentation helper that matches the installed TCA version. Do not mix old `IfLetStore` presentation with direct store observation in the same new feature.

## Pitfalls

- Avoid `WithViewStore`, `ViewStore`, `IfLetStore`, `ForEachStore`, `SwitchStore`, and `NavigationStackStore` in modern code.
- Do not run network, persistence, analytics, or database work directly from views.
- Avoid passing a root store into leaf views.
- Avoid computed view state that duplicates `@ObservableState` unless profiling proves it is needed.
- Avoid reading large parent state in a row view. Scope to the row store or pass a plain value plus event closures when the row has no reducer.
- Avoid storing a `Store` in reducer state or dependency clients.

## Tests

Reducer tests cover domain behavior. Use UI tests only for workflows that SwiftUI wiring can break, such as navigation presentation, accessibility, and platform integration.
