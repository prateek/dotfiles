# Applies to: TCA 1.25+, iOS 16+

# SwiftUI Integration Review

## Use When

Use this for views, store scoping, binding, local state, tasks, and observation performance.

## Inspect

- `StoreOf<Feature>` usage.
- Direct store reads and sends.
- Scoped stores for child views.
- Bindings and `BindableAction`.
- View-local `@State`, `@StateObject`, `@ObservedObject`, and environment values.
- `.task`, `.onAppear`, `.onDisappear`, and `.onChange`.
- Business logic in views.
- Broad observation and expensive computed properties.

## Findings To Look For

- Networking, persistence, analytics, or navigation decisions in views.
- Root stores passed into leaves.
- Duplicated state between SwiftUI local state and TCA state.
- `ViewStore` usage in modern code without a compatibility reason.
- High-frequency actions from text fields or scroll callbacks.

## Output

Include clean examples, risky examples, findings, and suggested before/after patterns.
