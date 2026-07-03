---
status: accepted
doc_type: adr
created: 2026-07-03
owner: Prateek
related:
  - ../plans/tartelet-runner-plan.md
  - 0004-tart-install-validation-and-tracing.md
  - 0010-machine-type-package-selection.md
  - 0012-config-gating-convention.md
status_detail: "Decision in force and implemented; a runner is registered and verified live on m4mini. Current mechanism (defaults-based settings) lives in the plan and runbook; this record is the decision as accepted."
---

# ADR 0014 - Tartelet self-hosted runners on homelab minis

## Context

The homelab Mac minis already carry the host toolchain for Apple builds. The
`homelab` machine type resolves to the `apple-development` group, which installs
Tart, `xcodes`, Xcode, `fastlane`, `xcodegen`, and the rest; `machines.host.m4mini`
already points `TART_HOME` at an external SSD so VM disks stay off the boot
volume. ADR 0004 established Tart as the local disposable-VM lane and explicitly
left promoting it into a self-hosted CI runner as future work.

We want those minis to run ephemeral iOS/macOS GitHub Actions runners:
per-job clean macOS VMs, registered and torn down automatically, so CI for
Apple projects stops depending on GitHub-hosted macOS minutes.

[Tartelet](https://github.com/framna-dk/tartelet) is a menu-bar app that
orchestrates exactly this on top of Tart. It is the least-effort path to the
ephemeral-runner lifecycle, but its configuration model fights automation:

- No headless, CLI, env-var, or config-file setup path. Configuration is a GUI.
- Non-secret settings persist to UserDefaults (`dk.shape.Tartelet.plist`); the
  keys are undocumented and can shift between releases.
- The GitHub App private key lives in the macOS keychain (access group
  `566MC7D8D4.dk.shape.Tartelet`), written by the app itself.
- Apple's Virtualization framework caps concurrent macOS VMs at two per host (as
  Tartelet's own docs state), so a mini yields at most two parallel runner slots.

So the host side is a clean fit for the repo's existing mechanisms, but the
app's own config is GUI-first and partly opaque.

## Decision

Adopt Tartelet as the self-hosted runner host on homelab minis, and automate as
much of the setup as the dotfiles mechanisms cleanly reach — up to and including
best-effort pre-seeding of Tartelet's own state and launch-at-login — while
keeping the genuinely one-time, account-level steps as a documented manual pass.

Specific decisions:

- **Install via the existing package machinery.** `tartelet` is a Homebrew cask.
  It enters the `homelab-overlay` group (the existing `homelab-admin` group
  renamed and broadened) — one homelab overlay for homelab-specific packages
  rather than a new group per ADR 0010. No bespoke installer.
- **Provision the runner VM image with a repo-owned script**, not by hand. A
  `run_onchange` script clones a cirruslabs Xcode base image into a named golden
  VM and provisions Xcode selection, the WWDR certificate, and build tooling,
  pinned by the same `ios-triple.json` the Xcode script already uses. This reuses
  `scripts/vm/lib.sh` and the `TART_HOME` boot-disk guard from ADR 0004.
- **Enter credentials once through the UI, from 1Password.** The GitHub App ID,
  org/owner/repo, the App private key, and the guest SSH login all live in the
  keychain access group `566MC7D8D4.dk.shape.Tartelet`, which is entitlement-gated
  to Framna's signing team. A `security`-CLI item lands in a different group and
  the app never reads it, so keychain pre-seed is infeasible without Framna's
  identity. 1Password holds these secrets for a one-time paste; `chezmoi apply`
  does not inject them.
- **Pre-seed only the non-secret settings** (VM name/count, start-on-launch,
  runner labels/name/group, scope, tart-home) through a managed
  `dk.shape.Tartelet.plist` fragment. The keys come from Tartelet source; they can
  drift on a major upgrade, mitigated by dry-run validation and a recorded
  `ask src` re-derivation command.
- **Start runners unattended.** Tartelet exposes a `startVirtualMachinesOnLaunch`
  setting, so the managed plist plus a login LaunchAgent gives login → running
  runners with no UI scripting. The LaunchAgent is a new launchd surface for the
  repo, introduced narrowly and gated to machines that run Tartelet.
- **Keep account-level and credential setup manual and documented.** Creating the
  GitHub App (org-level, once) and the first-run credential paste stay in a
  runbook, not in `chezmoi apply`.
- **Non-secret runner identity is host data.** VM name, VM count, labels, and
  scope live in a `machines.host.<hostname>` layer (or a dedicated data file),
  resolved at apply time like every other host fact. The secret identity fields
  (org, App ID) are keychain-only and never enter repo data.

## Alternatives considered

- **Raw Tart plus cirruslabs' runner scripts, no Tartelet.** Fully scriptable and
  headless, no GUI or opaque keychain state. Rejected for now because it means
  owning the whole clone/register/teardown loop ourselves; Tartelet gives that
  loop for free, and the GUI cost is a bounded one-time pass. Revisit if
  Tartelet's opacity causes upgrade churn.
- **GitHub-hosted macOS runners.** No host to manage, but slower, metered, and
  the reason we have the minis. Not mutually exclusive; this ADR is about the
  self-hosted lane.
- **MDM-pushed configuration profile for Tartelet.** Overkill for a personal
  homelab and does not solve the keychain-key delivery.

## Consequences

- The homelab minis gain a standing service surface. `chezmoi apply` now installs
  an app, provisions a multi-GB VM image, delivers a credential, and registers a
  login agent — heavier and more stateful than prior config-only applies.
- The one brittle moving part is the managed plist: its keys come from Tartelet
  source and match the current release, but a future version could rename them. A
  recorded `ask src` re-derivation command keeps a bump to a quick recheck, and a
  drifted key degrades to a wrong-but-harmless preference, not a broken apply.
- The credential half is a hard manual boundary, not a brittleness — the keychain
  access group is entitlement-gated, so first-run GUI entry is inherent, not a gap
  we might later close.
- The Virtualization-framework two-VM ceiling is a hard cap on parallelism per
  mini; scaling means more hosts, not more VMs.
- We take on golden-image maintenance: Xcode and runtime pins drift, and the
  image must be rebuilt to match `ios-triple.json`.
