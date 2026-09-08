---
status: current
doc_type: runbook
created: 2026-09-07
updated: 2026-09-07
related:
  - ../../agent-marketplace/packages/review/skills/land-changes/SKILL.md
  - ../../.agents/skills/agent-skill-management/SKILL.md
---

# Dotfiles landing

Use the published [land-changes skill](../../agent-marketplace/packages/review/skills/land-changes/SKILL.md)
for the Git procedure and review-history gate. Dotfiles normally lands one
commit directly onto `origin/master`; the canonical checkout is `~/dotfiles`.
Resolve and verify that checkout by its branch, including clean status, before
landing. Use the skill's effective review options and inspect live hosting rules.
Some task-specific workflows, such as fork adoption, request a PR instead.

The skill's `--deploy=true` (or an explicit saved default) selects the chezmoi
apply procedure below after landing. `--deploy=false` keeps the preview only.
The generic history waiver does not authorize a GitHub protection bypass.

## Checks for the diff

Apply the skill's effective `tests` mode to test-suite commands below. With
`tests=skip`, retain non-test checks and the post-landing preview, and report the
omitted suites. The option does not disable Git hooks or required CI.

Read [the tests index](../../tests/README.md#checks-by-changed-area) for the
affected paths and execution lanes. The `justfile` and `.github/workflows/`
are executable truth. Run whitespace validation against the committed landing
diff, and `shellcheck -x` for changed shell scripts where appropriate.

For changed `home/` files, run `just test-chezmoi-apply` from the worktree.
For marketplace inputs or plugin adapters, use
[agent-skill-management](../../.agents/skills/agent-skill-management/SKILL.md)
to select package, consumer, and config checks. Marketplace-only changes can
change rendered chezmoi scripts without changing any `home/` source file.

## After landing

Confirm `chezmoi source-path` resolves to `~/dotfiles/home` before previewing
the apply. If it points elsewhere, surface the mismatch; do not silently change
the source. Run `chezmoi diff`, map pending effects to the landed source diff,
and identify unrelated drift separately.

For marketplace inputs or plugin adapters, also inspect
`chezmoi diff --include=scripts` and the relevant rendered scripts. Script 36
can change after a marketplace-only edit; script 35 owns runtime-root maintenance.
Map those effects to the materialized marketplace and native client state.
`~/.agents/plugins` is script-created output with no direct chezmoi source mapping.

Apply when requested, including through effective `deploy=true`, from `~/dotfiles`.
Verify the checkout is clean and at the landed commit, review pending effects,
and use `chezmoi apply` within the agreed scope. Resolve unrelated drift that
would expand the apply before executing it. Use `chezmoi verify` for directly
managed entries. For plugin changes, follow agent-skill-management's scoped
materialization/reconciliation and artifact/native-state checks. A clean file
diff or successful `chezmoi verify` does not establish plugin convergence.

Report the pending apply and whether it ran. Leave worktree cleanup to Orca.
