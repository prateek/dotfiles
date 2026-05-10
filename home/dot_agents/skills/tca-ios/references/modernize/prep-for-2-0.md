# Applies to: TCA 1.25+, iOS 16+

# Prep for 2.0

## Use When

Use this when a codebase is on TCA 1.25+ and the user asks about 2.0 readiness or deprecation traits.

## Guidance

- Enable `ComposableArchitecture2Deprecations` for ongoing warning coverage.
- Enable `ComposableArchitecture2DeprecationOverloads` temporarily during migration.
- Migrate enum destination scopes to projected-key-path syntax.
- Replace Combine-based effect operators with `.run`, async/await, clocks, and `send` animation/transaction arguments.
- Add `@ReducerCaseIgnored` plus an explicit `Destination.Action` enum for destination prompt
  cases that carry actions, such as `AlertState<Action>` and `ConfirmationDialogState<Action>`. The 1.25 migration guide hints at a future "prompts" tool that will replace `AlertState<Action>` embedding once 2.0 lands; the explicit `Destination.Action` shape is forward-compatible with that direction.
- Move away from `StorePublisher` toward observation APIs.
- Treat reentrant-action warnings as real design feedback.

## Pitfalls

- Do not present hinted future prompt APIs as shipped 2.0 APIs.
- Do not enable overload traits permanently if compile time regresses.
- Do not combine 2.0 prep with unrelated feature rewrites.

## Tests

Run with traits enabled, capture warnings, migrate one warning class at a time, and run the affected test target after each class.
