---
status: accepted
doc_type: adr
created: 2026-10-16
updated: 2026-10-16
related:
  - 0035-separate-experimental-jev-browser-skill.md
  - ../plans/jev-deterministic-preparation-plan.md
  - ../research/jev-browser-integrations.md
current_guidance:
  - ../../agent-marketplace/packages/experimental/skills/browser-jev/SKILL.md
  - ../../tests/README.md
status_detail: "User-authorized relocation; Jev maintenance and trials are suspended."
---

# Suspend Jev in the existing experimental plugin

## Decision

Move `browser-jev` from `utils-agent` into the existing `experimental` plugin.
Keep experimental disabled by default and require explicit user invocation with
paired Claude frontmatter and Codex policy controls. Preserve the runner and
launcher implementation without restarting browser or model trials.

This supersedes the sibling publication decision in
[ADR 0035](0035-separate-experimental-jev-browser-skill.md) and closes the
[dynamic preparation plan](../plans/jev-deterministic-preparation-plan.md) as
suspended work. The [research](../research/jev-browser-integrations.md) remains
historical evidence; the missing end-to-end comparison is still unmeasured.

## Dependencies and maintenance

Jev requires `utils-agent:browser` for browser identity, authorization, focus,
and cleanup policy. Cross-plugin links resolve in the source and shared built
marketplace. Clients with separate versioned caches must locate the regular
browser skill through their catalog. Shared policy and helpers remain owned by
utils-agent; the regular browser skill has no dependency on Jev. The launcher
imports only its own Jev modules and resolves browser executables at runtime.

Keep the existing offline tests, fixture server, and receipt evaluator at their
current paths. Run `just test-browser-jev` explicitly when maintaining the
experiment. Ordinary `just test-node` and `test-ci` exclude these checks. This
deliberately gives up automatic detection of Jev runtime regressions while
preserving every assertion for optional use. Package build/check still validates
the published skill and paired invocation controls.

The [skill](../../agent-marketplace/packages/experimental/skills/browser-jev/SKILL.md)
and [test guide](../../tests/README.md) own current execution instructions.
Offline checks and package validation do not qualify a live browser/model trial
or establish an improvement over the regular browser workflow.
