# ANALYZE prompt — Runtime Quality pillar

You are writing the **Runtime Quality** section of an iOS app audit. Your
inputs are `.audit/raw/runtime.json` (logging, retry patterns, timeouts,
cache usage, network monitor, silent errors, persistence) plus the repo
itself for source-level verification.

Your outputs:

1. **Authored markdown** under `.audit/docs/operations/`.
2. **Findings JSON** at `.audit/findings/runtime.json`. IDs start with `RT-`.

## Doc outline to produce

### `operations/failure-modes.md`

Classification of how the app can fail and how it recovers. Build tables
grouped by category:

- Network failures (401, 4xx/5xx, DNS, timeout, offline, slow)
- Parsing failures (missing field, invalid enum, oversized response)
- Authentication failures (bad login, session expired, token refresh, keychain)
- Playback failures (stream URL invalid, codec unsupported, buffer underrun,
  quality switch fails) — only if the app plays media
- Progress/telemetry save failures
- Download failures
- UI race conditions (with cross-reference to quality/concurrency-audit.md)
- Silent failures inventory (every `try?` and empty catch, classified as
  acceptable / problematic)

Each row: Failure | Detection | Recovery | Gap?

Mark rows with `⚠️ Gap` where the recovery is missing, silent, or brittle.
Each gap becomes an RT-### finding.

### `operations/caching-strategy.md`

- What IS cached (from `cache_usage` sites): medium, hit rate estimate, TTL,
  size cap
- What is NOT cached but probably should be (gaps in catalog, detail, stream
  URL, favorite status, progress)
- Current implementation notes: URLSession configuration, Nuke image cache,
  in-memory response cache
- Proposed caching layer (if significant gaps exist): option A (URLSession)
  vs option B (custom manager), tradeoffs, recommended TTLs per endpoint

### `operations/resource-usage.md`

Synthesize from the raw data + your code reading:
- Network call patterns (fan-out on screen load, pagination loops, redundant
  fetches between views)
- Image loading patterns
- Memory hotspots (large arrays, caches without bounds)
- Background task / URLSession background modes
- Battery considerations (polling, timers, location, motion)

### `operations/runbooks/<topic>.md` (one per major failure mode)

Write a runbook for each gap worth debugging operationally. Each runbook:
- Title + symptom
- Diagnostic checklist (numbered, with curl/bash/Swift snippets)
- Known causes (with root cause + fix + test references)
- Common fixes (rebuild, clear cache, verify credentials, run E2E tests)
- Escalation checklist

Examples: playback failure, sign-in failure, download failure, offline
recovery, token expiry.

### `operations/observability.md`

- Logging inventory (os_log vs Logger vs print — prefer unified `Logger`)
- What is logged, at what level, with what subsystem/category
- What is NOT logged but should be (silent failure sites)
- MetricKit integration (if present)
- Crash reporting
- Analytics touchpoints (if any)

## Finding structure

IDs start with `RT-`. Severity rubric:

- **critical** — data loss (failed save not retried), crash-worthy race,
  runaway loops, always-on network drain, ship-blocking perf regression
- **major** — silent failure in a hot path, missing retry on transient
  failure, cache invalidation bug, battery drain, oversized image decode
- **moderate** — inconsistent error messages, noisy logs, un-bounded cache
- **minor** — logging level typos, missing docstrings on error enums

## Process

1. Read `.audit/raw/runtime.json`.
2. For every silent error site, open the file and decide: acceptable
   (fallback is obvious, caller tolerates nil) or problematic (data loss,
   UX surprise, silent drift).
3. For every retry site, verify the retry logic is correct (exponential
   backoff, max attempts, cancellation, idempotency).
4. For every cache use, ask: is there a TTL? invalidation? size cap?
5. Write the failure-modes table first, then runbooks, then cache + obs docs.
6. Cross-link every finding to the doc section where it's discussed.
