# Applies to: TCA 1.25+, iOS 16+

# Migrations

## Use When

Use this when changing released SQLite schemas, adding tables, backfilling data, or preparing iCloud sync tables.

## Guidance

- Register every migration in `bootstrapDatabase` before assigning `defaultDatabase`.
- Use GRDB's `DatabaseMigrator`, but prefer schema-safe `#sql` strings over GRDB's table-builder DSL.
- Give migrations stable names. Once a migration ships, never edit its body in place.
- New tables can contain non-null columns without defaults. Existing tables need defaults for new non-null columns.
- Backfill derived data inside the migration that introduces it.
- Create indexes in the same migration as the table or column that needs them.
- If the app uses `SyncEngine`, preserve CloudKit compatibility. Avoid dropping or renaming synced tables and columns.
- `eraseDatabaseOnSchemaChange` can speed up debug builds, but it must not replace released migrations.
- Migrations are forward-only. If a shipped migration is wrong, ship a corrective migration that fixes the schema or data; do not edit, reorder, or roll back the original. `eraseDatabaseOnSchemaChange` is the only "rollback" path, and it is DEBUG-only because it deletes user data.

## Shape

```swift
extension DependencyValues {
  mutating func bootstrapDatabase() throws {
    let database = try SQLiteData.defaultDatabase()

    var migrator = DatabaseMigrator()
    #if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
    #endif

    migrator.registerMigration("Create reminders") { db in
      try #sql("""
        CREATE TABLE "reminders" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
          "title" TEXT NOT NULL DEFAULT '',
          "isCompleted" INTEGER NOT NULL DEFAULT 0
        ) STRICT
        """)
        .execute(db)
    }

    migrator.registerMigration("Add due date to reminders") { db in
      try #sql("""
        ALTER TABLE "reminders"
        ADD COLUMN "dueAt" TEXT
        """)
        .execute(db)
    }

    try migrator.migrate(database)
    defaultDatabase = database
  }
}
```

## Adding Columns

```swift
migrator.registerMigration("Add position to reminders") { db in
  try #sql("""
    ALTER TABLE "reminders"
    ADD COLUMN "position" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0
    """)
    .execute(db)
}
```

Add the Swift property to the `@Table` model in the same change:

```swift
@Table
struct Reminder: Identifiable {
  let id: UUID
  var title = ""
  var position = 0
}
```

## Pitfalls

- Do not change a released schema model and rely on development erase behavior.
- Do not edit a migration that may already exist on a user's device.
- Do not make migrations depend on live network or user state.
- Do not use SQLite features that conflict with sync support when the table is CloudKit-backed.
- Do not create migration-time data by calling reducers. Migrations should work without app state.

## Tests

Keep old-schema database fixtures for important released versions. Run the migrator against each fixture, then assert schema shape, indexes, backfilled data, and the current `@Table` models' ability to read the migrated rows.
