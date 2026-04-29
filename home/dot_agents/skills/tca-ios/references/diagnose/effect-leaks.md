# Applies to: TCA 1.25+, iOS 16+

# Effect Leaks

## Use When

Use this when effects are still running, subscriptions keep emitting, or dismissed features keep sending actions.

## Diagnosis

- Find the action that starts the long-lived effect.
- Find its cancellation ID.
- Find the action that should end the lifetime.
- Check presentation dismissal, `onDisappear`, explicit cancel, and parent nil-ing.
- Check async streams for termination handling.

## Common Causes

- Missing `.cancellable`.
- Missing `.cancel(id:)`.
- Reused cancellation ID across unrelated features.
- Optional child state dismissed while its effect continues.
- Async stream dependency never finishes when cancelled.

## Fix

Add scoped cancellation, tie it to dismissal/lifecycle, and update tests to prove the effect stops.
