---
status: current
doc_type: index
created: 2026-05-12
updated: 2026-05-12
related:
  - document-lifecycle.md
  - ../home/dot_agents/skills/code-gardening/SKILL.md
status_detail: "Entry point for docs routing. Update when docs are added, moved, closed, or reclassified."
---

# Documentation Index

Use this file first when looking for repo guidance. Lifecycle status in each
document's frontmatter decides whether it is current guidance, active work, a
proposal, or history.

When changing docs, follow [Document Lifecycle](document-lifecycle.md) and the
[code-gardening workflow](../home/dot_agents/skills/code-gardening/SKILL.md).

## Current Guidance

| Doc | Use it for |
| --- | --- |
| [Documentation Index](index.md) | Routing to current guidance, proposed work, decisions, and history. |
| [Document Lifecycle](document-lifecycle.md) | Frontmatter, status transitions, and index rules for `docs/`. |
| [Chezmoi Architecture](references/chezmoi-architecture.md) | Dotfiles source-state architecture and validation entrypoints. |
| [Mise Tool Management](references/mise-tool-management.md) | Mise-native CLI/tool selection model. |
| [GRM](references/grmrepo.md) | Canonical clone discovery, GRM config refresh, and repo URL insertion. |
| [Tart mini validation](runbooks/tart-mini-validation.md) | Local disposable-VM install validation. |
| [Self-Improving Agents](research/self-improving-agents.md) | Pattern reference for durable agent feedback loops. |

## Proposed Work

| Doc | Status |
| --- | --- |
| [BetterDisplay display modes](plans/betterdisplay-display-modes-plan.md) | Proposed only; not implemented in this checkout. |
| [Chezmoi drift banner](plans/chezmoi-drift-banner-plan.md) | Active plan for the quiet managed-state drift shell banner. |

## Decision Records

Accepted ADRs explain why a decision was made. Use the current guidance above
for day-to-day implementation details.

| ADR | Current guidance |
| --- | --- |
| [ADR 0001 - Downstream fork repo architecture](adr/0001-downstream-fork-architecture.md) | [`setup-downstream-fork` skill](../home/dot_agents/skills/setup-downstream-fork/SKILL.md). |
| [ADR 0002 - Fresh-shell validator architecture](adr/0002-zsh-fresh-shell-validator.md) | `scripts/audit/zsh-fresh-shells.zsh` and [tests index](../tests/README.md). |
| [ADR 0004 - Tart install validation and tracing](adr/0004-tart-install-validation-and-tracing.md) | [Tart mini validation](runbooks/tart-mini-validation.md). |
| [ADR 0005 - Mise-managed tool selection](adr/0005-mise-tool-management.md) | [Mise Tool Management](references/mise-tool-management.md). |
| [ADR 0006 - Chezmoi migration target architecture](adr/0006-chezmoi-migration-prototype.md) | [Chezmoi Architecture](references/chezmoi-architecture.md). |

## Historical Records

These documents are retained for archaeology. Follow their `current_guidance`
or `superseded_by` frontmatter before using them.

| Doc | Current guidance |
| --- | --- |
| [Docs reorg and agent-surface refresh](plans/docs-reorg-plan.md) | `AGENTS.md`, [Documentation Index](index.md), and [Document Lifecycle](document-lifecycle.md). |
| [Agent skill management research](research/agent-skill-management-research.md) | `home/dot_agents/skills/`. |
| [Chezmoi agent skills plan](plans/chezmoi-agent-skills-plan.md) | `home/dot_agents/skills/`. |
| [Setup downstream fork plan](plans/setup-downstream-fork-plan.md) | [`setup-downstream-fork` skill](../home/dot_agents/skills/setup-downstream-fork/SKILL.md). |
| [Setup downstream fork secrets plan](plans/setup-downstream-fork-secrets-plan.md) | [`_secrets.py`](../home/dot_agents/skills/setup-downstream-fork/scripts/_secrets.py). |
| [Zsh fresh-shell validator plan](plans/zsh-fresh-shell-validator-plan.md) | `scripts/audit/zsh-fresh-shells.zsh` and [tests index](../tests/README.md). |
| [ADR 0003 - git-subrepo-managed `src/`](adr/0003-downstream-fork-subrepo.md) | [ADR 0001](adr/0001-downstream-fork-architecture.md). |
