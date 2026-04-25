# Applies to: TCA 1.25+, iOS 16+

# StructuredQueries Schema

## Use When

Use this for `@Table`, `@Column`, `@Selection`, primary keys, custom column names, and enum-backed values.

## Guidance

- Model tables as structs.
- Prefer `let id: UUID` and `Identifiable` for primary-keyed tables.
- Use default table and column names unless matching an existing schema.
- Use `@Column("name")` only when the database name differs from the Swift property.
- Use `@Selection` for grouped columns and custom selected rows.
- Use optional raw-representable enums when old app versions may read unknown future values.
- Use `@Column(primaryKey: true)` when the primary key is not named `id`.
- Use a nested `@Selection` value for composite primary keys.
- Use `@Column(as:)` for custom query representations such as JSON or color hex values.
- Keep persisted raw values stable forever after release.

## Basic Tables

```swift
import Foundation
import SQLiteData
import StructuredQueries

@Table
struct RemindersList: Identifiable {
  let id: UUID
  var title = ""
}

@Table
struct Reminder: Identifiable {
  let id: UUID
  var remindersListID: RemindersList.ID
  var title = ""
  var isCompleted = false
}
```

## Custom Names

```swift
@Table("reminders_lists")
struct RemindersList: Identifiable {
  let id: UUID
  @Column("display_title") var title = ""
}
```

Use custom names for existing schemas or server-imposed naming. Do not add string names that duplicate the default.

## Composite Key

```swift
@Table
struct ReminderTag: Identifiable {
  @Selection
  struct ID: Hashable {
    let reminderID: Reminder.ID
    let tagID: Tag.ID
  }

  let id: ID
}
```

## Values

```swift
enum Priority: Int, QueryBindable {
  case low = 0
  case normal = 1
  case high = 2
}

@Table
struct Reminder: Identifiable {
  let id: UUID
  var priority: Priority?
  @Column(as: [Note].JSONRepresentation.self) var notes: [Note] = []
}
```

## Pitfalls

- Do not use classes as table models.
- Do not mark multiple columns as primary keys; use a composite ID selection when needed.
- Do not change persisted raw values after release.
- Do not reuse the same enum column grouping more than once in one table.
- Do not let Swift property defaults drift from SQL column defaults.

## Tests

Compile-time macro expansion catches many schema errors. Add migration tests when changing released schemas, and add query tests for custom representations, enum values, and composite IDs.
