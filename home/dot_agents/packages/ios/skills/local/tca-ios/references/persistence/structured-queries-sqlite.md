# Applies to: TCA 1.25+, iOS 16+

# StructuredQueries SQLite

## Use When

Use this for SQLite-specific StructuredQueries APIs: FTS5, `rowid`, collation, temporary triggers, temporary views, and database functions.

## Guidance

- Import the SQLite-specific module when using SQLite-only APIs.
- Use FTS5 table models for full-text search.
- Use `rowid` intentionally and expose stable IDs when rows need identity.
- Use collations for case-insensitive comparisons.
- Prefer temporary triggers for derived search tables and maintenance logic that belongs to the connection.
- Register database functions during database preparation.
- Use temporary views for derived read models that can be rebuilt per connection.
- Use timestamp triggers for common `updatedAt` maintenance.
- Keep SQLite-only query code behind SQLiteData-specific modules.

## Import

```swift
import StructuredQueriesSQLite
```

## FTS5

```swift
@Table
struct ReminderText: FTS5, Identifiable {
  @Column(primaryKey: true) let rowid: Int
  var id: Int { rowid }
  let title: String
  let notes: String
}

ReminderText
  .where { $0.match(searchText) }
  .order(by: \.rank)
  .select {
    SearchResult.Columns(
      title: $0.title.highlight("<mark>", "</mark>"),
      notes: $0.notes.snippet("<mark>", "</mark>", "...", 80)
    )
  }
```

## Temporary Triggers

```swift
configuration.prepareDatabase { db in
  try Reminder.createTemporaryTrigger(
    after: .insert { new in
      ReminderText.insert {
        ReminderText(rowid: new.rowid, title: new.title, notes: new.notes)
      }
    }
  )
  .execute(db)

  try Reminder.createTemporaryTrigger(
    after: .update(touch: \.updatedAt)
  )
  .execute(db)
}
```

## Collation

```swift
@Table
struct Tag: Identifiable {
  let id: Int
  @Column(collate: .nocase) var name: String
}

Tag
  .where { $0.name.eq("Swift") }
  .order(by: \.name)
```

`@Column(collate:)` keeps case-insensitive comparisons and ordering correct without lowercasing the stored value. Use `.nocase` for user-entered text fields that need predictable equality and sort order.

## Temporary Views

```swift
@Table
struct CompletedReminder {
  let id: Reminder.ID
  let title: String
}

try CompletedReminder
  .createTemporaryView(
    as: Reminder
      .where(\.isCompleted)
      .select { CompletedReminder.Columns(id: $0.id, title: $0.title) }
  )
  .execute(db)
```

## Pitfalls

- Do not assume SQLite-specific code is portable to other SQL engines.
- Do not create persistent triggers casually; migrations then own them forever.
- Do not forget to rebuild FTS rows when source rows update or delete.
- Do not use `rowid` as product identity when sync, import/export, or cross-device identity matters.
- Do not create temporary triggers in only the live bootstrap; previews and tests need the same query behavior.

## Tests

Seed text that covers search, ranking, highlight/snippet behavior, trigger maintenance, collation, and view creation.
