# Applies to: TCA 1.25+, iOS 16+

# StructuredQueries Joins and CTEs

## Use When

Use this for joins, outer joins, aliases, subqueries, and common table expressions.

## Guidance

- Use join closures to connect table keys.
- Remember outer joins optionalize the joined table.
- Move filters that do not need joined tables before the join.
- Use aliases for self-joins.
- Use `With { ... } query: { ... }` for CTEs when the query is clearer as named intermediate data.
- After a join, query-builder closures receive one argument per joined table. Use named parameters when `$0`, `$1`, and `$2` stop being readable.
- A `where` inside the joined table argument is still applied to the main query in this API shape. Use an explicit subquery when that is what you mean.

## Join Shape

```swift
@Selection
struct ReminderRow: Identifiable {
  let reminder: Reminder
  let listTitle: String
  var id: Reminder.ID { reminder.id }
}

Reminder
  .where { !$0.isCompleted }
  .join(RemindersList.all) { reminders, lists in
    reminders.remindersListID.eq(lists.id)
  }
  .order { reminders, lists in lists.title.asc() }
  .select { reminders, lists in
    ReminderRow.Columns(reminder: reminders, listTitle: lists.title)
  }
```

## Outer Join

```swift
@Selection
struct ListRow: Identifiable {
  let list: RemindersList
  let reminder: Reminder?
  var id: RemindersList.ID { list.id }
}

RemindersList
  .leftJoin(Reminder.all) { lists, reminders in
    lists.id.eq(reminders.remindersListID)
  }
  .select { lists, reminders in
    ListRow.Columns(list: lists, reminder: reminders)
  }
```

## CTE Shape

```swift
@Selection
struct OverdueReminder {
  let id: Reminder.ID
}

With {
  Reminder
    .where { $0.dueAt.isNot(nil) && !$0.isCompleted }
    .select { OverdueReminder.Columns(id: $0.id) }
} query: {
  Reminder
    .where { $0.id.in(OverdueReminder.select(\.id)) }
    .update { $0.isFlagged = true }
}
```

## Pitfalls

- A `where` inside a joined query is still a main-query predicate unless the API explicitly builds a subquery.
- Do not ignore optionality from outer joins.
- Do not use a CTE to hide a query that would be clearer as a normal builder chain.
- Do not perform a join just to filter by a foreign key already present on the base table.

## Tests

Seed matched rows, unmatched rows, and duplicate child rows. Assert optional joined values, ordering, aggregate behavior, and the generated mutation result when a CTE drives a write.
