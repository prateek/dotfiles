# Applies to: TCA 1.25+, iOS 16+

# SQLiteData Previews

## Use When

Use this for Xcode previews that render database-backed views or observable models.

## Guidance

- Prepare dependencies inside the preview before constructing the view/model.
- Use a preview database separate from live and tests.
- Seed enough data to make the preview meaningful.
- Keep preview data local and deterministic.
- Use `try!` in previews only because `#Preview` is not throwing.
- Give explicit IDs only when a later row needs a foreign key.
- Prefer `Database.seed` for compact preview setup.
- Put reusable preview seeds in a clearly named preview-only helper.

## Shape

```swift
#Preview {
  let _ = prepareDependencies {
    try! $0.bootstrapDatabase()
    try! $0.defaultDatabase.write { db in
      try db.seed {
        RemindersList(id: UUID(1), title: "Personal")
        Reminder.Draft(title: "Get milk", remindersListID: UUID(1))
        Reminder.Draft(title: "Walk the dog", remindersListID: UUID(1))
      }
    }
  }

  RemindersListView(
    store: Store(initialState: RemindersListFeature.State()) {
      RemindersListFeature()
    }
  )
}
```

When a previewed view needs a row as an initializer argument, return it from `prepareDependencies`:

```swift
#Preview {
  let list = prepareDependencies {
    try! $0.bootstrapDatabase()
    return try! $0.defaultDatabase.write { db in
      try db.seed {
        RemindersList(id: UUID(1), title: "Personal")
      }
      return try RemindersList.find(UUID(1)).fetchOne(db)!
    }
  }

  RemindersListDetailView(list: list)
}
```

## Pitfalls

- Do not point previews at the live app database.
- Do not share preview seeds with tests.
- Do not make previews depend on iCloud, network, or user login.
- Do not use generated draft IDs as SwiftUI list identities.
- Do not hide failed preview database setup with empty fallback data.

## Tests

Build the preview support module and render at least one database-backed preview while working on the feature. Keep preview-only seed helpers out of test fixtures.
