# Bootstrap Instructions

This project was scaffolded by `ios-project-scaffold`. The Makefile, Tuist manifest, Fastlane lanes, hooks, and GitHub Actions workflows are already in place. Do these steps **once** per new app to finish the setup.

## Prerequisites

- Xcode 26.3 installed and selected (`xcodes select 26.3`).
- `git init` followed by `make bootstrap-local` (trusts `mise.toml`, installs tools, installs hooks, and checks Xcode).
- An Apple Developer Program membership under the team ID in `fastlane/Appfile`.

## Step 1 — Create the App Store Connect record (one-time, manual)

`fastlane produce` and the ASC API do not support programmatic app-record creation as of April 2026. Create the record in the web UI. Takes ~60 seconds.

1. Sign in at **https://appstoreconnect.apple.com/apps**.
2. Click **+** → **New App**.
3. Fill:
   - **Platform**: iOS
   - **Name**: your app's display name
   - **Primary Language**: English (U.S.) or your default
   - **Bundle ID**: the value from `fastlane/Appfile` → `app_identifier`
   - **SKU**: any stable string (e.g. the bundle ID)
   - **User Access**: Full Access
4. Click **Create**.

## Step 2 — Generate an ASC API key (one-time, manual)

1. Sign in at **https://appstoreconnect.apple.com/access/api**.
2. **Users and Access** → **Integrations** → **App Store Connect API**.
3. Click **Generate API Key** (or **+**).
4. Name it (e.g. `fastlane-beta`).
5. **Access**: `Admin` or `App Manager`.
6. Click **Generate**.
7. Download the `.p8` file immediately — Apple only lets you download it once.
8. Note the **Key ID** (10 characters) and the **Issuer ID** (UUID) shown in the UI.

Store the `.p8` file somewhere stable outside the repo:

```bash
mkdir -p ~/.config/app-store-connect
mv ~/Downloads/AuthKey_XXXXXXXXXX.p8 ~/.config/app-store-connect/
chmod 600 ~/.config/app-store-connect/AuthKey_XXXXXXXXXX.p8
```

## Step 3 — Wire the key into local Fastlane

```bash
cp fastlane/.env.example fastlane/.env
# Edit fastlane/.env with the three values from Step 2:
#   APP_STORE_CONNECT_API_KEY_KEY_ID=XXXXXXXXXX
#   APP_STORE_CONNECT_API_KEY_ISSUER_ID=00000000-0000-0000-0000-000000000000
#   APP_STORE_CONNECT_API_KEY_KEY_FILEPATH=/Users/you/.config/app-store-connect/AuthKey_XXXXXXXXXX.p8
```

`fastlane/.env` is in `.gitignore`; never commit it.

## Step 4 — Wire the key into CI

In the GitHub repo: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**. Create three secrets:

- `ASC_API_KEY_KEY_ID` — the 10-character Key ID from Step 2.
- `ASC_API_KEY_ISSUER_ID` — the UUID Issuer ID from Step 2.
- `ASC_API_KEY_KEY_FILEPATH` — path where the `.p8` will land in the runner workspace (for GHA, it's easier to inline the key content; see below).

Because the GHA runner is ephemeral, prefer the inline-content variant in `.github/workflows/testflight.yml`: swap `APP_STORE_CONNECT_API_KEY_KEY_FILEPATH` for `APP_STORE_CONNECT_API_KEY_KEY` and paste the `.p8` content (or base64 of it) directly into a secret.

Also create a **protected environment** called `testflight` under **Settings** → **Environments** → **New environment**. Require a reviewer on that environment so TestFlight pushes always need explicit approval.

## Step 5 — First local build

```bash
git init
make bootstrap-local         # installs tools, hooks, and checks Xcode
make lint                    # fast local hygiene; no simulator required
make generate                # tuist generate
# Manually boot a simulator once and drop its UDID in .ios-sim-udid:
xcrun simctl boot "iPhone 17 Pro"
xcrun simctl list devices booted -j \
  | jq -r '.devices | to_entries[] | .value[] | select(.state=="Booted") | .udid' \
  | head -1 > .ios-sim-udid
make run
make test
```

If every target succeeds, you're ready to ship.

## Fast local loop

The default local loop is intentionally fast:

- `make format` rewrites Swift files.
- `make lint` runs formatting lint, SwiftLint, and typos.
- `make setup-tools` trusts `mise.toml` and installs pinned tools.
- `make bootstrap-local` runs `setup-tools`, installs hooks, and checks Xcode.
- `.githooks/pre-commit` only checks staged files.

Hooks never run `xcodebuild`, simulator-based tests, or deep static analysis.

## Step 6 — First TestFlight upload

Local:

```bash
make beta
```

The first upload takes 5–15 minutes. Fastlane prints a TestFlight build link when it finishes.

CI (after secrets are in place):

```bash
git tag v0.1.0
git push origin v0.1.0
```

The tagged push fires `.github/workflows/testflight.yml`, which requires the `testflight` environment reviewer to approve before uploading.

## Troubleshooting

- **Fastlane asks for an Apple-ID password**: the ASC API key env vars aren't set or aren't readable. Source `fastlane/.env` first (`set -a; source fastlane/.env; set +a`) or run via `bundle exec` with dotenv loaded.
- **`fastlane produce` errors**: don't run it. The scaffold's `create_app_in_asc` lane fails on purpose to remind you to use the web UI.
- **Xcode version mismatch**: `make check-xcode` fails — run `xcodes select 26.3`.
- **`.ios-sim-udid` missing**: see `~/.agents/skills/ios-sim-lease/SKILL.md` for the interim flow.

## See also

- `~/.agents/docs/ios.md` — iOS conventions playbook.
- `~/.agents/skills/ios-project-scaffold/` — this skill; run `audit` mode to check drift.
