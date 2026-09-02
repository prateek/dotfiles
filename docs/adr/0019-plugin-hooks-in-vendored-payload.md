---
status: accepted
doc_type: adr
created: 2026-09-02
owner: Prateek
related:
  - 0013-apm-vendored-tool-integrations.md
  - 0007-default-loaded-plugin-policy.md
  - ../plans/agent-plugin-renderer-plan.md
  - ../../.agents/skills/agent-skill-management/SKILL.md
status_detail: "Accepted with the superpowers package and the crit hook move on 2026-09-02."
---

# ADR 0019: Plugin hooks ship in the vendored plugin payload

## Context

The agent package renderer only projected skills. A marketplace plugin
that also ships hooks had two bad options: enumerate its skill
subdirectories one dependency at a time and drop the hook, or hand-carry
the hook somewhere else. [ADR 0013](0013-apm-vendored-tool-integrations.md)
took the second route for crit, placing its `ExitPlanMode` plan-review hook
in `claude-settings-managed.json.tmpl` because the renderer had no hook
projection. Adding [superpowers](https://github.com/obra/superpowers) made
the gap concrete: its SessionStart hook is the mechanism behind its skills,
apm already normalizes the plugin's hooks under `.apm/hooks`, and the only
thing rejecting them was this repo's own source-surface audit.

Two runtime facts, verified on Claude Code 2.1.258 with an isolated
`CLAUDE_CONFIG_DIR`, shaped the contract. Claude auto-loads a plugin's
`hooks/hooks.json` and logs a duplicate-hooks error if the manifest repeats
that path. A disabled plugin's hooks are read but not registered, so
`default_loaded = false` really does keep a package's hooks off.

## Decision

- A package may carry a `hooks/` payload: `hooks.json` plus the scripts it
  runs, the same layout the plugin tree uses. The renderer copies it
  verbatim, preserving executable bits, and the drift check treats a
  mode-only change as drift.
- `vendor-agent-package` copies a marketplace-plugin dependency's hooks from
  apm's `.apm/hooks` normalization into `hooks/` with a `SOURCE.md`, refuses
  to overwrite a hand-authored `hooks/`, removes a vendored `hooks/` whose
  dependency stopped shipping hooks, and fails when two dependencies ship
  hooks. Those checks run before any skill tree is replaced.
- Hooks are Claude-only. The rendered Codex manifest declares `"hooks": {}`,
  the one value that disables Codex's `hooks/hooks.json` auto-discovery.
  Upstream superpowers made the same call (Codex triggers skills natively and
  its bootstrap hook made Codex worse), and Codex gates plugin hooks behind
  a feature flag plus a trust review anyway. The Claude manifest does not
  name hooks at all.
- crit's plan-review hook moves into the review plugin. The review package
  depends on `tomasz-tomczyk/crit/integrations/claude-code`, crit's Claude
  plugin directory, which yields the same three skills plus the hook and
  re-vendors both together when the binary moves.
- The managed settings fragment retires its copy with a marker: a desired
  hook block whose `hooks` list is empty claims its matcher and contributes
  nothing, so the settings merge removes the block chezmoi used to own. The
  marker owns the whole matcher, exactly as the managed block it replaces
  did, so a third-party `ExitPlanMode` block would go with it. Prune the
  marker once every machine has applied.

## Consequences

- superpowers ships disabled with its hook intact; enabling it per project
  gives upstream behavior on Claude. Machines under an MDM policy with
  `allowManagedHooksOnly` skip every non-managed hook regardless.
- The plan-review hook fires only while `review@prateek-local` is enabled,
  matching how the skills that drive it are gated.
- Other apm primitives (`commands`, `prompts`, `mcp`) still fail the
  source-surface audit until the workflow carries them; the payload
  contract is table-driven so each is one entry.
- Subdirectory dependencies remain the fallback for plugins that ship
  primitives the workflow does not carry; a bare `skills/` directory is not
  a valid apm dependency, so that fallback means one dependency per skill.

## Alternatives considered

- **Keep the managed-settings hook for crit.** Works on machines where the
  review plugin is disabled, but duplicates a file upstream already
  maintains and would double-register once the plugin carried it.
- **Per-package acceptance list to drop primitives silently.** Cheaper than
  carrying hooks, but the audit exists to make exactly that drop loud.
- **Enumerate superpowers' 14 skill subdirectories.** Passes the audit
  unchanged, but loses the hook, adds a dependency line per upstream skill,
  and misses new skills until someone edits `apm.yml`.
