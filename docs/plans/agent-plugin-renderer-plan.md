---
status: active
doc_type: plan
owner: Prateek
created: 2026-07-02
updated: 2026-07-02
related:
  - ../adr/0007-default-loaded-plugin-policy.md
  - ../adr/0013-apm-vendored-tool-integrations.md
  - ../research/agent-skill-management-research.md
  - ../../.agents/skills/agent-skill-management/SKILL.md
status_detail: "Implementation landed on prateek/debug-crit-triggers 2026-07-02; pack-bundle vendoring remains deferred."
---

# Agent Plugin Renderer Plan

Collapse the agent package renderer to a single plugin-shaped pipeline: one
render mode, one payload contract covering every primitive APM can project,
and explicit per-agent mapping. Replaces the skills-only renderer and the
root-vs-plugin mode split.

## Background

Three inputs drove this design:

- An agentsview audit of crit usage showed the vendored Codex-flavored skills
  fighting how Claude Code actually works, and crit's own hook integration had
  no delivery path because the renderer only projects skills.
- The crit integration stays APM-vendored
  ([ADR 0013](../adr/0013-apm-vendored-tool-integrations.md)); its plan-review
  hook ships through managed Claude settings, so no package currently needs
  non-skill payload projection.
- A source-level review of apm-cli 0.13.0 found APM's plugin surface is a
  bounded five-part contract: `skills/`, `commands/`, `agents/`, a merged
  `hooks.json`, and `mcpServers` from `.mcp.json`. `apm pack` emits exactly
  this layout with an embedded per-file SHA-256 manifest. APM has no
  per-dependency agent targeting; one `apm.yml` per package matches its
  design.

## Decisions

1. **Single render mode.** Every package renders as a plugin in the
   `prateek-local` marketplace. The `root` render mode, the
   `render-agent-core-skills` script, and the `~/.claude/skills` root
   projection all retire; per-agent policy in `package.toml` collapses to
   plugin-or-none. One survivor: `~/.agents/skills` stays as an empty
   maintained stub because `~/.codex/skills` symlinks to it and Codex writes
   runtime `.system/` skills through that path
   (`maintain-agent-skill-roots`, chezmoi script 35).
2. **Payload contract is the plugin layout.** A package payload is the same
   five-part tree APM projects: `skills/`, `commands/`, `agents/`,
   `hooks.json`, `.mcp.json`. Local and vendored payloads share one shape;
   the renderer passes payload directories through verbatim and stamps the
   `.claude-plugin` / `.codex-plugin` manifests and marketplace entries.
3. **Per-agent mapping with warn-and-continue.** Claude maps all five payload
   kinds. Codex maps skills and hooks (`features.plugin_hooks`). A payload
   kind with no mapping for an enabled agent produces a rendered warning and
   is skipped; it must never be dropped silently, and it does not fail the
   render.
4. **Hooks ship through the same review gate as skills.** Hooks are
   executable config, so the vendor-time diff review is the gate; no extra
   machinery.
5. **No license capture.** APM has no license story and we do not need one
   here; SOURCE.md keeps a one-line license note only while the current
   vendoring flow exists.
6. **Deferred: `apm pack` bundle vendoring.** The committed
   `skills/vendor/` + SOURCE.md flow stays for now. Revisit committing pack
   bundle directories (and shrinking `vendor-agent-package`) when the next
   vendored package lands or the upstream bundle format settles.

## Costs To Sync

Retiring root projection namespaces the core skills: `decomment`,
`write-for-humans`, and friends become `core:<skill>` in listings and
invocations. References by bare name in `~/.claude/CLAUDE.md`,
`home/dot_agents/AGENTS.md`, memory files, and skill cross-references need a
sync pass in the same change. Description-driven auto-triggering is
unaffected, but the skill-listing context budget now counts every core skill
through the plugin path; re-check budget after the flip.

## Implementation Sketch

Sequenced after the crit re-vendor lands (it touches the review package and
the settings templates on the same branch):

1. `agent_skill_lib.py`: discover payload dirs beyond `skills/`; collapse
   render policy values.
2. `render-agent-plugin-marketplace`: pass payload through; emit manifests
   with `commands` / `agents` / `hooks` / `mcpServers` keys for Claude,
   skills + hooks for Codex; render warnings for unmapped payload kinds.
3. Delete `render-agent-core-skills` and chezmoi script 35; fold `core` into
   the plugin marketplace with `default_loaded = true`.
4. `validate-agent-packages` + the three test suites
   (`test-agent-skill-packages`, `test-claude-settings`,
   `test-codex-config`): cover payload validation, mapping warnings, and the
   core-as-plugin flip.
5. Reference sync pass for the `core:` namespace change, then live rollout
   via `render-agent-core-skills --check-live` equivalent for the new layout.
