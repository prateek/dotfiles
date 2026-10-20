---
status: active
doc_type: research
summary: "Fable review of source selection, adaptive exploration, capability contracts and the proposed evaluation."
created: 2026-10-18
updated: 2026-10-18
related:
  - ../plans/search-source-selection-plan.md
  - ../adr/0055-search-sources-independent-of-providers.md
  - search-source-selection-qualification.md
status_detail: "Planning revisions incorporated and implemented; retained as an input to active quality qualification. The original reviewer process ended with an ACP tool-completion error."
---

# Search source selection: adversarial review

The original review called for targeted clarification before implementation. Preserve explicit
user restrictions, make the evaluation comparison fair, specify the capability
output, and bound the initial evaluation. Fable's proposed relaxation of source
restrictions is not recommended. Existing facet-based requests already support
adaptive exploration within the original limits.

The recommendations below are historical review findings. They were incorporated
into the [plan](../plans/search-source-selection-plan.md) and implemented in 1.16.0;
[ADR 0055](../adr/0055-search-sources-independent-of-providers.md) is accepted.
The [qualification record](search-source-selection-qualification.md) owns current
tests, Opus dispositions, pilot failures and remaining quality limits. Incorporation
does not turn the original ACP failure into a clean reviewer process completion.

## Provenance and limits

A fresh Fable session reviewed the uncommitted plan and ADR against source commit
`7c76225d`, utils-agent 1.15.0. It received the task and file paths, with no parent
conversation or previous review. The launch used `acpx exec` and Claude Code's
`claude-agent-acp` directly because the installed Fable shortcut selected
OpenRouter. The Claude catalog helper also failed to resolve its SDK dependency;
the direct adapter launch succeeded without changing machine configuration.

| Evidence | Observed value |
| --- | --- |
| Session | `e0ef1aef-e960-4cb8-848b-3b38ef816ce1` |
| Requested model and effort | `claude-fable-5-1`, medium |
| Model in ACP usage and native assistant messages | `claude-fable-5-1` |
| Harness | Claude Code 2.1.302, claude-agent-acp 0.85.1, acpx 0.19.4 |
| Final review | Verdict, findings, decisions, delivery order, tests and review limits all returned |
| Process completion | Exit 1; ACP `incomplete_tool_call` for an internal `advisor` call |
| Source audit before this report | No tracked files or reviewed untracked documents changed; Git status unchanged |

The requested read-only constraint was audited, not inferred from permission
flags. The trace contains file reads/searches, Git inspection and one in-memory
planner reproduction. It also contains a failed server-managed `advisor` call;
its model and result are unavailable. The review text is usable, but this was
not a cleanly completed ACP run or an independently verified second review.
Python imports may refresh ignored bytecode; the source hash audit does not
claim that no runtime bookkeeping files were written.

The reviewer inspected the plan, ADR, contracts, planner, registry, engine,
identity, CLI, adapter declarations, skill references and selected consumer/test
sites. It read portions of the qualification research and writing-for-agents
criteria. Some claimed whole-file reads in its final scope summary exceed the
actual tool ranges. No provider calls, account actions, builds or test suites
ran. The primary agent separately reproduced the key planner behavior below.

Local raw evidence is in ignored `build/search-source-review/`: prompt, frozen
documents, JSON event log, original review text and audit. This report retains
the findings needed by the plan. Fable supplied several incorrect line numbers;
the file links and code facts below were checked against the current source.

## Findings and dispositions

### 1. Separate a starting source from a user restriction

Fable P1.1: the plan tells agents to expand through `extend`, while its CLI
examples establish global source and area restrictions. The behavior is real:
[planning.py](../../agent-marketplace/src/utils-agent/skills/search/scripts/searchlib/planning.py)
rejects facets outside those choices, and
[engine.extend](../../agent-marketplace/src/utils-agent/skills/search/scripts/searchlib/engine.py)
preserves choices when resolving new jobs. The
[options reference](../../agent-marketplace/src/utils-agent/skills/search/references/options.md#inspecting-newly-discovered-urls)
documents this contract.

Two local, transport-free cases distinguish the issue:

| Starting request | Append an HN discussion facet |
| --- | --- |
| `choices.source=[reddit]`, `choices.area=[social]` | Rejected: `Facet conflicts with selected sources` |
| One Reddit facet, with no global source choice | Accepted; original budget retained |

Disposition: **accept the guidance gap; reject the proposed semantic change.**
Fable recommended making `--source` and `--area` expandable seeds. That would
weaken explicit restrictions and contradict compatibility goals. Describe
facet-based starting branches for ordinary exploration, and reserve global
choices for actual user restrictions. Add an adaptive request/extension example
beside the focused CLI examples. A genuine scope change needs explicit handling;
it must not silently relax a restriction or reset the budget.

The finding does not establish a general engine blocker: the host-facet route
already works. A regression test should retain both outcomes above.

### 2. Give both evaluation variants the same mechanics documentation

Fable P2.2: “generalized contracts with baseline guidance” can leave one condition
without documentation for `site:`, `--operation` and changed shorthand behavior.
Its failures would then mix interface unfamiliarity with source-selection quality.

Disposition: **accept.** Both generalized-engine conditions should receive the
same CLI help, request schema, options reference, availability information and
mechanical examples. Only source-selection, regional, multilingual and shopping
decision guidance should differ. Freeze the exact instruction bundles and model
settings. Keep the separate comparison with 1.15.0 explicitly confounded by the
new capabilities.

### 3. Bound the pilot and name what cannot be judged

Fable P2.3: evaluating all sixteen families under three conditions and three
repeats could require 144 runs, before additional variants. The plan already says
“selected case” and requires a recorded allowance; 144 runs are therefore a
possible expansion, not a committed requirement.

Disposition: **accept a more concrete pilot; qualify the criticism.** Start with
used SSDs, urgent/new-only SSDs, a source absent from the catalogue, sparse access,
and one language-specific case when a qualified judge is available. Five cases
under three conditions and three repeats give a 45-run ceiling before canaries.
Record the actual call, spending and time allowances before execution; this
recommendation grants no new spending authority. Unrun families and language
accuracy without a capable judge remain unmeasured. Do not weaken critical
failure checks for cases that do run or claim broad non-regression from this pilot.

### 4. Specify scope capabilities without inventing provider rankings

Fable P2.1 and P2.5: a generic “public web scopes” declaration needs a concrete
representation in `capabilities`, host bindings and doctor probes. Query operators,
native domain filters and destination filtering have different implications for
yield and cost.

Disposition: **accept the contract work; reject unsupported provider conclusions.**
The plan already requires qualified operations and explicit bounded probes; add
wire examples and migration rules in the first contract slice. Distinguish a
provider accepting a domain/path request from guaranteeing server-side filtering.
Keep final destination checks authoritative and expose rejected-result counts.
Qualify behavior before changing route preferences.

Fable asserted that only Google-backed routes reliably honor site operators and
that Exa drops path scopes. This review supplied no live or primary-source evidence
for those assertions. Current
[web.py](../../agent-marketplace/src/utils-agent/skills/search/scripts/searchlib/adapters/web.py)
passes domain-filter strings directly to Exa's `includeDomains`; it does not itself
strip paths. The endpoint's accepted semantics remain a qualification question.
Do not adopt a blanket Google-first policy from this review.

### 5. Keep useful structured decisions; limit history machinery

Fable P2.4 recommends replacing `source_decisions` with strings because existing
reports already describe attempted facets. The new records also cover considered
but unattempted branches and connect those choices to executed facets.

Disposition: **accept the complexity concern, not the unstructured replacement.**
Keep bounded typed records and facet links needed for diagnostics. Define the
smallest append-only update rule, or defer superseding-decision history until its
caller-visible use is demonstrated. Avoid a general event graph. A breadth field
may remain host guidance without being an engine routing control; that boundary
must stay explicit. This is a design simplification opportunity, not a demonstrated
correctness failure.

### 6. Weigh the area-only alternative and existing domain-filter path

Fable P2.6 proposes general web discovery for `--area=social` or
`--area=shopping`, with an explicit notice, instead of the planned error. Generic
adapters already declare `post.discover` and `product.discover`.

Disposition: **record the alternative before accepting the compatibility break.**
The error remains defensible for an ambiguous standalone request, while the host
normally supplies facets. If a web fallback is chosen, it must disclose that
coverage and must not imply native platform search. Generic adapters also support
repository and issue discovery; their missing `code.discover` operation is a
specific full-code-search limit, not a lack of all code-related web search.
Define mixed-area shorthand explicitly whichever option wins.

A separate primary-agent check found that an unregistered domain already works
with `area=web`, `source=web`, and `filters.domains=[example.org/community]`.
The planner accepts it, query translation emits the site scope, and the engine
accepts an in-scope URL. The proposed resolver adds consistent source identity,
cross-area use and constraint semantics; it is not required for every new-site
discovery. Correct that distinction in the baseline description and use the
existing path to prototype guidance earlier.

## Smaller corrections

| Fable item | Disposition and recommended action |
| --- | --- |
| Vocabulary in the every-run selection reference | Clarify that the new `source-selection.md` owns this vocabulary. The plan's layout already points there; “runtime selection guide” is ambiguous. |
| `--operation` has no inspection URL argument | Define the new shorthand as discovery-only initially. Keep inspection/read jobs in the existing structured interface. |
| Saved-context origin lacks a portable owner | Name it as host-supplied saved context, if available. Do not imply the engine's existing choices preferences store delivery markets or other context. |
| Wide-search budgets lack a sizing example | Add a bounded example reserving discovery, inspection and retry allowance. Do not adopt Fable's fixed seconds-per-facet formula without latency evidence. |
| ADR acceptance is earlier than its evidence | Name the contract and resolver slices whose combined evidence satisfies acceptance. New-domain identity and filtering are slice 2 outputs; preserve the actual evidence gates. |
| Alias conflict checks use strings | Already covered by the plan's shared-resolver requirement. Include choices validation, initial planning, extension and returned destinations in its implementation checklist. |

Two reproduced baseline problems are already in scope: query translation unions
source/domain constraints while returned-URL filtering intersects them, and path
matching accepts a prefix without a segment boundary. Keep them labeled as
existing defects and add regression cases; they are not new findings against an
implemented version of this plan.

## Recommended next revision

1. Clarify restrictions versus starting facets, the existing generic-domain path,
   the area-only trade-off, and discovery-only operation shorthand.
2. Specify minimal scope-capability and decision-record shapes, compatibility
   examples, and the evidence required before ADR acceptance.
3. Freeze shared mechanics docs for the instruction comparison and choose the
   bounded pilot with explicit judging and runtime limits.
4. Prototype source guidance through existing capabilities while implementing
   only the source-resolution and diagnostic changes that those cases require.

The review does not require another user questionnaire before revising the plan.
Existing restrictions and authorizations remain binding. No implementation fixes,
provider calls, package activation, commits or landing occurred during this review.
