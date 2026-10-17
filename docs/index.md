---
status: current
doc_type: index
summary: "Router to current guidance and open plans; the inventory and the retirement ledger hold everything else."
created: 2026-05-12
updated: 2026-10-17
related:
  - document-lifecycle.md
  - inventory.md
  - retired.md
  - ../agent-marketplace/packages/core/skills/code-gardening/SKILL.md
status_detail: "Keep rows free of status prose; a doc's state lives in its frontmatter and the generated inventory."
---

# Documentation Index

Start here for repo guidance. This file routes; it does not describe
progress. For every document with its status and summary, read the generated
[inventory](inventory.md). For documents that have left the tree, read the
[retirement ledger](retired.md). Terms are in the [glossary](../GLOSSARY.md).

When changing docs, follow [Document Lifecycle](document-lifecycle.md) and the
[code-gardening workflow](../agent-marketplace/packages/core/skills/code-gardening/SKILL.md).

## Current Guidance

| Doc | Use it for |
| --- | --- |
| [Document Lifecycle](document-lifecycle.md) | Frontmatter, statuses, retirement, and validator rules for `docs/`. |
| [Chezmoi Architecture](references/chezmoi-architecture.md) | Dotfiles source-state architecture and validation entrypoints. |
| [Chezmoi Hook Lifecycle](references/chezmoi-hook-lifecycle.md) | Ordering and design rules for config hooks, apply scripts, init, and modify targets. |
| [Agent Marketplace](references/agent-marketplace.md) | Isolated APM source/build project, host activation, recovery, and validation lanes. |
| [acpx Routing](references/acpx-routing.md) | Explicit model/effort profiles, machine route declarations, catalog resolution, and diagnostics. |
| [Package helper](references/dotpkgs.md) | Shared package status, pin-aware operations, bulk latest, and banner/audit integration. |
| [Mise Tool Management](references/mise-tool-management.md) | Mise-native CLI and tool selection. |
| [Jamf Self Service Elevation](references/jamf-self-service-elevation.md) | Temporary admin elevation on Jamf-managed work Macs. |
| [Shell Banner](../home/dot_config/dotfiles/shell-banner/README.md) | Cached fastfetch banner for chezmoi drift and stale brew/mise packages. |
| [Private Service Certificate in Orca](../agent-marketplace/packages/utils-agent/skills/browser/references/certificate.md) | Host-scoped trust preference and pinned loopback recovery for an owned private HTTPS service. |
| [Dotfiles Landing](runbooks/dotfiles-landing.md) | Repo-specific checks and chezmoi preview for the published land-changes skill. |
| [Quarterly Review](runbooks/quarterly-review.md) | Docs that need a decision and the manual session-friction pass. |
| [acpx Skill Rewrite](runbooks/acpx-skill-rewrite.md) | Rewriting authored skills through acpx native flows, with the required runtime overrides. |
| [Corporate TLS Inspection](runbooks/corp-tls-inspection.md) | Corporate CA trust for Node clients in shells and GUI apps behind a decrypting proxy. |
| [G95NC Display](runbooks/g95nc-display.md) | Native-output Sharp/Butter setup, app-wide BetterDisplay reset, private backups, logs, and recovery. |
| [Host Storage](runbooks/host-storage.md) | Required SSD mounts before apply computes targets or installs packages. |
| [Orca Shortcut Validation](runbooks/orca-shortcut-validation.md) | Local, SSH, and paired-server fork comparisons, sidebar focus regression, and release-specific integration limits. |
| [Session Archive Sync Permissions](runbooks/session-sync-permissions.md) | Building the dedicated sync app and validating its removable-volume access. |
| [Tart Install Validation](runbooks/tart-mini-validation.md) | Local disposable-VM install validation on a Mac mini. |
| [Tartelet Runner Setup](runbooks/tartelet-runner-setup.md) | Standing up a homelab mini as an ephemeral iOS/macOS GitHub Actions runner host. |
| [TCC Onboarding](runbooks/tcc-onboarding.md) | Default desktop-role CLI audit, manual native review, and stale-grant recovery. |
| [USB-C Cable Audit](runbooks/usb-c-cable-audit.md) | Auditing unlabeled USB-C cables for speed, power, generation, and TB5 capability. |

## Open Plans

Status and summary for each are in the [inventory](inventory.md#plans).

- [ACPX shared pane](plans/acpx-shared-pane-plan.md)
- [agent_clis consolidation](plans/agent-clis-consolidation-plan.md)
- [Agent friction remediation](plans/agent-friction-remediation-plan.md)
- [Agent session wiki](plans/agent-session-wiki-plan.md)
- [Agent skills repo split](plans/agent-skills-repo-split-plan.md)
- [BetterDisplay display modes](plans/betterdisplay-display-modes-plan.md)
- [Browser skill](plans/browser-skill-plan.md)
- [Browser components and Camofox adoption](plans/browser-runtime-controller-plan.md)
- [Decomment skill](plans/decomment-skill-plan.md)
- [Goku Karabiner migration](plans/goku-karabiner-migration-plan.md)
- [Linux devbox](plans/linux-devbox-plan.md)
- [Orca settings store](plans/orca-settings-store-plan.md)
- [Orca shortcut repair](plans/orca-shortcuts-plan.md)
- [orcactl](plans/orcactl-plan.md)
- [Permissions hybrid UI](plans/permissions-hybrid-ui-plan.md)
- [Permission utility product follow-up](plans/permissions-product-plan.md)
- [Prolo Ring cheat sheet](plans/prolo-ring-cheatsheet-plan.md)
- [Psychology book archive and tools](plans/psychology-book-archive-and-tools-plan.md)
- [Raycast config automation](plans/raycast-config-automation-plan.md)
- [Shell banner](plans/shell-banner-plan.md)
- [Skill management console](plans/skill-management-console-plan.md)
- [SSD layout and Arq coverage](plans/ssd-arq-layout-plan.md)
- [Tartelet runner memory guard](plans/tartelet-runner-memory-guard-proposal.md)
- [TCC onboarding](plans/tcc-onboarding-plan.md)
- [Touch ID for sudo](plans/touchid-sudo-plan.md)
- [Using-git-spice skill](plans/using-git-spice-skill-plan.md)

## Decisions, research, and history

- [Decision records](inventory.md#decision-records): every ADR with its
  successor or current guidance.
- [Research](inventory.md#research): evidence documents and the decisions
  they informed.
- [Retirement ledger](retired.md): every plan, research doc, reference, or
  runbook that has left the tree, and where its content went.
