# Applies to: TCA 1.25+, iOS 16+

# Action Ping-Pong

## Use When

Use this when reducers bounce internal actions through parent/child layers or tests contain long chains of implementation actions.

## Diagnosis

- Trace the action sequence.
- Mark user events, effect responses, delegate events, and internal sequencing.
- Identify actions that exist only to call another case.
- Check whether a helper method or local reducer branch would be clearer.

## Fix

- Use delegate actions for child-to-parent domain events.
- Collapse purely internal sequencing into one reducer case when no external observation is needed.
- Keep effect responses explicit when async work completes.

## Pitfalls

- Do not remove actions that are part of the public feature contract.
- Do not hide important async boundaries.

## Tests

After refactoring, tests should read closer to the product flow: user event, response, state.
