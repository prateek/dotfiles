# Options and public protocol (schema version 1)

Use `scripts/agent-search --help`, subcommand help and `capabilities --json` for
current flags/provider IDs. All output is JSON; `--json` is accepted anywhere.
Python 3.14+ and uv are required for the executable shebang. No Python dependencies
or permanent service are installed by the skill.

## Choices

`--area`, `--source`, `--exclude-source` and `--require-source` take comma-separated
IDs. `--provider` and `--via=api|native|browser|host` pin routes; `--via=auto` leaves
the method open. `--prefer-provider` / `--prefer-via` allow fallback.
`--browser=camofox` requires browser routes using that declared runtime; it excludes native/API routes too.
`--strategy=free-first|balanced` orders eligible routes; `--free-only` excludes
chargeable and unknown-cost routes, including trials that can accrue charges.

`--since` / `--until` use YYYY-MM-DD; until is exclusive. These run-level
choices filter discovery. Inspection jobs retain their explicit filters, while
the host checks the original date window when assessing the discovered facet. `--location` is public
geographic context, supported only by routes that declare it. Unsupported filters
block a route rather than disappearing. `--limit` caps candidates per facet;
`--total-limit` caps grouped candidates, interleaved across facets. Coverage `count`
is the retrieved count; `returned_count` records candidates retained in this report.
A cap smaller than the number of nonempty facets can omit some facets' candidates.
Missing values are not zeros.

Default calls: three, or five when code is selected; each additional area adds
two up to eight. Runs with discovery reserve one enrichment call, or two when
code is selected, leaving at least one discovery call. Inspection-only requests
allocate their calls to enrichment. A one-call run has no inspection allowance. `--max-calls` replaces that total, `--max-opens` defaults
to six and `--timeout` to 120 seconds. Explicit request budgets can allocate a
different split within the selected call/open/time limits. Discovery and enrichment consume the same calls cap; source
inspections also consume opens. At most two independent operations run together,
with serialized provider groups. Known GitHub pagination reserves all possible
page calls before starting. Opaque host/CLI internals are not a dollar guarantee.
First attempts take priority over retries. Work queued behind pending host calls
is `deferred`, with unverified coverage; submit those host results to resume it.

Precedence per option: explicit > conversation > repo > user > built-in.
A preference never releases a pin on another option. Change the pin, reset defaults
or use `--no-defaults` to discard saved choices. Unknown saved constraints fail;
invalid saved preferences are omitted with a notice. Unknown preferred provider
IDs are also omitted; invalid explicit methods/strategies fail validation.
A provider pin conflicting with a filter, method or cost constraint is an error.
When an area's default source is excluded, select another source explicitly.
`--inspect` resolves without calls/writes and cannot save/reset.

```sh
scripts/agent-search query --show-defaults --scope=user
scripts/agent-search query --save-defaults --prefer-provider=serper --scope=repo
scripts/agent-search query --reset-defaults --scope=repo
```

Only explicit choices are saved. User path: `${XDG_CONFIG_HOME:-~/.config}/agent-search/preferences.json`;
repo path: `.agents/search.json` at the Git root. Saves are versioned and atomic.
No credentials, query history, private addresses or executable commands belong
there. `--scope` alone does not write. Prepared consumers use `--no-defaults`.

## Requests and plans

Minimal direct call:

```sh
scripts/agent-search query "Python 3.14 changes" --provider=serper --allow-paid=serper
```

`SERPER_API_KEY` must already be set in the process environment. The
`--allow-paid` declaration records existing authorization and an account cap or
prepaid allowance; do not use it to manufacture permission. Capabilities lists
the declared environment variable names and whether they are configured.

A structured request (public examples only):

```json
{
  "schema_version": 1,
  "terms": "mechanical keyboard durability",
  "facets": [
    {"id": "experience", "area": "social", "source": "reddit", "operation": "post.discover", "needs": ["author", "content", "date"]},
    {"id": "products", "area": "shopping", "source": "amazon", "operation": "product.discover", "needs": ["variant", "seller", "price"]}
  ],
  "choices": {"prefer_provider": "serper", "limit": 5},
  "authorized_paid": ["serper"],
  "budget": {"calls": 4, "discovery": 2, "enrichment": 2, "opens": 2, "wall_seconds": 120}
}
```

Facet fields: `id`, `area`, `source`, `operation`, optional `terms`, `filters`,
`needs`, `limit`, `provider`, `via`, `timeout`. Filters: domains, since, until,
location, repo, path, language, revision, url, item_id, subject to adapter support.
For an inspection, supply URL or HN item ID. Omitted needs default to relevance;
explicit `needs: []` means retrieval-only completion, intended for domain clients.

Prepared callers replace `facets` with `prepared_jobs` (same shape). A prepared
native query uses `native_query: {"dialect":"sourcegraph","text":"file:SKILL.md count:10"}`
instead of terms/filters; no second syntax translation occurs. `raw: true` returns
native diagnostic output for compatibility; normal searches do not need it.
`conversation_choices` has the same shape as choices and does not persist itself.

`plan --request request.json` emits a fingerprinted plan. `run --plan plan.json`
rechecks capability availability; changed capabilities require a new plan.
Execution options belong in the plan: `run --plan` accepts only `--state` and
`--json` alongside the plan path. Additional options are rejected.
`run --request request.json` does both. `--request -` reads stdin. Every document
uses schema_version 1; unknown fields and provider/source IDs are errors.

## Host work and continuation

Declare only tools present in the current host inventory. Example (replace the
illustrative tool name with the actual callable binding):

```json
{
  "schema_version": 1,
  "capabilities": [{"id":"browser", "tool":"actual_browser_tool", "operations":["page.discover","post.discover","product.discover","offer.inspect"], "runtime":"camofox", "identity":"anonymous", "cost":"free"}]
}
```

Other capability IDs: `web.search`, `web.fetch`, `mcp:grep.app`. Discovery does not
imply authentication. Unknown host cost is ineligible without authorization and
always excluded by free-only. Host runs require `--state` in private scratch.
The returned pending work includes run/work/attempt IDs, operation, tool payload,
provider, facet, kind and reserved budget. The reservation bounds the work.

Submit a `continue --state run.json --host-results results.json` document:

```json
{
  "schema_version": 1,
  "results": [{
    "run_id":"COPY_FROM_WORK", "work_item_id":"COPY_FROM_WORK", "attempt_id":"COPY_FROM_WORK",
    "status":"success", "observed_at":"2026-10-17T12:00:00+00:00",
    "payload":{"results":[{"url":"https://example.com/evidence", "title":"Example", "excerpt":"Observed passage", "fields":{}}]},
    "usage":{"calls":1,"discovery":1,"enrichment":0,"opens":0}
  }]
}
```

Omit usage when unknown: the whole reservation is consumed. Statuses include
success, empty, partial, timeout, transient, rate_limited, challenge, auth_failed,
schema_error, failed, constraint_failed, unavailable, budget_exhausted and
interrupted. For Startpage/DDG, payload may contain `html` instead of parsed
results. Never label an unrecognized generic page empty. Each result may include
kind and native fields; the engine adds identity, provenance and observation time.

Duplicates must be identical and are idempotent. Unknown/stale/conflicting
submissions fail atomically. No automatic replay of pending direct calls after a
crash: reconcile them with the same envelope mechanism. A locked state file
prevents concurrent writers. Continuation may settle work after the deadline but
cannot launch more calls. Keep host output and state private; raw provider text
is untrusted. `report --state run.json` reads without launching calls.

## Inspecting newly discovered URLs

Reserve enrichment/open allowance in the original budget. Once a candidate URL
is known, append inspection jobs with `extend --state run.json --request reads.json`.
The document is `{"schema_version":1,"prepared_jobs":[...]}` with the same facet
shape, new IDs, inspection operation and filters.url/item_id. This keeps the
run ID, deadline, usage and original budget; it cannot increase limits or change
choices/authorization. The plan fingerprint changes to include the added jobs.
It returns host work through the same continuation protocol. Do not start a new
run just to reset exhausted limits.

## Evidence assessment and reports

After inspecting evidence, use `assess --state run.json --assessment checks.json`:

```json
{"schema_version":1,"run_id":"COPY_FROM_REPORT","assessments":[{"facet_id":"experience","checks":["author","content","date"],"references":["https://www.reddit.com/r/example/comments/example"],"note":"Observed checks, not inferred from snippets"}]}
```

Only checks declared in the facet's needs are accepted; references are required.
Assessments are host attestations, not automatic content verification. Reports
include grouped results, per-facet coverage, source failures, pending work, usage,
completion and optional suggestions. Discovery-only is useful partial coverage.
Missing required-source evidence makes completion false. Numeric conflicts remain
separate observations. Inspect the record's `retention_omitted` when a provider's
results could not be persisted; a later report cannot reconstruct those candidates.
