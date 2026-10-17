---
status: active
doc_type: research
summary: "Executed client and lifecycle trials and Camofox REST adoption checks: pinned dependencies, telemetry suppression, task isolation, and cleanup, with Obscura evidence retained."
created: 2026-10-17
updated: 2026-10-17
related:
  - ../plans/browser-runtime-controller-plan.md
  - local-browser-runtime-evaluation.md
  - obscura-browser-evaluation.md
  - hermes-camofox-comparison.md
  - browser-runtime-controller-fable-review.md
status_detail: "Executed local qualification followed by Camofox REST source adoption and local helper checks. Obscura adoption dropped; live plugin activation remains separate."
---

# Browser controller qualification

## Decision supported by this work

Camofox 1.18.1 over Camoufox 152.0.4-beta.30 is usable for a narrow, explicit
terminal browsing recipe when its JavaScript dependencies, identity and state
directories are pinned. Actual curl calls qualify the proposed REST workflow.
The upstream MCP adapter also works through MCPorter when its user identity is
fixed across invocations. Neither requires porting Hermes's provider framework.
Keep REST as the first documented recipe: it has fewer process layers and also
provides the session/reset operations needed for cleanup. MCP is a tested
alternative interface, with its own identity and output-handling requirements.

Obscura's MCP client-lifetime problem is resolved: MCPorter can keep one Obscura
process alive across separate CLI calls, using explicit keep-alive configuration
and a private daemon namespace. Ad-hoc stdio calls lose browser state. This
qualification uses the existing pinned-main build; it does not repair release
0.2.4's previously observed reference and storage defects.

These are local qualifications, not a browser-default change, a general bot-mode
solution, or a native Codex/Claude integration. The qualification experiments
themselves changed no production configuration or authentication state.
Subsequent source adoption is recorded below and in the
[plan](../plans/browser-runtime-controller-plan.md). The user explicitly dropped
Obscura adoption; its client evidence remains historical comparison material.

## Method and exact dependencies

User-authorized experiments ran on macOS arm64 with Node 24.12.0, npm 11.6.2 and
the existing MCPorter 0.14.2. Subagents independently exercised public REST,
Camofox MCP and Obscura MCP; a separate agent audited receipts and source.
All browsers were headless, with fresh task-owned state and direct host network.
There were no credentials, proxy, profile imports, headed windows or silent
fallbacks. Every success below requires observed application state, not only
successful HTTP/tool delivery. These are bounded functional trials, not measured
reliability or performance comparisons.

The task-local package uses this complete manifest:

```json
{
  "name": "browser-qualification-camofox",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "dependencies": {"@askjo/camofox-browser": "1.18.1"},
  "overrides": {"playwright-core": "1.58.2", "camoufox-js": "0.11.5"}
}
```

An initial `npm install`, then a clean `npm ci`, both succeeded with
`CAMOFOX_SKIP_DOWNLOAD=1`. The lock resolves one copy each of Playwright-core
1.58.2 and camoufox-js 0.11.5; MCP SDK resolves to 1.32.1. Lock SHA256:
`c576ab68c213a6756139640957682d03d3facb3dfa9538c7668b33a8bad6aeaa`.
This closes the local pin-mechanism question. The source adoption below adds
the published lock and installation owner; other platforms remain unqualified.

The browser is the previously verified official macOS arm64 Camoufox archive.
This run rehashed the retained archive and compared its executable member with
the extracted executable actually used:

| Artifact | SHA256 |
| --- | --- |
| Camoufox 152.0.4-beta.30 archive | `3b43e766574f286a6a63296cf58b660b7a3120952086c869b4df4c9a71604bc3` |
| Extracted executable and matching archive member | `e468f25acba5085624da4d1ac809fd5679fa281ed2b0265f82efe63904900b33` |

The wrapper already pins its browser download release, but its Playwright range
does not pin a compatible protocol implementation. The earlier default 1.64.1
resolution failed storage serialization. This run qualifies the explicit 1.58.2
override, not the unconstrained install.
[Downloader](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/lib/camoufox-download.js),
[package manifest](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/package.json).

Versioned source was fetched with `ask src github:jo-inc/camofox-browser@v1.18.1`
and `ask src npm:mcporter@0.14.2`; exact Camoufox source from the earlier `ask`
fetch was reused. Both versioned GitHub and npm-derived camoufox-js source fetches
failed because the expected v0.11.5 tag is absent. Its installed, locked npm
source was inspected; upstream main was not treated as version-matched proof.

## Camofox REST and lifecycle

Every browser-controller request invoked actual curl with `--fail-with-body`, a
connection deadline, a request deadline and a response-size bound. Python only
orchestrated the processes and assertions. Public-site requests used 3-second
connect, 45-second request and 1 MiB bounds, with a 48-second outer process
deadline. JSON bodies were passed as files or stdin. Receipts retain curl exit,
HTTP status and application body separately.

Each task server had its own loopback endpoint, `userId`, `sessionKey`, profile,
cookie, upload, trace and temporary directories. The actual binding variable is
`CAMOFOX_BIND_HOST=127.0.0.1`. Launch explicitly supplied `CAMOUFOX_EXECUTABLE`
and `CAMOUFOX_INSTALL_DIR`, disabled default addon downloads and crash reporting,
and selected headless operation with `CAMOFOX_INTERACTIVE=off`. Listeners and
owned browser descendants were inspected independently of health responses.
[Configuration](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/lib/config.js).

The final controlled trial passed all 34 named checks:

| Guarantee | Observed result |
| --- | --- |
| Fresh-ref form interaction | Name fill and submit produce visible `Submitted Ada` plus exactly one fixture HTTP event |
| Fresh refs after DOM mutation | Remove First, take a new snapshot, click Second; DOM and HTTP ledger identify Second |
| Uncertain action outcome | Delayed response causes curl timeout 28 after a real click; new snapshot and ledger show one committed action; no retry |
| Concurrent task isolation | Separate servers/identities/directories do not share cookies or localStorage; B survives A's restart |
| Same identity, multiple tabs | A's second tab sees A's synthetic cookie/localStorage |
| Session deletion | Checkpoints state to disk; it is not an ephemeral-state purge |
| Whole process restart | After checkpoint and verified server/browser exit, a new process and new tab restore synthetic cookie/localStorage |
| Storage reset | Clears live context and saved snapshot; recreated tab has empty cookie/localStorage |
| Empty-session reaper | Closing last tab eventually removes its empty session; log identifies the reaper |
| Idle expiry | `SESSION_TIMEOUT_MS=1000` with the unmodified 60000ms reaper expires the test session; log and missing-tab response agree |
| Cleanup | All owned descendants exit, all five fixture/server/proxy ports close and complete ephemeral state tree is removed |

Process-restart retention here means **checkpointed synthetic storage** survives
a graceful stop/start. It does not restore tabs, prove crash durability or qualify
real authenticated sessions. The idle test shortens the timeout, not the reaper;
it does not claim to have waited the default ten-minute idle duration.

Two harness assumptions were corrected, with failed receipts retained:

- Camoufox's default evaluation world cannot see a page-script global such as
  `window.clicked`. Shared DOM markers and an independent fixture HTTP ledger
  correctly observe the action. Upstream's own test runner documents this
  isolation. Earlier reference tests already used DOM markers and remain valid.
  [Camoufox runner](https://github.com/daijro/camoufox/blob/v152.0.4-beta.30/build-tester/scripts/runner.py).
- A nonexistent non-UUID tab returned HTTP404, but a missing UUID-shaped tab
  shortly after launch returned HTTP410 with `browser_restarted`. Source sets
  the timestamp on every successful browser launch and uses this label for
  five minutes; reset and expiry can therefore produce it without a crash.
  Treat it as missing-resource evidence and reconcile ownership.
  [Launch timestamp](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/server.js#L1229),
  [missing-tab response](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/server.js#L1771-L1786).

Persisted state is separate from process lifetime. The recipe must remove all
owned profile/cookie/upload/trace/temp directories after ephemeral work.
`DELETE /sessions/:userId/storage_state` clears the live context and saved
storage snapshot but does not replace that full-directory cleanup.
[Persistence implementation](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/plugins/persistence/index.js).

## Public sites through actual curl

One bounded run per site used the same pinned combination, current observations
and independent DOM checks through REST evaluate. Search used query URLs; form
typing and result-link followthrough are separate capabilities.

| Site/task | Outcome and limit |
| --- | --- |
| Brave: Obscura browser github | Pass: snapshot and actual DOM contain the relevant official GitHub repository |
| Amazon: search to product | Pass: populated grid, observed candidate link, click, matching product URL and `#productTitle`; no variant, price or checkout claim |
| MDN: querySelector to querySelectorAll | Pass: current snapshot ref, destination URL/title/h1 agree |
| GitHub: repository to docs directory | Pass: current ref, changed URL/title and actual directory file contents; this does not rewrite the earlier direct-Playwright inconclusive result |
| Google: Obscura browser github | Partial: navigation returns HTTP200 with `ok:false` after 30.23 seconds; later snapshot and independent actual DOM contain relevant results; no result-link followthrough |

Google demonstrates why HTTP200 is insufficient. It was not retried through a
different runtime and no fallback result was counted as browser success.

## Camofox upstream MCP through MCPorter

The upstream adapter connects to an already running Camofox REST server. It
does not own that server's lifetime. The tested CLI uses explicit task-local
configuration with `imports: []`, `--output json` and a fixed
`CAMOFOX_USER_ID` in the adapter launch environment. A fresh adapter process on
each CLI call can still address the same REST-owned state when that ID is stable.
The control with omitted/random identity creates a tab, then sees an empty tab
list on the next separate CLI invocation.
[Adapter source](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/mcp/server.mjs).

The config points `command` to the pinned Node executable and `args` to the
installed upstream `mcp/server.mjs`, with explicit `lifecycle: "ephemeral"`.
Adapter environment includes the owned `CAMOFOX_BASE_URL`, task-unique stable
`CAMOFOX_USER_ID`, `CAMOFOX_SESSION_KEY` and empty owned cookie directory.
Each call specifies the absolute config path. This lane creates no MCPorter
keep-alive daemon: REST owns the persistent browser state, unlike Obscura below.

Actual CLI calls verified form submission to the intended tab while another tab
remained unchanged, cross-user rejection, tab close, long-snapshot pagination
and uncertain-action reconciliation. A 250ms client timeout returned nonzero
exit with an `error`/`issue` envelope and no `isError`; the fixture nevertheless
recorded one action. A fresh snapshot observed its committed result and the
client did not replay it. Tool errors, client transport errors and application
postconditions must be checked independently.

`sessionKey` is grouping, not identity isolation: the same `userId` sees tabs
in other groups. Numeric refs remain latest-observation aliases. A snapshot's
last page can report `truncated:true` with `hasMore:false`; follow `hasMore` and
`nextOffset`, not `truncated` alone. The upstream MCP snapshot always requests
a screenshot, so account for image/output cost even during text-only tasks.

A separate persistent-client probe used MCPorter's exported `createRuntime`
API. One adapter's generated random identity stayed stable across calls;
unknown tools returned `isError:true`. The server advertises tools only, so an
unsupported resources-list method is not a missing browser feature. Closing
the adapter left its REST-owned tab alive, verified independently. This probe
does not qualify native harness registration or replace server/state cleanup.

Public-site calls through this actual MCP path also found the official Obscura
repository in Brave and completed Amazon search-to-product navigation. Amazon's
first exact-href CSS target matched three links and returned
`ambiguous_selector`; reobservation confirmed no product navigation. After that
run was cleaned up, one diagnostic run used a fresh product-name ref and reached
the chosen Anker product with an exactly matching title. This qualifies corrected
targeting in a new browser, not recovery continuity across the discarded session.
Google, login, price and variant selection were not tested through MCP.

The adapter advertises eleven tools; discovery does not mean all were exercised.
Cookie import was not tested. Its tool set has no dedicated session/group/reset,
upload/download, dialog, frame-selection or server-stop operation. Cleanup still
needs the underlying REST/process owner. MCP snapshots always request a
screenshot, whereas a text-only REST snapshot can avoid that image cost. These
are concrete reasons to retain the smaller REST recipe as the first interface.
[Tool contracts](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/mcp/lib/tool-contracts.mjs).

## Obscura with an owned persistent MCP client

MCPorter 0.14.2 used the existing Obscura render build
`0.2.4-post-bd9529418b`, commit
`bd9529418b7fa975b50eabeac415cfaaa865a588`. All ten assertions passed: ad-hoc
calls lose page state, configured keep-alive preserves it, form actions have a
verified result, second-tab selection and switchback preserve the intended page,
the transport connection stays the same, tool errors propagate, and cleanup
removes the owned daemon, Obscura child, socket and fixture.

The task-local MCPorter server entry was:

```json
{
  "imports": [],
  "mcpServers": {
    "obscura": {
      "command": "/absolute/path/to/pinned/obscura",
      "args": ["mcp", "--allow-private-network"],
      "cwd": "/absolute/path/to/task",
      "lifecycle": {"mode": "keep-alive", "idleTimeoutMs": 60000}
    }
  }
}
```

Private-network permission was needed for the owned localhost fixture; it is
broader than a localhost allowlist and is not a blanket public-browsing default.
Separate calls used `mcporter --config <path> call obscura.<tool> --args <json>
--timeout 10000 --output json`.

**The daemon namespace is essential.** MCPorter's default daemon is shared per
OS account. Different config files, HOME or XDG directories alone do not isolate
it. Set `MCPORTER_DAEMON_DIR` to a short private mode-0700 directory on every call,
including `daemon status` and `daemon stop`. The trial also redirected HOME/XDG
for subprocesses and disabled config imports. Stopping the private namespace
removed its owned child and socket; never issue an unscoped global daemon stop.
[Version-matched daemon documentation](https://github.com/openclaw/mcporter/blob/v0.14.2/docs/daemon.md).

Use `--output json`: `raw` prints Node inspection syntax. JSON can unwrap an
evaluate result to a primitive, so parse the expected operation-specific shape.
Keep executable, arguments, working directory and launch environment consistent
between calls. The configured idle limit was observed in status but its expiry,
daemon crash recovery and parallel callers were not tested in this lane.
No public-site, authentication or release-regression result is inherited from
this localhost client-lifetime trial.

## Adoption follow-up

The approved implementation publishes only Camofox REST, with ephemeral identity
in terminal and Orca harnesses. It handles explicit requests and compatible
automatic fallbacks for generic browsing. The browser skill contains
the exact npm manifest/lock and checksum-pinned browser input. Its small helper
owns installation and server/process/state lifetime; page actions stay on the
upstream REST API. The writing-for-agents refactor separates runtime/controller,
scopes readiness and moves agent-browser session/vault mechanics into its recipe.
Obscura adoption and native MCP registration are excluded.

The helper's first installation passed health but failed actual tab creation:
upstream requires version metadata beside Camoufox.app as well as at the supplied
install directory. The independent trial preserved that failure. Installation
now creates both metadata files, and preflight rejects the missing outer file.
The regression was observed failing before the fix and passing afterward.

Telemetry checks use the actual pinned upstream configuration and reporting
modules under the helper's allowlisted child environment. Hostile inherited
crash-report/Sentry/NODE_OPTIONS settings do not reach the child. Triggered crash
and hang reports produce zero requests to an owned local sink; Sentry flush
returns false. Prometheus is disabled, Mozilla crash reporting is suppressed,
and preflight verifies the bundle's telemetry/study policies. This is not a
whole-network egress audit or website-tracker blocker.

An independent code review also found that the first Node-discovery command
inherited NODE_OPTIONS before the server environment was sanitized. A harmless
preload demonstrated execution during that discovery call. Discovery now uses
`mise which` under an allowlisted environment and probes the selected Node
binary with that same clean environment. The actual helper `check` passes under
the preload input without creating its marker. Permanent tests cover both
preflight process boundaries as well as the REST child's environment.

The corrected shipped helper then passed actual fresh-ref form entry/click,
an independent DOM predicate, second-tab creation and explicit return to the
original tab. SIGTERM produced a clean exit, no server or observed browser
descendants, a closed listener and an absent task directory. The independent
trial and preserved failed attempt are in
`.scratch/browser-adoption/qualification/`; bootstrap privacy evidence is under
`.scratch/browser-adoption/bootstrap-privacy/`.

The initial adoption review found no remaining material issue after the Node
preflight fix and an earlier unsupported-runtime routing branch. All eight helper
tests, 57 marketplace tests and 38 docs-lifecycle tests passed; 172 documents
validated. The reproducible plugin build contains all 20 browser files unchanged
from source, and its packaged helper verifies the local runtime. Review and
packaging evidence is retained under `.scratch/browser-adoption/`. These checks
do not establish activation in a fresh native agent session.

An Opus review through Claude Code subsequently found lifecycle, recovery,
diagnostic and wording gaps. The user deferred local REST authentication and
clarified routing: generic browsing automatically tries installed alternatives;
explicit runtime/tool/engine/profile requests need agreement before substitution,
unless the request permits fallback. Checkpoint/discussion requests remain binding.

The follow-up moves provisioning to `mise run browser:camofox:install`. Its locked
helper still owns the compatible npm graph and verified browser ZIP; `check` and
`run` are installation-free. Mise lookup uses the user's home instead of the
caller's project. Setup serializes; staged `--repair` preserves the previous
cache until the replacement validates and refuses active users of the runtime.
Current verification receipts explicitly name the inspected inputs and executable;
they do not promise a full hash of every installed resource.

Controlled trials demonstrated that SIGHUP and loss of the launching parent left
the old supervisor's server/child running. Both now trigger existing graceful
cleanup. An additional regression observed a server spawning a child and exiting
between process samples while the helper emitted a false successful-cleanup
receipt. The helper now stops observed descendants, preserves private state and
reports uncertain cleanup on server failure. It retains up to 64 KiB of diagnostic
log separately; recovery must reconcile surviving owned processes before deleting
that state or repairing the cache. A forced supervisor kill still needs manual
recovery. All owned experiment processes were cleaned.

The actual mise task was discovered and its normal/repair argument forwarding
passed with an isolated fake helper. Fourteen permanent tests cover the real CLI
supervisor seam on macOS as well as preflight/privacy. The actual mise task also
reused and verified the existing pinned runtime through the real helper.
The revised real Camoufox
form/tab/cleanup trial and actual reporter probes passed again. A real occupied-port
startup failure preserves its diagnostic and reports uncertain state; the probe
recovered that state and left the original listener untouched. Evidence is under
`.scratch/browser-adoption/revision-qualification/`, `parent-death/`,
`mise-task-probe/`, and the revision test/review logs.

The archive discussed in review is the checksum-pinned Camoufox release ZIP.
macOS may attach `com.apple.quarantine` to browser downloads. The installer adds
no quarantine and performs no blanket attribute removal; a quarantine-specific
launch failure was not established and no bypass is adopted.

The local runtime installation is separate from publishing the plugin into
native clients. Real login/retention, crash recovery, repeated site reliability,
mobile/visual fidelity, other platforms and shared-server use remain unqualified.
Earlier Gmail/Patreon checks used a different dependency resolution and did not
establish usable authenticated sessions. Current deployment status belongs to
the [plan](../plans/browser-runtime-controller-plan.md#delivery-boundaries).

## Evidence and independent review

Local evidence is retained under ignored
`.scratch/browser-qualification-20261017/`; disposable scripts are not a new
production controller. All owned runtime state is removed after each trial;
dependencies, browser artifacts and public/synthetic receipts are retained.

| Lane | Evidence |
| --- | --- |
| Exact install | `pinned-app/package.json`, `package-lock.json`, `install-receipt.json`, `browser-reverification.json` |
| REST lifecycle | `lifecycle/trial.py`, `results.json`, `report.md`, and separate `attempt-1/`, `attempt-2/` failures |
| Public REST | `public-sites/report.md`, `results.json`, `checks.json`, request/response receipts and `cleanup.json` |
| Camofox MCP | `camofox-mcp/` CLI and persistent-client scripts, receipts and cleanup |
| Obscura MCP | `obscura-mcp/trial.py`, `verify.py`, `receipts.json`, `assertions.json`, `cleanup.json` and concrete config |
| Independent audit | `evidence-audit.md` |

The independent reviewer found no material false pass in the completed install,
REST, client-lifetime and lifecycle evidence. It specifically checked the
separate error channels, pagination termination, missing-tab classification and
synthetic-versus-authenticated retention boundary.


## Astra adversarial follow-up

A fresh Astra source review and controlled process probes reproduced parent loss
inside Node preflight and browser creation during server shutdown. Both were
real lifecycle failures: the old helper could start after its parent died or
report successful cleanup with a surviving child. A second pass found that
reading the spawn journal after a process snapshot could prematurely retire a
new group. The helper now reads ownership records before taking the fresh snapshot.

The supervisor captures its launching parent before preflight, journals exact
browser launches through a Node preload, and reconciles detached process groups
after server exit. It preserves uncertainty for incomplete journals and
nonzero/forced shutdown. Durable task leases prevent cache repair while recovery
state remains. PID/start identity checks and retired group generations avoid
signaling unrelated replacement processes. Server-tree discovery also requires
the verified direct-child relationship and the recorded server generation.
Diagnostic-write failure cannot
interrupt the preload's mandatory failure exit when ownership cannot be recorded.

The 25-test helper suite covers these regressions, including an actual Node
spawn during SIGTERM, malformed journals and reparented group members. An actual
pinned Camoufox replay independently verified fresh-reference form input, an
explicit DOM predicate, separate tab identity and normal cleanup: server stopped,
port closed, no observed owned survivors, and task state absent. The retained
metadata-only journal records the real browser PID and detached group. Scratch evidence
is under `.scratch/browser-adoption/astra-qualification/`; controlled review
probes and red regression logs are under `.scratch/browser-adoption/`.
These checks qualify local source behavior; native plugin activation and landing
remain separate.

Astra independently replayed the observation-order, diagnostic-failure and reused
server-PID probes against the fixes and reported no remaining actionable findings
within the macOS arm64 ephemeral-runtime scope. Review-owned processes and state
were removed. Arbitrary new sessions outside the journaled launch boundary and
recovery after supervisor SIGKILL or host crash remain manual recovery limits.
