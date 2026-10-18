---
status: active
doc_type: research
created: 2026-09-26
updated: 2026-10-17
owner: Prateek
status_detail: "Historical corpus, API and website retrieval runs complete; relevance and agent-task judgments pending."
summary: "Normalized historical search cases, provider coverage and evaluation methodology."
related:
  - ../plans/search-skill-plan.md
---

# Search-index evaluation from recent sessions

This corpus turns actual requests from agent sessions into standalone search
tasks. Cases are selected for relevance and breadth, regardless of conversation
date. It is intended to compare search providers against Prateek's workload,
including repository discovery, source-code lookup, documentation, discussion
search, and product research where those tasks occur in the available history.

The machine-readable cases live in [cases.jsonl](../../evals/search-index/cases.jsonl).
The [first retrieval run](search-index-first-run.md) records 270 core searches
and source-specific platform discovery. Its result counts are not relevance
scores; blinded judgments and completed-agent trials remain pending.
The [added-provider run](search-index-second-run.md) extends retrieval to
OpenSERP OSS and SearchAPI.io.
The [Degoog run](search-index-fourth-run.md) compares local metasearch engine
configurations against the same frozen queries.
The [website run](search-index-website-run.md) sends those queries through an
isolated Camoufox browser to the public search sites and records access gates.
The [provider landscape](../../evals/search-index/search-provider-landscape.html) gives a visual map of
source types, current published prices, and retrieval-test status.
Historical prompts establish task provenance, not correct answers. Published
evaluation prompts are editorial adaptations. Private source excerpts and session
locators are retained locally under ignored `build/search-skill/landing/` and are
excluded from the public corpus.

## Collection and coverage

The initial inventory query covered **2026-08-27 17:50:54 UTC through 2026-09-26
17:50:54 UTC**. AgentsView v0.42.0 supplied the inventory and message evidence
through its CLI, including children, automated sessions, and one-shot sessions.
The user subsequently removed the date restriction, and the relevant Cursor
candidates were merged into the main corpus. Their message dates remain unknown
in source metadata; this does not restrict their use in evaluations. The original
collection counts below describe that initial inventory, not an all-history scan.

The inventory contains 6,005 session records across four providers and five
machine labels. A machine label is not necessarily a distinct physical machine.
This is the locally available AgentsView corpus, not proof that every session
from every machine is present. Archived host heartbeats are stale: m4mini last
reports September 17, personal-mbp September 20, and work-mbp September 23.
Indexed sessions can be newer than those heartbeats, so both evidence sources
must be reported separately. No archive refresh or live configuration change
was performed for this collection.

| Indexed provider | Session records |
| --- | ---: |
| Claude | 4,743 |
| Cursor | 937 |
| Codex | 324 |
| OMP | 1 |

Every inventoried session was fetched successfully. The CLI returned 14,622
user-role rows: 8,985 with timestamps inside the window, 1,062 outside it, and
4,575 Cursor rows without individual timestamps. Cursor's displayed session
dates may reflect import time. These counts include
system scaffolding and generated assignments recorded as user messages; they
are not counts of human requests.
No session returned fewer user-role rows than its inventory user-message count.
Some returned more because their user-role stream also contains scaffolding.

| Machine label | Session records | Latest indexed session activity, UTC |
| --- | ---: | --- |
| `work-mbp` | 3,859 | 2026-09-24 00:49:54 |
| `prateek-personal-mbp.local` | 1,448 | 2026-09-24 10:03:07 |
| `m4mini` | 626 | 2026-09-17 16:52:03 |
| `Mac.lan` | 61 | 2026-09-26 17:11:49 |
| `prateek-personal-mbp` | 11 | 2026-09-26 17:51:07 |

The inventory was read during active sessions, so its latest activity can
postdate the original cutoff. The local
archive's five labels should not be interpreted as five independent hosts.

Raw CLI responses and extraction scratch files remain outside the repository at
`/tmp/search-index-eval-20260926/`. They are not an external-provider input.

## Selection principles

- Favor distinct user information needs over repeated implementation followups.
- Preserve exact source session IDs and message locators in the private originals;
  publish anonymous family IDs for grouping related cases.
- Exclude generated agent assignments, fixtures, boilerplate instructions, and
  the search-provider conversation that requested this corpus.
- Keep a small core set for inexpensive comparisons and an extended set for
  coverage. Neither is a random sample or an estimate of workload frequency.
- Record absent categories as gaps. Do not manufacture historical examples to
  fill the shopping, social, or local-service categories.
- Label private-context and live-interaction dependencies. Those cases must not
  silently count as ordinary public-index failures.

## Selected corpus and files

The corpus contains **78 cases from 61 sessions**: **27 core**, **47 extended**,
and **4 controls**, with provenance from 77 distinct user messages. All 24 Cursor
candidates are represented: 23 became new cases, and the duplicate git-spice
comparison was merged into `SEARCH-045` as an additional source. The core now
includes direct Reddit retrieval and two Go source-code search cases.

- [cases.jsonl](../../evals/search-index/cases.jsonl): standalone evaluation prompts,
  criteria and anonymous source-family grouping, without private source excerpts.
- [coverage.json](../../evals/search-index/coverage.json): public case counts,
  evaluation groups and split policy. The original inventory remains local.
- [platform-probes.jsonl](../../evals/search-index/platform-probes.jsonl): 18
  explicitly synthetic, source-specific social and shopping probes. These have
  no session IDs and are not counted in the 78 historical cases.

| Evaluation group | Core | Extended | Controls |
| --- | ---: | ---: | ---: |
| GitHub repository/skill discovery | 4 | 10 | 0 |
| GitHub code, issues, and history | 7 | 13 | 0 |
| Technical documentation and APIs | 3 | 14 | 0 |
| Social and forum research | 5 | 3 | 0 |
| YouTube discovery and recovery | 2 | 0 | 0 |
| Software comparisons | 2 | 5 | 0 |
| Hardware and local models | 2 | 1 | 0 |
| Local events and service contacts | 1 | 1 | 0 |
| General web facts | 1 | 0 | 0 |
| Private/local access controls | 0 | 0 | 4 |

`category` preserves the narrower use case; `evaluation_group` is the shared
reporting bucket. Each record also supplies capability tags, evidence-based
success criteria, freshness requirements, and access constraints. `source_family`
and `related_source_families` are anonymous grouping IDs. The private originals
retain canonical session IDs, message locators, timestamps, excerpt hashes and
source wording for local reconstruction; those fields are not published.

The core is intentionally diverse and GitHub-heavy, reflecting the stated
priority. It is a curated sample of information needs, not a statistical sample
of all sessions. First-pass filtering left 2,616 timestamped candidate rows in
439 sessions; 2,088 had distinct exact text. Those candidates were triaged for
search relevance, and selected prompts were checked against their source
messages. A further 4,543 Cursor candidate rows were triaged for relevant tasks.
The review did not read every assistant/tool message in every session.

### Gaps and gates

There are no defensible historical inventory/transaction cases for Amazon,
Alibaba, Uber Eats, Instacart, or Facebook Marketplace in this selection. The
current conversation listing those services was excluded as circular. Local
event schedules are useful live-data cases but do not substitute for
address-specific shopping availability. A shopping suite needs separately
labeled new prompts or further historical evidence.

Social cases include direct Reddit retrieval and cross-platform research; they
do not establish balanced coverage of Reddit, HN, X, and Facebook individually.
Code search now includes upstream Go escape-analysis tests and production
`runtime.GC()` call sites alongside repository discovery and issue investigation.
Travel booking is absent. Sensitive personal health and adult-content
preference prompts were excluded from exported cases.

The [platform probes](../../evals/search-index/platform-probes.jsonl) address
the source gap without changing historical provenance: two each for Reddit,
Hacker News, YouTube, X, Facebook Marketplace, Amazon, Alibaba.com, Uber Eats,
and Instacart. They separate URL discovery from comment/video evidence and
live listing, offer, stock, or delivery verification. Shopping probes use ZIP
10016 and USD; cases needing a full address or account must be marked
**access-gated** until that context is available. Do not count a web-indexed
product URL as proof of current price or availability. Compare results from
different configurations at the same time and location, and judge source
evidence against the live page or a frozen snapshot. All 18 are
`preflight_only` with an unverified live-source oracle: calibrate a reachable
answer or an independently checked empty result before including a probe in
scored provider rankings. A missing or gated source is not a relevance miss.

`SEARCH-052` (Orca release history) has unverified public-source availability.
Resolve that access gate before scoring it as a public retrieval task. The
four controls test whether an agent requests private documents, session history,
meeting context, or local logs rather than inventing an answer from public search. They belong
in the task-routing evaluation, not the raw search-index ranking.

### Representative normalized prompts

These prompts are editorial adaptations. The private originals retain the source
wording and its locator separately.

**SEARCH-019 — Compare Setapp command-line projects through source and issues**

Find GitHub projects for installing Setapp applications from the command line. Compare their actual installation mechanisms using source code, documentation, and issues, including maximlevey/setapp-cli. Explain known authentication or installation limitations and distinguish verified functionality from claims.

**SEARCH-028 — Recover a video link buried in BetterDisplay issue comments**

Find BetterDisplay GitHub issues or comments that link to an app or video demonstrating a multi-screen zonal layout on Windows. Return the exact comment permalinks, the linked video or application, and why it matches.

**SEARCH-031 — Find an OSS Granola alternative mentioned on YouTube**

Find the open-source Granola alternative featured on the GithubAwesome YouTube channel before 2026-09-14. Return plausible matches with the exact video or description evidence and canonical repositories.

**SEARCH-012 — LM Studio versus oMLX**

Compare LM Studio, oMLX, and relevant alternatives for serving local models on an M3 Ultra Mac with 256 GB RAM. Include upstream documentation and first-hand reports from Reddit, Hacker News, X, GitHub, or YouTube; distinguish quality, compatibility, and measured performance.

**SEARCH-010 — M3 Pro Wi-Fi and MLO compatibility**

Does an M3 Pro MacBook Pro support Wi-Fi Multi-Link Operation? Can it connect to a router SSID with MLO enabled, and does that imply it is actually using MLO?

**SEARCH-003 — Public puppy-playdate schedules**

Find publicly listed puppy-playdate sessions at Andrea Arden during the four weeks starting {{evaluation_date}}. List dates, days of week, locations, eligibility requirements, prices, and booking links; flag anything that cannot be verified publicly.

**SEARCH-050 — Raycast clipboard and snippets API boundaries**

Can Raycast clipboard history and snippet management be accessed programmatically? Find the supported APIs, commands, or import/export mechanisms, and distinguish extension-only access from access by external scripts.

**SEARCH-033 — Find up-to-date Wandering Inn scale statistics**

Find word-count, chapter-count, and volume-scale statistics for The Wandering Inn, stating the date and counting scope of each figure. Prefer the author site or transparent community counts, and distinguish web-serial, rewrite, and published-edition counts.

**SEARCH-056 — 8BitDo Zero 2 macOS/iOS community setup reports**

Find relevant Reddit discussions about connecting an 8BitDo Zero 2 to macOS and iOS. Summarize working setups, common connection problems, and community workarounds, with links to the actual threads.

**SEARCH-069 — Locate upstream Go compiler escape-analysis tests**

Find concrete tests in the upstream Go compiler/runtime source that compile sample programs and assert escape-analysis or allocation behavior. Show the test harness, representative test cases, and how assertions are checked.

**SEARCH-077 — Production precedent for explicit Go garbage collection**

Find documented examples of Go applications explicitly calling runtime.GC(). Explain the circumstances, motivation, and tradeoffs using concrete source call sites and maintainer discussions, and distinguish production code from tests or benchmarks.

## How to use the corpus

Run two evaluations separately. First compare retrieval: give each applicable
provider the same query, retrieve at most ten results, and assess those results
without allowing an agent to rewrite the query. Then compare completed tasks
with a fixed model, prompt, fetch tool, and search-call budget. A provider that
wins the second evaluation may be benefiting from extraction or agent behavior,
not solely from its index.

Natural-language task prompts are not automatically valid GitHub or regex-search
queries. For the retrieval comparison, author and freeze a small query set per
case and interface before running providers. Compare like interfaces within
their capability groups. In the task comparison, the agent may translate the
same task into provider-specific query syntax within the fixed call budget.

Resolve date placeholders to a single recorded evaluation date. A task that
originally asked for the latest release or next month's schedule should have
fresh judgments at run time. Historical replay is a separate experiment and
requires date-bounded evidence; do not grade a current recommendation against
an old session's answer.

Core and extended are cost/coverage tiers, not independent train/test splits.
Related source families occur in both tiers. Use the core cases to establish the
harness and rubric, then freeze those decisions before running the extended
cases. For a tuning holdout, group by `source_family`, any merged
`related_source_families`, and related topic so followups and near-duplicate tasks
stay together. Neither this document nor its
dataset provides a hidden test set.

For each applicable case, collect:

| Measure | What to record |
| --- | --- |
| Retrieval usefulness | Human relevance grades for the first ten results, first useful rank, and nDCG@10 once judgments exist. |
| Coverage | Which required evidence facets have support; distinguish partial answers from complete coverage. |
| Source quality | Primary documentation/source code versus summaries, stale pages, duplicates, and unrelated results. |
| Freshness | Retrieval time, publication/update date where available, version/commit, and any mismatch with the task's time frame. |
| Fetchability | Whether the result yields usable content through the same fetch tool; report separately from retrieval. |
| Task outcome | Whether the fixed agent meets the case-specific criteria with supported citations. |
| Latency and cost | Search and extraction costs, model tokens, total elapsed time, errors, retries, and rate limits. |

Pool candidate results across providers, deduplicate URLs, and judge relevance
without provider names. Do not calculate recall against the entire web; a pooled
judgment set can only support recall relative to that pool. A past assistant
answer or recommendation is not a relevance label.

Report category results and macro averages alongside any overall score. Keep
public search, private/local-context controls, and tasks requiring an
authenticated browser in separate result groups. An unsupported source should
be marked unsupported, not silently dropped. If measuring the usefulness of a
whole provider stack, report that missing capability as a coverage gap.

Preserve a frozen record of provider endpoint, mode, filters, query, execution
time, and cost. Retain returned URLs/content only where the provider's terms
permit it; settle retention before collecting the judgment pool. For live
shopping tasks, hold geography, currency, delivery address context, and
collection time constant. For code
tasks, inspect the referenced file and revision before accepting a snippet.

Send only the normalized public evaluation prompt to a provider. Session IDs,
source excerpts, private paths, access notes, and internal project names are
local provenance. Do not send the entire JSONL record as an API request. No
provider call has received a raw session excerpt or session identifier; the
retrieval runs used only the frozen public query fields derived from cases.

## Initial provider setup, 2026-09-27

Seven new provider accounts have working API keys in the Devland vault. Each
passed a live search using a generic SearXNG documentation query. These checks
established access. The subsequent core retrieval comparison is described
below; relevance scoring remains pending.

| Provider | Devland key item | Verified access | Initial allowance |
| --- | --- | --- | --- |
| Serper | `SERPER_API_KEY` | Search, HTTP 200 | Free credits; no card added |
| Brave | `BRAVE_SEARCH_API_KEY` | Web Search and LLM Context, HTTP 200 | $5 monthly Search credits; auto-reload off |
| Exa | `EXA_API_KEY` | Auto search, HTTP 200 | $10 trial credits |
| Parallel | `PARALLEL_API_KEY` | Fast search, HTTP 200 | $20 trial credits |
| Tavily | `TAVILY_API_KEY` | Basic search, HTTP 200 | 1,000 credits/month; pay-as-you-go off |
| Octen | `OCTEN_API_KEY` | Search with highlights, HTTP 200 | $5 trial credits |
| Perplexity | `PERPLEXITY_API_KEY` | Search, medium context, HTTP 200 | $10 trial credits; auto-refill off |

No credit purchases were made. Brave's free-plan activation saved the
authorized card; its dashboard showed $0 purchased credits and auto-reload
disabled. Prateek completed Perplexity's payment verification, and its dashboard
showed $10 in credits with auto-refill off. The other five accounts used their
free allowances without adding a card. Trial balances and terms are snapshots,
not permanent entitlements.

Existing GitHub authentication passed repository and code searches. The
[official grep.app MCP endpoint](https://vercel.com/blog/grep-a-million-github-repositories-via-mcp)
at `https://mcp.grep.app` passed a code-search request without a key; the ordinary
grep.app API returned HTTP 429. Hacker News's Algolia endpoint also passed a
search. Existing xAI and OpenRouter credentials authenticated successfully;
an xAI search-tool call has not been tested.

A task-owned local SearXNG container runs at `http://127.0.0.1:18888`.
It binds only to localhost and has Docker restart policy `no`; it is not a
boot-managed service or an owned search index.
Its current baseline enables Bing and Yahoo for general web search and the
dedicated Hacker News and YouTube engines. On 2026-09-27, web returned 11
results (10 Bing, one Yahoo); the HN-only and YouTube-only probes returned 30
and 19 respectively, with no engine errors. A site-scoped URL-discovery query
returned at least one matching-domain URL for each of the nine social/shopping
platforms, but relevance, freshness, and live inventory were not judged.

The previous Google-only probe returned a SearXNG `Suspended: CAPTCHA` error.
Further probes found Qwant CAPTCHA, DuckDuckGo CAPTCHA, and the scraped Brave
engine rate-limited. Mojeek and Startpage selections fell back to other
engines, so they were not credited. These engines are out of the current
baseline; the authenticated Brave API is a separate provider. The task-owned
settings backup is at
`~/.local/state/search-index-eval/searxng/config/settings.yml.pre-platform-coverage-20260927`.
SearXNG is a metasearch service here and maintains no independent index.
Treat a CAPTCHA or rate limit as an availability failure, never as a relevance
miss. Use Serper for the Google-backed lane rather than repeatedly probing
Google's scraped page through SearXNG.

The first retrieval comparison used SearXNG web, Serper, Brave Web Search,
Exa Auto, Parallel Fast and Advanced, Tavily Basic and Advanced, Octen Search
with highlights, and Perplexity Search with medium context. Brave LLM Context
passed one separate source/grounding canary; it does not return the same ranked
result interface and belongs in a later task-level comparison. See the
[first-run findings](search-index-first-run.md) for the measured results and
limitations. Bing reported an HTTP error during an initial canary but not
during the subsequent core run, so SearXNG availability needs continued checks.
GitHub repository/code search and grep.app belong in the relevant category
comparisons. The [source-access matrix](social-shopping-search-sources.md)
records native social and shopping routes and their gates. Provisioning web
providers establishes URL-discovery candidates, not native coverage of full
threads, posts/replies, video content, Marketplace inventory, or address-bound
prices and delivery.

### Additional candidates and access

The first run did not include these providers. The
[added-provider run](search-index-second-run.md) covers OpenSERP OSS and
SearchAPI.io, and the [Kagi run](search-index-third-run.md) covers Kagi Search
API with the same frozen queries. Keep the same evidence checks before
comparing scores.

| Candidate | Distinct reason to test | Access and cost snapshot, 2026-09-27 |
| --- | --- | --- |
| [Kagi Search API](https://help.kagi.com/kagi/api/search.html) | Managed search combining [Kagi's Teclis/TinyGem indexes with other sources](https://help.kagi.com/kagi/search-details/search-sources.html); test web, discussions, and video discovery against the existing ranked-result modes. It is not a GitHub code index. | [Commercial API](https://kagi.com/api/pricing) at $12 per 1,000 searches; billing and a Search-only key are active. The [frozen-query run](search-index-third-run.md) used 37 requests for $0.444, with a $5 Kagi usage limit. [Consumer Search subscription and API billing are separate](https://help.kagi.com/kagi/api/quick-start.html). |
| [OpenSERP OSS or Cloud](https://openserp.org/docs/oss-vs-cloud/) | Compare Google/Bing result availability with the local SearXNG baseline. OpenSERP scrapes external search engines and has no independent index; its Yandex/Baidu routes may add regional coverage. Do not count OSS and Cloud as independent indexes. | OSS was run locally. [Cloud](https://openserp.org/pricing/) advertises 60 one-time starter credits without a card, but its activation link was invalid or expired and resend produced no new mail. |
| [Degoog](https://github.com/degoog-org/degoog) | Self-hosted metasearch with a JSON API and installable engines; compare engine selection and platform URL discovery with SearXNG. It does not add an independent index or GitHub code search. | [Native Bun trial](search-index-fourth-run.md) complete on the frozen queries. No API fee; local compute and upstream availability apply. Startpage + Bing found a source URL in 8/9 platform probes. |
| [OpenSerp.dev](https://openserp.dev/) | Separate hosted service with a similar name. Its Google/Yahoo/Bing/Brave SERPs overlap existing modes; test only if the advertised low price warrants a reliability comparison. | Account and API key created. The balance is zero; the $5 starter checkout is sold out, the $25 checkout offers cryptocurrency only, and a direct API probe received HTTP 403/Cloudflare 1010. Lists $0.0002 per successful API call. |
| [SerpApi](https://serpapi.com/search-engine-apis) | Test its dedicated Amazon/product, Google Shopping, and YouTube search modes on the synthetic platform probes. A general Google SERP mode would overlap Serper; retain it only as a quality or reliability control. | Account created and email confirmed. The [free plan](https://serpapi.com/pricing) offers 250 searches per month, but the phone-verification flow reached an image reCAPTCHA before issuing a key. |
| [SearchAPI.io](https://www.searchapi.io/pricing) | Test [GitHub repository, issue, and discussion search](https://www.searchapi.io/github-search-api) plus Amazon/Shopping/YouTube verticals. Its documented GitHub search types omit code, so keep native GitHub search and grep.app for source files. | Account and API key created; general web and selected vertical retrieval ran on the 100 free starter requests. No paid plan. |

Kagi returned a different managed web result mix, but its YouTube URLs need
source validation. SerpApi and SearchAPI.io are higher priority than another general SERP mode for
shopping and video. OpenSERP earns a focused availability test because the
SearXNG Google engine hit CAPTCHA; it should not count as an independent index.
The dedicated commerce modes return public listings. Current inventory,
location-specific prices, and delivery still require source-side verification.
The OSS and Cloud OpenSERP candidate above is `openserp.org`, distinct from
`openserp.dev`.

| Platform | Current runnable discovery lane | Further evidence/access gate |
| --- | --- | --- |
| Reddit | Site-scoped web search | OAuth native search and comment retrieval; web snippets are incomplete. |
| Hacker News | SearXNG HN engine; public HN Algolia | Official item API or canonical thread for comments. |
| YouTube | SearXNG YouTube engine; site-scoped web search | Data API key/quota for native metadata; transcript or playback for in-video claims. |
| X | Site-scoped web search | X developer API/credits for timely posts and replies. An xAI key is not an X API token. |
| Facebook Marketplace | Site-scoped web search | Signed-in, location-aware Marketplace for live listings. |
| Amazon, Alibaba.com | Site-scoped web search | Source page for offers/MOQ; native buyer search access is gated or unverified. |
| Uber Eats, Instacart | Site-scoped web search | Consumer address/account/time for inventory, price, and delivery; partner APIs are gated. |

Brave's activation terms restrict response storage, and its
[Search API terms](https://api-dashboard.search.brave.com/terms-of-service)
also contain restrictions on using results to evaluate or benchmark AI models
or services. The Search plan adds inference permission. Confirm the permissions
needed for the intended evaluation and retention before including Brave in an
archived judgment pool.

The nonsecret local inventory is
`~/.local/state/search-index-eval/providers.json`; it records vault item IDs and
verification status. Credentials and payment details are not stored in this repo.

## Full case catalog

Full source and normalized prompts are in the JSONL. Use the session ID and
ordinal with `agentsview session messages <id> --around <ordinal> --before 0
--after 0 --json` to retrieve a source message. Canonical IDs include any provider
prefix shown below.

| Case | Tier | Use case | Source session | Ordinal |
| --- | --- | --- | --- | ---: |
| SEARCH-001 | core | Obsidian CLI and agent skills | `441058a8-bbdc-433e-97a0-da7189314db3` | 0 |
| SEARCH-002 | extended | Granola MCP through mcporter | `codex:01a05338-e792-7d53-bfe9-4c157b27b8dd` | 93 |
| SEARCH-003 | core | Public puppy-playdate schedules | `codex:01a05382-4607-79f2-84e5-880c75da16e5` | 0 |
| SEARCH-004 | extended | Obsidian dashboard plugins | `codex:01a05d3b-5298-76f1-9a60-6cea6c2a4cd2` | 41 |
| SEARCH-005 | core | Modern Notational Velocity forks | `codex:01a07ed3-fa6c-7980-9db8-fee849d08895` | 49 |
| SEARCH-006 | extended | Dropbox alternatives | `codex:01a07edb-f8dd-71b0-94c7-96473fd66375` | 0 |
| SEARCH-007 | core | How people are leaving Dropbox | `codex:01a07edb-f8dd-71b0-94c7-96473fd66375` | 27 |
| SEARCH-008 | core | Syncthing selective sync and S3 | `codex:01a07edb-f8dd-71b0-94c7-96473fd66375` | 53 |
| SEARCH-009 | extended | Evaluate sudo-touchid repository | `codex:01a07f37-5c51-7c50-ace7-5aa2956c0148` | 10 |
| SEARCH-010 | core | M3 Pro Wi-Fi and MLO compatibility | `codex:01a0c147-2059-7161-9329-21ae0b591279` | 25 |
| SEARCH-011 | core | Best local models for M3 Ultra 256 GB | `codex:01a0c148-d097-7461-93da-dbec6cfc6a20` | 6 |
| SEARCH-012 | core | LM Studio versus oMLX | `codex:01a0c148-d097-7461-93da-dbec6cfc6a20` | 27 |
| SEARCH-013 | extended | Readable iPhone roleplay clients | `codex:01a0c185-4bf3-7162-9be0-e674acf31108` | 0 |
| SEARCH-014 | core | Pi-based roleplay harnesses | `codex:01a0c185-4bf3-7162-9be0-e674acf31108` | 35 |
| SEARCH-015 | extended | Storytelling agent skills | `codex:01a0c185-4bf3-7162-9be0-e674acf31108` | 136 |
| SEARCH-016 | extended | Well-liked LitRPG discovery | `codex:01a0c185-4bf3-7162-9be0-e674acf31108` | 228 |
| SEARCH-017 | extended | AgentsView retention code versus roadmap | `codex:01a0c24e-e3b8-7711-a348-573b995eeb3b` | 141 |
| SEARCH-018 | extended | Import browser AI conversations into AgentsView | `codex:01a0debe-e69a-7220-9459-283e55f860ec` | 0 |
| SEARCH-019 | core | Compare Setapp command-line projects through source and issues | `728676d8-75af-4eda-94f2-8dbc1a189c9d` | 428 |
| SEARCH-020 | core | Find official Cloudflare R2 CLI or MCP tooling | `codex:01a05331-2102-71b1-a270-606d923f56ae` | 11 |
| SEARCH-021 | extended | Discover browser automation agent skills with provenance | `codex:01a0536b-c4c1-7f13-b404-8e54ef580c2e` | 25 |
| SEARCH-022 | extended | Locate public browser-interaction prompts from agent vendors | `codex:01a0536e-c1e4-7353-adb4-acc3fb29d7b9` | 0 |
| SEARCH-023 | extended | Find agent self-reflection and self-improvement skills | `codex:01a0539f-e31d-79a2-9c11-00e12acfaf21` | 0 |
| SEARCH-024 | extended | Recover a vaguely remembered Hermes-related game-driven agent project | `codex:01a0539f-e31d-79a2-9c11-00e12acfaf21` | 48 |
| SEARCH-025 | core | Discover OSS and paid alternatives to Raycast | `codex:01a06ab5-d11d-7663-baa3-3372bce89d9a` | 0 |
| SEARCH-026 | extended | Assess current cmux worktree-tracking support | `codex:01a07465-2151-7d61-accc-c9f8b54ae5b5` | 0 |
| SEARCH-027 | core | Native macOS/iOS agent workspace alternatives across social sources | `codex:01a07465-2151-7d61-accc-c9f8b54ae5b5` | 21 |
| SEARCH-028 | core | Recover a video link buried in BetterDisplay issue comments | `codex:01a076e6-4a96-7fa1-9fd7-bea26c301aad` | 0 |
| SEARCH-029 | extended | Verify native monitor-zone support on high-resolution Macs | `codex:01a076e6-4a96-7fa1-9fd7-bea26c301aad` | 23 |
| SEARCH-030 | core | Extract temporally bounded YouTube GitHub project roundups | `codex:01a0a144-63a0-7550-9323-592c71b4b47c` | 35 |
| SEARCH-031 | core | Find an OSS Granola alternative mentioned on YouTube | `codex:01a0a144-63a0-7550-9323-592c71b4b47c` | 66 |
| SEARCH-032 | core | Find VMware Unity-like remote application windows for Macs | `codex:01a0c17f-9267-7141-93d8-d699df832a73` | 0 |
| SEARCH-033 | core | Find up-to-date Wandering Inn scale statistics | `codex:01a0c203-d21b-7010-89af-218726d970a2` | 60 |
| SEARCH-034 | extended | Find Terraform providers for UniFi and OpenWrt | `codex:01a0c119-bc12-7c43-8a47-ae2047501af7` | 20 |
| SEARCH-035 | extended | Find Arq Backup source repositories and CLI support | `f0702ffc-d631-4f91-bb0a-46fee941bede` | 527 |
| SEARCH-036 | extended | Locate the source repository for the mo command | `f28496a9-c3e2-472e-8377-5b7499b4d894` | 0 |
| SEARCH-037 | extended | Verify Nix/macOS hostname-setting caveats | `fd7cc05d-964a-40ef-862b-e3c742370cf3` | 222 |
| SEARCH-038 | extended | Verify a service contact address from authoritative sources | `codex:01a05517-9940-7671-a4cd-f25767810fc9` | 191 |
| SEARCH-039 | core | Slack practices for remote teams with many channels | `1d57daed-cb72-4038-acd8-5698002a8ebe` | 0 |
| SEARCH-040 | extended | Claude Code queued messages | `1e43f307-e2d7-429d-9577-f12982454c7c` | 0 |
| SEARCH-041 | extended | Selective Slack Dock badges on macOS | `2193bb25-f216-4280-bb90-4d80dc0ae52c` | 0 |
| SEARCH-042 | core | Discover popular Git worktree managers | `2d035362-92aa-4972-b5fe-999b16de919b` | 221 |
| SEARCH-043 | extended | Community practice for large-monorepo worktrees | `2d035362-92aa-4972-b5fe-999b16de919b` | 221 |
| SEARCH-044 | core | OrbStack exact panic lookup | `40f1c061-66eb-4755-83f0-9f1e0ef8e467` | 0 |
| SEARCH-045 | core | Git-spice versus GitHub native stacked PRs | `5254bd42-a18c-4a40-894c-d488058d6c33` | 0 |
| SEARCH-046 | extended | Free visual disk usage applications | `72cdb157-2700-46bb-9cb1-78799442d8f6` | 0 |
| SEARCH-047 | extended | Aven and similar agent workspaces | `8d2ebde6-1164-4cde-8a05-ce4e61f8f16c` | 276 |
| SEARCH-048 | extended | Git notes as durable metadata linkage | `8d2ebde6-1164-4cde-8a05-ce4e61f8f16c` | 276 |
| SEARCH-049 | core | Skill invocation frontmatter across agent harnesses | `a9728c51-76de-4624-9bad-5fcc19d6407d` | 25 |
| SEARCH-050 | core | Raycast clipboard and snippets API boundaries | `c85bc768-e15c-4640-b024-f3a18bcde5b5` | 0 |
| SEARCH-051 | extended | Programmatic Cursor usage costs | `f00da6b8-6703-43b7-a7df-63acc1a6e71d` | 153 |
| SEARCH-052 | extended | Six-month Orca release history | `f27a9e9f-e985-48ea-b251-a89f0d1818f1` | 0 |
| SEARCH-053 | control | Authenticated Google document routing control | `0154c1b4-e6c3-43ba-88ad-be6ecca46908` | 0 |
| SEARCH-054 | control | Prior-session artifact lookup control | `62f318d2-2070-4c22-b383-9209ea183863` | 0 |
| SEARCH-055 | control | Local crash diagnosis routing control | `cb38ec48-c407-4f2a-818f-807ab64ce68c` | 0 |
| SEARCH-056 | core | 8BitDo Zero 2 macOS/iOS community setup reports | `cursor:0be2a19d-dbd8-49f5-8359-eed810dad9ad` | 0 |
| SEARCH-057 | extended | Official firmware update procedure for Zero 2 | `cursor:0be2a19d-dbd8-49f5-8359-eed810dad9ad` | 13 |
| SEARCH-058 | extended | Community firmware existence check for Zero 2 | `cursor:0be2a19d-dbd8-49f5-8359-eed810dad9ad` | 15 |
| SEARCH-059 | extended | Terminal copy/paste line wrapping and OSC hypothesis | `cursor:1b322dbc-6b1e-4f0a-b11e-a4a4345dd58c` | 0 |
| SEARCH-060 | extended | Discover pi providers that can use Cursor Agent | `cursor:28136843-dffb-4730-8444-821669e17d0c` | 8 |
| SEARCH-061 | extended | Understand the entwurf repository | `cursor:28136843-dffb-4730-8444-821669e17d0c` | 30 |
| SEARCH-062 | extended | Quantified adoption and maintenance comparison for pi integrations | `cursor:28136843-dffb-4730-8444-821669e17d0c` | 34 |
| SEARCH-063 | extended | Cross-application long-text automation on macOS | `cursor:4750cc3e-8af9-46fe-9ad9-b6e284f6bce6` | 0 |
| SEARCH-064 | extended | Tuna versus Raycast x-callback-url support | `cursor:4750cc3e-8af9-46fe-9ad9-b6e284f6bce6` | 6 |
| SEARCH-065 | extended | Use Cursor as a pi or Claude Code subagent | `cursor:57339814-e156-4d3d-81d0-0006de33076f` | 0 |
| SEARCH-066 | extended | Verify Cursor CLI read-only restriction claim | `cursor:57339814-e156-4d3d-81d0-0006de33076f` | 11 |
| SEARCH-067 | extended | Chezmoi init and hook lifecycle | `cursor:7e0f0add-ac0f-46b7-a3a2-2c0385d6305c` | 547 |
| SEARCH-068 | extended | acpx execution and concurrency limits | `cursor:9360acb5-1d56-4ea0-8a8e-3aebb4bcc995` | 0 |
| SEARCH-069 | core | Locate upstream Go compiler escape-analysis tests | `cursor:3d68e42a-ee5b-407c-8494-ec0c53bfb9d7` | 14 |
| SEARCH-070 | extended | git-spice fork pull-request stack workflow | `cursor:3e9da840-1588-4f20-941c-85b8075b3f7a` | 143 |
| SEARCH-071 | extended | Extensible OSS command-palette foundations | `cursor:4382ce56-3e02-42db-a57d-8876eafe463b` | 0 |
| SEARCH-072 | extended | cmux worktree tracking in community practice | `cursor:4931b64a-d711-45b4-a7ac-e1fae264b2a5` | 5 |
| SEARCH-073 | extended | Discover worktree and coding-agent dashboard UIs | `cursor:58c422b2-6b76-4860-9160-873e8a9b0816` | 0 |
| SEARCH-074 | extended | macOS floating dashboard host comparison | `cursor:855bf887-f03e-4798-90a1-52f4420cdb13` | 0 |
| SEARCH-075 | extended | Private GitHub Pages access guarantees | `cursor:925ee200-df54-402c-a371-a4d628e95b54` | 57 |
| SEARCH-076 | extended | Discover investigation and postmortem agent skills | `cursor:dc59de18-c27e-4b9b-b90f-93b2171123f0` | 148 |
| SEARCH-077 | core | Production precedent for explicit Go garbage collection | `cursor:fa2dfc90-ac6c-4b95-b178-ed4cd1369db1` | 0 |
| SEARCH-078 | control | Private planning preparation needs authenticated sources | `cursor:09edaefc-4970-4e26-95c4-069f2abce33a` | 0 |
