---
status: active
doc_type: research
created: 2026-10-17
updated: 2026-10-17
related:
  - ../plans/search-skill-plan.md
  - search-skill-plan-review.md
status_detail: "Second Fable review completed; four contract blockers and four suggestions addressed in the clean plan rewrite."
summary: "Follow-up search design review and accepted implementation boundaries."
---

# Search skill: second Fable review

## Provenance

A fresh `acpx exec` ran through Claude Code's `claude-agent-acp`, with requested model `claude-fable-5-1` and medium effort. The session received no chat history. It reviewed the fixed snapshot in ignored `build/search-skill-plan/review-2/plan-before-review.md`, related source code and experiment reports. Its tool trace also shows an inspection of the first review's headings; this was a fresh-context review, not a blinded comparison with the first review.

The exact prompt and full output are retained locally beside the snapshot. The delegate made no file edits or provider calls. It returned the review below and ended cleanly with `[done] end_turn` and process exit 0. Model identity is the requested client configuration, not independently verified server identity.

## Original review

Prateek, here is the independent review. Read-only; nothing changed.

## Verdict

The revision fixes the prior review's substantive blockers (ordered routing, Brave lane eligibility, holdout contamination, public-data gate, defined critical failures). The architecture is right. What remains is contract detail an implementer cannot guess: the host handoff has no resume path, budgets have no owner across that boundary, pin-versus-preference semantics are missing, and typed identity is asserted but never defined. Four blockers, four suggestions.

## Blockers

**B1. Host handoff has no resume contract.** Section: Shared engine and adapter contract. The plan says the engine "emits typed work items, the host calls its tool, and validated result envelopes return to the common pipeline," but the command surface is `plan` then `run --plan`, both one-shot. There is no command that accepts host results and continues, no plan-state file, and no schema for `host-capabilities.json` or for the host result envelope. Browser routes (Startpage/DDG), harness web search, and grep.app MCP are all host work, so in a sparse configuration every web request hits this gap. Fix: add `agent-search continue --state state.json --host-results results.json` (or `run --resume`), define the state file as the resolved plan plus completed jobs and remaining budget, and define the host envelope as `{work_item_id, status, raw_or_parsed_payload, usage}`. Specify who writes host capabilities: the skill's SKILL.md step 1 has the agent emit it from its own tool inventory, with a fixed vocabulary (`web.search`, `web.fetch`, `browser`, `mcp:grep.app`).

**B2. Budget envelopes have no selector and no owner across the host boundary.** Section: contract, budget paragraph. "Three calls for a simple web lookup, five for code chains, eight plus six opens for multi-area" are stated as defaults, but nothing says how the engine classifies a request into those classes, or how `--max-calls` interacts with them. "Source opens" are performed by the host, so the engine cannot count them unless the host reports usage (ties to B1). The skills-searcher migration makes this acute: the current script enriches every result repo with two `gh api` calls (see `enrich_repo` in `scripts/skill-search`), which for 25 results is 50 calls and would blow any default envelope. Fix: make budget a structured request field `{discovery, enrichment, opens, wall_seconds}`, derive defaults from selected areas (web 3, code 5, each extra area +2, cap 8; opens 6), let `--max-calls` override `discovery+enrichment` only, require every host envelope to carry `usage`, and let callers such as skill-search pass an explicit enrichment budget rather than inheriting the interactive default.

**B3. Pin versus preference is undefined for saved and natural-language choices.** Sections: Architecture (routing paragraph), User-facing controls, options precedence paragraph. Two rules collide: "explicit provider/method pins stay fixed" and "a zero-result response can trigger another eligible route within budget." If a saved default is `provider=serper`, is it a pin that forbids fallback or a preference? land-changes resolves this by origin tracking; the browser skill resolves it with "try X first" versus "use X." The plan adopts neither. Also unspecified: whether `--limit` is per facet or total, how a user requests the repo scope (`.agents/search.json` is "only when that scope is requested" but no `--scope` control exists), and what happens when `--source=reddit` meets `--area=code`. Fix: declare that explicit flags and explicit natural language are constraints (no substitution), saved defaults are preferences (fallback allowed, origin reported), add `--prefer-provider`/`--prefer-via` or equivalent language for soft explicit choices, add `--scope=user|repo` to the save/show/reset family, make `--limit` per facet with a total cap, and make a source outside every selected area a resolution error.

**B4. Typed identity and dedupe are asserted, not specified.** Section: contract, "Preserve typed metadata" paragraph. The result boundary has a "canonical identity" field but no per-operation key definition, and dedupe is assigned to the engine without a merge rule. skill-search parity depends on exactly this: `result_key` falls back through (repo, path), (repo, skill name), (url, name), and `merge_results` takes the max of stars/installs and preserves an ordered source list. Code results also need a rule for same path at different refs, and the "two Google wrappers are not independent" claim needs an adapter-declared `upstream` field, which the capability row does not list. Fix: add a phase 0 identity table per operation (`repo.search`: owner/repo; `code.search`: repo+path+ref, with ref-less duplicates collapsed but refs retained; `post.search`: platform+post id; `item.read` for YouTube: `v`; HN: `id`; `product.search`: marketplace+ASIN/listing id+variant), add `upstream` to the capability schema, and define merge as union of sources, per-provider rank retained, numeric fields max, scalar fields first non-empty.

## Suggestions

**S5. Query-syntax ownership is split and invites double translation.** Sections: Architecture ("each area owns query formulation") and contract ("adapter translates a supported request"). If `references/social.md` tells the agent to write `site:reddit.com` and the adapter also appends it for `source=reddit`, queries double up and `site:` honoring becomes unmeasurable. Rule to add: the host never puts provider syntax in `query`; it expresses sources, dates and paths as structured filters, and adapters own every translation. Also state that `query` is implemented as `plan` plus `run` internally, so the two entrypoints cannot diverge.

**S6. Browser route phase and parser location are inconsistent; diagram misroutes skills-searcher.** The rollout table lists browser handoff as Foundation, but phase 1 omits it and phase 2 adds "browser result ingestion." Decide which, and say where the Startpage/DDG result parser lives: it should be a `searchlib` parser accepting a DOM or snapshot envelope from the host, not a browser-skill driver. The mermaid diagram sends skills-searcher into the intent router, while the text says it calls the engine with prepared jobs and the router never sees it. Point the arrow at the engine.

**S7. Eval baseline and fixture reuse need one more sentence each.** "Compare baseline and skill under identical access" is ambiguous: the baseline agent has no CLI, so it cannot reach Serper or Exa. Define baseline as host-native tools only, and name the confound. The phase 2 acceptance "evidence checks catch observed false positives" should name SEARCH-031/028/030 as regression fixtures that count for nothing in the generalization claim. Sparse-capability rows should state they run against fixture `host-capabilities.json` files, which also gives phase 0 a concrete artifact.

**S8. Two dropped contracts: runtime dependencies and credential resolution.** skills-searcher promises stdlib-only `uv run --script`; the plan says "small Python package" without a dependency policy. Choose stdlib-only or PEP 723 metadata and say so, since it affects cold-start and offline behavior for the thin wrapper. The prior review's suggestion to name the credential contract as environment variables (`SERPER_API_KEY`, `EXA_API_KEY`, `BRAVE_SEARCH_API_KEY`) was not carried over; "read the actual runtime resolver" has no definition for a portable package. Adapters should declare `credential.env` and host capabilities may mark `credential_source: host-bridge`.

Minor: the proposed description's last sentence about skills-searcher is architecture, not a trigger, and belongs in the body per writing-for-agents.

## Outline for the clean replacement

1. **Frontmatter and summary.** Status proposed; one paragraph: what the skill does, what it never does (no index, no provisioning, no spend outside caps).
2. **Evidence basis.** The current evidence table only, plus the exposure statement for the 78-case corpus and the measurement caveats. Drop the reassessment narrative, AgentsView inventory, and prior-review commentary; link the review report once under related.
3. **Architecture.** Diagram (corrected), the two routing owners, the concept table (area/source/provider/upstream/method/operation/evidence level), automatic selection order, fallback rule, and the pin/preference rule from B3.
4. **Availability model.** Readiness, observation, coverage states; capability discovery rules; host capability declaration vocabulary.
5. **Invocation and preferences.** Metadata, control table (with `--scope`, prefer variants, `--limit` semantics), examples, precedence, persistence rules.
6. **Engine contract.** Commands including continue/resume; boundary table; host handoff protocol and envelopes; identity and merge table; failure classification; budget structure and defaults; dependency and credential policy; registry policy.
7. **Area policies.** The four-row table plus operation-level gap rule.
8. **Adapter rollout.** The delivery-group table with phases reconciled.
9. **Skills-searcher migration.** Responsibilities split, migration steps, executable resolution, parity test list.
10. **Files and phases.** File layout, phase table with acceptance, ADR note.
11. **Evaluation.** Exposure and holdout rules, public-data gate, provider lane eligibility, recorded conditions, baseline definition, the layer/gate table, critical failures.
12. **Validation.** Implementation checks only. Review history moves to the research report.


## Primary-agent dispositions

The plan was rewritten after this review. Review chronology and superseded decisions stay in these research reports; the plan contains the proposed implementation only. These dispositions are the primary agent's assessment, not a further independent approval.

| Finding | Disposition |
| --- | --- |
| B1: host resume | Accepted. Added continue/state, host capability and work/result envelopes, atomic checkpointing, attempt IDs, idempotent ingestion, reconciliation and preserved deadline. |
| B2: budget ownership | Accepted. Engine owns structured budgets and reservations across host/native calls. Defined area-derived defaults, override behavior and a separate skills-search enrichment allowance including per-file calls. |
| B3: choices | Amended. Added hard pins, soft prefer controls, scope and result-limit semantics. Saved choices retain their original constraint/preference kind; saving a free-only or browser restriction must not weaken it. |
| B4: identity | Amended. Added per-resource identity and provenance-preserving observation groups. Generic numeric-max/first-nonempty merging is rejected for prices and conflicting evidence; the skills-searcher compatibility formatter retains its existing metric policy. |
| S5: query translation | Accepted. Structured terms/filters are translated once by adapters; explicit native dialect jobs support the existing skill-query builder. query uses the same resolver/runner. |
| S6: browser and diagram | Accepted. Foundation includes browser handoff, resume and parsing; parsers live in searchlib, controllers in browser. Skills-searcher points directly to the engine. |
| S7: eval comparison | Amended. Added equal-tool instruction ablation and separate host-native comparison with the tooling confound identified; source regressions remain development fixtures and sparse tests use host manifests. |
| S8: runtime/secrets | Accepted. Python 3.14+, stdlib and uv-script contract; declared environment credential names and host bridge responsibilities. |

Validation of the rewrite: document link checks, 38 docs lifecycle tests and repository document validation, plus `git diff --check`. No skill implementation or host activation was performed.
