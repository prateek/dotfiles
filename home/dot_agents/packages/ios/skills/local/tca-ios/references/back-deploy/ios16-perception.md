# Applies to: TCA 1.25+, iOS 16+

# iOS 16 Perception

## Use When

Use this when a TCA app targets iOS 16 and uses modern `@ObservableState` store observation.

TCA 1.25 requires iOS 16+, so do not add iOS 15-specific compatibility work. The only back-deploy concern in this skill is Observation support on iOS 16, where Perception still provides tracking wrappers for state reads.

## Guidance

- Wrap SwiftUI body contents that read observable store state in `WithPerceptionTracking`.
- Wrap lazy SwiftUI closure contents too: `ForEach`, navigation destinations, sheets, popovers, alerts with custom content, and row builders.
- Use `@Perception.Bindable` for bindings when the view must run on iOS 16.
- On iOS 17+, native Observation handles tracking, but keep wrappers while the minimum supported version is iOS 16.
- Remove `WithViewStore` as part of modernization; do not keep it just to avoid a Perception warning.
- Fix warnings at the exact state-read site. A parent wrapper may not cover closures SwiftUI evaluates later.

## Pitfalls

- Do not treat iOS 16 support as iOS 15 support. This skill does not target iOS 15.
- Do not remove `WithPerceptionTracking` because the code works on an iOS 17 simulator.
- Do not wrap the entire app once and assume every destination, row, or sheet is tracked.
- Do not mix old helper store views back into otherwise modern observation code.

## Tests

Compile with the actual minimum deployment target and exercise the affected view path on an iOS 16 simulator. Runtime Perception warnings are behavioral failures; resolve them before treating the migration as done.
