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
status_detail: "Accepted and implemented on the prateek/setapp-stats-menu branch."
---

# ADR 0024 — Setapp subscription apps install from packages.toml via setapp-cli

## Context

Setapp is a subscription that installs Mac apps through its own desktop client.
Homebrew has a cask for the client itself, but none for the apps behind the
subscription — those exist only in Setapp's catalogue. So `brew bundle` gets the
store and stops there, and every app inside it was installed by hand.

That left `home/.chezmoidata/packages.toml` describing only part of the desktop.
A rebuilt Mac reproduced the Homebrew half and silently lost the Setapp half,
which is why `AGENTS.md` carried a standing rule against adding managed config
for a Setapp app: there was no install path to hang it on.

Setapp ships no supported CLI. It does expose an XPC service,
`com.setapp.AppsManagementService`, hosted by its launch agent and used by its
own helpers. Three ways to reach it were on the table:

- **`setappDiscovery://` deep links.** The client's `InstallAppFromURL` handler
  opens a confirmation window per app. Undocumented, and interactive.
- **UI automation.** Needs an Accessibility grant and breaks on every redesign.
- **[setapp-cli](https://github.com/maximlevey/setapp-cli).** A third-party
  Swift binary that reads Setapp's own catalogue database for app IDs and drives
  the same XPC service through `SetappInterface.framework`. No private macOS
  APIs, no Accessibility grant, no UI automation. It exposes a Brewfile-shaped
  `bundle install / check / dump / cleanup` surface over a plain-text AppList.

## Decision

Setapp apps become a fourth package section, declared alongside the casks that
already select them.

- `setapp_apps` on a `[packages.groups.*]` entry names Setapp catalogue apps.
  It lives on `mac-desktop`, so `personal` and `work` select it and `ci` and
  `homelab` do not.
- `home/.chezmoitemplates/setapp-applist.tmpl` unions `setapp_apps` across the
  selected groups exactly as `brewfile.tmpl` unions casks, and renders one name
  per line. It fails the render when a selection names Setapp apps without the
  `setapp` cask, since that combination has no install path at all.
- `scripts/packages/render-setapp-applist` renders that fragment for an
  arbitrary machine type, mirroring `render-brewfile`. Both now share the
  machine-type pinning in `scripts/packages/lib.sh`.
- `home/.chezmoiscripts/run_after_22-setapp-apps.sh.tmpl` feeds the rendered
  AppList to `setapp-cli bundle install`.
- setapp-cli installs through mise (`github:maximlevey/setapp-cli`), which
  verifies the release's GitHub artifact attestations and SLSA provenance.

Two properties of the apply hook are deliberate.

**It installs and never uninstalls.** `bundle cleanup` would make an apply
silently remove any app tried from the Setapp GUI before it reached
`packages.toml`. This matches `brew bundle install --no-upgrade`, which also
only adds. Removals are an explicit `setapp-cli remove` after the entry leaves
`packages.toml`.

**It is `run_after_`, not `run_onchange_`.** The XPC service only answers once
Setapp is installed, loaded, and signed in, and none of that holds on a fresh
Mac where the cask lands long before anyone logs into Setapp. So the hook warns
and exits 0 on a missing prerequisite rather than failing the apply — and
chezmoi records a `run_onchange_` script's state whenever it exits 0, so a
skipped run would never retry until `packages.toml` changed again. `bundle
install` skips apps that are already present and returns in well under a second
once converged, which makes re-running every apply the cheaper correctness.

## Consequences

- A rebuilt Mac restores the Setapp apps, and the standing rule against managed
  config for a Setapp app is lifted for any app listed in `setapp_apps`.
- `packages.toml` is the single place a desktop app is declared, whether it
  comes from Homebrew, the Mac App Store, or the Setapp subscription.
- Names must match the Setapp catalogue exactly, including version suffixes
  (`Bartender 5`). A typo surfaces as a per-app failure from setapp-cli, not a
  render error, because only Setapp's database knows the catalogue.
- The install path depends on an unofficial tool riding an undocumented XPC
  interface. A Setapp client update can break it. The blast radius is bounded:
  the hook already tolerates failure, so a break degrades to the status quo of
  installing Setapp apps by hand.
- Setapp login stays manual and interactive. It is the one step of a fresh-Mac
  desktop rebuild this cannot automate.

## Alternatives considered

- **A committed AppList file** (`~/.setapp/AppList` through chezmoi). Simpler,
  and it is setapp-cli's native format — but it sits outside the machine-type
  group model, so a work Mac and a personal Mac could not differ.
- **Leave Setapp apps unmanaged.** The status quo. Rejected: it makes
  `packages.toml` an incomplete description of the desktop, which is exactly the
  failure a fresh-Mac rebuild exposes.
- **Replace Setapp apps with Homebrew equivalents where they exist.** Changes
  which apps are run to suit the tooling, and forfeits the subscription.
