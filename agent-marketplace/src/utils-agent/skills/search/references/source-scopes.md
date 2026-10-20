# Source scopes and exploration records

Read this with [options](options.md) when writing structured requests. These fields
describe host decisions; the engine neither infers a region nor translates queries.

## Scopes and operations

Known aliases remain valid. `site:hostname[/path-prefix]` adds a public source
without registering it. Hostnames normalize to lowercase IDNA and match the host
and its subdomains. Paths preserve case and match complete segments: `/forum`
includes `/forum/thread`, not `/forums`. Trailing slashes in scope references normalize away. Schemes,
ports, credentials, query/fragment syntax, IP addresses, local hostnames, dot
segments and ambiguous encodings are rejected. `site:` is a scope, not a URL to fetch.

Use explicit ASCII punycode for hostnames containing sharp s (`ß`/`ẞ`), final sigma
(`ς`), or zero-width joiners/non-joiners, including compatibility-normalized forms.
The stdlib IDNA codec can map these to different hosts; Unicode-form scopes are
rejected and Unicode-form results are dropped. For example, use
`site:xn--fa-hia.de` for `faß.de`; `site:fass.de` is a different scope.

The `amazon` alias scopes only `amazon.com` and its subdomains. Select regional
storefronts with explicit scopes such as `site:amazon.de`; exclude each relevant
storefront explicitly as well. An `amazon` exclusion alone does not exclude those
regional hosts. Platform-family identity groups Amazon offers while retaining
their market host; it does not broaden a source or exclusion scope.

Path scopes are literal and case-sensitive. Servers may treat differently cased
paths or semicolon parameters as aliases; the resolver cannot infer those rules.
For an exclusion that must cover such aliases, exclude the host or list the known
variants. Ambiguous encoded paths on an excluded host fail closed.

`twitter.com`/`x.com` and `youtu.be`/`youtube.com` share qualified scope aliases.
Do not infer that arbitrary mirrors or translated copies are the same resource.
The source and `filters.domains` intersect; an empty intersection fails before
execution. Every parsed destination is checked again, including `fields.final_url`
when a host observed a redirect. Inspection observations also retain an
engine-owned `inspection_requested_url`, allowing the read to support its original
candidate without changing that candidate ID or merging distinct offers. Report
the final URL rather than claiming a
redirect was checked from its initial URL alone.

Area selects evidence requirements; operation selects retrieval behavior. Reddit
can supply shopping research, GitHub social issue discussion, and a new site code
documentation. Actual routes must support both the operation and scope. Generic
discovery does not imply comments, transcripts, offers or authenticated access.
Use `capabilities` instead of assuming a site's native integration exists.
For `site:` shorthand, supply `--area` when the operation needs a non-web area,
for example `--area=shopping --operation=product.discover`. Structured facets
always name their area explicitly.

Global source/provider/method pins, exclusions and required sources remain in
force across extensions. Starting facets are seeds, not global pins. Source
exclusions also filter matching destinations found by general web discovery.
Required sources must have facets. Read their coverage rows for missing or
discovery-only evidence; a planned facet alone is not successful coverage.
The host answer assessment and the engine facet-completion flag are separate.

## Context, decisions and query language

Example request; host bindings are supplied separately:

```json
{
  "schema_version": 1,
  "intent": {
    "request": "Find Japanese reports of SQLite WAL behavior; answer in English",
    "breadth": "ordinary",
    "context": [
      {"name": "content_languages", "value": ["ja", "en"], "origin": "explicit"},
      {"name": "answer_language", "value": "en", "origin": "explicit"}
    ]
  },
  "facets": [{
    "id": "jp-reports", "area": "code", "source": "site:zenn.dev",
    "operation": "page.discover", "terms": "SQLite WAL ロック",
    "query_language": "ja", "needs": ["version", "content"]
  }],
  "source_decisions": [{
    "id": "technical-community", "family": "Japanese technical articles",
    "sources": ["site:zenn.dev"], "disposition": "selected",
    "reason": "Look for original implementation reports", "facet_ids": ["jp-reports"]
  }],
  "budget": {"calls": 3, "discovery": 1, "enrichment": 2, "opens": 2, "wall_seconds": 180}
}
```

Context has at most 24 uniquely named records. Origins: `explicit`, `conversation`,
`saved`, `assumption`; saved means a value supplied by the host, not an engine
context database. Values are public scalars or up to 16 scalars; strings max 512
characters, names max 64. Do not put credentials, private addresses or profiles here.
Breadth is `focused`, `ordinary` or `wide`; it never raises the budget.

`query_language` is a language tag (for example `ja`, `zh-Hant`), not a promise
about results. It travels unchanged in host work and reports. `filters.language`
still means programming language for code routes. Observed content language and
translation limitations belong in evidence assessments.

Decisions have unique IDs, family, source list, reason, disposition and facet IDs.
Disposition is `selected`, `not_relevant`, `excluded` or `deferred`. Selected rows
require linked facets whose effective scopes fit the listed sources; every link
must exist. Other dispositions have no facet links. `excluded` records a host
choice to omit a family; only `choices.exclude_source` enforces a global ban. There are at most 64 records, 16
sources and 32 facet links per record; IDs/family max 64 and reason max 512.
Records are append-only explanations, not instructions to enable a source.
When broad web discovery finds a narrower source, link the new scoped inspection
facet and explain its discovery in the reason; do not attach the whole broad-web
outcome count to that narrower source.

Append discovery or inspection jobs and fresh decisions with `extend`. A decision
can link existing or newly added facets; rejected extensions leave the run intact.
Use an empty `prepared_jobs` list to record a considered but deferred branch.
The original limits, reservations, authorization and deadline remain unchanged.
Reports join these decisions to per-facet execution/coverage. Semantic usefulness
still comes from candidate selection. Save an optional `stopping_reason` (max 512)
with selection, and add a concise coverage sentence only when it affects the answer.

## Compatibility and retention

New runs use identity policy 2: known platform destinations retain qualified
identities across alias/site discovery; unknown destinations use conservative URL
identity. Requested scope remains in provenance. Regional Amazon offers include
their market host; unknown federated instances remain distinct.

Pre-1.16 checkpoints without `identity_version` keep policy 1. Report, paging,
selection and pending settlement preserve their IDs and settle each attempt once.
They may extend with baseline-compatible jobs. New site/cross-area semantics need
a new explicit plan using only remaining authorized allowance; never reset limits
to bypass exhaustion. Old unexecuted plans whose resolution changed require
re-planning. Do not edit fingerprints or add identity versions to migrate by hand.

Existing private XDG traces retain these fields subject to normal redaction.
After restricted-retention evidence is encountered, persisted context and source
decision prose are omitted as a group because they may quote it. Reports expose
`exploration.retention_omitted`; selection and stopping prose follow the existing
selection omission policy. An omitted record cannot be reconstructed on resume. Removing request prose
changes the persisted plan fingerprint; the run/work/attempt IDs remain stable.
Compare run IDs across resume, not the pre-redaction plan fingerprint.
