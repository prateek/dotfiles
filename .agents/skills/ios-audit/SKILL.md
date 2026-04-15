---
name: ios-audit
description: "Comprehensive iOS audit for Swift and SwiftUI apps. Runs deterministic collectors for Code Health, UX, Runtime Quality, and Release & Compliance, then synthesizes a complete fresh docs tree plus `audit.html`, `audit.json`, and `audit-diff.md`. Explicitly checks state and config provenance, cross-surface semantic consistency, adaptive device-lane coverage, and storage placement and cleanup policy. Use when the user asks to audit an iOS app, baseline engineering quality, generate architecture or UX docs, replace docs with an audit, find ship blockers, produce a release-readiness report, or diff audits across commits. Requires a Swift or SwiftUI Xcode or Tuist project; for UX, a booted simulator plus `ios-simulator-skill`."
---

# iOS Audit

One end-to-end audit skill for Swift/SwiftUI iOS apps. Runs four pillars (Code Health, UX, Runtime, Release) through four phases (COLLECT → ANALYZE → RENDER → DIFF), producing:

- **`docs/`** — a replacement documentation tree (architecture, UX flows, operations, quality, release) written by analyzers
- **`audit.json`** — a single JSON baseline containing every finding with severity, priority, evidence, and RICE score
- **`audit.html`** — a self-contained HTML report for sharing
- **`audit-diff.md`** — a trend report comparing this run to the previous baseline

Use this skill when the goal is a **complete, reproducible snapshot of an iOS app's engineering state**, not a one-off review. It is the right tool for baselining before a refactor, ship-gate reviews, quarterly health checks, onboarding packages, and catching drift between audits.

## Workflow decision tree

```
User asks to "audit this iOS app" / "generate docs" / "baseline quality"
│
├─ Do you have a booted simulator + a workflow YAML for UX flows?
│  ├─ YES → Run ALL four pillars (full audit)
│  └─ NO  → Run --no-ux (skip UX pillar). You still get Code Health, Runtime, Release.
│
├─ Is this the FIRST audit (no prior audit.json)?
│  ├─ YES → Skip DIFF phase; today's audit.json becomes the baseline.
│  └─ NO  → DIFF phase compares against prior baseline; writes audit-diff.md.
│
└─ Does the user want to replace the existing docs/?
   ├─ YES → --docs-dir docs/
   └─ NO  → --docs-dir .audit/docs-preview/ (renders into a sandbox)
```

The skill's top-level script is `scripts/audit.py`. It has four subcommands — `collect`, `analyze`, `render`, `diff` — plus `all` which runs everything in order.

Fresh-run invariant:

- `collect` treats `--output` as disposable generated state and deletes it before recollecting.
- `analyze` must author a complete current-run docs tree; do not reuse prior audit prose, screenshots, thumbnails, or findings.
- `render` now fails fast if the required authored docs or findings are missing for any pillar that ran.

## The four pillars

| Pillar | What it answers | Raw inputs | Doc outputs |
|---|---|---|---|
| **Code Health** | How is the code organized? Where do state, configuration, and magic constants actually come from? Where are the smells, dead code, concurrency bugs, and undocumented layers? | SwiftLint JSON, Periphery JSON, Tuist graph, file tree, per-screen layer hierarchies, state/config inventories | `docs/architecture/*.md`, `docs/quality/*.md` |
| **UX** | What does the app actually look and feel like at every step? Are repeated capabilities and metadata consistent across surfaces? Was adaptive UI exercised on the right device classes? | Screenshots, accessibility trees, navigation graph, component catalog, semantic-surface signals, workflow/device-lane coverage | `docs/ux/screen-inventory.md`, `docs/ux/flows/*.md`, `docs/ux/component-catalog.md`, `docs/ux/navigation-graph.md`, `docs/ux/consistency-audit.md` |
| **Runtime Quality** | How does it fail, recover, cache, and perform under real conditions? Is data stored in the right bucket with the right cleanup policy? | os_log grep, error-path scan, cache patterns, network resilience grep, storage-policy inventory, Instruments (optional) | `docs/operations/failure-modes.md`, `docs/operations/runbooks/*.md`, `docs/operations/caching-strategy.md`, `docs/operations/resource-usage.md`, `docs/operations/storage-policy.md` |
| **Release & Compliance** | Is this thing shippable? Privacy manifest, Info.plist, localization, signing, App Store risks. | `PrivacyInfo.xcprivacy`, `Info.plist`, `*.lproj/Localizable.strings`, entitlements, signing config | `docs/release/privacy-manifest.md`, `docs/release/localization.md`, `docs/release/app-store-readiness.md` |

See `references/pillars/*.md` for the authoritative description of each pillar's inputs, prompts, and doc outputs.

## Phases

### 1. COLLECT — deterministic, no LLM

`scripts/audit.py collect` runs Python collectors that invoke tools and greps against the repo + (optionally) the simulator. It writes raw JSON under `.audit/raw/`:

```
.audit/raw/
  meta.json              # git rev, timestamp, tool versions, target app
  code_health.json       # swiftlint, periphery, file tree, complexity, state/config provenance
  ux.json                # flow capture results, device-lane coverage, semantic consistency signals
  runtime.json           # os_log usage, catch-blocks, retry/backoff patterns, cache usage, storage policy
  release.json           # privacy manifest presence, Info.plist perms, localization coverage
```

Collectors are under `scripts/collect/`. They are tolerant of missing tools: if `swiftlint` is not on `PATH`, the collector records a `tool_missing` note instead of failing. Re-running `collect` regenerates the entire audit root from scratch.

### 2. ANALYZE — LLM synthesis, pillar by pillar

This phase is performed by **you, the agent invoking this skill**. For each pillar:

1. Read the raw inputs at `.audit/raw/<pillar>.json`.
2. Read the analysis prompt at `scripts/analyze/prompts/<pillar>.md`. It tells you what sections to author, what questions to answer, and what structure the findings must have.
3. Write the markdown docs into `.audit/docs/<section>/*.md` (authored prose, NOT rendered from templates).
4. Write findings into `.audit/findings/<pillar>.json` as a JSON array matching the schema in `audit-schema.json` (the `findings` key). Each finding needs: `id`, `pillar`, `severity`, `priority`, `title`, `summary`, `evidence`, `recommendation`, `rice`, `tags`.
5. Treat every doc named in the pillar prompt as required output for that run. Partial docs are not acceptable; `render` enforces this.

Do not copy forward prior audit prose or screenshots. Every claim in the new docs must be backed by the current raw inputs and current source.

The four prompts are discoverable at:
- `scripts/analyze/prompts/code_health.md`
- `scripts/analyze/prompts/ux.md`
- `scripts/analyze/prompts/runtime.md`
- `scripts/analyze/prompts/release.md`

Read each one before working on that pillar — they contain the rubric, the doc outline, and the priority model.

### 3. RENDER — merge findings and build outputs

`scripts/audit.py render` reads `.audit/docs/` + `.audit/findings/*.json` + `.audit/raw/meta.json` and produces:

- `audit.json` — the merged baseline for this run (see `audit-schema.json`)
- `audit.html` — a self-contained single-file report, built from `scripts/render/templates/audit.html.j2`
- `<docs-dir>/` — the freshly authored markdown is copied into the target docs tree

Render is intentionally strict. If the current audit root is missing required docs, required findings files, or current-run UX flow screenshots, the command errors instead of producing a thin or misleading report.

### 4. DIFF — compare against the previous baseline

`scripts/audit.py diff` reads the new `audit.json` plus the previous baseline (auto-detected from `docs/audit.json` if present, or explicit `--baseline PATH`). It writes `audit-diff.md` showing:

- Findings fixed since baseline (IDs no longer present)
- Findings new since baseline
- Findings regressed (severity increased)
- Findings demoted (severity decreased)
- Net RICE delta

If there is no prior baseline, this phase prints "First audit — no baseline" and exits 0.

## Quick start

```bash
# 1. Make sure prerequisites are installed
brew install uv
brew install swiftlint       # optional, recommended
brew install peripheryapp/periphery/periphery  # optional, recommended
xcrun simctl boot "iPhone 16 Pro"

# 2. Write a workflow YAML for UX flows (see examples/movies-do.yaml)
cp ~/.agents/skills/ios-audit/examples/movies-do.yaml \
   ~/code/my-app/.audit/workflows.yaml
# Edit bundle_id, credentials (use env vars), flows, and `device_matrix`
# when the app adapts across iPhone/iPad or compact/regular layouts.

# 3. Run COLLECT
~/.agents/skills/ios-audit/scripts/audit.py collect \
  --repo ~/code/my-app \
  --workflows ~/code/my-app/.audit/workflows.yaml \
  --output ~/code/my-app/.audit

# 4. ANALYZE — as the invoking agent, read each prompt and write docs + findings
#    (see scripts/analyze/prompts/*.md)

# 5. RENDER
~/.agents/skills/ios-audit/scripts/audit.py render \
  --audit ~/code/my-app/.audit \
  --docs-dir ~/code/my-app/docs

# 6. DIFF (no-op on first run)
~/.agents/skills/ios-audit/scripts/audit.py diff \
  --current ~/code/my-app/.audit/audit.json

# 7. Open the report
open ~/code/my-app/.audit/audit.html
```

Or run everything in one shot:

```bash
~/.agents/skills/ios-audit/scripts/audit.py all \
  --repo ~/code/my-app \
  --workflows ~/code/my-app/.audit/workflows.yaml \
  --docs-dir ~/code/my-app/docs
```

`all` will pause between COLLECT and RENDER so the invoking agent can do the ANALYZE step. The script prints the exact paths to the prompts and raw inputs and waits on STDIN.

The Python entrypoints in this skill are self-contained `uv` scripts with `# /// script`
metadata. Run them directly, or equivalently via `uv run path/to/script.py ...`.

## Credentials and secrets

Workflow YAMLs may reference credentials for test accounts. **Never commit plaintext credentials.** Use env-var interpolation:

```yaml
app:
  credentials:
    username: "${MY_APP_TEST_USERNAME}"
    password: "${MY_APP_TEST_PASSWORD}"

device_matrix:
  - id: iphone_compact
    device: "iPhone 16 Pro"
    traits: [compact, phone]
    default: true
  - id: ipad_regular
    device: "iPad Pro 13-inch (M4)"
    traits: [regular, ipad]
    default: false
```

`scripts/audit.py` expands `${VAR}` references at runtime. If a referenced variable is unset, collect fails with a clear error. For Xcode UI tests, pass credentials through the `TEST_RUNNER_` prefix pattern (Xcode 15.3+): `TEST_RUNNER_MY_APP_TEST_USERNAME="$MY_APP_TEST_USERNAME" xcodebuild test ...`.

## Pillars in detail

See the files under `references/pillars/`:

- `references/pillars/code-health.md`
- `references/pillars/ux.md`
- `references/pillars/runtime.md`
- `references/pillars/release.md`

Each contains:
- What raw inputs the pillar collects
- Which tools are required vs. optional
- The exact doc structure the analyzer should produce
- The severity + priority rubric (MoSCoW + RICE)
- Common findings patterns worth flagging

## Priority model

Every finding has:
- **severity**: `critical` | `major` | `moderate` | `minor`
- **priority**: `must` | `should` | `could` | `wont` (MoSCoW)
- **rice**: `{reach, impact, confidence, effort, score}` where `score = (reach * impact * confidence) / effort`

See `references/priority-model.md` for definitions and scoring guidance.

## Files

```
ios-audit/
  SKILL.md                    # This file
  audit-schema.json           # JSON schema for audit.json and findings/*.json
  workflow-schema.yaml        # YAML schema for UX flow definitions
  scripts/
    audit.py                  # Top-level CLI: collect | analyze | render | diff | all
    common.py                 # Shared helpers (repo detection, env interpolation, JSON I/O)
    collect/
      __init__.py
      code_health.py          # SwiftLint, Periphery, file tree, complexity, layer hierarchies
      ux.py                   # Wraps ../ux/run_workflows.py and captures a11y trees + device coverage
      runtime.py              # os_log, catch, retry/backoff, cache usage + storage policy scans
      release.py              # PrivacyInfo.xcprivacy, Info.plist, localization, signing
    analyze/
      prompts/
        code_health.md        # ANALYZE prompt for Code Health pillar
        ux.md                 # ANALYZE prompt for UX pillar
        runtime.md            # ANALYZE prompt for Runtime pillar
        release.md            # ANALYZE prompt for Release pillar
  render/
      render.py               # Validate completeness, then merge findings + docs → audit.json + audit.html + docs/
      templates/
        audit.html.j2         # Self-contained HTML report template
    diff/
      diff.py                 # Compare current audit.json to baseline → audit-diff.md
    ux/
      run_workflows.py        # Flow executor (ported, now supports workflow device lanes)
      workflow_matrix.py      # Device-lane normalization + coverage summaries
      generate_report.py      # HTML flow report (ported)
      review_screenshots.py   # LLM review manifest builder (ported)
  references/
    pillars/
      code-health.md
      ux.md
      runtime.md
      release.md
    priority-model.md         # MoSCoW + RICE definitions
    authoring-workflows.md    # How to write flow YAMLs
    migration-from-ios-flow-audit.md
  assets/
    styles/audit.css          # Stylesheet for audit.html
  examples/
    movies-do.yaml            # Streaming app flows
    silly-tavern.yaml         # Chat app flows
  agents/
    openai.yaml               # UI metadata
```

## Tips

- **Run COLLECT behind a Makefile target** (`make audit`) so the command invocation is stable across runs.
- **Keep `.audit/` out of git** except for `.audit/audit.json` if you want a checked-in baseline. Add `.audit/raw/` and `.audit/docs/` to `.gitignore`.
- **Use `device_matrix` in the workflow YAML** when the app has compact/regular or iPhone/iPad branches. If adaptive layout signals exist and only one lane runs, the UX pillar should raise a coverage finding.
- **Use separate `--output` directories per lane** (compact vs standard, light vs dark) if you run multiple audit variants.
- **Do not preserve prior audit docs or assets.** If you need to keep non-audit notes, store them outside the audit target tree.
- **Diff every audit** once you have a baseline. Regressions are the highest-signal output of this skill.
- **Fail loud on missing tools** the first time, then decide if the missing tool is worth installing. Do not silently skip collectors — the doc outputs become inconsistent across runs.
