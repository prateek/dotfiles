# Applies to: TCA 1.25+, iOS 16+

# Macro Testing

## Use When

Use this for Swift macros in feature support packages or library code.

## Guidance

- Keep macro tests in a macro-specific test target.
- Assert expansions with the local macro-testing style.
- Wrap platform-specific expansion tests when the macro output differs by OS.
- Delete stale expansion snapshots before updating an assertion if the tool expects regeneration.
- Keep macro expansion tests separate from TCA reducer behavior tests.
- Test the generated API shape that downstream reducers depend on.

## Example Shape

```swift
assertMacro {
  """
  @MyFeatureMacro
  struct Search {}
  """
} expansion: {
  """
  struct Search {
    // expected expansion
  }
  """
}
```

When the macro output contains platform-specific imports or availability, wrap the assertion the same way the package does. Do not normalize away meaningful generated code.

## Target Shape

Keep these targets separate:

```swift
.macro(
  name: "FeatureMacros",
  dependencies: [...]
),
.testTarget(
  name: "FeatureMacrosTests",
  dependencies: [
    "FeatureMacros",
    .product(name: "MacroTesting", package: "swift-macro-testing"),
  ]
)
```

Reducer behavior belongs in the feature test target. Macro tests prove expansion and diagnostics; reducer tests prove the generated API works in the app domain.

## Diagnostics

When a macro emits diagnostics, assert the diagnostic text and location. Do not rely only on expansion snapshots, because a broken diagnostic can make downstream feature errors hard to understand.

## Pitfalls

- Do not link a full app target into macro tests.
- Do not mix macro expansion tests with reducer behavior tests unless the package already does so.
- Do not accept expansion churn without reading the generated code.
- Do not update snapshots while compiler diagnostics are still failing.
- Do not put macro test helpers in the app product.
- Do not run macro tests only through an app test scheme. Run the macro test target directly when changing macro behavior.

## Tests

Run the macro test target directly. A reducer feature using macro-generated code still needs normal reducer tests.
