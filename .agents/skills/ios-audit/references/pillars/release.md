# Pillar: Release & Compliance

## What it answers

- Is this app shippable?
- Does the privacy manifest cover every required-reason API the app uses?
- Are all permission usage strings present and accurate?
- Is localization complete for the target locales?
- Is the build signed correctly?
- Is there an automated release lane (Fastlane) and what does it do?
- Are there any known-risk APIs (IDFA, contacts, location) without
  corresponding declarations?
- Any plaintext credentials or bundle IDs leaking in source / plist?

## Raw inputs

The collector at `scripts/collect/release.py` captures:

- **privacy_manifest** — every `PrivacyInfo.xcprivacy` file, parsed as plist.
- **info_plists** — every `Info.plist` file with its usage descriptions,
  URL schemes, background modes, supported orientations, encryption flag.
- **entitlements** — every `*.entitlements` file, parsed as plist.
- **localization** — every `*.lproj` directory with its `.strings` files
  and per-file key counts; plus every `*.xcstrings` catalog.
- **signing** — `*.xcconfig` files mentioning `CODE_SIGN`, `DEVELOPMENT_TEAM`,
  or `PROVISIONING`; plus `*.pbxproj` signing settings (teams + styles).
- **risky_apis** — grep sites for known-risk APIs: `identifierForVendor`,
  `advertisingIdentifier`, IDFA, AppTrackingTransparency, CLLocationManager,
  UNUserNotificationCenter, Contacts, EventKit, HealthKit, AVCaptureDevice,
  PHPhotoLibrary, documentDirectory access.
- **fastlane** — `fastlane/` directory presence, file list, lane names
  parsed from `Fastfile`.

## Tuist-generated configuration

If the project uses Tuist, the collector may find NO `Info.plist` or
`.entitlements` files at the repo root — they're generated at build time
from `Project.swift`. In that case, the analyzer should read `Project.swift`
directly and note that the release configuration lives in the Tuist manifest.

This is common and not a finding in itself, but the analyzer should verify
that `Project.swift` declares the same usage descriptions, privacy manifest,
and signing that a raw Info.plist would carry.

## Required tools

- **Python 3.10+** with the standard library (`plistlib` is builtin)

No optional tools — everything is file + plist parsing.

## Analyzer outputs

See `scripts/analyze/prompts/release.md`. The prompt produces:

- `release/privacy-manifest.md`
- `release/permissions-and-plist.md`
- `release/localization.md`
- `release/signing-and-distribution.md`
- `release/app-store-readiness.md` (ship gate checklist)
- `release/third-party-dependencies.md`

## Common findings patterns

| ID example | Pattern | Severity |
|---|---|---|
| RL-001 | No PrivacyInfo.xcprivacy → App Store rejection | critical |
| RL-002 | Uses `identifierForVendor` without required-reason declaration | critical |
| RL-003 | Plaintext API key in Info.plist or Swift source | critical |
| RL-004 | Permission API called but usage description missing | critical |
| RL-005 | ITSAppUsesNonExemptEncryption not declared | major |
| RL-006 | Only English localized; app ships to non-English markets | major |
| RL-007 | Fastlane lane has drift from what's documented | moderate |
| RL-008 | Unused usage description string (API not called) | minor |
| RL-009 | Stale copyright year | minor |
