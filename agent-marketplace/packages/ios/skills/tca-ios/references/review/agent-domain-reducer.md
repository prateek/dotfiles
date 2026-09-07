# Applies to: TCA 1.25+, iOS 16+

# Domain and Reducer Review

## Use When

Use this for State, Action, Reducer, parent-child composition, and domain modeling.

## Inspect

- Coherent State, Action, and Reducer for each major feature.
- State fields needed for rendering and decisions.
- Impossible states that should be enums, presentation state, or precise domain types.
- Action vocabulary: user events, lifecycle, effect responses, delegate, binding, child routing.
- Reducer size and responsibility.
- Parent-child communication and duplicate state ownership.

## Findings To Look For

- God reducers.
- Massive or vague action enums.
- Parent reducers reaching deeply into child internals.
- Child features mutating parent concerns directly.
- State duplicated across parent, child, and global roots.
- Views mutating domain state outside reducer actions.

## Output

Include an overall assessment, findings, a feature-by-feature table, and suggested reducer tests for risky flows.
