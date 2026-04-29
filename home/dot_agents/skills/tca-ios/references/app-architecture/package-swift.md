# Applies to: TCA 1.25+, iOS 16+

# Package.swift

## Use When

Use this when adding a TCA feature target, test target, dependency client, macro target, or sibling-library dependency.

## Guidance

- Add the package dependency at the package level once.
- Link only the needed products into each target.
- Add `ComposableArchitecture` to feature targets using TCA.
- Add `DependenciesTestSupport` to test targets that use dependency traits.
- Keep target dependencies explicit and minimal.
- Mirror feature target names and test target names clearly.
- Set package platforms to the app's real minimums, commonly `.iOS(.v16)` for this plugin's target baseline.
- Add sibling libraries only when the target imports them directly: `SQLiteData`, `StructuredQueries`, `StructuredQueriesSQLite`, `Sharing`, `UIKitNavigation`, `SnapshotTesting`, and so on.
- Keep live dependency implementations out of feature tests unless the test is an integration test.
- When using TCA 1.25 deprecation traits, enable them deliberately and expect temporary compile-time cost from overload traits.

## Feature Target Shape

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "MyAppPackage",
  platforms: [
    .iOS(.v16),
  ],
  products: [
    .library(name: "SettingsFeature", targets: ["SettingsFeature"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/pointfreeco/swift-composable-architecture",
      from: "1.25.0"
    ),
    .package(
      url: "https://github.com/pointfreeco/swift-dependencies",
      from: "1.0.0"
    ),
  ],
  targets: [
    .target(
      name: "SettingsFeature",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "SettingsFeatureTests",
      dependencies: [
        "SettingsFeature",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
      ]
    ),
  ]
)
```

## 2.0-Prep Traits

```swift
.package(
  url: "https://github.com/pointfreeco/swift-composable-architecture",
  from: "1.25.0",
  traits: [
    "ComposableArchitecture2Deprecations",
    "ComposableArchitecture2DeprecationOverloads",
  ]
)
```

Use `ComposableArchitecture2Deprecations` as a steady warning surface. Use `ComposableArchitecture2DeprecationOverloads` temporarily while migrating because it can add overload pressure.

## Persistence Products

```swift
.package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.0.0"),
.package(url: "https://github.com/pointfreeco/swift-structured-queries", from: "0.1.0"),
```

Link `SQLiteData` into targets that execute database reads/writes. Link `StructuredQueries` or `StructuredQueriesSQLite` into schema/query targets that import those modules directly.

## Pitfalls

- Do not link the app target into every feature test.
- Do not rely on transitive dependencies.
- Do not upgrade shared package versions casually in a multi-team app.
- Do not add every Point-Free product to every target.
- Do not introduce a package dependency without also adding the product to the target that imports it.
- Do not hand-edit generated manifests when Tuist or XcodeGen owns package wiring.

## Tests

Run `swift package describe` or the package build after manifest changes, then run the smallest affected test target. For Xcode projects, run the app target build after package resolution changes.
