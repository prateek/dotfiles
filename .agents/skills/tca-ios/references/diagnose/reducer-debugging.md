# Applies to: TCA 1.25+, iOS 16+

# Reducer Debugging

## Use When

Use this when action flow or state mutations are hard to trace.

## Tools

- Add `_printChanges()` temporarily to a reducer to log every action and the resulting state diff.
- Use `_printChanges(.actionLabels)` when the diff noise is overwhelming and only the action stream matters.
- Apply the `Reducer` debug modifier to a child feature instead of the root reducer when one feature is enough.
- Narrow logging to the feature under diagnosis.
- Remove debug reducers before finishing unless the user asked to keep diagnostic hooks.

## Diagnosis

- Reproduce the smallest action sequence.
- Compare observed actions to expected user/effect events.
- Look for duplicate actions, missing responses, and state changes from unexpected branches.
- When a TestStore failure is too noisy to read, switch the reducer under test to `_printChanges(.actionLabels)` for a single run to identify the offending action, then return to a structural diff.

## Pitfalls

- Do not leave noisy reducer logging in production code.
- Do not use prints instead of tests.
- Do not debug the whole root reducer if one child feature is enough.

## Tests

Turn the discovered minimal action sequence into a TestStore regression test.
