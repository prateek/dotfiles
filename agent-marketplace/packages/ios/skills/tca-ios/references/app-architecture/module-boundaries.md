# Applies to: TCA 1.25+, iOS 16+

# Module Boundaries

## Use When

Use this for SPM feature modules, shared domain packages, dependency clients, and circular import problems.

## Guidance

- Put large features in their own modules when build time, ownership, or reuse justifies it.
- Keep dependency clients in shared dependency modules when many features use them.
- Keep shared domain models separate from feature UI when server/API and app features both use them.
- Avoid sibling feature imports. Coordinate through parents or shared domain modules.
- Keep tests beside the feature module they exercise.
- Keep the app target thin: app entry point, root view, root feature composition, and platform adapters.
- Put live dependency implementations below the feature layer so tests can link feature modules without live services.
- Use `Internal` feature helpers inside the feature target. Export only the reducer, view/model, and domain types other modules need.
- Split a feature module when ownership, compile time, or reuse says yes, not because every screen needs a package.
- Let parent modules import child feature modules for reducer composition. Child modules should not import parents.

## Common Graph

```text
App
  imports AppFeature, LiveDependencies

AppFeature
  imports HomeFeature, SettingsFeature, AuthFeature, SharedModels

HomeFeature
  imports SharedModels, DependencyClients

HomeFeatureTests
  imports HomeFeature, DependenciesTestSupport
```

## Dependency Clients

Keep interfaces near shared domain when many features use them:

```swift
struct AnalyticsClient: Sendable {
  var track: @Sendable (AnalyticsEvent) async -> Void
}
```

Live implementations can live in `AnalyticsClientLive`, while feature tests override through `withDependencies` or suite traits.

## Root Composition

The root feature should compose child reducers and route cross-feature actions. It should not know leaf view layout, networking details, SQL text, or analytics payload formatting.

## Pitfalls

- Do not create one module per tiny view if it slows navigation and build work.
- Do not put unrelated models into a junk-drawer shared module.
- Do not make root import every leaf's internals beyond reducer composition needs.
- Do not let shared modules depend on feature modules.
- Do not link live dependency products into feature test targets unless the test explicitly exercises live integration.
- Do not use module boundaries to hide parent-child state reach-through. Fix the action and state ownership.

## Tests

The build graph is the first test. Run the affected package or workspace build after moving boundaries. Then run the feature test target and at least one root-composition test that proves the parent still scopes child actions correctly.
