---
status: current
doc_type: runbook
created: 2026-09-07
updated: 2026-09-22
related:
  - ../../agent-marketplace/packages/review/skills/land-changes/SKILL.md
  - ../../.agents/skills/agent-skill-management/SKILL.md
---

# Dotfiles landing

Use the published [land-changes skill](../../agent-marketplace/packages/review/skills/land-changes/SKILL.md).
Dotfiles normally lands one commit directly onto `origin/master`; the canonical
checkout is `~/dotfiles`. Verify its branch and local state before synchronization.
Inspect live hosting rules and the actual caller's capabilities. Direct landing
can require an explicitly authorized bypass; a history waiver does not supply it.
Task-specific workflows such as fork adoption can select a PR instead.

## Checks for the diff

Read [the tests index](../../tests/README.md#checks-by-changed-area) for applicable
checks. The `justfile`, effective hooks, and `.github/workflows/` define the current
commands and triggers. Use those native names as choices; the user may select,
skip, or bypass individual actions/gates through the skill. Preserve the distinction
between skipping a local check and satisfying or bypassing a server requirement.

By default run whitespace validation against the committed diff, and `shellcheck -x`
for changed shell scripts where appropriate. For changed `home/` files, run
`just test-chezmoi-apply` from the worktree. For marketplace inputs or adapters,
use [agent-skill-management](../../.agents/skills/agent-skill-management/SKILL.md)
to select package, consumer, and config checks. Marketplace-only changes can alter
rendered scripts even without changing a `home/` source file.

## Follow-up effects

A bare landing selects no manual apply. Choose an effect by this runbook name or
equivalent natural language. Each selected effect records the instruction/saved
choice that covers its host, source revision, and scope.

| Name | Effect and completion evidence |
| --- | --- |
| `preview` | Read-only post-landing `chezmoi diff`, including scripts for marketplace changes; report which pending effects belong to the landed change. Default inspection, not apply authorization. |
| `apply-landed` | Apply only the authorized effects of the landed change on the named host. Verify directly managed entries and any separately affected runtime state. |
| `apply-full` | Full `chezmoi apply` on the named host after reviewing all pending effects, including unrelated drift covered by this explicit scope. |
| `activate-plugins` | Materialize/reconcile the landed marketplace and verify artifact receipt, native plugin version, and enabled state. A managed-file diff alone is insufficient. |

Before preview, confirm `chezmoi source-path` resolves to `~/dotfiles/home`.
Surface a mismatch rather than changing the source silently. Map pending effects
to the landed diff and report unrelated drift separately. For marketplace changes,
inspect `chezmoi diff --include=scripts` and the relevant rendered scripts.
Script-created `~/.agents/plugins` has no direct chezmoi source mapping.

Before applying, verify the source checkout is clean and at the verified revision.
Use `chezmoi diff` and the scoped dry-run from
[materialization](../../.agents/skills/agent-skill-management/references/generated-outputs.md)
when plugin effects are selected. Resolve any expansion beyond the selected scope
before execution. A command scoped to a target can still run broader hooks.
If a local sync failed, resolve the source revision before using that checkout.

Use `chezmoi verify` for directly managed entries. For plugins, follow
[reconciliation](../../.agents/skills/agent-skill-management/references/plugin-reconcile.md)
and inspect native state; successful apply alone does not prove activation.
Resume an unfinished authorized effect without republishing. A completed apply
for one change does not authorize an apply for the next. Report publication,
preview, apply, and activation independently. Leave worktree cleanup to Orca.
