# Bootstrap Instructions

This project was scaffolded by `ios-project-scaffold`. The Makefile, Tuist manifest, worktree helper, simprofile, Fastlane lanes, hooks, and GitHub Actions workflows are already in place. Do these steps once per new app to finish setup.

## Prerequisites

- Xcode 26.3 installed and selected (`xcodes select 26.3`).
- `git init` followed by `make bootstrap-local`.
- An Apple Developer Program membership under the team ID in `fastlane/Appfile`.

## Local Developer Setup

```bash
git init
make bootstrap-local
make generate
make build
make run-iphone
make test-matrix
```

The worktree helper creates and reuses repo-owned simulators automatically. Inspect the current owner, locks, and simulator metadata with:

```bash
make doctor-state
```

All repo-generated mutable state lives under `build/`. Do not point new tooling at `~/Library/Developer/Xcode/DerivedData` when the repo-owned path exists.

## App Store Connect Setup

`fastlane produce` and the ASC API do not support programmatic app-record creation as of April 2026. Create the app record in the App Store Connect web UI once, then use Fastlane for every upload after that.

1. Sign in at `https://appstoreconnect.apple.com/apps`.
2. Create a new iOS app using the bundle identifier from `fastlane/Appfile`.
3. Generate an App Store Connect API key at `https://appstoreconnect.apple.com/access/api`.
4. Store the `.p8` file outside the repo and copy `fastlane/.env.example` to `fastlane/.env`.

Set these values in `fastlane/.env`:

```bash
APP_STORE_CONNECT_API_KEY_KEY_ID=XXXXXXXXXX
APP_STORE_CONNECT_API_KEY_ISSUER_ID=00000000-0000-0000-0000-000000000000
APP_STORE_CONNECT_API_KEY_KEY_FILEPATH=/Users/you/.config/app-store-connect/AuthKey_XXXXXXXXXX.p8
```

## CI Setup

- Add the App Store Connect secrets required by `.github/workflows/beta.yml`.
- Configure the `beta` environment in GitHub Actions if you want approval gates for TestFlight uploads.
- Keep workflow invocations on the `make` surface so CI and local automation use the same build structure.

## Fast Local Loop

- `make generate` refreshes the generated project from Tuist.
- `make build`, `make run-iphone`, and `make run-ipad` go through the worktree helper.
- `make test-matrix` runs the full build-and-test sweep across both device families.
- `make trace-matrix` captures a clean waterfall trace under `build/traces/`.
- `.githooks/pre-commit` only touches staged files and stays off the simulator and `xcodebuild` path.

## Cleanup and Recovery

```bash
make clean-build
make clean-simulators
make reset-simulators
make clean
```

Use `make release-owner` if a stale owner lock blocks the worktree after a crashed shell or agent.
