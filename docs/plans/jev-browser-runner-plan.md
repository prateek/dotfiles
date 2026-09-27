---
status: archived
doc_type: plan
owner: Prateek
created: 2026-09-26
updated: 2026-09-26
closed: 2026-09-26
current_guidance:
  - ../../agent-marketplace/packages/utils-agent/skills/browser-jev/references/jev.md
  - ../research/jev-browser-integrations.md
related:
  - ../adr/0033-skill-owned-jev-browser-runner.md
  - ../research/jev-browser-integrations.md
  - browser-skill-plan.md
status_detail: "Experiment completed: runner implemented and isolated headless Orca qualified; development comparison rejected adoption. Desktop execution, Linux launcher, and Pi invocation were not qualified."
---

# Jev execution inside the browser skill

Add an optional local execution loop to the existing `browser` skill. The
parent agent supplies a bounded task; Jev chooses the next action; the runner
executes through the browser the skill already selected. Orca and standalone
agent-browser share one interface and require separate qualification.

The goal is faster repetitive navigation and filtering with the same browser
ownership and verifiable results. Claude, Codex, and Pi must invoke one shell
entry point. The design decision is recorded in
[ADR 0033](../adr/0033-skill-owned-jev-browser-runner.md); upstream findings are
in the [research](../research/jev-browser-integrations.md).

## Experiment outcome

Implementation and the bounded development experiment are complete. The runner
worked through standalone agent-browser and an isolated headless Orca runtime,
but the measured candidate failed the adoption gate. In twenty matched pairs,
the parent browser loop completed 20/20 autonomously and parent-plus-Jev
completed 13/20. Scored median end-to-end time was 33.96 seconds for the parent
and 50.26 seconds for Jev, including fallback. Both arms recorded zero false
successes and forbidden effects. No holdout ran after this development failure.

Keep the runner experimental and the existing browser routing unchanged.
The [research findings](../research/jev-browser-integrations.md#matched-development-comparison)
record the workload, source boundary, and failure causes. Current execution
guidance belongs in the [skill reference](../../agent-marketplace/packages/utils-agent/skills/browser-jev/references/jev.md).
Desktop execution, a Linux launcher, and successful Pi invocation were not
completed in this experiment; the isolated Orca proof does not require those
claims. Any future performance experiment needs a separately defined workload
and a new development comparison, rather than tuning this result into a win.

## Starting evidence

On September 26, Orca 1.4.214 reported a reachable runtime. The current
`browser-skill-followups` worktree resolved by its explicit path and had no
browser tabs. The inherited `ORCA_WORKTREE_ID` named a different worktree:
resource selection must use the checked worktree identity, never that variable
alone or an implicit current tab.

The `AI_CLOUDFLARE_API_KEY` item is readable through the existing 1Password
service-account helper. Prateek added `account_id`, and the probe now reads
both fields directly into process memory. The earlier account-list request
returned HTTP 200 with an empty list; explicit account selection resolves that
discovery limitation.

The first two inference attempts returned HTTP 402, error 2021, for
insufficient balance. After Prateek funded the account, the synthetic probe
succeeded. The retained response at 2026-09-27 01:30:41 UTC (September 26
locally) returned `jev-1.13.0`, selected `CLICK` and the `filters` target, and
assigned confidence 1 to both. Choice membership and probability distributions
passed validation against the independently specified fixture answer.

The verified call used 495 input tokens and 67 output tokens and took 584 ms
at the client. This is one small API probe, not a browser latency benchmark.
The sanitized receipt is `build/jev-browser/cloudflare-smoke.json`; its saved
synthetic response is `build/jev-browser/cloudflare-smoke-response.json`.
Neither contains the credential or account value. No browser actions ran.

Cloudflare documents Jev at `POST
https://api.cloudflare.com/client/v4/accounts/{account_id}/ai/run`, with
`{"model":"typesafe/jev","input":{"state":...,"questions":...}}`.
The observed successful response nests the model payload at `result.result`,
with outer `success: true` and `result.state: "Completed"`. The probe initially
expected only one `result` layer; inspecting and validating the saved response
resolved that mismatch without another inference call. The production decoder
must check both success and completion before consuming answers. Non-completed
or unknown envelopes cannot authorize an action. The existing wrappers'
TypeSafe-direct clients are not interchangeable with this contract.
[Cloudflare Jev contract](https://developers.cloudflare.com/ai/models/typesafe/jev/).

The provider preflight establishes model access and the response contract.
Browser trials are recorded separately below. The earlier XHTML review
illustrates the design; its passing document tests do not establish runner or
browser integration behavior.

## Implementation evidence

Implementation is authorized. Keep the evidence for each boundary separate;
passing a provider or fixture test does not complete a browser qualification
or adoption gate.

| Boundary | Evidence as of September 26, 2026 | Remaining gate |
| --- | --- | --- |
| Cloudflare Jev | `jev-1.13.0` returned validated choices through the runner during real standalone and headless Orca trials | Broader task and confidence calibration |
| Offline contracts | Full `just test-node` passed 130 cases across Raycast, runner/provider/driver/process contracts, and fixture self-tests | Keep regression cases aligned with later runtime changes |
| Desktop Orca | Orca 1.4.214, bundled agent-browser 0.27.0: observation and Jev decision worked; input stopped with `window_not_focused`, zero actions | Attended action qualification; preserve the foreground guard |
| Headless Orca | Isolated Linux Orca 1.4.214: 3/4 tasks verified at default floor 0.85, with search handing back; 4/4 verified at explicit floor 0.60; 16 scripted driver cases produced expected outcomes | Paired Orca evaluation; desktop input and Linux launcher remain outside this qualification |
| Standalone agent-browser | Version 0.38.1: 20/20 split-question development trials verified at explicit floor 0.60; five per task family, zero forbidden effects | Matched baseline and holdout; default-floor reliability remains separate |
| Performance | Twenty matched development pairs rejected adoption: parent 20/20 autonomous versus Jev 13/20; scored medians 33.96 s versus 50.26 s | Holdout intentionally not run; a future experiment requires a new defined development workload |
| Published skill | Marketplace checks passed 52 cases and built the exported payload; copied-payload invocation passed in fresh Codex and Claude sessions; Pi stopped before invocation on OAuth refresh HTTP 401 | Pi invocation remains unverified; subsequent payload changes require their own build/export checks |

The [local findings](../research/jev-browser-integrations.md#local-implementation-findings)
record the development trials and their receipts. Codex/Claude smokes exercised
portable CLI invocation and malformed-job rejection; they did not drive a
browser or call Jev. Initial desktop Orca attempts returned control at the
focus guard: the owned worktree and page must be selected as well as the app
being frontmost. Separate headless Orca trials used an advertised runtime
capability and needed no desktop focus.

Target fingerprints and node tokens reject observed changes, including
same-label replacements and field-state changes. Validation and CLI dispatch
remain separate operations; the current adapter cannot prove an atomic
check-and-click. Restrict trials to qualified low-impact controls and keep
consequential writes in the parent workflow.

## Architecture and ownership

```text
Claude / Codex / Pi
  -> shared browser skill: select driver, identity, owned page, task scope
  -> run-jev: one JSON job, one bounded process
       observe -> build choices -> Cloudflare Jev -> validate -> execute
                   ^                                      |
                   +----------- fresh evidence -----------+
       -> Orca adapter -> page-scoped Orca CLI -> Orca browser
       -> agent-browser adapter -> named task session
  <- verified result or handoff with effect receipts
```

The skill owns tab/profile creation and cleanup. The runner borrows an explicit
page or session and never opens a replacement browser on failure. A handoff
returns to the parent on that same resource. A process-local claim, backed by
an exclusive lock for the selected page/session, prevents two runner jobs from
mutating it concurrently. It cannot lock out the user or another tool; detect
observable navigation/identity drift and hand back.

Use a small authored Node 24 runner with built-in HTTP and subprocess APIs.
That matches the repo's pinned Node runtime, supports cancellation without a
new SDK, and keeps the published skill runnable outside this checkout. Start
with no runtime npm dependencies. Forvela's browser interface and Ultrafast's
action bookkeeping are references; importing their session managers or
automatic completion/retry behavior would add work to undo.

Authored files under
`agent-marketplace/packages/utils-agent/skills/browser/`:

| Path | Responsibility |
| --- | --- |
| `SKILL.md` | Select a suitable bounded task after existing driver/identity routing |
| `references/jev.md` | Invocation, suitability, result interpretation, and handoff |
| `scripts/run-jev` | Portable launcher; resolve sibling files from its own path |
| `scripts/jev/cli.mjs` | Bind job, credentials, driver, cancellation, and cleanup |
| `scripts/jev/runner.mjs` | Job validation, loop, budgets, effect bookkeeping, verification |
| `scripts/jev/cloudflare.mjs` | Fixed provider endpoint, request/response validation, cancellation |
| `scripts/jev/dom.mjs` | Bounded observations, target identity, and declarative checks |
| `scripts/jev/process.mjs` | Literal subprocess calls, environment isolation, and browser claims |
| `scripts/jev/orca.mjs` | Decode real Orca results and execute page-scoped commands |
| `scripts/jev/agent-browser.mjs` | Same contract over an explicitly named session |

Keep boundaries small. Split another module only when it owns a distinct
contract. Never require the dotfiles checkout, a Pi extension, MCP registration,
or a particular parent model to execute a published job.

## Job and result contracts

`run-jev` reads one versioned JSON job from stdin. Stdout contains exactly one
JSON result; stderr contains bounded diagnostics with no secrets or raw page
content. Malformed jobs fail before browser or model I/O. The initial job
schema uses these fields:

```json
{
  "version": 1,
  "goal": "Show published entries matching orchard",
  "browser": {
    "driver": "orca",
    "worktree": "path:/absolute/task/worktree",
    "pageId": "page_from_orca"
  },
  "provider": { "kind": "cloudflare", "model": "typesafe/jev" },
  "limits": { "actions": 8, "decisions": 12, "elapsedMs": 60000 },
  "scope": {
    "origins": ["http://127.0.0.1:PORT"],
    "foregroundInput": false,
    "controls": [
      {
        "selector": "#filters", "operations": ["CLICK"],
        "expect": { "selector": "#filter-panel", "property": "visible", "equals": true }
      },
      { "selector": "#published", "operations": ["CHECK"] },
      { "selector": "#query", "operations": ["FILL"], "inputId": "query" }
    ]
  },
  "inputs": { "query": "orchard" },
  "checks": [
    { "selector": "#published", "property": "checked", "equals": true },
    { "selector": "#query", "property": "value", "equals": "orchard" },
    { "selector": "#result-count", "property": "text", "equals": "2" },
    { "selector": "#result-ids", "property": "text", "equals": "orchard-alpha,orchard-beta" }
  ]
}
```

IDs, selectors, and expected values above belong to a synthetic fixture. The
parent derives real task scope from the user's request and its inspection of
the page. It cannot use page instructions or a model risk score as authority.
The control descriptors bound what the runner may do; they are not a security
boundary against a compromised parent agent or hostile website JavaScript.
Origin checks restrict runner actions and provider submission; they do not
block website-initiated network requests.

The initial operation set is `CLICK`, `CHECK`, `FILL`, `SELECT`, `SCROLL`,
`WAIT`, `DONE`, and `HANDOFF`. Include only operations the current driver has
qualified. Omit arbitrary JavaScript, shell commands, uploads, and credential
entry. Navigation uses observed links within the supplied scope. The parent
handles login, unsupported widgets, and tasks needing visual judgment.

Jev answers an operation question and one target question for each available
operation in the same request. Target choices are complete candidate IDs;
each binds its operation to a captured browser target and any caller-supplied
input value. Only the target answer for the selected operation can execute.
The runner validates membership in that operation's candidate set, so separate
answers cannot create a new action. The model never supplies a CLI command,
selector, or free-form value. Missing input returns a handoff. Bind values to
the inspected field identity and operation, not just its label.

Results have `status: verified | handoff | failed`, a stable `reason`, browser
identity, verification evidence, action receipts, counters, and stage timings.
Use exit 0 for verified, 2 for a recoverable handoff, and 1 for invalid input or
an execution failure. A timed-out mutation always carries
`effect: unknown`, regardless of the result status.

Each action receipt records an action ID, observation generation, intended
operation/target, dispatch state, and observed effect. Preserve a receipt even
if the next observation fails. A model `DONE` initiates fresh independent
checks; missing or failed checks cannot produce `verified`. Checks are a small
declarative set of URL, visible text, and control-state assertions. UI checks
prove UI state; fixture-server assertions separately prove synthetic writes.

The initial runner has no automatic cross-process resume. If it exits without
a final result, the caller treats any possible dispatched effect as unknown.
The skill requires fresh inspection and reconciliation before starting a new
job. In-process receipts and a page lock do not provide durable idempotency.

Define settling through the same declarative predicates: `FILL`, `CHECK`, and
`SELECT` verify the intended field state; a `CLICK` requires a caller-supplied
`expect` predicate or a validated navigation destination. A scoped click can
execute only once per job. `SCROLL` supports the page viewport through `html`
or `body` and verifies its position change or reports a boundary; container
scrolling is unsupported. `WAIT` polls a supplied pending predicate. Missing
click postconditions require handoff. Final result checks
may wait for delayed updates within the remaining deadline. Implement only
fixed read-only predicate evaluators, never model-provided page JavaScript.

## Observe, decide, execute, verify

1. Validate the job and resolve the pinned executable. Check page-to-worktree
   or session ownership and acquire the local claim. Reject missing or
   unsupported capabilities before the first model request.
2. Observe the selected page. Check its exact origin before sending any page
   content to Jev; an initial mismatch or cross-origin redirect requires
   handoff. Normalize document identity, bounded text, controls, and current
   refs. Associate every candidate with one observation generation. If
   truncation hides needed context, hand back.
3. Intersect observed controls with the supplied task scope. Resolve selectors
   uniquely; duplicate matches and ambiguous fields require parent inspection.
   Send the bounded observation and eligible choices to Jev.
4. Validate the response shape, selected operation, and target membership in
   that operation's candidate set. Validate finite probabilities and confidence
   values. Both the operation and selected target must meet `confidenceFloor`,
   which defaults to 0.85 and accepts values from 0 to 1 for development trials.
   Tune thresholds on the development suite only and record the chosen value
   with every result. Confidence never grants permission.
5. For `DONE`, run fresh checks. For an action, recheck origin, page/document
   identity, and the target's applicable fingerprint. Discard a stale decision and
   re-observe within budget. Matching `@e7` or an identical label is insufficient.
6. Consume the decision once and record dispatch before execution. Pass argv
   directly to the driver process. Append the effect receipt before attempting
   the next snapshot. A lost response to a mutation means an uncertain effect;
   hand back with evidence and require reconciliation before another attempt.
7. Await the expected observable consequence, then re-observe. Count decisions,
   actions, recovery attempts, and elapsed time independently. Stop on the
   first exhausted limit, unsupported step, or repeated lack of progress.
8. Return the result and release the runner's claim. Preserve the borrowed
   browser on every exit; the parent skill cleans up resources it created.

Every HTTP request and browser subprocess receives the remaining run budget
and a per-call ceiling. Cancellation must terminate the subprocess tree and
abort HTTP, with a short bounded cleanup grace. Killing a CLI does not prove
its remote browser action stopped: return an uncertain receipt and prohibit
automatic replay. Allow at most one provider retry for a transport failure or
429/503 within the decision/time budget; never turn a retry into an unlimited
run. Start with no automatic retry of browser mutations.

The available Orca interface may leave a race between checking a target and
clicking it. Measure that behavior in the stale-DOM fixture. If stable target
identity or atomic validation is unavailable, restrict the initial lane to
qualified low-impact controls and return the rest to the parent. Do not claim
that taking two snapshots eliminates this race.

## Orca and credential qualification

Record the Orca app/CLI versions and its bundled agent-browser version. Capture
the real outer JSON envelope, inner snapshot structure, and errors on a local
fixture. The adapter must test both outer success and command-level success.
Every command carries the checked page ID. Resolve tab closure by page identity
through the current tab inventory; never reuse an old tab index for cleanup.

The [current Orca driver](../../agent-marketplace/packages/utils-agent/skills/browser/references/drivers/orca.md)
records two relevant limitations: raw `exec` does not forward stdin, and CDP
input can activate the window internally. Use typed commands for ordinary
nonsecret values; no generalized raw-command forwarding is part of this runner.
Page scoping does not establish background focus preservation.

The adapter binds the ready runtime ID, resolved worktree, profile, and page.
Only a ready graph with `desktopWindowStatus: "openable"` and advertised
`browser.headless.v1` permits input without foreground consent. The adapter
derives this requirement from CLI status, never page content, and rejects
runtime or capability drift. Desktop input still requires explicit foreground
scope and a focused document. Runtime placement belongs to the driver; a
harness does not select a different execution loop.

Run the first fixture in a task-owned Orca page/profile using a documented
background path. Confirm creation and each selected input operation preserve
foreground focus. If that path is unavailable, pause the affected live test
until the user grants a named foreground handoff. Browser/API authorization
already covers these trials; only a newly needed focus decision remains under
the [shared policy](../../agent-marketplace/packages/utils-agent/skills/browser/references/policy.md#focus).
Do not substitute Chrome to make an Orca gate pass.

Use the existing 1Password service-account helper to read the named credential
directly into a launcher process. Supply `CLOUDFLARE_API_TOKEN` and
`CLOUDFLARE_ACCOUNT_ID` to the runner without writing a secret file or putting
the token in argv. The runner removes provider credentials from every browser
child's environment. Keep the portable runner independent of 1Password; a
machine-specific provisioning reference can live in `secrets.toml` later.

The API preflight sends a synthetic state with an obvious expected choice. Verify
the actual HTTP status, response envelope, selected answer, resolved model,
and usage. Record only sanitized metadata. Send credentials exclusively to
the fixed Cloudflare HTTPS host and reject redirects. No page-controlled
provider URL is accepted. Start live browser trials with synthetic/public
content; authenticated private-page data requires an explicit task scope.

## Implementation phases and acceptance evidence

Each phase leaves a reviewable result. A phase may be complete while another
is blocked, but fake tests cannot substitute for its live evidence.

| Phase | Deliverable | Exit evidence |
| --- | --- | --- |
| 0. Qualify the interfaces | Disposable probes in ignored `build/jev-browser/`; sanitized contract examples | Real Cloudflare decision; real Orca snapshot/action receipts; explicit focus result and version matrix |
| 1. Build the smallest loop | CLI schema, provider, Orca adapter, two simple fixture tasks | Real Jev completes filter/search and a synthetic form through the selected Orca page; independent checks pass |
| 2. Make failures explicit | Cancellation, stale-state handling, receipts, handoffs | Contract and fault cases below pass, including no replay after uncertain mutation |
| 3. Add agent-browser | Second adapter behind the same job/result contract | Same fixture cases pass in an isolated named session; no implicit live-browser attach |
| 4. Measure and iterate | Paired benchmark, full attempt log, frozen holdout | Reliability and speed gates below pass, or documented rejection with the measured cause |
| 5. Package an opt-in lane | Skill guidance, plugin build/version change, rollout note | Exported payload works without dotfiles; Codex/Claude/Pi invocation smokes pass; current driver routing preserved |

Phase 0 should settle response shapes and target/focus capability before
freezing the schema. Use Node's built-in test runner. Keep tests at
`tests/node/browser-jev/` and fixtures at `tests/fixtures/browser-jev/`; extend
the root `node_tests` selection so `just test-node` includes them while
retaining the existing empty/skipped-suite failure behavior. Live suites are
explicit host/network selections and are never required by offline CI.

After runtime changes, run the focused contract tests and the affected live
cases. After skill changes, run the marketplace parser/build check and docs
validation. Bump only `utils-agent` when changing its published payload. Use
the [marketplace workflow](../../.agents/skills/agent-skill-management/SKILL.md)
for materialization; source edits do not refresh existing agent sessions.

## Tests that protect caller-visible behavior

| Case | Public seam and expected result |
| --- | --- |
| Invalid JSON, unsupported driver, no page, or missing verifier | Real CLI exits before effects; explicit reason |
| Cloudflare wire contract | Local HTTP boundary verifies model/input shape and nested `result.result` decoding; HTTP 200 with a non-completed or malformed envelope produces no action; real provider probe validates the recorded shape independently |
| Invalid/low-confidence choice or unavailable input | CLI returns handoff; fixture browser receives no mutation |
| False model `DONE` | Wrong query with the right result count still fails independent checks; never `verified` |
| Normal multi-step task | Real runner reaches independently specified fixture state and returns matching evidence |
| Duplicate labels, recycled ref, or DOM replacement | Wrong control is never accepted as the intended target; unsupported identity check hands back |
| Delayed results | Runner waits for the result condition within its deadline; no sleep-based success assertion |
| Click succeeds, next snapshot fails | Receipt retains the executed effect; this run never replays it and returns a reconciliation-required handoff |
| Mutation hangs or response is lost | Wall time is bounded; effect is unknown; zero automatic replay |
| 429/503, malformed JSON, authentication failure | Bounded retries only where specified; stable failure reason and no browser effects |
| Page or worktree disappears; another runner claims page | Explicit handoff/failure; no resource substitution and no closing borrowed tabs |
| Prompt injection or tempting unauthorized submit/delete | Choices stay within caller scope; fixture-server forbidden-effect counter remains zero |
| Unexpected cross-origin redirect | No subsequent mutation or provider-bound page content; handoff identifies the scope change |
| Login, CAPTCHA, unsupported widget, or focus requirement | Structured handoff on the same page |
| Secret canary and provider credential | Absent from browser-child environment, argv, traces, and result; logs remain bounded |
| Exported skill invoked elsewhere | Same stdin/stdout contract from a directory without the repo or APM cache |

Drive the real runner through HTTP/process boundaries for deterministic tests;
fake external I/O, not internal modules. Use a fake clock for pure budget cases
and one real subprocess deadline case. Use a fixture server's independent
state/event ledger as the oracle for local mutations. Inject provider failures
with a local server rather than provoking production rate limits.

Observe an intended failure before implementing each regression fix. Preserve
discovered counterexamples as behavior tests. Do not assert private function
names, incidental log wording, or a complete snapshot when a smaller semantic
assertion proves the guarantee. The requested real Orca/Jev path remains a
separate live gate.

## Benchmark and iteration loop

Freeze four task families before measuring: navigation to a named item,
search plus filtering, pagination/sorting, and a synthetic form using supplied
values. Create separate development and holdout variants with different text,
element order, and delays. Public-site smoke tests supplement the repeatable
fixtures; they do not replace them.

Compare the current parent-driven browser skill with Jev on the same driver,
profile, fixture reset, task, and verifier. Fix the parent model/effort and
browser/provider versions for a batch. Both arms receive the same task scope
and known inputs. Start timing before common setup and finish after independent
verification and task cleanup. Include parent inspection/job construction in
the Jev arm; do not hide the cost of producing its control descriptors.

Run five alternating paired repeats per task for the first signal (20 pairs
for four tasks). If promising, freeze the candidate and run ten new paired
repeats per holdout task. Randomize pair order using a recorded seed. Do not
tune prompts or thresholds against holdout results; a failed holdout becomes
development evidence and the next candidate needs a new holdout.

Record every attempt, including failures. Report verified completions, false
successes, unauthorized effects, handoffs, parent interventions, provider
calls/usage, and estimated provider cost. Report total elapsed time and each
stage's duration. A handoff counts as autonomous failure even when the parent
subsequently completes it. Preserve the runner's handoff reason separately
when a later parent fallback exhausts the enclosing task budget.

The adoption score uses `totalMs + fallbackMs`, including parent reconciliation
and completion through the existing skill. If the enclosing task timed out or
never reached an independently verified completion, charge at least the full
task budget: `max(taskBudgetMs, totalMs + fallbackMs)`. Apply that floor once
to the combined duration. A verified fallback can finish the task, but cannot
turn a handoff into autonomous success. Retain observed combined time,
primary-attempt timing, and warm execution as separate diagnostics; none
replaces the scored end-to-end measure. Show paired outcomes so a lower median
cannot hide dropped hard cases. The [receipt evaluator](../../scripts/eval/browser-jev.mjs)
implements this contract without running a browser or model.

The proposed adoption gate is at least 2x lower median scored end-to-end time across
the frozen workload, no lower verified-completion count than the baseline,
and zero false success or unauthorized effects in the fixture suite. Inspect
per-task medians and tail cases before attributing the aggregate win. These
are product trial criteria, not a statistical claim of general reliability.
Passing justifies an opt-in lane. Changing the default requires a later
decision backed by broader tasks.

For each iteration:

1. Classify the largest failure or delay: observation, provider choice,
   driver execution, verification, or parent handoff.
2. State one hypothesis and the expected observable improvement.
3. Add the smallest regression/example that distinguishes it, then change
   one factor: candidate encoding, context size, waiting, or driver overhead.
4. Run focused checks and the development cases affected by that change.
5. Keep or revert using verified outcomes and timing. Record the candidate
   revision, configuration, and rejected attempts.
6. Re-run the frozen comparison only when the candidate is ready to adopt.

Keep traces in ignored scratch with synthetic inputs. Persist sanitized
findings and the adoption decision in the research doc. Do not optimize away
freshness, authorization, or independent verification to meet the speed target.
If Orca command overhead dominates, measure it before proposing a persistent
transport. Ultrafast's different Chrome/CDP setup is a useful reference, but
its reported timing is not a matched Orca baseline.

## Rollout and work checklist

Initially expose Jev only when the parent explicitly selects it for an eligible
task. Unsupported or failed jobs return to the existing browser skill on the
same page. Rollback is removal of that optional delegation; no browser/profile
migration is required. Test the published entry point from fresh Codex, Claude,
and Pi sessions. Their smokes prove invocation portability; benchmark claims
apply only to the harness/model combinations actually measured. Current host
evidence covers the macOS launcher, offline tests, and standalone browser.
The headless Orca trials used that macOS launcher to control an isolated Linux
browser runtime; they do not qualify a Linux launcher. Launcher, subprocess
cancellation, and driver checks remain separate requirements for each host.

- [x] Inspect current skill/CLI contracts and upstream designs.
- [x] Confirm Orca runtime and explicit worktree identity.
- [x] Locate the existing Cloudflare credential without exposing its value.
- [x] Read the new Cloudflare account ID and execute a synthetic inference probe.
- [x] Verify a successful synthetic Jev response after funding; confirm `jev-1.13.0` choices and the nested response envelope.
- [x] Qualify headless Orca observation and CLICK/FILL/CHECK/SELECT/viewport SCROLL on task-owned synthetic fixtures, including lost mutation replies.
- [ ] Qualify desktop foreground behavior before claiming desktop execution; qualify a Linux launcher separately if supported.
- [x] Implement the bounded runner and independent verification.
- [x] Pass deterministic fault tests and real headless Orca/Jev task scenarios.
- [x] Qualify standalone agent-browser on synthetic tasks at the explicit development confidence floor of 0.60.
- [x] Complete development iterations and twenty matched development pairs; record the rejection of adoption.
- [ ] Run a frozen holdout only after development passes; not run for this rejected candidate.
- [x] Package the optional runner and verify copied-payload invocation in fresh Codex and Claude sessions.
- [ ] Verify Pi invocation; its OAuth refresh failed before the runner was called.

For plan and ADR changes, run `just test-docs-lifecycle` and `git diff --check`.
Run runtime/package checks at the implementation phases above and record their
results in the evidence ledger. An unchecked live gate remains open even when
the offline suite passes.
