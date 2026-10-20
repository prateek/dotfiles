# Applies to: TCA 1.25+, iOS 16+

# Tabs and Roots

## Contents

- [Use When](#use-when)
- [Guidance](#guidance)
- [State Shape](#state-shape)
- [Reducer Shape](#reducer-shape)
- [View Shape](#view-shape)
- [Pitfalls](#pitfalls)
- [Tests](#tests)

## Use When

Use this for tab apps, multiple navigation roots, shared tab state, and cross-tab routing.

## Guidance

- Give each tab its own feature state and reducer.
- Keep selected tab in root state.
- Keep each tab's navigation stack with that tab unless routes are global.
- Put cross-tab shared state in the root or a shared value, not in a sibling tab.
- Route deep links by selecting the tab and then setting that tab's path/destination.
- Preserve tab stacks by default. Reset only when the product says a repeated tab tap should pop to root.
- Keep global sheets and alerts above the tab feature when they can appear from any tab.
- Use delegate actions for tab children that need root coordination.
- Use `@Shared` or a root-owned dependency for state truly shared across tabs.

## State Shape

```swift
@Reducer
struct SignedInFeature {
  @ObservableState
  struct State: Equatable {
    var selectedTab = Tab.home
    var home = HomeFeature.State()
    var search = SearchFeature.State()
    var settings = SettingsFeature.State()
    @Presents var destination: Destination.State?
  }

  enum Tab: Hashable {
    case home
    case search
    case settings
  }

  enum Action {
    case selectedTabChanged(Tab)
    case home(HomeFeature.Action)
    case search(SearchFeature.Action)
    case settings(SettingsFeature.Action)
    case destination(PresentationAction<Destination.Action>)
    case deepLink(DeepLink)
  }

  @Reducer
  enum Destination {
    case profile(ProfileFeature)
  }
}
```

## Reducer Shape

```swift
var body: some ReducerOf<Self> {
  Scope(state: \.home, action: \.home) { HomeFeature() }
  Scope(state: \.search, action: \.search) { SearchFeature() }
  Scope(state: \.settings, action: \.settings) { SettingsFeature() }

  Reduce { state, action in
    switch action {
    case .selectedTabChanged(let tab):
      state.selectedTab = tab
      return .none
    case .deepLink(.search(let query)):
      state.selectedTab = .search
      state.search.path.append(.results(SearchResults.State(query: query)))
      return .none
    case .home, .search, .settings, .destination, .deepLink:
      return .none
    }
  }
  .ifLet(\.$destination, action: \.destination) {
    Destination()
  }
}
```

## View Shape

```swift
struct SignedInView: View {
  @Bindable var store: StoreOf<SignedInFeature>

  var body: some View {
    TabView(selection: $store.selectedTab.sending(\.selectedTabChanged)) {
      HomeView(store: store.scope(state: \.home, action: \.home))
        .tag(SignedInFeature.Tab.home)

      SearchView(store: store.scope(state: \.search, action: \.search))
        .tag(SignedInFeature.Tab.search)

      SettingsView(store: store.scope(state: \.settings, action: \.settings))
        .tag(SignedInFeature.Tab.settings)
    }
  }
}
```

## Pitfalls

- Do not reset a tab's stack unless the product expects it.
- Do not let one tab mutate another tab's private state directly.
- Do not use global state for tab-local details.
- Do not put every deep link in one global path if each tab already owns a path.
- Do not let root state grow into a dump of all tab internals. Scope and delegate.

## Tests

Test deep links that switch tabs, tab-local navigation persistence, repeated tab selection behavior, global presentation, and cross-tab shared-state updates.
