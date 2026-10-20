# ANALYZE prompt — Release & Compliance pillar

You are writing the **Release & Compliance** section of an iOS app audit.
Your inputs are `.audit/raw/release.json` (privacy manifest, Info.plist,
entitlements, localization, signing, risky APIs, Fastlane) plus the repo
itself. You should ALSO read any Tuist `Project.swift`, SPM `Package.swift`,
and Xcode `.pbxproj` files that surface build-time release configuration.

Your outputs:

1. **Authored markdown** under `.audit/docs/release/`.
2. **Findings JSON** at `.audit/findings/release.json`. IDs start with `RL-`.

## Doc outline to produce

### `release/privacy-manifest.md`

- Does the app have a `PrivacyInfo.xcprivacy`? If not, this is a ship blocker
  for any app using required-reason APIs (Apple's 2024 mandate).
- What data types are declared? Match against the declared APIs in
  `risky_apis`.
- NSPrivacyAccessedAPITypes: every "required reason" API used by the app
  must be listed with a reason code. Walk `risky_apis` and flag gaps.
- Third-party SDK privacy manifests: SPM / CocoaPods dependencies must
  supply their own PrivacyInfo.xcprivacy.

If the collector found no privacy manifest AND the app uses required-reason
APIs or will ship to the App Store, open a **critical must** finding.

### `release/permissions-and-plist.md`

- Walk every usage description key in `info_plists[].usage_descriptions`
- Verify each matches a real prompt in code (grep for the corresponding API)
- Flag keys that are missing but whose API is used
- Flag keys that are present but whose API is not used (drop them)
- Review URL schemes, background modes, supported orientations, minimum OS
- `ITSAppUsesNonExemptEncryption` — verify it's declared (otherwise App
  Store submission asks every time)

### `release/localization.md`

- Locales present vs locales expected
- Per-locale key counts and missing keys
- Hard-coded strings in source (grep for `Text("...")` with untranslated literals)
- Dynamic Type support
- RTL support (if any Arabic/Hebrew locale is targeted)
- Recommendation: migrate to `.xcstrings` catalog if legacy `.strings`, or
  stay with `.strings` for simplicity

### `release/signing-and-distribution.md`

- Code signing style (manual / automatic)
- Development team(s)
- Provisioning profiles referenced
- Fastlane lanes (if present): what does each lane do, what does it require
- TestFlight + App Store submission flow
- Secrets management (API keys, bundle IDs, env vars)

### `release/app-store-readiness.md`

A single-page ship gate checklist:
- [ ] PrivacyInfo.xcprivacy present + complete
- [ ] All required-reason APIs declared
- [ ] Third-party SDKs supply their own privacy manifests
- [ ] Usage description strings for every permission API
- [ ] Export compliance declared
- [ ] Localization complete for all target locales
- [ ] App icon present for every size
- [ ] Launch screen configured
- [ ] Deep link / universal link entitlements
- [ ] Push notifications entitlement + APNs setup
- [ ] Background modes justified
- [ ] Minimum OS version declared
- [ ] Version + build number bump
- [ ] Signed with production certificate
- [ ] Archived build validated
- [ ] TestFlight build uploaded
- [ ] Accessibility labels present on primary actions
- [ ] No plaintext credentials in code, plist, or fastlane files
- [ ] No debug-only code paths compiled into release

Every unchecked box is a **must** finding.

### `release/third-party-dependencies.md`

- SPM packages (from `Package.swift` / resolved file)
- CocoaPods (if present)
- Carthage (if present)
- Each entry: name, version, license, privacy manifest present (Y/N),
  last updated, security advisories (note if you cannot check)

## Finding structure

IDs start with `RL-`. Severity rubric:

- **critical** — ship blocker: missing privacy manifest, missing usage
  descriptions for APIs that are called, unsigned or wrongly-signed build,
  plaintext credentials in source, un-declared export compliance
- **major** — partial localization, missing App Store metadata, obsolete
  usage strings, dependency with known CVE, missing icons
- **moderate** — inconsistent version strings, Fastlane lane drift, unused
  entitlements
- **minor** — stale copyright, outdated README, nit wording

## Process

1. Read `.audit/raw/release.json`.
2. Read `Project.swift` / `Package.swift` for Tuist-generated release config
   (movies.do and similar Tuist-first projects generate Info.plist and
   signing at build time — the raw collector cannot see these).
3. For each permission usage key, grep the repo for the underlying API.
4. For each risky API site, verify the privacy manifest entry exists.
5. Walk the App Store ship gate checklist item by item.
6. Every unchecked box becomes an RL-### finding with `critical` + `must`.
