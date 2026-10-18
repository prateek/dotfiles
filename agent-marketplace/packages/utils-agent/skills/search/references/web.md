# Web evidence

Choose the primary evidence family first: official documentation/changelogs for
product behavior, original papers and research repositories for research claims,
regulators/courts/public records for jurisdiction-specific facts, and original
reporting for events. Secondary explainers help discover terms and opposing claims.
Directories, maps and local-language institutions may be better discovery routes
for local questions than an English general query. Inspect the original rather
than treating a syndicated or translated copy as independent confirmation.
Use [multilingual discovery](multilingual.md) when the question crosses languages;
regional search engines are optional providers, subject to actual capabilities.

Separate exact keyword discovery from semantic discovery. Start with entities,
versions, error strings and primary domains; do not send provider query syntax to
every adapter. Use structured filters, or a native query with its declared dialect.
Adapters translate once. A date filter requests retrieval behavior; inspect dates
before claiming a result falls within the window.

Startpage and DDG browser routes require loaded result markup; parser support
does not establish current access. Google redirect-only results,
Bing's generic off-topic pages, and HTTP 200 challenge pages are not successful
retrieval. A clean empty state differs from an unrecognized page.

Serper's keyword route, Exa's semantic route and Brave's independent index are
provisional roles, not a relevance ranking. Read live capabilities for configured
alternatives. Preserve provider/upstream provenance when comparing results.

Inspect the destination, publication/update date, primary-source status and the
passage supporting the claim. Resolve redirect destinations before grouping pages.
Keep identity-bearing URL parameters. When a specific URL already exists, use
fetch/browser inspection rather than broad search unless corroboration is needed.

Brave's current adapter has `derived-only` retention: response candidates can be
used during the call, while state stores counts/status instead of result content.
Do not archive its raw response or include it in pooled retrieval/model benchmarks
without establishing applicable permission. The CLI cannot control a caller's
stdout capture or host transcript retention.
