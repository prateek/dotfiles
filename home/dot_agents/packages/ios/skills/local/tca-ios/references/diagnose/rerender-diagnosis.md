# Applies to: TCA 1.25+, iOS 16+

# Re-render Diagnosis

## Use When

Use this when lists or views re-render too often, typing is slow, or broad store observation causes performance issues.

## Diagnosis

- Identify which state each view reads.
- Check whether a parent store is passed too deeply.
- Check `IdentifiedArray` identity stability.
- Check computed properties used in view bodies.
- Check high-frequency actions like text changes and scroll updates.

## Common Causes

- Leaf view reads parent state.
- Row IDs change across updates.
- Formatting or filtering runs in every body pass.
- Text input sends reducer actions on every keystroke without a debounce/local state boundary.

## Fix

Scope stores narrowly, stabilize IDs, move expensive derivations, and debounce or localize high-frequency input.

## Tests

Reducer tests catch action-rate behavior. Use profiling or UI instrumentation for render counts when needed.
