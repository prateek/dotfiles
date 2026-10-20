---
status: active
doc_type: plan
summary: "Install every plugin on every harness and retire the unpatched adapters, then split agent-marketplace by origin into src/, vendor/, and build/ with one root manifest."
owner: Prateek
created: 2026-10-20
updated: 2026-10-20
related:
  - ../references/agent-marketplace.md
  - ../adr/0023-apm-agent-marketplace-packaging.md
  - ../adr/0025-shared-apm-acquisition.md
  - ../adr/0049-official-agent-plugin-marketplaces.md
  - agent-skills-repo-split-plan.md
  - ../research/agent-marketplace-adapter-layout-research.md
  - ../../agent-marketplace/README.md
  - ../../.agents/skills/agent-skill-management/SKILL.md
status_detail: "All five deliverables landed on the branch. Open gates: console and Bats lanes not run, live Codex probe, Cursor directory entry (GHOST_OF_COMMITS_PAST.md)."
---

# Agent marketplace layout

## Problem

- **Plugins reach different harnesses by different routes.** Ten of the 17
  local plugins are Codex-only adapters that repackage an upstream plugin which
  Claude installs natively. Every `claude = false` or `codex = false` in the
  policy files is one of these workarounds. No plugin or skill is meant for one
  harness only.
- **The folder mixes what we wrote with what we fetched.** `apm_modules/` holds
  76 MB of vendored code next to `packages/`, which holds our 45 skills
  alongside the patches and selections for upstream code. Root `apm.yml` is
  both the dependency list and the hand-maintained catalog. Most of
  `agent-marketplace/tests/` tests skill helpers, not the build.

## Outcome

**Every plugin reaches every harness.** Claude and Codex install the same set,
and the per-client flags go away. Pi and OMP already take Claude's selection.
Cursor loads whatever Claude has installed and enabled.

**The folder is sorted by origin:**

```text
agent-marketplace/
  marketplace.toml          # catalog, plugin order, versions, selections, manifest overrides
  src/<plugin>/             # we wrote it; only plugins that have files
    skills/<skill>/         #   authored skills, each with its own tests/
    patches/  overlays/     #   edits to selected vendored content
    evals/
  vendor/                   # we fetched it: APM project root, never hand-edited
    apm.yml  apm.lock.yaml  apm_modules/
  build/                    # we built it: ignored, same shape as today
  scripts/  tests/  justfile  pyproject.toml  uv.lock  mise.toml  README.md
```

Anything outside `vendor/` and `build/` was written by hand. The catalog holds
the seven authored plugins (core, design, experimental, ios, review,
utils-agent, utils-human) and five adapters we keep for their patches
(better-writing, crit, mattpocock, obsidian-wiki, pstack).

## Decisions

- **Codex installs upstream Claude catalogs natively.** Codex reads
  `.claude-plugin/marketplace.json` and `.claude-plugin/plugin.json` (verified
  in source at `rust-v0.163.0`; [research](../research/agent-marketplace-adapter-layout-research.md)
  section D). It has never been run live; that check is in
  [`GHOST_OF_COMMITS_PAST.md`](../../GHOST_OF_COMMITS_PAST.md).
- **Cursor needs no plugin config of its own.** The installed cursor-agent
  (2026.07.01) reads both `.cursor-plugin/` and `.claude-plugin/` formats, and
  by default loads every plugin in Claude's `installed_plugins.json` that
  `enabledPlugins` turns on.
- **Each adapter's fate:**

  | Adapter | Our patch | Fate |
  | --- | --- | --- |
  | obsidian, apple-hig, shortcut | none | Retire |
  | ios-tools | adds LICENSE files for our artifact | Retire |
  | ui-ux-pro-max | deletes the Gemini-API icon generator | Retire; accept upstream |
  | better-writing | makes the skill explicit-only | Keep |
  | pstack | makes `setup-pstack` human-only | Keep |
  | mattpocock | `diagnosing-bugs` probe path; `retro` generalisation | Keep for now |
  | crit | daemon-visibility check; edit comments via the HTTP API only | Keep for now |
  | obsidian-wiki | verify loop through the `obsidian` CLI | Keep for now |

  Retired adapters come from upstream on both clients. Kept adapters serve both
  clients, so Claude starts running our patched copies of mattpocock, crit,
  obsidian-wiki, and better-writing.
- **`vendor/`, not `third_party/`.** `vendor/` conventionally means a tool
  fetched the code and nobody edits it. Kept adapters stay in `src/`. A file
  added inside a module directory fails the build's content-hash check, and a
  sibling directory would put hand-written patches under the no-edit name
  (research section A).
- **`src/<plugin>/skills/<skill>/` keeps today's depth.** Six cross-plugin
  relative links and two helpers that climb a fixed number of levels keep
  working unchanged.
- **Keep the name `build/`.** The materializer, release receipt, tree hash,
  and tests all read it by name.
- **Skill tests live inside the skill and ship with it,** as `search`,
  `disk-usage-audit`, and `ios-audit` already do.
- **Two ADRs.** One for deliverable 1 (one plugin set, no per-client flags,
  refining ADR 0049), and one for deliverable 5 (one root manifest, refining
  ADR 0025). The path moves need none.
- **Proceed now.** [The Nix split proposal](agent-skills-repo-split-plan.md)
  doesn't block this. After deliverable 5, its payload directories match
  `src/<plugin>/`.

Out of scope:

- Leaving APM or no longer committing the cache. Every `chezmoi apply` builds
  offline from it.
- Rewriting history to shrink clones.

## Verification

- **Artifact-identity check.** Build the base commit in a separate worktree
  (`build/` is in-tree) and copy its `build/marketplace` to ignored scratch.
  Build again after the change. Run `diff -r` on the two trees, excluding
  `release.json`, and compare the receipts' `files` maps. `source_digest` and
  `revision` will differ.
- **Marketplace check:** `just -f agent-marketplace/justfile -d agent-marketplace check`.
- **Consumer suite:** `just test-python -p test_packages.py -p 'test_console_*.py'`.

Each deliverable updates the docs it affects: the README, the reference, the
`agent-skill-management` skill and its references, the `AGENTS.md` repo map,
and `tests/README.md`.

## Deliverables

### 1. One plugin set for every harness

- Remove the `claude` and `codex` keys from `agent_plugins.toml` and
  `agent_upstream_plugins.toml`, and keep `default_loaded`. The Claude, Codex,
  and Pi config templates, the OMP path, and both reconcilers stop reading
  per-client flags.
- `reconcile-upstream-agent-plugins` accepts `.claude-plugin/marketplace.json`
  in a Codex marketplace snapshot. Today it accepts only
  `.agents/plugins/marketplace.json`.
- Upstream entries:
  - drop mattpocock, crit, obsidian-wiki, and better-writing, which the kept
    adapters now serve on both clients;
  - replace the two superpowers marketplaces with `obra/superpowers`, which
    ships its own Claude catalog.
- Retire the five adapters in the table. Install their upstream replacements
  first, then reconcile the wrappers away. Remove each from `packages/`, the
  catalog, and `agent_plugins.toml`. Remove its root dependencies from
  `apm.yml` once nothing else selects them, then run `just fetch` on a personal
  machine (work-mbp's corp filter blocks some GitHub downloads).
- In `cursor-cli-config-managed.json.tmpl`, check whether the `prateek-local`
  directory entry duplicates what Cursor loads through Claude, or loads
  disabled plugins. Remove the entry if Claude's set is enough.
- Never run a real `apm prune`. A dry run showed it would also register
  plugins in `.github/copilot/settings.local.json`.

This removes about 51 of the cache's 76 MB: `ui-ux-pro-max-skill`,
`apple-hig-skills`, `kepano/obsidian-skills`, `hefgi/skills`,
`AvdLee/SwiftUI-Agent-Skill`, `efremidze/swift-patterns-skill`, and
`conorluddy/ios-simulator-skill`.

*Acceptance:*

- Native inventories show every plugin on both Claude and Codex with its
  expected enabled state. Retired adapters come from upstream; kept adapters
  come from `prateek-local`, with no duplicate upstream install.
- `just test-agent-skill-packages-native` passes on a host with both clients.
- The Claude, Codex, Cursor, and Pi config merge checks pass.
- The consumer suite and the marketplace check pass.
- Skills that name upstream ones still resolve them, for example design naming
  UI/UX Pro Max.
- The skill-listing budget report shows no dropped descriptions.

### 2. Move the catalog into `marketplace.toml`

The build writes its staging catalog manifest from a new root
`marketplace.toml` instead of copying `apm.yml`. Doing this in the current
layout keeps it testable apart from the move.

- `marketplace.toml` holds the catalog's `name` (`prateek-local`), `version`
  (still bumped by hand), `description`, `license`, `owner`, `outputs`, and
  default `category` (`Productivity`).
- It also holds an ordered `plugins` list that keeps today's hand-picked
  order. The build fails if the list and the plugin directories disagree.
- `apm.yml` keeps `devDependencies`. If APM needs `name` and `version` to
  lock, they stay as fixed placeholders that are never bumped.
- If `apm pack` needs the dependency list in staging, the build copies it from
  `apm.yml`.

*Acceptance:*

- The artifact-identity check and the marketplace check pass.
- A `test_marketplace.py` case shows the build failing for an unlisted plugin
  and for a listed plugin with no directory.
- `just fetch` leaves `git status` clean.

### 3. Move to `src/` and `vendor/`

Run `git mv packages src`, move `apm.yml`, `apm.lock.yaml`, and `apm_modules/`
into `vendor/`, and repoint every consumer:

| Area | Change |
| --- | --- |
| Build | `scripts/marketplace.py` iterates `src/` and runs `apm lock`, the cache-mode check, and acquisition cleanliness in `vendor/`. Also update the project `.gitignore` and `.gitattributes`. |
| Skill management | `agent_skill_lib.py` (the `PACKAGES_ROOT` constant and `iter_skill_dirs`). The console: `skill-console`, `inventory.py`, `decisions.py` (edit and patch paths, and the temporary `apm lock` copy), and `skill-console.html`. |
| Other scripts | `scripts/acpx/skill-rewrite.mjs`, `scripts/crit-evals`, and `home/bin/symlink_skill-search.tmpl`. dotpkgs `providers.py`, `actions.py`, and `readiness.py`. |
| Repo root | `justfile` `python_roots`; `.gitattributes`, including the already stale `packages/*/apm_modules/**`; and `.gitleaks.toml`. |
| Tests | `tests/python/agents/`, `tests/python/docs/`, `tests/python/packages/test_dotpkgs.py`, `tests/bats/agents/{acpx-pane,orca-import-login}.bats`, `tests/node/` (including `browser-jev/`), the `agent-marketplace/tests/` fixtures, and `ios-audit`'s `test_run_workflows.py`. |
| Docs | About 110 mentions in 36 `docs/` files, plus `AGENTS.md`, `home/dot_agents/docs/crit.md`, the `chezmoi-management` references, and `docs/validate-doc-lifecycle.py`. |

A rename-only first commit makes review easier. Squash it into the repoint if
the commit hooks reject a tree that doesn't build, and never bypass them.

Locked docs (accepted ADRs 0031, 0036, 0037, 0050, 0051, 0054, and 0055, plus
superseded 0033) may rewrite a link only if Git detects the target as renamed
across the branch. With about 3,400 files moving, keep moved Markdown
byte-identical so the renames are exact.

The chezmoi apply path needs no edits. It hashes the whole project and reads
only `build/marketplace`.

*Acceptance:*

- The artifact-identity check, marketplace check, and consumer suite pass.
- `just test-python -p test_dotpkgs.py -p test_portable.py -p test_locked_docs.py -p test_camofox_runtime.py -p test_orca_fill_stdin.py -p test_skill_rewrite.py`
  passes, as do `just test-shell`, `just test-node`, and
  `just test-browser-jev`.
- `DOCS_LIFECYCLE_BASE=origin/master just test-docs-lifecycle` passes.
- A search for `agent-marketplace/packages` and `agent-marketplace/apm_modules`
  finds nothing outside `docs/retired.md`, the locked docs, and the cache.
- `chezmoi apply --dry-run --verbose --exclude=scripts` shows no unexpected
  changes.
- A console dry-run writes an authored edit and an imported-skill patch to the
  new paths.

### 4. Move skill-helper tests into their skills

| From `agent-marketplace/tests/` | To |
| --- | --- |
| `test_amazon_order_coverage.py` | `src/experimental/skills/amazon-orders/tests/` |
| `test_land_choices.py`, `test_land_git.py` | `src/review/skills/land-changes/tests/` |
| `test_orca_fill_stdin.py` | `src/utils-agent/skills/browser/tests/` |
| `test_search_engine.py` | Delete. It only loads `search/tests/test_engine.py`. |

Both the root `python_roots` and the marketplace `test`/`check` recipes
discover every `agent-marketplace/src/*/skills/*/tests` directory. That
replaces the explicit `ios-audit` entry. The justfile's reason for explicit
roots, vendored suites, no longer applies now that they live in `vendor/`.
`tests/python/agents/test_orca_fill_stdin.py` stays where it is; it covers the
module, not the CLI.

*Acceptance:*

- The root Python lane and the marketplace check pass with the same total
  test count, minus the shim.
- The artifact gains exactly the moved files.
- The affected plugins (experimental, review, and utils-agent) get version
  bumps.

### 5. One root manifest

`marketplace.toml` absorbs every `publish.toml` and
`.codex-plugin/plugin.json`:

- Each plugin becomes a `[plugins.<name>]` table, in catalog order, holding its
  version, selections, `mirror_invocation_controls`, and any manifest
  overrides on top of a shared template.
- The build generates each `plugin.json`.
- `src/<plugin>/` keeps only real files.

The research (section B) has the format sketch and trade-offs. The change
reaches the build's selection, mirror, and manifest code; the console's
selection lookup, deletion guard, version bump, and UI label;
`agent_skill_lib`; the dotpkgs removal guard; and about 15 test fixtures.

*Acceptance:*

- The artifact-identity check passes, with byte-identical generated
  `plugin.json` files and the same catalog order.
- The marketplace check, consumer suite, and `test_dotpkgs.py` pass.
- A console version bump and a selection edit both write to
  `marketplace.toml`.

## Risks

- **Concurrent branches.** Anything touching `agent-marketplace/packages/`
  conflicts with deliverable 3. Land it quickly and rebase the others.
- **Console writes.** The console fingerprints the project before planning and
  again before writing, so a plan made against the old layout fails safely.

## Follow-ups

- Kept patches: Prateek decided on 2026-10-20 to keep the mattpocock, crit,
  and obsidian-wiki adapters and their patches.
- Narrowing `obsidian-wiki` is not possible in APM 0.29.1. Its skills live
  upstream in `.skills/`, and APM rejects a subdirectory dependency whose last
  segment contains a dot (`apm_cli/models/dependency/reference.py`,
  `InvalidVirtualPackageExtensionError`). Per-skill dependencies such as
  `ar9av/obsidian-wiki/.skills/wiki-ingest` would parse, but they would replace
  the whole-collection selection that tracks upstream additions. The full
  dependency stays.
- **Research alternatives to APM.** Prateek wants to move off it. APM 0.31+
  breaks `apm lock` for Agent Plugins 1.0 packages such as pstack
  (microsoft/apm#2806 fails installs that deploy nothing, and lockfile-only
  mode never deploys), and the maintainers declined to deploy that format to
  non-Copilot targets (#2802, closed as not planned). APM is pinned to 0.30.x
  until then; see the README's pin note. Two starting points:
  - the [Nix split proposal](agent-skills-repo-split-plan.md) already weighs
    dropping APM for pinned flake inputs;
  - a small in-repo fetcher, since the build only needs pinned Git checkouts
    plus content hashes. The marketplace already does selection, patching, and
    catalog generation itself. It uses APM to acquire, verify cache hashes and
    pins, scan content, and pack the Claude manifests and catalogs.

## Progress

- 2026-10-20: Plan and research written. Prateek settled every decision above.
- 2026-10-20: Deliverable 1 landed: per-client flags removed, five adapters
  retired, a retired-upstream list added, and ADR 0059 written. Two checks are
  open in `GHOST_OF_COMMITS_PAST.md`: Cursor's `prateek-local` entry was kept
  unverified, and the console tests didn't run.
- 2026-10-20: Deliverable 2 landed (catalog in `marketplace.toml`; artifact
  identical, lock unchanged).
- 2026-10-20: Deliverable 3 landed as one commit; the hooks rejected the
  rename-only commit. The move itself left the artifact identical, but the
  later docs sweep rewrote paths in two shipped files, core's `adoption.md`
  and utils-agent's `skill-search.zsh`, without a version bump. Deliverable 4
  bumps core and utils-agent. The marketplace, consumer,
  dotpkgs, docs, Node, and browser-jev lanes pass. The Bats and console lanes
  didn't run, because `build/test-libraries` couldn't be provisioned.
- 2026-10-20: Deliverable 4 landed. `agent-marketplace/tests/test_skills.py`
  runs every skill's own tests in the marketplace check (151 tests), replacing
  the search shim and the root `ios-audit` entry. It skips three suites
  unittest can't run: image-gen-nano-banana (pytest), skills-searcher (zsh),
  and experiment-scaffold (expects `fastcp` on the host). disk-usage-audit
  and organize-important-documents now run in CI for the first time.
- 2026-10-20: Deliverable 5 landed with ADR 0060. `marketplace.toml` holds
  every plugin's version, manifest, and selections. Eleven generated
  `plugin.json` files are byte-identical; crit's moved `hooks` into the
  canonical key order and was bumped to 1.0.2. The console and skill-rewrite
  version bumps edit the catalog as text. The console's write tests didn't run
  (same `build/test-libraries` block); its catalog edits were exercised
  directly against the real file.
- 2026-10-20: Follow-ups settled: patches kept, obsidian-wiki narrowing ruled
  out by APM's virtual-path rule. The ghost convention moved to its own
  handoff (worktree `ghost-convention`).
- 2026-10-20: Tried APM 0.34.0. Builds were identical, but `apm lock` failed on
  pstack (Agent Plugins format, microsoft/apm#2806). Pinned `apm-cli` to 0.30.0,
  the newest release that still locks: fetch, check, and the artifact are
  unchanged. Researching alternatives to APM is now a follow-up.
