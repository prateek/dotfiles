---
status: active
doc_type: research
created: 2026-09-26
updated: 2026-09-27
related:
  - ../plans/browser-skill-plan.md
  - ../plans/jev-browser-runner-plan.md
  - ../plans/jev-deterministic-preparation-plan.md
  - ../adr/0035-separate-experimental-jev-browser-skill.md
status_detail: "Source assessment, isolated headless Orca qualification, and a completed development comparison that rejected adoption. The runner remains experimental."
---

# Jev browser integrations

The skill-owned Jev runner can control Orca, but the measured development
candidate was slower and completed fewer tasks autonomously than the existing
parent-driven loop. Keep it experimental and preserve the existing browser
router and session ownership. The evidence does not justify adoption or a
default change.

The Jev runner now lives in the separate portable `browser-jev` skill, which
reads the regular `browser` skill's policy and driver guidance. Claude, Codex,
and Pi can invoke the same shell/JSON runner through that experimental skill.
Native Pi extensions are discovery leads and implementation references; their
host bindings are outside the proposed adoption scope. Ajevt's completion
handling is worth evaluating behind a portable wrapper. Forvela offers a CLI,
and jev-ultrafast remains the performance reference. The follow-up
[implementation plan](../plans/jev-browser-runner-plan.md) tracks a small
authored runner with Orca and agent-browser adapters and the Cloudflare provider.

The initial review used upstream documentation, GitHub metadata, and selected
execution-loop source on September 26, 2026. That source review preceded local
implementation and model calls. Upstream timing claims below belong to their
authors; local trial evidence is recorded in the implementation findings at
the end of this document.

Jev selects typed answers from supplied choices. A browser loop can send page
text and current controls, receive an operation and target, execute through its
driver, and repeat without a parent-agent turn for every click. Jev accepts text
only; a parent agent or separate generative model still supplies free-form text
and visual reasoning. This makes navigation/filtering a plausible fit, while
visual UI review still needs the existing tools.
[TypeSafe model description](https://docs.typesafe.ai/concepts/system-one).

The popularity is real as a point-in-time observation: GitHub's API reported
20,509 stars for `browser-use/jev-ultrafast`, created September 16, and 555 for
`wy-coliney/jev-browser-use`, created September 18. These are young repositories;
star counts establish attention, not reliability.
[Browser Use metadata](https://api.github.com/repos/browser-use/jev-ultrafast),
[Codex adapter metadata](https://api.github.com/repos/wy-coliney/jev-browser-use).

| Candidate | What it adds | Assessment for this repo |
| --- | --- | --- |
| [browser-use/jev-ultrafast](https://github.com/browser-use/jev-ultrafast/tree/1231850a0bf1a0c0341fe408ef1668dbbfdfac46) | Jev action selection, separate typing model, Browser Harness connection to existing Chrome | Best reference implementation and measurement report. Its live-profile ownership and limited DOM support make it unsuitable as an automatic replacement for isolated sessions. |
| [forvela/jev-agent-browser](https://github.com/forvela/jev-agent-browser/tree/b4d4e0284a4b0336f12831ef6fe64ba5d29b1efb) | Delegated loop over agent-browser, supplied input values, injected browser adapter, CLI flag forwarding | Existing portable CLI and useful adapter interface. Needs action authorization and independent verification. |
| [jal-co/jev-agent-browser](https://github.com/jal-co/jev-agent-browser/tree/db88ece0513e9f43d495f3562d06dfbcbbbc9543) | Python adapter with parent-agent typing handoffs and DOM freshness checks | Useful implementation reference. Missing safety-flag passthrough and typed-text history handling are concrete integration gaps. |
| [wy-coliney/jev-browser-use](https://github.com/wy-coliney/jev-browser-use/tree/cf7e76607d4ec70592b24becadd0296dcda8177a) | Continuous action loop using the Codex Computer Use connection | Its runtime coupling excludes it from the shared skill's initial runner shortlist. Claude browser support is still described as forthcoming. |
| [jkudish/jev-browser](https://github.com/jkudish/jev-browser/tree/7b9adab7f7535e93d5d1f93b00cc7f46d594fbc1) | Playwright CLI/MCP/library, optional typing provider, borrowed Page support | Convenient isolated smoke-test candidate. Its loop lacks a caller authorization callback and an independent completion predicate. |
| [tontoko/jev-browser](https://github.com/tontoko/jev-browser/tree/c2d5461475fe2952ac3eab3e9cf2e00dd899ebd4) | Playwright SDK/CLI/MCP with action/command hooks and caller assertions | Strongest policy and verification interface of the reviewed candidates. Consider as a design reference or isolated trial; adopting its full session stack would increase integration scope. |

The Browser Use performance report is unusually clear about its boundaries.
Its 7.073-second Flights run excludes browser setup, initial navigation, and the
fresh independent post-run check. Six alternating attempts compared two
versions of the same Jev runtime: both passed three times, with median time
falling from 9.450 to 7.092 seconds. That is a runtime optimization result;
it does not measure Jev against this repo's parent-driven browser loop. The
report also records a failed development attempt and explicitly limits the
claim to one task/profile.
[Pinned performance report](https://github.com/browser-use/jev-ultrafast/blob/1231850a0bf1a0c0341fe408ef1668dbbfdfac46/docs/performance.md).

The Codex adapter's advertised 5–10x improvement is an approximate result from
the author's product workflows, excluding server processing. Forvela has a
17-second walkthrough and says reproducible wrapper benchmarks remain future
work. Neither establishes performance on Prateek's tasks.
[Codex adapter evidence](https://github.com/wy-coliney/jev-browser-use/blob/cf7e76607d4ec70592b24becadd0296dcda8177a/README.md),
[Forvela evidence](https://github.com/forvela/jev-agent-browser/blob/b4d4e0284a4b0336f12831ef6fe64ba5d29b1efb/README.md).

Current direct TypeSafe pricing is $0.042 per million input tokens, with free
output tokens. At that rate, 100,000 input tokens cost $0.0042. This is decision
model cost only; parent-agent work and browser overhead remain. TypeSafe says
requests are not used for training and describes enterprise ZDR separately.
Sending page observations still adds a data recipient, which matters for
authenticated work pages.
[Pricing and data handling](https://docs.typesafe.ai/models).

The source review found adoption blockers beyond package installation:

- Forvela's loop invokes `browser.action` directly after checking action shape
  and repetition. It has no per-action authorization callback in the reviewed
  implementation. A generic `CLICK` can submit or delete. It reports success
  from `goal_reached >= 0.8`, with another weaker heuristic path, so callers
  must independently verify completion. Its parser records probabilities but
  the execution loop does not gate clicks on operation/target confidence.
  [Loop](https://github.com/forvela/jev-agent-browser/blob/b4d4e0284a4b0336f12831ef6fe64ba5d29b1efb/src/loop.js),
  [decision parsing](https://github.com/forvela/jev-agent-browser/blob/b4d4e0284a4b0336f12831ef6fe64ba5d29b1efb/src/decision.js).
- Jal-co's command builder forwards session/restore options but offers no
  general safety-flag passthrough. Its agent records typed text in history,
  and the next policy request includes recent history's text. Parent-generated
  text therefore is not automatically private from the decision provider.
  [Driver](https://github.com/jal-co/jev-agent-browser/blob/db88ece0513e9f43d495f3562d06dfbcbbbc9543/src/jev_agent_browser/browser.py),
  [history](https://github.com/jal-co/jev-agent-browser/blob/db88ece0513e9f43d495f3562d06dfbcbbbc9543/src/jev_agent_browser/agent.py),
  [request construction](https://github.com/jal-co/jev-agent-browser/blob/db88ece0513e9f43d495f3562d06dfbcbbbc9543/src/jev_agent_browser/policy.py).
- TypeSafe documents susceptibility to adversarial state, irrelevant context,
  numerical reasoning, and date comparisons. Constrained output does not make
  a selected action trustworthy. Keep calculations and authorization in code;
  let the parent handle ambiguous interpretation.
  [Vendor-documented limitations](https://docs.typesafe.ai/model-jaggedness/jev-1.13).

Tontoko is a useful exception to the missing-policy-hook pattern. It documents
`allowAction` and `allowCommand` hooks requiring literal `true`, caller-supplied
assertions, and distinct verification provenance. Those hooks do not control
website scripts or browser networking. Its verification report makes no
comparative speed/cost claim and separates synthetic live tests from general
site accuracy. These are promising interfaces, with local runtime proof still
needed.
[Policy contract](https://github.com/tontoko/jev-browser/blob/c2d5461475fe2952ac3eab3e9cf2e00dd899ebd4/SECURITY.md),
[Verification evidence](https://github.com/tontoko/jev-browser/blob/c2d5461475fe2952ac3eab3e9cf2e00dd899ebd4/docs/verification.md).

Jkudish's source accepts an injected Playwright Page but has no corresponding
authorization or independent-completion callback in `NavigateOptions`.
`submit_` executes an effect and model decisions can end the run as done.
Disabling typing therefore does not turn it into a read-only executor.
[Navigation implementation](https://github.com/jkudish/jev-browser/blob/7b9adab7f7535e93d5d1f93b00cc7f46d594fbc1/src/navigate.ts).

The `vlad-terin/jev-browser` repository returned 404 during review. A surviving
`jasonduncan/jev-browser` copy still points at that upstream; its authority as a
successor is unclear. Its evaluation report explicitly labels the two-trial
prototype comparisons as historical rather than packaged-runtime evidence.
Keep it as background reading rather than an adoption candidate.
[Surviving evaluation report](https://github.com/jasonduncan/jev-browser/blob/main/evals/README.md).

For the current [browser router](../../agent-marketplace/packages/utils-agent/skills/browser/SKILL.md),
the integration would be an optional decision loop beneath the router. Orca
must retain its page/profile ownership; outside Orca, agent-browser must retain
the task session and command flags. Forvela's injected `snapshot`/`action`
interface made an Orca adapter plausible; the source review did not verify a
working adapter.
An adapter must enforce the existing action policy before each effect, return
to the parent when uncertain, and treat model completion as a request to verify.
This source-review proposal led to the local implementation described below.
[Injectable browser interface](https://github.com/forvela/jev-agent-browser/blob/b4d4e0284a4b0336f12831ef6fe64ba5d29b1efb/src/browser.js),
[local Orca contract](../../agent-marketplace/packages/utils-agent/skills/browser/references/drivers/orca.md).

A useful next experiment would compare the existing parent-driven loop with
Jev over the same driver on public navigation/filter tasks and controlled local
forms. Include duplicate labels, delayed results, a DOM replacement between
selection and click, and an unsupported control that must hand back. Add a
fixture with an attractive but unauthorized submit/delete button and injected
page instructions. Use five repeats per task, pinned versions, and record all
failures and fallback time. Count verified completions, parent interventions,
provider cost, and end-to-end duration including setup and verification; also
report the warm action loop separately.

My proposed trial threshold is at least 2x lower median end-to-end time on
repetitive tasks, no loss of verified completion in the paired sample, and no
unauthorized actions or false success reports in the fixtures. Passing would
justify an opt-in lane and broader evaluation. It would not establish general
reliability or authorize a default change.

The [awesome-pi catalogue](https://github.com/shaftoe/awesome-pi-coding-agent/tree/f1a9ddd571fbcf51e187a3e92eba369c0a97c028)
is a discovery source, not a qualification list. Its September 26 snapshot lists
12,868 resources, including 10,015 extensions. Its pipeline gathers candidates,
filters relevance, deduplicates, classifies, and renders entries; those stages
do not establish browser behavior. This follow-up filtered browser/Jev entries
and traced selected packages through npm metadata to their upstream source.
[Pipeline architecture](https://github.com/shaftoe/awesome-pi-coding-agent/blob/f1a9ddd571fbcf51e187a3e92eba369c0a97c028/docs/ARCHITECTURE.md).

| Catalogue entry | What the follow-up established | Disposition |
| --- | --- | --- |
| [ajevt-browser](https://github.com/XYenon/ajevt-browser/tree/abe83741ad1531e35fc737db9fedcc92fc3ffaab) | Pi extension over agent-browser; caller supplies text values and deterministic verifiers; confidence, repetition, and stale-state handoffs | Evaluate its core behind a portable CLI wrapper. Version 0.1.0 and a repository created September 23: still very early. |
| [pi-jev-browser](https://github.com/laihenyi/pi-Jev-browser/tree/206a351831d82580a78ac4635aabcc33bc7134c9) | Separate Playwright session profiles, a driver abstraction, browser and macOS tools; model completion explicitly returns `done_unverified` | Driver/loop design reference. Its Pi tool registration is outside the shared skill integration. |
| [pi-agent-browser-native](https://github.com/fitchmultz/pi-agent-browser-native/tree/6d4f6fefa14cf00fd0bb72cc50cace295aa55871) | Native Pi tools around external agent-browser, with session management and artifact handling | Session and artifact reference only; adding native Pi tools would not meet the requested integration surface. |

Ajevt improves on the first-pass wrappers in concrete ways: it returns `done`
only when its supplied verifiers pass, otherwise `likely_done`; missing typed
values return `input_required`; risk and low-confidence decisions hand back.
The loop accepts an injected browser adapter, but the shipped tool constructs
`AgentBrowserAdapter` directly. It has no shipped Orca route.
[Execution loop](https://github.com/XYenon/ajevt-browser/blob/abe83741ad1531e35fc737db9fedcc92fc3ffaab/src/loop.ts),
[tool binding](https://github.com/XYenon/ajevt-browser/blob/abe83741ad1531e35fc737db9fedcc92fc3ffaab/src/tool.ts),
[verifiers](https://github.com/XYenon/ajevt-browser/blob/abe83741ad1531e35fc737db9fedcc92fc3ffaab/src/verifier.ts).

Its confirmation mechanism still needs qualification. Risk detection combines
label keywords with Jev's risk judgment, and `allow_risky` is a tool argument
that enables risky actions for the run. That is not an approval token bound to
one exact action. Its driver also passes fill values as subprocess arguments,
which conflicts with this repo's credential-handling contract for secret text.
The published verifier choices prove matching observed UI state, not durable
server-side effects. Trial it on public navigation and synthetic data, keeping
authorization outside model-controlled arguments.
[Risk labels](https://github.com/XYenon/ajevt-browser/blob/abe83741ad1531e35fc737db9fedcc92fc3ffaab/src/policy.ts),
[command construction](https://github.com/XYenon/ajevt-browser/blob/abe83741ad1531e35fc737db9fedcc92fc3ffaab/src/agent-browser.ts).

Pi-jev-browser reports 22 passing local/model/live/desktop scenarios from
September 20. Its report explicitly excludes date-picker and multi-step flight
form coverage: the flight scenarios navigate with URL parameters. It also
excludes purchase paths and screenshot-based outcome assertions. These are
useful regression results, with no matched speed comparison against this repo.
[Benchmark boundaries](https://github.com/laihenyi/pi-Jev-browser/blob/206a351831d82580a78ac4635aabcc33bc7134c9/benchmarks/README.md).

The jev-ultrafast implementation review found a sharper integration boundary
than its library example suggests. `Agent` creates `Browser(url)` internally;
there is no driver, Page, existing-tab, or caller-CDP injection. Browser Harness
creates a background tab in the existing Chrome profile. Cleanup closes that
owned tab, but the identity remains shared with the profile. Pi packaging alone
would not preserve Orca's browser ownership.
[Agent construction](https://github.com/browser-use/jev-ultrafast/blob/1231850a0bf1a0c0341fe408ef1668dbbfdfac46/jev_ultrafast/agent.py),
[browser connection](https://github.com/browser-use/jev-ultrafast/blob/1231850a0bf1a0c0341fe408ef1668dbbfdfac46/jev_ultrafast/browser.py).

Its `command("predict")` and `command("act", ...)` split provides an interception
point for a wrapper. Automatic `run()` has no authorization callback and accepts
model `DONE`; the independent result checker belongs to the Flights example.
It bounds actions and decisions, but has no total run deadline. Typed values
enter provider-bound history and returned traces. A trial wrapper would need
independent completion checks and a total timeout, plus an explicitly selected
Chrome identity. An Orca integration requires a driver refactor.
[Loop](https://github.com/browser-use/jev-ultrafast/blob/1231850a0bf1a0c0341fe408ef1668dbbfdfac46/jev_ultrafast/agent.py),
[provider state](https://github.com/browser-use/jev-ultrafast/blob/1231850a0bf1a0c0341fe408ef1668dbbfdfac46/jev_ultrafast/model.py),
[example verifier](https://github.com/browser-use/jev-ultrafast/blob/1231850a0bf1a0c0341fe408ef1668dbbfdfac46/examples/flights.py).

The skill contract has three parts:

1. The experimental `browser-jev/SKILL.md` references `browser/SKILL.md` for
   driver and identity selection. An explicitly requested bounded task can then
   use Jev. Jev guidance lives in `browser-jev/references/jev.md`.
2. The portable `browser-jev/scripts/run-jev` entry point accepts a JSON
   request on stdin: goal, selected driver, owned page/session identity, known
   input values, task limits, and completion checks. Credentials come from the
   environment or protected files. The runner performs the continuous
   observe/decide/validate/act loop and enforces the supplied bounds.
3. The runner returns structured evidence and either verified completion or a
   handoff for missing input, authorization, ambiguity, unsupported controls,
   or failure. The parent agent handles that handoff through the same skill.
   An uncertain effect requires inspecting state before retrying.

The local implementation now supplies this entry point and supporting modules.
ADR 0035 supersedes the earlier decision to place them in `browser/`.
Keeping the inner loop in a process is essential to the intended speedup: a
skill instruction that asks the parent model to choose every next click retains
the parent-turn overhead. The skill remains the integration owner while its
runner supplies the execution machinery.

Harness portability and browser-driver support are separate requirements. The
same shell/JSON interface can serve every harness, while driver adapters retain
Orca's page/profile ownership or agent-browser's task session and flags. An
unsupported adapter returns to the existing skill route; it must not silently
switch to a different browser or profile. Browser Harness stays the explicitly
selected live-Chrome lane.

Forvela already publishes a `jev` executable. Ajevt exports `./core`, but that
entry point currently constructs agent-browser directly; its manifest has no
browser-runner CLI. A wrapper could reuse that core for the agent-browser lane,
while Orca support needs a supported adapter seam. Jev-ultrafast requires a
driver refactor for that same reuse. None is presently verified as a drop-in
runner meeting this contract.
[Forvela manifest](https://github.com/forvela/jev-agent-browser/blob/b4d4e0284a4b0336f12831ef6fe64ba5d29b1efb/package.json),
[Ajevt manifest](https://github.com/XYenon/ajevt-browser/blob/abe83741ad1531e35fc737db9fedcc92fc3ffaab/package.json).

The [completed implementation plan](../plans/jev-browser-runner-plan.md)
records the authored Jev runner in `utils-agent`, separate driver
qualification, portable harness invocation, and whole-task comparison against
the existing browser loop. The local findings below qualify the implementation
and record the development comparison's rejection of adoption.

## Local implementation findings

The authored [runner](../../agent-marketplace/packages/utils-agent/skills/browser-jev/scripts/jev/runner.mjs)
now uses the experimental skill's JSON entry point with Cloudflare Jev and
borrowed browser resources. Local evaluation used `jev-1.13.0`, standalone agent-browser
0.38.1, and Orca 1.4.214 with bundled agent-browser 0.27.0. The implementation
remains an experimental lane. The matched development comparison below
rejected adoption; no frozen holdout ran.

The first encoding asked Jev to choose one complete action. Navigation,
pagination, and a synthetic form passed the independent server oracle at the
default confidence floor of 0.85. Search repeatedly stopped despite choosing
a useful next action: initial confidence ranged from 0.42 to 0.70, and later
choices fell to 0.38–0.48. Lower-floor trials still stopped; those failures are
retained rather than counted as completions.

A development experiment separated operation and target questions in one
request. It returned `CLICK` at 0.97 with target confidence 1, then `CHECK` at
0.83 with target confidence 1. The second action correctly stopped below the
default floor. The runner now uses this encoding while keeping each target
choice bound to a complete authorized candidate. This small experiment shows
that encoding changed the observed confidence; it does not establish general
calibration or an accuracy improvement.

On the final split-question candidate, default-floor navigation and pagination
passed. The form filled its three fields, then stopped before submission
because the click's operation confidence was 0.82. Search passed with three
actions and independent verification at an explicitly selected development
floor of 0.60. The default remains 0.85; confidence tuning is separate from
authorization and result verification. Receipts are
`build/jev-browser/standalone-7994.json`, `standalone-8065.json`, and the earlier
`split-head-83568.json`.

A frozen split-question candidate then completed 20 development trials at
floor 0.60: five each for navigation, search, pagination, and form entry. All
20 passed the independent server oracle with zero forbidden effects. The
receipt is `build/jev-browser/standalone-17578.json`. This batch had no
parent-driven comparison and did not use the holdout, so it establishes no
speed advantage or adoption result.

Thirteen real headless-browser cases were rerun against the split-question
candidate using scripted decisions to qualify driver and runner behavior.
Four normal tasks plus delayed results verified; adverse
cases checked ambiguous targets, replacement, redirects, forbidden actions,
login/CAPTCHA, unsupported controls, and duplicate submission. All produced
their expected outcome with zero forbidden effects. These are browser/runner
tests with a deterministic decision source, not thirteen model-success trials.
The receipt is `build/jev-browser/live-faults.json`.

The initial Orca trial observed the owned page and obtained a correct navigation
decision, then returned `window_not_focused` with zero actions. Native focus
inspection found another application frontmost. A later attempt had Orca
frontmost but another worktree selected: `tab switch --focus` did not select
the owning worktree. A visible Orca tab did not establish input ownership,
and the guard was retained. Desktop Orca mutation and end-to-end task
completion remain unverified. The receipts are
`build/jev-browser/live-orca.json` and `orca-focus-evidence.json`.

An isolated Linux Orca 1.4.214 runtime subsequently qualified typed CSS
operations without touching desktop Orca. Its ready status advertises
`browser.headless.v1`; the adapter binds runtime/page ownership and permits
input without foreground consent only for that qualified status combination.
The macOS launcher controlled that Linux browser runtime; this did not qualify
a Linux launcher. Eight real Cloudflare/Jev jobs used `foregroundInput: false`.
At default floor
0.85, navigation, pagination, and the form verified; search opened its filter
panel then handed back when CHECK confidence was 0.69. At floor 0.60, all four
tasks verified. The independent server oracle recorded zero forbidden effects
in every trial. These trials exercise CLICK, FILL, CHECK, and SELECT, including
one authorized synthetic form submission per successful form task. They do
not establish desktop focus behavior or a performance advantage.

The headless runtime ran as user `orca` in an unprivileged Docker container,
with no host mounts or published ports, using synthetic fixtures only. Its
official AppRun fallback supplied `--no-sandbox` because Docker blocked the
user-namespace probe; Chromium reported its sandbox disabled. This isolation
is a bounded qualification environment, not approval for general browsing.
Receipts are `build/jev-browser/orca-container/qualification.json` and
`build/jev-browser/orca-container/live-jev.json`.

Sixteen scripted cases then exercised the same headless Orca adapter and real
browser. They repeated the thirteen standalone driver cases, added a lost
reply after an actual form submission, and checked viewport scrolling. The
lost reply returned `mutation_reply_lost` with an unknown effect receipt and
exactly one server-recorded submission; it did not replay the click. Scrolling
down moved the viewport from 0 to 400 and passed a DOM event check; scrolling
up at the top returned `scroll_boundary` after one dispatch. All sixteen cases
produced the expected outcome. All fourteen cases with server effect ledgers
recorded zero forbidden effects. These deterministic driver trials use no
model and establish neither model reliability nor a speed advantage. The
receipt is `build/jev-browser/orca-container/live-faults.json`.
The task tabs/profiles, container, image tag, and downloaded AppImage were
removed afterward; `build/jev-browser/orca-container/cleanup.json` records
cleanup without touching desktop Orca.

Fresh Codex and Claude sessions invoked the copied portable entry point and
verified malformed-job rejection without browser or provider calls. Pi's
configured provider failed OAuth refresh with HTTP 401 before invoking the
runner. Those smokes establish only invocation portability for the two
successful harnesses. Offline tests, live driver trials, model trials, and
the paired comparison establish different guarantees, recorded in the
[completed experiment plan](../plans/jev-browser-runner-plan.md).

## Matched development comparison

The frozen candidate failed the adoption gate in twenty matched pairs: five
repeats each of navigation, search/filtering, pagination, and form entry. Both
arms used fresh native Codex `gpt-6-astra` parents at high effort, standalone
agent-browser 0.38.1, the same owned session/profile/target, and independent
fixture resets. The Jev arm used `jev-1.13.0` with explicit floor 0.60; the
source default remains 0.85. Each parent inspected the actual page. In the Jev
arm it constructed the job rather than receiving a prewritten manifest.

| Measure | Parent browser loop | Parent plus Jev |
| --- | ---: | ---: |
| Autonomous verified completions | 20/20 | 13/20 |
| Scored end-to-end median, including fallback | 33.96 s | 50.26 s |
| Native parent task timeouts | 0 | 2 |
| False successes | 0 | 0 |
| Forbidden effects | 0 | 0 |

The median ratio was 0.676x, below the required 2x improvement; parent-plus-Jev
took about 1.48 times as long. By task, Jev completed navigation 3/5, search
0/5, pagination 5/5, and form entry 5/5 autonomously; the baseline completed
5/5 for every task. The six runner handoffs comprised five low-confidence
search decisions and one invalid selector. Parent fallback reached the
independent oracle in all six. Two enclosing parent tasks timed out: one
after a runner handoff and one after the runner had verified. These overlapping
counts retain the original receipts; a runner handoff and a later parent
timeout describe different stages.

Timing includes task setup, skill reading, inspection, job construction,
execution, independent verification, fallback, and cleanup. The common rig's
865 ms startup was disclosed separately. The adoption score applies the full
task-budget floor once to the combined duration for timeouts or uncompleted
tasks. Warm runner time was fast: median 0.96 seconds across returned results,
or 1.08 seconds among verified results. Parent job construction alone took a
median 19.62 seconds. Those diagnostics explain part of the gap; they cannot
replace the full comparison. Cloudflare recorded 44 inference calls, 49,462
input tokens, and 4,287 output tokens. Complete native token usage and dollar
cost were unavailable, so no cost-saving claim follows.

The candidate was a copied skill bundle with SHA-256
`3ad7e5737b238e80e1fdfdcec02415611d2e1276e8a441cc4a756081e3a0ed7e`.
Later headless Orca support, CLI error reporting, and skill-reference edits
were not folded into that frozen copy. This comparison qualifies neither
Orca performance nor other parent models or effort settings. An earlier
instrumentation attempt failed on transcript paths outside the native sandbox
and was retained separately; the completed batch used the same local execution
permissions in both arms. Raw trial receipts were not rewritten.

Receipts, source manifest, audit, findings, and XHTML report are under
`build/jev-browser/benchmark/2026-09-27T03-04-24-694Z/`. The experiment stops
with this negative result; the holdout remains unused. A future hypothesis
could test whether reusable inspected manifests or longer repeated tasks
amortize parent preparation, using a separately defined development workload,
equal setup advantages for both arms, and all preparation costs included.

## How the three loops interact with models

All three implementations batch the operation and target questions into one
Jev decision request. Choosing a target does not require a second model round
trip. Their differences lie in which controls and values enter that request,
what code permits afterward, and how completion is established. This compares
our current source with pinned UltraFast `1231850a` and Forvela `b4d4e028`;
neither upstream implementation was run in the matched benchmark.

| Boundary | Our skill runner | Jev Ultrafast | Forvela jev-agent-browser |
| --- | --- | --- | --- |
| Model context | Goal, URL, bounded page text, parent-scoped controls, completion-check results, recent receipts | Goal/rules, viewport page text, indexed discovered elements, current field state, recent actions | Goal, agent-browser snapshot text and refs; optional plan, subtask, history, recovery |
| Jev questions | Operation plus a target question for each available operation | Operation plus a target question for each available operation | Operation, click/type/select targets, goal reached, stuck; optional tool target |
| Target identity | Candidate ID binds an allowed operation, observed control, and any supplied input value | Element index; dropdown target includes an option index | Browser ref selected from role-filtered candidates |
| Field values | Parent supplies ordinary text and select values; Jev cannot invent them | After TYPE_TEXT, a separate text model derives the value from goal/field/page context; SELECT chooses an observed option | After target choice, code resolves caller-supplied values by ref or field name/key, or a global value; missing input hands back |
| Action confidence | Both selected heads must pass 0.85 by default; trials explicitly used 0.60 | Validates distributions and choice membership; no minimum action-confidence threshold | Records returned probabilities; no minimum action-confidence threshold |
| Completion | Fresh caller-defined predicates must pass; DONE only requests verification | DONE plus a fresh-page check marks completion | Scalar goal-reached judgment at 0.8, or 0.6 with a narrow history heuristic |

Our mechanics live in the [runner](../../agent-marketplace/packages/utils-agent/skills/browser-jev/scripts/jev/runner.mjs)
and [DOM observer](../../agent-marketplace/packages/utils-agent/skills/browser-jev/scripts/jev/dom.mjs).
They include fresh target identity/state checks before dispatch and expected
effects afterward. UltraFast's request construction and validation are in
[model.py](https://github.com/browser-use/jev-ultrafast/blob/1231850a0bf1a0c0341fe408ef1668dbbfdfac46/jev_ultrafast/model.py);
its execution and DONE handling are in
[agent.py](https://github.com/browser-use/jev-ultrafast/blob/1231850a0bf1a0c0341fe408ef1668dbbfdfac46/jev_ultrafast/agent.py).
Forvela's six default questions include two scalar `noul` judgments, not six
requests. Its default context caps are 18,000 snapshot characters and 180 refs.
The 0.6 completion exception specifically requires a preceding BACK action
and completion wording in the goal; it is not an independent task verifier.
[Forvela request](https://github.com/forvela/jev-agent-browser/blob/b4d4e0284a4b0336f12831ef6fe64ba5d29b1efb/src/decision.js),
[Forvela execution/input resolution](https://github.com/forvela/jev-agent-browser/blob/b4d4e0284a4b0336f12831ef6fe64ba5d29b1efb/src/loop.js).

The fixture's Published checkbox exposes a concrete difference. Our runner
offers CHECK to enable an unchecked control. UltraFast discovers checkbox
state and offers CLICK, with prompt instructions to avoid toggling an already
satisfied control. Forvela's default CLICK target question only includes
buttons and links; it offers no CHECK operation. That fixture therefore needs
added target support or an explicit page helper before Forvela can control the
native checkbox through its normal decision space.
[UltraFast discovery](https://github.com/browser-use/jev-ultrafast/blob/1231850a0bf1a0c0341fe408ef1668dbbfdfac46/jev_ultrafast/snapshot.js),
[UltraFast rules](https://github.com/browser-use/jev-ultrafast/blob/1231850a0bf1a0c0341fe408ef1668dbbfdfac46/jev_ultrafast/questions.py),
[Forvela target roles](https://github.com/forvela/jev-agent-browser/blob/b4d4e0284a4b0336f12831ef6fe64ba5d29b1efb/src/decision.js).

UltraFast's TYPE_TEXT helper defaults to `deepseek-chat` over a separately
configured OpenAI-compatible endpoint and credential. Our runner and Forvela
do not make that typing-model call. UltraFast also reuses a Browser Harness
CDP session, whereas our adapters and Forvela dispatch browser CLI commands.
These are potential latency tradeoffs, not measured wins in this experiment.
[Text helper](https://github.com/browser-use/jev-ultrafast/blob/1231850a0bf1a0c0341fe408ef1668dbbfdfac46/jev_ultrafast/model.py),
[UltraFast browser](https://github.com/browser-use/jev-ultrafast/blob/1231850a0bf1a0c0341fe408ef1668dbbfdfac46/jev_ultrafast/browser.py),
[Forvela browser](https://github.com/forvela/jev-agent-browser/blob/b4d4e0284a4b0336f12831ef6fe64ba5d29b1efb/src/browser.js).

Provider routes differ: our fixed Cloudflare `typesafe/jev` route returned
`jev-1.13.0`; both upstream sources default to direct TypeSafe `jev-latest`.
TypeSafe currently documents that alias as `jev-1.13.0`, matching the version
ID in our receipts. We did not execute those upstream wrappers during the
comparison, so matched serving behavior during those trials is unproven.
[Current model aliases](https://docs.typesafe.ai/models).
The local negative result includes a measured 19.62-second median manifest
construction cost and five search handoffs at our confidence gate. It does
not show how UltraFast or Forvela would perform, or that removing validation
would retain verified completion. Broader automatic discovery and different
context/rules remain hypotheses for a separate controlled experiment.

## Why our current integration loses

The paired result measures the complete **parent plus runner** workflow, which
is the right adoption measure for this skill. It does not measure Jev's inner
loop in isolation. Across the 20 Jev arms, the parent spent a median 19.62
seconds constructing each job: CSS selectors, allowed operations, input values,
expected effects, and final checks. Median execution then fell from 6.92
seconds in the ordinary parent loop to 1.51 seconds with Jev; the runner itself
reported a 0.96-second median. We paid much more to prepare delegation than we
saved during these short tasks. The explicit-manifest
[observer](../../agent-marketplace/packages/utils-agent/skills/browser-jev/scripts/jev/dom.mjs)
used in that comparison only offered controls listed in the job, so it could
not discover an unanticipated control revealed after an action. That
restriction was our initial design choice, not a requirement of skill
ownership or Orca.

All five paired search runs clicked Filters. On their next decision, Jev chose
FILL twice and CHECK three times, with operation confidence 0.33–0.43; our
uniform 0.60 floor handed off before either action. Both filling the query and
checking Published could advance that goal. [TypeSafe's confidence definition](https://docs.typesafe.ai/confidence)
does not interpret those scores as the chance of an incorrect action. The
retained receipts omit the full probability vectors, so the exact cause of
the low scores remains unproved. Another paired handoff came from the parent
putting an `agent-browser` text locator in a CSS-only job. The parent fallback
completed all six handed-off tasks. The ignored development artifact
`build/jev-browser/benchmark/2026-09-27T03-04-24-694Z/findings.md` retains the
frozen findings and raw receipt paths.

The upstream speed claims use different boundaries. As checked on September
27, [UltraFast's recorded
7.073-second Flights run](https://github.com/browser-use/jev-ultrafast/blob/main/docs/performance.md)
starts after the first page observation and excludes browser setup, initial
navigation, and independent post-run verification. Its matched optimization
comparison is three pairs on that one task; it is evidence that its dynamic
browser loop is fast, not a comparison against our parent workflow.
[Forvela explicitly says](https://github.com/forvela/jev-agent-browser#performance)
its wrapper benchmark is still to come. Neither source establishes that the
Cloudflare route or an Orca browser is the dominant cost in our trials: the
measured local runner was already fast.

A better skill-owned candidate would let the parent pass an owned browser
identity, goal, origin and operation policy, and necessary ordinary input
values. A local observer would discover currently available low-impact
controls and enforce that policy; the parent would independently verify the
returned outcome once. That removes per-control job authoring while retaining
browser ownership, effect receipts, origin checks, and no blind mutation
replay. Test this as a new candidate with the same full-task accounting and
independent oracle. The present negative result applies to the current
manifest-heavy design.

The [dynamic follow-up](../plans/jev-deterministic-preparation-plan.md) now
implements that setup as an opt-in `scope.discover` mode in the skill-owned
runner. A deterministic sequence completed the synthetic search in a real
isolated agent-browser, including a newly revealed checkbox; the fixture's
independent oracle passed and recorded zero forbidden effects. This proves the
browser/observer path and deterministic setup, not that the full workflow is
faster. The frozen 20-pair result above remains
the result for the explicit-manifest candidate.

Two initial dynamic Cloudflare trials still handed back before action: Jev
chose Filters, but operation confidence was 0.52–0.54, below the 0.85 and 0.60
floors. We then moved caller-supplied field values into deterministic execution.
With `query: "orchard"`, the runner filled the field itself; Jev subsequently
selected Filters and Published at confidence 1 in two new trials. Both passed
the independent fixture oracle with zero forbidden effects. Supplying the
checkbox value as `published: true` completed the same search entirely through
deterministic rules, with no Jev calls. These runs show a useful division of
labor on one fixture, not a calibrated confidence policy or a paired speed win.

## Official TypeSafe guidance and implications

The official documentation supports the core decomposition: Jev evaluates
typed judgments over supplied state, and application code composes the answers.
It does not generate free-form field text or replace the parent agent's
open-ended planning. Asking operation and speculative target questions together
matches TypeSafe's fan-out pattern; code uses the relevant target answer and
ignores the others. These are independent parallel evaluations against one
shared state, not a sequence in which the target question receives the
operation answer.
[Introduction](https://docs.typesafe.ai/introduction),
[State](https://docs.typesafe.ai/concepts/state),
[Speculative fan-out](https://docs.typesafe.ai/patterns/fan-out).

Confidence describes the concentration of a Choice answer's probability
distribution. It is not a measured probability that our browser action will
be correct. Low confidence can mean several offered operations compete,
rather than that every offered operation is wrong. Our minimum of operation
and target confidence implements a requirement that both pass; it is not a
joint success probability. Confidence gating follows the documented pattern,
but our universal 0.85 default and 0.60 trial floor are local policy choices,
not provider recommendations. TypeSafe recommends testing thresholds against
domain results and action consequences. The upstream loops' lack of action
thresholds does not establish that their decisions are more correct.
[Confidence](https://docs.typesafe.ai/confidence).

The failed `search-3-jev` receipt illustrates the distinction: CLICK had
operation confidence 0.88 and target confidence 1; the next CHECK had 0.34
and 1, causing handoff. The retained result lacks the full option-probability
vectors. Several acceptable next steps competing for operation probability
is a plausible explanation, but the receipt cannot prove it. The measured
handoff and benchmark result remain valid; the cause needs a new experiment.

Question independence exposes an unfixed prompt gap in our
[request builder](../../agent-marketplace/packages/utils-agent/skills/browser-jev/scripts/jev/runner.mjs).
Only the operation question includes the page-untrusted and no-repeat
instructions. Target questions repeat the goal and hypothetical operation,
but do not inherit those sibling instructions. Each target question needs
self-contained guidance relevant to its judgment; executable scope and checks
still constrain every candidate. TypeSafe recommends narrow questions,
relevant structured state, and explicit references to the fields being judged.
[State isolation](https://docs.typesafe.ai/concepts/state),
[How to build with TypeSafe](https://docs.typesafe.ai/concepts/how-to-build-with-system-one).

Question IDs are response-routing keys the model does not see; option IDs and
descriptions do reach it. Choice supports up to 255 options and recommends an
escape option when candidate coverage may be incomplete. Our operation-level
HANDOFF supplies an escape at that level; target-choice coverage still needs
evaluation. Instructions and option descriptions may be structured objects or
arrays. Our [Cloudflare client](../../agent-marketplace/packages/utils-agent/skills/browser-jev/scripts/jev/cloudflare.mjs)
deliberately accepts a string-only question subset; that is a client boundary,
not a limitation of TypeSafe's API.
[Choice](https://docs.typesafe.ai/primitives/choice),
[Structured instructions and criteria](https://docs.typesafe.ai/primitives/advanced).

As reviewed on September 26, TypeSafe lists `jev-1.13.0`, with both `jev-latest`
and `jev-preview` pointing to it. Aliases can move; calibration should pin a
supported version where the provider permits it and retain the returned ID.
The direct API documents 64k tokens per request and 32k for state plus the
longest question. Those are token limits, not our character/byte limits, and
do not independently establish Cloudflare's serving constraints. TypeSafe's
jaggedness notes support testing literal wording, irrelevant context, and
adversarial content. They do not establish option-order sensitivity.
[Models](https://docs.typesafe.ai/models),
[Jev 1.13 jaggedness](https://docs.typesafe.ai/model-jaggedness/jev-1.13).

A subsequent development experiment should retain full probability vectors with bounded
sanitized decision evidence, make each question self-contained, and test
clearer distinctions between acceptable next operations. Calibrate confidence
by action consequence against independent outcomes rather than automatically
lowering the threshold. Measure parent preparation alongside those model
changes; the existing end-to-end comparison includes its 19.62-second median
job-construction cost. These are proposed next tests; they do not change the
completed benchmark result.
