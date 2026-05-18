---
status: archived
doc_type: plan
created: 2026-05-10
updated: 2026-05-15
closed: 2026-05-15
current_guidance:
  - ../../.agents/skills/agent-skill-management/SKILL.md
  - ../adr/0007-default-loaded-plugin-policy.md
related:
  - ../research/agent-skill-management-research.md
  - ../adr/0007-default-loaded-plugin-policy.md
status_detail: "Historical implementation plan. Current package layout and plugin operations live in the agent-skill-management skill; default-loaded policy lives in ADR 0007."
---

# Chezmoi Agent Skills Plan

## Goal

Make dotfiles the source of truth for Prateek's shared agent skills and skill
packages.

The steady state is:

- APM packages under `home/dot_agents/packages/` own local and vendored skill
  source.
- `run_onchange_after_35-agent-core-skills.sh.tmpl` renders root skills from
  package source straight into `~/.agents/skills` and `~/.claude/skills`.
- `run_onchange_after_36-agent-plugins.sh.tmpl` renders the shared local plugin
  marketplace straight into `~/.agents/plugins`.
- Codex and Claude Code config files express marketplace registration and
  rendered plugin activation.
- Tool-owned plugin caches stay outside chezmoi.

This keeps always-on skill metadata small while letting non-core skills be
installed and enabled as plugin packages, or omitted with
`render.<agent> = "none"`.

## Current Problem

Codex warns when available skill descriptions exceed the startup context budget:

```text
Skill descriptions were shortened to fit the 2% skills context budget. Codex can still see every skill, but some descriptions are shorter. Disable unused skills or plugins to leave more room for the rest.
```

The repo already centralizes machine-wide agent guidance under
`home/dot_agents/`. Today too many skills compete for always-on discovery. The
fix is to keep a small core set in root discovery and move the rest into
toggleable plugins.

## Non-Goals

Here, "initial implementation" means Phases 1-5 below.

- Do not let APM write directly into live `~/.agents`, `~/.codex`, or
  `~/.claude` paths.
- Do not hand-edit `~/.claude/plugins/installed_plugins.json`,
  `~/.claude/plugins/cache/`, or `~/.codex/plugins/cache/`.
- Do not manage remote public plugin publishing in this plan.
- Do not package APM prompts, hooks, agents, scripts, MCP servers, LSP servers,
  monitors, themes, or app integrations in the first implementation. Package
  skills first. Add other plugin components only after their install paths and
  validation are explicit.
- Do not make Graph of Skills part of bootstrap in this change.

## Ownership Model

Keep human-edited package source separate from generated install surfaces:

- `home/dot_agents/packages/<package>/package.toml`: human-edited package
  desired state. The package id is the directory name; the file records display
  name and per-agent render surface.
- `home/dot_agents/packages/<package>/apm.yml`: human-edited APM package
  manifest for that package.
- `home/dot_agents/packages/<package>/apm.lock.yaml`: optional committed APM
  resolver record, present only when the package has APM dependencies.
- `home/dot_agents/packages/<package>/skills/local/`: repo-owned skill source
  for the package.
- `home/dot_agents/packages/<package>/skills/vendor/`: reviewed vendored remote
  skill source for the package.
- `home/.chezmoiscripts/run_onchange_after_35-agent-core-skills.sh.tmpl`:
  apply-time renderer for `~/.agents/skills` and `~/.claude/skills`.
- `home/.chezmoiscripts/run_onchange_after_36-agent-plugins.sh.tmpl`:
  apply-time renderer for `~/.agents/plugins`.
- `home/dot_codex/symlink_skills`: Codex compatibility symlink from
  `~/.codex/skills` to `~/.agents/skills`.
- `home/.chezmoitemplates/agent-codex-plugin-config.toml.tmpl`: generated
  Codex plugin config fragment derived from package render policy.
- `home/.chezmoitemplates/agent-claude-plugin-settings.json.tmpl`: generated
  Claude Code plugin settings fragment derived from package render policy.
- `home/dot_codex/modify_private_config.toml.tmpl`: managed Codex config merge
  for marketplace registration and rendered plugin activation.
- `home/dot_claude/modify_private_settings.json.tmpl`: managed Claude Code
  settings merge for marketplace registration and rendered plugin activation.
- `.agents/skills/agent-skill-management/`: repo-local management skill for
  editing, validating, and regenerating this workflow. It is not machine-wide
  package content.

Steady-state layout:

```text
.agents/skills/agent-skill-management/
  SKILL.md
  references/
    generated-outputs.md
    package-layout.md
    plugin-reconcile.md
    third-party-imports.md
  scripts/
    inventory-agent-skills
    validate-agent-packages
    render-agent-core-skills
    render-agent-plugin-marketplace
    reconcile-agent-plugins
    vendor-agent-package
    audit-apm-source-surface
    audit-skill-context
home/dot_agents/
  packages/
    core/
      package.toml
      apm.yml
      apm.lock.yaml            # absent until APM dependencies exist
      skills/
        local/
          code-gardening/
        vendor/
          third-party-core-skill/
            SOURCE.md
    review/
      package.toml
      apm.yml
      apm.lock.yaml            # absent until APM dependencies exist
      skills/
        local/
        vendor/
    ios/
      package.toml
      apm.yml
      apm.lock.yaml            # absent until APM dependencies exist
      skills/
        local/
        vendor/
home/.chezmoitemplates/
  agent-codex-plugin-config.toml.tmpl      # generated
  agent-claude-plugin-settings.json.tmpl   # generated
home/.chezmoiscripts/
  run_onchange_after_35-agent-core-skills.sh.tmpl
  run_onchange_after_36-agent-plugins.sh.tmpl
home/dot_codex/
  symlink_skills                 # ~/.codex/skills -> ~/.agents/skills
  modify_private_config.toml.tmpl
home/dot_claude/
  modify_private_settings.json.tmpl
```

Live generated targets:

```text
~/.agents/skills/
~/.claude/skills/
~/.agents/plugins/
  marketplace.json            # Codex catalog
  .claude-plugin/
    marketplace.json          # Claude Code catalog
  plugins/
    review/
      .codex-plugin/
        plugin.json
      .claude-plugin/
        plugin.json
      skills/
    ios/
      .codex-plugin/
        plugin.json
      .claude-plugin/
        plugin.json
      skills/
```

Do not put skill or plugin source under `home/.chezmoidata/`. Chezmoi data files
are for structured template input, not mixed package trees containing
`SKILL.md`, scripts, vendored files, lockfiles, and source metadata.

If Go templates need a compact package index, add or generate a structured data
file such as `home/.chezmoidata/agent-packages.toml` from
`home/dot_agents/packages/*/package.toml`. Keep the authoritative source trees
under `home/dot_agents/packages/`.

Generated source fragments should be obvious to GitHub:

- add repo `.gitattributes` entries marking generated config templates as
  `linguist-generated=true`:

  ```gitattributes
  home/.chezmoitemplates/agent-codex-plugin-config.toml.tmpl linguist-generated=true
  home/.chezmoitemplates/agent-claude-plugin-settings.json.tmpl linguist-generated=true
  ```

- ignore `home/dot_agents/skills/`, `home/dot_claude/skills/`, and
  `home/dot_agents/plugins/` so accidental source-tree generation stays out of
  git;
- write a `README.generated.md` marker into each live generated root that names
  the generator and points back to `home/dot_agents/packages/`; per-package
  generated plugin subtrees should also name their source package;
- check generated-output drift by rendering to explicit temp roots and running
  the renderer `--check` modes against those roots;
- do not use generated-root `AGENTS.md` files as markers, because they would
  change the instruction scope for agents reading those directories.

## Package Manifest

There is no global package manifest. The renderer walks
`home/dot_agents/packages/*/package.toml` and treats each package directory as
the unit of ownership. This avoids a separate control plane while still keeping
agent render policy next to the package it controls.

Each package's `package.toml` should avoid duplicating details already present
in that package's APM manifest.

The package id is the package directory name. Do not repeat it inside
`package.toml`.

Example:

```toml
# home/dot_agents/packages/core/package.toml
display_name = "Core Agent Skills"

[render]
codex = "root"
claude = "root"
```

```toml
# home/dot_agents/packages/review/package.toml
display_name = "Review"

[render]
codex = "plugin"
claude = "plugin"
```

```toml
# home/dot_agents/packages/ios/package.toml
display_name = "iOS"

[render]
codex = "none"
claude = "plugin"
```

Allowed `render.<agent>` values:

- `root`: generate the agent's default/root materialized surface.
- `plugin`: generate plugin source, marketplace entries, and enabled plugin
  config for that agent.
- `none`: do not generate this package for that agent.

`root` means the agent's always-on discovery/config surface, not the package
directory root. In the first implementation, root rendering emits supported
skill trees into live `~/.agents/skills` or `~/.claude/skills` during
`chezmoi apply`. Future non-skill APM components need explicit render rules
before root rendering emits them.

The initial implementation only requires `root`, `plugin`, and `none`.

Missing `render.<agent>` keys default to `none` for non-core packages. That
makes new packages visible for review without adding them to an agent's active
surface. In the first implementation, use `root` only in the `core` package.

There is no installed-but-disabled state in the first implementation:
`render.<agent> = "plugin"` means enabled, and `render.<agent> = "none"` means
omitted.

## Core Skills

The `core` package is the always-on baseline.

Rules:

- `~/.agents/skills` is rendered at apply time from packages whose
  `package.toml` has `render.codex = "root"`.
- `~/.claude/skills` is rendered at apply time from packages whose
  `package.toml` has `render.claude = "root"`.
- Core skills should be few, short, and broadly useful.
- The first implementation does not generate or enable a `core` plugin.
- The generator fails if a directly rendered skill also appears in an enabled
  plugin for the same agent discovery surface.

This keeps the root startup list small. Add a `core` plugin later only if root
projections are not enough.

## Existing Skills Cutover

`home/dot_agents/skills/` used to contain hand-maintained skill source. The
cutover must keep every retained top-level skill under package source before
any live root is generated.

Cutover rules:

- Phase 2 moves every current top-level `home/dot_agents/skills/<skill-id>/`
  source root into `home/dot_agents/packages/<package>/skills/local/` or
  `home/dot_agents/packages/<package>/skills/vendor/`.
- Skills rejected during classification are removed or archived only as
  reviewable repo diffs.
- Non-core skills must exist under their package source before the apply-time
  core projection replaces live `~/.agents/skills` or `~/.claude/skills`.
- `home/dot_agents/skills/` and `home/dot_claude/skills/` stay absent from git
  after package-source cutover.

Live runtime preflight:

- Before Phase 3 or any `chezmoi apply` that can touch generated skill
  projections, inventory `~/.agents/skills`, `~/.claude/skills`,
  `~/.codex/skills`, and their symlink targets.
- Compare every live `SKILL.md` with the package source tree. A live-only skill
  must be adopted into a package, archived outside active discovery, or
  explicitly quarantined in a reviewable note before projection materialization.
- Report compatibility symlinks that point at old worktrees. Replace them only
  through the generated projection or a deliberate compatibility link update.
- `render-agent-core-skills --check-live` fails while live-only skills or stale
  compatibility symlinks remain unresolved.

## Generated Plugin Marketplace

`~/.agents/plugins` is apply-time generated output. It is the shared source root
for local plugin catalogs and plugin directories. Do not commit
`home/dot_agents/plugins/`.

Rules:

- Generate one plugin directory per package that has
  `render.<agent> = "plugin"` for at least one agent.
- Generate both manifests in each plugin directory:
  - `.codex-plugin/plugin.json`
  - `.claude-plugin/plugin.json`
- Copy generated skill trees under the plugin root's `skills/` directory, using
  one `skills/<skill-id>/SKILL.md` tree per exposed skill.
- Generate `~/.agents/plugins/marketplace.json` for Codex.
- Generate `~/.agents/plugins/.claude-plugin/marketplace.json` for Claude Code.
- Keep marketplace plugin paths relative to the marketplace root and inside that
  root.
- Do not edit generated plugin directories by hand. Change the package source or
  the package's `package.toml`, then regenerate.

Codex and Claude Code do not share one manifest schema. They can share one
plugin source tree because that tree carries both manifest directories.

Plugin skill trees are copied into the generated marketplace, not symlinked to
package source. Claude Code skips or dereferences symlinks depending on where
they resolve when it copies a plugin into its cache, and Codex also installs
from its own cache. Copies make the generated plugin root self-contained and
easy to validate.

`~/.agents/plugins` is a local marketplace source root. Codex and Claude
Code may install or cache plugin copies under their own plugin directories after
reading that marketplace. The generated source root does not try to be the
installed cache layout.

## Agent Config

Agent-specific config owns marketplace registration and rendered plugin
activation. It does not own plugin source.

Per-package `package.toml` files are the source of truth for each package's
`render.<agent>` surface. Config files are generated projections of that desired
state. Reconcile commands populate and align tool-owned caches; they do not
introduce a second desired-state layer.

Codex config is `~/.codex/config.toml`, managed through
`home/dot_codex/modify_private_config.toml.tmpl`.

The Codex merge should manage stable tables like:

```toml
[marketplaces.prateek-local]
source_type = "local"
source = "/Users/prateek/.agents/plugins"

[plugins."review@prateek-local"]
enabled = true
```

It must preserve host-local trust, hook approval, NUX, marketplace timestamps,
and unrelated plugin state.

Claude Code config is `~/.claude/settings.json`. Add a private modify template
under `home/dot_claude/` to merge the repo-owned plugin settings while
preserving unrelated user settings.

The Claude merge should manage stable entries like:

<!-- Stale snapshot: predates the per-package `default_loaded` flag. After ADR 0007 the renderer emits per-package true/false derived from `package.toml`. See agent-skill-management/SKILL.md for current behavior. -->

```json
{
  "extraKnownMarketplaces": {
    "prateek-local": {
      "source": {
        "source": "directory",
        "path": "/Users/prateek/.agents/plugins"
      }
    }
  },
  "enabledPlugins": {
    "review@prateek-local": true,
    "ios@prateek-local": true
  }
}
```

Before committing the exact Claude local-source JSON shape, validate it by
running the native CLI once against `~/.agents/plugins` and copying the observed
settings shape into the merge template. Rendered plugins should be enabled in
config; packages with `render.<agent> = "none"` should be absent.

Ownership table:

```text
Path or state                                      Owner
home/dot_agents/packages/*/package.toml           human-edited desired state
home/dot_agents/packages/**                       human-edited package source
home/.chezmoiscripts/run_onchange_after_35-*      apply-time skill projection
home/.chezmoiscripts/run_onchange_after_36-*      apply-time plugin projection
~/.agents/skills                                  chezmoi materialized output
~/.claude/skills                                  chezmoi materialized output
~/.agents/plugins                                 chezmoi materialized output
~/.codex/config.toml                              chezmoi merge plus Codex local state
~/.claude/settings.json                           chezmoi merge plus Claude local state
~/.claude/plugins/known_marketplaces.json         Claude Code CLI
~/.claude/plugins/installed_plugins.json          Claude Code CLI
~/.claude/plugins/cache/**                        Claude Code CLI
~/.codex/plugins/cache/**                         Codex
```

## Tool-Owned Plugin State

Chezmoi owns desired state and generated source. The agent tools own install
caches.

Do not manage these paths directly:

```text
~/.claude/plugins/cache/
~/.claude/plugins/installed_plugins.json
~/.claude/plugins/known_marketplaces.json
~/.codex/plugins/cache/
```

Those files contain install paths, versions, timestamps, git SHAs, and cache
layout chosen by the tools. The repo may read them for validation, but should
not render them as source state.

Use a reconcile script to bridge desired config and tool caches.

## APM Package Layer

Use one APM project per package. APM resolves remote dependencies, produces a
lockfile, and gives the repo a repeatable source audit path.

Minimum package manifest:

```yaml
name: review
version: 1.0.0
targets:
  - agent-skills

dependencies:
  apm: []
```

Example remote dependency:

```yaml
dependencies:
  apm:
    - openai/skills/skills/.curated/cli-creator
```

Rules:

- Packages may contain local skill source under `skills/local/` without using
  APM local-path dependencies.
- Remote skills should be represented in the package `apm.yml` when possible.
- Keep package `apm.yml` dependencies unpinned so they target latest upstream
  refs by default. Use explicit full-SHA `#ref` pins only when intentionally
  testing or dogfooding PR-specific skill content.
- Commit `apm.lock.yaml` whenever a package has APM dependencies.
- Use `apm.lock.yaml` as the reproducible resolved snapshot for vendored
  content.
- Vendor every skill folder that APM deploys into staging for the package,
  including transitive-deployed skills selected by APM.
- Store accepted remote skill copies under
  `home/dot_agents/packages/<package>/skills/vendor/<skill-id>/`.
- Keep one `SOURCE.md` in each vendored remote skill root with upstream URL,
  ref, license note, scanner commands, and reviewer notes.
- Reject non-skill APM primitives in the first implementation.

If local-path APM dependencies become useful, add them after a smoke test proves
that APM handles this repo's package layout correctly.

## Vendoring Integrity

`vendor-agent-package` resolves one package at a time in a temporary staging
tree.

Staging contract:

- copy only that package's `apm.yml` and existing `apm.lock.yaml`, when present,
  into the staging root;
- run `apm install --dry-run --only=apm --target agent-skills`;
- run `apm install --only=apm --target agent-skills`;
- run the
  `.agents/skills/agent-skill-management/scripts/audit-apm-source-surface`
  script against `<staging-root>/apm_modules` before copying files back;
- run `apm audit --ci --no-policy --format json`;
- copy accepted deployed skill folders from staging into the package's
  `skills/vendor/` tree;
- preserve existing local vendor directory names by matching each
  `SOURCE.md` `APM dependency` field to the staged lockfile;
- remove stale APM-managed vendor directories that are no longer deployed by
  the staged lockfile;
- copy the generated lockfile back to the package.

The validator should enforce:

- staging audit passes;
- copied vendor paths match staged `agent-skills` deployment output;
- copied file lists match lockfile deployed paths when APM records them;
- copied file hashes match lockfile hashes when APM records them;
- when APM omits per-file hashes, repo validation computes and compares hashes;
- vendored skill roots contain no extra files except documented repo metadata.

New remote skills are inactive until their package is rendered to an agent's
root surface or rendered as a plugin for an agent.

## Manual Remote Skills

Use manual vendoring only when a useful remote skill cannot yet be represented
as an APM dependency.

Rules:

- stage downloads outside the repo or under an ignored staging directory;
- preview with `gh skill`, `npx skills`, or the upstream repository before
  copying;
- run `skill-scanner` when available;
- normalize the accepted skill into
  `home/dot_agents/packages/<package>/skills/vendor/<skill-id>/`;
- add `SOURCE.md` before strict validation;
- keep `render.<agent> = "none"` until validation and review pass.

## Repo-Local Management Skill

Create one repo-local skill at `.agents/skills/agent-skill-management/`. Its
`SKILL.md` is the agent entrypoint for this workflow, and its `scripts/`
directory owns the deterministic helpers. Keep these helpers inside the skill
unless they become useful outside agent-driven maintenance.

Skill scripts:

- `inventory-agent-skills`: report every discovered `SKILL.md`, source root,
  runtime root, duplicate, missing `SKILL.md`, and broken link as JSON.
- `validate-agent-packages`: parse per-package `package.toml`, `apm.yml`, and
  package skill roots. It fails on missing source, duplicate skill ids, nested
  runtime skills, invalid frontmatter, unsupported plugin components, invalid
  package state, and missing third-party source metadata.
- `vendor-agent-package <package>`: resolve one package's APM dependencies in
  staging, update its lockfile, copy accepted remote skills into
  `skills/vendor/`, and run validation.
- `audit-apm-source-surface <source-audit-root>`: inspect staged dependency
  source before APM target filters hide unsupported components.
- `render-agent-core-skills`: render explicit output roots from packages whose
  `render` surface is `root` for that agent.
  `--check-live` also inventories live skill roots and fails on live-only skills
  or stale compatibility symlinks before `chezmoi apply`.
- `render-agent-plugin-marketplace`: render an explicit plugin marketplace
  root, including Codex and Claude manifests and marketplace catalogs.
- `reconcile-agent-plugins`: print the native CLI commands for the current
  package render policy. Preview-only; the user copy/pastes the output. There
  is no apply path because Codex and Claude Code own their install caches.
- `audit-skill-context`: measure startup metadata as skill name, description,
  and runtime path. It should support root skill projections and installed
  plugin surfaces.

Do not create separate repo-local skills for audit, render, vendor, or install
operations in the first implementation. The single skill keeps the workflow
discoverable and matches the existing repo-local `chezmoi-management` pattern.

If this becomes useful outside this checkout, move or copy the skill into the
`core` machine-wide package as a later, reviewable change.

`reconcile-agent-plugins` is preview-only: it prints native commands for the
current render policy so the user can copy/paste them. See
`agent-skill-management/SKILL.md` and `references/plugin-reconcile.md` for
the current shape (the script honors `default_loaded` and skips Codex CLI
toggles since the current `codex plugin` CLI only exposes `marketplace`).

Only use native commands for tool-owned cache and install records. Do not write
those records directly.

## Repo-Local Skill Scopes

This plan governs machine-wide skills and plugins materialized under `$HOME`.
Repo-local `.agents/skills`, `.agents/plugins`, `.claude/skills`, and
`.claude-plugin` directories stay repo-local.

Rules:

- `inventory-agent-skills` includes repo-local roots in reports and context-cost
  accounting, because Codex and Claude Code can discover them from project
  scope.
- `audit-skill-context --agent codex .` reports per-skill description sizes
  for the current checkout. Budget rollup is not implemented yet.
- `audit-skill-context --agent claude .` is the symmetric Claude report.
- Repo-local skills do not become machine-wide skills unless they move into
  `home/dot_agents/packages/<package>/`.
- Duplicate skill ids between repo-local and machine-wide packages are reported
  before projection or plugin generation.

## Implementation Phases

Phase 1: package inventory and manifest

- Add `.agents/skills/agent-skill-management/` with a lean `SKILL.md`.
- Add `.agents/skills/agent-skill-management/scripts/inventory-agent-skills`.
- Add the package-source mode of
  `.agents/skills/agent-skill-management/scripts/validate-agent-packages`.
- Add `.agents/skills/agent-skill-management/scripts/audit-skill-context`.
- Add tests against sample package trees.
- Add one `package.toml` per initial package under
  `home/dot_agents/packages/<package>/`.
- Classify current skills into proposed packages.
- Add minimal `apm.yml` files for each package, with empty `dependencies.apm`
  when the package has no remote dependencies.

Phase 2: package source cutover

- Move every retained current skill out of `home/dot_agents/skills/` and into
  `home/dot_agents/packages/<package>/skills/local/` or
  `home/dot_agents/packages/<package>/skills/vendor/`.
- Move the always-on baseline into `home/dot_agents/packages/core/`.
- Move non-core skills into their package source before any apply-time
  generated output replaces live root skills.
- Add `SOURCE.md` for manually vendored remote skills before strict validation.
- Run the package-source validator and fix duplicate or nested skill ids.

Phase 3: core root projection

- Add `.agents/skills/agent-skill-management/scripts/render-agent-core-skills`.
- Run
  `.agents/skills/agent-skill-management/scripts/render-agent-core-skills --check-live`
  and resolve every live-only skill or stale compatibility symlink.
- Add `home/.chezmoiscripts/run_onchange_after_35-agent-core-skills.sh.tmpl`
  so `chezmoi apply` renders live `~/.agents/skills` and `~/.claude/skills`.
- Run validation and the Codex `audit-skill-context` report.
- Keep reducing the core package until the report stays small.

Phase 4: generated plugin marketplace

- Choose the first package with `render.<agent> = "plugin"` that already
  exists under `home/dot_agents/packages/`.
- Add
  `.agents/skills/agent-skill-management/scripts/render-agent-plugin-marketplace`.
- Add `home/.chezmoiscripts/run_onchange_after_36-agent-plugins.sh.tmpl` so
  `chezmoi apply` renders live `~/.agents/plugins`.
- Extend `.agents/skills/agent-skill-management/scripts/validate-agent-packages`
  to check package source and use renderer `--check` modes for generated-output
  drift.
- Validate Codex manifests, Claude manifests, and both marketplace catalogs.
- Verify that the generated plugin root can be installed by Claude with
  `claude plugin validate` and a local marketplace add in a scratch or dry-run
  path when possible.

Phase 5: config and reconcile

- Extend `home/dot_codex/modify_private_config.toml.tmpl` for the local
  marketplace and rendered plugin activation.
- Add `home/dot_claude/modify_private_settings.json.tmpl` for
  `extraKnownMarketplaces` and `enabledPlugins`.
- Add `.agents/skills/agent-skill-management/scripts/reconcile-agent-plugins`.
- Use native CLIs to populate tool-owned caches.
- Confirm that packages rendered as plugins are enabled and packages rendered as
  `none` are unavailable to the agent.

Phase 6: APM vendoring

- Add remote dependencies to per-package `apm.yml` files.
- Add per-package `apm.lock.yaml` files when dependencies exist.
- Add `.agents/skills/agent-skill-management/scripts/vendor-agent-package`.
- Add `.agents/skills/agent-skill-management/scripts/audit-apm-source-surface`.
- For dependency-bearing changes, run the full path:
  `vendor-agent-package`, `validate-agent-packages`, renderer `--check` modes
  against temp roots, and the context audits.

## Validation

For this docs change:

```sh
git diff --check
```

Package and generated-output checks:

Run the package and generated-output checks after editing package source or
render policy.

```sh
.agents/skills/agent-skill-management/scripts/inventory-agent-skills
.agents/skills/agent-skill-management/scripts/validate-agent-packages
.agents/skills/agent-skill-management/scripts/render-agent-core-skills --check-live
tmp="$(mktemp -d)"
.agents/skills/agent-skill-management/scripts/render-agent-core-skills \
  --codex-root "$tmp/.agents/skills" \
  --claude-root "$tmp/.claude/skills"
.agents/skills/agent-skill-management/scripts/render-agent-core-skills \
  --check \
  --codex-root "$tmp/.agents/skills" \
  --claude-root "$tmp/.claude/skills"
.agents/skills/agent-skill-management/scripts/render-agent-plugin-marketplace \
  --plugins-root "$tmp/.agents/plugins" \
  --skip-config-templates
.agents/skills/agent-skill-management/scripts/render-agent-plugin-marketplace \
  --check \
  --plugins-root "$tmp/.agents/plugins"
.agents/skills/agent-skill-management/scripts/audit-skill-context --agent codex "$tmp/.agents/skills"
.agents/skills/agent-skill-management/scripts/audit-skill-context --agent codex .
.agents/skills/agent-skill-management/scripts/audit-skill-context --agent claude .
```

Plugin reconcile checks:

```sh
tmp="${tmp:-$(mktemp -d)}"
claude plugin validate "$tmp/.agents/plugins"
.agents/skills/agent-skill-management/scripts/reconcile-agent-plugins
chezmoi apply --dry-run --verbose --exclude=scripts
```

APM dependency edits:

```sh
tmp="$(mktemp -d)"
.agents/skills/agent-skill-management/scripts/vendor-agent-package <package>
.agents/skills/agent-skill-management/scripts/validate-agent-packages
.agents/skills/agent-skill-management/scripts/render-agent-core-skills \
  --codex-root "$tmp/.agents/skills" \
  --claude-root "$tmp/.claude/skills"
.agents/skills/agent-skill-management/scripts/render-agent-plugin-marketplace \
  --plugins-root "$tmp/.agents/plugins" \
  --skip-config-templates
.agents/skills/agent-skill-management/scripts/render-agent-core-skills \
  --check \
  --codex-root "$tmp/.agents/skills" \
  --claude-root "$tmp/.claude/skills"
.agents/skills/agent-skill-management/scripts/render-agent-plugin-marketplace \
  --check \
  --plugins-root "$tmp/.agents/plugins"
.agents/skills/agent-skill-management/scripts/audit-skill-context --agent codex .
.agents/skills/agent-skill-management/scripts/audit-skill-context --agent claude .
```

When a live Codex or Claude restart is practical, verify that omitted packages
are absent from automatic discovery and rendered plugin packages are available
through their plugin namespace.
