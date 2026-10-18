---
status: active
doc_type: research
created: 2026-09-27
updated: 2026-09-27
related:
  - search-index-eval.md
  - search-index-first-run.md
  - social-shopping-search-sources.md
status_detail: "OpenSERP OSS and SearchAPI.io retrieval measured; other hosted candidates have account, billing, or verification gates. Relevance judgments remain pending."
summary: "OpenSERP and SearchAPI retrieval measurements and platform access limits."
---

# Search-index evaluation: added provider run

This run extends the [first retrieval run](search-index-first-run.md) with
OpenSERP OSS and SearchAPI.io. It uses the same [27 frozen core queries](../../evals/search-index/core-queries.jsonl)
and [nine platform discovery queries](../../evals/search-index/platform-queries.jsonl).
Results, timestamps, and client-observed latencies are in ignored
`build/search-index-eval/openserp/oss-{core,platform}.jsonl` and
`build/search-index-eval/searchapi-{core,platform}.jsonl`. New account keys
are held in Devland 1Password; the untracked local provider inventory records
item IDs without key values. No private session transcript or session ID was
sent to a provider.

| Ranked-result mode | Core calls succeeded | Nonempty core cases | Median results, successful calls | Median latency, ms |
| --- | ---: | ---: | ---: | ---: |
| OpenSERP OSS Bing | 27/27 | 27 | 9 | 1,226 |
| OpenSERP OSS DuckDuckGo | 25/27 | 25 | 10 | 1,810 |
| OpenSERP OSS Google | 22/27 | 20 | 9 | 2,121 |
| SearchAPI.io Google | 27/27 | 25 | 9 | 1,923 |

OpenSERP OSS used the current source build at commit
`98e48e6a8300fe2b5753d7de5f855afe951583f8` and a local Chrome browser
binary. Its Google mode produced 171 organic URLs, all as opaque Google
`/goto` redirects; it also hit four CAPTCHAs and one timeout. Those Google
results cannot yet be scored as canonical-source retrieval. DuckDuckGo had
two timeouts. Bing's core success did not carry over to platform targeting:
several `site:` queries returned unrelated sites, including dictionary pages
for the Alibaba query and Russian social-video pages for Marketplace.

The nine platform queries returned an expected-source URL for **9/9** with
OpenSERP DuckDuckGo and **8/9** with SearchAPI.io Google. SearchAPI.io missed
the Amazon product-page query, returning zero general Google results; its
dedicated Amazon engine did return product listings for a separate exact
product probe. OpenSERP Bing reached the expected source in only a subset of
these queries, and the Google redirect URLs prevent a comparable domain count.
These are URL-discovery observations, not proof that a social post is recent,
a product offer is current, or an address-specific item is orderable.

SearchAPI.io's general Google results had a median of six canonical URL
overlaps with Serper's Google results in the same core case and a median of
one URL absent from Serper's top ten. This indicates substantial overlap on
this frozen workload, not equivalent relevance. Against SearXNG general web,
the median SearchAPI.io overlap was one URL. OpenSERP DuckDuckGo and Bing each
overlapped SearXNG by a median of five URLs. URL normalization here strips
`www.`, query strings, fragments, and trailing slashes; it does not judge
content quality.

SearchAPI.io's native vertical probes, recorded in
`build/search-index-eval/searchapi-vertical.jsonl`, returned eight repository
results for an open-source meeting-transcription query, ten upstream Go issues
for an escape-analysis query, and ten YouTube video results for SearXNG setup.
Its Amazon search returned ten products, including
ASIN and listed price fields. A separate Google Shopping query returned 20
shopping items with prices. An Amazon product-detail request timed out once,
then succeeded on retry: the response included a $89.99 buy box, Amazon.com as
seller, stock status, and US delivery text for the searched ASIN. This is
provider-reported source data, not an independently verified offer for ZIP
10016. A narrow GitHub issue query returned a
provider-level "no results" response inside HTTP 200, so a successful HTTP
status alone must not count as a relevant hit. The documented GitHub vertical
supports repositories, issues, discussions and several other result types,
but not source-code search; native GitHub search and grep.app remain the code
routes. The Amazon and YouTube probe outputs have not been checked against
live product detail or video playback/transcripts.

Spot checks show why URL counts cannot stand in for relevance. For
`SEARCH-056`, SearchAPI.io returned Reddit threads explicitly about the
8BitDo Zero 2 on both MacBook and iOS; the threads still need to be read for
working setup claims. For `SEARCH-031`, OpenSERP DuckDuckGo returned a plausible
open-source Granola alternative and a Meetily video, but neither result alone
proves that the specified GithubAwesome channel featured it. For
`SEARCH-069` and `SEARCH-077`, SearchAPI.io's general Google mode returned
mostly unrelated discussions and non-Go code, missing the upstream escape
assertion files and production `runtime.GC()` call sites identified in the
first run. These cases still favor code-specific retrieval and source checks.

| Other candidate | State at this run | Evaluation gate |
| --- | --- | --- |
| Kagi Search API | Agent-email account created; password in Devland. | Billing and retrieval were completed in the [Kagi follow-up run](search-index-third-run.md). |
| OpenSERP Cloud (`openserp.org`) | Registration produced an activation email and a Devland login. | The activation URL was invalid or expired when opened. The resend form produced no new email, and login did not advance. OSS results above are a separate local engine run, not Cloud API results. |
| OpenSerp.dev | Agent-email account and API key created. | Balance is $0. The $5 starter credit is sold out, the current $25 checkout offers cryptocurrency only, and a direct API probe received Cloudflare error 1010 (HTTP 403). No paid retrieval occurred. |
| SerpApi | Agent-email account confirmed; Devland login created. | The owner's stored phone number was entered, but the Send Code action opened an image reCAPTCHA in an iframe. No SMS or API key was issued. |
| SearchAPI.io | Agent-email account confirmed; key stored in Devland. | General and selected vertical retrieval completed using free credits; no paid plan. |

AgentCard was also set up as a possible source of one-use cards for provider
accounts. The agent-email login, saved Devland funding card, agent inbox, Base
wallet, and owner identity are verified. The issued-card source reports ready,
but two $1 issuance probes returned HTTP 402 and are listed as declined; no
card was issued or charged. Its separate x402 wallet delegation also failed
with a contract-signature mismatch. The passwordless login instructions and
current expiring session token are in Devland 1Password. AgentLine, considered
for SerpApi SMS, has an API key but a zero balance and a checkout marked Test
Mode; it has no live phone number.

These counts are not a provider ranking. A blinded, source-checked relevance
pass and completed-agent trials are still required to choose a default search
configuration. The [source-access matrix](social-shopping-search-sources.md)
also remains the boundary for Reddit comments, X replies, Marketplace listing
availability, and address-specific shopping or delivery claims.
