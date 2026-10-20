---
status: active
doc_type: plan
summary: "Camofox REST adoption for the browser skill with explicit mise setup, repair, supervisor checks, and automatic generic fallback under the existing runtime constraints."
created: 2026-10-16
updated: 2026-10-17
related:
  - browser-skill-plan.md
  - ../adr/0051-camofox-rest-browser-recipe.md
  - ../../agent-marketplace/src/utils-agent/skills/browser/SKILL.md
  - ../research/browser-controller-qualification.md
  - ../research/local-browser-runtime-evaluation.md
  - ../research/hermes-camofox-comparison.md
  - ../research/browser-runtime-controller-fable-review.md
  - ../research/obscura-browser-evaluation.md
status_detail: "Camofox follow-up source and local validation complete: automatic generic fallback, explicit mise setup, staged repair, diagnostics and HUP/parent-loss supervision. Landing and host activation remain separate."
---

# Browser components and Camofox REST adoption

## Agreed scope

Adopt the locally qualified Camofox REST controller over Camoufox, disable tool
telemetry, add the general telemetry instruction to root AGENTS.md, and make
the shared browser-skill changes. The user explicitly dropped Obscura adoption.
There is no Obscura production recipe, managed tool entry or MCP activation.
The earlier investigations remain linked evidence, not instructions to adopt it.

[ADR 0051](../adr/0051-camofox-rest-browser-recipe.md) records the decision.
Jev retirement belongs to its separate child-worktree change; this work adds no
Jev implementation or tests. Existing Orca secret helpers and their version
boundaries remain outside this change.

The review follow-up adopts the user's routing clarification: generic browsing
can fall back automatically while explicit runtime/tool constraints need user
feedback before substitution. Local REST authentication is deliberately deferred.
Setup belongs to an explicit mise task; browsing only checks and runs it.

## Implementation status

The source implementation is in utils-agent 1.13.0. The exact runtime is
installed locally. The following final follow-up checks passed on 2026-10-17:

| Check | Result |
| --- | --- |
| Helper regression suite | 25 tests: preflight/privacy plus real CLI supervisor, HUP/parent loss, bounded diagnostics, uncertain crash cleanup, installation-free check/run and staged repair |
| Shipped-helper browser trial | Fresh-ref form submission, independent DOM result, explicit tab targeting and graceful cleanup passed |
| Telemetry probes | Actual upstream reporters produced zero local-sink requests; hostile Node preload did not execute during preflight |
| Independent code and fresh-reader review | Follow-up has no remaining material findings after uncertain crash-state handling; generic versus explicit fallback agrees with the user's clarification |
| Mise setup task | Actual mise discovery/argument forwarding passed with a fake helper; the real task also reused and verified the installed pinned runtime |
| Marketplace check | 57 tests passed; reproducible 17-plugin build and final payload rebuild passed |
| Published payload | All 21 browser files match source; packaged helper verifies the local runtime with an explicit verification scope |
| Documentation | 38 lifecycle tests passed; 172 documents validated; 388 changed-document relative links resolve, including imported skills in the built plugin |
| Whitespace and cleanup | Tracked/new text checks passed; owned trial listener remains closed and task directory absent |

The live plugin has not been materialized or activated. Landing and a fresh
native-session check remain the delivery work described below. The landing
candidate integrates current trunk, including Orca input fixes and Jev retirement. Local evidence lives in ignored `.scratch/browser-adoption/`;
the [qualification report](../research/browser-controller-qualification.md#adoption-follow-up)
preserves the findings and limits.

## Resulting behavior

The router distinguishes these components:

| Component | Meaning |
| --- | --- |
| Harness | Where the agent runs: Orca or terminal |
| Runtime | The browser executing a page, including ownership |
| Engine | The compatibility implementation beneath that runtime |
| Controller | The tool that operates the runtime or native window |
| Transport | REST, CDP, MCP or another connection; not a compatibility guarantee |
| Identity | Isolated state, explicitly imported login, or requested live attach |
| Retention | Delete task state or explicitly retain it after the task |

Each controller reference names its runtime, identity support and limits.
There is no second exhaustive backend matrix or generic provider framework.

Routing stays ordered and explicit:

1. Requested running Chrome uses browser-harness in either harness.
2. Explicit Camofox/Camoufox page browsing uses the new task-owned REST recipe
   on macOS arm64 in either harness.
3. Explicit tools/runtimes stay constrained by the request. If compatible routes
   cannot complete it, ask which alternative is acceptable. "Try X first" is a
   preference allowing fallback; "use X" is a constraint unless alternatives
   are otherwise permitted. Respect requests for discussion/checkpoints.
4. Native UI uses the existing native controller; engine-specific tests use
   Playwright; simple reads can use fetch/API.
5. Generic interactive work starts with Orca inside Orca and agent-browser in a
   terminal. On failure, use installed compatible alternatives automatically:
   Orca → agent-browser → Camofox; terminal agent-browser → Camofox. Preserve
   identity/retention and reconcile uncertain actions before replay. Fallback
   runs from the current harness and does not install missing software.

Orca readiness is checked only for page/native operations that depend on Orca.
Its downtime does not prevent standalone Camofox, live Chrome, Playwright tests
or fetch. This is an intentional routing change and has its own acceptance
scenarios, separate from terminology edits.

## Camofox implementation

The production interface is bounded curl REST. The upstream MCP interface was
qualified in research but is not published or registered here. REST avoids an
adapter process, supports text-only snapshots and exposes session cleanup.

The skill owns three runtime inputs under `scripts/camofox/`: npm manifest,
lockfile and browser/Node pins. `mise run browser:camofox:install` invokes the
helper's explicit setup operation and installs the exact
lock into a cache keyed by those inputs; it uses mise's pinned Node, skips the
wrapper's automatic browser/addon download, verifies the official browser
archive and installs that bundle. It does not replace a global npm package or
edit native agent configuration. Existing verified archives may be reused.
The task is sourced from
`home/dot_config/mise/tasks/browser/camofox/executable_install` and resolves the
materialized skill by default; `BROWSER_SKILL_DIR` supports source/portable setup.
Direct portable setup remains `camofox-runtime.py install`.

`check` and `run` never install Node or Camofox. Mise discovery runs from the
user's home rather than an arbitrary caller's project. Normal setup serializes
on a per-runtime lock and reuses an existing valid installation. `--repair`
refuses an active runtime, validates a complete staged replacement, then swaps
it in with rollback if publication fails. The same lock protects running tasks
and checks from replacement. Errors identify the cache and repair operation.

Installation verifies the browser ZIP and npm lock integrity. Subsequent checks
compare shipped inputs, declared dependency versions, browser executable bytes,
version metadata and telemetry/study policies. They do not rehash all installed
JavaScript or browser resources; the returned verification scope says so.

`run` validates the pins and privacy policies, creates a private task tree,
starts a loopback-only server, checks that its own child owns the listener and
returns explicit ownership/identity values. The caller controls page actions
through upstream REST and retains the supervisor process handle. SIGINT, SIGTERM,
SIGHUP or loss of the launching parent stops the server, waits for owned
browser process groups, then removes the whole task tree. The parent PID is
captured before Node preflight, so parent loss during preflight prevents launch.
A Node preload journals exact browser spawns synchronously, including detached
groups created during shutdown. The final ownership pass runs after server exit. A failed cleanup retains the path and reports the failure.
Startup/server errors preserve at most 64 KiB of server diagnostics in a separate
private directory. An unexpected server failure preserves the task tree and
reports `cleaned: false, cleanupUncertain: true`, because periodic process samples
can miss a child reparented during server exit. The caller reconciles surviving
owned processes before removing that state and diagnostic or repairing the cache.
Forced/nonzero shutdown and incomplete ownership journals remain cleanup failures.
A durable task lease blocks cache replacement while retained state exists, even
after the supervisor exits or is killed. Identity mismatches never authorize
signaling an unrelated process group.
A supervisor SIGKILL or machine crash still requires manual
owned-resource recovery; a second parent-death wrapper is not adopted.

REST remains unauthenticated on loopback by user decision. Addressing UUIDs are
not credentials and do not isolate mutually untrusted local callers.

Initial support is ephemeral public browsing. No profile import, live attach,
secret entry or retained login is advertised. Checkpointed synthetic retention
was evaluated, but real authenticated retention was not. Session deletion can
write state; final cleanup must remove profile/cookie/upload/trace/temp files.
Shared servers and automatic tab adoption are excluded.

The runtime pins are Camofox 1.18.1, Camoufox 152.0.4-beta.30, camoufox-js 0.11.5
and Playwright-core 1.58.2. The earlier floating resolution selected 1.64.1 and
failed storage serialization. The mise task preserves that qualified dependency
graph and separately verified browser bundle; a plain npm tool pin is not an
equivalent installation.

## Telemetry contract

Root AGENTS.md requires version-supported opt-outs, removal of inherited
opt-ins and verification before tool launch. The browser policy carries that
requirement into the portable skill; each recipe owns concrete controls.

The Camofox supervisor supplies an allowlisted environment, including:

- `CAMOFOX_CRASH_REPORT_ENABLED=false` for the default-on report relay;
- empty `SENTRY_DSN`, which otherwise activates a separate reporter;
- `PROMETHEUS_ENABLED=false` and `MOZ_CRASHREPORTER_DISABLE=1`;
- private HOME/TMPDIR and explicit state directories;
- disabled default addon downloads and headless operation.

It verifies the downloaded Camoufox bundle's DisableTelemetry and
DisableFirefoxStudies policies. Generic DO_NOT_TRACK is supplementary.
Validation includes hostile inherited opt-ins and actual pinned reporter code,
not only assertions that a prose instruction exists. Local diagnostics,
package downloads and visited website traffic are separate from tool telemetry.

## Shared skill changes

| Surface | Change |
| --- | --- |
| Root AGENTS.md | Durable telemetry/analytics/crash-upload adoption rule |
| Browser SKILL.md and Codex sidecar | Component vocabulary, explicit Camofox route, runtime-owned readiness, defaults preserved |
| Policy | Fresh observation, current refs, independent result checks and reconciliation before retry; shared tool privacy |
| Auth | Identity/retention organized by controller; agent-browser mechanics moved to its recipe |
| Existing controller references | Runtime/controller/identity contract; preserve focused workflows and secret-helper compatibility |
| New Camofox reference | Installation, launch, curl action loop, exact identity, capability limits and cleanup |
| Runtime helper and locked inputs | Explicit mise setup, repair/locking, installation-free checks, diagnostics and TERM/HUP/parent-loss supervision |
| Machine browser convention | Align runtime/controller wording and explicit alternatives |
| utils-agent metadata | Bump native plugin version for changed published payload |
| Plan, ADR, index and evidence | Distinguish implemented, tested, packaged and activated state; remove Obscura adoption work |

## Writing-for-agents acceptance

The implementation reads writing-for-agents and SKILL-MECHANICS before changing
skill or AGENTS content. Validate every touched agent-facing file against:

- One trigger per branch in the description; existing model invocation retained.
- Router, shared policy, identity policy and per-controller mechanics each have
  one authority. Controller-specific session/vault commands are not global auth.
- Load references only on their branch; Camofox implementation detail stays out
  of the top-level router.
- Workflow steps have observable completion criteria, including process/state
  cleanup. Success receipts are not substituted for application postconditions.
- Positive instructions carry the workflow; hard prohibitions protect ownership,
  secrets and untrusted content rather than restating routine behavior.
- No unsupported runtime/identity capabilities or universal stale-ref guarantee.

## Qualification and validation

Existing [qualification](../research/browser-controller-qualification.md) covers
actual curl and upstream MCP, controlled forms, current refs, timeout-after-commit,
isolated concurrent servers, reset, session expiry and synthetic process-restart
retention. Public REST trials passed Brave, Amazon product navigation, MDN and
GitHub; Google readiness remained partial. Earlier auth trials established no
usable Gmail/Patreon login. These are bounded observations, not success rates.

Adoption-specific checks must exercise the shipped helper and recipe:

1. Clean locked install, repeated verification and rejection of wrong versions,
   browser bytes or privacy policies.
2. Allowlisted child environment rejects inherited reporter/proxy/config
   settings; pinned upstream reporter stays silent when triggered.
3. Actual helper launch, fixture form through bounded curl and independent
   result; SIGTERM cleanup leaves no owned browser/server, listener or task tree.
4. Process-boundary tests exercise actual CLI launch with external fixture server,
   TERM/HUP, launching-parent loss, environment isolation, private bounded
   diagnostics, repair/exclusion and installation-free check/run.
5. Fresh reader routes generic Orca, generic terminal, live Chrome, named Camofox
   in both harnesses, engine tests, fetch, unsupported platforms and missing
   runtime capabilities correctly, including automatic generic fallback and
   confirmation for changing explicit constraints. Camofox has no Orca readiness dependency.
6. `just -f agent-marketplace/justfile -d agent-marketplace check`, focused helper
   tests, docs lifecycle, relative links and whitespace checks.

Do not add tests that merely match skill prose. Use the real helper/environment
boundary for privacy and ownership behavior; fixtures and manual client trials
cover browser interoperability. Keep disposable experiments ignored and retain
sanitized results in the qualification report.

## Delivery boundaries

Source edits and a successful package build do not reload current agent sessions.
The local runtime installation is separate from plugin materialization and native
activation. The landing candidate integrates current trunk and retains newer
utils-agent changes. Preserve the previous artifact through reconciliation and
verify the selected recipe in a fresh native agent session.

Landing follows the repository's direct-push procedure. Host apply is a separate
effect selected by the user's saved landing preferences; successful source checks
do not themselves authorize activation. No global MCP registration or automatic
browser daemon is part of this change. The machine convention source materializes
through the ordinary dotfiles deployment.

## Rollback and maintenance

Remove the explicit Camofox routing row and restore the prior checked plugin
artifact if the recipe regresses. Existing default routes remain usable.
Stop only task-owned processes and remove only their state; installed versioned
runtime caches can be removed separately when no task uses them. macOS may mark
an internet-downloaded Camoufox ZIP with `com.apple.quarantine`; the installer
does not add quarantine or bypass it. A browser-downloaded ZIP launch problem
must be reproduced before adding any quarantine override.

Dependency or browser upgrades require reviewed pin changes and relevant live
qualification. Other platforms, authentication, retention and visual fidelity
are distinct future decisions. Obscura adoption is not a remaining milestone.
