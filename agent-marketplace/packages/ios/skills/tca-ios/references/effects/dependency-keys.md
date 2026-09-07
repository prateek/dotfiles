# Applies to: TCA 1.25+, iOS 16+

# Dependency Keys

## Use When

Use this when defining a new dependency client or fixing a dependency that is hard to test.

## Guidance

- Model the client as a small `Sendable` struct of function properties.
- Give live implementations real behavior.
- Give test implementations failing or unimplemented defaults unless a harmless deterministic default exists.
- Give preview implementations fast deterministic data.
- Use `DependencyKey` for the concrete key and `DependencyValues` for access.
- Keep `liveValue`, `testValue`, and `previewValue` close to the client unless the package has an established dependency module.
- `DependencyKey` already conforms to the testing dependency protocol; do not add a second conformance for the same type.

## Values

`liveValue` should be production-safe and concurrency-safe.

`testValue` should make accidental live calls fail loudly. Override it in each test that needs behavior.

`previewValue` should make previews useful without network, file, or account setup.

## Example

```swift
struct SearchClient: Sendable {
  var search: @Sendable (String) async throws -> IdentifiedArrayOf<SearchResult>
}

extension SearchClient: DependencyKey {
  static let liveValue = SearchClient(
    search: { query in
      try await LiveSearchAPI().results(matching: query)
    }
  )

  static let previewValue = SearchClient(
    search: { query in
      [
        SearchResult(id: "preview-\(query)", title: "Preview \(query)")
      ]
    }
  )

  static let testValue = SearchClient(
    search: unimplemented("SearchClient.search")
  )
}

extension DependencyValues {
  var searchClient: SearchClient {
    get { self[SearchClient.self] }
    set { self[SearchClient.self] = newValue }
  }
}
```

If `LiveSearchAPI` is not `Sendable`, hide it behind an actor or make the operation build a fresh request value instead of capturing the object in a `@Sendable` closure.

## Pitfalls

- Avoid dependency clients that expose raw SDK objects everywhere.
- Avoid mutable shared state unless protected by an actor, lock, or isolated dependency implementation.
- Avoid synchronous blocking work inside async dependency operations.
- Avoid global variables as hidden dependency storage.
- Avoid `fatalError` in live dependency paths. Use thrown errors or issue reporting for recoverable failures.
- Avoid harmless test defaults for operations that should always be arranged by a test. Silent defaults hide missing coverage.

## Tests

If a reducer can reach the dependency, a test should prove the dependency can be overridden. For effectful dependencies, assert both success and failure paths when product behavior differs.
