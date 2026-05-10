# Applies to: TCA 1.25+, iOS 16+

# Modern SwiftUI

## Contents

- [Use When](#use-when)
- [Guidance](#guidance)
- [View Shape](#view-shape)
- [Local UI State](#local-ui-state)
- [High-Frequency Input](#high-frequency-input)
- [Pitfalls](#pitfalls)
- [Tests](#tests)

## Use When

Use this for SwiftUI views, action closures, bindings, tasks, and local state choices.

## Guidance

- Keep domain decisions in reducers.
- Use `Button` and gesture closures to send clear actions.
- Use `.task { await store.send(.task).finish() }` only when the feature models task lifecycle that way.
- Use local `@State` for focus, scroll, animation, and transient visual details.
- Use `@Bindable var store` only when bindings are needed.
- Observe state directly from `StoreOf<Feature>` in modern TCA. Avoid `WithViewStore` and `ViewStore`.
- Use `@ObservableState` in reducer state so direct store observation is precise.
- Scope child stores close to the view that renders the child.
- For iOS 16 targets, use the back-deploy perception wrapper where required by the migration guide.
- Use `BindingReducer` and binding actions only for real two-way form state.

## View Shape

```swift
struct SettingsView: View {
  @Bindable var store: StoreOf<SettingsFeature>

  var body: some View {
    Form {
      Toggle(
        "Reduce motion",
        isOn: $store.reduceMotion
      )

      Button("Save") {
        store.send(.saveButtonTapped)
      }
      .disabled(!store.canSave)
    }
    .task {
      await store.send(.task).finish()
    }
  }
}
```

```swift
@Reducer
struct SettingsFeature {
  @ObservableState
  struct State: Equatable {
    @BindingState var reduceMotion = false
    var canSave = false
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case task
    case saveButtonTapped
  }

  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        state.canSave = true
        return .none
      case .task, .saveButtonTapped:
        return .none
      }
    }
  }
}
```

## Local UI State

Keep focus, scroll position, hover, selected text range, animation flags, and one-frame gesture state local unless the reducer must test or coordinate them.

```swift
@FocusState private var focusedField: Field?
@State private var scrollPosition: Reminder.ID?
```

## High-Frequency Input

Do not dispatch on every scroll tick, drag update, or text-editing character unless reducer logic needs every event. Keep visual feedback local and send a debounced or committed action for product state.

## Pitfalls

- Do not start networking from views.
- Do not hide product state in `@State`.
- Do not send high-frequency actions without debounce, batching, or local-only state.
- Do not pass parent stores deeply into leaf views.
- Do not create computed `ViewState` structs in modern TCA unless profiling proves direct observation is too broad.
- Do not use `@Bindable` when the view only reads state and sends actions.
- Do not trigger reentrant actions from synchronous view update hooks.

## Tests

Reducer tests cover product behavior. Add UI tests for wiring, accessibility, platform presentation details, and workflows where SwiftUI modifiers are the integration point.
