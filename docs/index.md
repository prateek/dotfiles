---
status: current
doc_type: index
created: 2026-05-12
updated: 2026-07-04
related:
  - document-lifecycle.md
  - ../home/dot_agents/packages/core/skills/local/code-gardening/SKILL.md
status_detail: "Entry point for docs routing. Update when docs are added, moved, closed, or reclassified."
---

# Documentation Index

Use this file first when looking for repo guidance. Lifecycle status in each
document's frontmatter decides whether it is current guidance, active work, a
proposal, or history.

When changing docs, follow [Document Lifecycle](document-lifecycle.md) and the
[code-gardening workflow](../home/dot_agents/packages/core/skills/local/code-gardening/SKILL.md).

## Current Guidance

| Doc | Use it for |
| --- | --- |
| [Documentation Index](index.md) | Routing to current guidance, proposed work, decisions, and history. |
| [Document Lifecycle](document-lifecycle.md) | Frontmatter, status transitions, and index rules for `docs/`. |
| [Chezmoi Architecture](references/chezmoi-architecture.md) | Dotfiles source-state architecture and validation entrypoints. |
| [Chezmoi Drift Banner](../home/dot_config/dotfiles/chezmoi-drift/README.md) | Cached shell banner for managed chezmoi drift. |
| [Jamf Self Service Elevation](references/jamf-self-service-elevation.md) | Temporary admin elevation on Jamf-managed work Macs. |
| [Mise Tool Management](references/mise-tool-management.md) | Mise-native CLI and tool selection. |
| [Tart Install Validation](runbooks/tart-mini-validation.md) | Local disposable-VM install validation on a Mac mini. |
| [Tartelet Runner Setup](runbooks/tartelet-runner-setup.md) | Standing up a homelab mini as an ephemeral iOS/macOS GitHub Actions runner host. |
| [USB-C Cable Audit](runbooks/usb-c-cable-audit.md) | Auditing unlabeled USB-C cables for speed, power, generation, and TB5 capability. |

## Open And Proposed Work

| Doc | Status |
| --- | --- |
| [Agent Plugin Renderer](plans/agent-plugin-renderer-plan.md) | Active; single plugin-only render mode with APM payload pass-through landed — pack-bundle vendoring stays deferred. |
| [Crit Integration](plans/crit-integration-plan.md) | Active; claude-code skills re-vendored with plan-hook via managed settings — live rollout smoke and upstream description PR remaining. |
| [Crit Agent Bridge](plans/crit-agent-bridge-plan.md) | Active; wires crit's `agent_cmd` hook to acpx for reply-only cross-model comment dispatch. Implemented and tested; live smoke pending. |
| [BetterDisplay Display Modes](plans/betterdisplay-display-modes-plan.md) | Proposed only; no `displayctl` implementation exists in this checkout. |
| [Decomment Skill](plans/decomment-skill-plan.md) | Active; decomment core skill, trigger-channel fixes, and evals under implementation. |
| [Orcactl](plans/orcactl-plan.md) | Draft for a separate Go repo/tool; dotfiles integration is future install/skill wiring. |
| [Downstream Fork](plans/downstream-fork-plan.md) | Active; thin assembly-repo forks as daily drivers on the `prateek/forks` fleet monorepo — engine, three-job template, harness, security review, monorepo scaffold, and fleet digest done; dotfiles gardening landed bar the retoken; provisioning + ghost-pepper migration pending Prateek. |
| [Goku Karabiner Migration](plans/goku-karabiner-migration-plan.md) | Active; Karabiner config now compiles from `karabiner.edn` via goku — on-device pad verification pending. |
| [Leader Key to Tuna Migration](plans/leader-key-to-tuna-migration-plan.md) | Active; full cutover applied on the migrate-tuna branch (config at `~/.config/tuna`, F18→combo). Remaining: grant Tuna Accessibility, verify shell/URL binds. Leader Key kept as fallback. |
| [Sudo Askpass 1Password](plans/sudo-askpass-1password-plan.md) | Accepted design; implementation pending, current code still uses sudo keepalive. |
| [Tartelet Self-Hosted Runners](plans/tartelet-runner-plan.md) | Active; cask, managed plist, LaunchAgent, host data, VM-image builder, and runbook landed. On-mini end-to-end (golden VM build + first-run credential paste) still to be exercised. |
| [Tartelet Runner Memory-Guard](plans/tartelet-runner-memory-guard-proposal.md) | Proposed; design for a circuit breaker that sheds the runner under host memory pressure after a 2026-07-03 jetsam wedge. Prototyped and validated, then dropped — no code in-tree. |
| [Zsh Fresh-Shell Validator](plans/zsh-fresh-shell-validator-plan.md) | Active plan for shell correctness and startup checks. |
| [Test-Suite Rebuild](plans/test-suite-rebuild-plan.md) | Proposed; rebuild the `tests/*.zsh` suite from scratch on two primitives — assertions derived from source-of-truth, and self-enforcing coverage — with a five-tier pyramid and a shared harness. Not started. |

## Decision Records

Accepted ADRs explain why a decision was made. Use the current guidance above
for day-to-day implementation details.

| ADR | Current guidance |
| --- | --- |
| [ADR 0001 - Downstream fork repo architecture](adr/0001-downstream-fork-architecture.md) | Superseded by [ADR 0015](adr/0015-downstream-fork-daily-driver.md). |
| [ADR 0002 - Fresh-shell validator architecture](adr/0002-zsh-fresh-shell-validator.md) | `scripts/audit/zsh-fresh-shells.zsh` and [tests index](../tests/README.md). |
| [ADR 0003 - git-subrepo-managed `src/`](adr/0003-downstream-fork-subrepo.md) | Superseded by [ADR 0001](adr/0001-downstream-fork-architecture.md). |
| [ADR 0004 - Tart install validation and tracing](adr/0004-tart-install-validation-and-tracing.md) | [Tart Install Validation](runbooks/tart-mini-validation.md). |
| [ADR 0005 - Mise-managed tool selection](adr/0005-mise-tool-management.md) | [Mise Tool Management](references/mise-tool-management.md). |
| [ADR 0006 - Chezmoi migration target architecture](adr/0006-chezmoi-migration-prototype.md) | [Chezmoi Architecture](references/chezmoi-architecture.md). |
| [ADR 0007 - Default-loaded plugin policy](adr/0007-default-loaded-plugin-policy.md) | [Agent Skill Management](../.agents/skills/agent-skill-management/SKILL.md). |
| [ADR 0008 - Sudo askpass via 1Password](adr/0008-sudo-askpass-1password.md) | Current behavior remains [Jamf Self Service Elevation](references/jamf-self-service-elevation.md); accepted askpass design is tracked in [Sudo Askpass 1Password](plans/sudo-askpass-1password-plan.md). |
| [ADR 0009 - Karabiner config via Goku codegen](adr/0009-goku-karabiner-codegen.md) | [Goku Karabiner Migration](plans/goku-karabiner-migration-plan.md); edit `karabiner.edn`, never `karabiner.json`. |
| [ADR 0010 - Single machine_type axis for package selection](adr/0010-machine-type-package-selection.md) | [Chezmoi Architecture](references/chezmoi-architecture.md) > Packages And Tools. |
| [ADR 0011 - Private repo for config overlays](adr/0011-private-repo-config-overlays.md) | `prateek/dotfiles-private` cloned via gated `.chezmoiexternal`, composed by `run_after_37-agent-slack-doc`; first consumer `~/.agents/docs/slack.md`. |
| [ADR 0012 - Config-gating convention](adr/0012-config-gating-convention.md) | chezmoi toggle convention (render-time vs init-time), implemented as one identity prompt + a layered `machines.toml` resolved by `features.tmpl`. Current guidance: [Chezmoi Architecture](references/chezmoi-architecture.md) > Config Gating. |
| [ADR 0013 - Agent tool integrations stay APM-vendored](adr/0013-apm-vendored-tool-integrations.md) | [Crit Integration](plans/crit-integration-plan.md) and [Agent Skill Management](../.agents/skills/agent-skill-management/SKILL.md). |
| [ADR 0014 - Tartelet self-hosted runners](adr/0014-tartelet-self-hosted-runners.md) | [Tartelet Self-Hosted Runners](plans/tartelet-runner-plan.md). |
| [ADR 0015 - Downstream forks as thin assembly repos](adr/0015-downstream-fork-daily-driver.md) | [Downstream Fork plan](plans/downstream-fork-plan.md) and the [`fork-lifecycle` skill](../.agents/skills/fork-lifecycle/SKILL.md) (fleet ops live in the `fork-ops` skill in `prateek/forks`). |

## Research

| Doc | Use it for |
| --- | --- |
| [Agent Skill Management Research](research/agent-skill-management-research.md) | Background on skill context pressure, package layout, and plugin defaults. |
| [Self-Improving Agents](research/self-improving-agents.md) | Pattern reference for durable agent feedback loops. |

## Historical Records

These documents are retained for archaeology. Follow their `current_guidance`
or `superseded_by` frontmatter before using them.

| Doc | Current guidance |
| --- | --- |
| [Chezmoi Agent Skills Plan](plans/chezmoi-agent-skills-plan.md) | [Agent Skill Management](../.agents/skills/agent-skill-management/SKILL.md) and [ADR 0007](adr/0007-default-loaded-plugin-policy.md). |
| [Chezmoi Drift Banner Plan](plans/chezmoi-drift-banner-plan.md) | [Chezmoi Drift Banner](../home/dot_config/dotfiles/chezmoi-drift/README.md). |
| [Chezmoi Migration Plan](plans/chezmoi-migration-plan.md) | [Chezmoi Architecture](references/chezmoi-architecture.md). |
| [Config-Gating Simplification](plans/config-gating-simplification-plan.md) | [ADR 0012](adr/0012-config-gating-convention.md) and [Chezmoi Architecture](references/chezmoi-architecture.md). |
| [Machine-Type Package Selection](plans/machine-type-package-selection-plan.md) | [ADR 0010](adr/0010-machine-type-package-selection.md) and [Chezmoi Architecture](references/chezmoi-architecture.md). |
| [Docs Reorg And Agent-Surface Refresh](plans/docs-reorg-plan.md) | `AGENTS.md`, [Documentation Index](index.md), and [Document Lifecycle](document-lifecycle.md). |
| [GRM Repo](references/grmrepo.md) | [Git Conventions](../home/dot_agents/docs/git.md) for the `gh`/clone workflow; repos are cloned with `ghc`/`gh`. |
| [Setup Downstream Fork Plan](plans/setup-downstream-fork-plan.md) | [ADR 0015](adr/0015-downstream-fork-daily-driver.md) and the [`fork-lifecycle` skill](../.agents/skills/fork-lifecycle/SKILL.md). |
| [Setup Downstream Fork Secrets](plans/setup-downstream-fork-secrets-plan.md) | [ADR 0015](adr/0015-downstream-fork-daily-driver.md); credentials now flow through a 1Password service account. |
| [Worktree Convention Cleanup](plans/worktree-convention-cleanup-plan.md) | [Worktrees](../home/dot_agents/docs/worktrees.md) and [Git Conventions](../home/dot_agents/docs/git.md) for the Orca worktree workflow; worktrunk and the custom `grm` integration were removed. |
