---
status: current
doc_type: index
created: 2026-05-12
updated: 2026-09-08
related:
  - document-lifecycle.md
  - ../agent-marketplace/packages/core/skills/code-gardening/SKILL.md
status_detail: "Entry point for docs routing. Update when docs are added, moved, closed, or reclassified."
---

# Documentation Index

Use this file first when looking for repo guidance. Lifecycle status in each
document's frontmatter decides whether it is current guidance, active work, a
proposal, or history.

When changing docs, follow [Document Lifecycle](document-lifecycle.md) and the
[code-gardening workflow](../agent-marketplace/packages/core/skills/code-gardening/SKILL.md).

## Current Guidance

| Doc | Use it for |
| --- | --- |
| [Documentation Index](index.md) | Routing to current guidance, proposed work, decisions, and history. |
| [Document Lifecycle](document-lifecycle.md) | Frontmatter, status transitions, and index rules for `docs/`. |
| [Agent Marketplace](references/agent-marketplace.md) | Isolated APM source/build project, host activation, recovery, and validation lanes. |
| [Dotfiles Landing](runbooks/dotfiles-landing.md) | Repo-specific checks and chezmoi preview for the published land-changes skill. |
| [Chezmoi Architecture](references/chezmoi-architecture.md) | Dotfiles source-state architecture and validation entrypoints. |
| [Chezmoi Drift Banner](../home/dot_config/dotfiles/chezmoi-drift/README.md) | Cached shell banner for managed chezmoi drift. |
| [Chezmoi Hook Lifecycle](references/chezmoi-hook-lifecycle.md) | Ordering and design rules for config hooks, apply scripts, init, and modify targets. |
| [Corporate TLS Inspection](runbooks/corp-tls-inspection.md) | Corporate CA trust for Node clients in shells and GUI apps behind a decrypting proxy. |
| [Host Storage](runbooks/host-storage.md) | Required SSD mounts before apply computes targets or installs packages. |
| [Jamf Self Service Elevation](references/jamf-self-service-elevation.md) | Temporary admin elevation on Jamf-managed work Macs. |
| [Mise Tool Management](references/mise-tool-management.md) | Mise-native CLI and tool selection. |
| [Tart Install Validation](runbooks/tart-mini-validation.md) | Local disposable-VM install validation on a Mac mini. |
| [Tartelet Runner Setup](runbooks/tartelet-runner-setup.md) | Standing up a homelab mini as an ephemeral iOS/macOS GitHub Actions runner host. |
| [Session Archive Sync Permissions](runbooks/session-sync-permissions.md) | Building the dedicated sync app and validating its removable-volume access. |
| [USB-C Cable Audit](runbooks/usb-c-cable-audit.md) | Auditing unlabeled USB-C cables for speed, power, generation, and TB5 capability. |

## Open And Proposed Work

| Doc | Status |
| --- | --- |
| [acpx Skill Packaging](plans/acpx-skill-packaging-plan.md) | Active; the acpx conventions are now a trigger-owning skill next to the vendored `acpx-cli` command surface, the conventions doc and its AGENTS.md pointer are deleted. See [ADR 0028](adr/0028-router-skill-over-vendor-remap.md). Trigger arbitration measured 2026-09-08 (15/18, no cross-listing steals); remaining: two eval labels to settle. |
| [Agent Session Wiki](plans/agent-session-wiki-plan.md) | Active; hourly launchd archive sync, QMD history index, AgentsView wiring, and daily Claude wiki ingest on m4mini. See [ADR 0017](adr/0017-agent-session-archive.md). |
| [Restore Wiki Ingestion](plans/wiki-ingest-revisit-plan.md) | Active; the m4mini schedule and Claude Sonnet 5/high configuration are live and passed an end-to-end ingest. |
| [SSD Layout And Arq Coverage](plans/ssd-arq-layout-plan.md) | Active; Code, Tart, and WinMux storage migrated. Both SSD volumes retained for Code and GhostPepper; Arq selection and restore checks deferred. |
| [BetterDisplay Display Modes](plans/betterdisplay-display-modes-plan.md) | Proposed only; no `displayctl` implementation exists in this checkout. |
| [Decomment Skill](plans/decomment-skill-plan.md) | Active; decomment core skill, trigger-channel fixes, and evals under implementation. |
| [Justfile Migration](plans/justfile-migration-plan.md) | Accepted and executed; both Makefiles replaced by justfiles, per-file test targets deleted, and selection moved into the runners. See [ADR 0026](adr/0026-just-task-runner.md). |
| [Orcactl](plans/orcactl-plan.md) | Draft for a separate Go repo/tool; dotfiles integration is future install/skill wiring. |
| [Downstream Fork](plans/downstream-fork-plan.md) | Active; thin assembly-repo forks as daily drivers on the `prateek/forks` fleet monorepo — engine, three-job template, harness, security review, monorepo scaffold, and fleet digest done; dotfiles gardening landed bar the retoken; provisioning + ghost-pepper migration pending Prateek. |
| [Goku Karabiner Migration](plans/goku-karabiner-migration-plan.md) | Active; Karabiner config now compiles from `karabiner.edn` via goku — on-device pad verification pending. |
| [Leader Key to Tuna Migration](plans/leader-key-to-tuna-migration-plan.md) | Active; full cutover applied on the migrate-tuna branch (config at `~/.config/tuna`, F18→combo). Remaining: grant Tuna Accessibility, verify shell/URL binds. Leader Key kept as fallback. |
| [Raycast Config Automation](plans/raycast-config-automation-plan.md) | Proposed; deferred backlog of Raycast preference keys worth porting into the managed plist, plus what the encrypted extension store puts out of reach. |
| [Skill Management Console](plans/skill-management-console-plan.md) | Active; `skill-console` reproduces Claude Code's character-budgeted skill listing from live inputs, renders an HTML console over the repo's 142 skills plus third-party, user, and built-in rows, and applies exported decisions (description edits, frontmatter flags, vendored-skill deletion, package toggles, budget fraction) to the chezmoi source tree through a staged, validated, path-by-path commit. Phases 1-3 built; pi and Codex budget projection remains. |
| [Sudo Askpass 1Password](plans/sudo-askpass-1password-plan.md) | Accepted design; implementation pending, current code still uses sudo keepalive. |
| [Tartelet Self-Hosted Runners](plans/tartelet-runner-plan.md) | Active; cask, managed plist, LaunchAgent, host data, VM-image builder, and runbook landed. On-mini end-to-end (golden VM build + first-run credential paste) still to be exercised. |
| [Tartelet Runner Memory-Guard](plans/tartelet-runner-memory-guard-proposal.md) | Proposed; design for a circuit breaker that sheds the runner under host memory pressure after a 2026-07-03 jetsam wedge. Prototyped and validated, then dropped — no code in-tree. |
| [Using-git-spice Skill](plans/using-git-spice-skill-plan.md) | Active; the replacement skill and config are applied, the duplicate is disabled, and the Orca smoke passed. Only the disruptive manual logged-out auth check remains. |
| [Zsh Fresh-Shell Validator](plans/zsh-fresh-shell-validator-plan.md) | Active plan for shell correctness and startup checks. |

## Decision Records

Accepted ADRs explain why a decision was made. Use the current guidance above
for day-to-day implementation details.

| ADR | Current guidance |
| --- | --- |
| [ADR 0001 - Downstream fork repo architecture](adr/0001-downstream-fork-architecture.md) | Superseded by [ADR 0015](adr/0015-downstream-fork-daily-driver.md). |
| [ADR 0002 - Fresh-shell validator architecture](adr/0002-zsh-fresh-shell-validator.md) | `scripts/audit/zsh-fresh-shells.zsh` and [tests index](../tests/README.md). |
| [ADR 0003 - git-subrepo-managed `src/`](adr/0003-downstream-fork-subrepo.md) | Superseded by [ADR 0001](adr/0001-downstream-fork-architecture.md). |
| [ADR 0004 - Tart install validation and tracing](adr/0004-tart-install-validation-and-tracing.md) | [Tart Install Validation](runbooks/tart-mini-validation.md). |
| [ADR 0005 - Mise-managed tool selection](adr/0005-mise-tool-management.md) | [Mise Tool Management](references/mise-tool-management.md); its Codex Homebrew channel is superseded by [ADR 0027](adr/0027-codex-standalone-installer.md). |
| [ADR 0006 - Chezmoi migration target architecture](adr/0006-chezmoi-migration-prototype.md) | [Chezmoi Architecture](references/chezmoi-architecture.md). |
| [ADR 0007 - Default-loaded plugin policy](adr/0007-default-loaded-plugin-policy.md) | [Agent Skill Management](../.agents/skills/agent-skill-management/SKILL.md). |
| [ADR 0008 - Sudo askpass via 1Password](adr/0008-sudo-askpass-1password.md) | Current behavior remains [Jamf Self Service Elevation](references/jamf-self-service-elevation.md); accepted askpass design is tracked in [Sudo Askpass 1Password](plans/sudo-askpass-1password-plan.md). |
| [ADR 0009 - Karabiner config via Goku codegen](adr/0009-goku-karabiner-codegen.md) | [Goku Karabiner Migration](plans/goku-karabiner-migration-plan.md); edit `karabiner.edn`, never `karabiner.json`. |
| [ADR 0010 - Single machine_type axis for package selection](adr/0010-machine-type-package-selection.md) | [Chezmoi Architecture](references/chezmoi-architecture.md) > Packages And Tools. |
| [ADR 0011 - Private repo for config overlays](adr/0011-private-repo-config-overlays.md) | `prateek/dotfiles-private` cloned via gated `.chezmoiexternal`, composed by `run_after_37-agent-slack-doc`; first consumer `~/.agents/docs/slack.md`. |
| [ADR 0012 - Config-gating convention](adr/0012-config-gating-convention.md) | chezmoi toggle convention (render-time vs init-time), implemented as one identity prompt + a layered `machines.toml` resolved by `features.tmpl`. Current guidance: [Chezmoi Architecture](references/chezmoi-architecture.md) > Config Gating. |
| [ADR 0013 - Agent tool integrations stay APM-vendored](adr/0013-apm-vendored-tool-integrations.md) | [Agent Skill Management](../.agents/skills/agent-skill-management/SKILL.md). |
| [ADR 0014 - Tartelet self-hosted runners](adr/0014-tartelet-self-hosted-runners.md) | [Tartelet Self-Hosted Runners](plans/tartelet-runner-plan.md). |
| [ADR 0015 - Downstream forks as thin assembly repos](adr/0015-downstream-fork-daily-driver.md) | [Downstream Fork plan](plans/downstream-fork-plan.md) and the [`fork-lifecycle` skill](../.agents/skills/fork-lifecycle/SKILL.md) (fleet ops live in the `fork-ops` skill in `prateek/forks`). |
| [ADR 0016 - Vendored dependency content may land inside a local skill](adr/0016-vendor-into-skill-references.md) | Never implemented; superseded by [ADR 0028](adr/0028-router-skill-over-vendor-remap.md). |
| [ADR 0017 - Cross-machine agent-session archive](adr/0017-agent-session-archive.md) | [Agent Session Wiki plan](plans/agent-session-wiki-plan.md) and the `agent-session-wiki` operator skill (utils-agent package). |
| [ADR 0018 - Sparse, blobless archive clones on work machines](adr/0018-sparse-work-archive-clones.md) | `agent_session_wiki_sparse` in `machines.toml`, reconciled by `scripts/agent-sessions/reconcile-wiki-clone`; the ingest host stays a full clone. |
| [ADR 0019 - Plugin hooks ship in the vendored plugin payload](adr/0019-plugin-hooks-in-vendored-payload.md) | [Agent Skill Management](../.agents/skills/agent-skill-management/SKILL.md); first consumers are the superpowers package and crit's plan-review hook. |
| [ADR 0020 - chezmoi apply reconciles plugin install records](adr/0020-apply-reconciles-plugin-installs.md) | `reconcile-agent-plugins --apply`, run by `run_onchange_after_36-agent-plugins`; see [Plugin Reconcile](../.agents/skills/agent-skill-management/references/plugin-reconcile.md). |
| [ADR 0021 - Shared plist verification](adr/0021-shared-plist-verification.md) | [Tests index](../tests/README.md#plist-merge-verification) and [Chezmoi Architecture](references/chezmoi-architecture.md). |
| [ADR 0022 - Bats with repo-owned zsh test support](adr/0022-bats-and-zsh-test-support.md) | [Test Refactoring](plans/test-suite-rebuild-plan.md); implemented and validated locally and in remote CI. |
| [ADR 0023 - Isolate marketplace packaging and commit APM module inputs](adr/0023-apm-agent-marketplace-packaging.md) | Accepted; [APM Agent Marketplace plan](plans/apm-agent-marketplace-plan.md). Current operations are in the [marketplace reference](references/agent-marketplace.md) and [management skill](../.agents/skills/agent-skill-management/SKILL.md). |
| [ADR 0024 - Setapp subscription apps install from packages.toml](adr/0024-setapp-subscription-app-installs.md) | `setapp_apps` groups in `packages.toml`, rendered by `scripts/packages/render-setapp-applist` and installed by `run_after_22-setapp-apps` via Setapp's store API. |
| [ADR 0025 - Share APM acquisition across native plugins](adr/0025-shared-apm-acquisition.md) | One root manifest, lock, and committed cache; per-plugin native metadata remains. See the [marketplace reference](references/agent-marketplace.md). |
| [ADR 0026 - just as the task runner](adr/0026-just-task-runner.md) | Accepted; [justfile migration plan](plans/justfile-migration-plan.md). Both Makefiles replaced and per-file test targets deleted; selection moves to the runners. See the [tests index](../tests/README.md). |
| [ADR 0027 - Codex CLI installs standalone](adr/0027-codex-standalone-installer.md) | Accepted; `run_after_07-codex-standalone.sh` installs the CLI through OpenAI's installer and `[packages.retired]` drops the cask, because `/agents` and the app-server daemon need the standalone layout. See [Mise Tool Management](references/mise-tool-management.md) > Codex workflow. |
| [ADR 0028 - Sibling router skill over vendored remap](adr/0028-router-skill-over-vendor-remap.md) | Accepted; when local conventions and a vendored skill share a subject, publish both as siblings in one package and split the trigger between their descriptions. First customer: the `acpx` / `acpx-cli` pair ([plan](plans/acpx-skill-packaging-plan.md)). |

## Research

| Doc | Use it for |
| --- | --- |
| [Shell Testing Framework Comparison](research/shell-testing-framework-comparison.md) | Alternatives, decision history, and experiment/upstream evidence supporting the [Test Refactoring plan](plans/test-suite-rebuild-plan.md). |
| [Agent Skill Management Research](research/agent-skill-management-research.md) | Background on skill context pressure, package layout, and plugin defaults. |
| [Public Dotfiles Skill Packaging](research/public-dotfiles-skills-packaging-research.md) | Eight public examples of skill source ownership, installation, and updates, with pinned source links and a comparison to this repo. |
| [Nix Agent Skill Packaging](research/nix-agent-skills-packaging-research.md) | Five public Nix configurations, Home Manager skill and plugin options, source catalogs, dependency packaging, and deployment ownership. |
| [Agent Marketplace Packaging Tools](research/agent-marketplace-packaging-tools-research.md) | Packaging tools and reusable compilers for reviewed local skill sources, separate plugins, and Claude/Codex marketplace output. |
| [APM Skill Marketplace Spike](research/apm-skill-marketplace-spike.md) | Executed APM source publication, native Claude/Codex inventory parity, offline updates, bundle limitations, and the Mise setup incident. |
| [APM Migration Verification](research/apm-marketplace-migration-verification.md) | Executed acquisition, source transport, native recovery, changed-source plain apply, fresh skill invocation, authored/imported edit and restore, and legacy backup review. |
| [APM Module Vendoring](research/apm-modules-vendoring-research.md) | Pinned source findings for committing APM caches, native lock-only acquisition, local patches, Git round-trip checks, and deferred registry/mirror options. |
| [Skill Invocation-Control Frontmatter](research/skill-invocation-frontmatter-research.md) | Which harnesses honor `disable-model-invocation` and `user-invocable`, with per-harness evidence and citations. |
| [Self-Improving Agents](research/self-improving-agents.md) | Pattern reference for durable agent feedback loops. |
| [macOS Defaults: Sources And Verified Facts](research/macos-defaults-sources.md) | Sources to mine for the next rework of the macOS defaults layer, plus key encodings and Apple Silicon power facts verified on hardware. |
| [acpx Rewrite Model Bake-Off](research/acpx-rewrite-model-bakeoff.md) | Why `agptw` pins `gpt-5.6-luna-high`, with the scoring method and repro steps for re-picking the prose-rewrite model. |
| [Nix Migration Research](research/nix-migration-research.md) | Why the repo stays on chezmoi, what a package-only nix spike would look like, and the work-Mac MDM check that gates nix-darwin. |

## Historical Records

These documents are retained for archaeology. Follow their `current_guidance`
or `superseded_by` frontmatter before using them.

| Doc | Current guidance |
| --- | --- |
| [acpx Claude Code Streaming PoC](plans/acpx-claude-streaming-poc-plan.md) | Completed; the relay loop it proved now lives in the acpx skill's [harness lanes](../agent-marketplace/packages/utils-agent/skills/acpx/references/harness-lanes.md), and the packaging follow-up went to [ADR 0028](adr/0028-router-skill-over-vendor-remap.md). |
| [Portable land-changes](plans/portable-land-changes-plan.md) | Review plugin's [published skill source](../agent-marketplace/packages/review/skills/land-changes/SKILL.md) and [dotfiles landing](runbooks/dotfiles-landing.md). |
| [APM Agent Marketplace](plans/apm-agent-marketplace-plan.md) | Completed shared acquisition, just-based apply, native skill invocation, maintenance round trip, and CI verification. Use the [marketplace reference](references/agent-marketplace.md); see the [rollout evidence](research/apm-marketplace-migration-verification.md#rollout-completion). |
| [Agent Plugin Renderer](plans/agent-plugin-renderer-plan.md) | Replaced by [APM Agent Marketplace](plans/apm-agent-marketplace-plan.md); [current guidance](references/agent-marketplace.md). |
| [Test Refactoring](plans/test-suite-rebuild-plan.md) | Completed Bats/native runner migration, local and remote CI validation, and scoped apply; [tests index](../tests/README.md) and [ADR 0022](adr/0022-bats-and-zsh-test-support.md). |
| [Shared Config-Merge Verification](plans/config-merge-verification-plan.md) | Completed local implementation and validation; [tests index](../tests/README.md#plist-merge-verification) and [ADR 0021](adr/0021-shared-plist-verification.md). |
| [Chezmoi Agent Skills Plan](plans/chezmoi-agent-skills-plan.md) | [Agent Skill Management](../.agents/skills/agent-skill-management/SKILL.md) and [ADR 0007](adr/0007-default-loaded-plugin-policy.md). |
| [Chezmoi Drift Banner Plan](plans/chezmoi-drift-banner-plan.md) | [Chezmoi Drift Banner](../home/dot_config/dotfiles/chezmoi-drift/README.md). |
| [Chezmoi Migration Plan](plans/chezmoi-migration-plan.md) | [Chezmoi Architecture](references/chezmoi-architecture.md). |
| [Crit Agent Bridge](plans/crit-agent-bridge-plan.md) | Retired; crit's `agent_cmd` now runs full-access claude directly (`home/modify_private_dot_crit.config.json.tmpl`), and the acpx shortcuts remain for general use. |
| [Crit Integration](plans/crit-integration-plan.md) | Live repo state ([Agent Skill Management](../.agents/skills/agent-skill-management/SKILL.md)); the superseding plannotator experiment was reverted. |
| [Plannotator Experiment](plans/plannotator-experiment-plan.md) | [Crit Integration](plans/crit-integration-plan.md) setup restored; reverted 2026-08-25, reland from history if retried. |
| [Config-Gating Simplification](plans/config-gating-simplification-plan.md) | [ADR 0012](adr/0012-config-gating-convention.md) and [Chezmoi Architecture](references/chezmoi-architecture.md). |
| [Machine-Type Package Selection](plans/machine-type-package-selection-plan.md) | [ADR 0010](adr/0010-machine-type-package-selection.md) and [Chezmoi Architecture](references/chezmoi-architecture.md). |
| [Linux Work DevPod Orca Pilot](plans/linux-work-devpod-orca-pilot-plan.md) | Reverted before final cold-start acceptance; no Linux profile is active. |
| [Linux Work DevPod And Orca](runbooks/linux-work-devpod-orca.md) | Historical operating procedure for the reverted pilot. |
| [Docs Reorg And Agent-Surface Refresh](plans/docs-reorg-plan.md) | `AGENTS.md`, [Documentation Index](index.md), and [Document Lifecycle](document-lifecycle.md). |
| [GRM Repo](references/grmrepo.md) | [Git Conventions](../home/dot_agents/docs/git.md) for the `gh`/clone workflow; repos are cloned with `ghc`/`gh`. |
| [Setup Downstream Fork Plan](plans/setup-downstream-fork-plan.md) | [ADR 0015](adr/0015-downstream-fork-daily-driver.md) and the [`fork-lifecycle` skill](../.agents/skills/fork-lifecycle/SKILL.md). |
| [Setup Downstream Fork Secrets](plans/setup-downstream-fork-secrets-plan.md) | [ADR 0015](adr/0015-downstream-fork-daily-driver.md); credentials now flow through a 1Password service account. |
| [Worktree Convention Cleanup](plans/worktree-convention-cleanup-plan.md) | [Worktrees](../home/dot_agents/docs/worktrees.md) and [Git Conventions](../home/dot_agents/docs/git.md) for the Orca worktree workflow; worktrunk and the custom `grm` integration were removed. |
