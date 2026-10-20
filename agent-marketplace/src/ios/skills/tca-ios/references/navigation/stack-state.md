# Applies to: TCA 1.25+, iOS 16+

# Stack State

## Use When

Use this for push navigation, drill-down flows, heterogeneous routes, and deep-linkable stacks.

## Guidance

- Store stack path as `var path = StackState<Path.State>()`.
- Route actions with `case path(StackActionOf<Path>)`.
- Model path elements with `@Reducer enum Path`.
- Compose with `.forEach(\.path, action: \.path)` for a `@Reducer enum Path`.
- Drive SwiftUI with `NavigationStack(path: $store.scope(state: \.path, action: \.path))`.
- In the destination closure, switch over `store.case` and pass the scoped store to each child view.

## Example

```swift
@Reducer
struct AppFeature {
  @ObservableState
  struct State {
    var path = StackState<Path.State>()
  }

  enum Action {
    case path(StackActionOf<Path>)
    case settingsButtonTapped
  }

  @Reducer
  enum Path {
    case detail(Detail)
    case settings(Settings)
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .settingsButtonTapped:
        state.path.append(.settings(Settings.State()))
        return .none

      case .path:
        return .none
      }
    }
    .forEach(\.path, action: \.path)
  }
}

struct AppView: View {
  @Bindable var store: StoreOf<AppFeature>

  var body: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
      RootView(store: store)
    } destination: { store in
      switch store.case {
      case .detail(let store):
        DetailView(store: store)
      case .settings(let store):
        SettingsView(store: store)
      }
    }
  }
}
```

## Pitfalls

- Do not split one push flow between local SwiftUI path state and TCA path state.
- Do not make a path enum know about unrelated app roots.
- Do not push raw model values when a child feature has behavior; push child state.
- Do not use `NavigationStackStore` in modern code.

## Tests

Send the action that appends to the path and assert the correct path element. For deep links, assert the whole path, not only the final screen.
