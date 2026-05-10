# Applies to: TCA 1.25+, iOS 16+

# Reference Index

## Contents

- [build](#build)
- [review](#review)
- [modernize](#modernize)
- [diagnose](#diagnose)
- [decide](#decide)

Use this file to choose reference bundles without loading the whole skill.

Rows are intentionally precise. Every file under `tca-ios/references/` appears at least once below.

## Update Rule

- Adding a new reference: add a row to at least one mode's `Required` or `Optional` table.
- Adding a new trigger keyword to `SKILL.md`: update the matching mode's `Optional` `trigger-keywords` column so the router and the index agree.
- Renaming a reference: update every row that names it.
- The `Advisory-against` table is a soft signal. The model may still load a flagged reference if the user's prompt explicitly names it or gives a specific reason; declare the override in one line.

Keep this rule in `design/tca-ios/authoring-conventions.md` aligned with the steps here.

## build

### Required

| ref-path | trigger-keywords | reason |
|---|---|---|
| references/index.md | always | Choose optional and support references without loading the whole library. |
| references/core/modern-tca-anatomy.md | always | Baseline modern feature shape. |
| references/core/state-shape.md | always | State ownership and impossible states. |
| references/core/action-vocabulary.md | always | Action naming and routing. |
| references/core/naming-conventions.md | always | Shared names for features, actions, dependencies, and tests. |
| references/core/reducer-composition.md | always | Parent, child, optional, enum, and list composition. |
| references/core/view-integration.md | always | Store and SwiftUI integration. |
| references/effects/dependencies.md | always | Controlled dependencies for side effects. |
| references/effects/effect-run.md | always | Async effect shape. |
| references/testing/teststore-basics.md | always | Reducer tests for build work. |

### Optional

| ref-path | trigger-keywords | reason |
|---|---|---|
| references/core/case-paths-and-enums.md | enum, case path, @CasePathable, Destination | Enum-case access and destination modeling. |
| references/effects/cancellation.md | cancel, debounce, polling, subscription, sheet-owned | Effect lifecycle. |
| references/effects/clocks-and-time.md | debounce, throttle, timer, delay, clock | Time-based behavior and tests. |
| references/effects/dependency-keys.md | new dependency, liveValue, testValue, previewValue | Dependency client definitions. |
| references/effects/issue-reporting.md | reportIssue, fallback, unexpected dependency | Visible development-time failures. |
| references/effects/swift6-sendable.md | Swift 6, Sendable, actor isolation | Strict concurrency in effect code. |
| references/navigation/deep-links.md | deep link, URL, universal link, notification route | URL-to-state routing. |
| references/navigation/destination-enum.md | sheet, alert, dialog, popover, full-screen cover | Tree navigation with destinations. |
| references/navigation/dismissal-lifecycle.md | dismiss, optional child, presentation lifecycle | Dismissal and child effect lifetimes. |
| references/navigation/global-router-pattern.md | global router, app-wide navigation, coordinator migration | Large-app routing. |
| references/navigation/sheets-alerts-dialogs.md | sheet, alert, confirmationDialog, popover | SwiftUI presentation modifiers. |
| references/navigation/stack-state.md | stack, push, pop, drill-down | Stack navigation. |
| references/navigation/uikit-navigation.md | UIKit, UIViewController, @UIBindable, observe | UIKit navigation interop. |
| references/testing/cancellation-tests.md | cancellation test, debounce test, long-lived effect | Asserting effect teardown. |
| references/testing/custom-dump.md | diff, expectDifference, customDump | Readable assertions. |
| references/testing/dependency-overrides-in-tests.md | override dependency, UUID, date, clock, client | Deterministic test dependencies. |
| references/testing/exhaustive-vs-non-exhaustive.md | brittle test, non-exhaustive, implementation noise | Exhaustivity choices. |
| references/testing/macro-testing.md | macro, assertMacro, expansion | Macro test targets and snapshots. |
| references/testing/navigation-tests.md | sheet test, stack test, deep-link test, delegate flow | Navigation coverage. |
| references/testing/shared-state-tests.md | @Shared test, app storage, file storage | Shared-state assertions. |
| references/testing/snapshot-testing.md | snapshot, visual regression, rendered output | Snapshot coverage. |
| references/testing/swift-testing-hygiene.md | Swift Testing, test target, duplicate class | Test target hygiene. |
| references/persistence/migrations.md | migration, schema change, backfill | SQLite schema migration. |
| references/persistence/shared-state.md | @Shared, @SharedReader, app storage, file storage | Shared and persisted values. |
| references/persistence/sqlite-data-bootstrap.md | bootstrapDatabase, prepareDependencies, database setup | App database boot order. |
| references/persistence/sqlite-data-drafts-assets.md | draft, asset, blob, image | Draft rows and asset fields. |
| references/persistence/sqlite-data-fetching.md | @FetchAll, @FetchOne, observed query, fetch animation | Observed database reads. |
| references/persistence/sqlite-data-icloud.md | iCloud, CloudKit, share acceptance, SyncEngine | Cloud-backed SQLiteData. |
| references/persistence/sqlite-data-previews.md | preview, Xcode preview, preview database | Database-backed previews. |
| references/persistence/sqlite-data-testing.md | SQLite test, deterministic ID, database uuid | Database tests. |
| references/persistence/sqlite-data-writing.md | insert, update, upsert, delete, transaction | Database writes. |
| references/persistence/structured-queries-joins-ctes.md | join, CTE, subquery, alias | Multi-table queries. |
| references/persistence/structured-queries-schema.md | @Table, @Column, schema, primary key | StructuredQueries schema. |
| references/persistence/structured-queries-select.md | SELECT, WHERE, ORDER BY, GROUP BY, LIMIT | Reads and filters. |
| references/persistence/structured-queries-sql-functions.md | SQL function, raw SQL, operator, expression | SQL escape hatches. |
| references/persistence/structured-queries-sqlite.md | FTS5, rowid, collation, trigger, view | SQLite-specific query APIs. |
| references/persistence/structured-queries-writes.md | insert, update, upsert, delete | StructuredQueries writes. |
| references/app-architecture/module-boundaries.md | module, package, circular import, feature target | Module boundaries. |
| references/app-architecture/package-swift.md | Package.swift, product, target, dependency | SPM edits. |
| references/app-architecture/root-store.md | @main, AppFeature, boot, dependency preparation | Root store setup. |
| references/app-architecture/session-auth.md | login, logout, onboarding, token refresh | Session routing. |
| references/app-architecture/tabs-and-roots.md | tab, root, cross-tab | Tab roots. |
| references/app-architecture/xcode-spm-integration.md | Xcode project, workspace, local package | Xcode and package integration. |
| references/ui/modern-swiftui.md | SwiftUI, binding, task, action closure | Modern SwiftUI idioms. |
| references/ui/observable-models.md | @Observable model, no reducer, local model | Observable model boundary. |
| references/ui/uikit-interop.md | UIKit interop, UIViewControllerRepresentable | SwiftUI/UIKit integration. |
| references/back-deploy/ios16-perception.md | iOS 16, Perception, WithPerceptionTracking | Back-deployed observation for iOS 16. |

### Advisory-against

| ref-path | trigger-keywords | reason |
|---|---|---|
| references/review/coordinator.md | review | Review posture is read-only. Load only when building from an accepted review finding. |
| references/review/survey.md | survey | Survey belongs to review mode. |
| references/review/synthesis.md | synthesis | Synthesis belongs to review mode. |

## review

### Required

| ref-path | trigger-keywords | reason |
|---|---|---|
| references/index.md | always | Choose focused review and support references. |
| references/review/coordinator.md | always | Orchestrates review. |
| references/review/survey.md | always | Repo map before findings. |
| references/review/finding-format.md | always | Shared output schema. |
| references/review/synthesis.md | always | Final review structure and merge rules. |
| references/version-ledger.md | always | Interpret installed TCA generation. |

### Optional

| ref-path | trigger-keywords | reason |
|---|---|---|
| references/review/agent-domain-reducer.md | state, action, reducer, domain | Domain modeling pass. |
| references/review/agent-effects-deps.md | effect, dependency, client, SDK | Side-effect and dependency pass. |
| references/review/agent-concurrency.md | cancel, async, stream, Sendable | Concurrency and lifecycle pass. |
| references/review/agent-swiftui.md | SwiftUI, view, binding, observation | View integration pass. |
| references/review/agent-navigation.md | navigation, sheet, stack, deep link, dismiss | Navigation pass. |
| references/review/agent-testing.md | test, TestStore, deterministic, fixture | Test quality pass. |
| references/review/agent-modularity.md | module, package, root, boundary | Modularity pass. |
| references/review/agent-modernization.md | legacy, ViewStore, ReducerProtocol, modernize | API consistency pass. |

### Support Before Final Findings

Load these support references only when a focused review agent is about to produce or verify a concrete finding.

| review-agent | support refs | reason |
|---|---|---|
| references/review/agent-domain-reducer.md | references/core/state-shape.md; references/core/action-vocabulary.md; references/core/reducer-composition.md; references/core/naming-conventions.md | Verify domain, action, and reducer claims. |
| references/review/agent-effects-deps.md | references/effects/dependencies.md; references/effects/dependency-keys.md; references/effects/effect-run.md; references/effects/cancellation.md | Verify dependency and effect findings. |
| references/review/agent-concurrency.md | references/effects/swift6-sendable.md; references/effects/cancellation.md; references/diagnose/effect-leaks.md | Verify lifecycle and sendability findings. |
| references/review/agent-swiftui.md | references/core/view-integration.md; references/ui/modern-swiftui.md; references/back-deploy/ios16-perception.md | Verify observation and view-integration findings. |
| references/review/agent-navigation.md | references/navigation/destination-enum.md; references/navigation/stack-state.md; references/navigation/dismissal-lifecycle.md; references/navigation/sheets-alerts-dialogs.md | Verify presentation and stack navigation findings. |
| references/review/agent-testing.md | references/testing/teststore-basics.md; references/testing/exhaustive-vs-non-exhaustive.md; references/testing/dependency-overrides-in-tests.md; references/testing/cancellation-tests.md | Verify testing findings. |
| references/review/agent-modularity.md | references/app-architecture/module-boundaries.md; references/app-architecture/root-store.md; references/app-architecture/package-swift.md; references/app-architecture/xcode-spm-integration.md | Verify module and package findings. |
| references/review/agent-modernization.md | references/modernize/version-probe.md; references/modernize/viewstore-to-bindings.md; references/modernize/reducerprotocol-to-reducer.md; references/modernize/prep-for-2-0.md | Verify modernization findings. |

### Advisory-against

| ref-path | trigger-keywords | reason |
|---|---|---|
| references/modernize/version-probe.md | migrate, fix | Review can recommend migration, but it does not edit. |
| references/diagnose/effect-leaks.md | fix leak | Diagnose mode owns fixes. |

## modernize

### Required

| ref-path | trigger-keywords | reason |
|---|---|---|
| references/index.md | always | Choose migration support references. |
| references/modernize/version-probe.md | always | Detect installed version first. |
| references/version-ledger.md | always | Interpret API generation. |

### Optional

| ref-path | trigger-keywords | reason |
|---|---|---|
| references/modernize/viewstore-to-bindings.md | WithViewStore, ViewStore, view state, binding helper | Observation migration. |
| references/modernize/reducerprotocol-to-reducer.md | ReducerProtocol, reduce(into:) | Macro reducer migration. |
| references/modernize/environment-to-dependency.md | Environment, dependency initializer | Dependency migration. |
| references/modernize/combine-to-run.md | Effect.publisher, Effect.task, debounce, throttle, Combine | Async effect migration. |
| references/modernize/nav-legacy-to-destination.md | @PresentationState, IfLetStore, NavigationStackStore, boolean navigation | Navigation migration. |
| references/modernize/swift6-migration.md | Swift 6, Sendable, strict concurrency | Swift 6 migration. |
| references/modernize/ios16-back-deploy.md | iOS 16, Perception, WithPerceptionTracking | Back-deployed observation while modernizing. |
| references/modernize/prep-for-2-0.md | 2.0, trait, TCA 1.25, deprecation | 2.0-prep trait sweep. |
| references/effects/swift6-sendable.md | Sendable, .run, onChange, ifLet | Supporting effect guidance. |
| references/navigation/destination-enum.md | destination, presentation | Supporting navigation target shape. |
| references/testing/teststore-basics.md | behavior identical, regression test | Behavior-preserving tests. |

### Advisory-against

| ref-path | trigger-keywords | reason |
|---|---|---|
| references/review/coordinator.md | audit | Modernize mode edits narrowly instead of producing a full audit. |

## diagnose

Diagnose mode loads symptom-specific files via `Optional` rather than pulling every `diagnose/*` page into context. The user's reported symptom is concrete enough that one or two matching pages plus the supporting effects/testing/navigation refs are more useful than the full diagnose tree.

### Required

| ref-path | trigger-keywords | reason |
|---|---|---|
| references/index.md | always | Choose symptom-specific support references. |
| references/version-ledger.md | always | Interpret installed API generation. |

### Optional

| ref-path | trigger-keywords | reason |
|---|---|---|
| references/diagnose/action-pingpong.md | ping-pong, internal action, delegate noise | Action-flow diagnosis. |
| references/diagnose/action-rate.md | keystroke, scroll, debounce, throttle, high frequency | Action volume diagnosis. |
| references/effects/clocks-and-time.md | keystroke, scroll, debounce, throttle, high frequency | Clock and debounce support for action-rate fixes. |
| references/diagnose/dismissal-bugs.md | dismiss, sheet, nil child, save cancel | Presentation lifecycle diagnosis. |
| references/diagnose/effect-leaks.md | still running, leak, subscription, stream | Unfinished effect diagnosis. |
| references/diagnose/perception-warnings.md | Perception warning, WithPerceptionTracking, iOS 16 | Back-deployed observation diagnosis. |
| references/back-deploy/ios16-perception.md | Perception warning, WithPerceptionTracking, iOS 16 | Perception wrapper rules. |
| references/diagnose/perf-hygiene.md | slow reducer, throughput, copy, performance | App-scale performance diagnosis. |
| references/diagnose/reducer-debugging.md | printChanges, action trace, hard to trace | Reducer debugging tools. |
| references/diagnose/rerender-diagnosis.md | re-render, invalidation, slow view, broad observation | View invalidation diagnosis. |
| references/diagnose/sendable-warnings.md | Sendable, actor isolation, strict concurrency | Swift 6 warning diagnosis. |
| references/effects/swift6-sendable.md | Sendable, actor isolation, strict concurrency | Effect sendability support. |
| references/diagnose/sqlite-query-tracing.md | SQL trace, SQLite, query churn, trigger noise | Database query tracing. |
| references/diagnose/teststore-failures.md | TestStore, unexpected state, missing receive, unfinished effect | TestStore failure diagnosis. |
| references/testing/teststore-basics.md | TestStore, unexpected state, missing receive | TestStore assertion styles. |
| references/testing/exhaustive-vs-non-exhaustive.md | unexpected action, brittle test, non-exhaustive | Exhaustivity support for TestStore failures. |
| references/effects/cancellation.md | cancel, long-lived, lifecycle | Supporting effect lifecycle guidance. |
| references/testing/cancellation-tests.md | assert cancellation, teardown test | Verification for effect fixes. |
| references/navigation/dismissal-lifecycle.md | dismissed child, optional state | Supporting navigation lifecycle guidance. |
| references/persistence/sqlite-data-fetching.md | @FetchAll, fetch animation | Supporting fetch diagnosis. |

### Advisory-against

| ref-path | trigger-keywords | reason |
|---|---|---|
| references/app-architecture/adoption-fit.md | architecture | Diagnose should stay on the reported symptom unless the symptom is organizational. |

## decide

### Required

| ref-path | trigger-keywords | reason |
|---|---|---|
| references/index.md | always | Choose architecture decision support references. |
| references/app-architecture/observable-vs-tca.md | always | Code-level architecture choice. |
| references/app-architecture/adoption-fit.md | always | Team and product fit. |

### Optional

| ref-path | trigger-keywords | reason |
|---|---|---|
| references/ui/observable-models.md | @Observable, model, small feature | Practical non-TCA feature shape. |
| references/app-architecture/module-boundaries.md | team scale, modules, ownership | Scaling cost. |

### Advisory-against

| ref-path | trigger-keywords | reason |
|---|---|---|
| references/core/modern-tca-anatomy.md | implement, scaffold | Decide mode does not edit or scaffold. |
