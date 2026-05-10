# Applies to: TCA 1.25+, iOS 16+

# Version Ledger

Use this before recommending a TCA API migration. Version facts are current to the research snapshot dated 2026-04-24.

Default target: iOS 16+ with modern TCA 1.25+. Older rows exist to identify and migrate legacy code, not to steer new code.

## Applicability Header

Each reference starts with `# Applies to: TCA 1.25+, iOS 16+`.

References whose subject is a legacy API or a bounded migration window should use a range form so future readers know when the page stops applying:

`# Applies to: TCA 1.0 – 1.6, iOS 16+`

Use the floor form (`1.25+`) for guidance about current code. Use the range form when the reference exists only to identify or migrate a specific era.

## API Generations

| Generation | Common markers | Usual recommendation |
|---|---|---|
| Closure era, pre-0.41 | `Reducer<State, Action, Environment>`, `pullback`, `combine`, `Effect` with Combine schedulers | Treat as legacy. Modernize only with user buy-in or when touching the feature. |
| ReducerProtocol era, 0.41-1.3 | `ReducerProtocol`, `reduce(into:)`, `body`, environment often gone | Transitional. Prefer `@Reducer` for new code. |
| Macro era, 1.4-1.6 | `@Reducer`, case-path scoping, `IdentifiedAction` | Good base, but views may still be ViewStore-heavy. |
| Observation era, 1.7-1.9 | `@ObservableState`, `@Presents`, direct store observation, no helper store views | Modern SwiftUI integration. Add Perception wrappers for older OSes. |
| Shared-state era, 1.10-1.16 | `@Shared`, UIKit integration in 1.13, Swift 6 clean library in 1.15 | Modern, with more sibling-library surface. |
| Sharing extraction, 1.17+ | `swift-sharing` as separate package | Current baseline for this skill. |
| 2.0 prep, 1.25+ | package traits, projected enum scopes, Combine effect deprecations | Enable traits in a controlled branch and follow recipes. |

## Milestones

- 1.4: `@Reducer` macro and modern action scoping became the target for new features.
- 1.7: `@ObservableState` and `@Presents` removed most `ViewStore` boilerplate and deprecated helper store views in new code.
- 1.10: `@Shared` introduced shared and persisted state tools.
- 1.12: TestStore gained Swift Testing support.
- 1.13: UIKit integration moved through swift-navigation tools like `observe` and `@UIBindable`.
- 1.15: TCA itself built cleanly in Swift 6 language mode.
- 1.17: Sharing moved to the separate `swift-sharing` package.
- 1.25: 2.0-prep traits exposed future deprecations, including old Combine effect operators and non-projected enum destination scopes.

## 1.25 Trait Posture

Enable `ComposableArchitecture2Deprecations` to keep seeing future 2.0 warnings. Enable `ComposableArchitecture2DeprecationOverloads` temporarily during migration; it can add overload pressure to builds.

Do not treat a trait warning as a reason for sweeping rewrite. Use it to queue narrow migrations around code already being touched.
