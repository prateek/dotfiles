---
status: current
doc_type: reference
owner: Prateek
created: 2026-09-07
updated: 2026-09-07
related:
  - ../../agent-marketplace/README.md
  - ../../.agents/skills/agent-skill-management/SKILL.md
  - ../adr/0023-apm-agent-marketplace-packaging.md
  - ../plans/apm-agent-marketplace-plan.md
---

# Agent Marketplace

[The isolated project](../../agent-marketplace/README.md) owns authored skills,
reviewed APM inputs, patches, native plugin metadata, build checks, and export.
It can build outside dotfiles after tool provisioning. The
[implementation plan](../plans/apm-agent-marketplace-plan.md) tracks rollout;
a changed checkout does not by itself change the live marketplace.

The consumer boundary is:

| Surface | Owner |
| --- | --- |
| `agent-marketplace/packages/` | Authored content, native locks/caches, reviewed patches |
| `agent-marketplace/build/marketplace` | Validated disposable native artifact |
| `home/.chezmoidata/agent_plugins.toml` | Explicit host eligibility and default enablement |
| `~/.agents/plugins` | Materialized shared marketplace |
| `~/.agents/plugins.previous` | Previous artifact retained for rollback |
| `~/.agents/skills` | Writable Codex runtime stub, preserving `.system/` |
| `~/.codex/skills` | Managed symlink to `../.agents/skills` |
| `~/.claude/CLAUDE.md` | Managed symlink to `../.agents/AGENTS.md` |
| Claude/Codex native caches | Native client CLIs and app-server APIs |

The default enabled set is `core`, `mattpocock`, `review`, and `utils-agent`. All ten
packages remain available in both catalogs. Codex's hook-bearing plugins suppress
hook discovery with an explicit empty `hooks` object. The 22 paired human-only
controls remain file contracts; these checks do not prove model invocation behavior.

Use [materialization](../../.agents/skills/agent-skill-management/references/generated-outputs.md)
for build-on-apply or prebuilt copy, and
[native reconciliation](../../.agents/skills/agent-skill-management/references/plugin-reconcile.md)
for cache updates, disabled project plugins, and rollback. Script 35 preserves
Codex's runtime skill stub; script 36 owns the build/copy/reconcile sequence.
Config merge templates read host policy directly. Pi follows Claude selection;
Cursor keeps its existing marketplace registration and ACP behavior.

The [management skill](../../.agents/skills/agent-skill-management/SKILL.md) routes
maintenance work. The [test index](../../tests/README.md#agent-package-checks)
separates portable packaging checks, consumer checks, native client checks,
console producer parity, and authenticated evals.
