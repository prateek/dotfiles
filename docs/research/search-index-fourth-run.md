---
status: active
doc_type: research
created: 2026-10-13
updated: 2026-10-13
related:
  - search-index-eval.md
  - search-index-first-run.md
  - search-index-second-run.md
status_detail: "Degoog native API and three engine configurations tested; relevance and agent-task judgments remain pending."
summary: "Degoog engine configurations evaluated on frozen search queries."
---

# Search-index evaluation: Degoog local trial

On 2026-10-13, [Degoog](https://github.com/degoog-org/degoog) 1.1.0 at
`5cd67cec74d38944792db498b604790624a1cbbe` was built with Bun and run
at `127.0.0.1:18889`, with a disposable data directory under ignored
`build/search-index-eval/`. Docker was unavailable on this host at trial time.
Degoog is a self-hosted metasearch aggregator, not a new web index or a managed
search API. Its [JSON `/api/search` route](https://degoog-org.github.io/docs/api.html)
returns results, source labels, and per-engine status/timings; an optional
setting serves a SearXNG-shaped response. The [fresh install has no search
engines](https://degoog-org.github.io/docs/getting-started.html), so this trial
installed the official Bing, DuckDuckGo, Reddit, Hacker News, DuckDuckGo Videos,
and Startpage extensions. No paid key, private session text, or session ID was
sent to an upstream engine.

The same [27 core queries](../../evals/search-index/core-queries.jsonl) and
[nine platform queries](../../evals/search-index/platform-queries.jsonl) used
in the earlier runs were sent to Degoog's API. Raw result rows are in ignored
`build/search-index-eval/degoog-*.jsonl`. This is retrieval and URL discovery,
not blinded relevance or completed agent tasks. Earlier providers ran on
2026-09-27, so latency and changing web results are not controlled comparisons.

| Degoog engine selection | Nonempty core cases | Expected source URL in top ten platform results | Observed failure |
| --- | ---: | ---: | --- |
| Bing + DuckDuckGo + Reddit | 27/27 | 0/9 | Bing supplied every late result, but site-scoped queries often returned generic pages. DuckDuckGo returned results in 5/27 core cases and 0/9 platform cases; Reddit RSS returned HTTP 429 in 26/27 core and 9/9 platform calls. |
| Startpage only | 23/27 | 8/9 | Empty for `SEARCH-019`, `SEARCH-028`, `SEARCH-030`, and `SEARCH-044`; no Amazon product-page URL in the platform probe. |
| Startpage + Bing | 27/27 | 8/9 | Bing filled Startpage's gaps in result count, but those links require relevance review; the Amazon product-page probe still missed. |

The first configuration had a 162 ms median client-observed latency, and
Startpage-only had a 350 ms median, but both mixed upstream response and cache
effects. The combined run reused cached results and its latency should not be
compared with other providers. A nonempty HTTP 200 response also does not mean
that a query was answered: for `SEARCH-030`, Bing's first results were
dictionary pages about “weekly,” and for `SEARCH-069` they were generic
definitions of “escape.” Conversely, Startpage found plausible Obsidian skill,
worktree-manager, and 8BitDo Reddit URLs. The median canonical URL overlap
between Startpage's top ten and the older SearXNG top ten was zero; different
URLs are not automatically better URLs.

The dedicated Hacker News engine returned 28 merged news-tab results for a
separate “search API AI agents” canary, including HN item URLs; DuckDuckGo
Videos returned 59 video-tab results for a separate SearXNG setup query,
including YouTube watch URLs. Those are useful discovery routes, but they were
not run across the frozen core or platform sets and do not establish native
YouTube metadata, Reddit comments, Marketplace inventory, or current shopping
offers. The official extension catalog has no GitHub code-search engine;
its GitHub plugin displays a card for GitHub URLs already found in web results.
Keep native GitHub search and grep.app for repository and code tasks.

This trial supports keeping Degoog as an **optional local metasearch
configuration**, especially with Startpage, but it does not justify replacing
the earlier SearXNG baseline: SearXNG found a source URL in 8/9 platform probes
and returned nonempty results in 27/27 core cases with its Bing/Yahoo setup.
Degoog's clean JSON API, engine-status diagnostics, and extension routing are
attractive for agents. Its weak first-engine configuration and dependence on
upstream scraping make source selection and periodic canaries necessary. If
used outside a disposable localhost trial, secure settings before exposing it:
extensions can execute server-side code, as the [setup guide](https://degoog-org.github.io/docs/getting-started.html)
explains.

The [reliability follow-up](degoog-metasearch-reliability.md) traces these
failures to upstream behavior and tests a few query and transport changes.
