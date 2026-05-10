# Applies to: TCA 1.25+, iOS 16+

# SQLiteData Fetching

## Use When

Use this for `@FetchAll`, `@FetchOne`, `@Fetch`, observed queries, and manual reads.

## Guidance

- Use `@FetchAll`, `@FetchOne`, or `@Fetch` for UI/model state that should track database changes.
- Use `database.read` for one-shot reads inside reducers, dependency clients, scripts, and migrations.
- Use StructuredQueries to construct queries. Avoid hand-built SQL unless the typed API cannot express the query.
- Pass animation at the fetch observation layer when observed rows should animate.
- Use `@Fetch` plus `FetchKeyRequest` when multiple queries must load from the same transaction.
- For initializer-driven dynamic queries, start with `.none` and call `.load(...)` from `.task` or a model method.
- Call `.load()` in tests or observable models when the wrapper needs explicit loading before assertions.

## Observed Rows

```swift
struct RemindersView: View {
  @FetchAll(Reminder.order(by: \.title), animation: .default)
  private var reminders

  var body: some View {
    List(reminders) { reminder in
      Text(reminder.title)
    }
  }
}
```

```swift
@Observable
@MainActor
final class RemindersModel {
  @ObservationIgnored
  @FetchAll(Reminder.none) var reminders

  func task(listID: RemindersList.ID) async throws {
    try await $reminders
      .load(Reminder.where { $0.remindersListID.eq(listID) }, animation: .default)
      .task
  }
}
```

## Multi-Query Fetch

```swift
struct DashboardRequest: FetchKeyRequest {
  struct Value {
    var incomplete: [Reminder] = []
    var completedCount = 0
  }

  func fetch(_ db: Database) throws -> Value {
    Value(
      incomplete: try Reminder.where { !$0.isCompleted }.fetchAll(db),
      completedCount: try Reminder.where(\.isCompleted).fetchCount(db)
    )
  }
}

@Fetch(DashboardRequest()) var dashboard
```

## Pitfalls

- Wrapping the write in `withAnimation` does not necessarily animate observed fetch state. Put animation where the fetch observation is configured.
- Do not perform reads on the main actor if the async database API is available and the work can suspend.
- Do not duplicate fetched rows into reducer state without a reason.
- Do not use a broad observed query when the view needs a small `@Selection`.
- Do not keep a fetch subscription alive for a screen that is no longer visible.

## Tests

Seed an isolated database, load the fetch, assert rows, perform a write, load or observe again, and assert the changed rows. Cover query arguments, ordering, empty state, and the animation-bearing load path when UI depends on it.
