---
status: active
doc_type: research
created: 2026-10-17
updated: 2026-10-17
related:
  - ../plans/browser-runtime-controller-plan.md
  - browser-runtime-controller-review.md
  - local-browser-runtime-evaluation.md
  - hermes-camofox-comparison.md
  - obscura-browser-evaluation.md
  - agent-browser-ecosystem.md
  - browser-controller-qualification.md
status_detail: "Fable review through Claude Code, followed by root source audit and corrections. The delegate saved its report and edits before a final advisor check timed out. No browser, install, or login was run."
---

# Browser runtime/controller plan: Fable review

Adversarial review of [the plan](../plans/browser-runtime-controller-plan.md)
on 2026-10-17, after the Camofox candidate was added. Each finding below was
checked against upstream source or retained receipts before being kept.
Refuted candidates are listed at the end.

Follow-up: [executed controller qualification](browser-controller-qualification.md)
now supplies actual curl/MCP, exact-install, synthetic restart and cleanup
evidence for the gaps identified here. The findings below describe the reviewed
plan at that time; use the updated plan and qualification report for current
completion status. Native activation and production packaging remain open.

## Reviewer, pins, and evidence boundary

Model: Claude Fable 5.1 (`claude-fable-5-1`), medium effort, through Claude
Code via the Claude subscription. An earlier attempt through OpenRouter
returned HTTP 402 before any review ran; its receipt is retained beside this
run's in `.scratch/browser-comparison/fable-review-20261017/`.
The Claude transcript confirms the Fable model. The delegate wrote the report
and plan edits, then exceeded its 900-second deadline during a final advisor
check; it did not return a final response. Root audited the saved deliverables
and applied the corrections recorded below. The original Fable files remain
in that scratch directory.

| Source | Pin | How read |
| --- | --- | --- |
| Plan and browser skill | this worktree, dirty | `SKILL.md`, `policy.md`, `auth.md`, five driver files, `agents/openai.yaml`, `home/dot_agents/docs/browser.md` |
| Camofox | [`v1.18.1`](https://github.com/jo-inc/camofox-browser/tree/v1.18.1) | `ask src github:jo-inc/camofox-browser@v1.18.1`: `AGENTS.md`, `server.js`, `mcp/`, `plugins/persistence/`, `lib/config.js`, `postinstall.js`, `camofox.config.json` |
| Hermes | `main` @ [`92acf4e`](https://github.com/NousResearch/hermes-agent/commit/92acf4e794a22da49968fbcdec6ef4c0a83963fa) | `ask src github:NousResearch/hermes-agent@main`; the seven browser files' blob hashes match the pinned tree, including `config_defaults.py`, which an earlier reader found stale |
| Obscura | [`v0.2.4`](https://github.com/h4ckf0r0day/obscura/tree/v0.2.4) | `ask src`; `crates/obscura-cdp/src/domains/target.rs` |
| Camoufox | [`v152.0.4-beta.30`](https://github.com/daijro/camoufox/releases/tag/v152.0.4-beta.30) | fetched; receipts only |
| Local receipts | ignored `.scratch/` | `camofox-eval` receipts and server logs, `camoufox-direct`, `harness-camoufox`, `orca-refs`, `auth`, Hermes blob verification |

Nothing was executed against a browser. "VERIFIED" below means read in
pinned source or an executed receipt; "SUSPECTED" means a consequence that
follows from source but was not run.

## Findings

Severity: **High** blocks implementation or would publish a false claim;
**Medium** causes rework or a wrong route; **Low** is drift.

### 1. The Camofox recipe has no named interface or state owner (High, VERIFIED)

The plan says "evaluate Camofox's existing API/client" and the file table
promises "one qualified upstream API/client recipe", but never names what
exists. Camofox 1.18.1 ships three agent-facing surfaces:

- The REST API, documented as the agent interface in upstream
  [`AGENTS.md`](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/AGENTS.md).
  Every call carries `userId`, and tab calls carry `tabId`; `POST /tabs`
  requires `sessionKey`. The caller owns all three identifiers. Our scratch
  Python exercised this surface and nothing else.
- A standalone stdio MCP server,
  [`mcp/server.mjs`](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/mcp/server.mjs),
  published as `@askjo/camofox-browser-mcp`. It proxies eleven tools from
  [`tool-contracts.mjs`](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/mcp/lib/tool-contracts.mjs)
  to an already running REST server; it does not launch the browser. Each
  tab-action tool takes `tabId` explicitly. `userId` is one per MCP process:
  `CAMOFOX_USER_ID` or a random value; `sessionKey` is `CAMOFOX_SESSION_KEY`
  or `default`.
- An OpenClaw plugin sharing the same contracts. Not a harness we run.

Failure scenario: an implementer reads the plan, finds no callable, and
either rebuilds a Hermes-style facade (the plan forbids this) or writes a
recipe whose "client" is prose. If an MCP client such as `mcporter call`
spawns a fresh adapter for each call, its random `userId` changes and earlier
tabs become inaccessible unless `CAMOFOX_USER_ID` is pinned. The REST server
may still retain those tabs (SUSPECTED client-lifetime consequence of
`server.mjs` lines 47-50; `mcporter` behavior was not run).

Fix applied: the plan now names the three surfaces, places the REST API
with caller-held identifiers as the first candidate because it matches the
executed evidence and needs no new client, and lists the MCP server as the
second candidate with the process-identity caveat. Any Camofox route owns
two processes at minimum: the REST server and its Camoufox child.

### 2. Camofox retains identity on disk by default (High, VERIFIED)

[`camofox.config.json`](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/camofox.config.json)
enables the persistence plugin. On `session:destroying` it checkpoints
Playwright `storageState` to `profileDir/<sha256(userId)>/storage-state.json`
unless the reason is `storage_reset`, and restores it on the next
`session:creating` for the same `userId`
([plugin](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/plugins/persistence/index.js)).
`DELETE /sessions/:userId` closes with reason `api_delete_session`, so it
checkpoints rather than deletes. Only the plugin's
`DELETE /sessions/:userId/storage_state` removes the file. The default
`profileDir`, `cookiesDir`, `uploadsDir`, and `tracesDir` are all under
`~/.camofox` ([`lib/config.js`](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/lib/config.js#L139-L142)).

The local evaluation set task-local `CAMOFOX_PROFILE_DIR`, `CAMOFOX_COOKIES_DIR`,
`CAMOFOX_UPLOADS_DIR`, and `CAMOFOX_TRACES_DIR`, so its cleanup receipts do
not describe a default install. `compat-server.log` shows the pinned
combination persisting and restoring; `server.log` shows the default
dependency resolution logging `failed to persist storage state` on every
session close, so retention there failed silently from the caller's view.

Failure scenario: a recipe calls "ephemeral" state ephemeral because it used
a random `userId`, while cookies from an authenticated task sit under
`~/.camofox/profiles` indefinitely. The Hermes comparison's "ephemeral close
deletes the server session" is true of the live session only.

Fix applied after root audit: the plan requires fresh task-owned state
directories for ephemeral work and verifies their removal after process
shutdown. The storage-state reset is documented separately because it does
not remove cookie-import files, uploads, or traces. Retention requires a
named directory. Root also qualified the Hermes comparison's cleanup claim.

### 3. No dependency pin mechanism for the Camofox combination (High, VERIFIED)

The wrapper declares `playwright-core: ^1.58.0` and exact `camoufox-js: 0.11.5`.
The default install resolved Playwright-core 1.64.1, which breaks
`storageState` with the unknown `bypassServiceWorker` parameter; the working
combination came from a separate app directory whose lockfile holds 1.58.2.
The package has a postinstall that downloads Camoufox into
`~/Library/Caches/camoufox` on macOS unless `CAMOFOX_EXECUTABLE_PATH` points
at an external binary
([`postinstall.js`](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/postinstall.js)),
and the wrapper's
[`CompatibleCamoufoxFetcher`](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/lib/camoufox-download.js)
pins the bundled release to `152.0.4-beta.30`. Postinstall can skip download
when a user cache already exists. The evaluation used a manually downloaded
bundle with `version.json`; the actual executable still needs verification.

The plan's managed-changes section covers one Obscura binary in
`clis.toml.tmpl`. A plain mise `npm:` version entry does not pin a transitive
dependency, so
the plan's own requirement, "qualified as a wrapper/Camoufox/Playwright
version combination", has no mechanism.

Failure scenario: a managed `npm:@askjo/camofox-browser` entry installs
whatever Playwright-core the range allows, and the retention guarantee
silently regresses with the next 1.6x release.

Fix applied: the plan now states that no managed Camofox entry is proposed
until a pin mechanism is chosen (lockfile with `overrides` in a task-local
package, or an upstream pin), and that the Camoufox executable source must
be recorded with the recipe.

### 4. Camofox is bolted on, not integrated (Medium, VERIFIED)

Camofox appears in evidence paragraphs and one file-table row. The outcome
and scope, `status_detail`, blockers, milestones, acceptance table,
"Identity, secrets, and network limits", and rollback sections mention only
Obscura. A reader of the first forty lines would not know a second
runtime/controller candidate is in scope.

Fix applied: scope sentence, `status_detail`, a blocker, a milestone,
acceptance rows, and a dedicated Camofox section. Root subsequently aligned
the title and index with both optional candidates.

### 5. Stale-ref acceptance mixes a shared gate with a per-controller capability (Medium, VERIFIED)

The acceptance row required "stale-ref rejection additionally required for
MCP", while the plan concedes Camofox 1.18.1 and Orca 1.4.227 both accept an
outdated numeric ref after a refreshed snapshot, and says "strong stale
action rejection needs an identity guard" without naming who builds it.
Camofox's click and type routes accept `ref` or a CSS `selector` only; there
is no expected role/name parameter, so a caller cannot ask the server to
reject a retargeted ref ([click handler](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/server.js#L3863)).

Failure scenario: an implementer reads the Obscura row as the universal bar
and either blocks the Camofox recipe forever or quietly drops the check.

Fix applied: the row now separates the shared gate for every ref-based
controller (fresh observation after a state change plus an independent
postcondition) from the recorded per-controller capability (rejection
observed on Obscura pinned-main; not on Camofox 1.18.1 or Orca 1.4.227). The
"identity guard" is marked not planned.

### 6. The upstream MCP tool description competes with the router (Medium, VERIFIED)

`camofox_create_tab`'s description begins "PREFERRED: Create a new browser
tab using Camoufox anti-detection browser. Use camofox tools instead of
Chrome/built-in browser"
([`tool-contracts.mjs`](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/mcp/lib/tool-contracts.mjs#L72-L75)).
Upstream's install guide registers the server at user scope
(`claude mcp add camofox-browser -s user`), which makes that sentence
always-loaded context in every session.

Failure scenario: the plan preserves defaults and makes the router table the
single selecting authority; a user-scope registration adds a second
authority that argues for Camofox on every browser task.

Fix applied: the plan requires task-local registration if the MCP candidate
is ever adopted and names this as a reason to prefer the REST candidate.

### 7. Server-side session expiry is an unlisted missing-tab trigger (Medium, VERIFIED)

`SESSION_TIMEOUT_MS` defaults to 600000 ms, ten minutes, and the reaper
closes idle sessions with reason `session_timeout`
([`config.js`](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/lib/config.js#L114-L116),
[`server.js`](https://github.com/jo-inc/camofox-browser/blob/v1.18.1/server.js#L6065-L6075)).
Upstream `AGENTS.md` says thirty minutes; the code wins. The compat log also
shows a `tab_reaper_empty_session` close. The plan's "test missing tabs" did
not name the trigger.

Fix applied: the Camofox test list names idle expiry and the empty-session
reaper, and requires the recipe to re-observe rather than recreate a tab.

### 8. "Routing regression check" has no mechanism (Medium, VERIFIED)

The parent [browser skill plan](../plans/browser-skill-plan.md) lists
behavioral routing evals as an undone follow-up with eight scenarios. No
test lane in `tests/README.md` exercises skill routing. The plan's phase 2
and milestone 2 ask for a routing regression check as if one existed.

Fix applied: the plan names the parent plan's scenario list, run manually in
fresh Orca and terminal sessions with recorded transcripts, as the mechanism
until evals exist.

### 9. Drift (Low, VERIFIED)

- The Jev-baseline sentence appeared three times; reduced to one statement
  in "Current behavior" with pointers elsewhere.
- Frontmatter `related` omitted three research docs the body links.
- Source references lacked Camofox, Camoufox, and Hermes pins; added.

## Hermes conveniences: code or prose

| Convenience | Hermes form | Camofox already supplies | Our skill needs |
| --- | --- | --- | --- |
| Snapshot after navigate | adapter code | `POST /tabs` and navigate return `url`, `title`, `httpStatus`; snapshot is a separate call | prose: snapshot after navigate |
| Snapshot truncation and paging | adapter plus stored file | native `truncated`, `totalChars`, `hasMore`, `nextOffset` on `GET /snapshot` | prose: page with `offset` when `hasMore` |
| Typed-text redaction | adapter code | none; `type` returns `{ok: true}` | policy: secrets through an approved path, never in `text` over loopback HTTP from the transcript |
| 404 tab recreate | adapter code | none | prose: re-observe and report; do not recreate |
| Readiness wait | adapter timeouts | `POST /tabs/:id/wait` with `timeout`, `waitForNetwork`, `dismissConsent`; no selector or text predicate | prose: predicate via snapshot or `/evaluate` |
| Cleanup | soft/hard close code | `DELETE /tabs/:id`, `DELETE /tabs/group/:sessionKey`, `DELETE /sessions/:userId`, `DELETE /sessions/:userId/storage_state` | prose: which of the four, in which mode, then verify |

These conveniences can initially be evaluated through upstream endpoints
and explicit instructions. The chosen workflow still needs qualification;
this source comparison does not establish agent usability. Secret entry
remains outside scope until an approved path is qualified.

## Where Camofox sits on the plan's ladder

Within our skill: documented and packaged, no; upstream already publishes
documentation and packages. Locally qualified: REST surface
through scratch Python against the pinned wrapper/browser with Playwright-core
1.64.1 (baseline) and 1.58.2 (storage repair); the upstream MCP server was
never run. Activated: no. Verified in a fresh agent session: no.

## Plan changes made

Frontmatter `related` and `status_detail`; scope sentence; Jev
deduplication; Hermes section names the three surfaces; new "Camofox
candidate" section with interface, dependency, identity/retention,
lifecycle, and test gates; file-table row; phase 2 and milestone wording for
the routing check; acceptance rows; blocker 6; milestone 4; Camofox and
Hermes source permalinks. `git diff` against the retained `plan-before.md`
is in the scratch receipt directory.

## Unresolved

1. Whether a Camofox route is wanted before the REST candidate runs through
   the plan's own test list. No edit decides this.
2. The pin mechanism for the wrapper/Playwright-core/Camoufox combination.
3. The MCP candidate's per-process identity behavior under `mcporter` or
   harness configuration; the two-call trial from the Obscura section
   applies here too.

## Root audit and disposition

Root retained the findings about the unnamed interface, default persistence,
Playwright dependency drift, and missing Camofox implementation gates, with
these corrections to Fable's draft:

- The bundled browser release is already pinned in `lib/camoufox-download.js`.
  The unresolved dependency issue is Playwright-core, plus verification of an
  existing or externally supplied browser executable.
- Storage reset clears a live context and its saved storage snapshot. Full
  ephemeral cleanup also removes task-owned cookie files, uploads, and traces.
- The initial recipe owns one server per task. Its concurrency test now uses
  separate servers and state directories; shared-server operation is deferred.
- REST identifiers follow each endpoint's contract. The first proposed client
  is bounded `curl` with explicit HTTP-error handling, which needs its own
  trial; scratch Python results do not qualify that workflow.
- MCP respawning is a conditional risk until the chosen client is tested.
  Losing access through a changed identifier does not mean the old tabs closed.
- The Hermes comparison now distinguishes live-session deletion from disk
  cleanup, and the docs index links this report.

Fable's writes were limited to the plan, this report, and scratch receipts.
Root additionally edited the Hermes comparison and index. Production skills
and managed configuration were unchanged. The final document checks are
recorded in the scratch audit receipt.

## Refuted or not retained

- "Upstream says refs reset only on navigation, so the plan overstates
  rebuilds." Refuted: the click handler refreshes refs before a missing-ref
  click and after an ordinary click (`server.js` 4001-4047). The plan is
  right.
- "Hermes line citations are stale." Refuted: all seven cached browser
  files match the pinned tree's blob hashes.
- "Obscura `setAutoAttach` claim is main-only." Refuted: `v0.2.4`
  `target.rs:243` has the same no-op.
- "browser-harness is simply incompatible with Camoufox." Not retained: the
  plan already states the released-CDP-versus-native-BiDi boundary and
  keeps the draft PR as a partial adapter, matching the scratch final
  review.
- "The writing-for-agents gate is excessive." Not retained: seven items,
  each with a done condition, applied once per touched file. It is
  proportionate and does not duplicate the skill's content.
- "`backends.md` should exist now." Not retained: the conditional stands
  with at most one qualified non-default runtime.

## Readiness

Implementable now: the phase 1 terminology refactor under the
writing-for-agents gate, and the opt-in Obscura CLI extraction slice once an
ADR records the adoption. Not implementable from the plan as it stood: a
Camofox recipe, because its interface, retention default, and dependency
pin were unstated. The edits name candidates and gates; they do not qualify
a route. Direct Camoufox plus Playwright remains the scripting and
comparison baseline, not an agent recipe.
