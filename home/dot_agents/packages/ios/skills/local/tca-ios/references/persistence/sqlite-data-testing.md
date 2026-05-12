# Applies to: TCA 1.25+, iOS 16+

# SQLiteData Testing

## Use When

Use this for deterministic tests involving SQLiteData, StructuredQueries, observed fetches, or database-generated IDs.

## Guidance

- Bootstrap a fresh isolated database per test or suite.
- Link `DependenciesTestSupport` in the test target.
- Use throwing dependency traits where available.
- Register a database `uuid()` function that reads `@Dependency(\.uuid)`.
- Use `.incrementing` UUIDs for tests that assert generated IDs.
- Seed with explicit IDs. Use negative IDs for fixture data so generated IDs do not collide.
- Call `.load()` before asserting observed fetch state when required.
- Keep test seed helpers separate from preview seeds.
- Assert through the database for writes. Reducer state alone is not enough when persistence is the behavior.

## Suite Setup

```swift
import Dependencies
import DependenciesTestSupport
import Testing

@Suite(
  .dependency(\.uuid, .incrementing),
  .dependencies {
    try $0.bootstrapDatabase()
    try $0.defaultDatabase.write { db in
      try db.seed {
        RemindersList(id: UUID(-1), title: "Personal")
        Reminder(id: UUID(-1), remindersListID: UUID(-1), title: "Get milk")
      }
    }
  }
)
struct RemindersTests {
  @Dependency(\.defaultDatabase) var database
}
```

## Generated UUIDs

Install a database `uuid()` function during bootstrap:

```swift
@DatabaseFunction
nonisolated func uuid() -> UUID {
  @Dependency(\.uuid) var uuid
  return uuid()
}
```

Tests can then use `.incrementing` and assert rows whose IDs come from SQLite defaults.

## Observed Fetches

```swift
@Test
func observedRowsReloadAfterWrite() async throws {
  let model = RemindersModel(listID: UUID(-1))
  try await model.$reminders.load()

  try await database.write { db in
    try Reminder.upsert {
      Reminder.Draft(remindersListID: UUID(-1), title: "Call accountant")
    }
    .execute(db)
  }

  try await model.$reminders.load()
  #expect(model.reminders.map(\.title) == ["Call accountant", "Get milk"])
}
```

## Pitfalls

- Do not reuse preview seeds in tests.
- Do not use a constant UUID generator when multiple rows are inserted.
- Do not let tests touch the app's real database file.
- Do not trace SQL in tests unless the test is specifically about tracing.
- Do not use one shared writable database across parallel tests.
- Do not assert generated IDs without controlling the database `uuid()` function.

## Tests

For insertion, set `uuid = .incrementing`, call the reducer action, receive the result if any, read the database, and assert the inserted row ID and values. For migrations, run the migrator on old-schema fixtures and assert both schema and readable models.
