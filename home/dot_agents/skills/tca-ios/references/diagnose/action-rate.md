# Applies to: TCA 1.25+, iOS 16+

# Action Rate

## Use When

Use this when scrolling, typing, dragging, or streaming sends too many actions.

## Diagnosis

- Identify the event source frequency.
- Determine whether every event must reach the reducer.
- Check if the reducer performs expensive work per event.
- Check if in-flight effects cancel.

## Fixes

- Keep purely visual transient input local.
- Debounce or throttle domain-changing input.
- Batch updates where the product does not need every intermediate value.
- Cancel stale effects with `cancelInFlight`.

## Pitfalls

- Do not debounce actions that must be immediate for correctness.
- Do not drop accessibility-relevant state changes.

## Tests

Use `TestClock` to assert the reducer emits one domain action after the chosen interval.
