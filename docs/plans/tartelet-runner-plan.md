---
status: active
doc_type: plan
owner: Prateek
created: 2026-07-03
updated: 2026-07-03
related:
  - ../adr/0014-tartelet-self-hosted-runners.md
  - ../adr/0004-tart-install-validation-and-tracing.md
  - ../runbooks/tartelet-runner-setup.md
  - ../runbooks/tart-mini-validation.md
status_detail: "Landed and verified live on m4mini: cask, defaults settings, LaunchAgent, host facts, golden VM builder, verify check, runbook, and softnet LAN isolation via the tart wrapper (a GitHub Actions job runs on the isolated runner with the LAN blocked). Remaining: fresh-mini reproducibility, and retiring the wrapper once tart run flags can be passed without it."
---

# Tartelet Self-Hosted Runner Plan

Automate, through this repo, standing up a homelab Mac mini as an ephemeral
iOS/macOS GitHub Actions runner host with [Tartelet](https://github.com/framna-dk/tartelet).
The decision and its rationale live in [ADR 0014](../adr/0014-tartelet-self-hosted-runners.md).

## Goal

After `chezmoi apply` on a `homelab` mini plus one documented manual pass, the
mini installs Tartelet, holds a provisioned golden runner VM, has its non-secret
Tartelet settings pre-seeded (including start-VMs-on-launch), and starts
registering ephemeral runners at login. The credentials themselves — GitHub App
ID, org/owner/repo, the App private key, and the guest SSH login — are entered
once through Tartelet's UI, because Tartelet stores them in a code-signed
keychain access group that a script cannot write to (see the persistence model
below). 1Password is where those secrets live for that one-time paste, not a
channel `chezmoi apply` injects through.

## Non-goals

- Replacing GitHub-hosted runners everywhere. This is the self-hosted lane, not a
  mandate.
- Owning the clone/register/teardown loop ourselves. Tartelet owns it; see the
  alternatives in ADR 0014.
- More than two parallel runners per mini. Apple's Virtualization framework caps
  concurrent macOS VMs at two per host; that is a platform limit, not a knob.

## The automation boundary

| Piece | How | Tier |
| --- | --- | --- |
| Install Tartelet | `tartelet` cask in the `homelab-overlay` overlay group | Automated |
| Host build toolchain | In `apple-development` (Tart, xcodes, fastlane); Xcode.app itself via the gated interactive script | Mostly done |
| Golden runner VM image | `run_onchange` provisioning script over cirruslabs Xcode base (Xcode already baked in) | Automated |
| Non-secret Tartelet settings (VM name/count, start-on-launch, labels, scope, tart home) | Applied via `defaults` (cfprefsd-safe), keys from source | Automated |
| Start VMs on launch | `startVirtualMachinesOnLaunch=true` in the managed settings + a LaunchAgent | Automated |
| GitHub App creation | Org-level, once, on github.com | Manual (runbook) |
| Credentials into keychain (App ID, org/owner/repo, private key, SSH login) | Paste from 1Password into Tartelet's UI on first run | Manual (runbook) — not scriptable |

## Tartelet's persistence model

Tartelet's configuration splits across two stores, taken from its source
(`AppStorageSettingsStore.swift`, `KeychainGitHubCredentialsStore.swift`,
`Composers.swift`, `Tartelet.entitlements`; re-derive with
`ask src github:framna-dk/tartelet`). The phases below depend on this split, and
the runbook carries the same map and the re-derivation command, since these keys
can shift on a Tartelet upgrade.

**UserDefaults** — domain `dk.shape.Tartelet`, plain
`~/Library/Preferences/dk.shape.Tartelet.plist` (the app is not sandboxed).
Manageable by us. Exact keys: `virtualMachine` (VM name), `numberOfVirtualMachines`
(Int, default 1), `startVirtualMachinesOnLaunch` (Bool), `gitHubRunnerLabels`
(default `tartelet`), `gitHubRunnerName`, `gitHubRunnerGroup`,
`gitHubRunnerDisableDefaultLabels`, `gitHubRunnerDisableUpdates`,
`githubRunnerScope` (enum `organization`/`repo`), `tartHomeFolderURL`,
`applicationUIMode`, `gitHubPrivateKeyName` (the key's *name*, not its bytes).

**Keychain** — everything secret, under the hardcoded access group
`566MC7D8D4.dk.shape.Tartelet` (`Composers.swift:97`). GitHub identity is a
generic password per field (accounts `github.credentials.organizationName`,
`repositoryName`, `ownerName`, `appId`); the App private key is a `SecKey` under
tag `github.credentials.privateKey`; the guest SSH login lives in a parallel
`KeychainVirtualMachineSSHCredentialsStore`.

**Why the keychain half is not scriptable.** That access group is gated by the
`keychain-access-groups` entitlement, which only a binary code-signed by team
`566MC7D8D4` can claim. The `security` CLI is signed by Apple, so items it
creates land in a different group and Tartelet's queries never see them. There
is no team-signed helper we can ship. So the credential half is inherently a
GUI-entry step; only the UserDefaults half is dotfiles-managed.

**No headless bootstrap path.** Tartelet parses no launch arguments, reads no
config file, registers no URL scheme, and installs no privileged helper (no
`SMAppService` / `SMJobBless` / `AuthorizationRef` — it is a non-sandboxed app
that calls Virtualization.framework directly, so its privileges are simply the
running user's). The one environment variable it reads is
`TARTELET_RUN_OPTIONS` (`Tart.swift:31`), whose value is appended verbatim to
`tart run` — extra VM run flags (networking, mounts), not app config or
credentials. So there is genuinely no seam to bootstrap privileges or the keychain
headlessly; the only useful hook is passing `TARTELET_RUN_OPTIONS` through the
LaunchAgent environment when the runner VMs need specific `tart run` flags.

## Phases

### 1. Package install

- Rename the existing `homelab-admin` group to `homelab-overlay` in
  `home/.chezmoidata/packages.toml` and broaden its description to "homelab-specific
  packages" — one homelab overlay rather than one group per concern. Update the
  reference in the `homelab` type's `groups` list in
  `home/.chezmoidata/machines.toml`, and the two `homelab-admin` mentions in
  `docs/references/chezmoi-architecture.md`, in the same change.
- Add the `tartelet` cask to that `homelab-overlay` group.
- Gate any Tartelet-adjacent config in `home/.chezmoiignore` on
  `package-cask-enabled.tmpl name=tartelet`, so nothing renders on machines that
  do not install it.

### 2. Golden runner VM image

- Add `scripts/vm/build-runner-image.sh` and a
  `run_onchange_after_16-tartelet-runner.sh.tmpl` that:
  - short-circuits unless the host resolves the `apple-development` group and is a
    designated runner host (host data, see phase 4);
  - clones `ghcr.io/cirruslabs/macos-tahoe-xcode` into a named `tartelet-runner`
    VM under `TART_HOME`, using the boot-disk guard from `scripts/vm/lib.sh`. The
    cirruslabs `*-xcode` images already ship Xcode preinstalled, so the guest
    needs no interactive `xcodes install` / Apple ID download;
  - provisions inside the guest: `xcodes select` among the versions the image
    already carries (or pick the image tag whose Xcode matches the pin), the Apple
    WWDR G3 certificate, and any required build tooling;
  - is idempotent — skip the clone when the golden VM already matches the pin.
- Settle the guest SSH account here, not in phase 5. The cirruslabs base images
  ship a single `admin`/`admin` login; Tartelet SSHes in with whatever credentials
  it is configured with. Either keep `admin`/`admin` end to end, or have this
  script create a dedicated `runner` user in the golden image. Whichever it is,
  phase 5 must configure the same pair — the two phases share one source of truth.
- Reuse the `ios-triple.json` sha in the script header so the image rebuilds when
  the Xcode pin moves, matching `run_onchange_after_15-xcode.sh`.

### 3. Credential delivery (manual, via 1Password)

The persistence model rules out scripting this: the GitHub App ID, org/owner/repo,
the private key, and the guest SSH login all live in Tartelet's code-signed
keychain access group. So there is no `secrets.toml` ref, no `onepasswordRead` at
apply time, and no `security add-generic-password` step — a CLI-created item would
land in the wrong access group and Tartelet would never read it.

- Store the GitHub App private key and the identity fields in 1Password (a single
  item is fine). The runbook records the item and field layout.
- On first run, the operator pastes them into Tartelet's GitHub settings pane. The
  app writes them to its keychain group itself.
- Nothing here touches the repo; no `.pem` on disk after entry.

### 4. Runner identity as host data

These are the *non-secret* per-host facts that parameterize the settings script in
phase 5 — the same mechanism as `machines.host.m4mini.tart_home`
(`machines.toml:60`), resolved at apply time by `features.tmpl`. They are the
values that live in UserDefaults, not the keychain ones (org/App ID stay GUI-only).

- Add to the `homelab` machine-type layer (or a host layer): `runner_vm_name`
  (the golden VM from phase 2), `runner_vm_count` (1 or 2), `runner_labels`,
  `runner_scope` (`organization`/`repo`), and `runner_start_on_launch` (bool).
- The settings script (phase 5) reads these; the VM-image script (phase 2) reads
  `runner_vm_name`. `tartHomeFolderURL` comes from the same `tart_home` host fact.

### 5. Non-secret settings via `defaults`

Apply the UserDefaults keys through `defaults`, not a plist file write. A direct
file write is silently reverted once Tartelet has run: `cfprefsd` owns the domain
and the app rewrites the file from its cache on next launch (observed on m4mini —
scope and VM count reverted). `defaults` is the cfprefsd-authoritative path.

- `run_onchange_after_17-tartelet-settings.sh` writes only the UserDefaults keys
  enumerated in the persistence model — `virtualMachine`, `numberOfVirtualMachines`,
  `startVirtualMachinesOnLaunch`, `gitHubRunnerLabels`, `githubRunnerScope` — plus
  `tartHomeFolderURL` set to the host's `tart_home` (so Tartelet finds the golden
  VM on the external SSD, not `~/.tart`). Values come from phase-4 host facts.
- It diffs current-vs-desired first and only acts on a change, and quits Tartelet
  before writing so the values are authoritative, relaunching it afterwards.
- Template-gate the whole block on the tartelet cask: the `runner_*` facts do not
  exist on other machine types, so referencing them there fails template render.
- No credentials, no SSH login, no App ID here — those are keychain-only (phase 3).
- The key names can shift on a Tartelet upgrade. Validate on
  `chezmoi apply --dry-run`; the runbook carries the `ask src` re-derivation
  command so a version bump is a quick recheck.

### 6. Start runners at login

- Set `startVirtualMachinesOnLaunch=true` in the managed settings (phase 5) so
  Tartelet boots its VMs and registers runners the moment it launches — no
  menu-bar click, no UI scripting.
- Add a gated LaunchAgent under `home/Library/LaunchAgents/` that launches
  Tartelet at login on runner hosts only. This is the repo's first launchd surface;
  keep it minimal and gated on the cask being present. Together with the plist key,
  login → running runners is unattended.
- Isolate runner guests from the homelab LAN with softnet. `tart run --net-softnet`
  keeps internet egress via the vmnet gateway (runners register, builds fetch deps)
  but drops the guest onto its own subnet with the LAN denied. `softnet` ships as a
  `tart` dependency.

  Tartelet cannot pass this flag — it drives `tart run` at a fixed path,
  `/opt/homebrew/bin/tart`, with no flag hook. So a wrapper at that path
  (`home/.chezmoiassets/tart-softnet-wrapper.sh`, installed by
  `run_after_18-tartelet-tart-softnet-wrapper`) forwards to the real tart and adds
  `--net-softnet`. The wrapper prepends the brew bin to `PATH` so tart can find
  `softnet`, and reinstalls on every apply since `brew upgrade tart` restores the
  plain symlink. softnet needs a passwordless-sudo grant, a one-time
  `/etc/sudoers.d` drop-in per host (runbook). Widen access with
  `--net-softnet-allow=<cidr>`; never revert to NAT. The wrapper is a stopgap — see
  the migration item under Open questions and risks.

### 7. Runbook and validation

- Write `docs/runbooks/tartelet-runner-setup.md`: create the GitHub App, store its
  key + identity fields in 1Password, set the host data, run apply, do the
  first-run GUI paste, verify the runner appears in GitHub. Include the persistence
  map above and the `ask src github:framna-dk/tartelet` re-derivation command so
  the plist keys can be re-checked on a Tartelet upgrade.
- Add a lightweight doctor/verify check (extend `run_onchange_after_90-verify.sh`
  or the tart lane) that asserts: cask installed, golden VM present, LaunchAgent
  loaded, and the managed settings present (via `defaults read`). It cannot assert the keychain items
  (different access group, not CLI-readable) — verify those by confirming the
  runner registered in GitHub.
- Update `docs/index.md` and this plan's status as phases land.

## Open questions and risks

- **Plist keys can drift on upgrade.** Phase 5's keys come from Tartelet source, so
  they match the current release, but a future version could rename them.
  Mitigation: dry-run validation plus the `ask src` re-derivation command in the
  runbook.
- **Keychain pre-seed is not possible.** The access group
  `566MC7D8D4.dk.shape.Tartelet` is entitlement-gated to Framna's signing team, so
  a `security`-CLI item is unreadable by the app. Credentials are GUI-entered by
  design; there is no fallback that makes this scriptable without Framna's identity.
- **Two-VM framework cap.** `runner_vm_count` must stay ≤ 2. More parallelism
  means more hosts.
- **Golden-image drift.** The image must be rebuilt when the Xcode pin moves;
  phase 2 keys the rebuild off the `ios-triple.json` sha.
- **The tart wrapper is a stopgap; migrate off it.** It owns `/opt/homebrew/bin/tart`
  and injects softnet into every `tart run` on the host — fine for a dedicated
  runner mini, but a global override that `brew upgrade tart` resets (hence the
  every-apply reinstall). Retire it by landing `TARTELET_RUN_OPTIONS` support in a
  Tartelet release (then set the env var in the LaunchAgent and delete the wrapper),
  or by moving the host to Ekiden or Orchard, which pass `tart run` flags natively.
  A local from-source Tartelet build is not a path: it loses the vendor-signed
  keychain access group that holds the runner credentials.
- **softnet coexists with Tartelet's guest control.** softnet isolates the guest's
  outbound traffic; Tartelet still reaches into the guest over SSH and the guest
  still registers to GitHub. If a future softnet or Tart release regresses this,
  widen the guest subnet with `--net-softnet-allow=<cidr>` rather than reverting to
  NAT.
- **Deviation from Tartelet's host-account model.** Tartelet's own setup guide
  runs the app under a dedicated auto-login non-admin "runner" *host* user with a
  hardening checklist (no sleep, no auto-update, scoped sudoers). This plan's
  launch-at-login assumes the normal login user and does not stand up that
  dedicated account. Acceptable for a homelab, but call it out so the simplification
  is a choice, not an oversight. Do not conflate this host user with the phase-2
  *guest* SSH account.

## Validation strategy

- Per phase: `chezmoi diff` / `--dry-run` on a `homelab` render, and the existing
  package-render and cask-gate checks.
- End to end on a real mini: run apply, launch Tartelet, push a trivial workflow
  targeting the runner labels, confirm a job runs in an ephemeral VM and the VM is
  torn down after.
- Keep CI lightweight per ADR 0004 — no VM boot in CI; the end-to-end proof is
  local on the mini.

## References

- [ADR 0014 - Tartelet self-hosted runners](../adr/0014-tartelet-self-hosted-runners.md)
- [ADR 0004 - Tart install validation and tracing](../adr/0004-tart-install-validation-and-tracing.md)
- [Tart Install Validation runbook](../runbooks/tart-mini-validation.md)
- [Tartelet wiki](https://github.com/framna-dk/tartelet/wiki)
