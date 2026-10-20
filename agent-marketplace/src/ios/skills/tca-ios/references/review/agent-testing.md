# Applies to: TCA 1.25+, iOS 16+

# Testing and Determinism Review

## Use When

Use this for reducer tests, dependency overrides, clocks, navigation tests, cancellation tests, and fixture hygiene.

## Inspect

- TestStore coverage for meaningful reducer behavior.
- Async effect tests and received actions.
- Dependency overrides for time, UUID, random, network, files, database.
- Navigation and presentation tests.
- Failure, cancellation, and delegate paths.
- Exhaustive vs non-exhaustive choices.
- Test target dependencies.

## Findings To Look For

- Tests that only instantiate views.
- Live services in tests.
- Missing `receive` assertions for effects.
- Real sleeps.
- Uncontrolled dates or UUIDs.
- Complex reducers without tests.
- Test target linking that hides dependencies or creates duplicate classes.

## Output

Include a test map, coverage assessment by feature, findings, missing tests, and a sample TestStore test for the highest-risk gap.
