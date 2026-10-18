---
status: active
doc_type: research
summary: "Search 1.16 contracts, adversarial review, bounded live pilot, source canaries and activation evidence."
created: 2026-10-18
updated: 2026-10-18
related:
  - ../plans/search-source-selection-plan.md
  - ../plans/search-skill-plan.md
  - ../adr/0055-search-sources-independent-of-providers.md
  - search-skill-implementation.md
  - search-source-selection-review.md
  - ../../agent-marketplace/packages/utils-agent/skills/search/SKILL.md
status_detail: "Implementation and pilot qualified separately; broader task quality, translation correctness and hidden-family generalization remain unmeasured."
---

# Search source selection: implementation and qualification

The 1.16.1 source package implements open site scopes, independent evidence areas
and providers, conditional source guidance, and exploration records within the
existing search run. Contract and consumer tests pass. The live pilot found useful
evidence and exposed defects that were repaired, but it does **not** establish a
relevance advantage, statistical equivalence or comprehensive platform coverage.

## Delivered behavior

| Surface | Behavior |
| --- | --- |
| Source resolver | Known aliases plus `site:hostname[/path]`; shared normalization, host/path intersection, exclusions and returned-destination checks |
| Routing | Area selects evidence policy; source selects its publisher/community; providers declare qualified scopes and operations. No additional model router or per-site adapter is required |
| Context | Bounded public context with explicit/conversation/saved/assumption origins; separate query language and programming-language filter |
| Exploration | Selected/deferred/excluded/not-relevant decisions link to compatible facets; extensions preserve the original deadline, budget, pins and pending work |
| Identity | New runs use policy 2; alias/site views of known resources merge while unknown hosts, offer variants, markets and revisions remain distinct |
| Reads | Observed redirects attach inspection evidence to the original discovery candidate without changing its ID; evidence changes invalidate previous assessments |
| Diagnostics | Existing XDG state/events and receipts include joined exploration coverage and stopping reason; restricted retention omits added prose and exposes the omission |
| Guidance | Separate social/shopping areas; regional and multilingual discovery, used/refurb/surplus/auction sourcing, wholesale/delivery, non-GitHub code and primary web evidence |
| Ownership | Parent owns retrieval, shared evidence policy and diagnostics; specialized skills own domain queries, interpretation and output. New profiles, aliases and adapters have separate addition criteria |

The durable contracts are in [source scopes](../../agent-marketplace/packages/utils-agent/skills/search/references/source-scopes.md),
[source selection](../../agent-marketplace/packages/utils-agent/skills/search/references/source-selection.md)
and [extension ownership](../../agent-marketplace/packages/utils-agent/skills/search/references/extending.md).
The source catalog supplies conditional leads, not integrations or guaranteed access.
Portable instructions contain no personal infrastructure, account or vault conventions.

Compatibility changes are explicit: ambiguous non-web area-only requests need a
source/facet unless a provider pin identifies one source; conflicting global source
and required-source pins fail instead of widening; new native GitHub runs qualify
github.com, not arbitrary Enterprise hosts inferred from repository fields.
The `amazon` alias remains amazon.com; regional storefronts use explicit site scopes.
Path scopes preserve case and literal segments. Server-specific case/semicolon
aliases require host exclusions or listed variants rather than guessed equivalence.

## Deterministic verification

The portable suite has **96 passing tests**, including baseline-generated
1.15 checkpoints, pending settlement/idempotency, old web comment reads and extension,
source/operation limits, redirect linking, encoded-host exclusions, legitimate
percent paths, scope intersections, bounded metadata, retention and redaction.
An environment credential becoming known after planning previously made a redacted
checkpoint fingerprint invalid; a failing regression was observed and the persisted
fingerprint now follows the final redacted request.

The skills-searcher shell suite passes with its prepared-job, no-enrich, legacy
display, relevance, receipt and output contracts intact. Its positive native result
fixture now uses github.com; a separate negative test rejects wrong-host native
results. The assertions were retained. Ruff undefined/unused-name checks pass.
Package, lifecycle and fresh-session evidence is recorded below separately.

## Adversarial review and fixes

Two fresh reviews used Claude Code through `claude-agent-acp`, with the main model
verified as `claude-opus-5-5` and medium effort. They received paths and a review
task, not the parent conversation. Both processes exited 0. Read-only tool traces
were audited: local reads/searches and in-memory Python reproductions, no provider
calls or source edits. The second also ran the then-current 89-test suite.

| Review | Session | Scope and limit |
| --- | --- | --- |
| Initial | `f55dae55-c7d0-4cde-97d9-d7d97e101814` | 39 tool calls; found redirect and exclusion blockers plus compatibility/diagnostic issues |
| Verification | `3a8c716a-c5a9-4ed2-a2bd-7f5de00b2ae1` | 31 tool calls; no remaining blocker reported; three low findings below. Usage also reports a small Haiku call, whose purpose is not established; this is not a second independent review |

| Finding | Disposition |
| --- | --- |
| Redirected read failed to support its discovery candidate | Fixed with engine-owned requested-URL linkage; IDs preserved, evidence digests change; legacy identity remains unchanged |
| Ambiguous destination paths could bypass source exclusions | Fixed: host matching is separate from strict scope parsing; ambiguous matching-host paths fail closed |
| Source/required-source widening and native Enterprise behavior differed from baseline | Retained explicit restrictions; documented intentional compatibility changes and tested them |
| HN provider-only shorthand rejected an otherwise unique source | Fixed for any qualified single named source, including API routes |
| Existing web comment/offer/transcript reads and legacy extension rejected | Restored and exercised with a genuinely generated 1.15 fixture |
| Decision rows could claim unrelated facet counts | Validate every linked facet's effective scope; deferred/omitted rows cannot claim execution links |
| Host/path constraints intersected incorrectly across dimensions | Combine the narrower host and narrower path independently |
| Restricted metadata changed the persisted fingerprint | Fingerprint the final retained/redacted request; retain stable run/work/attempt identities |
| Encoded destination hostname bypassed an exclusion | Fixed after verification review, with regression coverage |
| Valid `%25` destination under a path scope was rejected | Fixed after verification review; source-reference parsing remains strict |
| Case and semicolon path aliases depend on the server | Documented literal matching and host-scope remedy; no generic case folding |

The simplification pass reused one source resolver, removed redundant validation
and duplicate fingerprint recomputation, and pruned narration. Writing-for-agents
guidance is organized around triggers, decisions and completion evidence. The last
small hostname/path/redaction fixes were subsequently covered by the fresh review
recorded below. No reviewer endorsement is claimed for unseen changes.

### Corrective patch 1.16.1

A third fresh review used native Claude Code 2.1.302, main model
`claude-opus-5-5`, medium effort, session
`4ea290c0-421f-4053-91ce-d96d5465a635`. It exited successfully and reran the then-current
91 portable tests. It made 32 shell tool calls and consulted one built-in advisor;
usage also lists `claude-fable-5-1`. Package source hashes and Git status were
unchanged; test/probe temporary directories were created. This was not an
exclusively single-model review. It did not rerun consumer, package or live tests.

Independent reproductions confirmed four findings, corrected in 1.16.1:

| Finding | Correction and evidence |
| --- | --- |
| A 1.15 run with `source=reddit`, `require_source=hn` loads but cannot extend | Legacy re-planning retains the original union of selected and required sources. New runs keep the stricter pin. A genuine baseline checkpoint exercises extension, unchanged budget/deadline/authorization/pending work, and atomic rejection outside the original scope |
| IDNA2003 silently conflates `faß.de` and `fass.de` | Reject Unicode deviation characters and compatibility-normalized forms in scopes and returned hosts, with an explicit ASCII punycode remedy. Regression cases cover query translation, returned/percent-encoded hosts, redirects, and general-web exclusions |
| Portable guidance leaves Amazon alias geography unclear | Source-scope guidance states that `amazon` covers amazon.com only; regional selection and exclusions use explicit site scopes. Shopping guidance links to that contract. Regional offer identity does not widen scope |
| A site scope with `product.discover` but no area yields an opaque error | The validation error names compatible areas and `--area`/explicit-facet remedies. The CLI regression verifies failure before state creation and success with `--area=shopping` |

The four new regression tests failed for the intended reasons before the fixes;
all 95 portable tests and the skills-searcher consumer suite then passed. The new
`legacy-required-source-state.json` fixture was produced by the unmodified modules
from `7c76225d02985bb63cdfd45cb1e7a14f133f2ded` using `plan`, `new_state`, `reserve`
and `persisted`. Only its deadline was moved into the future for repeatable tests.
The baseline itself validates the fixture and successfully extends it.

The Unicode handling deliberately remains conservative and stdlib-only. It is
not a full UTS46 implementation; valid Unicode such as `BÜCHER.de` still works,
while affected domains can use their explicit punycode form. The deviation set
and distinct `faß.de`/`fass.de` destinations follow
[Unicode UTS46](https://www.unicode.org/reports/tr46/#Deviations).
No provider endpoints, ranking rules, budgets or live-pilot observations changed.

A focused native Claude Code follow-up (`claude-opus-5-5`, medium effort, session
`ffae4d83-010b-40b7-b026-766c2fa71123`) independently confirmed those fixes and reran
the 95 tests. Its 14 tool calls left package hashes unchanged; it created and
removed a temporary baseline extraction. Usage lists only Opus. It found one
regression in the new guard: lowercasing uppercase Greek `ΑΣ-1.gr` could introduce
a final sigma and reject a previously supported hostname. A fifth failing
regression test reproduced both source and destination failures. The correction
checks characters before lowercasing and uses the raw URL host, with explicit
empty-host rejection. Unicode, port-bearing and percent-encoded forms now pass;
actual deviation characters still fail closed. The legacy test also extends with
the required HN source directly. All 96 tests then passed.

A final focused Opus verification through native Claude Code, session
`eda14df8-eb58-43d6-92da-cb9ba1f1d0fe`, found no actionable hostname issue. It
exercised raw/encoded Unicode, trailing dots, ports, subdomains, userinfo and
malformed hosts, and reran all 96 tests. The six tool calls left package source
hashes unchanged; usage lists only `claude-opus-5-5`. Scope was the corrected
hostname handling and tests, not a fresh full-engine review. Existing behavior
that ignores a malformed port during host-scope matching remains unchanged.

## Public development pilot

The [protocol](../../agent-marketplace/packages/utils-agent/skills/search/evals/source-selection.json)
freezes five public cases, three conditions and three repeats: **45 attempts**.
Each permits at most two discovery queries and one content open, three calls total,
within 240 seconds. No accounts, purchases or paid-provider calls were made. Brave
was excluded from pooled evaluation. Host web search/read was the shared route;
the native HN canary below is separate.

A is frozen 1.15.0. B uses the generalized engine with baseline source-selection
guidance. C uses the same engine with new source-selection/regional/shopping guidance.
B and C have the same mechanics/help/schema documentation. Frozen file hashes,
per-attempt metrics and condition-blinded judgments are retained in the
[public results](search-source-selection/data/pilot-results.json).

| Condition | Attempts / valid execution | Actual calls / engine-accounted | Median elapsed | Unique guidance bytes loaded | Audited answers: pass / partial / invalid |
| --- | --- | --- | --- | --- | --- |
| A: 1.15 baseline | 15 / 14 | 41 / 40 | 53.0 s | 30,417 | 2 / 12 / 1 |
| B: generalized, baseline guidance | 15 / 15 | 44 / 44 | 65.5 s | 39,436–40,947 | 2 / 13 / 0 |
| C: generalized, new guidance | 15 / 14 | 43 / 42 | 72.4 s | 58,842–61,663 | 4 / 10 / 1 |

Elapsed time includes task execution and host interaction, not provider latency
alone. Guidance bytes are the union of reported Markdown reads, not measured model
tokens or full context consumption. Dollar cost and exact worker model ID are
unmeasured. Nine workers inherited the same model/harness settings; five cases share
each worker context, with three fresh workers per condition. Case order was rotated
and execution interleaved, but these are not 45 independent fresh contexts.

### Task evidence and descriptive differences

| Case | A | B | C | Evidence and unresolved requirement |
| --- | --- | --- | --- | --- |
| Four used/tested 1 TB 2.5-inch SATA SSDs, US, $200 delivered | 3 partial | 3 partial | 3 partial | Listing inspection exposed sold stock, price/variant mismatches and over-budget lots; no available qualifying four-drive order verified |
| One new 1 TB 2280 NVMe SSD, Toronto, CAD150 delivered in 48 h | 3 partial | 3 partial | 3 partial | Retail stock, dispatch and seller policy remained distinct from destination-specific arrival; no qualifying delivered offer verified |
| Codeberg documentation for preventing direct pushes | 3 partial | 3 partial | 2 partial, 1 invalid | Every valid attempt reached a permissions overview; none established the direct-push control or complete role-table markers |
| K2 owner discussion without Reddit comments/authenticated social | 2 pass, 1 invalid | 2 pass, 1 partial | 3 pass | Public forum reads supported particular symptoms and competing diagnoses; no population failure-rate inference |
| Japanese SQLite WAL locking reports | 3 partial | 3 partial | 1 pass, 2 partial | One C answer had directly relevant inspected WAL evidence; others used adjacent migration/concurrency reads or discovery-only WAL claims. Translation correctness unmeasured |

These are descriptive wins/ties/losses in a small development sample, not causal
rankings. All conditions tied on unresolved shopping and Codeberg completion.
C supplied more explicit channel decisions and had more audited core-answer passes,
while loading more text and taking longer in this sample. Different retrieved
pages, worker context and timing can explain those differences. No provider or
guidance winner is established.

A fresh judge read only shuffled condition-masked answers, fixed criteria and saved
inspection rows. It audited 135 criteria and classified 8 core answers as pass,
35 as partial and 2 invalid. These are answer-audit labels: all 43 valid engine
selections retained `answer_status: partial` for their recorded coverage gaps.
The judge did not judge search completeness, exact queries or
model reasoning from missing evidence. Four ancillary claim flags were checked:
A1 and B3 overstated full-thread coverage; B3 added an unsupported host-computer
detail; B2 used an inspected-support footer after a failed read and categorically
excluded auction fees. The answer bodies largely disclosed the gaps. Current
receipt guidance explicitly rules out the misleading footer/completeness wording;
auction guidance compares actual all-in costs rather than banning fees.

### Pilot failures and interpretation limits

- A2 sparse-access and C1 new-domain issued one query each after CLI validation
  failed, without a reservation. They are **invalid**, not successful searches.
  Neither was restarted. Total actual calls are 128; engine records account for
  126. Guidance now requires a separately checked successful CLI response and
  matching reservation before each host call; follow-up canaries exercised this.
- A1 made seven calls immediately after successful CLI execution in the same tool
  orchestration, before the agent read the reservation. No missing reservation was
  found, but this sequencing deviates from the corrected guidance.
- Five workers (A2, B1, B2, C1, C2) accidentally displayed nested criteria while
  reading the protocol. They are rubric-exposed. The later condition-blinded judge
  does not repair that contamination.
- Several workers retained only subsets of returned results or changed observed
  order; A2 omitted two signed irrelevant attachment URLs. Candidate counts are
  parsed-pool diagnostics, not exhaustive provider-recall measurements.
- C2/C3 urgent-shopping reads exposed a redirect-linking defect: a real page read
  counted as zero inspected candidates. The final engine was replayed offline over
  both saved observations: each now attaches content to the same candidate ID and
  changes its evidence digest. This proves accounting on identical evidence, not a
  live relevance improvement or a newly valid shopping offer.
- The final decision validator rejects three prototype C checkpoints (C2 used,
  C3 used and sparse) whose decisions attached broad-web facet counts to narrower
  sources. Their frozen engine remains the replay authority. All 14 valid baseline
  checkpoints remain readable. Prototype trace incompatibility is disclosed rather
  than rewriting saved experiments.
- Original Japanese body passages were not retained in the judge packet. English
  summaries support an English consistency audit, not translation correctness.
  No independent hidden-family custodian was available; generalization is unmeasured.

## Separate bounded canaries

| Route or scenario | Actual work | Observation and limit |
| --- | --- | --- |
| HN source in shopping area | 1 native HN query | Two story results; source/area separation works. No shopping-usefulness or comments qualification |
| Korean `site:news.hada.io` | 1 host query | 17 parsed results, 2 in scope and 15 rejected. Terms survived transport; relevance weak, original language evidence uninspected |
| Public Surplus discovery/read | 1 query + 1 open | 21 parsed results, 11 in scope; one additional encoded search URL omitted and disclosed. Auction page returned HTTP401, recorded as auth failure, not empty stock |
| Final-guidance Codeberg | 2 queries + 1 open | All 12 discovery results retained; one inspected page, exact direct-push configuration still missing |
| Final-guidance sparse K2 | 2 queries + 1 open | All 35 discovery results retained; open hit verification challenge; stopped that read and kept three discussion leads provisional |

The last two use fresh context, the corrected reservation/decision guidance and
the review-fixed engine. Every host call followed an observed successful reservation;
both finished on the original three-call budget, with no pending work. A rejected
selection was corrected in the same run and preserved in its trace. The combined
canaries made ten calls, separate from the 128-call pilot. They establish bounded
workflow/access evidence, not a rerun of the full comparison.

The wider profiles—Threads, Mastodon, Bluesky, LinkedIn, TikTok, Instagram,
Chinese-language communities, other regional markets, wholesale, delivery and
institutional/public-record channels—remain conditional guidance. Their native
operations and current access were not qualified by this pilot. Generic site
destination filtering is fixture-qualified across providers; real path-operator
behavior was not measured for every API. Exa's path-filter translation follows its
[documented includeDomains behavior](https://exa.ai/docs/search/quickstart).

## Packaging and activation

### 1.16.0 baseline

Utils-agent is bumped to 1.16.0. The package contains its matching engine, consumer
and new references. The marketplace check passed 104 tests and two identical
artifact builds. An earlier invocation timed out in three existing 45-second
fixture commands; the unchanged suite passed on retry. No timeout or assertion was
weakened. Documentation lifecycle checks passed 54 tests and validation against
HEAD and origin/master; `git diff --check` passed.

The checked artifact was materialized with the previous 1.15.0 copy retained for
rollback. Only utils-agent payloads and their catalog metadata differed. Native
Claude and the active Orca Codex profile report utils-agent 1.16.0 enabled. Canonical
Codex reconciliation encountered an unrelated malformed `superpowers-dev`
marketplace and a remote catalog error; targeted `codex plugin add
utils-agent@prateek-local` succeeded without changing that other registration.
The canonical native cache reports 1.16.0 and its config remains enabled. Claude
and canonical Codex cached payloads match the checked artifact byte-for-byte.
Existing sessions keep their loaded instruction context until restarted.

A fresh native Claude Code session (`d69f9d8e-6fa6-476b-a9a0-695ccdafb6b8`, reported
model `claude-fable-5-1`) successfully invoked `Skill: utils-agent:search`. The
native loader resolved the installed materialized plugin folder, not repository
source. Its CLI reported 1.16.0 and all six new features, resolved the Korean
`site:news.hada.io` facet to `post.discover`, and rejected social-only shorthand
with an actionable source-selection error. No provider calls occurred. With no
injected credentials or host manifest, the valid scoped plan honestly had no
eligible route; this smoke proves installation/contracts, not live access.

Two preceding ACP launches timed out before completing the smoke; one reported
that the computer slept mid-response. The successful smoke used Claude Code
directly. Its audit found two temporary plan captures despite the read-only prompt;
they were retained with the local evidence and removed from the temporary paths.
No source edits, provider execution or account actions occurred. Separate direct
CLI checks of both native cache copies produced the same version, features and
scope/rejection behavior. Cursor/Pi session reload and implicit invocation remain
unmeasured; the shared artifact alone is not proof of those runtime behaviors.

### 1.16.1 correction

The final 1.16.1 package passed 104 marketplace tests and two identical artifact
builds. The 96-test portable suite, skills-searcher consumer suite, Ruff checks
and changed-file formatting checks passed. The release diff contains only
utils-agent payloads and its catalog metadata. Source simplification kept the
legacy scope union and Unicode guard in their shared owners; the two hostname
comments explain external Unicode constraints rather than narrating the code.

The checked artifact is materialized with 1.16.0 retained at the previous-artifact
path. Native Claude and the active Codex profile report 1.16.1 installed and
enabled; canonical Codex was refreshed through targeted `plugin add` and its
enabled setting verified. Shared, Claude, canonical Codex and active-profile
payload hashes match the checked artifact. Direct CLI smoke checks on all four
copies confirm version 1.16.1, Unicode rejection with a punycode remedy,
uppercase-Greek acceptance, the missing-area error and explicit shopping-area
success. No provider requests or search states were created. These checks verify
installed CLI behavior; existing sessions still need a restart for instruction
reload. No new live-provider evaluation or implicit-invocation claim is made.

Local raw evidence remains ignored under `build/search-source-selection/`: frozen
bundles and hashes, 45 attempt traces/answers, the masked judge packet and audit,
Opus logs, offline replay, canaries and validation logs. Public metrics and review
dispositions above survive independently of those disposable files. No secret,
private session corpus or signed attachment URL is included in the public dataset.

## Remaining qualification

The plan's implementation slices are delivered; broader task-quality acceptance
remains active. Future qualification should isolate a fresh bounded holdout,
retain original language evidence for a capable judge, and test materially
different market/access families. Keep failed attempts and trace/parser omissions
visible. Do not broaden credentials, account access or spend to fill those gaps
without a separate need and authorization. None of the present evidence justifies
changing default provider rankings.
