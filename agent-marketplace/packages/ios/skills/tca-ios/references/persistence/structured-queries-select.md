# Applies to: TCA 1.25+, iOS 16+

# StructuredQueries Select

## Use When

Use this for SELECT, WHERE, ORDER BY, GROUP BY, aggregations, LIMIT, and dynamic filters.

## Guidance

- Use key-path forms before joins for simple property access.
- Use named predicate functions such as `eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `is`, and `isNot`.
- Use `find(id)` for primary-key lookup.
- Chain query builder calls in the order that keeps closures simple.
- Use `@Selection.Columns` when selecting into a custom value.
- Move filters, grouping, and ordering before joins when they do not need joined tables.
- Use `limit` and `offset` at the query level for pagination.
- Use aggregate functions for counts and summaries instead of fetching rows and counting in Swift.

## Common Queries

```swift
Reminder.find(reminderID)

Reminder
  .where { !$0.isCompleted }
  .order(by: \.title)
  .limit(20)

Reminder
  .where { $0.dueAt.isNot(nil) }
  .where { !$0.isCompleted }
```

## Dynamic Filters

```swift
func reminders(showCompleted: Bool) -> some SelectStatementOf<Reminder> {
  Reminder
    .where {
      if !showCompleted {
        !$0.isCompleted
      }
    }
    .order(by: \.title)
}
```

## Selection Rows

```swift
@Selection
struct ReminderListRow: Identifiable {
  let id: Reminder.ID
  let title: String
  let listTitle: String
}

Reminder
  .join(RemindersList.all) { $0.remindersListID.eq($1.id) }
  .select { reminder, list in
    ReminderListRow.Columns(
      id: reminder.id,
      title: reminder.title,
      listTitle: list.title
    )
  }
```

## Aggregates

```swift
Reminder
  .where(\.isCompleted)
  .fetchCount(db)

RemindersList
  .group(by: \.id)
  .leftJoin(Reminder.all) { $0.id.eq($1.remindersListID) }
```

## Pitfalls

- Do not use infix Swift operators when the query builder expects named SQL predicates.
- Do not select directly into a selection value instead of its generated columns type.
- Do not keep join-only closures after the join if the condition can happen earlier.
- Do not fetch full rows when a `@Selection` has enough data for the view.
- Do not assume chained builder order has to match SQL text order. Put readability first.

## Tests

Exercise each query against an isolated database with rows that cover empty results, matches, ordering, limits, and optional fields.
