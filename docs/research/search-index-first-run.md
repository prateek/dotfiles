---
status: active
doc_type: research
created: 2026-09-27
updated: 2026-09-27
related:
  - search-index-eval.md
  - social-shopping-search-sources.md
status_detail: "First core retrieval and platform discovery run completed; blinded relevance and agent-task judgments remain pending."
summary: "Initial API retrieval measurements for core queries and platform discovery."
---

# Search-index evaluation: first retrieval run

The [evaluation protocol](search-index-eval.md) distinguishes retrieval from
completed agent tasks. This first run, on 2026-09-27, executed **270 searches**:
27 core cases × 10 ranked-result modes. It also executed 40 initial canary
searches, 72 platform-discovery searches (nine platforms × eight modes), nine
additional Brave platform searches retaining only derived counts, and focused
native GitHub, Hacker News, YouTube, and grep.app probes. The
[core query set](../../evals/search-index/core-queries.jsonl) and
[platform query set](../../evals/search-index/platform-queries.jsonl) are frozen
for this run. Keyword-style APIs received the same short `web_query` per case;
semantic APIs received the same `semantic_query`. Every provider was asked for
at most ten results. No query retries, result fetching, agent answering, or
automated relevance grades were part of these numbers.

Returned URLs, titles, and short excerpts for non-Brave APIs live in ignored
`build/search-index-eval/` scratch files, alongside timestamps, status, and
client-observed latency. Brave raw results were discarded; only result counts
and derived platform-domain counts were retained. The scratch files are not
the scored corpus and are not committed. No session transcript, session ID,
or private-context control was sent to a search provider.

| Ranked-result mode | Calls succeeded | Zero-result cases | Median returned | Median latency, ms |
| --- | ---: | ---: | ---: | ---: |
| SearXNG local web | 27/27 | 0 | 10 | 579 |
| Serper Google search | 27/27 | 2 | 10 | 1,037 |
| Brave Web Search | 27/27 | 1 | 10 | 758 |
| Exa Auto | 27/27 | 0 | 10 | 1,766 |
| Parallel Fast | 27/27 | 0 | 10 | 641 |
| Parallel Advanced | 27/27 | 0 | 10 | 3,179 |
| Tavily Basic | 27/27 | 0 | 10 | 2,084 |
| Tavily Advanced | 27/27 | 0 | 10 | 3,575 |
| Octen Search | 27/27 | 0 | 10 | 361 |
| Perplexity Search, medium context | 27/27 | 0 | 10 | 246 |

These latencies are wall-clock observations with providers called concurrently
per case; they are not controlled latency benchmarks. Ten returned results do
not imply ten relevant or unique sources. Call costs and remaining balances
were not captured. Brave LLM Context answered one separate Syncthing canary
with `grounding` and `sources`; its output is not a ranked-result list and is
excluded from the table. SearXNG's Bing engine reported an HTTP error in an
initial canary and was temporarily suspended, although the later core run had
no reported engine errors. Keep engine availability separate from relevance.

## Social and shopping URL discovery

For each of the nine requested platforms, a source-specific query measured
whether at least one top-ten URL landed on the expected domain (and, for
YouTube, Marketplace, and Amazon, the expected URL type). This measures
**candidate discovery only**. A listing may be stale, an X result may be old,
and a matching YouTube URL may belong to the wrong channel. The
[18 platform probes](../../evals/search-index/platform-probes.jsonl) remain
unscored until live-source oracles and access gates are resolved.

| Mode | Platform queries with an expected-source URL in top ten | Missed source in this run |
| --- | ---: | --- |
| Brave Web Search | 9/9 | None; derived metric only, no raw result retention. |
| Octen | 9/9 | None. |
| Serper | 8/9 | Amazon product page; its `site:amazon.com/dp` query returned no results. |
| SearXNG general web | 8/9 | YouTube watch URL. |
| Perplexity | 8/9 | Marketplace listing URL. |
| Parallel Fast | 7/9 | Reddit and X. |
| Exa Auto | 6/9 | Reddit, X, and Marketplace. |
| Tavily Basic | 6/9 | X, Marketplace, and Amazon product page. |

The domain counts are not a quality ranking. In particular, Serper's Amazon
miss shows that query syntax can cause a zero-result outcome; it does not prove
that the provider lacks Amazon pages. No provider was tested for native Reddit
OAuth, X API posts/replies, current Facebook Marketplace availability, Amazon
offers, or address-specific Uber Eats and Instacart inventory. The
[source-access matrix](social-shopping-search-sources.md) records those gates.

## Checked examples and routing lessons

- `SEARCH-030` asks for GithubAwesome videos **as of 2026-09-14**. The short
  keyword query returned zero Serper results, one Brave result, and one Octen
  result. SearXNG's dedicated YouTube engine returned nine video URLs for a
  related query, but its first results included September 18 and 25 videos,
  outside that case's time boundary. Neither count establishes the requested
  four weekly and two weeks of daily videos.
- `SEARCH-031` illustrates a false positive: several providers surfaced
  [“Granola, But Open Source and Local (Meetily)”](https://www.youtube.com/watch?v=LCoF8dCVkIw).
  YouTube's oEmbed metadata identifies **Better Stack** as its channel, while
  the case requires GithubAwesome. A plausible title is insufficient evidence.
- `SEARCH-069` requires upstream Go escape-analysis **tests**. Exa returned
  upstream `test/escape*.go` source files near the top, and grep.app's literal
  `// ERROR` search restricted to `golang/go` and `test/escape` found
  [test/escape2n.go](https://github.com/golang/go/blob/master/test/escape2n.go).
  That file starts with `// errorcheck -0 -N -m -l` and has `// ERROR` compiler
  diagnostic assertions. A broad `gh search code "escape analysis"` query
  returned general Go source files instead. Query translation and code-specific
  filters matter.
- `SEARCH-077` asks for production `runtime.GC()` calls. Native `gh search
  code` returned [mox's heap-profile path](https://github.com/mjl-/mox/blob/be2b665318823a932fcdc824b919c031d8215bab/profile.go),
  [gopher-lua's collection binding](https://github.com/yuin/gopher-lua/blob/75f497656b1c6864139dd2a7d88cf96d09550814/baselib.go),
  and [RudderStack's heap-profile path](https://github.com/rudderlabs/rudder-server/blob/0806478532f0f2fa38ad05a2c12957676e7ae35b/app/app.go)
  in its first three results. Their call sites were checked at those revisions.
  A broad grep.app literal query began with Go's own test files; it needs path
  or repository filtering for this intent.
- Native `gh search repos` found three Setapp CLI candidates and ten worktree
  manager candidates for `SEARCH-019` and `SEARCH-042`, but a broad pi-agent
  roleplay query returned zero and the BetterDisplay comment query returned
  zero issues. GitHub's CLI code search states that it uses the legacy API and
  lacks website regex search; evaluate repository, issue/comment, and code
  surfaces separately.

SearXNG's dedicated Hacker News and YouTube engines returned 30 and 19 results
for broad source canaries. The public HN Algolia endpoint had already passed a
search preflight. These are useful source routes, but the exact core YouTube
cases still need source verification and sometimes channel/date filtering.

No nDCG, first-useful-rank, completed-task success rate, or overall provider
winner is claimed here. Next, pool and deduplicate candidate URLs, blind the
provider names, verify source evidence for each case's criteria, and judge
relevance. Then run completed-agent trials with one fixed model, fetch tool,
and search-call budget. Keep access-gated shopping and social outcomes in their
own lane.
