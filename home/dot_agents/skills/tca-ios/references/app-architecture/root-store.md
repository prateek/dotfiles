# Applies to: TCA 1.25+, iOS 16+

# Root Store

## Contents

- [Use When](#use-when)
- [Guidance](#guidance)
- [Shape](#shape)
- [Pitfalls](#pitfalls)
- [Tests](#tests)

## Use When

Use this for `@main`, `AppFeature`, dependency preparation, database bootstrap, app lifecycle, and root composition.

## Guidance

- Keep `@main` responsible for dependency preparation and root store construction.
- Model app-wide behavior in an `AppFeature`.
- Put session gates, tabs, app routes, and global presentation in root state.
- Bootstrap persistence before features that read from it are created.
- Keep leaf business logic out of the root reducer.
- Create the root `Store` once at the app boundary unless the product truly has separate independent state machines.
- For iOS 16 support, wrap SwiftUI roots that observe TCA state in `WithPerceptionTracking` when the app targets pre-iOS-17. See `references/back-deploy/ios16-perception.md`.
- Keep startup sequencing explicit: configure dependencies, construct root store, render root view.
- If using SQLiteData, call `bootstrapDatabase` from `prepareDependencies` before constructing any `@Fetch` or database-backed observable model.
- Do not present any sample app as a SQLiteData bootstrap example unless a fresh source read shows those exact APIs in use. This reference gives the pattern directly.

## Shape

```swift
import ComposableArchitecture
import Dependencies
import SwiftUI

@main
struct MyApp: App {
  private let store: StoreOf<AppFeature>

  init() {
    prepareDependencies {
      try! $0.bootstrapDatabase()
    }
    store = Store(initialState: AppFeature.State()) {
      AppFeature()
    }
  }

  var body: some Scene {
    WindowGroup {
      AppView(store: store)
    }
  }
}
```

```swift
@Reducer
struct AppFeature {
  @ObservableState
  struct State: Equatable {
    var signedIn = SignedInFeature.State()
    @Presents var destination: Destination.State?
  }

  enum Action {
    case task
    case signedIn(SignedInFeature.Action)
    case destination(PresentationAction<Destination.Action>)
    case scenePhaseChanged(ScenePhase)
  }

  @Reducer
  enum Destination {
    case settings(SettingsFeature)
  }

  var body: some ReducerOf<Self> {
    Scope(state: \.signedIn, action: \.signedIn) {
      SignedInFeature()
    }
    Reduce { state, action in
      switch action {
      case .task:
        return .none
      case .signedIn(.delegate(.showSettings)):
        state.destination = .settings(SettingsFeature.State())
        return .none
      case .signedIn, .destination, .scenePhaseChanged:
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination) {
      Destination()
    }
  }
}
```

Use enum root state when the app has mutually exclusive modes; see `session-auth.md` for that route shape. Use struct root state when tabs, global sheets, and session state coexist.

## Pitfalls

- Do not make a root reducer a catch-all for leaf actions.
- Do not create multiple unrelated root stores unless the app has separate state machines by design.
- Do not run bootstrapping after views have already read dependencies.
- Do not put live client construction in leaf reducers.
- Do not let a root reducer reach through child internals for ordinary feature work. Use delegate actions.
- Do not force every app mode into optionals and booleans when an enum describes the state machine.

## Tests

Test root routing, session transitions, tab coordination, deferred deep links, and bootstrap-dependent flows at the root. Root tests should prove the app chooses the right child state and forwards child delegate actions correctly.
