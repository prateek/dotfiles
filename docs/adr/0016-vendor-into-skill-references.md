---
status: proposed
doc_type: adr
created: 2026-08-28
updated: 2026-08-30
owner: Prateek
related:
  - ../plans/acpx-claude-streaming-poc-plan.md
  - 0013-apm-vendored-tool-integrations.md
status_detail: "Sketch for review before implementation; acpx is the first customer. On 2026-09-03 core/skills/local/writing-for-humans consolidated three writing skills by copying two upstream bodies into its references by hand; it converts to the vendor mapping when this lands."
---

# ADR 0016 — Vendored dependency content may land inside a local skill

## Context

Packages vendor whole upstream skills into `skills/vendor/<id>/`, and every
skill directory in a rendered package becomes a listed skill. For acpx this
produces two artifacts with one subject: the vendored upstream skill owns
the trigger but knows nothing about local conventions (model shortcuts,
safety flags, the watching-a-run patterns), while the conventions live in
`~/.agents/docs/acpx.md` behind an AGENTS.md pointer that only helps agents
who follow it. Invoking the skill loads the upstream command surface and
none of the conventions — observed directly in the acpx streaming PoC
session ([plan](../plans/acpx-claude-streaming-poc-plan.md)).

The desired end state is one trigger-owning local skill whose body is the
conventions, with the upstream command surface as progressive-disclosure
reference material that refreshes mechanically. Skill-trigger arbitration
between overlapping listings is undocumented in Claude Code, so the design
removes the second listing outright rather than betting on arbitration.
Ways to approximate this inside today's contract fall short — see Options
considered.

## Decision

`package.toml` gains an optional per-skill vendor destination:

```toml
[vendor.acpx]
dest = "skills/local/acpx/references/upstream"
```

Semantics:

- The table key is the deployed skill id (the staged skill's directory
  name) — the same key `vendor-agent-package` already uses for lock
  metadata. A dependency that deploys several skills maps each one
  separately; its unmapped skills land in `skills/vendor/` as usual. A
  mapping key that matches no deployed skill fails validation, so a typo
  (or a mapping retained after its dependency is removed) dies loudly
  instead of silently stranding content.
- `vendor-agent-package` copies the accepted staged tree to `dest` instead
  of `skills/vendor/<skill-id>/`, byte-intact — no renames, no frontmatter
  edits, no injected headers. Provenance lives solely in `SOURCE.md`,
  matching the ecosystem norm of intact redistribution with sidecar
  metadata.
- A nested or root `SKILL.md` inside `dest` is inert: plugin skill
  discovery is flat (`skills/<name>/SKILL.md` only, per the plugins
  reference), and trycycle's nested copies already render today without
  registering. Implementation verifies Codex and pi discovery are also
  flat before relying on this; if any consumer ever recurses, the
  fallback is a rename step for the offending files — a transform this
  decision otherwise deliberately avoids.
- The script owns `dest` exactly: it deletes and recreates that directory
  on every refresh, preserving the reviewed sidecar set (`SOURCE.md`'s
  `License`/`Notes` fields and any review-time license file) across the
  cycle. A dest-root license file absent from the staged tree is that
  reviewed sidecar; if upstream later ships its own license file, the
  staged copy replaces it. `dest` must be a direct child of a
  `skills/local/<skill>/references/` directory in the same package —
  never `references/` itself — and hand-authored reference files live
  outside mapped destinations.
- `SOURCE.md` is written in `dest` with the same fields and refresh
  behavior as today. Introducing a mapping for a skill that currently
  lives under `skills/vendor/<id>/` migrates its reviewed fields rather
  than regenerating TODO defaults. A staged tree that ships its own root
  `SOURCE.md` fails validation rather than colliding with the pipeline's.
- Every `SOURCE.md`-marked tree must carry its upstream license status:
  license text copied when the staged tree ships it, added at review time
  when upstream declares a license without shipping the file, or a
  reviewed `License` field recording the declared absence when upstream
  has none — several vendored upstreams declare no license, so a
  text-only rule would be unsatisfiable. This repo is public; MIT-style
  licenses require the notice to travel with copies. The validator
  enforces the invariant uniformly — mapped destinations and
  `skills/vendor/` alike — and the implementing change's backfill stays
  mechanical: copy license files where upstream ships them, record
  status for the rest. Any keep-versus-remove policy for unlicensed
  upstreams is out of scope here.
- Refresh removes every direct child of a local skill's `references/`
  that carries a pipeline-written `SOURCE.md` at its root and is not the
  destination of a current mapping with a matching deployed skill —
  mirroring today's stale-child cleanup of `skills/vendor/`. Deeper
  `SOURCE.md` files inside a destination are upstream content, never
  cleanup markers.
- Skills without a mapping land in `skills/vendor/` as before; the
  default is unchanged.

`validate-agent-packages` enforces the destination rule above, fails
duplicate destinations across mappings, and accepts `SOURCE.md` (plus the
license requirement) at mapped destinations. All mapping rules also run
as a preflight inside `vendor-agent-package` before any destination is
deleted or the lockfile written: a bad mapping must fail before it can
destroy content or record state.

First customer, acpx:

- `utils-agent/skills/local/acpx/`: `SKILL.md` is the conventions (from
  `home/dot_agents/docs/acpx.md`), with a trigger description covering
  both conventions and command-surface phrasing since the upstream
  listing disappears — sized against the description budget and checked
  with `audit-skill-context` after render.
- Upstream content at `skills/local/acpx/references/upstream/`;
  `skills/vendor/acpx/` is removed. The local `SKILL.md` links to
  `references/upstream/SKILL.md` wherever it hands off to the command
  surface.
- `home/dot_agents/docs/acpx.md` is deleted. The machine AGENTS.md pointer
  changes to the rendered path
  `~/.agents/plugins/plugins/utils-agent/skills/acpx/SKILL.md`, and the
  migration greps the repo for `docs/acpx.md` and updates every live hit
  (mise config comments and the vendored `SOURCE.md` Notes point at the
  doc today). Closed historical docs also match (the retired
  crit-agent-bridge plan); their bodies stay untouched per the docs
  lifecycle rules.
- The conversion rewrites the doc's self-references — "this doc", the
  sibling-skill pointer, repo-relative source paths — for the skill body,
  alongside authoring the trigger description.
- The implementing change teaches the renderer to stamp a content-derived
  plugin version, so installed Claude and Codex caches pick up relocated
  content on their normal update path (pi reads the rendered marketplace
  directly). Until that lands, the migration runs the
  `reconcile-agent-plugins` flow by hand.
- The implementing change also keys `inventory-agent-skills` provenance
  on `SOURCE.md` instead of the path prefix, so the acpx skill does not
  report as wholly local.

## Options considered

- **Local delta pointer (rejected):** edit the vendored SKILL.md to point
  at the conventions doc. One line re-applied by hand after every apm
  refresh, forever — deltas are for small divergence awaiting
  upstreaming, not a permanent structural pointer — and the conventions
  stay out of the listing and trigger.
- **Per-skill render exclusion (rejected):** an excluded skill's files
  never enter the rendered plugin, so the local skill would have nothing
  self-contained to reference at runtime.
- **Build-time merge of upstream into SKILL.md (rejected):** the whole
  payload loads on every trigger, and review diffs blur local versus
  upstream authorship.
- **Curated excerpts (rejected):** an unpinned latest-tracking dependency
  plus hand-curation rots invisibly; the whole-tree-plus-SOURCE.md design
  exists to prevent exactly this.
- **apm-native extension points (rejected):** apm offers per-dependency
  `skills:` subsets, `alias:` renames, and post-install lifecycle
  scripts, but no reviewed embed-as-reference transform (`alias:` is
  additionally suspect: the apm 0.28 upgrade at this branch's merge base
  found `apm update` honors aliases while `install` ignores them, and
  dropped the repo's only aliased dependency over it). A post-install
  script could perform the copy, yet it would run outside the vendor
  pipeline's review gate and validation; the mapping stays in
  `package.toml`, where the pipeline that owns review also owns the
  transform.

## Consequences

- Zero recurring deltas for the acpx pointer problem; refresh stays
  `apm update` plus `vendor-agent-package` with no manual re-apply step
  for content. The chezmoi attribute-prefix rename (upstream filenames
  like `run_*` need a `literal_` prefix) remains a recurring manual step
  wherever it occurs, mapped or not.
- One listing and one trigger surface, authored locally, with progressive
  disclosure. The benefit is trigger-time only — the command-surface
  handoff still loads the full upstream body (~27 KB for acpx) in one
  read. The merged description risks the listing budget, where overflow
  silently drops descriptions and kills auto-triggering.
- Plugin cache refresh is version-keyed and the renderer stamps a static
  `"version": "1.0.0"` today, so any same-version content change ships
  stale to installed caches (see the reconcile reference's short-circuit
  note). The Decision's content-derived stamp retires that hazard for
  every future refresh, not just this migration.
- Mapped paths fall outside apm's per-file hash and deployment ledger, so
  apm-native audit tooling cannot trace them. Byte-intact copies keep the
  divergence to a relocation; acceptable while that tooling is unused
  here.
- The pattern is reusable where a package wants upstream content as
  reference material inside a local skill (crit and orca-cli are
  plausible next customers).
- Vendored source no longer lives only under `skills/vendor/`;
  `SOURCE.md` becomes the marker of a vendored subtree wherever it lands.
  Tooling and reviewers must key on `SOURCE.md`, not the path prefix.
- The AGENTS.md pointer targets generated plugin output. The path does
  not exist before the first `chezmoi apply`, and also goes missing when
  the plugin render script fails (it hard-exits without `uv`) or when an
  operator applies with `--exclude=scripts` — cases where the deleted doc
  previously materialized unconditionally in the file phase. Accepted:
  every other rendered skill already has this property.
- Post-migration the helper (chezmoi-delivered) and the skill text
  (plugin-cache-delivered) ship on different latencies. The helper's
  header remains the authoritative contract; the skill body defers to it
  rather than restating exit codes and defaults.
- The packaging contract docs — the agent-skill-management `SKILL.md` and
  its `references/` (package layout, third-party imports) — currently
  require all remote content under `skills/vendor/`. The implementing
  change must update them together with the scripts; until it lands,
  this ADR, not those docs, is authoritative for mapped destinations.
- `vendor-agent-package`, `validate-agent-packages`, and the renderer
  version stamp grow modestly (tens of lines each).

## Validation

- Fixtures for the mapping in `make test-agent-skill-packages`, and all
  four suites per the agent-skill-management rule (`test-claude-settings`,
  `test-codex-config`, `test-pi-settings` alongside it).
- `render-agent-plugin-marketplace --check` against temp roots.
- A live utils-agent re-vendor demonstrating a delta-free refresh with the
  mapping in place.
- A live cache-propagation check: after a content-only change, the
  installed Claude plugin cache picks up the new bytes without an
  uninstall. This guards against version schemes the cache comparator
  ignores (for example semver build metadata), which would pass every
  render check while still shipping stale caches.
