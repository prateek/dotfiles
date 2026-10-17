---
status: active
doc_type: research
created: 2026-10-16
updated: 2026-10-17
related:
  - browser-runtime-controller-review.md
  - obscura-browser-evaluation.md
  - agent-browser-ecosystem.md
  - ../plans/browser-runtime-controller-plan.md
  - browser-controller-qualification.md
status_detail: "Local Lightpanda, Camofox and direct Camoufox evaluation, including browser-harness compatibility; installation is not production adoption."
---

# Local browser runtime and controller evaluation

The later [controller qualification](browser-controller-qualification.md)
tests actual curl and upstream MCP clients with a clean, exact-pinned install,
synthetic storage across a complete Camofox process restart, isolated task
lifecycle and further public-site actions. It closes those specific gaps;
the dated trials and failures below remain their original evidence.

## Scope and method

User-authorized installation and local experiments on macOS arm64. All runtimes
used fresh task-owned state, the same machine/network, no proxy, and background
headless operation. No live personal browser profile was imported or attached.
Gmail and Patreon login checks reuse the earlier explicit Devland authorization;
private content, messages, purchases and account changes are outside the trial.

This evaluates the local browser/controller combinations directly. It does not
install or qualify a complete Hermes or OpenClaw integration. Camofox's REST
surface was checked against Hermes's `tools/browser_camofox.py` source. Camofox
is the server/controller; Camoufox is its Firefox-derived browser runtime.

Evidence is retained in ignored `.scratch/lightpanda-eval/`,
`.scratch/camofox-eval/`, and `.scratch/browser-comparison/` directories. Scripts,
release metadata and machine-readable receipts accompany each scratch report.
Only sanitized conclusions belong in this public document.

These are bounded functional trials, not a performance or anti-bot success-rate
benchmark. Search trials mostly navigate directly to query URLs, unlike some
previous Obscura form-submission trials. Queries and controller paths differ;
Brave also received a matching query in a Lightpanda follow-up. No aggregate
ranking follows from timings or a single successful website request. A receipt
with `ok: true` can mean only that a call returned; task outcomes below require
application content or an independent state check.

## Lightpanda 1.0.1

Installed the official native macOS arm64 binary, verified against its GitHub
release asset digest, and linked it into a scratch-only mise data directory.
SHA256: `d4b66ac8484f49d7a49e05b6f9342716c747129527fcbe8ffe36679ffa18dd60`.
No shared mise selection was changed. Telemetry and core dumps were disabled.
[Official release](https://github.com/lightpanda-io/browser/releases/tag/1.0.1).

Tested existing Playwright-core 1.58.2 over CDP and the runtime's own persistent
stdio MCP. The CDP server explicitly enabled iframe, stylesheet and worker
resources; MCP used default resources. No Chrome fallback occurred. CDP reports
124.0.6367.29 as a compatibility version; the actual installed runtime is
Lightpanda 1.0.1.

- Forms: label fill, submit and independent input/change/submit event checks pass.
- Open shadow input and same-origin iframe input pass through Playwright.
- A detached ElementHandle rejects a click without clicking the replacement.
  This does not qualify native snapshot/node-reference freshness.
- Cookie and localStorage survive same-origin navigation. A second page in the
  same context fails with `TargetAlreadyLoaded`; cross-tab storage is unqualified.
- PNG capture works, but produces a text representation. It is not graphical
  website rendering or visual-layout evidence.
- Google returns an unusual-traffic challenge. Brave returns relevant GitHub
  results, including with the Chrome control's `Obscura browser github` query.
- Amazon returns real listings once, then HTTP 503 on subsequent sessions.
  Product-detail interaction is not qualified.
- Native MCP completes GitHub root-to-src and MDN querySelector-to-querySelectorAll
  navigation with resulting content verification. The GitHub transition needs
  an explicit readiness wait.
- Playwright's MDN click fails on viewport geometry. GitHub's first failure used
  a nonexistent docs path, and a later one selected a hidden duplicate link;
  those selector mistakes are not evidence of a runtime navigation defect.

## Camofox 1.18.1 / Camoufox 152.0.4-beta.30

Installed `@askjo/camofox-browser` 1.18.1 into scratch with Node 24.12.0,
`camoufox-js` 0.11.5 and initially resolved `playwright-core` 1.64.1. The official
macOS arm64 Camoufox archive SHA256
`3b43e766574f286a6a63296cf58b660b7a3120952086c869b4df4c9a71604bc3`
matched its GitHub release asset digest. The npm receipt retains package integrity.
The manually downloaded bundle needed downloader-equivalent `version.json`
metadata beside it before the wrapper could start; the browser archive was not
modified. Server binding, profiles, cookies and traces were task-local/loopback;
telemetry and default addon downloads were disabled. No proxy was configured.
[Wrapper source](https://github.com/jo-inc/camofox-browser),
[browser release](https://github.com/daijro/camoufox/releases/tag/v152.0.4-beta.30).

- REST form fill and click produce the expected submitted text. Independent DOM
  event receipt records input; a separate Enter test submits the expected value.
  Do not claim the complete input/change/submit event sequence from these receipts.
- Open shadow input passes. A top-level CSS selector cannot address a frame's
  field, but the snapshot exposes a frame ref and filling that ref passes an
  independent iframe value check.
- localStorage, sessionStorage and cookies survive same-origin navigation.
  A new tab shares localStorage/cookies while sessionStorage starts empty.
- A detached-ref click times out and invalidates the tab; later checks return
  410. This does not qualify safe stale-ref rejection because the final target
  state could not be inspected. Later storage/frame trials use fresh tabs.
- A separate fresh trial confirms unsafe reference reuse: First was `e4`;
  after removing First and refreshing the snapshot, Second became `e4`.
  Clicking the old `e4` succeeded and an independent DOM check recorded Second
  as clicked. Snapshot refresh does not provide reference-generation safety.
- A real rendered fixture screenshot is readable. Viewport requests time out
  with both tested dependency combinations; the screenshot is 390×844 and CSS
  matches a narrow viewport, but reported window dimensions disagree. Coherent
  mobile emulation is not qualified.
- Google navigation reports `ok: false` after about 30 seconds. A subsequent
  snapshot contains relevant search-result text. Source inspection establishes
  that this snapshot uses the wrapper's specialized DOM extractor, not a search
  API. This proves delayed result extraction, not reliable navigation readiness
  or a completed click through Google's opaque result redirect.
- Brave supplies relevant results; Amazon supplies a populated product grid.
- GitHub's Obscura docs-folder click updates URL and directory content, unlike
  the earlier Obscura release's stale-body result.
- MDN navigation to querySelectorAll passes through a fresh snapshot ref after
  correcting an ambiguous CSS selector. Amazon product details and Google's
  result-link destinations were not exercised.

The default dependency combination reports an unknown `bypassServiceWorker`
Firefox protocol parameter during storageState/persistence. In-session storage
success does not qualify persistence across restarts. A separate installation
pinning Playwright-core 1.58.2 successfully serializes storage and restores a
cookie and localStorage after destroying and recreating a session for the same
user/origin. This establishes session recreation, not server-process restart
persistence or authenticated-session retention. The baseline remains failed;
the repaired combination was not rerun through authentication.
The [follow-up](browser-controller-qualification.md#camofox-rest-and-lifecycle)
subsequently passed checkpointed synthetic storage across a complete graceful
server/browser restart. Authenticated retention remains unqualified.

### Source audit: reference lifetime

Read with `ask`: Camofox `v1.18.1` and `master`, Camoufox
`v152.0.4-beta.30`, Playwright `v1.64.1`, and camoufox-js `master`.
The Camofox server file matches the installed npm artifact and the live upstream
`master` blob at `39c82094013480b373df6600d44c7f036f58356e`.
The camoufox-js 0.11.5 tag lookup failed; its installed JavaScript was inspected
alongside upstream source rather than treating `master` as a version pin.

Camofox's [agent guide](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/AGENTS.md#element-refs)
describes stable identifiers and tells callers to refresh after navigation.
The implementation has a broader invalidation boundary:

- [`buildRefs`](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/server.js#L2328-L2429)
  starts a new map and counter at one. Each ID stores role, name and occurrence
  index, with frame metadata where needed; it does not retain DOM-node identity.
- [`refToLocator`](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/server.js#L2572-L2604)
  turns that record into `getByRole(...).nth(...)`. Playwright locators resolve
  against the current DOM for each action, as documented in its
  [version-matched locator guide](https://github.com/microsoft/playwright/blob/v1.64.1/docs/src/locators.md#locating-elements).
- The [click handler](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/server.js#L3997-L4056)
  can rebuild refs before a missing-ref action and rebuilds them after an
  ordinary successful click. Thus refs can change without a navigation or an
  explicit caller snapshot. The response does not expose a reference generation.
- Merged [PR 25](https://github.com/jo-inc/camofox-browser/pull/25) intentionally
  expands automatic rebuild/retry for missing refs. This recovers lookup failures;
  it does not verify that an existing numeric ID still denotes the old target.
  The inspected [operational-failure test](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/tests/unit/operationalFailures.test.js#L21-L35)
  checks an unknown `e9999`, not reuse of a valid ID for a different element.

The local test deliberately reused an ID from an older snapshot. It proves
missing generation protection, not failure when the caller selects the target
from the current snapshot. Source inspection additionally shows that discarding
IDs only on explicit snapshot refresh is insufficient. Treat refs as ephemeral
selector aliases: serialize observation/action, obtain a fresh snapshot for the
next action after a state change, and never replay an old numeric ref blindly.
These measures reduce risk; they do not guarantee node identity when same-name
elements reorder between observation and action. That latter scenario follows
from the locator implementation and was not exercised by the local trial.

This reference table belongs to Camofox's controller. Camoufox's
[Playwright integration](https://github.com/daijro/camoufox/blob/v152.0.4-beta.30/docs/playwright-maintenance.md)
supplies the Firefox automation protocol; camoufox-js launches it through
Playwright. Direct Camoufox plus Playwright is a distinct controller combination,
evaluated separately below; the REST test does not establish its behavior.

## Direct Camoufox + Playwright

Tested on 2026-10-17 with the same verified Camoufox 152.0.4-beta.30 binary,
camoufox-js 0.11.5 and Playwright-core 1.58.2. Existing scratch dependencies were
reused; the Camofox REST server did not participate. Playwright controls the
browser through Firefox's Juggler pipe, not CDP. Contexts were fresh and headless,
with no proxy, imported profile or authentication trial.

- Form fill/click and Enter submission produce independently verified values.
  Input events were observed; change events were not. Full event parity is not
  established.
- Semantic shadow-root locators and explicit iframe locators fill the intended
  fields. A real rendered fixture screenshot is legible.
- A detached ElementHandle rejects a click, and a unique semantic locator for a
  removed button times out. Neither clicks the remaining, differently named
  button. Direct locators avoid Camofox's numeric-reference table, but remain
  queries against the current DOM. Same-name replacements/reordering were not
  tested; this is not a persistent-node-identity guarantee.
- Same-origin navigation preserves cookies, localStorage and sessionStorage.
  A second tab shares cookies/localStorage and starts with empty sessionStorage.
  Exporting storageState and restoring it in a fresh context preserves cookies
  and localStorage. Browser-process restart and authenticated retention remain
  unqualified.
- Google and Brave direct query URLs return actual Obscura repository results.
  Search-box submission and result-link followthrough were not tested. Different
  execution times and randomized fingerprints prevent attributing Google's
  improved readiness over the earlier Camofox trial solely to the controller.
- Amazon search-to-product navigation succeeds: the detail title matches the
  selected LISEN USB C cable. No cart, purchase, price audit or exact variant
  qualification occurred. MDN link navigation verifies the destination URL and
  querySelectorAll heading.
- GitHub's initial selector chose a hidden duplicate. A visible semantic-link
  retry reaches the docs URL, but the expected directory-content predicate
  times out. Directory-content verification remains inconclusive; this does
  not establish stale content or a completed workflow.

This establishes a useful direct scripting and comparison baseline without a
REST server or an additional reference table. It does not compare the maintenance
cost of complete agent integrations. The later
[Hermes comparison](hermes-camofox-comparison.md) keeps Camofox's existing API as
an agent-facing recipe candidate. Neither result establishes universal Playwright
compatibility, a reliable anti-bot advantage, mobile fidelity or successful login.

## browser-harness + Camoufox

Read official source with `ask` and tested browser-harness 0.1.13. Its installed
`daemon.py` matches upstream commit
`a6426f846fc59d16f38cf66f79176bc7793c16b6`. The released controller uses
[`CDPClient` and `Target.getTargets`](https://github.com/browser-use/browser-harness/blob/a6426f846fc59d16f38cf66f79176bc7793c16b6/src/browser_harness/daemon.py);
it has no Playwright/Juggler or native WebDriver BiDi adapter. A configurable
WebSocket URL is not sufficient to make those protocols interchangeable.

| Configuration | Executed result | Interpretation |
| --- | --- | --- |
| Released browser-harness 0.1.13 → Camoufox native endpoint | Native BiDi `session.status` succeeds; actual `Daemon.start()` fails with `invalid session id`. `/json/version` and `/json/list` return 404. | Released CDP controller cannot attach to this Camoufox endpoint. Site workflows are blocked before navigation. |
| Draft PR 564 transport → standalone Camoufox native BiDi | Session creation, all 11 event subscriptions, existing-page discovery, navigation, evaluation, typing and pointer click pass. An independent DOM read verifies submitted `Ada`. | A working partial adapter exists, but this was a transport probe, not the full harness CLI/MCP workflow. |
| Same draft, page lifecycle | Additional-tab creation times out at the adapter's 30-second command limit; `Target.closeTarget` returns `unsupported_browser_capability`. | Multi-tab operation and per-tab cleanup are unqualified. The launcher, not the adapter, terminates the owned browser. |

The timed-out tab creation's eventual effect was not inspected; the timeout is
not proof that no tab was created.

[PR 564](https://github.com/browser-use/browser-harness/pull/564) was open, draft
and unmerged when checked on 2026-10-17. The probe used head
`83b591df687338cb4470c95d62a639b99c528c09` from the contributor's branch fetched
with `ask`; the inspected transport blob was independently matched to that head.
The branch source was loaded through `PYTHONPATH` using the installed 0.1.13
environment. Its complete declared dependency set and package were not installed
or qualified. The adapter also lacks viewport/device-metrics and dialog-accept
mappings in the inspected source; these were not live-tested.

An initial attempt added a BiDi port to a Playwright-launched Camoufox process
and timed out during draft startup. That mixed-controller attempt is not the
basis for the compatibility verdict. The corrected probe launches the native
executable with camoufox-js-generated configuration, an owned temporary profile
and a loopback BiDi port, without a Playwright/Juggler connection. The final
draft trial uses a fresh process. No running Chrome, cloud session or personal
profile was substituted. Browser-harness state was isolated and recording and
telemetry disabled.

Keep browser-harness as the existing Chrome/CDP recipe. Reconsider a Camoufox
recipe only after choosing a maintained BiDi implementation and qualifying the
full controller's lifecycle, forms, frames/shadow roots, storage, screenshots and
intended public sites. The partial draft form pass does not inherit direct
Playwright's site results or either controller's authentication results.

## Orca reference comparison

Ran the same Camofox fixture through local Orca 1.4.227 using three task-created
tabs and one fresh isolated profile. Calls used explicit page IDs, without
activation, tab switching or native keyboard input. The installed CLI and runtime
versions were captured; the shell's agent-browser reports 0.38.2, but the trial
does not independently identify Orca's resolved helper binary.

| Trial | Orca outcome | Comparison with Camofox |
| --- | --- | --- |
| Remove First, refresh snapshot, click First's old ref | First was `e3`; new snapshot assigns `e3` to Second; old `@e3` clicks Second, verified through an independent DOM marker | Same reuse behavior as Camofox's `e4` trial |
| Click Second using its current snapshot ref | Second receives the click | Correct current-ref use succeeds |
| Remove First, click old ref without refreshing | Clean lookup error; independent click marker remains empty | Camofox's earlier timeout destroyed its tab, so its final click state was unobservable |
| Navigate, then use an old ref without a snapshot | Old ref clicks a same-name button in the new document | Extra Orca observation; not a matched Camofox trial or proof of a wrong-target click |

The last result conflicts with the installed browser guide's stated navigation
invalidation rule for this path. An error code named `browser_stale_ref` is not
evidence that every outdated reference is rejected.

The old-ref-after-refresh result is shared by both controllers. It should not
be treated as a Camofox-only disqualifier. Both trials deliberately reused an
outdated ID; neither proves failure when an agent chooses the intended target
from the current snapshot. Apply the same observation/action rules and identity
requirements across controller evaluations.

Independent review checked the fixture and raw receipts. All owned tabs and the
profile were deleted; no owned helper remained, the fixture port closed, and
the residual task partition was removed. Foreground application samples before
and after each call were unchanged; this does not establish every transient
focus event. Evidence: `.scratch/browser-comparison/orca-refs/`.

## Chrome control

Existing installed Google Chrome 155.0.8059.82, existing Playwright-core 1.58.2, standard
headless automation launch, fresh temporary profile, no proxy or stealth patch.
This is a control for that configuration, not all Chrome usage modes.

- Google: unusual-traffic challenge; Brave: HTTP 429 CAPTCHA.
- Amazon: actual search results, then product link to an Anker cable page with
  title, selected variant, seller and specification/availability text. No cart.
- GitHub: existing visible src directory link, updated title and file contents.
- MDN: querySelectorAll destination, heading and article content verified.

Initial GitHub missing/hidden links and Amazon duplicate productTitle IDs were
corrected in the harness. They are not counted as browser failures. One controller
close stalled after Chrome exited; only its owned process was terminated and
its exact temporary profile removed. The follow-up closed normally.

## Authentication

Both runtimes first passed a dummy-password roundtrip without the marker in
captured logs. Real credentials remained in process memory and CDP or loopback
HTTP bodies, not shell arguments, screenshots or persisted logs. These checks
qualify the scratch transport only, not every integration or client.

| Runtime/controller | Gmail | Patreon |
| --- | --- | --- |
| Lightpanda 1.0.1 / Playwright-core 1.58.2 | Identifier fill succeeds; Next click times out. One diagnostic retry stays at the identifier stage, with no explicit insecure-browser rejection. | Credentials reach TOTP; after TOTP, a challenge remains and no authenticated navigation is established. |
| Camofox 1.18.1 / Camoufox 152.0.4-beta.30 / Playwright-core 1.64.1 | CAPTCHA observed after identifier submission; no password submitted. | Identifier entry succeeds; HTTP 422 timeout occurs during password fill or submit. Completed password submission is not established. |

Neither is a verified usable login. Camofox's Patreon outcome may be a controller
or form-shape problem; do not label it credential rejection or a proven browser
engine defect. No further retries were made after the bounded diagnostics.
The auth trials do not qualify a later dependency-repaired Camofox combination.

Auth cleanup independently verified owned ports closed, observed service/browser
PIDs exited, and task profile directories removed. Initial shutdown-request
receipts were supplemented by that final verification.

## Implications for the browser skill

Keep the evaluated alternatives experimental. Lightpanda is a candidate for lightweight
DOM work when graphical rendering and multiple pages per context are unnecessary;
controller choice changes which interactions succeed. Camofox reached useful
public content, but its confirmed old-reference reuse prevents treating opaque
refs as durable action targets. The follow-up qualifies the fresh-observation
workflow through curl and MCP; preserve that contract in a published recipe.
Strong stale-action rejection would require an identity guard
in addition to caller discipline. Pin the wrapper/browser/Playwright combination
rather than relying on npm's unconstrained resolution.

For Camoufox, keep the tested direct Playwright combination as the scripting
baseline. Camofox's existing REST and MCP interfaces now have bounded local
qualification, removing the need to build another agent-facing interface for
the tested operations. Use scoped, unique locators for direct scripts and fresh observations
for ref-based actions, with independent postconditions in both. Keep runtime
installation, controller selection and identity/retention separate. Released
browser-harness remains a Chrome/CDP route; its unmerged BiDi adapter is a
separate experiment.

Neither earlier authentication trial established a usable login.
These results do not establish behavior with retained authenticated profiles,
other network reputations, a full agent integration, or repeated site trials.
No default routing, production skill, managed configuration or global package
selection was changed.

## Retained evidence and cleanup

Owned browser/server processes stopped, loopback service ports closed and
temporary profiles were removed. Task-local binaries, dependencies and receipts
remain in ignored scratch directories for reproduction.

| Evidence directory | Main receipts |
| --- | --- |
| `.scratch/lightpanda-eval/` | `report.md`, `results.json`, `followup.json`, `mcp-public.json`, `mcp-github-wait.json`, `fixture.png` |
| `.scratch/camofox-eval/` | `report.md`, `receipt.json`, `compat-receipt.json`, `stale-fresh-results.json`, `compat-restore-results.json`, `mdn-results.json`, `fixture.png` |
| `.scratch/browser-comparison/chrome/` | `report.md` and per-trial receipts |
| `.scratch/browser-comparison/auth/` | `report.md`, `cleanup.json` and sanitized per-trial receipts |
| `.scratch/browser-comparison/orca-refs/` | `trial.py`, `results.json`, `receipt.json`, `cleanup.json`, `report.md` |
| `.scratch/browser-comparison/camoufox-direct/` | `trial.mjs`, `results.json`, `github-retry-results.json`, `receipt.json`, `report.md`, cleanup receipts and `fixture.png` |
| `.scratch/browser-comparison/harness-camoufox/` | `probe.py`, `draft_probe.py`, `standalone-browser.mjs`, `results.json`, `standalone-initial-results.json`, `receipt.json`, `report.md` and review notes |

Scratch evidence is local and is not part of the committed/public report.
