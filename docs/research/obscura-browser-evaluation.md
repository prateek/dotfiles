---
status: active
doc_type: research
summary: "Local Obscura browser experiment: installation, control paths, and the limits found."
created: 2026-10-16
updated: 2026-10-17
related:
  - ../plans/browser-runtime-controller-plan.md
  - browser-runtime-controller-review.md
  - browser-controller-qualification.md
  - ../references/mise-tool-management.md
status_detail: "Retained experimental evidence. Obscura adoption was dropped by explicit user decision on 2026-10-17; no production route or managed installation is planned."
---

# Obscura browser evaluation

Obscura adoption is dropped. This report retains the experiments and limitations;
it is not an installation or adoption instruction. The
[current plan](../plans/browser-runtime-controller-plan.md) adopts Camofox REST.

## Decision supported by the evidence

Obscura 0.2.4 can execute basic scripted forms through persistent MCP,
Playwright/CDP, and agent-browser/CDP. It is not qualified as a replacement for
our default browser routes. The released MCP implementation fails the proposed
stale-reference and localStorage guarantees, and the tested public search and
shopping workflows did not reach their required outcomes.

This is local evidence from macOS arm64 on 2026-10-16, using task-owned
processes. It does not establish behavior on other networks, platforms, or
versions. A controller connection, successful tool receipt, and HTTP success
are each weaker evidence than the requested application result.

## Installation and dependency ownership

The user authorized local installation through mise and parallel experiments.
The worktree-local selection is in ignored `mise.local.toml`:

```toml
[tools]
"github:h4ckf0r0day/obscura" = { version = "0.2.4", asset_pattern = "obscura-aarch64-macos.tar.gz" }
```

Reproduction of that selection:

```sh
mise use --path mise.local.toml 'github:h4ckf0r0day/obscura[asset_pattern=obscura-aarch64-macos.tar.gz]@0.2.4'
mise exec -- obscura --version
```

The installed binary reports `obscura 0.2.4`. Its adjacent worker is retained.
No extra runtime dependency or fonts were needed for the standard render build.
The 66,840,143-byte official archive has SHA-256
`456210fe48e77324a064477fe450452a58709940a50e71678ae6638a3e5095ec`.
An independent download matched the release API's digest; both installed
executables matched the verified archive's bytes. This is artifact consistency,
not independent reproducible-build provenance.

Correction to the earlier review: lack of a separate checksum file does not
mean lack of an upstream checksum. GitHub's release asset API exposes SHA-256
`digest` metadata. Inspect and verify that field before declaring verification
unavailable. [Official release](https://github.com/h4ckf0r0day/obscura/releases/tag/v0.2.4).

A separate render+stealth artifact was installed under a scratch-specific
`MISE_DATA_DIR`, verified against its own API digest, and invoked explicitly
with `--stealth`. It did not overwrite the baseline. The binary variant matters:
the standard build's flag alone does not provide the feature-gated stealth TLS
transport. Playwright core 1.58.2 was installed through mise for the CDP trial,
without a browser download or global selection; Obscura remained the runtime.
Existing agent-browser 0.38.2 supplied the independent native-CDP trial.

No managed `home/` configuration, global tool selection, MCP registration,
system certificate store, or production skill was changed. The global mise
cache holds installed packages; that is distinct from enabling them globally.

## Methods and evidence retention

Experiments live in ignored `.scratch/obscura-eval/`, with separate `install`,
`control`, `search`, `amazon`, `auth`, `spa`, `tls`, and `history` directories.
Each lane records its versions, steps, expected result, observed result, and
cleanup. Those local receipts and prototype scripts are intentionally not
part of the published skill. This document retains the useful findings.

A small Python stdio MCP client keeps one subprocess alive across calls.
It logs neither arguments nor results itself, checks deadlines, and terminates
its owned process on exit. Callers inspect `isError` and control which fields
are retained. This proves scripted persistent MCP access; it does not prove
native agent registration. The later
[MCPorter qualification](browser-controller-qualification.md#obscura-with-an-owned-persistent-mcp-client)
demonstrates process continuity with task-local keep-alive configuration and a
private daemon namespace, and confirms ad-hoc calls lose page state. That trial
uses pinned main; it does not change the release/runtime failures recorded here.

Fixtures used independent application-side event counters and result markers,
not assertions mirroring tool success receipts. Private-network permission was
scoped to local fixture processes. Public-site trials used no imported browser
profiles, proxies, or CAPTCHA-solving loops. Initial selector and fixture
mistakes were corrected and distinguished from runtime failures.

## Released runtime results

| Workload | Controller/build | Observed result |
| --- | --- | --- |
| Example Domain JS title and PNG | CLI, standard | Pass: expected title and valid 1280×720 PNG |
| Controlled ordinary form | Persistent MCP, standard | Pass: JS marker, input/change events, fill, submit, independent result |
| Controlled ordinary form | Playwright core 1.58.2/CDP, standard | Pass: context/page, navigation, labeled fill, click, result, screenshot, page close |
| Controlled ordinary form | agent-browser 0.38.2/CDP, standard | Pass: named session, open, interactive snapshot, fill, click, read result, close |
| Stale reference after refreshed listing | MCP, standard | Fail: old `e1` changed from First to Second and activated Second without error |
| localStorage across same-origin navigation | MCP, standard | Fail: set/read succeeded, next page returned null; destination had no resetting script |
| Cookie continuity and fresh-process isolation | MCP, standard | Pass: cookie survives navigation/tab creation; fresh process has no cookie |
| Tab selection and close | MCP, standard | Pass for inspected basic sequence |
| Shadow-root form and iframe controls | MCP, standard | Child DOM exists, but listing/top-level selectors omit the controls; workflow unqualified |
| Keypress on missing shadow target | MCP, standard | Fail: success receipt but no value/event change |
| Snapshot inline refs | MCP, standard | Release requires separate `browser_interactive_elements`; current-main docs differ |
| Simple controlled screenshot | MCP, standard | Pass: image inspected for visible marker, input, events, result |
| Google web search | CLI/MCP, standard and stealth diagnostics | Unusual-traffic block; no relevant result |
| Brave web search | CLI/MCP, standard and stealth diagnostics | Standard challenge; stealth reaches homepage but submitted query is challenged |
| Bing web search | MCP, standard | Submit click reaches query URL; unrelated Facebook results fail relevance acceptance |
| DuckDuckGo web search | MCP, standard | Submit click reaches query URL; shell without result list |
| Amazon browsing | CLI/MCP, standard and stealth diagnostic | AWS WAF HTTP 202 challenge, blank content and zero forms; search/product/variant steps not exercised |
| GitHub repository folder click | MCP, standard | URL changes but stale root content remains; direct directory navigation loads correct listing |
| MDN reference navigation | MCP, standard | Expected linked document and substantive content reached; screenshot has layout defects |
| Local HTTPS with private-network denied | CLI/MCP, standard | Pass: rejected before fixture handler receives request |
| Local HTTPS with private access, untrusted CA | CLI/MCP, standard | Pass: fails closed, no handler request |
| Local HTTPS with process-local custom CA | CLI/MCP, standard | Pass: expected marker and one handler request |

Search used a benign query with the independently known Obscura GitHub
repository as the expected destination. No tested browser-search route produced
the required relevant title and link. Bing irrelevance and DuckDuckGo's shell
are observations, not a diagnosis of an engine defect: no matched independent
browser/network baseline established the cause. Enter sometimes reported success
without submitting; explicit inspected submit controls produced different results.

Amazon remains access-blocked, not proven incapable of every product operation.
No real product or variant was available to test. Stealth changed some page
access outcomes elsewhere but did not solve Amazon's challenge.

TLS custom trust uses `SSL_CERT_FILE`/`SSL_CERT_DIR` in the normal client. Its
scope is all connections in that task process, not a hostname, tab, or pinned
leaf fingerprint. This is not equivalent to Orca's certificate-pinned proxy.
Generated fixture private keys were deleted. Generic network errors required
differential tests to attribute them to certificate validation. Stealth TLS
trust behavior was not tested.

## Authentication and API lanes

Authentication uses only the explicitly authorized Devland identity in an
isolated process, after a dummy-secret transport check. Secrets are read into
local process memory and transmitted over stdio; no passwords, OTPs, cookies,
mail contents, or private creator content belong in this report.

Google reached the identifier step and rejected sign-in with the insecure-browser
message. No password or OTP was submitted and no inbox was opened. A prior
Gmail API success is not evidence of Obscura browser sign-in.

Patreon standard build stopped at a Cloudflare challenge. The render+stealth
build reached the login form; after waiting for hydration, credentials advanced
to TOTP, then submission changed the URL to `/home`. The DOM still showed code
verification and lacked authenticated navigation after ten seconds. This is
post-TOTP navigation with **usable signed-in state unverified**, not login
success. No private creator content was read or state exported. Early server
HTML controls were replaced during hydration, making an immediate fill an
invalid test. Missing DOMImplementation and worker importScripts were observed
in diagnostics; their causal role was not established.

Brave Search API, Tavily, and Serper each received one direct API query using
existing Devland credentials held only in process memory. All returned HTTP 200
and the expected Obscura GitHub repository as the first of five results. No keys,
raw account metadata, purchases, or subscription changes were recorded. These
results qualify the bounded direct API controls only, not Obscura browser search.
The earlier environment/config scan missed available vault credentials; an
absence claim must name its search scope.

## History-derived workload selection

A targeted AgentsView audit selected actual prior task shapes rather than a
random browser benchmark. Indexed coverage is partial. Its first query
unexpectedly started daemon discovery; the investigator issued no explicit
sync or configuration changes. Historical summaries supplement current indexed
messages and are not treated as fresh runtime verification.

| Historical task | Evidence pointer | Experiment implication |
| --- | --- | --- |
| Nested shadow input and Enter event recovery | 2026-09-27, session `01a0e396-ea29-7040-8ff6-441f685054df` | Assert input/change/keyboard events and visible app result |
| Auth succeeds despite guessed redirect wait timing out; mobile reader | 2026-10-01, session `01a0f58d-553f-7a62-9770-b6bd14d50953`, historical summary | Check actual signed-in state; exercise frames, viewport, navigation and persistence |
| Exact shopping variants and pooled reviews matter | 2026-10-04, session `eab89bc9-ede4-4733-86b6-688f4571a909` | Product/variant/price evidence, not generic product title |
| Empty HTTP-200 and irrelevant search results | 2026-09-19/20, session `01a0bcb8-8179-7bd3-b449-0b99e6a5abdf`, historical summary | Require relevant result destinations |
| Owned-service certificate failure | 2026-09-27, session `01a0e396-ea29-7040-8ff6-441f685054df` | Separate private-network denial, untrusted TLS, and process-scoped trust |
| Google embedded sign-in rejection followed by Gmail API access | 2026-09-26/27, session `01a0df92-2bee-70c3-a963-f0d590f00af2`, historical summary | Separate browser authentication from API authorization |

These findings justify forms/refs, storage isolation, mobile/frame behavior,
public search/shopping, scoped TLS, and bounded authentication trials. They do
not authorize accessing unrelated historical services or reproducing past
external writes. Mobile reader fidelity remains unqualified until the actual
viewport/frame/navigation/progress sequence is exercised.

## Development-build follow-up

Pinned main `bd9529418b7fa975b50eabeac415cfaaa865a588` is 128 commits beyond the
release in the inspected comparison. A separate locked render-only build
completed in 1m52s using the existing Rust/Cargo 1.96.0 toolchain. Its explicit
version is `0.2.4-post-bd9529418b`; a scratch-specific mise link keeps it separate
from the release selection. No SDK or system dependency installation was needed.

The installed `ask` could fetch release/branch sources but failed on the raw
commit spec. The installer used the official GitHub API tarball for the immutable
SHA and recorded its hash, Cargo.lock hash, exact build command, and binary hash.
This fallback is recorded rather than presenting an unsuccessful ask invocation
as a pinned source fetch.

The same fixtures were replayed, retaining release and main receipts separately:

| Guarantee | Pinned-main result |
| --- | --- |
| Old ref after refresh/removal | Fixed: old ref rejected and unintended target unchanged |
| Snapshot actionable refs | Fixed: refs included inline and current ref works |
| localStorage navigation/new tab | Fixed: value survives same-origin next page and tab |
| Independent-process state | Pass: fresh process has empty cookie/storage state |
| Missing-target keypress | Fixed: reports tool error |
| Shadow-root ordinary MCP control | Still limited: input omitted/unfillable |
| Iframe ordinary MCP control | Still limited: child loads but snapshot/control route omits fields |
| Playwright/CDP and agent-browser/CDP forms | Both pass bounded sequence |
| 390×844 viewport | innerWidth/innerHeight and matching CSS media query pass |

This proves those fixes on the tested development build. It does not qualify a
future release, touch/mobile identity, complete reader progress, production MCP
integration, retained authentication, or public sites on main. The main build
has rendering but no stealth transport; it does not inherit the separate
release+stealth site's authentication outcome.

## Consequences for the plan

1. Keep existing default browser routes. Installation is not adoption.
2. Name the exact runtime version/build and controller for each supported recipe.
3. Prefer the existing agent-browser/CDP surface for further evaluation where it
   meets the task; a new MCP controller needs to justify its extra maintenance.
4. Require application state after actions, fresh target inspection, and explicit
   handling of tool errors or success-with-no-effect.
5. Reject release MCP for the proposed stale-ref guarantee. Version-gate any
   later recipe on executed regression checks, not mutable upstream docs.
6. Treat authentication, storage retention, visual fidelity, and search APIs as
   separate qualifications. Do not promote them from one ordinary-form pass.
7. Use existing mise and chezmoi ownership if an installation is later adopted;
   no bespoke installer or persistent daemon is needed for CLI/CDP support.

Source pointers: [release source](https://github.com/h4ckf0r0day/obscura/tree/v0.2.4),
[pinned main](https://github.com/h4ckf0r0day/obscura/tree/bd9529418b7fa975b50eabeac415cfaaa865a588),
[agent-browser 0.38.2](https://github.com/vercel-labs/agent-browser/tree/v0.38.2).
