# Applies to: TCA 1.25+, iOS 16+

# StructuredQueries SQL Functions

## Use When

Use this for SQL functions, safe raw SQL fragments, operators, custom database functions, and expressions the query builder cannot express directly.

## Guidance

- Prefer typed query-builder APIs first.
- Use safe SQL string macros only for expressions that need raw SQL.
- Interpolate static schema symbols instead of hand-writing table and column names.
- Wrap custom database functions in typed Swift declarations and register them at database setup.
- Use `@DatabaseFunction` for Swift functions that SQLite queries should call.
- Register functions in `Configuration.prepareDatabase`.
- Keep nondeterministic functions behind dependencies so tests can control them.

## Safe SQL

```swift
extension Reminder.TableColumns {
  var isPastDue: some QueryExpression<Bool> {
    dueAt.isNot(nil) && dueAt < #sql("datetime('now')")
  }
}

Reminder.where(\.isPastDue)
```

Use safe SQL for small expressions the builder does not expose. Interpolate schema objects instead of spelling table and column names yourself.

## Database Functions

```swift
@DatabaseFunction
nonisolated func normalized(_ value: String) -> String {
  value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
}

configuration.prepareDatabase { db in
  db.add(function: $normalized)
}
```

```swift
Reminder
  .where { $normalized($0.title).eq(query) }
```

## Dependency-Backed Functions

```swift
@DatabaseFunction
nonisolated func uuid() -> UUID {
  @Dependency(\.uuid) var uuid
  return uuid()
}
```

Use this shape for database defaults that need deterministic tests.

## Pitfalls

- Do not concatenate raw SQL strings.
- Do not use raw SQL to bypass schema drift.
- Do not register nondeterministic functions in tests unless the nondeterminism is controlled by dependencies.
- Do not hide a large query in `#sql` just because it is familiar SQL. Prefer typed StructuredQueries for schema safety.
- Do not forget to register functions for previews and tests.

## Tests

Test raw SQL fragments with a real SQLite database fixture. A compile-only check is not enough for custom SQL.
