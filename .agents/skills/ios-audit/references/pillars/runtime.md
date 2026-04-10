# Pillar: Runtime Quality

## What it answers

- How does the app fail, and how does it recover?
- What gets logged, at what level, with what context?
- What is cached, and with what TTL / size cap?
- Are there retry / backoff / timeout strategies for transient failures?
- Where are silent errors hiding (`try?`, empty catches)?
- Where does the app touch persistent storage, and is it safe?
- For media apps: playback resilience, buffer management, quality switching.

## Raw inputs

The collector at `scripts/collect/runtime.py` is grep-based and captures:

- **logging** — every `os_log`, `Logger`, `os.Logger`, `print`, `debugPrint`,
  `NSLog` call site.
- **retry_patterns** — `retryCount`, `maxRetries`, `retryTask`,
  `exponentialBackoff`, `Task.sleep`, `DispatchQueue.main.asyncAfter`.
- **timeouts** — `timeoutInterval*`, `URLSessionConfiguration`,
  `.timeoutIntervalForRequest`, `.timeoutIntervalForResource`.
- **cache_usage** — `URLCache`, `NSCache`, `ImageCache`, `Nuke.*`, `Cache`.
- **network_monitor** — `NWPathMonitor`, `NetworkMonitor`, `isConnected`,
  `reachability`.
- **silent_errors** — `try?`, empty `catch {}`, comment-only catch,
  `// silent`.
- **persistence** — `UserDefaults.`, `KeychainHelper`, `Keychain.`,
  `FileManager.default`, `NSCoding`, `Codable .* write`.
- **playback_signals** — `AVPlayer`, `AVPlayerItem`, `AVPlayerLayer`,
  `timeControlStatus`, `isPlaybackBufferEmpty`, `isPlaybackLikelyToKeepUp`.

A summary block reports total counts per category so the analyzer can spot
ratios at a glance (e.g. "45 silent-error sites vs 2 os_log sites" is a
clear signal).

## Required tools

**None** — pure grep. Instruments (`xcrun xctrace`) integration is on the
roadmap but not shipped yet; the analyzer may optionally invoke it
manually and attach results to `.audit/raw/runtime.json` under a new key.

## Analyzer outputs

See `scripts/analyze/prompts/runtime.md`. The prompt produces:

- `operations/failure-modes.md`
- `operations/caching-strategy.md`
- `operations/resource-usage.md`
- `operations/runbooks/<topic>.md` (per gap worth a runbook)
- `operations/observability.md`

## Common findings patterns

| ID example | Pattern | Severity |
|---|---|---|
| RT-001 | Save path catches and ignores errors → data loss | critical |
| RT-002 | No retry on transient API failure, user sees generic error | major |
| RT-003 | URLSession default 60s timeout is too long for mobile | major |
| RT-004 | Image cache without size cap → memory pressure | major |
| RT-005 | Response body re-fetched every tab switch — no in-memory cache | moderate |
| RT-006 | Logging uses `print()` instead of `Logger` — not filterable | moderate |
| RT-007 | Error types are `NSError`-ish instead of enum cases | minor |
