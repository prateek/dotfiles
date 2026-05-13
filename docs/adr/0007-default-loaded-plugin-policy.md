---
status: accepted
doc_type: adr
created: 2026-05-13
owner: Prateek
related:
  - ../dev/chezmoi-agent-skills-plan.md
  - 0006-chezmoi-migration-prototype.md
---

# ADR 0007 — Default-loaded plugin policy

## Context

The plugin marketplace generated under `~/.agents/plugins/` carried every package as enabled. With ~60 skills installed, Claude Code's `/doctor` reported it was truncating ~20 skill descriptions every session: the listing exceeded the 1% context budget (~2k of 200k tokens; full listing ~7.5k). Most of the cost came from a few large packages (`design`, `ios`) Prateek only uses occasionally.

Native Claude Code controls are plugin-level via `enabledPlugins` (no per-skill disable; that's an open feature request). Prior to this ADR the renderer hardcoded `enabledPlugins[<pkg>] = true` for every plugin package, so there was no way to express "ship installed but disabled by default" without removing the package or writing a wrapper.

## Decision

Add a top-level `default_loaded: bool` field to `package.toml`. Default is `true`; the renderer in `.agents/skills/agent-skill-management/scripts/render-agent-plugin-marketplace` emits `enabledPlugins[<pkg>@prateek-local] = default_loaded` (Claude) and `enabled = default_loaded` (Codex). Packages still render into the marketplace tree; only the activation flag changes.

Mark the following packages as `default_loaded = false` in this iteration:

- `design`
- `experimental`
- `ios`
- `utils-human`

Override paths are project-scoped. The chezmoi modify scripts (`home/dot_claude/modify_private_settings.json.tmpl` for JSON via stdlib, `home/dot_codex/modify_private_config.toml.tmpl` for TOML via tomlkit) deep-merge the rendered desired tree into the user's `~/.claude/settings.json` and `~/.codex/config.toml` on every apply, with desired winning on conflicts. There is no provenance tracking, so per-machine override of managed keys via these files is not supported (any user edit gets overwritten on the next apply).

- Per-project Claude: drop `.claude/settings.json` at the project root with `"enabledPlugins": { "design@prateek-local": true }`. Project settings override user settings.
- Per-project Codex: drop `.codex/config.toml` at the project root with `[plugins."<pkg>@prateek-local"] enabled = true`. Codex walks `.codex/config.toml` from the project root down to cwd and deep-merges layers (closest wins, [docs](https://developers.openai.com/codex/config-advanced)). The project must be trusted on first use.

To flip a plugin globally, change `default_loaded` in `package.toml` and re-render. Stale `*@prateek-local` keys for retired packages persist as harmless cruft (the deep-merge engine treats `desired` as additive); clean them up by hand if they accumulate.

## Consequences

Loaded skill description tokens drop from ~7,500 to ~2,700 in the default machine state, which is just above the truncation threshold. The four disabled packages stay one config flip away.

`load_packages()` rejects non-bool TOML values for `default_loaded` so a typo in `package.toml` fails fast rather than silently coercing. `inventory-agent-skills` reports the field so audit tooling has a machine-readable surface.

This makes the source of truth explicit (`package.toml`) and routes around the absence of a `disabledSkills` setting in Claude Code. If `disabledSkills` ships upstream, this ADR can be revisited to allow per-skill control without splitting packages.

## Alternatives considered

- **Split packages further** so the granularity matches Prateek's actual use (e.g., `experimental-orca` vs the rest). Rejected because it inflates the package count and the daily/occasional split mostly aligns with existing package boundaries already.
- **Profile wrapper around `CLAUDE_CONFIG_DIR`** (à la community `claude-profile`/`claude-code-profiles`). Rejected as too heavy: it isolates credentials, sessions, and history, which is not what we want here.
- **Wait for upstream `disabledSkills`** ([anthropics/claude-code#26838](https://github.com/anthropics/claude-code/issues/26838)). Not actionable now.
