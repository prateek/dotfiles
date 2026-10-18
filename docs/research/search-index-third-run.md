---
status: active
doc_type: research
created: 2026-09-27
updated: 2026-09-27
related:
  - search-index-eval.md
  - search-index-first-run.md
  - search-index-second-run.md
  - social-shopping-search-sources.md
status_detail: "Kagi Search API retrieval measured on the frozen core and platform queries; source relevance and live listing checks remain pending."
summary: "Kagi API retrieval measurements and source validation limits."
---

# Search-index evaluation: Kagi Search API

Kagi Search API v1 completed the same [27 core queries](../../evals/search-index/core-queries.jsonl)
and [nine platform queries](../../evals/search-index/platform-queries.jsonl) used in the
[earlier retrieval runs](search-index-first-run.md). The normalized results,
timestamps, and client-observed latencies are in ignored
`build/search-index-eval/kagi-{core,platform}.jsonl`. Only the public
`web_query` values went to Kagi; session provenance and private prompts stayed
local. The test used a Search-only API key stored as **Kagi Search API - search
eval** in Devland 1Password.

| Measure | Kagi Search API v1 |
| --- | ---: |
| Core calls succeeded | 27/27 |
| Core cases with results | 26/27 |
| Median returned core results, capped at ten | 10 |
| Median client-observed core latency | 1,255 ms |
| Platform queries with an expected-domain URL | 9/9 |

The platform queries returned Reddit discussions, Hacker News threads, X
posts, Facebook Marketplace item URLs, Amazon product URLs, Alibaba product
pages, Uber Eats store pages, and Instacart product pages. This measures URL
discovery, not whether a listing is current, local, orderable, or readable.
The YouTube query returned five URLs in `youtube.com/watch/<id>` form; all
five failed YouTube's oEmbed lookup with HTTP 404. Count these as
expected-domain hits only, not usable video links. The Amazon and YouTube
queries each returned five results rather than ten.

Across the 27 core cases, Kagi's top-ten URLs had a median overlap of four
with Serper Google and four with SearchAPI.io Google after stripping `www.`,
query strings, fragments, and trailing slashes. The median overlap with
SearXNG general web was three. This suggests Kagi adds different candidates,
but overlap is not a relevance judgment. For `SEARCH-001`, it found the
official Obsidian CLI page and the relevant agent-skill repository. For
`SEARCH-056`, it found Reddit discussions about the requested controller on
Mac and iOS. `SEARCH-030` returned no results, and `SEARCH-077` placed .NET
garbage-collection results ahead of the requested production Go call sites.
Code-specific retrieval still needs native GitHub search and grep.app.

Kagi's usage page recorded 37 Search requests, including one canary, for
**$0.444** at the [published $0.012 per-search rate](https://kagi.com/api/pricing).
Billing was added using a Privacy Digital Goods category card in Devland.
Its 1Password note says $30 lifetime, and Prateek confirmed that limit in
Privacy; this run did not independently verify it in the Privacy dashboard.
Kagi's own **$5 usage limit** was saved and remained set after a fresh page
load. The local runner also capped each batch at 30 requests. The initial
default Kagi API key was revoked after its plaintext was exposed during page
inspection; the replacement key is restricted to Search, not Extraction.

These counts do not establish Kagi as the best provider. A blinded,
source-checked relevance pass and completed-agent trials are still needed,
especially for code search, YouTube URLs, and live social or shopping claims.
