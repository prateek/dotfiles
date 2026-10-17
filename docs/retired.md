---
status: current
doc_type: index
summary: "Append-only record of every retired document: what it was, when it closed, and where its durable content went."
created: 2026-10-17
related:
  - document-lifecycle.md
  - inventory.md
---

# Retirement Ledger

A retired document is a closed document whose file has left the tree. This
ledger is the only in-tree record that it existed. Rows are append-only: the
validator refuses a change that edits or removes one, and a path listed here
cannot come back; revived work gets a new file that links this ledger.

To read a retired document, use git:

```sh
git log --diff-filter=D --oneline -- docs/<path>
git show <commit>^:docs/<path>
```

Add a row in the same change that deletes the file. `Where it went` names the
reference, runbook, ADR, or skill that now holds anything durable, or says
there was nothing to keep. Links in that column may point at paths that have
since retired themselves.

| Closed | Path | Doc | Status | Where it went |
| --- | --- | --- | --- | --- |
| 2026-09-08 | plans/acpx-claude-streaming-poc-plan.md | acpx Claude Code Streaming PoC Plan | archived | [agent-marketplace/packages/utils-agent/skills/acpx/references/harness-lanes.md](../agent-marketplace/packages/utils-agent/skills/acpx/references/harness-lanes.md) |
| 2026-10-05 | plans/acpx-explicit-profiles-plan.md | ACPX explicit profiles | archived | [references/acpx-routing.md](references/acpx-routing.md) |
| 2026-09-26 | plans/acpx-native-skill-rewrite-plan.md | Native acpx skill rewrite flows | archived | [runbooks/acpx-skill-rewrite.md](runbooks/acpx-skill-rewrite.md) |
| 2026-10-05 | plans/acpx-routing-plan.md | acpx model routing | superseded | [references/acpx-routing.md](references/acpx-routing.md) |
| 2026-10-17 | plans/acpx-skill-packaging-plan.md | acpx Skill Packaging Plan | archived | [adr/0028-router-skill-over-vendor-remap.md](adr/0028-router-skill-over-vendor-remap.md), [agent-marketplace/packages/utils-agent/skills/acpx/SKILL.md](../agent-marketplace/packages/utils-agent/skills/acpx/SKILL.md) |
| 2026-09-26 | plans/acpx-skill-rewrite-plan.md | Authored skill rewrite flow | archived | [runbooks/acpx-skill-rewrite.md](runbooks/acpx-skill-rewrite.md) |
| 2026-10-12 | plans/additional-upstream-agent-plugins-plan.md | Additional maintainer marketplace plugins | archived | [references/agent-marketplace.md](references/agent-marketplace.md) |
| 2026-09-07 | plans/agent-plugin-renderer-plan.md | Agent Plugin Renderer Plan | superseded | [references/agent-marketplace.md](references/agent-marketplace.md), [agent-marketplace/README.md](../agent-marketplace/README.md), [.agents/skills/agent-skill-management/SKILL.md](../.agents/skills/agent-skill-management/SKILL.md) |
| 2026-09-07 | plans/apm-agent-marketplace-plan.md | APM Agent Marketplace Plan | archived | [references/agent-marketplace.md](references/agent-marketplace.md), [agent-marketplace/README.md](../agent-marketplace/README.md), [.agents/skills/agent-skill-management/SKILL.md](../.agents/skills/agent-skill-management/SKILL.md) |
| 2026-05-15 | plans/chezmoi-agent-skills-plan.md | Chezmoi Agent Skills Plan | archived | [.agents/skills/agent-skill-management/SKILL.md](../.agents/skills/agent-skill-management/SKILL.md), [adr/0007-default-loaded-plugin-policy.md](adr/0007-default-loaded-plugin-policy.md) |
| 2026-05-15 | plans/chezmoi-drift-banner-plan.md | Chezmoi Drift Banner Plan | archived | [plans/shell-banner-plan.md](plans/shell-banner-plan.md), [home/dot_config/dotfiles/shell-banner/README.md](../home/dot_config/dotfiles/shell-banner/README.md) |
| 2026-05-15 | plans/chezmoi-migration-plan.md | Chezmoi Migration Plan | archived | [references/chezmoi-architecture.md](references/chezmoi-architecture.md) |
| 2026-06-29 | plans/config-gating-simplification-plan.md | Config-Gating Simplification Plan | superseded | [adr/0012-config-gating-convention.md](adr/0012-config-gating-convention.md), [references/chezmoi-architecture.md](references/chezmoi-architecture.md) |
| 2026-09-05 | plans/config-merge-verification-plan.md | Shared Config-Merge Verification Plan | archived | [tests/README.md](../tests/README.md), [references/chezmoi-architecture.md](references/chezmoi-architecture.md) |
| 2026-08-26 | plans/crit-agent-bridge-plan.md | Crit Agent Bridge Plan | archived | [.agents/skills/agent-skill-management/SKILL.md](../.agents/skills/agent-skill-management/SKILL.md) |
| 2026-08-25 | plans/crit-integration-plan.md | Crit Integration Plan | superseded | [.agents/skills/agent-skill-management/SKILL.md](../.agents/skills/agent-skill-management/SKILL.md) |
| 2026-05-12 | plans/docs-reorg-plan.md | Docs Reorg And Agent-Surface Refresh Plan | archived | [index.md](index.md), [document-lifecycle.md](document-lifecycle.md), [AGENTS.md](../AGENTS.md), [agent-marketplace/packages/core/skills/code-gardening/SKILL.md](../agent-marketplace/packages/core/skills/code-gardening/SKILL.md) |
| 2026-10-12 | plans/dotpkgs-surface-plan.md | Dotpkgs command surface repair | archived | [references/dotpkgs.md](references/dotpkgs.md) |
| 2026-10-11 | plans/g95nc-complete-modes-plan.md | Complete G95NC Modes | archived | [runbooks/g95nc-display.md](runbooks/g95nc-display.md) |
| 2026-10-03 | plans/g95nc-diagnostics-plan.md | G95NC Preconditions and Diagnostics | archived | [runbooks/g95nc-display.md](runbooks/g95nc-display.md) |
| 2026-09-26 | plans/jev-browser-runner-plan.md | Jev execution inside the browser skill | archived | [agent-marketplace/packages/experimental/skills/browser-jev/references/jev.md](../agent-marketplace/packages/experimental/skills/browser-jev/references/jev.md), [adr/0050-suspend-jev-in-experimental-plugin.md](adr/0050-suspend-jev-in-experimental-plugin.md) |
| 2026-10-16 | plans/jev-deterministic-preparation-plan.md | Remove parent-authored Jev browser manifests | archived | [adr/0050-suspend-jev-in-experimental-plugin.md](adr/0050-suspend-jev-in-experimental-plugin.md) |
| 2026-10-17 | plans/justfile-migration-plan.md | Replace both Makefiles with justfiles and delete the per-file test targets | archived | [adr/0026-just-task-runner.md](adr/0026-just-task-runner.md), [tests/README.md](../tests/README.md) |
| 2026-09-22 | plans/land-changes-workflow-plan.md | Discovered landing workflows | archived | [agent-marketplace/packages/review/skills/land-changes/SKILL.md](../agent-marketplace/packages/review/skills/land-changes/SKILL.md), [runbooks/dotfiles-landing.md](runbooks/dotfiles-landing.md) |
| 2026-10-05 | plans/leader-key-to-tuna-migration-plan.md | Leader Key to Tuna Migration Plan | archived | [home/dot_config/tuna/config.toml](../home/dot_config/tuna/config.toml), [home/dot_config/karabiner.edn.tmpl](../home/dot_config/karabiner.edn.tmpl) |
| 2026-09-04 | plans/linux-work-devpod-orca-pilot-plan.md | Linux work DevPod Orca pilot | archived | [references/chezmoi-architecture.md](references/chezmoi-architecture.md) |
| 2026-06-29 | plans/machine-type-package-selection-plan.md | Machine-type package selection plan | archived | [references/chezmoi-architecture.md](references/chezmoi-architecture.md) |
| 2026-10-12 | plans/package-helper-plan.md | Package helper | archived | [references/dotpkgs.md](references/dotpkgs.md) |
| 2026-10-17 | plans/periodic-session-review-plan.md | Periodic session review — plan | superseded | [runbooks/quarterly-review.md](runbooks/quarterly-review.md) |
| 2026-10-05 | plans/permissions-ui-prototype-brief.md | Permissions utility: comparative prototype brief | superseded | [plans/permissions-hybrid-ui-plan.md](plans/permissions-hybrid-ui-plan.md) |
| 2026-08-25 | plans/plannotator-experiment-plan.md | Plannotator Experiment Plan | archived | [.agents/skills/agent-skill-management/SKILL.md](../.agents/skills/agent-skill-management/SKILL.md) |
| 2026-09-07 | plans/portable-land-changes-plan.md | Portable land-changes | archived | [agent-marketplace/packages/review/skills/land-changes/SKILL.md](../agent-marketplace/packages/review/skills/land-changes/SKILL.md), [runbooks/dotfiles-landing.md](runbooks/dotfiles-landing.md) |
| 2026-05-15 | plans/setup-downstream-fork-plan.md | setup-downstream-fork — plan | archived | [adr/0015-downstream-fork-daily-driver.md](adr/0015-downstream-fork-daily-driver.md), [.agents/skills/fork-lifecycle/SKILL.md](../.agents/skills/fork-lifecycle/SKILL.md) |
| 2026-07-03 | plans/setup-downstream-fork-secrets-plan.md | setup-downstream-fork — pluggable secret resolver | superseded | [adr/0015-downstream-fork-daily-driver.md](adr/0015-downstream-fork-daily-driver.md), [.agents/skills/fork-lifecycle/SKILL.md](../.agents/skills/fork-lifecycle/SKILL.md) |
| 2026-09-06 | plans/test-suite-rebuild-plan.md | Test refactoring plan | archived | [tests/README.md](../tests/README.md) |
| 2026-10-12 | plans/upstream-agent-plugins-plan.md | Use upstream agent plugins | archived | [references/agent-marketplace.md](references/agent-marketplace.md) |
| 2026-10-17 | plans/wiki-ingest-revisit-plan.md | Restore wiki ingestion | archived | [plans/agent-session-wiki-plan.md](plans/agent-session-wiki-plan.md) |
| 2026-06-30 | plans/worktree-convention-cleanup-plan.md | Worktree Convention Cleanup Plan | archived | [home/dot_agents/docs/worktrees.md](../home/dot_agents/docs/worktrees.md) |
| 2026-06-29 | references/grmrepo.md | GRM (git-repo-manager) on this machine | archived | [home/dot_agents/docs/git.md](../home/dot_agents/docs/git.md) |
| 2026-09-22 | research/acpx-rewrite-model-bakeoff.md | Which Model Should Do acpx Prose Rewrites | superseded | [references/acpx-routing.md](references/acpx-routing.md) |
| 2026-10-17 | research/agent-skill-collection-audit.md | Remaining agent skill collections | archived | [adr/0049-official-agent-plugin-marketplaces.md](adr/0049-official-agent-plugin-marketplaces.md) |
| 2026-10-17 | research/agent-skill-management-research.md | Agent Skill Management Research | archived | [adr/0007-default-loaded-plugin-policy.md](adr/0007-default-loaded-plugin-policy.md), [references/agent-marketplace.md](references/agent-marketplace.md) |
| 2026-10-17 | research/apm-marketplace-migration-verification.md | APM Marketplace Migration Verification | archived | [adr/0023-apm-agent-marketplace-packaging.md](adr/0023-apm-agent-marketplace-packaging.md), [adr/0025-shared-apm-acquisition.md](adr/0025-shared-apm-acquisition.md), [references/agent-marketplace.md](references/agent-marketplace.md) |
| 2026-10-17 | research/apm-modules-vendoring-research.md | Committing APM Modules as Reviewed Source | archived | [adr/0023-apm-agent-marketplace-packaging.md](adr/0023-apm-agent-marketplace-packaging.md), [adr/0025-shared-apm-acquisition.md](adr/0025-shared-apm-acquisition.md) |
| 2026-10-17 | research/apm-skill-marketplace-spike.md | APM Skill Marketplace Spike | archived | [adr/0023-apm-agent-marketplace-packaging.md](adr/0023-apm-agent-marketplace-packaging.md) |
| 2026-10-17 | research/documentation-maintenance-review.md | Documentation maintenance and retention review | archived | [adr/0052-retire-closed-docs-through-a-ledger.md](adr/0052-retire-closed-docs-through-a-ledger.md) |
| 2026-10-16 | research/jev-browser-integrations.md | Jev browser integrations | archived | [adr/0050-suspend-jev-in-experimental-plugin.md](adr/0050-suspend-jev-in-experimental-plugin.md) |
| 2026-10-17 | research/macos-defaults-sources.md | macOS Defaults: Sources And Verified Facts | archived | [home/.chezmoitemplates/macos-defaults.sh.tmpl](../home/.chezmoitemplates/macos-defaults.sh.tmpl) |
| 2026-10-17 | research/self-improving-agents.md | Self-Improving Agents | archived | [index.md](index.md), [document-lifecycle.md](document-lifecycle.md), [AGENTS.md](../AGENTS.md), [agent-marketplace/packages/core/skills/code-gardening/SKILL.md](../agent-marketplace/packages/core/skills/code-gardening/SKILL.md) |
| 2026-10-17 | research/shell-testing-framework-comparison.md | Shell testing framework comparison | archived | [adr/0022-bats-and-zsh-test-support.md](adr/0022-bats-and-zsh-test-support.md), [tests/README.md](../tests/README.md) |
| 2026-10-17 | research/skill-pack-doc-lifecycles.md | Document Lifecycles in Three Agent Skill Packs | archived | [adr/0052-retire-closed-docs-through-a-ledger.md](adr/0052-retire-closed-docs-through-a-ledger.md) |
| 2026-09-04 | runbooks/linux-work-devpod-orca.md | Linux work DevPod and Orca | archived | [references/chezmoi-architecture.md](references/chezmoi-architecture.md) |
| 2026-10-17 | plans/downstream-fork-plan.md | downstream-fork: daily-driver forks | archived | [adr/0015-downstream-fork-daily-driver.md](adr/0015-downstream-fork-daily-driver.md), [.agents/skills/fork-lifecycle/SKILL.md](../.agents/skills/fork-lifecycle/SKILL.md) |
| 2026-10-17 | plans/sudo-askpass-1password-plan.md | Sudo Askpass via 1Password Plan | rejected | [adr/0053-touchid-and-jamf-replace-askpass.md](adr/0053-touchid-and-jamf-replace-askpass.md), [references/jamf-self-service-elevation.md](references/jamf-self-service-elevation.md) |
| 2026-10-17 | plans/tartelet-runner-plan.md | Tartelet Self-Hosted Runner Plan | archived | [adr/0014-tartelet-self-hosted-runners.md](adr/0014-tartelet-self-hosted-runners.md), [runbooks/tartelet-runner-setup.md](runbooks/tartelet-runner-setup.md) |
| 2026-10-17 | plans/zsh-fresh-shell-validator-plan.md | zsh-fresh-shell-validator — plan | archived | [adr/0002-zsh-fresh-shell-validator.md](adr/0002-zsh-fresh-shell-validator.md), [tests/README.md](../tests/README.md), [scripts/audit/zsh-fresh-shells.zsh](../scripts/audit/zsh-fresh-shells.zsh) |
