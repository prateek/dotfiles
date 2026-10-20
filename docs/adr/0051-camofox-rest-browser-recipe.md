---
status: accepted
doc_type: adr
summary: "Browser automation runs an explicit task-owned Camofox REST runtime with pinned Camoufox, tool telemetry disabled, ephemeral state, and the runtime separated from the controller."
created: 2026-10-17
updated: 2026-10-17
current_guidance: ../../agent-marketplace/src/utils-agent/skills/browser/SKILL.md
related:
  - ../plans/browser-runtime-controller-plan.md
  - ../research/browser-controller-qualification.md
---

# Adopt a Camofox REST browser recipe

## Decision

Add Camofox REST controlling task-owned Camoufox as an optional route
in the existing browser skill. It is available in terminal and Orca harnesses
on the qualified macOS arm64 platform. Generic interactive work continues to
start with Orca inside Orca and agent-browser in a terminal. Generic requests
automatically try installed compatible alternatives when the preferred route
fails. Preserve explicitly requested runtimes/tools, engines, profiles and
identity; ask before changing those constraints, unless the request permits
alternatives. Live Chrome remains a browser-harness route, and required engine
tests use Playwright.

Keep runtime, controller, transport, identity and retention distinct in the
router and recipes. Readiness belongs to the selected runtime; an unavailable
Orca runtime does not block a standalone Camofox process, live Chrome or fetch.
Move agent-browser session/vault mechanics out of the harness-wide auth policy.
Apply fresh-observation, explicit ownership and uncertain-action reconciliation
to every controller. Numeric refs are not durable node identities.

Use the upstream REST API directly through bounded curl. A small skill-owned
helper installs the pinned dependency combination through an explicit mise task
and supervises one isolated,
ephemeral task. It does not wrap page actions, provide a provider registry or
register MCP tools. The published npm lock pins Camofox 1.18.1 with Playwright-core
1.58.2 and camoufox-js 0.11.5. A checksum-verified Camoufox 152.0.4-beta.30 bundle
is separate from mutable task state. Node is selected through mise and installed
only during setup. Runtime checks report their limited verification scope.
Setup is serialized, and staged repair excludes active users of the cache.

Tool telemetry, analytics and crash uploads are disabled before launch. The
supervisor uses an allowlisted environment, disables Camofox reporting, clears
Sentry configuration, disables metrics, suppresses Mozilla crash reporting and
checks Camoufox's telemetry/study policies. The root AGENTS.md makes this a
general tool-adoption convention. This does not claim to block website tracking.
Local REST access-key authentication is deferred by explicit user decision;
loopback addressing and UUIDs are not a local-caller security boundary.

Obscura adoption is dropped by explicit user decision. Keep its research as
evidence, without a production recipe, managed installation or activation.
Jev retirement remains a separate change.

## Rationale

The [qualification](../research/browser-controller-qualification.md) demonstrates
actual curl forms, fresh-ref targeting, separate-task isolation, checkpointed
synthetic storage across restart, expiry and cleanup. Bounded public trials
reach useful Brave, Amazon, MDN and GitHub content; Google readiness is partial.
Neither a general anti-bot claim nor authenticated persistence follows.

REST also exposes session/reset operations required for cleanup and allows
text-only snapshots. The tested MCP adapter adds another process and identity
boundary, always requests screenshots with snapshots and lacks those lifecycle
tools. It remains research evidence rather than a second production interface.

## Consequences

The first recipe supports ephemeral public browsing only. Import, live attach,
secret entry, retained login, mobile fidelity and other platforms require their
own qualification. Exact dependency/browser upgrades repeat relevant acceptance
checks; a floating npm wrapper version is insufficient.

The runtime cache may persist across tasks. The supervisor removes task browser
state only after its owned processes stop and reports cleanup failures. SIGHUP
and launching-parent loss reuse graceful cleanup; server failures retain a bounded
private diagnostic and task tree when descendant cleanup is uncertain. A Node
preload journals exact browser launches before returning from spawn, including
detached groups created during shutdown. Parent identity is captured before
preflight. Nonzero/forced shutdown and incomplete ownership records prevent a
success receipt; retained task leases block cache replacement until recovery.
Supervisor SIGKILL and machine-crash recovery remain manual.
It does
not run as a global daemon. Production plugin publication and native reload
remain the ordinary marketplace workflow, separate from local installation and
recipe validation. See the [plan](../plans/browser-runtime-controller-plan.md)
for implementation and validation status.
