# Applies to: TCA 1.25+, iOS 16+

# SQLite Query Tracing

## Use When

Use this when diagnosing unexpected SQLite queries, slow queries, observation churn, or sync-trigger noise.

## Guidance

- Configure tracing inside `Configuration.prepareDatabase` so every database connection (live, preview, share-acceptance) is traced consistently.
- Gate tracing to DEBUG so production builds never emit query logs.
- Use the system `Logger` for live/debug app traces; `print` is acceptable only for one-off previews or short local experiments.
- Suppress SyncEngine and trigger noise when it obscures app queries; filter on the SQL prefix or on a known SyncEngine SQL signature.
- Do not trace during tests unless the test is specifically about tracing.

## Pitfalls

- Query logs can leak user data.
- Tracing can slow hot paths.
- Sync and trigger queries can mislead diagnosis if not filtered.

## Tests

Prefer behavior or performance tests over assertions on log output. If tracing is the feature, inject a logger sink.
