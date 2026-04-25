# Applies to: TCA 1.25+, iOS 16+

# Naming Conventions

## Use When

Use this when naming new features, actions, dependencies, tests, and files.

## Guidance

- Feature type: `Search`, `Settings`, `SyncUpsList`.
- State and Action stay nested unless the module exposes them intentionally.
- View type: `SearchView`, `SettingsView`.
- Test suite: `SearchTests`.
- Dependency client: `SearchClient`, `AnalyticsClient`, `DatabaseClient`.
- Dependency value key path: `\.searchClient`, `\.analytics`, `\.defaultDatabase`.
- Cancellation IDs: nested `enum CancelID { case search, subscription }`.
- Delegate enum: nested `enum Delegate { case saved(Item.ID) }`.
- Child actions: plural property names match plural action cases, such as `rows` and `case rows(IdentifiedActionOf<Row>)`.
- Effect response actions: `<work>NameResponse`, such as `searchResponse`, `refreshResponse`, or `speechResult`.
- View events: name the control and event when the interaction is specific, such as `saveButtonTapped`; name the domain event when the control is incidental, such as `queryChanged(String)`.

## Action Names

Use event names:

- `saveButtonTapped`
- `queryChanged(String)`
- `searchResponse(Result<[Result], any Error>)`
- `delegate(Delegate)`
- `destination(PresentationAction<Destination.Action>)`
- `rows(IdentifiedActionOf<Row>)`

Avoid command names:

- `save`
- `fetch`
- `update`
- `didTap`
- `requestSearch`
- `setLoading`

## Pitfalls

- Do not use `New`, `Improved`, `Modern`, or `Enhanced` in code names.
- Do not encode migration history into names.
- Avoid abbreviations unless the codebase already uses them.
- Do not use `Reducer` suffixes for reducer types.
- Do not name a dependency after its transport if the reducer only cares about a domain capability. Prefer `searchClient` over `httpClient` in a search feature.
- Do not make every child action singular. Match the state field and reducer composition: `rows` with `IdentifiedArrayOf`, `destination` with presentation state, `path` with stack state.

## File Names

Use the feature name for the reducer file and append `View` for the SwiftUI view when the codebase splits them:

```text
Search.swift
SearchView.swift
SearchTests.swift
```

If a feature has small dependency clients or fixtures, keep names domain-specific:

```text
SearchClient.swift
SearchResult.swift
SearchFixtures.swift
```
