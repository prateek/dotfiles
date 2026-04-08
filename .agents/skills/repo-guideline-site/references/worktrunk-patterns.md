# Worktrunk Patterns

Use this as the benchmark for “repo to product-quality guidance site”. The goal is to copy the durable patterns, not the exact styling.

## What Worktrunk Gets Right

### 1. The home page is a proof page

The site does not open with abstract positioning alone. It combines:

- a short promise
- immediate product proof
- a short quickstart path
- obvious next pages

The fastest convincing artifact is near the top. This is the right default for tool sites.

### 2. The structure follows the user journey

The content split is roughly:

- home / overview
- getting started and core loop
- command and config reference
- practical recipes
- integration pages
- FAQ

This is better than mirroring the source tree or dumping commands alphabetically.

### 3. Reference pages are generated where possible

Worktrunk auto-generates command pages from CLI source and keeps the authored work focused on:

- the homepage narrative
- practical recipes
- integration-specific guidance
- FAQ and framing

This is the right pattern for repos with strong machine-readable sources such as CLI help, schemas, or config metadata.

### 4. Demos are part of the system, not one-off assets

The demo pipeline includes:

- versioned VHS tapes
- isolated fixtures and demo repos
- text snapshots for command-output regression checks
- OCR validation for interactive terminal states that snapshots cannot capture

This is a strong model for any site that depends on GIFs, videos, or screenshots.

### 5. The theme is intentional but restrained

The visual system is not generic docs boilerplate. It uses:

- a clear palette and type hierarchy
- a stable shell: sticky top bar, search, left rail navigation, and one main content card
- proof-friendly code and demo styling
- responsive layout decisions documented in-repo
- design tokens and CSS variables instead of scattered one-off fixes

The transferable lesson is not “use warm amber”. It is “pick a coherent visual language and encode it in shared variables.”

### 6. The homepage is visually restrained

The rendered homepage does not try to teach everything above the fold. It uses:

- one large product name
- one supporting claim
- one dominant CTA
- one branded hero visual with motion

Then it moves into proof and quickstart. This is a better default than cramming the landing page with every feature.

## What The Commit History Suggests

The docs evolved toward:

- a standalone custom theme instead of a generic theme dependency
- a simpler hero with clearer proof
- stronger generated-reference workflows
- better demo validation over time

That is useful guidance. High-quality sites usually mature by tightening the landing narrative and making the asset pipeline more deterministic.

## What To Copy

- Home page proof above the fold
- Quickstart plus deeper workflow pages
- Generated reference when source material already exists
- Recipe pages for real operator patterns
- Versioned demo sources and validation
- Explicit docs architecture notes for future maintainers
- A stable visual shell that makes long operational pages feel consistent

## What Not To Cargo-Cult

- The exact color palette
- The exact page names
- CLI-only assumptions for non-technical products
- GIF-heavy storytelling when screenshots or diagrams would communicate better

## Translation Rules

If the target repo is CLI-heavy:

- copy the demo pipeline pattern closely
- use command output as proof
- keep reference pages generated where possible

If the target repo serves non-technical users:

- keep the journey structure
- swap terminal proof for annotated screenshots, walkthrough clips, and empty-state illustrations
- make task verbs more prominent than internal implementation nouns
