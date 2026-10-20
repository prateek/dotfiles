# Applies to: TCA 1.25+, iOS 16+

# Swift Testing Hygiene

## Use When

Use this when test targets fail to build, duplicate runtime classes appear, or dependency overrides are unreliable.

## Guidance

- Mark TestStore suites or tests `@MainActor`.
- Link test targets only to the modules they test and their explicit test-support dependencies.
- Prefer `DependenciesTestSupport` in tests when using dependency traits.
- Avoid pulling the whole app target into a feature test target.
- Put shared suite traits in a small base suite only when the codebase already uses that pattern.
- Keep feature tests near the feature module when the repo is modularized.
- Prefer one test target per feature or layer over a single app-wide test target that imports everything.

## Package Hygiene

For a feature package, the test target should depend on the feature and explicit test helpers:

```swift
.testTarget(
  name: "SearchTests",
  dependencies: [
    "Search",
    .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
  ]
)
```

Do not link the app target just to access dependency overrides. That hides missing module dependencies and often creates duplicate runtime class warnings.

## Swift Testing

Use `@MainActor` on suites or individual tests that construct `TestStore` or touch UI-bound state:

```swift
@MainActor
@Suite
struct SearchTests {
  @Test
  func searchSuccess() async { ... }
}
```

## Pitfalls

- Linking transitive app dependencies can hide missing product dependencies and create duplicate class warnings.
- Mixing XCTest and Swift Testing is fine, but keep conventions clear per target.
- Do not let tests fall back to live dependency values.
- Do not add broad `@testable import App` to every feature test.
- Do not put macro expansion tests in reducer test targets. Macro target wiring, expansion snapshots, and the host-platform `#if os(macOS)` guard live in `references/testing/macro-testing.md`.

## See Also

- `references/testing/macro-testing.md` for macro test target isolation, expansion snapshots, and stale-snapshot discipline.

## Tests

The validation here is the build. Run the smallest test target that exercises the affected package manifest or project target.
