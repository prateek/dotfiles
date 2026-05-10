# Applies to: TCA 1.25+, iOS 16+

# Sendable Warnings

## Use When

Use this when Swift 6 reports Sendable, actor isolation, or non-Sendable capture warnings in TCA code.

## Diagnosis

- Locate the closure boundary: `.run`, dependency function, `onChange`, `ifLet`, binding, stream.
- Identify implicit `self` captures.
- Inspect dependency clients for `Sendable` conformance.
- Identify mutable shared state.

## Fix

- Capture dependency functions and values explicitly.
- Mark safe reducers and clients `Sendable`.
- Convert mutable shared state to actor/lock/isolated storage.
- Use narrow unchecked bridges only when the invariant is known.

## Pitfalls

- Do not silence warnings broadly with `@preconcurrency`.
- Do not make UI objects Sendable.

## Tests

Build in Swift 6 mode and run reducer tests around migrated effect paths.
