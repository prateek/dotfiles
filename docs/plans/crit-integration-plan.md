---
status: active
doc_type: plan
owner: Prateek
created: 2026-07-02
updated: 2026-07-02
related:
  - ../adr/0013-apm-vendored-tool-integrations.md
  - ../plans/agent-plugin-renderer-plan.md
status_detail: "Implementation landed on prateek/debug-crit-triggers; remaining: live rollout smoke and the upstream description PR."
---

# Crit Integration Plan

Bring the crit review-loop integration back in sync with how it is actually
used: vendor the Claude Code variant of crit's skills, ship the plan-review
hook through managed Claude settings, and keep the binary and skills upgraded
together.

## Evidence

An agentsview audit of 52 sessions / 552 crit invocations (May 13 – Jul 2,
2026) found:

- Usage is 100% Claude-side; the vendored skills were crit's Codex variant,
  frozen seven weeks stale.
- Agents overrode the vendored guidance where it fought the harness: ~40% of
  launches were backgrounded despite a foreground-blocking instruction (the
  Bash tool's 10-minute cap killed one foreground `crit --range` review), and
  `--author 'Claude'` was improvised 214 times against the skill's
  `--author 'Codex'`.
- Auto-triggering was the weak link: 33 sessions entered via explicit
  `/review:crit`, 8 by autonomous skill selection, 11 with no skill loaded.
- Upstream had already fixed most of this in its claude-code integration
  (background launch, `crit comments`, stdout-driven protocol) but dropped the
  description's "Use when ..." trigger clause that autonomous selection needs.

## Changes

1. **Re-vendor to the claude-code variant.** `review/apm.yml` deps point at
   `integrations/claude-code/skills/{crit,crit-cli}`; lock and vendor tree at
   upstream `ea3e089`. One local delta: the skill description keeps the
   trigger clause, recorded in SOURCE.md and pending upstream.
2. **Plan-review hook via managed settings.**
   `claude-settings-managed.json.tmpl` ships the `PermissionRequest` /
   `ExitPlanMode` → `crit plan-hook` block; the settings modify script merges
   it (managed owns that hook list, other hook events pass through).
   `tests/claude-settings-modify.zsh` asserts both properties.
3. **Binary channel management.** `mise run crit:use` selects
   release/main/PR/local builds; skills re-vendor whenever the binary moves.
4. **Rejected paths** (see [ADR 0013](../adr/0013-apm-vendored-tool-integrations.md)):
   the official `crit@crit` marketplace and apply-time `crit install`, both of
   which bypass the committed-copy review gate.

## Remaining

- Live rollout: render plugins, `chezmoi apply` the settings hook, switch the
  binary to a channel matching the vendored skills, smoke a review round.
- Upstream PR restoring the "Use when ..." trigger clause to the claude-code
  skill description; drop the local delta once merged.
