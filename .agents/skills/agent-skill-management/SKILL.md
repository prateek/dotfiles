---
name: agent-skill-management
description: Manage this repo's dotfiles-backed agent skill packages, apply-time skill and plugin projections, and Codex or Claude rendered plugin activation. Use when editing home/dot_agents package sources, generated live skill or plugin output scripts, agent plugin config, or the related docs/dev plans and research docs.
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

There is no global package manifest. The renderers walk
`home/dot_agents/packages/*/package.toml`; the package id is the directory name.

Allowed render policy values:

- `root`: materialize the package into the agent's default always-on skill root.
- `plugin`: render the package as an enabled local plugin for that agent.
- `none`: do not render the package for that agent.

In the first implementation, use `root` only for the `core` package. Non-core
packages should render as `plugin` or `none`.

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

Apply-time generated live roots:

- `~/.agents/skills`: Codex root skill projection.
- `~/.claude/skills`: Claude root skill projection.
- `~/.agents/plugins`: shared local plugin marketplace.

The apply-time scripts are:

- `home/.chezmoiscripts/run_onchange_after_35-agent-core-skills.sh.tmpl`
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

After editing package source, run validation against explicit temp roots:

```sh
tmp="$(mktemp -d)"
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
```

Before a live `chezmoi apply` that may replace `~/.agents/skills` or
`~/.claude/skills`, run:

```sh
.agents/skills/agent-skill-management/scripts/render-agent-core-skills --check-live
```

For context-budget work, use:

```sh
.agents/skills/agent-skill-management/scripts/audit-skill-context --agent codex .
```

The script reports per-skill description size (chars/words) for the given
root. Budget rollup is not implemented yet.

## Supporting Docs

This `SKILL.md` is the operational entrypoint. Use the files in `references/`
for focused detail, and `docs/dev/chezmoi-agent-skills-plan.md` for historical
plan context when needed. Do not require agents to read the plan before using
this skill.
