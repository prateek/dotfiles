---
status: draft
doc_type: plan
owner: Prateek
created: 2026-10-05
updated: 2026-10-05
related:
  - tcc-onboarding-plan.md
  - ../adr/0044-tcc-onboarding.md
status_detail: "Deferred follow-up: standalone utility, independently published app registry, release automation, website and launch materials."
---

# Standalone permission utility and launch

Extract the native helper after [attended onboarding validation](tcc-onboarding-plan.md#critical-path-and-acceptance).
Ship a Mac utility whose permission definitions can update independently of its
binary. Build the release pipeline and a public website, then prepare marketing
copy and launch materials for Product Hunt, Reddit and other relevant channels.

This is future work. The current helper reads a local chezmoi manifest, builds
locally and has no remote registry or public product site. The initial copy below
is a draft; the product name, domain and distribution terms remain undecided.

## Registry versioned per app

Keep one independently versioned definition per app, keyed by a stable app ID.
Distinguish the definition revision from the installed app version: a revised
permission description must not require a new utility build or imply that every
app update invalidates its grants.

Each definition includes bundle identity, supported app-version ranges, declared
helper paths, permissions, reasons, recovery instructions and supporting evidence.
Record verification date and tested macOS/app versions. Use separate variants
when an app version changes its helper layout or requirements. Unknown versions
remain explicitly unverified instead of inheriting an arbitrary definition.

Publish immutable definition revisions and an immutable registry snapshot. A
small latest index points to the snapshot and its per-app revisions. The registry
schema version, snapshot revision, definition revision and app version are
separate fields. Schema-breaking updates require a compatible client; ordinary
app additions and definition corrections do not.

The utility checks for the latest compatible registry on launch and offers an
explicit refresh. Fetch off the UI thread with a bounded timeout; compare
revisions, fetch a changed snapshot as one static artifact, validate the complete
candidate, then replace the cache atomically. Reuse unchanged definitions locally. Retain a bundled baseline and the last known
good snapshot for offline use or a failed update. Show the registry revision and
last successful update in the UI, with a clear cached-state indication.

Authenticate the published index and artifact hashes with a signing key whose
public key the utility trusts. Define key rotation and rollback before release.
Reject invalid signatures, unsupported schemas, unexpected identity changes and
unsafe helper paths. Definitions are data, never executable commands or arbitrary
URLs to launch. Keep service handling and native actions in reviewed utility code.

Preserve local selection and overrides: a public definition describes an app's
possible requirements; the user or dotfiles chooses which features and grants
to expect. Registry updates must not opt users into newly added apps or features.
Present changed expectations for review. Keep private/work definitions in local
overlays. Send no installed-app inventory to the registry server; choose a static
snapshot delivery design that does not require per-app network queries.

Acceptance: publish a new app definition and a correction, fetch both with the
same utility binary, and verify its hash is unchanged. Exercise offline startup,
corrupt downloads, invalid signatures, unsupported schemas, rollback, app-version
selection and local overrides. None of these paths may write TCC or change grants.

## CI/CD and distribution

Use separate publish workflows for the utility and registry. A registry release
must not build the app. A utility release must not silently revise definitions.

Registry pull requests validate schemas, stable IDs, version ranges, helper-path
confinement, supported services and evidence links. Produce a readable change
summary per app. After review, publish signed immutable artifacts and promote the
latest index only after validating the published snapshot. Keep previous releases
available and rehearse rollback.

Utility pull requests run native tests, manifest compatibility and updater failure
tests. Tagged releases build Apple silicon and Intel artifacts, sign and notarize
the app, staple the result, and publish checksums and release notes. Keep signing
credentials in protected CI secrets. Smoke-test the downloaded artifact on a clean
Mac without Swift or Xcode and verify the existing grant survives an ordinary
compatible update. Record any reauthorization requirement rather than promising
that signing alone prevents it.

Dotfiles installs a pinned utility release and retains its terminal opt-in flow.
The utility's compatible registry can advance independently; support a registry
pin for reproducible onboarding. Define application update channels and rollback
separately from registry refresh. Document maintainer ownership, contribution
review, release recovery and support before public launch.

## Website and launch deliverables

Create the standalone product website with native light/dark screenshots and a
short recording of a verified Settings flow. Explain supported services, exact
drag targets, stale-grant recovery, the registry contribution process and the
privacy model. Include download/install instructions, system requirements,
changelog, help and source links. Avoid claims of automatic grants or universal
permission detection. Publish compatibility claims only after attended validation.

Prepare a reusable copy pack: homepage, short and long descriptions, screenshot
captions, release announcement, FAQ and contributor invitation. Then adapt it to
each channel:

- Product Hunt: tagline, description, gallery, demo and maker comment.
- Reddit: useful posts for relevant Mac and developer communities, a clear maker
  disclosure, concrete examples and an invitation for compatibility reports.
- Other channels: repository README, release notes, a concise demo post, and
  possible Show HN/community announcements where appropriate.

Verify current platform and community submission rules when preparing the launch.
Choose destinations from audience fit. Keep final copy and assets reviewable
before publishing; this deferred plan does not schedule or post announcements.

## Initial copy draft

Working headline: **Know which Mac permissions your apps need.**

Homepage introduction:

> Review your apps' macOS permissions in one native window. See which recorded
> grants match the installed app, follow recovery steps for stale entries, and
> drag the exact app into System Settings. You approve every change.

Registry paragraph, for use after implementation:

> App permission definitions stay current through a versioned community registry.
> Refresh the registry without reinstalling the utility. Your selected apps and
> local overrides stay yours, and permission checks happen on your Mac.

Product Hunt tagline: **A native guide to your Mac's app permissions.**

Maker-comment draft:

> I built this after setting up Macs and repeatedly hunting for the right app in
> Privacy & Security. The utility shows the permission target and opens the right
> Settings pane. It also compares saved grants with the installed app's code
> identity, so an old entry can be explained instead of treated as working.
> I'd love reports of confusing onboarding flows and apps the registry should
> cover.

Reddit title draft: **I built a native Mac app to help review app permissions and stale grants**

Reddit post draft:

> I'm the developer. This started as a helper for my dotfiles setup: list the
> permissions selected apps need, check the recorded state, and make it easier
> to add the correct app or helper in System Settings.
>
> A single checklist groups permissions by app and expands the Settings guidance
> inline. It reads permission records; you make every grant change.
> Access to those records requires Full Disk Access for the helper, which the
> setup screen explains.
>
> Which apps have the most confusing permission setup? Compatibility reports
> would help me improve the definitions and recovery instructions.

Replace the working name, add verified screenshots and demo links, and reconcile
all copy with the shipped feature set before launch. Pricing, license, support
scope and analytics policy need explicit decisions before the site is published.
