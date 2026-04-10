# Release: Fastlane, TestFlight, App Store Connect

Read this file when you need to set up releases for a new app, rotate an ASC API key, or debug a failing `fastlane beta` run. The scaffold templates under `assets/templates/fastlane/` and `assets/templates/github-workflows/testflight.yml` encode these rules.

## The key fact about ASC app creation

**As of April 2026, you cannot create an App Store Connect app record programmatically with an API key.** Apple's ASC API has no `POST /v1/apps` endpoint. `fastlane produce` still requires Apple-ID + 2FA for both the ASC app record half and the Developer Portal bundle ID half ([fastlane/fastlane#29435](https://github.com/fastlane/fastlane/issues/29435)).

So the scaffold enforces a one-time manual step: create the app in the ASC web UI, then automate everything after. The `create_app_in_asc` lane in the template Fastfile fails loudly on purpose to remind you.

Everything else — bundle ID registration via `match`, TestFlight uploads, metadata sync, App Store submission — supports ASC API key auth and is automated.

## Required environment variables

Fastlane's `app_store_connect_api_key` action reads three canonical env vars. Do **not** rename them:

- `APP_STORE_CONNECT_API_KEY_KEY_ID` — the 10-character Key ID.
- `APP_STORE_CONNECT_API_KEY_ISSUER_ID` — the UUID Issuer ID.
- `APP_STORE_CONNECT_API_KEY_KEY_FILEPATH` — filesystem path to the `.p8` file. Alternative: `APP_STORE_CONNECT_API_KEY_KEY` with inline content (better for CI where you paste the key as a secret).

Source: [app_store_connect_api_key.rb](https://github.com/fastlane/fastlane/blob/master/fastlane/lib/fastlane/actions/app_store_connect_api_key.rb).

Note the doubled `_KEY_` in two of the names — it's easy to miss and fastlane will silently fall back to password auth if the env var is misnamed.

## The asc_auth pattern

Every lane that talks to ASC starts with a call to a private `asc_auth` lane:

```ruby
private_lane :asc_auth do
  app_store_connect_api_key(
    is_key_content_base64: false,
    in_house: false
  )
end

lane :beta do
  asc_auth
  build_app(scheme: ENV.fetch("SCHEME"), export_method: "app-store")
  upload_to_testflight(skip_waiting_for_build_processing: true)
end
```

`app_store_connect_api_key` sets `lane_context[SharedValues::APP_STORE_CONNECT_API_KEY]`, which every downstream ASC-facing action picks up automatically. You do not pass the key through each action's parameters; the lane context threads it.

## Key rotation

ASC API keys last indefinitely by default, but rotate yearly as hygiene:

1. Generate a new key at https://appstoreconnect.apple.com/access/api (Users and Access → Integrations → App Store Connect API).
2. Download the new `.p8` file.
3. Update the local file and the env var in `fastlane/.env`.
4. Update the GitHub repo secret (`ASC_API_KEY_KEY_ID`, etc.) with the new values.
5. Run `fastlane beta` locally once to confirm it works.
6. Delete the old key from ASC.

Apps in flight during rotation may need a forced rebuild; the new key has the same permissions so upload flows are otherwise unchanged.

## Secret storage

- **Local**: `.p8` file at `~/.config/app-store-connect/AuthKey_XXXX.p8`, `chmod 600`. `fastlane/.env` holds the three env vars and is gitignored.
- **CI**: GitHub repo secrets. For `KEY_FILEPATH`, you need to materialize the `.p8` in the runner workspace before Fastlane runs; the simpler path is to paste the `.p8` contents as `APP_STORE_CONNECT_API_KEY_KEY` and let Fastlane read the content directly.
- **1Password**: store both the `.p8` file and the Key ID / Issuer ID as structured secrets. Use `op read` in a shell script to populate env vars at session start if you prefer not to keep unencrypted files on disk.

Never commit `.p8`, `.p12`, `.mobileprovision`, or any `AuthKey_*` file.

## Beta → Release pipeline

The scaffold's `.github/workflows/testflight.yml` fires on tag push:

```
git tag v0.1.0
git push origin v0.1.0
```

The tagged push triggers `fastlane beta`, gated behind the `testflight` environment reviewer. Once the build is live in TestFlight, testers get it through the Apple TestFlight app.

For App Store submission (the `release` lane), use `workflow_dispatch` only. Never automate App Store submission on tag push — you want a human in the loop for the "Submit for Review" click.

## Metadata and screenshots

The scaffold does not generate metadata or screenshots. Create them once, then let the `metadata` lane sync:

```bash
fastlane metadata     # pulls current ASC metadata down into fastlane/metadata/
# Edit fastlane/metadata/en-US/description.txt etc.
fastlane deliver --force --skip-binary-upload=false  # push edits back
```

Store localized descriptions, keywords, promotional text, and release notes under `fastlane/metadata/<locale>/`. Commit them; they aren't secret.

Screenshots live under `fastlane/screenshots/<locale>/<device>/`. Use `fastlane snapshot` (a separate tool) to generate them via XCUITest if you want to automate; otherwise capture manually and drop them in the right directory.

## match (signing)

`match` manages signing certs and provisioning profiles via a private git repo. It supports ASC API key auth for bundle ID registration in the Developer Portal, which is the one Fastlane-produce alternative that actually works with just the API key.

Setup (once per team):

```bash
fastlane match init                   # asks for your cert repo URL
fastlane match appstore               # creates distribution cert and profile
fastlane match development            # creates development cert and profile
```

Add to the Fastfile:

```ruby
lane :certs do
  asc_auth
  match(type: "appstore", readonly: false)
  match(type: "development", readonly: false)
end
```

Then `fastlane beta` and `fastlane release` call `match(type: "appstore", readonly: true)` before `build_app` to pull signed credentials without modifying the cert repo.

Store the `MATCH_PASSWORD` (encryption key for the cert repo) as an env var alongside the ASC API key vars.

## Troubleshooting

- **Fastlane asks for an Apple-ID password**: the env vars aren't loaded. `set -a; source fastlane/.env; set +a` before running, or use `dotenv`.
- **"No Data provider found for your App Store Connect API key"**: the Key ID or Issuer ID is wrong. Check them in the ASC web UI under Users and Access → Integrations.
- **Upload hangs on "Processing build"**: Apple's TestFlight processing queue. Pass `skip_waiting_for_build_processing: true` to return immediately after upload.
- **`match` asks for MATCH_PASSWORD**: set it as an env var or pipe it: `MATCH_PASSWORD=xxx fastlane certs`.
- **Build fails with "No account for team"**: check `fastlane/Appfile` → `team_id` matches your developer team. Find the team ID at https://developer.apple.com/account under Membership.
