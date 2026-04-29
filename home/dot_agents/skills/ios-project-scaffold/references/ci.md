# CI and GitHub Actions cost control

The scaffold's `.github/workflows/ci.yml`, `security.yml`, and `beta.yml` templates encode these rules. Read this file when you need to tune them, add a new workflow, or debug a CI cost spike.

## The cost math

GitHub-hosted macOS runners cost roughly 30× a Linux runner per minute:

| Runner | Rate (USD/min) |
|---|---|
| Linux 1-core | 0.002 |
| Linux 2-core x64 | 0.006 |
| Linux 2-core arm64 | 0.005 |
| Windows 2-core x64 | 0.010 |
| Windows 2-core arm64 | 0.010 |
| macOS standard | 0.062 |

Source: https://docs.github.com/en/billing/reference/actions-runner-pricing

An unbounded macOS job running 60 minutes once per push costs ~$3.72 per run. Ten contributors × ten pushes a day = $372/day.

## Routing rules

- **Push to Linux** anything that does not need Xcode: linters, spell checks, docs builds, JSON/YAML validation, shell script checks, markdown validation, simple unit tests written in Go or Python.
- **Keep on macOS only** what genuinely needs Apple tooling: `xcodebuild`, `tuist generate`, SwiftPM builds, TestFlight uploads, any code signing.
- **Split rather than promote.** Two 3-minute jobs (one Linux, one macOS) cost less than one 6-minute macOS job. Break mixed workloads by language, not by phase.

## Mandatory macOS job settings

Every macOS job must set:

1. **Explicit `timeout-minutes`.** Start conservative (15 for build-and-test, 30 for TestFlight deploys) and tighten as you measure. Unbounded macOS jobs are the #1 cause of cost spikes.
2. **`concurrency:` with `cancel-in-progress: true`** so stale runs do not keep consuming minutes after a new push. The scaffold does this automatically in `ci.yml`.
3. **Pinned `xcode-version`** matching `.xcode-version` in the repo. `maxim-lobanov/setup-xcode@v1` is the standard action; it switches among pre-installed versions.
4. **`xcodebuild` output piped through `xcbeautify`.** Raw `xcodebuild` log volume wastes human review time and hides errors; also increases log storage cost.
5. **Runner image pinned** to `macos-15` or `macos-26`. Never use `macos-latest` — it silently flips under you and breaks reproducibility. Both `macos-15` and `macos-26` ship Xcode 26.3 and iOS 26.2 pre-installed as of April 2026; pick one and stick.
6. **No runtime download step.** The iOS 26.2 runtime is baked into the image. Explicit `xcodes runtimes install` is not needed for the canonical triple.

## Trigger gates

- **ci**: fires on `push` and `pull_request`. Cheap, high-frequency.
- **TestFlight deploy**: fires only on tag pushes matching `v*` or on manual dispatch. Never fires on every commit; the cost and the TestFlight rate limit both matter.
- **TestFlight deploy**: tag or manual dispatch only, and require an environment reviewer gate. The scaffold's `beta.yml` uses `environment: beta`.

Never rerun the full CI suite inside a deploy workflow unless the extra coverage justifies the cost. If it does, quote the cost in the workflow file comments.

## Budgets

For every personal iOS repo with recurring macOS usage:

1. Open `https://github.com/settings/billing` → `Budgets and alerts`.
2. Create a product-level budget for `Actions`, scoped to the repository.
3. Set a monthly limit (start at $20 for low-traffic repos, $50 for active ones).
4. Enable threshold alerts at 50%, 75%, 90%.
5. Enable `Stop usage when budget limit is reached` if you want a hard ceiling.

## Diagnosing a cost spike

Investigate in this order when billing jumps:

1. **Group spend by workflow, job, runner label, and actor.** The GitHub billing UI supports this filter.
2. **Look for long `macos-*` jobs first.** These dominate cost.
3. **Look for cancelled runs that still consumed minutes.** Cancellation doesn't refund partial minutes.
4. **Look for duplicate CI triggered by both push and deploy flows.** Common footgun.
5. **Look for release jobs waiting indefinitely on external systems.** TestFlight upload occasionally hangs; add a short timeout at the Fastlane action level.

Once you know the cause, apply one of: add a timeout, tighten a trigger, move the job to Linux, or split it.

## Structured test results (`xcresult`)

Agents parse text logs inefficiently. Upload the `.xcresult` bundle as an artifact and let downstream tools read it:

```yaml
- name: Archive xcresult bundle
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: xcresults
    path: build/results/*.xcresult
    if-no-files-found: ignore
```

`xcresulttool get --path foo.xcresult --format json` produces structured failure diagnostics. The scaffold's `ci.yml` uploads the `.xcresult` bundle so downstream tools can inspect it.

## Tuist Cloud in CI

If the project uses Tuist Cloud binary caching (see `tuist.md` in this skill), add a repo secret for the Tuist token and a cache-warm step to the nightly build:

```yaml
- name: Warm Tuist Cloud cache
  env:
    TUIST_CONFIG_CLOUD_TOKEN: ${{ secrets.TUIST_CLOUD_TOKEN }}
  run: tuist cache warm
```

Schedule the warm job with `schedule: - cron: '0 6 * * *'` so the cache is fresh for the day's work and never blocks a push.
