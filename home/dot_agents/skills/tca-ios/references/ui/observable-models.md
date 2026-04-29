# Applies to: TCA 1.25+, iOS 16+

# Observable Models

## Contents

- [Use When](#use-when)
- [Guidance](#guidance)
- [Shape](#shape)
- [Optional Presentation](#optional-presentation)
- [Identity Conformance](#identity-conformance)
- [SQLiteData Fetches](#sqlitedata-fetches)
- [Pitfalls](#pitfalls)
- [Tests](#tests)

## Use When

Use this for small features that use `@Observable` models instead of reducers, or for deciding a mixed architecture boundary.

## Guidance

- Use `@Observable` for reference models that own small, cohesive behavior.
- Put dependencies in models with `@ObservationIgnored @Dependency`.
- Avoid heavy work in initializers; start async work from a task method.
- Use identity-based `Equatable`, `Hashable`, or `Identifiable` only when object identity is the contract.
- Use optional child models for presentation when not using TCA navigation.
- Mark UI-owned models `@MainActor` unless the model has a specific non-main actor.
- Name methods after user events: `saveButtonTapped`, not `save`.
- Make methods `async` when the work is async. Let the view create the `Task`.
- Use `withDependencies` in tests around model construction and method calls.
- Use `@ObservationIgnored` on `@FetchAll`, `@FetchOne`, and `@Fetch` wrappers in models.

## Shape

```swift
@Observable
@MainActor
final class SearchModel {
  var query = ""
  var results: [SearchResult] = []
  var isLoading = false
  var alert: String?

  @ObservationIgnored
  @Dependency(\.searchClient) var searchClient

  func searchButtonTapped() async {
    isLoading = true
    defer { isLoading = false }

    do {
      results = try await searchClient.search(query)
    } catch {
      alert = "Search failed."
    }
  }
}
```

```swift
Button("Search") {
  Task { await model.searchButtonTapped() }
}
```

## Optional Presentation

```swift
@Observable
@MainActor
final class ParentModel {
  var child: ChildModel?

  func addButtonTapped() {
    child = ChildModel()
  }
}

@Observable
@MainActor
final class ChildModel: Identifiable {}
```

```swift
.sheet(item: $model.child) { child in
  ChildView(model: child)
}
```

## Identity Conformance

```swift
extension ChildModel: Equatable, Hashable {
  static func == (lhs: ChildModel, rhs: ChildModel) -> Bool {
    lhs === rhs
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}
```

Use object identity when identity is the contract. Do not hash mutable model data.

`Identifiable` on a class is synthesized by Swift for free: the default `id` is `ObjectIdentifier(self)`, which matches the `===` and `ObjectIdentifier`-based `Equatable`/`Hashable` shown above. Add an explicit `id` only when the model has a stable domain ID (for example, a database row ID) and `===` is the wrong contract.

## SQLiteData Fetches

```swift
@Observable
@MainActor
final class RemindersModel {
  @ObservationIgnored
  @FetchAll(Reminder.none) var reminders

  func task(listID: RemindersList.ID) async throws {
    try await $reminders.load(
      Reminder.where { $0.remindersListID.eq(listID) }
    )
  }
}
```

## Pitfalls

- Do not duplicate a TCA feature's state in an observable model.
- Do not store `@Dependency` fields as observed state.
- Do not choose observable models for flows that need exhaustive reducer tests.
- Do not start unstructured tasks inside model methods when the caller can `await`.
- Do not perform database/network work in initializers.
- Do not use observable models to dodge established TCA boundaries inside a TCA feature.

## Tests

Use `withDependencies` around model construction and method calls. Assert observable state after async methods complete, including loading, success, failure, and presentation state.
