# Applies to: TCA 1.25+, iOS 16+

# UIKit Interop

## Contents

- [Use When](#use-when)
- [Guidance](#guidance)
- [Basic Controller](#basic-controller)
- [Bindings And Presentation](#bindings-and-presentation)
- [Stack Controller](#stack-controller)
- [SwiftUI Bridge](#swiftui-bridge)
- [Pitfalls](#pitfalls)
- [Tests](#tests)

## Use When

Use this for SwiftUI views inside UIKit, UIKit controllers inside SwiftUI, or TCA stores driving UIKit screens.

## Guidance

- Keep the feature reducer independent of UI framework.
- Use `observe` for UIKit state observation.
- Use SwiftUI hosting controllers only as a boundary adapter.
- Use `@UIBindable` for UIKit presentation bindings where the navigation API expects it.
- Send actions from target/action, delegate callbacks, and lifecycle methods.
- Import `ComposableArchitecture` in TCA UIKit controllers. Import `UIKitNavigation` when using swift-navigation outside TCA.
- Call `observe` from `viewDidLoad` and access only the state that should invalidate that block.
- Use `[weak self]` in observation closures to avoid retaining controllers.
- Use `present(item:)`, `navigationDestination(item:)`, or `NavigationStackController` for state-driven UIKit navigation.
- Keep UIKit coordinator state as adapter state only. Reducer state owns product navigation.

## Basic Controller

```swift
final class CounterViewController: UIViewController {
  private let store: StoreOf<Counter>

  init(store: StoreOf<Counter>) {
    self.store = store
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    let countLabel = UILabel()
    let incrementButton = UIButton(type: .system)
    incrementButton.addTarget(
      self,
      action: #selector(incrementButtonTapped),
      for: .touchUpInside
    )

    observe { [weak self] in
      guard let self else { return }
      countLabel.text = "\(store.count)"
    }
  }

  @objc private func incrementButtonTapped() {
    store.send(.incrementButtonTapped)
  }
}
```

## Bindings And Presentation

```swift
final class NewGameViewController: UIViewController {
  @UIBindable var store: StoreOf<NewGame>

  init(store: StoreOf<NewGame>) {
    self.store = store
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    let playerNameTextField = UITextField(text: $store.playerName)

    observe { [weak self] in
      guard let self else { return }
      navigationItem.rightBarButtonItem?.isEnabled = store.canStartGame
    }

    navigationDestination(
      item: $store.scope(state: \.game, action: \.game)
    ) { store in
      GameViewController(store: store)
    }
  }
}
```

## Stack Controller

Use `NavigationStackController` when the reducer owns a `StackState`.

```swift
final class AppController: NavigationStackController {
  private var store: StoreOf<AppFeature>!

  convenience init(store: StoreOf<AppFeature>) {
    @UIBindable var store = store

    self.init(path: $store.scope(state: \.path, action: \.path)) {
      RootViewController(store: store)
    } destination: { store in
      switch store.case {
      case .detail(let store):
        DetailViewController(store: store)
      case .edit(let store):
        EditViewController(store: store)
      }
    }

    self.store = store
  }
}
```

## SwiftUI Bridge

```swift
struct SettingsControllerView: UIViewControllerRepresentable {
  let store: StoreOf<SettingsFeature>

  func makeUIViewController(context: Context) -> SettingsViewController {
    SettingsViewController(store: store)
  }

  func updateUIViewController(
    _ viewController: SettingsViewController,
    context: Context
  ) {}
}
```

## Pitfalls

- Do not let UIKit controllers mutate reducer state directly.
- Do not create parallel UIKit coordinator state for reducer-owned navigation.
- Do not keep stores alive through accidental retain cycles in closures.
- Do not observe the whole store in one large block if separate UI regions can update independently.
- Do not imperatively push a controller and also bind the same route through `navigationDestination`.
- Do not hide lifecycle effects in controllers when reducer tests need to cover them. Send lifecycle actions.

## Tests

Reducer behavior remains platform-independent. Add controller tests or UI tests for adapter wiring, UIKit binding, presentation, and lifecycle actions.
