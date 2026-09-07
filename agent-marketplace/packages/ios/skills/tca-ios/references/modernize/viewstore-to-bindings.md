# Applies to: TCA 1.25+, iOS 16+

# ViewStore to Bindings

## Use When

Use this when replacing `WithViewStore`, `ViewStore`, view-state structs, or legacy binding helpers.

## Steps

1. Add `@ObservableState` to feature state if missing and the version supports it.
2. Replace `WithViewStore` closures with direct store reads.
3. Replace `viewStore.send` with `store.send`.
4. Use `@Bindable var store` when deriving `$store` bindings.
5. Add or keep `BindableAction`, `binding`, and `BindingReducer()` only for state that is actually bound.
6. If the deployment target includes iOS 16, keep the Perception backport requirements in place:
   `WithPerceptionTracking` around state-reading bodies and lazy closures, and
   `@Perception.Bindable` where SwiftUI `@Bindable` is unavailable.

## Pitfalls

- Do not delete computed view state if it encodes a real performance boundary without checking observation behavior.
- Do not use direct bindings for domain events that deserve named actions.
- Do not add or preserve iOS 15-specific migration work in this iOS 16+ target.

## Tests

Run view-compiling targets and reducer tests for any binding-driven behavior.
