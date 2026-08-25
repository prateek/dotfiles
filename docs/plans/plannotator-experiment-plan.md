---
status: archived
doc_type: plan
owner: Prateek
created: 2026-08-25
updated: 2026-08-25
closed: 2026-08-25
current_guidance: ./crit-integration-plan.md
related:
  - ../adr/0013-apm-vendored-tool-integrations.md
  - ./crit-integration-plan.md
status_detail: "Landed (5dc1a89) and reverted the same day after a plugin load error surfaced on live reload; the crit review loop is live again. Reland from the reverted commit if retried."
---

# Plannotator Experiment Plan

Experimentally replace the crit review loop with
[Plannotator](https://github.com/backnotprop/plannotator): browser-based plan
review on `ExitPlanMode`, code review via `plannotator review`, and document
annotation, plus the
[effective-html](https://github.com/plannotator/effective-html) visual-artifact
skills. Supersedes the crit integration
([crit-integration-plan](./crit-integration-plan.md)) while the experiment
runs; crit's binary stays installed so the setup can be restored wholesale.

## Changes

1. **Binary via mise.** `github:backnotprop/plannotator` pinned to the
   reviewed release in `home/dot_config/mise/conf.d/clis.toml` (checksum +
   GitHub attestation verified by the backend). Bump the pin only together
   with a `vendor-agent-package review` re-vendor so binary and skills move
   in lockstep. `[env]` pins
   `PLANNOTATOR_DATA_DIR=$XDG_DATA_HOME/plannotator` (one env-less run would
   otherwise create `~/.plannotator` and that location sticks) and
   `PLANNOTATOR_SHARE=disabled` (no plan/review uploads to share links or the
   paste service).
2. **Plan-review hook.** `claude-settings-managed.json.tmpl` owns the
   `PermissionRequest`/`ExitPlanMode` slot with `plannotator`, plus
   `PreToolUse`/`EnterPlanMode` → `plannotator improve-context` (mirrors the
   upstream Claude plugin's hooks.json; the plugin itself is not installed —
   hooks ship via managed settings per ADR 0013).
   `tests/claude-settings-modify.zsh` asserts both matchers and that foreign
   matchers survive the merge.
3. **Command skills in the review package.** `review/apm.yml` swaps the crit
   skill deps for APM virtual-path deps on
   `backnotprop/plannotator/apps/skills/core/{plannotator,plannotator-annotate,plannotator-last,plannotator-review}`,
   vendored at the commit matching the installed binary release. Re-vendor on
   binary bumps; upstream's plannotator-skill-reference test keeps the
   reference skill in lockstep with the CLI surface.
4. **effective-html package.** New default-loaded `effective-html` package,
   APM-vendored from `plannotator/effective-html` (MIT): `html`,
   `design-artifact`, `html-wireframe`, `html-prototype`, `html-plan`,
   `html-diagram`.

## Rollout

- Land, `chezmoi apply` (installs binary, merges hooks, renders plugins),
  then reconcile: `claude plugin install/enable effective-html@prateek-local`
  and `codex plugin add effective-html@prateek-local`; restart agent
  sessions.
- Smoke: exit plan mode → browser review; `/plannotator-review` on a diff;
  `/plannotator-annotate` on a doc; confirm data lands under
  `~/.local/share/plannotator` and share UI is disabled.

## Exit criteria

- **Adopt:** retire the crit binary, `CRIT_NO_INTEGRATION_CHECK`, crit config
  modify script, and the crit-agent-bridge plan; record the decision (ADR if
  the review-tool contract changes).
- **Abort:** revert this branch's commits — the crit plan-hook line in the
  managed template and the crit deps in `review/apm.yml` restore the previous
  loop — and move [crit-integration-plan](./crit-integration-plan.md) back to
  `active`.

## Deferred

- Upstream `extra/` skills (`plannotator-compound`, `plannotator-setup-goal`,
  `plannotator-visual-explainer`).
- Codex `Stop`-hook plan review (upstream-experimental) and the pi extension
  (`pi install npm:@plannotator/pi-extension`); the vendored skills already
  render into the Codex and pi plugin projections.
