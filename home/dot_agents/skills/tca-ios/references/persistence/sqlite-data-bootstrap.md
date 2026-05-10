# Applies to: TCA 1.25+, iOS 16+

# SQLiteData Bootstrap

## Contents

- [Use When](#use-when)
- [Guidance](#guidance)
- [Shape](#shape)
- [Access](#access)
- [Pitfalls](#pitfalls)
- [Tests](#tests)

## Use When

Use this when adding SQLiteData to an app or fixing database setup order.

## Guidance

- Add the `SQLiteData` product to targets that create or use the database.
- Add `Dependencies` anywhere that calls `prepareDependencies` or reads `@Dependency(\.defaultDatabase)`.
- Define `bootstrapDatabase` on `DependencyValues`. Keep that name so other references and tests can find it.
- Create the database, configure `Configuration.prepareDatabase`, register database functions, run migrations, then set `defaultDatabase`.
- Call `prepareDependencies` in the `@main` app initializer before constructing the root store or any database-backed model.
- Bootstrap previews that use `@FetchAll`, `@FetchOne`, `@Fetch`, or `defaultDatabase`.
- Keep example provenance honest. This is SQLiteData setup guidance, not a claim that a specific sample app uses SQLiteData.

## Shape

```swift
import Dependencies
import SQLiteData
import StructuredQueriesSQLite

extension DependencyValues {
  mutating func bootstrapDatabase() throws {
    var configuration = Configuration()
    configuration.prepareDatabase { db in
      db.add(function: $uuid)
    }

    let database = try SQLiteData.defaultDatabase(configuration: configuration)
    var migrator = DatabaseMigrator()
    #if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
    #endif
    try migrator.migrate(database)
    defaultDatabase = database
  }
}

@DatabaseFunction
nonisolated func uuid() -> UUID {
  @Dependency(\.uuid) var uuid
  return uuid()
}
```

```swift
import ComposableArchitecture
import Dependencies
import SwiftUI

@main
struct AppMain: App {
  init() {
    prepareDependencies {
      try! $0.bootstrapDatabase()
    }
  }
}
```

## Access

Reducers usually wrap database work in a dependency client. Direct access is fine for small apps, previews, and observable models:

```swift
@Reducer
struct Reminders {
  @Dependency(\.defaultDatabase) var database

  enum Action {
    case task
    case remindersResponse(Result<[Reminder], Error>)
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task:
        return .run { [database] send in
          await send(.remindersResponse(Result {
            try await database.read { db in
              try Reminder.order(by: \.title).fetchAll(db)
            }
          }))
        }
      case .remindersResponse:
        return .none
      }
    }
  }
}
```

## Pitfalls

- Do not create ad hoc database connections in views or reducers.
- Do not run migrations lazily from feature code.
- Do not use `try!` in test suite dependency traits; tests can throw.
- Do not construct the root store before `prepareDependencies` has assigned `defaultDatabase`.
- Do not put `bootstrapDatabase` in a feature module that leaf modules must import.

## Tests

Add a test bootstrap that creates an isolated database, registers the same functions, runs the same migrations, and avoids the app's live database path. Use throwing dependency traits or explicit `withDependencies` blocks so setup failures fail the test cleanly.
