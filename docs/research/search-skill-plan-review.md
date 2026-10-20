---
status: active
doc_type: research
created: 2026-10-17
updated: 2026-10-17
related:
  - ../plans/search-skill-plan.md
  - search-index-eval.md
  - search-index-first-run.md
  - search-index-website-run.md
  - degoog-metasearch-reliability.md
status_detail: "Fresh-context Fable review complete; seven blocking findings for phase 0. Primary-agent dispositions recorded; implementation gates remain open."
summary: "Initial search design review and dispositions informing the implementation plan."
---

# Search skill plan: independent review

## Provenance

This review was a fresh `acpx exec` through Claude Code's ACP adapter (`claude-agent-acp`), run on 2026-10-17 with no conversation history. The prompt named the plan, the evidence docs, and the `writing-for-agents` skill, and granted write access to this file only.

Observed in the review process environment:

| Signal | Value |
| --- | --- |
| `CLAUDE_CODE_ENTRYPOINT` | `sdk-ts` |
| `HERDR_SESSION` | `acpx-312e844e34cb117c` |
| `ANTHROPIC_MODEL` | `claude-fable-5-1` |
| `CLAUDE_CODE_EFFORT_LEVEL` | `medium` |
| Claude Code | 2.1.302 |
| acpx | 0.19.4 |

The model variable and effort level are what the caller requested. No server-side confirmation of the serving model is available from inside the session, so treat the identity as requested rather than independently verified.

An earlier attempt the same day, routed through OpenRouter, was rejected with HTTP 402 before producing findings. That log remains in ignored `build/search-skill-plan/`. The plan's "Validation and review" paragraph and the `docs/index.md` row were updated by the primary agent while this review was being written; the findings below address the plan text as it stood before those edits.

No provider calls, credential reads, provisioning, commits, or edits outside this file were made. Evidence paths below are relative to the repo root.

## Method

I read the plan as an implementer who must build phase 1 from the document alone, then checked every claim in its evidence table against the cited run reports. All eight evidence rows match their sources. The findings are about what the plan leaves undefined, contradicts, or over-specifies, not about the experiments.

## Blocking findings

Each must be resolved in phase 0 before phase 1 starts.

### B1. The ordinary-web default contradicts the free-first policy and depends on an unmeasured route

- **Section:** Outcome and scope; Runtime workflow route table, "Ordinary public web" row.
- **Reason:** Scope says "Free routes are preferred when they meet the task." The route table's first row sends ordinary web lookups to "Existing harness search when adequate; otherwise configured Brave API." Brave is a paid route. Startpage, the free route with 24/27 core coverage and 9/9 platform shapes in `docs/research/search-index-website-run.md`, appears only in the "Free-only" row. "Adequate" has no test, and no run in the evidence set exercised any harness-native search tool, so the first link in the default chain is the only one with zero evidence. An implementer cannot tell which profile is the default or when to leave the harness tool.
- **Fix:** Replace the two profile rows with one ordered chain and a checkable exit test per link, for example: harness search, exit when the top ten contain a source matching the requested domain or facet; Startpage via browser when a browser is already warm or the harness has no search tool; Brave API only when the task budget allows paid calls. State which profile is default when the caller says nothing. Add the harness search tool to the phase 1 baseline so its coverage gets measured before it anchors the default.

### B2. Phase 4 relevance pooling conflicts with Brave's terms as recorded in the protocol

- **Section:** Evaluation design, "Retrieval quality" row; Implementation shape, final paragraph.
- **Reason:** `docs/research/search-index-eval.md:420-425` records that Brave's activation terms restrict response storage and that its Search API terms "contain restrictions on using results to evaluate or benchmark AI models or services." The first run therefore discarded Brave raw results (`docs/research/search-index-first-run.md:29`). The plan's phase 4 pools top-ten results across providers, blinds names, and grades relevance, with Brave as a V1 adapter. The plan says to "preserve the current derived-only Brave handling until its applicable retention rules are verified" but gives no owner or gate for that verification, and phase 4 cannot run as written while it holds.
- **Fix:** Make it a phase 0 line item with a binary outcome: either a confirmed reading of the applicable plan tier's terms that permits the intended evaluation and retention, or Brave is excluded from the pooled judgment lane and from archived fixtures, and the comparison uses Serper, Exa, and the website routes. Record the outcome in the plan.

### B3. The pilot and trigger sets are contaminated by the cases that shaped the routing table

- **Section:** What the experiments establish; Delivery phases, phase 1 and 4; Evaluation design.
- **Reason:** The route table and failure procedures were derived from named core cases: SEARCH-028, SEARCH-030, SEARCH-031, SEARCH-069, and SEARCH-077 (`docs/research/search-index-first-run.md#checked-examples-and-routing-lessons`, `docs/research/search-index-website-run.md`). The plan says "Have the reviewer select holdout families before tuning," but tuning has already happened on those families. The 12-task pilot and the 20 positive plus 20 negative trigger prompts name no cases, only strata, so an implementer will draw them from the same core set. The protocol itself warns that core and extended are cost tiers, not a train/test split (`docs/research/search-index-eval.md`, "How to use the corpus").
- **Fix:** List the already-tuned source families by case ID in the plan and exclude them from pilot and holdout. Draw the pilot from the extended tier and the platform probes, grouped by `source_family`, and freeze the case-ID manifest before `SKILL.md` is written. Commit the manifest of case IDs; IDs are public, provenance is not. Write the trigger prompt set from scratch, not from corpus prompts.

### B4. The evidence corpus the plan depends on carries work provenance into a public repo

- **Section:** Implementation shape, `evals/` row ("references to repo corpus without shipping private provenance"); What the experiments establish.
- **Reason:** `evals/search-index/` is untracked, not ignored, and sits in this branch for commit. `cases.jsonl` holds session IDs, machine labels, project names, and verbatim user prompts. Counting the `machine` field gives 41 of 78 cases from `work-mbp`, each carrying an internal project directory name and the verbatim prompt. `AGENTS.md` states the repo is public and that employer content lives in the work overlay, per `docs/adr/0039-work-overlay-in-work-repo.md`. The plan's privacy claim ("only normalized public queries may leave the machine") covers provider calls but not the commit itself. The skill's `evals/` row promises no private provenance while the referenced corpus is the provenance.
- **Fix:** Decide in phase 0, as Prateek's call: either split `cases.jsonl` into a committed file with case ID, category, tier, normalized prompt, and success criteria, plus an ignored or work-overlay file with session, machine, project, and source excerpt; or move the whole corpus out of this repo and have the skill's `evals/` carry only its own public prompts. The run docs already cite only case IDs, so the split costs little.

### B5. Phase 1 cannot exercise its own routing table

- **Section:** Delivery phases, phase 1 ("existing commands only"); Runtime workflow route table.
- **Reason:** Phase 1 ships the skill with existing commands, and its gate is "trace confirms correct routes." Three of the table's routes (Brave, Serper, Exa) have no existing command. Their only client code is ignored scratch under `build/search-index-eval/`, which a fresh implementer cannot find and which the plan refers to only as "existing ignored harness code." The Camofox website route exists through the browser skill, `gh` and HN Algolia exist, grep.app exists only where the MCP is configured.
- **Fix:** State the phase 1 route subset explicitly: harness search, `gh search`, HN Algolia, grep.app MCP when present, and Startpage or DDG through browser. Scope the phase 1 gate to those routes. Say the API rows are inactive until phase 2, and name the scratch directory or declare it disposable so nobody hunts for it.

### B6. The spend-control machinery is overbuilt for three adapters and has an untestable precondition

- **Section:** Runtime workflow, paid-adapter paragraph; Implementation shape, CLI (`--max-cost`).
- **Reason:** V1 requires a per-run money cap, a "sufficiently current price model," charge estimates with request, minimum, and credit multipliers, and a pre-call allowance check. "Sufficiently current" has no definition, so `doctor` cannot decide it. The three V1 adapters are Brave at a flat published price with monthly credits, Serper on free credits, and Exa on trial credits (`docs/research/search-index-eval.md`, "Initial provider setup"). The plan itself says "the skill cannot promise a billing guarantee" and that account-side caps are the real safeguard. The default budget is three calls, so the cost model can never move more than a few cents per task.
- **Fix:** V1 enforces a call-count cap per task and per provider, records provider, mode, and request count in output, and relies on account-side spend caps. Drop `--max-cost`, the price model, and the multiplier estimates from V1. Reintroduce a cost model only if phase 4 shows calls exceeding what account caps cover.

### B7. Release gates use undefined terms and samples too small to show "at least baseline"

- **Section:** Delivery phases, phase 1 criterion; Evaluation design, "Agent outcome" row.
- **Reason:** Phase 1 passes if it "introduces no critical error," with "critical" undefined there. The agent-outcome gate requires "at least baseline verified completion overall and in each represented category" from a 12-task pilot stratified four ways, which is three tasks per category, repeated three times. A one-task swing flips a category. No tie rule exists.
- **Fix:** Define "critical" once by pointing at the agent-outcome row's list: privacy leak, credential exposure, unbounded spend, fabricated verification. State the comparison rule: per category, skill must not lose more than one task-run across the three repeats, ties pass, and any category drop triggers the held-out extension the plan already mentions. Keep the plan's own sentence that the pilot is a smoke gate, not proof.

## Suggestions

Non-blocking. Each would lower implementation variance or remove sediment.

| Section | Observation | Suggested change |
| --- | --- | --- |
| Invocation and ownership, proposed description | Leads with "Search public sources," which fires on nearly any web question. It overlaps `deep-research` ("compare X vs Y"), `last30days` (recent social discussion), and the harness's own web search. Two trailing negations spend tokens on boundaries rather than branches. | Lead with the distinguishing branches: source-constrained retrieval, GitHub code/issue lookup, product candidates, verification of a claimed source. Put all three overlapping skills in the trigger negative set. |
| Route table, "Semantic discovery" | Exa Auto as a dedicated route has no relevance evidence and no branch trigger. Exa did well on SEARCH-069 and missed three of nine platform probes (`docs/research/search-index-first-run.md`). | Define the branch: no good keywords, or a vaguely remembered target such as SEARCH-024. Label as hypothesis like the other defaults. |
| Route table, "Ordinary public web" fallback | Serper had two zero-result core cases, the most of any API in the first run. It is a reasonable Google-backed lane, but the plan gives no reason to prefer it over Startpage as the fallback. | Say why: Google index, keyword `site:` honoring, or price. Otherwise make the website route the fallback. |
| Implementation shape, V1 adapters paragraph | Eight "named experimental" providers in a 120-line `SKILL.md` are sediment. `writing-for-agents` would prune them. | Keep the list in `search-index-eval.md` only. The helper rejects unknown providers with a pointer. |
| Implementation shape, `evals/` row | Existing packages use the skill-creator `evals/evals.json` shape (`agent-marketplace/src/utils-agent/skills/skills-searcher/evals/evals.json`). HTTP response fixtures for status classification are tests, not evals. | Put prompt evals in `evals/evals.json` and deterministic fixtures under `tests/`. |
| Route table, GitHub row | grep.app's MCP is harness-dependent and its HTTP API returned 429 during setup. The plan says "when available" without saying who checks. | `search doctor` reports grep.app MCP presence per harness. The skill falls back to `gh search code` with path filters, as SEARCH-077 showed works. |
| References, `providers.md` | SEARCH-030 and the X probe failed on date bounds, yet no row maps a freshness facet to provider parameters. | Add a date-filter translation line per adapter with a completion criterion: every date-bounded facet either used a provider filter or was checked on the source page. |
| Runtime workflow, budget paragraph | Three calls including retry is tight for the plan's own repo-then-search-within chain, which spends two before any code query. | Set the budget per route class: three for web, five for GitHub chains. Keep opens at five. |
| Runtime workflow, step 1 | "Reuse known context" can carry private tokens (internal hostnames, DAYJOB names) into a query. The provider-side rule lives in the eval protocol, not in the skill. | Add a step-2 completion condition: the outgoing query contains only public terms, with private context expressed as facets to verify locally. |
| Implementation shape, status list | SearchAPI returned provider-level "no results" inside HTTP 200 (`docs/research/search-index-second-run.md`). The list has `empty`, but the mapping rule is implicit. | State: parsed-zero inside any 2xx is `empty`; challenge markup or 202 is `challenge`; both are never `ok`. |
| Implementation shape, credential paragraph | "Devland service-account bridge" resolves only through `scripts/chezmoi-hooks/op-service-account` and the browser skill's `references/onepassword.md`. The portable package cannot name either. | Define the resolver contract as environment variable names, matching the eval doc's `BRAVE_SEARCH_API_KEY`, `SERPER_API_KEY`, `EXA_API_KEY`, and leave the Devland wiring to host config. |
| Delivery phases, phase 2 | Phase 2 is pre-committed even though the plan says to prune adapters if the baseline is strong. | Make phase 2 conditional on a phase 1 finding that a route the helper would add was needed and unavailable. |
| Validation and review | The paragraph describes the failed 402 attempt as the current state. | Replace with a pointer to this review and the disposition list after phase 0. |

## Strengths

- Every row in the evidence table reconciles with its cited run report, and the table separates consequence from remaining uncertainty.
- The neighbor ownership table is clean. Browser keeps runtime, identity, and cleanup, which matches `agent-marketplace/src/utils-agent/skills/browser/SKILL.md`.
- Defaults are labeled provisional, and the plan refuses to rank providers from URL counts.
- The status taxonomy and the "ok asserts parsed candidates, never relevance" rule encode the Degoog lessons in `docs/research/degoog-metasearch-reliability.md` directly.
- The protocol's split between unchanged-query retrieval and reformulation-allowed agent trials is preserved.

## Readiness verdict

Not ready for phase 1. The design is sound and the evidence is honest, but four phase 0 decisions block an implementer: one ordered routing default (B1), Brave's terms versus the judgment pool (B2), a holdout that excludes the tuned families (B3), and where the corpus provenance may live (B4). B5 through B7 are plan edits that need no new evidence. Once those land, phases 1 and 2 are buildable as written, with phase 2 made conditional on phase 1.

## Dispositions

Recorded by the primary agent after the critique. The findings above refer to the original draft; these dispositions are not a second independent approval.

| Finding | Disposition and change |
| --- | --- |
| B1 | Accepted. Default chain is explicitly free-first: no-incremental-charge harness search, Startpage, then authorized API fallback. Source verification defines success; phase 1 measures the harness route. |
| B2 | Accepted. Brave is excluded from pooled relevance/model benchmarks unless applicable terms explicitly permit the lane. Each provider needs a dated lane-eligibility decision before execution. |
| B3 | Amended. All existing cases/probes are exposed development data, not just the named families. Development pilot may reuse them; fresh trigger prompts and new-family holdout are frozen before skill authoring. Historical IDs are not presumed safe to publish. |
| B4 | Accepted as a publication gate. Existing provenance remains intact locally; implementation must produce audited public fixtures and an ignored local provenance mapping before commit/export. No employer-data transfer is authorized. The current corpus is untracked, not staged. |
| B5 | Accepted. Phase 1 enumerates executable existing routes; APIs activate only after phase 2. Scratch harness location is named and explicitly nonessential. |
| B6 | Amended. Replace the monetary-pricing framework with task/provider call caps and sequential dispatch, retaining explicit paid authorization and account-side limits/prepaid allowance. Cost can remain unknown; call caps are not billing guarantees. |
| B7 | Amended. Critical failures are enumerated once. Ties pass; any category regression pauses release for a pre-frozen extension. This conservative smoke gate avoids claiming statistical significance or inventing an acceptable regression threshold. |

Suggestions incorporated: narrower description, explicit semantic-discovery trigger, website-before-Serper fallback, experimental providers kept outside the skill, separate prompt evals and deterministic tests, harness-level MCP discovery, date verification, five-call GitHub budget, public-only outgoing queries, provider-level empty handling, explicit environment credential interface, and conditional adapter work. HTTP 202 alone is not classified as a challenge; payload/provider semantics decide it.

Execution note: the review file and final critique were delivered. The ACP adapter subsequently ended with an internal error because two `advisor` calls had no returned result. Those advisory calls supplied no usable findings. The completed written Fable critique is preserved; this was not a clean adapter exit. No second review of the revised plan is claimed.


## Subsequent user-directed revision

The next discussion requested optional-source operation inspired by last30days, a shared engine that skills-searcher can reuse, separate social/shopping areas, a router, and land-changes-style arguments. The primary agent reassessed the indexed worktree sessions and implementation artifacts, then revised the plan accordingly. This supersedes the conditional-helper decision in B5/B6's original dispositions and the separate skills-searcher ownership boundary. Adapters are now planned from the first runnable slice; evaluation decides preference and usefulness, not whether differing provider protocols require adapters. The remaining findings on evidence, privacy, retention, bounded calls and eval independence remain applicable. This note is not a second independent Fable review.
