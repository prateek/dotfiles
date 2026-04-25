# Applies to: TCA 1.25+, iOS 16+

# Custom Dump

## Use When

Use this for readable state diffs, large value assertions, and mutation assertions.

## Guidance

- Use `expectNoDifference` for whole-value equality with useful diffs.
- Use `expectDifference` when asserting a mutation to a large value.
- Use `diff(_:_:)` to get the diff string between two values without raising a failure, for example when logging a discrepancy or attaching it to an error.
- Use `customDump(_:to:)` to render a stable, reviewable description of a value, for example in a debug log or a generated fixture.
- Prefer full-state comparisons over mapping values into weaker projections.
- Add custom dump conformances only when the default output hides the meaningful identity.
- Use structural assertions for reducer state before snapshotting reducer output.
- Keep transformations in assertions small. A transformed assertion often stops checking the thing that matters.

## Example

```swift
let before = state
state.rows[id: row.id]?.title = "Updated"

expectDifference(before, state) {
  $0.rows[id: row.id]?.title = "Updated"
}
```

For reducer tests, TestStore already uses useful diffs. Reach for custom dump helpers when testing pure functions, dependency clients, or large values outside TestStore.

## Large State Assertions

Use full values when identity and ordering matter:

```swift
expectNoDifference(
  state.rows,
  [
    Row.State(id: firstID, title: "First"),
    Row.State(id: secondID, title: "Second"),
  ]
)
```

Use `expectDifference` when the before value is large and one mutation is the point of the test:

```swift
expectDifference(before, after) {
  $0.destination = nil
  $0.isRefreshing = true
}
```

This keeps the assertion focused while still checking the full before and after values through CustomDump.

## Diff Without Failure

```swift
if let report = diff(expected, actual) {
  logger.warning("Snapshot drift:\n\(report)")
}
```

`diff` returns `nil` when the values are equal, otherwise returns the same dump-based difference string that `expectNoDifference` would print. Useful when the test wants to keep going, or when a non-test path needs a readable diff.

## customDump

Use `customDump(_:to:)` for a stable description that does not rely on `String(describing:)`:

```swift
var output = ""
customDump(state, to: &output)
```

The output is the same shape used by TestStore failures and CustomDump diffs, so it survives across releases and is safe to embed in fixtures or commit to disk.

## When to Add Custom Dump Support

Add custom dump conformance only when the default dump hides the domain identity. Good candidates are wrappers around SDK values, database row IDs, or large payloads where the default dump includes unstable fields. Keep the custom dump stable and domain-specific.

## Pitfalls

- Do not use difference tools to avoid making a domain type Equatable when Equatable is the correct contract.
- Do not assert through transformed arrays if the order, identity, or full value matters.
- Do not overuse snapshots for reducer state when a structural diff is clearer.
- Do not compare string dumps when you can compare values.
- Do not hide identity bugs by sorting collections in the assertion.
- Do not use `expectNoDifference` for a mutation when `expectDifference` would name the changed fields directly.
- Do not snapshot reducer state just to get a diff. Structural diffs are easier to review.

## Tests

When a reducer mutates a nested collection, `expectDifference` can keep the test focused without losing the full before/after value.
