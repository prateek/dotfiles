---
status: active
doc_type: research
created: 2026-10-17
updated: 2026-10-17
related:
  - search-index-eval.md
  - search-index-first-run.md
  - search-index-fourth-run.md
  - degoog-metasearch-reliability.md
status_detail: "Anonymous Camofox website retrieval measured on the frozen queries; source relevance and completed agent tasks remain unscored."
summary: "Browser-based search retrieval measurements and website access failures."
---

# Search-index evaluation: provider websites in Camoufox

On 17 October 2026, the [browser skill's Camofox REST recipe](../../agent-marketplace/packages/utils-agent/skills/browser/references/drivers/camofox.md) opened search-result **websites** in an isolated, task-owned Camoufox 152.0.4-beta.30 browser. The local REST controller operated the browser; no search-provider API key was used for these calls. A website may call its own backend APIs. The task browser and its temporary state were removed after the run.

The rebased checkout contained the new recipe, but this host did not yet expose its `mise run browser:camofox:install` task. The recipe's supported direct installer provisioned and verified the pinned runtime cache. This run did not apply the dotfiles or activate the new task on the host.

The full website lane sent the exact `web_query` from the same [27 core](../../evals/search-index/core-queries.jsonl) and [nine platform](../../evals/search-index/platform-queries.jsonl) cases used in the API runs. Each observation read the first page and at most ten displayed result titles and links, without agent query rewriting, page fetching, or relevance grades. Raw rows are in ignored `build/search-index-eval/website-{public-serps,yahoo}.jsonl`. Client latency includes browser navigation, an accessibility snapshot, and a DOM read. It is not comparable to the earlier API latency column. The API runs were weeks earlier, so overlap cannot isolate browser transport from index or ranking changes.

| Website | Core cases with a result | Platform URL shape | Median core results | Median browser time |
| --- | ---: | ---: | ---: | ---: |
| Google Search | 26/27 | Unscorable; opaque `/goto` links | 9 | 919 ms |
| Bing Search | 27/27 | 0/9 | 10 | 768 ms |
| DuckDuckGo | 25/27 | 8/9 | 10 | 1,765 ms |
| Startpage | 24/27 | 9/9 | 10 | 1,081 ms |
| Yahoo Search | 25/27 | 8/9 | 7 | 1,066 ms |

“Platform URL shape” requires a Reddit comment thread, HN `item?id=`, YouTube `watch?v=`, X `/status/`, Marketplace `/marketplace/item/`, Amazon `/dp/`, Alibaba `/product-detail/`, Uber Eats `/store/`, or Instacart `/products/` URL in the displayed top ten. This is a **source and path check**, not a relevance judgment. Yahoo and DuckDuckGo returned `youtube.com/watch/<id>` links on the YouTube probe; those do not have a canonical `v=` ID and were excluded. Google's browser page exposed opaque `google.com/goto` links for its result tiles. Its displayed citations named the requested source domain in only one of nine platform probes; a displayed domain cannot establish the destination path.

The strict `SEARCH-028` BetterDisplay issue query returned an explicit no-results message on Google, DuckDuckGo, Startpage, and Yahoo. Bing returned ten links, none to the requested GitHub issue path. The `SEARCH-030` GithubAwesome YouTube query returned no results on DuckDuckGo, Startpage, and Yahoo. These are useful failures of the exact frozen wording. A browser rendering a page did not make an upstream honor `site:`.

Several platform hits illustrate why the shape count is only a preflight. Startpage's first Amazon `/dp/` hit was an unrelated portable monitor; Yahoo's was a book. The X result common to DuckDuckGo, Startpage, and Yahoo was an old post, although the underlying task asks for recent posts. None of these hits verifies a current offer, video content, location, or a dated discussion. For comparison with the earlier wrappers, median canonical top-ten URL overlap on core cases was one for Bing website versus OpenSERP Bing, five for DuckDuckGo website versus OpenSERP DuckDuckGo, and five for Startpage website versus Degoog Startpage. These comparisons span different dates and clients.

Brave's website returned ten results for each of the first four core queries, then a fresh browser tab received HTTP 429 on the fifth. Searches stopped at that point. The ignored `website-brave.jsonl` retains counts and the 429, not raw Brave result text or URLs. The authenticated Brave Search API completed its earlier run; the website 429 is a separate access result, not evidence that the API failed.

## Provider and source-site access

Kagi, Exa, Parallel, and Tavily redirected this isolated browser to sign-in. Perplexity began an answer session, then asked the visitor to sign in and repeat the request before returning an answer. Octen's public landing page did not expose a comparable ranked-search interface in this probe. The evaluated general-web modes of Serper and SearchAPI.io package Google results; the Google website lane tests the underlying consumer search surface, not either provider's scraping service or vertical API. No accounts or personal browser profiles were imported because this Camofox recipe does not support credential entry or login retention.

The native GitHub website probe reused eight queries tailored to `gh search`: five repository searches displayed results, the issue search displayed three unrelated issue URLs, and both code-search cases required sign-in. Its ignored rows are `build/search-index-eval/github-website.jsonl`. The prior authenticated `gh search code` result therefore remains a distinct, usable source-code route.

One native website query per requested social or shopping source is recorded in ignored `website-source-probes.jsonl`. Reddit search, HN Algolia's website, YouTube, Facebook Marketplace, Amazon, Alibaba, and Instacart displayed candidate links. X redirected to login. Uber Eats served an automated security-check page despite HTTP 200. Marketplace defaulted to New York within 40 miles, not the task's ZIP 10016 and 25-mile radius; the shopping pages had no common verified delivery address or account. Google Shopping rendered priced product cards, but this probe did not extract canonical merchant offers. These source-site checks show what an anonymous browser can reach, not the full [platform task criteria](../../evals/search-index/platform-probes.jsonl).

The first multi-site browser session expired during an exploratory pass; its stale tab IDs were discarded. The complete five-site rows above came from fresh isolated sessions. This run establishes retrieval and access only. Selecting a provider still needs blinded, source-checked judgments and completed-agent trials under the [evaluation protocol](search-index-eval.md#how-to-use-the-corpus).
