# Applies to: TCA 1.25+, iOS 16+

# Shared State

## Use When

Use this for `@Shared`, `@SharedReader`, app storage, file storage, in-memory shared values, or shared parent-to-child values.

## Guidance

- Use `@Shared` when two or more features must mutate the same value and immediately observe each other's changes.
- Use `@SharedReader` for read-only shared values.
- Use `.appStorage` for small preference-like values. Avoid secrets and complex domain data.
- Use `.fileStorage` for Codable values that should survive launches but do not need relational queries.
- Use `.inMemory` for app-wide state that should reset on launch.
- Conform a custom type to `SharedKey` (or `SharedReaderKey` for read-only) when none of the built-in strategies fit, for example a Keychain-backed credential or a remote-config stream. The custom key owns the load/save behavior; the rest of the API works the same as the built-ins.
- Use unkeyed `@Shared` to pass a reference-like value from parent state to child state.
- Derive child shared values from the projected parent value, for example `state.$settings.reduceMotion`.
- Use `Binding($shared)` to bind a shared value in SwiftUI.
- Prefer Observation and `Observations` over Combine publishers.
- For SQLite-backed domain data, use SQLiteData instead of forcing relational data into `@Shared`.

## Patterns

```swift
@Shared(.appStorage("reduceMotion")) var reduceMotion = false
@Shared(.fileStorage(settingsURL)) var settings = Settings()
@Shared(.inMemory("session")) var session: Session?
@Shared var currentUser: User?
```

```swift
Toggle("Reduce motion", isOn: Binding($reduceMotion))
Child.State(settings: state.$settings)
```

```swift
@Reducer
struct Parent {
  @ObservableState
  struct State {
    @Shared var settings: Settings
    @Presents var child: Child.State?
  }

  enum Action {
    case editButtonTapped
    case child(PresentationAction<Child.Action>)
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .editButtonTapped:
        state.child = Child.State(settings: state.$settings)
        return .none
      case .child:
        return .none
      }
    }
    .ifLet(\.$child, action: \.child) {
      Child()
    }
  }
}
```

## Observable Models

When an `@Observable` model owns shared state, hide the wrapper from observation:

```swift
@Observable
@MainActor
final class SettingsModel {
  @ObservationIgnored
  @Shared(.appStorage("reduceMotion")) var reduceMotion = false
}
```

Unwrap optional shared state through the projected value when the child needs a non-optional shared value:

```swift
if let currentUser = Shared($currentUser) {
  Profile.State(currentUser: currentUser)
}
```

## Pitfalls

- Do not copy a shared value into plain state and expect updates to propagate.
- Do not use invalid user-defaults keys.
- Do not use `@Shared` for every parent-child value. Plain state is simpler when only one owner mutates it.
- Do not store secret material in user defaults.
- Do not treat `@Shared` as a global escape hatch. Name the shared source of truth and keep ownership clear.
- Do not use Combine observation in new code unless the app still has a concrete Combine boundary.

## Tests

Use isolated storage and deterministic keys. Verify that mutation through one holder is visible through another holder. For persisted strategies, reconstruct the state and assert the value survives. For parent-to-child shared values, assert the parent state changes after the child mutates the projected shared value.
