---
name: agent-skill-management
description: Manage this repo's dotfiles-backed agent skill packages, apply-time skill and plugin projections, and Codex, Claude, or pi rendered plugin activation. Use when editing home/dot_agents package sources, generated live skill or plugin output scripts, agent plugin config, or the related docs in docs/plans, docs/research, and docs/adr.
---

# Agent Skill Management

Use this skill for machine-wide agent skill package work in this dotfiles repo:
package source under `home/dot_agents/packages/`, apply-time projections into
`~/.agents/skills`, `~/.claude/skills`, and `~/.agents/plugins`, and the Codex
Claude, or pi config that activates rendered plugins.

## Operating Model

Keep three ownership layers separate:

- Human-edited source lives under `home/dot_agents/packages/<package>/`.
- Chezmoi renders live generated roots during `chezmoi apply`.
- Codex, Claude Code, and pi own their plugin install caches.

Do not commit generated trees under `home/dot_agents/skills/`,
`home/dot_claude/skills/`, or `home/dot_agents/plugins/`. Those paths are
derived from package source and should stay out of git.

Machine-wide package work belongs under `home/`. Repo-local agent instructions
for this checkout stay at the repo root or under repo-root `.agents/`.

## Package Layout

Each package lives at `home/dot_agents/packages/<package>/`.

Expected package files:

- `package.toml`: human-edited display name and `[render]` policy.
- `apm.yml`: human-edited APM manifest for remote dependencies.
- `apm.lock.yaml`: committed resolver snapshot when the package has APM
  dependencies.
- `skills/local/<skill-id>/`: repo-authored skill source.
- `skills/vendor/<skill-id>/`: reviewed remote skill source.
- `skills/vendor/<skill-id>/SOURCE.md`: upstream URL, resolved ref, license
  note, scanner commands, and reviewer notes.
- Optional plugin-shaped payloads at the package root, in the layout the
  plugin tree uses: `commands/`, `agents/`, `hooks/` (its `hooks.json` plus
  the scripts it runs), `.mcp.json`. The renderer passes them through
  verbatim. Claude consumes all of them. Codex consumes skills only: the
  rendered Codex manifest declares `hooks: {}` to switch off its
  `hooks/hooks.json` auto-discovery, and the renderer warns (and continues)
  for every payload kind Codex does not map.
- `hooks/SOURCE.md`: provenance for an APM-vendored hooks payload, in the
  same format as a vendored skill's `SOURCE.md`.

There is no global package manifest. The renderers walk
`home/dot_agents/packages/*/package.toml`; the package id is the directory name.

Allowed render policy values:

- `plugin`: render the package as a local plugin for that agent.
- `none`: do not render the package for that agent.

Every rendered package is a plugin; there is no root-skill projection. Keep
always-on packages (like `core`) as plugins with `default_loaded = true`.

### User-invoked skills

A skill the human types but the model never fires on its own takes two
frontmatter-and-sidecar halves, because no single key reaches all four
harnesses:

- `disable-model-invocation: true` in `SKILL.md`, honored by Claude Code, pi,
  and cursor-agent.
- `policy.allow_implicit_invocation: false` in the skill's
  `agents/openai.yaml`, for Codex, which ignores the frontmatter key. Create
  the sidecar if the skill has none, and override the value if a vendored
  upstream ships `true`.

`validate-agent-packages` fails on either half without the other, so the pair
cannot drift apart — which matters most when a re-vendor restores upstream
frontmatter and strips the flag, leaving a sidecar that suppresses the skill
on Codex alone. Evidence for the per-harness split is in
[skill-invocation-frontmatter-research.md](../../../docs/research/skill-invocation-frontmatter-research.md).

Flagging a skill removes its listing row and its whole description budget.
The model can still read its files by path, so a listed router skill can
route to user-invoked bodies beside it; what it loses is the ability to
invoke them through the Skill tool.

### Default-loaded policy

`package.toml` may set `default_loaded = false` to ship a package installed
but disabled. Default is `true`. Today set to `false` on `design`,
`experimental`, `ios`, `obsidian-wiki`, `superpowers`, `utils-human`. The
plugin tree still renders and apply keeps Claude's install record, so on
Claude the skills are one flip away. `inventory-agent-skills` reports the
field, so check it there rather than trusting this list.

To flip a plugin globally, change `default_loaded` and re-render. To flip
one on for a single project, drop a project-root override:

- Claude: `.claude/settings.json` with
  `"enabledPlugins": { "design@prateek-local": true }`.
- Codex: `.codex/config.toml` with
  `[plugins."design@prateek-local"] enabled = true`. The project must be
  trusted on first use (`codex trust`). Apply does not give Codex a cache
  copy of a disabled package (`codex plugin add` also enables, and Codex has
  no disable verb), so first run `codex plugin add design@prateek-local` and
  then `chezmoi apply ~/.codex/config.toml` to restore the user-level
  `enabled = false`.

Per-machine override of managed keys is not supported via the agent
settings files; the chezmoi modify scripts deep-merge desired into each
file on every apply. See [ADR 0007](../../../docs/adr/0007-default-loaded-plugin-policy.md)
for the merge mechanism and the stale-key trade-off.

The `work × linux` headless profile is intentionally narrower: it merges the
generated Claude plugin fragment but omits
`claude-settings-managed.json.tmpl`, leaving DAYJOB's non-plugin settings
keys outside dotfiles ownership. A headless-only
`hooks.read-source-state.pre` command installs uv before target-state
computation; both the Claude modifier and later `run_after_` plugin renderer
use it. See the
[Linux DevPod runbook](../../../docs/runbooks/linux-work-devpod-orca.md).

## APM And Vendoring

Use one APM project per package.

Rules:

- Keep package `apm.yml` dependencies unpinned so they target latest upstream
  refs by default. Use an explicit full-SHA `#ref` pin only when intentionally
  testing or dogfooding PR-specific skill content, and keep the lockfile plus
  vendored source in sync.
- Use `apm.lock.yaml` as the reproducible reviewed snapshot.
- Vendor accepted remote skill folders into `skills/vendor/<skill-id>/`.
- Keep one `SOURCE.md` in each vendored remote skill root.
- Record intentional divergence from upstream as a "Local delta" note in
  `SOURCE.md`. Re-vendoring overwrites the skill tree, so re-apply noted
  deltas afterward and drop them once upstreamed.
- Agent tool integrations (for example crit) vendor like any other dependency;
  see [ADR 0013](../../../docs/adr/0013-apm-vendored-tool-integrations.md).
  When the tool's binary moves (e.g. `brew upgrade crit`), re-run
  `vendor-agent-package` for its package so skills match the installed CLI.
  crit's plan-review hook is part of that vendored payload (the review
  package's `hooks/`), so it moves with the skills.
- The vendor flow carries skills and hooks. `audit-apm-source-surface`
  rejects every other primitive a dependency ships (`mcp`, `commands`,
  `prompts`, ...); extend the workflow before accepting one.
- A package carries at most one `hooks/` payload. If two dependencies ship
  hooks, split them across packages.

Use `.agents/skills/agent-skill-management/scripts/vendor-agent-package
<package>` for APM-backed vendoring. It stages APM output, audits the source
surface, copies accepted skill trees, copies a marketplace-plugin dependency's
hooks (from apm's `.apm/hooks` normalization) into `hooks/`, updates the
package lockfile, and runs package validation.

### Refreshing to latest upstream

`vendor-agent-package` installs deterministically from `apm.lock.yaml`, so a
refresh needs a lockfile update first. For each package with APM dependencies:

1. Copy `apm.yml` and `apm.lock.yaml` into a scratch directory and run
   `apm update -y` there, then copy the refreshed `apm.lock.yaml` back.
   Running `apm update` in the package root would litter it with
   `apm_modules/` and deployed skill output.
2. Run `vendor-agent-package <package>`.
3. Re-apply the local deltas noted in each vendored skill's (and `hooks/`)
   `SOURCE.md`
   (LICENSE copies, the trycycle `literal_run_phase.py` rename), then review
   the vendor diff before committing. `validate-agent-packages` fails on any
   upstream filename that hits a chezmoi attribute prefix (like `run_`);
   rename such files with a `literal_` prefix.

Refresh gotchas:

- Subdirectory deps must not contain symlinks that point outside the
  subdirectory: apm materializes subdir deps with a git sparse cone, so such
  symlinks dangle and the install fails with ENOENT on the symlink targets.
  Depend on the repo root instead (`forjd/better-writing` in core hit this).
- A dependency path cannot end in a dot-directory: apm parses the final
  segment as a file extension and rejects e.g. `ar9av/obsidian-wiki/.skills`,
  and repo-root deps do not discover skills inside hidden directories either.
  Enumerate each skill subdir instead (`.../.skills/<skill>`, one dep per
  skill; see the obsidian-wiki package).
- A repo-root marketplace-plugin dependency (for example `obra/superpowers`)
  vendors its skills and its `hooks/`; any other primitive it ships fails
  `audit-apm-source-surface` until the workflow carries it. A bare `skills/`
  directory is not a valid apm dependency, so falling back to skills-only
  means one dep per `skills/<skill>` subdirectory.
- SOURCE.md regeneration preserves only the `License` and `Notes` fields.
  Keep local-delta and rename notes inside `Notes`, never as extra bullets.
- When a skill pairs with a CLI this repo installs (acpx, crit, agent-slack,
  shortcut), upgrade the binary first so the vendored skill matches it.
- On the corp laptop, `openclaw/*` clones 503 over HTTPS; prefix apm and
  vendor commands with a scoped rewrite:
  `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0='url.git@github.com:openclaw/acpx.insteadOf' GIT_CONFIG_VALUE_0='https://github.com/openclaw/acpx'`.

Manual vendoring is only for useful remote skills that cannot be represented as
APM dependencies yet. Stage downloads outside the repo or in ignored staging,
add `SOURCE.md`, and keep the package inactive until validation passes.

## Generated Outputs

Apply-time generated state:

- `~/.agents/plugins`: shared local plugin marketplace; the only skill
  projection.
- `~/.agents/skills`: empty maintained stub. It exists because
  `~/.codex/skills` symlinks to it and Codex writes runtime `.system/`
  skills through that path; the maintainer preserves `.system/` and clears
  everything else.
- `~/.claude/skills`: retired. The maintainer removes it when it is our
  generated root and leaves (with a warning) anything hand-authored.

The apply-time scripts are:

- `home/.chezmoiscripts/run_onchange_after_35-agent-skill-roots.sh.tmpl`
- `home/.chezmoiscripts/run_onchange_after_36-agent-plugins.sh.tmpl`

Those scripts should fail loudly, own their destination roots, clean stale
files, and include template hash comments for their generator inputs so
chezmoi reruns them only when package source or renderer code changes.

Committed generated config fragments:

- `home/.chezmoitemplates/agent-codex-plugin-config.toml.tmpl`
- `home/.chezmoitemplates/agent-claude-plugin-settings.json.tmpl`
- `home/dot_pi/agent/claude-plugins.json.tmpl`

They are projections of `package.toml` render policy, not separate desired
state.

## Plugin Boundaries

`~/.agents/plugins` is generated source for the local marketplace. The generated
plugin tree carries both Codex and Claude manifests:

- `.codex-plugin/plugin.json`
- `.claude-plugin/plugin.json`

Codex and Claude Code can share the generated plugin source tree, but they do
not share one manifest schema or one installed cache layout.

Do not hand-edit these tool-owned paths:

- `~/.claude/plugins/known_marketplaces.json`
- `~/.claude/plugins/installed_plugins.json`
- `~/.claude/plugins/cache/`
- `~/.codex/plugins/cache/`

`chezmoi apply` reconciles those records through the CLIs themselves:
`run_onchange_after_36-agent-plugins.sh.tmpl` runs
`.agents/skills/agent-skill-management/scripts/reconcile-agent-plugins --apply`
for each CLI in the machine's `agent_clis` right after rendering the
marketplace. Claude gets the marketplace registered, missing packages
installed, enable state matched to `default_loaded`, and orphaned
`@prateek-local` records uninstalled. Codex gets `plugin add` for
default-loaded packages (its cache refresh) and `plugin remove` for orphans;
disabled packages are skipped because `add` also enables. Run the script
without flags to print the equivalent command list for a manual pass. Details
in [plugin-reconcile.md](references/plugin-reconcile.md) and
[ADR 0020](../../../docs/adr/0020-apply-reconciles-plugin-installs.md).

## Validation

This subsystem is exercised by four independent test scripts. Run all four
when you change `package.toml`, the renderer, or either modify script — the
per-suite Makefile targets do not aggregate, and individual targets cover
disjoint behavior:

```sh
make test-agent-skill-packages   # validators, renderers, --check, inventory
make test-claude-settings        # ~/.claude/settings.json modify-script merge
make test-codex-config           # ~/.codex/config.toml modify-script merge
make test-pi-settings            # ~/.pi/agent settings and Claude marketplace config
```

Skipping any of the four lets a schema flip silently rot a sibling test.

After editing package source, run validation against explicit temp roots:

```sh
tmp="$(mktemp -d)"
.agents/skills/agent-skill-management/scripts/validate-agent-packages
.agents/skills/agent-skill-management/scripts/render-agent-plugin-marketplace \
  --plugins-root "$tmp/.agents/plugins" \
  --skip-config-templates
.agents/skills/agent-skill-management/scripts/render-agent-plugin-marketplace \
  --check \
  --plugins-root "$tmp/.agents/plugins"
```

When previewing chezmoi templates from a worktree, pass `--source <repo>` so
chezmoi reads from the worktree instead of the configured `sourceDir`
(typically `~/dotfiles`):

```sh
chezmoi --source "$PWD" execute-template \
  --file home/dot_claude/modify_private_settings.json.tmpl
```

For context-budget work, use:

```sh
.agents/skills/agent-skill-management/scripts/audit-skill-context --agent codex .
.agents/skills/agent-skill-management/scripts/skill-console render --no-open \
  --model claude-fable-5-1 --context-window 200000
```

`audit-skill-context` reports per-skill description size (chars/words) for
the given root. `skill-console render` simulates Claude Code's skill-listing
admission from live inputs (window x bytes/token x fraction = budget), checks
it against the newest `skill_listing` capture for the cwd, and writes a
self-contained HTML page for staging edits. Project skills, commands, and the
capture comparison key off the cwd (the capture falls back to
`--project-root`'s), so run `render` where Claude runs, normally the project
root. `--model` and `--context-window` are required until the statusline state
writer lands. `skill-console apply DECISIONS.json` dry-runs the exported
decisions; add `--commit` to write them into the source tree. `apply` refuses
dirty or symlinked targets and template syntax in settings keys, and at commit
re-checks every path's hash and every deletion's preconditions; the full
procedure is in
[the console plan](../../../docs/plans/skill-management-console-plan.md#apply-semantics).
Tests: `make test-skill-console`.

## Supporting Docs

This `SKILL.md` is the operational entrypoint. Use the files in `references/`
for focused detail, and `docs/plans/chezmoi-agent-skills-plan.md` for historical
plan context when needed. Do not require agents to read the plan before using
this skill.
