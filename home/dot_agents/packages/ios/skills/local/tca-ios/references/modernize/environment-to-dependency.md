# Applies to: TCA 1.25+, iOS 16+

# Environment to Dependency

## Use When

Use this when older TCA features pass an Environment struct or dependency values through reducer initializers.

## Steps

1. Identify each environment field and its live/test use.
2. Create or reuse a dependency client for each domain service.
3. Add `DependencyKey` and `DependencyValues` accessors.
4. Replace environment field access with `@Dependency`.
5. Update tests to override dependencies in `TestStore` or `withDependencies`.
6. Delete environment plumbing only after all call sites are gone.

## Pitfalls

- Do not collapse unrelated services into one mega-client.
- Do not lose test failure behavior; missing overrides should still fail loudly.
- Do not capture non-Sendable live clients directly in `.run` closures.

## Tests

Port existing environment-based tests first. The same actions should pass with dependency overrides.
