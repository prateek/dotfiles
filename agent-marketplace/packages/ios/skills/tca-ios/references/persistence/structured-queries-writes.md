# Applies to: TCA 1.25+, iOS 16+

# StructuredQueries Writes

## Use When

Use this for insert, update, upsert, delete, conflict handling, and returning values.

## Guidance

- Prefer drafts for primary-keyed inserts.
- Prefer full-value inserts unless a column-specific insert is clearer.
- Prefer upsert when create-or-update is the domain operation.
- Use `find(id).update` and `find(id).delete` for primary-key mutations.
- Use explicit conflict targets when handling conflicts.
- Use `returning` when the caller needs generated IDs or updated values.
- Delete by building the predicate first, then calling `.delete()`.
- Keep multi-row related writes inside one SQLiteData `database.write`.

## Insert

```swift
Reminder.insert {
  Reminder.Draft(remindersListID: listID, title: "Get milk")
  Reminder.Draft(remindersListID: listID, title: "Walk the dog")
}
```

```swift
Tag.insert {
  $0.title
} values: {
  "home"
  "work"
}
```

## Upsert

```swift
try Reminder
  .upsert { draft }
  .returning(\.id)
  .fetchOne(db)
```

```swift
try Reminder.insert {
  draft
} onConflict: {
  $0.id
} doUpdate: { reminder, excluded in
  reminder.title = excluded.title
}
.execute(db)
```

## Update And Delete

```swift
try Reminder
  .find(id)
  .update { $0.isCompleted.toggle() }
  .execute(db)

try Reminder
  .where(\.isCompleted)
  .delete()
  .execute(db)
```

## Insert From Select

```swift
ArchivedReminder.insert {
  ($0.title, $0.completedAt)
} select: {
  Reminder
    .where(\.isCompleted)
    .select { ($0.title, #sql("datetime('now')")) }
}
```

## Pitfalls

- `delete` does not take a predicate argument; build the predicate first.
- Do not use drafts for non-primary-keyed join tables unless the generated API actually supports that shape.
- Do not run multi-step related writes outside a transaction.
- Do not use column-specific inserts when a full value or draft keeps defaults clearer.
- Do not forget conflict targets on upserts for tables with nonstandard uniqueness.

## Tests

Assert the database after each write. Cover fresh insert, conflict update, delete, generated ID return, and multi-step transaction failure.
