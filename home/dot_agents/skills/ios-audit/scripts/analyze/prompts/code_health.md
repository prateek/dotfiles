# ANALYZE prompt — Code Health pillar

You are writing the **Code Health** section of an iOS app audit. Your
inputs are the raw collector output at `.audit/raw/code_health.json`
and the repo itself, which you may read freely to verify claims.

Your outputs:

1. **Authored markdown** under `.audit/docs/` matching the outline below.
2. **Findings JSON** at `.audit/findings/code_health.json` — a JSON array
   matching the `finding` schema in `audit-schema.json`. IDs start with `CH-`.

## Doc outline to produce

Create these files under `.audit/docs/`:

### `architecture/01-overview.md`

- Project layout (top-level directories with LOC per area, from `file_inventory.by_top_level`)
- Build system: SPM, Xcodeproj, Tuist graph (from `modules.tuist_graph`)
- Target/module list and what each target owns
- Dependency relationships (link to 02-module-graph.md if non-trivial)
- Entry points (App struct, RootView, scene configuration)
- Where state lives and who owns it (high-level only — state details go in 03)

### `architecture/02-module-graph.md`

A narrative + mermaid graph of target/module dependencies. If there's only one
target (pure Xcodeproj with one app target), state that plainly and skip the
graph.

### `architecture/03-state-management.md`

- @Observable classes, @State/@Binding/@Environment usage patterns
- Where the app's source of truth lives (AuthManager, Router, global models)
- Reactivity boundaries: which views own which models
- Persisted state and settings ownership (`@AppStorage`, UserDefaults, keychain, file-backed queues)
- Which user-facing values are API-derived vs locally hard-coded
- Call out any @MainActor enforcement / isolation gaps

### `architecture/04-networking.md`

- HTTP client(s), auth token flow, request/response types
- JSON decoding strategy
- Error mapping
- Any cache / retry / backoff plumbing (link to operations/caching-strategy.md)

### `architecture/05-configuration.md`

- Configuration sources: Info.plist, build settings, env vars, static constants, persisted preferences
- Magic literal inventory from `magic_literals` with the handful that affect UX, pagination, quality labels, or layout breakpoints
- Whether those values are centralized, duplicated, or inconsistent across features and device classes
- Any place a user-visible capability badge or option is hard-coded instead of derived from runtime data

### `architecture/NN-feature.md` (one per major feature area)

Identify feature areas from the top-level directory breakdown + file clustering.
For each, write:
- Responsibility (1 paragraph)
- Key types with file references
- Layer hierarchy for the main screen (use `layer_hierarchies` entries)
- Known risks or open gaps

### `quality/known-issues.md`

A consolidated table of every Code Health finding you produce, grouped by
severity. This file is the index; link each row to the deeper doc where the
finding is discussed.

### `quality/concurrency-audit.md`

Every concurrency smell from `concurrency_smells`, classified as:
- **Benign** (e.g. `Task {}` inside a view modifier that's automatically scoped)
- **Risky** (fire-and-forget with captured refs, unchecked Sendable, nonisolated(unsafe))
- **Critical** (data races, UI updates off main, cancellation bugs)

For each risky or critical entry, write a one-paragraph analysis with the
file path and line number. Include a corresponding finding in the JSON.

### `quality/code-smells.md`

Walk through:
- Force unwraps that aren't in tests / fixtures (from `force_unwraps`)
- Empty catches and silent try? (from `error_handling_smells`)
- Complexity hotspots (from `complexity_hotspots` — top 10)
- Largest files (from `file_inventory.largest_files` — files > 400 LOC)
- TODO / FIXME markers (from `todo_markers`)

### `quality/refactoring-opportunities.md`

Higher-level than code smells. Candidates come from your synthesis:
- Views that should be split
- Viewmodels with too many responsibilities
- Duplicated patterns that should become a shared helper
- Missing abstractions (e.g. no caching layer when network calls are duplicated)

## Finding structure

Each finding in `code_health.json` is an object:

```json
{
  "id": "CH-001",
  "pillar": "code_health",
  "severity": "critical|major|moderate|minor",
  "priority": "must|should|could|wont",
  "title": "Short imperative title",
  "summary": "2-4 sentences: what is wrong, why it matters",
  "recommendation": "Concrete fix in 1-3 sentences",
  "evidence": [
    {"path": "MoviesDo/Features/Player/PlayerEngine.swift", "line_start": 120, "line_end": 142, "snippet": "..."}
  ],
  "rice": {"reach": 8, "impact": 7, "confidence": 0.8, "effort": 2, "score": 22.4},
  "tags": ["concurrency", "player"]
}
```

## Severity rubric (Code Health)

- **critical** — data race, memory leak certain, crash-causing force unwrap in
  a path users hit, concurrency bug with evidence of reproduction
- **major** — force unwrap in a hot path without a fallback, silent catch that
  hides a recoverable error path, a view or viewmodel >1000 LOC doing too
  many things, dead code that confuses readers
- **moderate** — smells that don't ship bugs but slow down future work
  (complexity hotspot, duplication, missing type, inconsistent naming)
- **minor** — style drift, missing doc comments, inconsequential TODOs

## Priority rubric (MoSCoW)

- **must** — ship blocker or certain regression risk; fix before next release
- **should** — next sprint; meaningfully reduces future defect rate
- **could** — nice-to-have; schedule when the area is being touched anyway
- **wont** — intentional debt; record and move on

See `references/priority-model.md` for the full RICE scoring guide.

## Process

1. Read `.audit/raw/code_health.json` fully.
2. Skim the top-20 largest files in source to form a mental model.
3. Use `state_management`, `configuration_provenance`, and `magic_literals` to map where app state and app configuration truly come from.
4. Walk the concurrency + error handling smells in source to classify each.
5. Verify whether repeated user-facing metadata is API-derived or duplicated/hard-coded across screens.
6. Draft the overview + feature docs first (they establish vocabulary).
7. Draft the quality docs last (they reference the feature docs).
8. Produce findings JSON as you go; do NOT wait until the end.
9. Cross-link every finding to the doc section where it is discussed.
10. Do not carry forward stale prose from prior audits. If existing docs disagree with the source, treat that as evidence of documentation drift and note it explicitly.
