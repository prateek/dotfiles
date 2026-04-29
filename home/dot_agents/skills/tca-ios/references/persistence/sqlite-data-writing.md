# Applies to: TCA 1.25+, iOS 16+

# SQLiteData Writing

## Use When

Use this for inserts, updates, upserts, deletes, and reducer-triggered database mutations.

## Guidance

- Use `database.write` for mutations.
- Keep SQL in dependencies or model methods when reducers would otherwise become database scripts.
- Use transactions for multi-step writes that must succeed together.
- Use `withErrorReporting` for recoverable database failures, then set user-visible error state when the product needs it.
- Prefer StructuredQueries operations over raw SQL.
- Prefer `upsert` when the domain action is create-or-update.
- Use `find(id).update` and `find(id).delete` for primary-key mutations.
- Return generated IDs from writes when the reducer needs to navigate or select the inserted row.
- In reducers, capture state values before entering `.run` so the effect's `@Sendable` closure has explicit inputs.

## Reducer Write

```swift
case .saveButtonTapped:
  state.isSaving = true
  let draft = state.draft
  return .run { [database, draft] send in
    await send(.saveResponse(Result {
      try await database.write { db in
        try Reminder
          .upsert { draft }
          .returning(\.id)
          .fetchOne(db)!
      }
    }))
  }
  .cancellable(id: CancelID.save, cancelInFlight: true)
```

## Transactions

```swift
try await database.write { db in
  try Reminder.upsert { reminder }.execute(db)
  try ReminderTag.where { $0.reminderID.eq(reminder.id) }.delete().execute(db)
  try ReminderTag.insert { tags }.execute(db)
}
```

Keep related writes in the same `database.write` closure so they commit or fail together.

## Pitfalls

- Do not fatal-error on normal database failures.
- Do not mutate observed fetch state directly; write the database and let observation update.
- Do not perform writes from SwiftUI button closures when reducer behavior depends on the result.
- Do not write from multiple unrelated dependencies when one transaction owns the domain operation.
- Do not ignore write errors in iCloud-shared records; permission failures are product state.

## Tests

Assert writes through the database, not only through transient state. For reducer tests, override the database dependency with an isolated database, drive the action, receive any response, and then read the affected rows.
