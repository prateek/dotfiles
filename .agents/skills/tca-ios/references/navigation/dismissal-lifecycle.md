# Applies to: TCA 1.25+, iOS 16+

# Dismissal Lifecycle

## Use When

Use this when a child can dismiss itself, optional state becomes nil, or effects keep running after a sheet closes.

## Guidance

- A child can request dismissal through `@Dependency(\.dismiss)`.
- A parent can dismiss by setting presentation state to nil.
- Effects returned from a presented child reducer through `.ifLet` are automatically cancelled when presentation state is nilled.
- Explicit `.cancel(id:)` is for parent-owned or global work that is not owned by the presented child reducer.
- Parent reducers should handle child delegate actions before clearing state when they need child data.
- Keep cancellation IDs scoped to the feature that owns the work.

## Example

```swift
@Dependency(\.dismiss) var dismiss

case .doneButtonTapped:
  return .run { [dismiss] _ in
    await dismiss()
  }

case .destination(.dismiss):
  state.destination = nil
  return .none
```

## Pitfalls

- Returning long-lived child effects outside presentation composition can leave work running after dismissal.
- Dismissal should not be used as a data channel. Use delegate actions for saved/cancelled domain events.
- Do not assume SwiftUI dismissal and reducer state are independent. They must stay in sync.

## Tests

Use a long-lived test dependency or clock. Present the child, start child-owned work, dismiss, and assert no effect remains running. Add an explicit cancellation assertion only when the parent owns the work.
