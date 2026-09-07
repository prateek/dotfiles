---
status: accepted
doc_type: adr
created: 2026-09-07
owner: Prateek
related:
  - 0010-machine-type-package-selection.md
  - 0012-config-gating-convention.md
  - 0005-mise-tool-management.md
  - ../references/chezmoi-architecture.md
status_detail: "Accepted and implemented on the prateek/setapp-stats-menu branch. Install mechanism verified end to end on a live 3.55.0 client."
---

# ADR 0024 — Setapp subscription apps install from packages.toml via the store API

## Context

Setapp is a subscription that installs Mac apps through its own desktop client.
Homebrew has a cask for the client, but none for the apps behind the
subscription — those exist only in Setapp's catalogue. So `brew bundle` gets the
store and stops there, and every app inside it was installed by hand. A rebuilt
Mac reproduced the Homebrew half and silently lost the Setapp half, which is why
`AGENTS.md` long carried a rule against managed config for a Setapp app: there
was no install path to hang it on.

Setapp ships no supported CLI. Making this declarative meant finding a
programmatic install path. Three were investigated on a live 3.55.0 client:

1. **Setapp's XPC install service.** The background `SetappAgent` hosts
   `com.setapp.AppsManagementService` (and `com.setapp.CommandLineService`) with
   `installApps:` methods. The community tool `maximlevey/setapp-cli` drives
   exactly this. It does not work on current Setapp, and cannot be made to:
   `SetappAgent` runs a listener-wide connection validator
   (`XpcSecurity.framework`, `CodeRequirementValidator`) that admits a caller
   only if it satisfies `anchor apple generic and certificate leaf[subject.OU]
   == <Setapp's Team ID>` (self-pinned to `MEHY5QF425`, Setapp Limited) **and**
   presents a bundle identifier on an allowlist of Setapp's own components
   (`com.setapp.DesktopClient*`, `com.setapp.InstallSetapp`,
   `com.setapp.SingleAppInstaller`). A third-party binary — signed or not,
   whatever identifier it claims — is rejected with `Invalid xpc connection:
   Unknown bundle identifier`. Passing requires Setapp Limited's signing key.
   Verified: even setapp-cli's release binary, which embeds an Info.plist
   declaring `com.setapp.CommandLineClient` and is codesigned to that identity,
   is rejected.

2. **The `setapp://` / `setappDiscovery://` deep links.** The client's
   `InstallAppFromURL` handler installs through Setapp's own UI, so it passes the
   validator — but it opens a confirmation window per app. Semi-automatic, not
   headless. Rejected: it defeats the point of an apply hook.

3. **Direct download of the vendor archive.** The Setapp store exposes a public
   catalogue at `https://store.setapp.com/store/api/v8/en` (HTTP 200, no auth)
   whose every app version carries an `archive_url` — the vendor-signed,
   notarized `.app`, served from S3/CloudFront with no credentials. The
   `rolbk/SetappLite` client installs this way, bypassing XPC entirely. Licensing
   is a separate concern: a Setapp app validates its subscription against the
   agent at first launch through a crypto-receipt path (the agent's
   `SecKeyVerifySignature`), which accepts the vendor's own signature and is
   independent of the Team-ID-pinned install guard.

## Decision

Install Setapp apps by downloading the vendor archive, the way approach 3 does.
Setapp apps become a fourth package section, declared alongside the casks that
already select them.

- `setapp_apps` on a `[packages.groups.*]` entry names Setapp catalogue apps. It
  lives on `mac-desktop`, so `personal` and `work` select it and `ci`/`homelab`
  do not.
- `home/.chezmoitemplates/setapp-applist.tmpl` unions `setapp_apps` across the
  selected groups exactly as `brewfile.tmpl` unions casks, one name per line. It
  fails the render when a selection names Setapp apps without the `setapp` cask,
  since that combination has no install path at all.
- `scripts/packages/render-setapp-applist` renders that fragment for an arbitrary
  machine type, mirroring `render-brewfile`; both share `scripts/packages/lib.sh`.
- `home/.chezmoiscripts/run_after_22-setapp-apps.sh.tmpl` fetches the store
  catalogue once, resolves each declared name to its latest `archive_url`,
  downloads apps that are not already installed, extracts them with `ditto`, and
  places the `.app` into the Setapp apps directory. Each app licenses itself
  against the signed-in agent on first launch — the hook never launches them,
  matching Homebrew-cask semantics.

Properties of the hook, all deliberate:

**Install only, never uninstall.** Apps installed by hand from the Setapp GUI
survive an apply; removals are manual. Matches `brew bundle install --no-upgrade`.

**`run_after_`, not `run_onchange_`.** The preconditions (Setapp present, network
reachable) exit 0 when unmet, and chezmoi records a `run_onchange_` script's
state on any zero exit, so a skipped run would never retry until `packages.toml`
changed again. Already-installed apps are skipped, so re-running every apply is
cheap.

**`DOTFILES_SETAPP_ROOT` override.** The Setapp root defaults to `/Applications`
but is overridable, both for a nonstandard install (e.g. a Home Manager path)
and as the test seam. `DOTFILES_SETAPP_STORE_API` is overridable for tests.

## Consequences

- A rebuilt Mac restores the Setapp apps, and the standing rule against managed
  config for a Setapp app is lifted for any app listed in `setapp_apps`.
- `packages.toml` is the single place a desktop app is declared, whether from
  Homebrew, the Mac App Store, or the Setapp subscription.
- Names must match the Setapp catalogue's display name exactly. A miss is
  reported per app (from the resolver), not a render error, because only the
  catalogue knows the canonical names.
- The install path depends on an **undocumented** store API and direct archive
  URLs. MacPaw can change their shape or gate them at any time; if they do, the
  hook fetches nothing and warns rather than failing the apply. This is the
  accepted fragility of the only headless path that works.
- It is not the sanctioned install path, but it is not an access-control bypass
  either: it downloads publicly served, vendor-signed, notarized archives and
  lets Setapp's own agent license them. No signature is forged and the XPC guard
  is never touched.
- Verified end to end on 3.55.0: a side-loaded iStat Menus (which ships a
  privileged helper, self-installed on first launch via SMAppService) launches
  and shows `LICENSEISINVALID = 0` with a valid license blob in the agent's
  `ProvisioningInfo.sqlite`. The `com.setapp.appInstalledBySetapp` xattr the
  official installer sets is not load-bearing for licensing.
- Setapp login stays manual. It is the one step of a fresh-Mac rebuild this
  cannot automate.

## Alternatives considered

- **maximlevey/setapp-cli (the XPC path).** Rejected: dead on current Setapp per
  the Team-ID-pinned validator above, unfixable without MacPaw's signing key.
- **A committed AppList file.** Simpler, but sits outside the machine-type group
  model, so a work Mac and a personal Mac could not differ.
- **The `setapp://` deep link.** Rejected: one confirmation click per app, not
  headless.
- **Leave Setapp apps unmanaged.** The status quo; rejected because it makes
  `packages.toml` an incomplete description of the desktop, the exact failure a
  fresh-Mac rebuild exposes.

## Future work

Extract the install mechanism from the apply hook into its own packaged tool —
a small standalone CLI or script (its own repo or a `bin/` entry), not logic
embedded in `run_after_22-setapp-apps.sh.tmpl`. The tool would own catalogue
fetch, name → `archive_url` resolution, download, `ditto` extraction, placement,
idempotent already-installed detection, and a licensing-verification check
against the agent's `ProvisioningInfo.sqlite`; the hook would shrink to invoking
it over the rendered app list. Benefits: unit-testable in isolation (today the
logic is only reachable through a rendered chezmoi template), reusable outside
chezmoi (ad hoc `install <app>` / `list`), and a natural home for hardening the
undocumented-API surface — response-schema validation, archive integrity and
signature checks before placement, atomic staging with rollback, and a pinned
catalogue snapshot so a MacPaw-side change fails loudly instead of silently
fetching nothing. If it proves solid, it is also worth publishing for others
hitting the same dead XPC path.
