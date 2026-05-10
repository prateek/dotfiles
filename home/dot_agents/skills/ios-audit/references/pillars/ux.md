# Pillar: UX

## What it answers

- What does the app actually look like at every step of its core flows?
- Where does the navigation go? Which screens are dead ends?
- Which components are reused? Which are one-offs?
- Do gestures overlap or cancel each other?
- Is the app navigable with VoiceOver? Are labels and traits present?
- Does the flow break on the happy path?

## Raw inputs

The collector at `scripts/collect/ux.py` captures:

**Static (from the repo, no simulator):**

- **screen_inventory** — every `struct XxxView: View` that looks like a
  screen (holds a `NavigationStack`, `TabView`, `.navigationTitle`, or
  `.toolbar`, or is named `*View`). One entry per candidate screen.
- **navigation_graph** — every `NavigationLink(destination:)`,
  `NavigationLink(value:)`, `.sheet {}`, and `.fullScreenCover {}` edge,
  from-view → to-view.
- **component_catalog** — every `struct XxxView: View` that is NOT a
  screen (no NavigationStack or TabView), with file + line + LOC.
- **gesture_usage** — grep sites for `.onTapGesture`, `.onLongPressGesture`,
  `.gesture`, `.simultaneousGesture`, `.highPriorityGesture`, `.swipeActions`,
  `.contextMenu`, `.onDrag`, `.onDrop`.
- **adaptive_layout_signals** — code-derived evidence that the app adapts by
  size class, device idiom, split view, ViewThatFits, or other layout branches.
- **semantic_surface_signals** — grep hits for repeated user-facing concepts
  like quality badges, audio language, subtitle/caption options, downloads,
  and playback preferences so the analyzer can compare the screens that surface them.
- **workflow_matrix** — declared device lanes, workflow-to-lane assignments,
  executed lanes, and coverage gaps when adaptive UI exists but only one lane ran.

**Dynamic (from the simulator):**

- **flows** — per-workflow walk executed via `scripts/ux/run_workflows.py`:
  - screenshots at every step (PNG)
  - accessibility tree JSON at every step (via `screen_mapper.py --json`)
  - action metadata (tap target, type, duration_ms)
  - per-step success flag

## Required tools

- **Python 3.10+** with `pyyaml` and `pillow` for flow execution
- **ios-simulator-skill** at `~/.agents/skills/ios-simulator-skill/`
- **A booted iOS simulator** with the target app installed

You can skip the UX pillar entirely with `--no-ux` if you don't have a
simulator available or only want the code-derived parts.

## Workflow YAML

Flow definitions live OUTSIDE the skill. Projects should own their own
workflow YAML at `<repo>/.audit/workflows.yaml` or equivalent. See
`examples/movies-do.yaml` for a working reference.

Credentials should always be `${ENV_VAR}` references that the collector
expands at runtime. Never commit plaintext credentials.

## Analyzer outputs

See `scripts/analyze/prompts/ux.md`. The prompt produces:

- `ux/screen-inventory.md`
- `ux/navigation-graph.md` (with mermaid diagram)
- `ux/component-catalog.md`
- `ux/flows/<flow>.md` (one per workflow)
- `ux/layer-hierarchies.md`
- `ux/gesture-audit.md`
- `ux/accessibility-audit.md`
- `ux/device-matrix.md`
- `ux/consistency-audit.md`

Screenshots referenced from flow docs should be copied into
`.audit/docs/ux/flows/_screenshots/<flow>/` so that when RENDER copies
`.audit/docs/` into the target `docs/` tree, the images travel with the
prose.

## Common findings patterns

| ID example | Pattern | Severity |
|---|---|---|
| UX-001 | Gesture conflict: tap + long-press on the same view without `simultaneousGesture` | critical |
| UX-002 | Flow step fails: tap target does not exist on the screen shown | critical |
| UX-003 | Primary button has no accessibility label | major |
| UX-004 | Hardcoded English copy visible in screenshots (should be localized) | major |
| UX-005 | Nav link points to a view that no longer exists (compile-time check missing) | major |
| UX-006 | Two siblings use the same swipe direction → unreliable | moderate |
| UX-007 | Component used in 1 place but extracted as reusable — dead abstraction | minor |
| UX-008 | Missing dark-mode asset (visible in light-mode screenshot only) | moderate |
| UX-009 | Adaptive layout detected but only one device class was audited | major |
| UX-010 | Title/detail/player/download surfaces disagree about the same capability | major |
