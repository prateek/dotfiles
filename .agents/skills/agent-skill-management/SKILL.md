---
name: agent-skill-management
description: Manage this repo's dotfiles-backed agent skill packages, apply-time skill and plugin projections, and Codex or Claude rendered plugin activation. Use when editing home/dot_agents package sources, generated live skill or plugin output scripts, agent plugin config, or the related docs in docs/plans, docs/research, and docs/adr.
---

# Agent Skill Management

Use this skill for machine-wide agent skill package work in this dotfiles repo:
package source under `home/dot_agents/packages/`, apply-time projections into
`~/.agents/skills`, `~/.claude/skills`, and `~/.agents/plugins`, and the Codex
or Claude config that activates rendered plugins.

## Operating Model

Keep three ownership layers separate:

- Human-edited source lives under `home/dot_agents/packages/<package>/`.
- Chezmoi renders live generated roots during `chezmoi apply`.
- Codex and Claude Code own their plugin install caches.

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
- Optional plugin-shaped payloads at the package root, mirroring what APM
  projects: `commands/`, `agents/`, `hooks.json`, `.mcp.json`. The renderer
  passes them through to the plugin tree's conventional locations. Claude
  consumes all of them; Codex consumes skills and hooks, and the renderer
  warns (and continues) for payload kinds Codex cannot map.

There is no global package manifest. The renderers walk
`home/dot_agents/packages/*/package.toml`; the package id is the directory name.

Allowed render policy values:

- `plugin`: render the package as a local plugin for that agent.
- `none`: do not render the package for that agent.

Every rendered package is a plugin; there is no root-skill projection. Keep
always-on packages (like `core`) as plugins with `default_loaded = true`.

### Default-loaded policy

`package.toml` may set `default_loaded = false` to ship a package installed
but disabled. Default is `true`. Today set to `false` on `design`,
`experimental`, `ios`, `utils-human`. The plugin tree still renders, so
the skills are one flip away.

To flip a plugin globally, change `default_loaded` and re-render. To flip
one on for a single project, drop a project-root override:

- Claude: `.claude/settings.json` with
  `"enabledPlugins": { "design@prateek-local": true }`.
- Codex: `.codex/config.toml` with
  `[plugins."design@prateek-local"] enabled = true`. The project must be
  trusted on first use (`codex trust`).

Per-machine override of managed keys is not supported via the agent
settings files; the chezmoi modify scripts deep-merge desired into each
file on every apply. See [ADR 0007](../../../docs/adr/0007-default-loaded-plugin-policy.md)
for the merge mechanism and the stale-key trade-off.

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
  When the tool's binary moves (`mise run crit:use ...`), re-run
  `vendor-agent-package` for its package so skills match the installed CLI.
  crit's plan-review hook ships via `claude-settings-managed.json.tmpl`, not
  the plugin tree.
- Reject non-skill APM primitives unless this workflow is explicitly extended
  to support them.

Use `.agents/skills/agent-skill-management/scripts/vendor-agent-package
<package>` for APM-backed vendoring. It stages APM output, audits the source
surface, copies accepted skill trees, updates the package lockfile, and runs
package validation.

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

Use `.agents/skills/agent-skill-management/scripts/reconcile-agent-plugins` to
print the native tool commands needed to reconcile installed/cache state with
the local marketplace. The script is preview-only (copy/paste the output);
chezmoi does not render those records.

## Validation

This subsystem is exercised by three independent test scripts. Run all three
when you change `package.toml`, the renderer, or either modify script — the
per-suite Makefile targets do not aggregate, and individual targets cover
disjoint behavior:

```sh
make test-agent-skill-packages   # validators, renderers, --check, inventory
make test-claude-settings        # ~/.claude/settings.json modify-script merge
make test-codex-config           # ~/.codex/config.toml modify-script merge
```

Skipping any of the three lets a schema flip silently rot a sibling test.

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
```

The script reports per-skill description size (chars/words) for the given
root. Budget rollup is not implemented yet.

## Supporting Docs

This `SKILL.md` is the operational entrypoint. Use the files in `references/`
for focused detail, and `docs/plans/chezmoi-agent-skills-plan.md` for historical
plan context when needed. Do not require agents to read the plan before using
this skill.
