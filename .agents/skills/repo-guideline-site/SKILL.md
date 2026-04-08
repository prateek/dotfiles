---
name: repo-guideline-site
description: Generate or redesign a polished workflow/guidelines website from a repository, especially for CLI tools, operator workflows, and mixed technical audiences. Use when the goal is not generic API docs but a high-quality “how to use this” site with audience-aware onboarding, proof-oriented demos, a deliberate visual direction, task pages, recorded UI review gates, and an evaluation plan.
---

# Repo Guideline Site

Build websites that teach people how to use a tool, not just what commands or APIs exist. The output should feel like a product-quality adoption site: clear landing narrative, fast first success, task-oriented pages, proof artifacts, and a validation plan.

## When To Use It

Use this skill when the user wants any of the following:

- A docs site, workflow site, tutorial site, or “make this repo feel like worktrunk.dev”
- A site for a CLI, plugin, workflow tool, internal operator tool, or mixed technical audience
- A site for a non-technical product that still needs guided tasks, screenshots, and proof of how it works
- A redesign of an existing docs site whose current structure is too reference-heavy or generic

Do not use this skill for pure API reference generation with no workflow teaching component.

## Workflow

### 1. Inventory The Repository

Run `scripts/repo_site_inventory.py <repo-path>` first. Use that output as the fast evidence layer before reading many files by hand.

Then inspect the highest-signal sources:

- Root README and install instructions
- Existing docs pages or `docs/`, `website/`, `examples/`, `demo/`, `fixtures/`
- CLI help surfaces, config schemas, screenshots, GIFs, videos, and test fixtures
- Release notes or changelog entries that reveal what users actually care about

If the user gave a reference site, inspect that rendered site as well and capture the transferable patterns rather than copying the exact visual treatment.

### 2. Classify Product, Audiences, And Proof

Infer these before writing pages:

- Product type: `cli`, `developer-tool`, `library-with-guided-workflows`, `operator-console`, `end-user-app`, or mixed
- Primary surfaces: terminal, config files, browser UI, mobile UI, APIs, or generated artifacts
- Primary audiences: new evaluator, daily operator, admin, integrator, contributor, non-technical end user
- Proof artifacts: the fastest convincing demo, the best screenshot, the best “before/after”, or the most legible task flow

Always write down the audience split explicitly. Good websites teach different people different entry paths.

### 3. Create The Plan Bundle Before Building

Before implementing or rewriting the site, create a stable plan bundle in the target repo, usually `.codex/site-plan/` or `docs/site-plan/`.

Required files:

- `site-manifest.json`
- `audiences.md`
- `page-inventory.md`
- `media-plan.md`
- `build-test-plan.md`

The schema and field expectations are in `references/output-contract.md`.

Use `scripts/evaluate_site_manifest.py --manifest <path> --case <case.json>` whenever you have a relevant fixture or benchmark case.

### 4. Choose A Deliberate Visual Direction

Do not jump straight from repo inventory to generic docs theming.

Before building, decide and record:

- Purpose and audience tone: operator-console, editorial product brief, maker manual, polished enterprise workflow, playful household guide, and so on
- Memorable hook: the one visual idea or composition choice someone will remember
- Typography system: distinctive display/body pairing that fits the product instead of defaulting to generic stacks
- Color and atmosphere: restrained or bold, but intentional
- Composition: card-heavy shell, editorial sections, asymmetry, proof panels, diagrams, or denser operator layout
- Motion strategy: where motion teaches state or creates delight, and how reduced-motion fallback works
- Anti-patterns to avoid for this site

If the remote benchmark or local environment gives you a frontend design skill, use it as inspiration for the design direction. For this skill, the portable version lives in `references/visual-direction.md`.

Record the result in the plan bundle with either `visual-direction.md` or the optional `visual_direction` block in `site-manifest.json`.

### 5. Design The Information Architecture

Every site should have a strong opinionated structure. Default to these page types:

- Home / overview:
  explain the promise, show proof above the fold, give a short quickstart, map the major workflows, and point to the next pages
- Getting started:
  one path to first success with prerequisites, install, setup, and the first meaningful outcome
- Core workflow pages:
  2-5 task pages that reflect how users actually use the tool day to day
- Advanced patterns / integrations:
  scaling, automation, plugins, team workflows, or power-user recipes
- Reference:
  command, config, schema, or API material; auto-generate when practical
- FAQ / troubleshooting:
  objections, failure modes, environment differences, and recovery paths

Keep narrative pages and exhaustive reference separate. Narrative pages should teach judgment and flow; reference pages should answer exact lookups.

### 6. Pick The Right Site Stack

Prefer the repo’s existing docs stack if it is already viable. Otherwise:

- Use a static site generator with strong content ergonomics for most cases
- Favor `Astro` or MDX-heavy stacks when the site needs rich media layouts and componentized callouts
- Favor `Zola` or similarly lean static stacks for small, fast CLI or Rust/Go sites
- Favor the project’s established stack over your personal preference if it is already in use

Do not switch stacks casually when the repo already has a good docs pipeline.

### 7. Plan Media As Testable Artifacts

Media is part of the product proof, not decoration.

For CLI-heavy products:

- Prefer deterministic terminal captures using VHS or an equivalent scripted recorder
- Keep tapes under version control
- Reuse fixtures to keep output stable
- Validate command-output demos with text snapshots where possible
- Validate interactive or TUI demos with OCR checkpoints or frame checks when text snapshots are insufficient

For browser or end-user products:

- Prefer scripted screenshots or short recordings using browser automation
- Capture desktop and mobile states for onboarding-critical pages
- Favor annotated stills over long videos when a still explains the state better
- Verify rendered output after layout changes, not just the HTML or markdown source

For hybrid tools, mix both.

See `references/media-playbook.md`.

### 8. Run A Rendered UI Review Lane

Once there is a real build and real proof media, review the rendered site instead of trusting the source alone.

If the local skill exists at `/Users/prateek/.agents/skills/ui-ux-pro-max/SKILL.md`, use it as the primary review rubric. For this skill, only apply the relevant parts for guideline sites:

- Accessibility and heading hierarchy
- Touch target size and non-hover interaction states
- Responsive layout and navigation behavior
- Motion, reduced-motion handling, and GIF/video fallbacks
- Media performance details such as declared dimensions and layout stability

Do not make that external skill a hard dependency. If it is unavailable, use `references/ui-review-checklist.md`, which carries the portable subset this skill actually needs.

Record the outcome in the site plan:

- Add explicit rendered-site review items to `quality_gates`
- Add an optional `ux_review` object to `site-manifest.json` when the audit findings or fixes are worth preserving

### 9. Adapt The Writing To The Audience

For technical audiences:

- Lead with workflow value, not architecture
- Keep examples copy-pasteable
- Show expected output, not only commands
- Put advanced knobs on separate pages instead of stuffing them into the quickstart

For non-technical audiences:

- Prefer task language over system nouns
- Add a glossary when repo terminology is specialized
- Show screenshots of empty, partial, and successful states
- Add account, privacy, permissions, and recovery guidance when relevant
- Use shorter paragraphs and more explicit “what happens next” framing

### 10. Validate Before You Stop

Minimum quality bar:

- Site build passes
- Links and obvious nav flows work
- The plan bundle passes the manifest evaluator at an acceptable score
- At least one proof artifact exists for the homepage
- Each P0 workflow has a page and at least one supporting artifact
- Visual changes are verified on the rendered site, not only in source
- A rendered UI review has been recorded for focus/keyboard behavior, responsive layout, and motion/media fallback behavior
- A visual direction has been recorded explicitly enough that another reviewer could tell whether the site drifted into generic docs design

If you have a benchmark case or a relevant fixture, run the evaluator against it. If you do not, still score the manifest and report the weak dimensions.

## Benchmark Patterns

The main benchmark for this skill is distilled in `references/worktrunk-patterns.md`.

The important transferable ideas are:

- A concise landing claim paired with immediate proof
- Narrative pages for workflows and generated pages for reference
- A deliberate media pipeline with validation, not ad hoc screen capture
- A docs structure that reflects the user journey rather than the code layout

Copy the principles, not the exact palette or layout.

## Scripts

- `scripts/repo_site_inventory.py`:
  repo evidence scanner and product-surface classifier
- `scripts/evaluate_site_manifest.py`:
  scores a plan bundle and optionally compares it to fixture expectations

## References

- `references/worktrunk-patterns.md`
- `references/visual-direction.md`
- `references/media-playbook.md`
- `references/output-contract.md`
- `references/eval-rubric.md`
- `references/ui-review-checklist.md`
