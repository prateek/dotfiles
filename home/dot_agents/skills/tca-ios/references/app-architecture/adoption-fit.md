# Applies to: TCA 1.25+, iOS 16+

# Adoption Fit

## Use When

Use this when deciding whether a project or team should adopt, keep, or leave TCA.

## Fit Signals

- Complex multi-screen flows where navigation is product state.
- Shared domain state across features, tabs, widgets, or app extensions.
- Effects with cancellation, retries, streams, clocks, notifications, or long-lived subscriptions.
- Deep links and app-level routing that must be testable.
- A team willing to maintain reducer, action, dependency, and test conventions.
- Business logic that needs fast tests without UI automation.
- A modular app where feature boundaries can map to reducers and package targets.
- Existing dependency-control pain around dates, UUIDs, networking, analytics, persistence, or clocks.

## Caution Signals

- Small utility app with local UI state and little async work.
- Mostly isolated screens that do not share domain state.
- Team has no appetite for TCA API churn or migration windows.
- Many teams must upgrade one SPM version in lockstep.
- Root reducer already has ownership, compile-time, or scrollability pain.
- Parent/child encapsulation has become a recurring code review problem.
- High-frequency interaction paths, such as text editing or scrolling, would dispatch many actions per frame.
- The app already has a working architecture with good dependency control and tests.
- Key-person risk: a single engineer is the only one who can extend the reducer graph or upgrade TCA across the codebase. If that person rotates off the project, every later upgrade or large feature stalls.

## Alternatives

Use plain SwiftUI state for visual-only state. Use `@Observable` models when a small feature needs reference semantics and a few async methods. Use MVVM, Clean, or capability-based patterns when they give the team enough discipline with less framework surface.

Keep mixed architecture boundaries explicit:

- A TCA feature can present a UIKit adapter or SwiftUI view, but reducer state remains the source of truth.
- An `@Observable` model can own a small isolated feature, but it should not duplicate a TCA reducer's state.
- Shared dependencies can be used from both architectures.
- A migration should move leaf features first, then parents. Avoid recreating an old coordinator graph in reducer form.

## Recommendation Shape

A useful adoption recommendation answers:

1. Which workflows become easier to test first?
2. Which new costs does the team pay first?
3. Which module owns the root store and dependency bootstrap?
4. Which screens should stay outside TCA because they are local UI?
5. Which migration step can be shipped without changing behavior?

## Keep Or Leave

Keep TCA when the reducer tests catch real regressions, dependencies are controlled, and root composition still has clear ownership. Consider leaving or limiting TCA when compile time, reducer size, or action plumbing dominates feature work and the team can preserve testability another way.

## Tests

In decide mode, do not edit code. A good recommendation names the first reducer tests to write, the first non-TCA screens to leave alone, and the first cost the team will feel.
