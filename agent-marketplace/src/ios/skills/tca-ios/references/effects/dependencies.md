# Applies to: TCA 1.25+, iOS 16+

# Dependencies

## Use When

Use this when a reducer needs time, randomness, networking, persistence, analytics, permissions, notifications, files, or SDK access.

## Guidance

- Access dependencies with `@Dependency` in reducers.
- In observable classes, use `@ObservationIgnored @Dependency`.
- Override dependencies with `withDependencies` in tests and previews, or with reducer `.dependency` for scoped runtime composition.
- Make clients domain-specific. A reducer should call `searchClient.results(query)`, not build URL requests.
- Keep dependency operations `Sendable` and async-safe.
- Put dependency construction at the boundary. Reducers consume clients; live clients talk to URLSession, databases, SDKs, file systems, and analytics services.
- Prefer small clients with a few operations over one broad app client.

## Example

```swift
struct SearchClient: Sendable {
  var search: @Sendable (String) async throws -> IdentifiedArrayOf<SearchResult>
}

extension SearchClient: DependencyKey {
  static let liveValue = Self(
    search: { query in
      var components = URLComponents(string: "https://api.example.com/search")!
      components.queryItems = [URLQueryItem(name: "q", value: query)]
      let (data, _) = try await URLSession.shared.data(from: components.url!)
      return try JSONDecoder().decode(IdentifiedArrayOf<SearchResult>.self, from: data)
    }
  )
}

extension DependencyValues {
  var searchClient: SearchClient {
    get { self[SearchClient.self] }
    set { self[SearchClient.self] = newValue }
  }
}
```

Reducers capture operations, not clients, when returning effects:

```swift
return .run { [query = state.query, search = searchClient.search] send in
  await send(.searchResponse(Result { try await search(query) }))
}
```

## Override Shape

Use the same dependency surface in tests:

```swift
let store = TestStore(initialState: Search.State()) {
  Search()
} withDependencies: {
  $0.searchClient.search = { @Sendable query in
    [SearchResult(id: query, title: query)]
  }
}
```

Do not add a mock mode to the reducer. Override the real dependency value.

## Pitfalls

- Do not call `URLSession.shared`, `Date()`, `UUID()`, `Task.sleep`, `UserDefaults.standard`, or SDK singletons directly from reducers.
- Do not make one huge `AppEnvironment` client.
- Do not hide failure by returning empty values unless that is the product behavior.
- Do not invent alternate testing interfaces; tests should override the real dependency value.
- Do not capture non-Sendable SDK objects in `@Sendable` closures without an actor, lock, or other isolation strategy.
- Do not let previews or tests hit live services.

## Tests

Use `withDependencies` or `TestStore` dependency overrides. Control `uuid`, `date`, and `continuousClock` for deterministic tests. Make the default test value fail loudly when an override is required.
