# Applies to: TCA 1.25+, iOS 16+

# Swift 6 Migration

## Use When

Use this when enabling Swift 6 language mode or resolving strict concurrency warnings in TCA code.

## Steps

1. Build one target in Swift 6 mode and collect exact warnings.
2. Fix dependency clients to be `Sendable`.
3. Add `@Sendable` to dependency function properties.
4. Capture dependency functions and values explicitly inside `.run`.
5. Mark reducer types `Sendable` when their stored properties support it.
6. Isolate mutable shared state with actors, locks, or serial dependencies.
7. Use unchecked wrappers only as narrow bridges with comments explaining the invariant.

## Pitfalls

- Do not silence warnings with broad `@preconcurrency import`.
- Do not detach tasks to dodge actor isolation.
- Do not change reducer ordering while fixing Sendable warnings.

## Tests

Run the Swift 6 build and existing reducer tests. Add tests where changed captures or isolation affect timing.
