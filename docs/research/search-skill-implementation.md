---
status: active
doc_type: research
created: 2026-10-17
updated: 2026-10-18
related:
  - ../plans/search-skill-plan.md
  - ../plans/search-source-selection-plan.md
  - search-source-selection-qualification.md
  - ../adr/0054-shared-search-engine.md
  - ../../agent-marketplace/src/utils-agent/skills/search/SKILL.md
status_detail: "Implementation qualification; source health, task quality and native activation are separate gates."
summary: "Search implementation qualification, live canaries and remaining evidence gaps."
---

# Search skill implementation qualification

The authored [search skill](../../agent-marketplace/src/utils-agent/skills/search/SKILL.md)
ships a shared retrieval CLI with four area references, optional adapters,
constraint/preference resolution, private checkpoints and host continuation.
`skills-searcher` now sends prepared jobs through this engine while retaining
its query/ranking/output policy. The current source package version is 1.16.1;
the [source-selection qualification](search-source-selection-qualification.md)
owns its new contract, pilot and activation evidence. The historical sections below
describe 1.14.0 and the 1.15.0 relevance/diagnostics follow-up; their tests and activation
observations are not claims about later builds.

## Verified behavior

The initial **23-test** portable suite exercises request/option rejection, saved-choice precedence,
paid-route eligibility, free-only constraints, sparse access, budgets, source
filtering, identity, candidate-versus-assessed coverage, private state, retention,
HTTP errors and browser parsing. Host tests drive the real CLI across separate
processes for checkpoint/continue/assess. Fixtures verify stale/duplicate receipts,
atomic rejection, deadline preservation and inspection extension without budget
reset. Network calls are substituted at urllib's transport boundary.

The original skills-searcher shell suite passed before and after migration:
doctor, merged/sorted TSV, ascending order, JSON, progress, rate-limited partial
results and raw Sourcegraph output. It asserts one enrichment per merged file.
The wrapper retains preview/install fields, quotes untrusted arguments, and never executes installations. Additional checks cover no-enrich and a caller-supplied cap across discovery and enrichment.

A live Startpage proof-of-work page exposed a missing challenge signature. A new
test first failed with `schema_error`, then passed with `challenge` after the
classifier was corrected. The later adversarial review found additional false-block and false-empty cases; the fixes are described below.

## Live canaries on 2026-10-17

Public access/schema probes used three-result limits and one-call allocations per
provider. These are not relevance judgments, controlled timing comparisons or
new account provisioning. Existing approved credentials were supplied through the
host's credential bridge and environment, without values in arguments or reports.

| Route | Observation | Limit of this evidence |
| --- | --- | --- |
| Serper | Success, three candidates | General-web request/response shape |
| Exa | Success, three candidates | Semantic/web discovery shape |
| Parallel | Success, three candidates | Fast search only |
| Tavily | Success, three candidates | Basic search only |
| Perplexity Search | Success, three candidates | Search endpoint, not answer quality |
| Octen | Success, three candidates | Current search response shape |
| Kagi | Success, three candidates | Search workflow only |
| SearchAPI | Rate limited, zero candidates | Vertical adapters remain fixture-qualified |
| HN Algolia | Success, three candidates | Story discovery, not all replies |
| GitHub native | Success, three repositories | Repository discovery, not code-use verification |
| DDG through Camofox | Success, three parsed candidates after loaded-state observation | Anonymous browser discovery; no content assessment |
| Startpage through Camofox | Verification challenge | Route stopped; no challenge bypass |
| Brave | Fixture-qualified only in this implementation pass | Derived-only retention; excluded from pooled/model benchmarks |
| SearXNG / Degoog / OpenSERP | Optional configured routes; not launched or live-qualified here | No permanent service provisioning |

The shared browser parser consumed observed DOM markup. An early DDG navigation
snapshot showed only the page shell; waiting for loaded results produced a
recognized SERP. Camofox was task-owned and anonymous; the supervisor reported
`cleaned: true, serverStopped: true`, and its temporary state directory was absent.

Raw canary/debug artifacts remain ignored under `build/search-skill/`. The portable
package contains newly authored public prompts, not the historical session corpus
or its private provenance.

## Evaluation interpretation

The public evaluation file has 20 positive trigger prompts, 20 adjacent negatives
and 12 development tasks across the four areas. A tool-disabled Claude Code run
requested Fable 5.1 to classify the supplied skill description against the 40
prompts: **20/20 positives selected, 0/20 negatives selected**. The reported model
was `claude-fable-5-1`. This checks the original description under an explicit classification prompt; the tightened description has not been re-evaluated.
It is not proof of native implicit invocation or task execution.

The full paired agent-task comparison (12 tasks, three repeats, with the same
engine/tools), the full-stack comparison, blinded relevance grades and a new-family
holdout remain unmeasured. There is no independent holdout custodian. Retrieval
counts do not establish a provider winner or an improvement in answer quality.

## Packaging and activation

The marketplace check passed **81 tests** and built two fresh artifacts, validating
metadata, entrypoints and portable tests. The four client-config merge suites
passed **17 tests**; the docs lifecycle suite passed **38 tests**. Ruff formatting,
undefined/unused-name checks, and `git diff --check` passed. Utils-agent **1.14.0** was materialized and enabled in Claude and the active Orca
Codex profile. A fresh Claude initialization inventory included both
`utils-agent:search` and `utils-agent:skills-searcher`. The installed shared CLI's
inspect smoke passed without source calls and correctly reported absent host access.
The prior artifact is retained locally under ignored
`build/search-skill/pre-search-marketplace/` for rollback.

The canonical Codex profile accepted the plugin update and contains its 1.14.0
cache. Its global inventory command is blocked by a pre-existing `superpowers-dev`
marketplace registration whose directory lacks a manifest. That unrelated
registration was not changed; canonical inventory verification remains limited.
Existing sessions do not reload merely because source files changed.

This qualification records the pre-landing source and activation checks. Landing
and subsequent host activation require separate verification against the published
revision. A later apply from different source state can replace a local artifact.

## Adversarial review fixes

The first Opus 5.5 review exposed missing boundary cases despite passing fixtures.
The follow-up fixes reject execution overrides on saved plans, enforce explicit
budget ceilings, charge dispatched pagination calls even when they time out,
settle transport failures without losing independent results, distinguish browser
results from block/empty pages, preserve raw diagnostics and native identities,
and keep search date filters out of follow-up inspection queries.

Default non-code runs now reserve an inspection call. Routes without qualified
date translation decline dated requests instead of sending unverified query
operators. Skill instructions use ordered steps with completion criteria and
public provider/environment setup; internal account and storage conventions are
absent from the portable payload. Local simplification flattens routing/reporting
branches and removes an unreachable raw-mode branch and redundant comments.

Regression tests first reproduced the failures. The first repair pass passed 34
portable tests and 92 marketplace tests. A fresh Opus 5.5 review then reproduced
an all-excluded false completion, total-limit starvation across facets, retries
crowding out first attempts, deferred work mislabeled as exhausted, malformed-row
loss and request/preference validation gaps.

The second repair pass rejects an excluded implicit default source and conflicting
provider pins, leaves all-excluded requests incomplete, interleaves facet results
before truncation and exposes returned counts. First attempts precede retries;
queued host work remains unverified until settled. Invalid rows no longer discard
valid siblings. Invalid saved soft preferences produce notices, and malformed
request JSON produces the normal error envelope. Consumer query diagnostics and
rate-limit guidance are retained; exact reset times require an explicit quota
inspection instead of a hidden, unbudgeted request.

The final portable suite passes **46 tests**; the full marketplace check passes
**104 tests** and two fresh package builds. The consumer shell suite, Ruff checks,
diff whitespace checks and portable infrastructure-reference scan pass. Docs
lifecycle validation covers 186 documents against HEAD; its 38-test validator
suite passed earlier in this repair cycle. All 23 portable files match the built
artifact. Shared plan-field definitions, explicit branches, shared preference
validation and removed dead code simplify the execution path.

The focused Opus follow-up caught three more edge cases: rate-group scheduling
could still let a retry displace a first attempt, obsolete soft preferences could
block saving defaults, and valid Sourcegraph repository rows were mislabeled as
malformed. Each received a failing regression before its fix. A fresh Claude Code
Opus 5.5 closeout review found **no remaining actionable findings within that final
diff**, reran all 46 portable tests and independently exercised scheduling,
preference saving and mixed Sourcegraph rows with mocked transports. Earlier
findings were closed by the preceding full and follow-up reviews. Review prompts,
logs, reproductions and source fingerprints are retained under ignored
`build/search-skill/opus-review-{final,followup,closeout}/`.

These reviews qualify implementation behavior under fixtures, not current provider
schemas, live health or task relevance. The revised 1.14.1 source had not been activated during this qualification pass;
earlier activation and live canaries do not qualify these new source bytes.

## Additional full review

A subsequent fresh-context Opus 5.5 pass found three defects at that checkpoint despite
46 passing portable tests and a passing consumer suite: run-level dates silently
overwrite facet dates; pending host retries can retain stale unavailable coverage;
and later facets lose the cause when a shared route is suppressed after a rate
limit. The parent independently reproduced all three. This pass made no source
changes. The earlier clean verdict applies only to its reviewed final diff.

Opus also flagged inspection under global pins. Independent checks confirmed that
same-source inspections and discovery-only facet pins work; run-level pins retain
their documented constraints. The relevance follow-up clarifies that distinction in the usage guide. Location-aware discovery remains an unsupported capability.
The full report, validated dispositions and source fingerprints are retained in
ignored `build/search-skill/opus-review-additional/`.

## Relevance selection and durable diagnostics follow-up

The source follow-up in utils-agent 1.15.0 implements the approved
[selection and diagnostics contract](../../agent-marketplace/src/utils-agent/skills/search/references/selection.md).
It adds automatic private XDG runs, redacted transport events, candidate pages,
host-authored relevance assessments, evidence digests and final shortlist receipts.
Skills-searcher separates fetch and display/shortlist limits and uses one engine
run for discovery and enrichment. Legacy metric presentation remains available;
the skill now directs agents to relevance mode and actual content inspection.

All three additional-review defects were reproduced as failing regression tests
before their fixes: conflicting discovery dates now fail, pending retries report
unverified coverage, and provider suppression retains its originating failure.
Global source/provider pins still constrain inspection; facet pins allow separate
read routes.

Current offline evidence: 66 portable engine/selection tests and the extended
consumer shell suite pass; marketplace validation passes 104 tests and compares
two fresh builds. Docs validation passes 54 fixtures and checks 167 documents
against origin/master. The seven archived discovery-pool replays preserve all
167 recorded observations and make each candidate reachable in bounded pages,
with zero candidates automatically selected. The original saved query snapshots,
not current provider responses, supplied those replay pools. Replays and summaries
are retained privately in `build/search-skill/relevance-replay/`.

The code-simplifier pass extracted shared assessment defaults and content-evidence
lookup, removed a redundant temporary, and pruned a redundant transport comment.
It also found and fixed two assessment defects: unrelated content could support a
candidate inspection, and changed evidence could leave answer completeness stale.

Claude Code Opus 5.5 completed an adversarial review and focused closeout. Its six
findings were fixed or resolved by an explicit retention policy: ordinary auth
queries remain searchable; redaction happens before evidence digests; whole-selection
retention omission is disclosed with preserved aggregate counts; relevance display
omissions use the full saved pool; rejected rows appear in the receipt; and suppressed
facets name their originating provider. The closeout passed 65 portable tests and
reported no blockers. Its remaining URL-list redaction note was fixed with the 66th
test. The code-simplifier and writing-for-agents passes covered the changed code and
skill references. Review logs and dispositions remain in ignored
`build/search-skill/relevance-review/`.

The first review attempt through OpenRouter returned insufficient credits. At the
user's direction, review continued through Claude Code; a caller timeout was
recovered using the same native session. The review's first query reproduction
was flawed; the closeout corrected it and verified all three literal queries plus
rejection of a configured credential value. Review assertions are distinct from
independently passing regressions.

Known operational bounds: checkpoints reject payloads over 8 MiB while preserving
the prior checkpoint; interrupted or unrecorded direct work requires reconciliation
and is never replayed automatically. Host elapsed time includes time between dispatch
and settlement. Legacy enrichment can reserve a long deadline; relevance mode has a
bounded candidate page and explicit call/open budgets. These are not proof of live
provider quality or attended host/browser execution.

Offline replay validates
accounting and selection boundaries, not a measured improvement in task quality.
The seven historical comparisons retain their original interpretation. This
qualification preceded publication and activation; those outcomes require a
separate landing receipt. The earlier landing receipt applies to 1.14.1 only.
