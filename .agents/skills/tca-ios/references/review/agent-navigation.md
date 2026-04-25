# Applies to: TCA 1.25+, iOS 16+

# Navigation and Presentation Review

## Use When

Use this for stacks, sheets, alerts, dialogs, tabs, auth/onboarding routing, deep links, and dismissal.

## Inspect

- `StackState`, path reducers, and path actions.
- `@Presents`, destination reducers, presentation actions.
- Sheet, full-screen cover, popover, alert, and dialog state.
- Tabs and root routing.
- Auth/onboarding gates.
- Deep-link parsing and route handling.
- Dismissal behavior and child effect lifetime.

## Findings To Look For

- Navigation split between SwiftUI local state and TCA state without a boundary.
- Optional child state set nil while child effects continue.
- Manual booleans replacing destination state.
- Deep links scattered through views.
- Navigation state drifting from domain state.
- Root reducers knowing too much about leaf details.

## Output

Include a navigation map, lifecycle risks, findings, and navigation tests.
