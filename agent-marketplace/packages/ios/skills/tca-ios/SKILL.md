---
name: tca-ios
description: >-
  Build, review, modernize, or diagnose iOS 16+ applications that use modern
  Point-Free Composable Architecture (TCA 1.25+) or sibling libraries:
  ComposableArchitecture, Dependencies, SwiftNavigation, Sharing, Perception,
  CasePaths, IdentifiedCollections, CustomDump, SQLiteData, StructuredQueries,
  SnapshotTesting, MacroTesting, IssueReporting. Use whenever the user mentions
  TCA, Composable Architecture, @Reducer, @ObservableState, StoreOf, TestStore,
  @Dependency, StackState, Destination enums, @Shared, @FetchAll, @Table,
  @Column, @CasePathable, WithPerceptionTracking, WithViewStore (legacy
  removal), ReducerProtocol (legacy removal), is working on an iOS app that
  imports any of those modules, or asks whether TCA is the right architecture
  for an iOS project.
---

# TCA iOS

## Posture

You are working on an iOS 16+ codebase that uses TCA or adjacent Point-Free libraries. Target modern TCA 1.25+ for new guidance, including the live 2.0-prep deprecation traits, but verify the installed version before recommending APIs. Older APIs are recognized only as inputs to migration or removal, not as live patterns.

Be pragmatic: product correctness, clear state ownership, testability, and maintainability outrank purity. Do not propose sweeping rewrites unless the user explicitly authorizes them.

## Mode Banner

Declare the active TCA iOS mode at the top of every response that invokes this skill, exactly once:

`**Mode: tca-ios/build**`

Allowed banners: `**Mode: tca-ios/build**`, `**Mode: tca-ios/review**`, `**Mode: tca-ios/modernize**`, `**Mode: tca-ios/diagnose**`, `**Mode: tca-ios/decide**`.

## Version Probe

Before changing or judging code, inspect the installed TCA generation:

1. Check `Package.swift`, `Package.resolved`, `.xcodeproj/project.pbxproj`, Tuist manifests, XcodeGen specs, and local package pins for `swift-composable-architecture`.
2. Search for markers:
   - Modern: `@Reducer`, `@ObservableState`, `StoreOf<Feature>`, direct store observation, `@Dependency`, `Effect.run`, `@Presents`.
   - Transitional: `@Reducer` mixed with `ViewStore`, `@PresentationState`, Combine schedulers, or old navigation helpers.
   - Legacy: `ReducerProtocol`, `reduce(into:)` as the top-level reducer entry point, `Reducer.combine`, Environment structs, `WithViewStore`, `IfLetStore`, `ForEachStore`, `SwitchStore`, `NavigationStackStore`, `Effect.task`, `Effect.publisher`.
3. Load `references/version-ledger.md` when the version or API generation matters. Treat TCA 1.25+ as the target for new work.
4. Load `references/index.md` when choosing optional or support references.
5. Do not modernize a stable legacy area unless the user asked for it or the old API creates concrete risk.

## Mode Router

Default first-turn mode is `build` when the prompt triggers this skill but does not clearly choose another mode.

When the user asks to add, scaffold, or implement a feature, use `build`. Load:
- `references/core/modern-tca-anatomy.md`
- `references/core/state-shape.md`
- `references/core/action-vocabulary.md`
- `references/core/naming-conventions.md`
- `references/core/reducer-composition.md`
- `references/core/view-integration.md`
- `references/effects/effect-run.md`
- `references/effects/dependencies.md`
- `references/testing/teststore-basics.md`
- navigation, persistence, or app-architecture references when the task touches those areas

When the user asks for a review, audit, health check, or "is this idiomatic", use `review`. Load:
- `references/review/coordinator.md`
- `references/review/survey.md`
- `references/review/finding-format.md`
- `references/review/synthesis.md`
- the focused review agents that match the code under review
- supporting technical references from `references/index.md` before finalizing a finding

When the user asks to migrate, upgrade, remove legacy APIs, adopt Swift 6, or prepare for 2.0, use `modernize`. Load:
- `references/modernize/version-probe.md`
- `references/version-ledger.md`
- the specific migration recipe for each detected legacy API

When the user brings a failure, warning, leak, re-render storm, TestStore diff, cancellation issue, dismissal bug, Sendable warning, or database tracing problem, use `diagnose`. Load:
- `references/version-ledger.md`
- the matching diagnose reference listed in `references/index.md`
- supporting references from `effects`, `testing`, `navigation`, `ui`, or `persistence`

When the user asks "should I use TCA", "should we adopt TCA", "is TCA the right architecture", "evaluate whether (TCA / Composable Architecture)", "architecture recommendation", "TCA vs MVVM", "TCA vs `@Observable`", "TCA vs SwiftUI `@State`", or otherwise asks for an architecture decision, use `decide`. **No edits.** Load:
- `references/app-architecture/observable-vs-tca.md`
- `references/app-architecture/adoption-fit.md`

If a prompt spans modes, choose one mode for the current response, state which mode the next turn should be in, and tell the user which work remains. If switching from the last declared mode, write one line before the new mode banner:

`Switching from tca-ios/review to tca-ios/diagnose: user requested a fix for finding N.`

## Mode Contracts

**Build** may edit files. Scaffold tests alongside feature code in the same change. Match the surrounding file's style. Do not refactor neighboring code that the user did not ask to change.

**Review** is read-only. Do not edit files. Produce findings using `references/review/finding-format.md` (severity, confidence, files, evidence, why, fix, test). Do not invent issues. Prefer pragmatic incremental recommendations over rewrites.

**Modernize** probes version first via `references/modernize/version-probe.md`. Migrate incrementally per recipe; justify each migration by risk reduction or compatibility, not style. Edits stay scoped to the recipe.

**Diagnose** starts from the user's exact symptom (TestStore diff, Xcode warning, observed behavior). Reproduce or inspect the smallest failing surface, then apply one narrow fix. Edit only the file(s) named in the diagnosis.

**Decide** makes no code edits. Produce a recommendation grounded in `observable-vs-tca.md` and `adoption-fit.md`. Recommend the least ceremony that still fits the product and team.

## Load-Bearing Opinions

- Name a reducer `Settings`, not `SettingsReducer`.
- Name actions after user events or system results: `saveButtonTapped`, `searchResponse(Result<...>)`, `delegate(.saved)`.
- Use delegate actions for child-to-parent communication.
- Keep state as the source of truth. Model impossible states with enums, optional presentation state, or more precise domain types.
- Use `@Reducer`, `@ObservableState`, `StoreOf<Feature>`, direct store observation, `@Bindable`, and `BindingReducer`.
- Avoid `WithViewStore`, `ViewStore`, `IfLetStore`, `ForEachStore`, `SwitchStore`, and `NavigationStackStore` in modern code.
- Avoid `ReducerProtocol`, old closure reducers, and top-level `reduce(into:)` implementations in new code.
- Put `@Dependency` properties directly in reducers. In `@Observable` classes, use `@ObservationIgnored @Dependency`.
- Control `Date`, `UUID`, clocks, randomness, networking, files, analytics, notifications, and database clients through dependencies.
- Provide Sendable live dependency implementations. Make test and preview values deliberate.
- Prefer `Effect.run` with async/await. Avoid legacy Combine-based effects and old effect scheduling operators.
- Give repeatable effects a cancellation ID. Search, refresh, polling, subscriptions, and sheet-owned streams must have a lifecycle story.
- Dismissal must cancel effects scoped to dismissed features.
- Use `IdentifiedArrayOf<Child.State>` with `IdentifiedActionOf<Child>` for child lists.
- Use `@Presents` plus `Destination` enum reducers for tree navigation; use `StackState` and `StackActionOf` for stack navigation.
- Use `@CasePathable` and `@dynamicMemberLookup` together for case-path access where the ecosystem expects it.
- Use `@Shared` for shared values and persisted values only when there is a real shared source of truth.
- Bootstrap SQLiteData with `bootstrapDatabase` and call it from `prepareDependencies` in the app entry point.
- Wrap view bodies and lazy SwiftUI closures in `WithPerceptionTracking` for iOS 16 deployments; iOS 17 uses native Observation.
- In tests, prefer `expectDifference` over `expectNoDifference` when asserting a mutation: it names the changed fields directly while still comparing full before/after values. Compare full values, not transformations. Use non-exhaustive TestStore only when the exhaustive test would mirror implementation noise.
- Do not recommend broad rewrites unless the user explicitly authorizes them.

## Decision Heuristic

TCA is a good fit when an app has multi-screen flows, shared domain state, effect-heavy logic, deep links, cancellation needs, or a team that values reducer-level tests.

Prefer plain SwiftUI state or an `@Observable` model for a small utility app, isolated screens, mostly local UI state, or a team that will not maintain the TCA conventions.

Use `references/app-architecture/adoption-fit.md` for organization-level concerns: module lockstep, root reducer growth, encapsulation leaks, and key-person risk.

## Reference Map

- `references/core/`: feature anatomy, naming, state, actions, reducer composition, views, case paths.
- `references/effects/`: dependencies, effect lifecycles, cancellation, clocks, Sendable, issue reporting.
- `references/navigation/`: destination enums, stacks, sheets, deep links, dismissal, global routers, UIKit navigation.
- `references/testing/`: TestStore, dependency overrides, cancellation, navigation, shared state, custom dump, snapshots, macros.
- `references/persistence/`: Sharing, SQLiteData, StructuredQueries, iCloud, migrations.
- `references/app-architecture/`: app root, session, tabs, modules, Package.swift, Xcode integration, adoption fit.
- `references/ui/`: SwiftUI idioms, observable models, UIKit interop.
- `references/back-deploy/`: Perception support for iOS 16 deployments.
- `references/review/`: coordinator and focused review-agent prompts.
- `references/modernize/`: migration recipes.
- `references/diagnose/`: symptom-to-cause-to-fix guides.
- `references/index.md`: mode routing and support-reference maps.
- `references/version-ledger.md`: TCA API generation and migration checkpoints.
