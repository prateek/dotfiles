# Relevance selection and durable diagnostics

Read this for every search answer, including specialized consumers. The engine
owns candidate identity and provenance. The executing agent owns semantic fit,
evidence checks, ordering and the final answer.

## Select within a bounded pool

1. Record the original request, requirements and hard constraints in request
   `intent`. Expand queries into facets with separate fetch and inspection
   budgets. Choose a candidate page size and final `result_limit`. Finish when
   every requirement has a query or an explicit unsupported-evidence gap.
2. Retrieve and let the engine group canonical duplicates. Keep every observation,
   including disagreements. Use `candidates --state PATH --offset N --limit N`
   to inspect another bounded page when the initial pool misses a requirement.
   Finish when each attempted query has an outcome or pending work to reconcile.
3. Assess hard constraints as `met`, `failed` or `unknown`. Classify task fit as
   `direct`, `partial`, `adjacent`, `irrelevant` or `unassessed`, with short reasons
   and references to evidence in this run. Uninspected candidates remain uncertain;
   use `unassessed` or a provisional fit, with `verification: unverified`.
   Finish when each considered candidate has an assessment or a named inspection
   gap. Avoid numerical relevance scores: these labels are judgments, not calibration.
4. Inspect promising candidates and uncertainties that could change the answer.
   Add inspection jobs with `extend`; settle host reads with `continue`. Apply the
   relevant area checks. Reading full content already returned by discovery also
   counts as inspection; popularity enrichment alone does not. Record facet checks
   with `assess`, and candidate fit separately with `select`. Finish when each
   selected claim has inspected support or a clear unresolved qualification.
5. Exclude failed hard constraints; retain unknowns with explicit gaps. Direct
   fit precedes partial and adjacent fit. Among similar fits, compare evidence
   quality, appropriate authority and freshness or maintenance. Use popularity
   only as a secondary signal; missing metrics remain unknown. Preserve useful
   alternatives and disagreements. Providers sharing an upstream do not establish
   independent corroboration. Apply the final result limit only after this step.
6. Save the shortlist, reasons, criteria, gaps and optional `stopping_reason` with
   `select`. Account separately
   for duplicate merging, uninspected candidates, inspected exclusions and relevant
   candidates outside the shortlist. A provider tail has unknown identities and
   often an unknown count; say so. Finish when the saved report matches the answer.

Assessments are agent attestations. The engine checks IDs, current evidence,
references, constraints, ordering and budgets; it cannot establish that an agent
read or correctly understood the content. New observations invalidate an old
candidate assessment until the agent reassesses it.

## Candidate assessment contract

Run `select --state PATH --selection decision.json`. Schema version 1:

```json
{
  "schema_version": 1,
  "run_id": "COPY_FROM_REPORT",
  "assessments": [{
    "candidate_id": "COPY_FROM_CANDIDATE",
    "evidence_digest": "COPY_FROM_CANDIDATE",
    "fit": "direct",
    "inspected": true,
    "verification": "verified",
    "constraints": {"installable": "met"},
    "reason": "The inspected instructions implement the requested workflow",
    "references": ["https://example.org/evidence"]
  }],
  "selected": [{"candidate_id": "COPY_FROM_CANDIDATE", "reason": "Closest supported task fit"}],
  "criteria": "Task fit → inspected contents → authorship; popularity unused",
  "gaps": ["Remaining candidates uninspected within the declared budget"],
  "answer_status": "partial"
}
```

Replace the example constraint with the exact strings from `intent.hard_constraints`
(or `{}` when none). `verification` is `unverified`, `verified` or `failed`.
References must exist in the run; `inspected: true` needs a recorded content read
or returned full content. `assessments` updates the supplied candidates; `selected`
replaces the ordered shortlist. Send intermediate decisions with an empty shortlist
and `answer_status: pending`. `complete` requires no stated gaps or pending work and
verified, inspected selections. Use `partial` for unresolved hard constraints.
Record concise evidence explanations only; private reasoning is not part of the trace.
`stopping_reason` is at most 512 characters: adequate inspected coverage, diminishing
useful evidence, exhausted limits or a specific access gap. It does not change limits.

## Receipt in every answer

Write a compact receipt from the returned structured facts, once per logical run:

```text
Search: <answer_status> · <fetched> fetched → <unique> unique → <inspected> inspected → <selected> selected
Providers: <successful counts>; <named errors, skips or unavailable access>
Selection: <criteria actually applied and any tie-breaker>
Trace: <link to trace.state>
```

When language, market or omitted channels materially affect the answer, add one
optional line: `Coverage: <languages/markets actually examined; material omissions>`.
Distinguish considered/deferred families from attempted sources and inspected
evidence. The report's `exploration` joins source decisions to execution outcomes;
the receipt counts remain execution facts. Do not enumerate an unused catalogue.

The report supplies a factual `receipt` scaffold, and checkpoints retain its
`inline_receipt`. Condense large provider sets while naming material exceptions.
Include only considered sources and providers. Provider readiness, execution
outcomes and answer completeness are separate facts; successful retrieval counts
do not measure relevance. Legacy facet `complete` means declared evidence checks,
while `diagnostics.answer_status` describes the host's answer assessment.
If every content read failed, describe selection as provisional discovery fit;
do not copy an inspected-support criterion from the example. A successful page
read establishes only the returned content, not completeness of an entire thread.

## Storage, recovery and omissions

Executing runs automatically write under
`${XDG_STATE_HOME:-$HOME/.local/state}/agent-search/runs/<UTC-date>/<run-id>/`.
`state.json` is the authoritative resumable record, including the request, expanded
queries, effective options, planned/skipped routes, pending reservations, attempts,
observations, selection and receipt. `state.json.events.jsonl` records transport
starts/finishes, translated requests, pagination calls and elapsed time. Neither
file is a second copy of provider response bodies. Both use schema version 1.
`--state PATH` retains compatibility as an explicit private-storage override;
it does not also write an XDG copy. The report returns the actual paths.

Use the same state for query expansion (`extend` accepts additional discovery jobs),
enrichment, content inspection and selection. Extension keeps the original budget,
deadline and authorization. For a global provider/source pin, inspections retain
that pin; put discovery-only pins on the discovery facets when reads need a different
route. Provide host capabilities at the start. A new run must not reset an exhausted
budget for the same task without revisiting the agreed scope.

Writes are incremental and atomic; transport events are flushed before and after
calls. Files are private, and newly created directories are private. With an explicit
path, choose a private parent directory. A crash can leave pending work or a transport
start without a finish. Reconcile that work through the existing host envelope
protocol; no automatic replay occurs. Write failures fail the command, and may leave
an earlier checkpoint. An oversized checkpoint is rejected before replacing the
previous readable state. A trace link is valid only after a successful write.

Credentials are excluded from requests and transport headers are never logged.
Known credential values, structured credential fields and credential query
parameters in URLs are redacted before candidate identity and evidence digests
are computed. Diagnostics disclose redacted provider rows. Ordinary authentication
examples in search terms or prose remain searchable. Raw native
stdout/stderr stays transient even for `raw`. Redaction cannot detect an unknown
secret embedded in ordinary prose, so submit only evidence suitable for private
local storage. A run containing a retention-restricted provider omits that provider's result
content and **all host selection text** on disk, including unrestricted picks,
because decision prose may quote restricted evidence. Aggregate inspected and
selected counts survive. The live receipt explicitly discloses this whole-selection
omission; later reports label missing data and unknown unique counts.
Opaque internal fan-out, billing and provider tails remain unknown unless measured.
