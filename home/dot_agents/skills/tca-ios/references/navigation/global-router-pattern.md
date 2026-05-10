# Applies to: TCA 1.25+, iOS 16+

# Global Router Pattern

## Use When

Use this for large apps where navigation is already a cross-feature product concern, especially migration from coordinator webs.

## Guidance

- Centralize app-level navigation decisions in a root/router reducer.
- Keep leaf features focused on local domain events and delegate upward.
- Translate route intents into stack and destination state in one place.
- Use this pattern to remove ambiguous coordinator-to-coordinator calls, not to make every leaf know every route.

## Pitfalls

- A global router can become a god reducer if it owns leaf behavior.
- Do not mirror the old coordinator graph one-to-one.
- Do not route every small local sheet through the app root; only elevate flows that are genuinely app-level.

## Tests

Write route tests at the router/root level. A route action should produce a clear app state: selected tab, path, destination, and any deferred route after auth.
