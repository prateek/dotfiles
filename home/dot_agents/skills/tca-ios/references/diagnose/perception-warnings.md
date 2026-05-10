# Applies to: TCA 1.25+, iOS 16+

# Perception Warnings

## Use When

Use this when iOS 16 runtime warnings say observable/perceptible state was accessed without tracking.

## Diagnosis

- Reproduce on an older simulator.
- Expand the runtime warning and inspect the stack.
- Find the view, row, destination, or sheet closure that reads store state.
- Check lazy SwiftUI closures separately from the parent body.

## Fix

Wrap the state-reading body or closure in `WithPerceptionTracking`. Use `@Perception.Bindable` for bindings when the OS target requires it.

## Pitfalls

- One wrapper around a parent body may not cover lazy child closures.
- Do not suppress the warning by going back to `WithViewStore`.

## Tests

Run the affected path on the minimum supported simulator.
