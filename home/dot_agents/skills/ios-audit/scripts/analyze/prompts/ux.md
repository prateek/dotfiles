# ANALYZE prompt — UX pillar

You are writing the **UX** section of an iOS app audit. Your inputs are
the raw collector output at `.audit/raw/ux.json` — which includes static
screen inventory, navigation graph, component catalog, gesture usage, AND
the results of scripted flow walkthroughs with per-step screenshots and
accessibility trees, adaptive-layout signals, semantic-surface grep hits,
and workflow/device-lane coverage data — plus the screenshots themselves under
`.audit/raw/ux_run/`.

You should visually review screenshots, not just metadata.

Your outputs:

1. **Authored markdown** under `.audit/docs/ux/`.
2. **Findings JSON** at `.audit/findings/ux.json`. IDs start with `UX-`.

## Doc outline to produce

### `ux/screen-inventory.md`

A table of every screen in the app with:
- Screen name
- Source file + line
- Brief purpose (1 sentence)
- Entry points (where users get here)
- Key actions
- Dependencies (viewmodels, services)

Drive this from `screen_inventory` in the raw JSON, verify by reading the
source, and enrich with the actual rendered screenshots where available.

### `ux/navigation-graph.md`

A mermaid `graph LR` diagram built from `navigation_graph` edges. Group
by origin screen. Annotate unusual patterns: non-linear flows, modal
presentations, multi-entry destinations, dead ends.

### `ux/component-catalog.md`

Walk every reusable `View` struct in `component_catalog` and write:
- Name + file + line
- What it does (1-2 sentences)
- Props (parameters)
- Used by (from the nav graph / grep)
- Variants or states it can render

Group by theme (cards, rows, chrome, badges, buttons, etc.).

### `ux/flows/<flow>.md` (one per workflow in `flows.results.workflows`)

For each workflow executed:
- Name, tags, precondition, device lane, and target simulator
- Happy path description (1 paragraph)
- Step-by-step walkthrough referencing the captured screenshots inline
  (image paths are in `.audit/raw/ux_run/<flow>/` and match
  `flow.results.workflows[*].steps[*].screenshot_path`)
- Per-step accessibility-tree observations (use the `.accessibility` field
  to note a11y label gaps, missing traits, unlabelled buttons, etc.)
- Edge cases observed or expected
- Known failure modes (link to runtime docs)

### `ux/device-matrix.md`

- Declared workflow lanes from `workflow_matrix.declared_lanes`
- Which workflows actually executed on which device lane
- Whether adaptive-layout signals exist without compact + regular coverage
- Any lane-specific blockers (for example, iPad flow missing, large-screen controls clipped, sidebar-only nav untested)

### `ux/consistency-audit.md`

Compare recurring user-visible semantics across screens, workflows, and data sources.

- For media apps, explicitly compare home/catalog/detail/player/download/settings for:
  quality badges, version labels, audio language, subtitle/caption options,
  download/offline status, watch progress, and any playback preference labels
- For non-media apps, identify the equivalent repeated user-facing concepts
- For each concept: source of truth, where it is rendered, whether it is API-derived or hard-coded, and whether the values stay consistent across the surfaces
- If the audit cannot prove consistency, say that plainly and treat it as a finding when the concept matters to user choice

### `ux/layer-hierarchies.md`

A per-screen container-stack breakdown (from `code_health.layer_hierarchies`
which you may also use here). For each significant screen:
- Ordered list of containers (ZStack, VStack, ScrollView, etc.)
- Depth indicators
- Overlay regions (where gestures may conflict)
- Any place a custom `ViewRepresentable` is embedded

### `ux/gesture-audit.md`

Take `gesture_usage` sites and classify each:
- Simple tap (usually fine)
- Long-press with tap peer (conflict risk — use `simultaneousGesture` or cancel)
- Scroll container overlapping with horizontal swipe siblings
- `highPriorityGesture` or `simultaneousGesture` overrides
- Drag/drop or custom recognizers
- Swipe-to-dismiss conflicts with player scrubber, carousel, etc.

Flag every conflict risk as a finding.

### `ux/accessibility-audit.md`

Walk the accessibility trees from flow walkthroughs. Report:
- Elements without labels (found by scanning the tree for empty `label` fields)
- Elements without traits (buttons not marked as buttons)
- Dynamic Type fallbacks you can infer from the screenshots
- Color contrast concerns (visual inspection of screenshots)
- VoiceOver walkability (is the flow reachable without tapping specific coordinates?)

## Finding structure

IDs start with `UX-`. Severity rubric:

- **critical** — broken flow (step fails, wrong screen lands), blocker gesture
  conflict, unreachable UI, a11y barrier that prevents task completion
- **critical** — a core capability is advertised on one surface and unavailable on the path that should consume it
- **major** — cosmetic bug that appears on every launch (overflow, clipping),
  contrast failure, missing a11y label on a primary button, or primary metadata/options drift between key surfaces
- **moderate** — inconsistency, slightly off padding, placeholder copy in prod
- **minor** — polish: unused alignment, nit spacing

Priority (MoSCoW) and RICE scoring identical to Code Health. See
`references/priority-model.md`.

## Process

1. Read `.audit/raw/ux.json` fully.
2. Open each screenshot in `.audit/raw/ux_run/*/` and look at it. The
   text metadata is not a substitute for visual review.
3. Walk the accessibility tree for each captured step. Pay attention to
   nodes with empty labels or no traits.
4. Use `workflow_matrix` to state which device classes were actually covered and where lane coverage is missing.
5. Use `semantic_surface_signals` plus source inspection to compare repeated capability badges/options across screens. Do not assume consistency just because the labels look similar.
6. For each flow, write the walkthrough first (with inline screenshots),
   then the findings for that flow.
7. Write the cross-cutting docs (screen inventory, nav graph, components,
   gestures, a11y, device matrix, consistency) last — they reference everything else.
8. Every screenshot mentioned in the walkthrough must be committed under
   `docs/ux/flows/_screenshots/<flow>/` so the rendered docs are self-contained.
   Copy them as part of writing the markdown (the RENDER phase copies your
   authored `.audit/docs/` into `docs/` verbatim).

Visual review is the whole point of this pillar. Do not skip it.
