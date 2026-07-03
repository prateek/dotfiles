---
status: active
doc_type: runbook
owner: Prateek
created: 2026-07-03
updated: 2026-07-03
related:
  - ../plans/tartelet-runner-plan.md
  - ../adr/0014-tartelet-self-hosted-runners.md
  - tart-mini-validation.md
---

# Tartelet Runner Setup

Bring up a homelab Mac mini as an ephemeral iOS/macOS GitHub Actions runner host.
`chezmoi apply` handles the app, its non-secret settings, the login agent, and the
verify checks; this runbook covers the parts that cannot be automated: the GitHub
App, the golden VM build, and the one-time credential entry. Design and rationale
are in [ADR 0014](../adr/0014-tartelet-self-hosted-runners.md) and the
[runner plan](../plans/tartelet-runner-plan.md).

## What apply already did

On a `homelab` machine, `chezmoi apply` installs the `tartelet` cask, applies the
non-secret settings via `defaults` (VM name, count, start-on-launch, labels,
scope, and `tartHomeFolderURL` → the host's `TART_HOME`), and installs the login
LaunchAgent `~/Library/LaunchAgents/com.prateek.tartelet-runner.plist`. The runner
facts come from the `homelab` layer in `home/.chezmoidata/machines.toml`
(`runner_vm_name`, `runner_vm_count`, `runner_labels`, `runner_scope`,
`runner_start_on_launch`).

Settings go through `defaults`, not a plist file write, on purpose: once Tartelet
has run, `cfprefsd` owns the domain and a direct file write is reverted on the
app's next launch. `run_onchange_after_17-tartelet-settings.sh` diffs before
writing, quits Tartelet to apply, and relaunches — so it only disrupts a running
runner when a value actually changes.

Everything below is manual because Tartelet stores it in a code-signed keychain
access group or outside dotfiles entirely.

## 1. Create the GitHub App (once per org/account)

On github.com, create a GitHub App and grant it self-hosted-runner registration:

- **Organization runners** (`runner_scope = "organization"`): permission
  `Organization → Self-hosted runners: Read and write`.
- **Repository runners** (`runner_scope = "repo"`): permissions
  `Repository → Administration: Read and write` and `Metadata: Read-only`.

Install the App on the org (or repo), then note the **App ID** and generate a
**private key** (`.pem`).

Set `runner_scope` in `machines.toml` to match the App's scope before applying.

## 2. Store the credentials in 1Password

Put the App private key and identity fields in a single 1Password item, for
example fields: `app_id`, `owner` (org or account login), `repo` (repo scope
only), and the `.pem` as a document/field. These are pasted into Tartelet's UI in
step 5; they are never read by `chezmoi apply`.

## 3. Build the golden runner VM

On the mini, with the external SSD mounted (so `TART_HOME` is off the boot disk):

```sh
DOTFILES_BUILD_TARTELET_IMAGE=true chezmoi apply   # or run the builder directly:
scripts/vm/build-runner-image.sh
```

This clones `ghcr.io/cirruslabs/macos-tahoe-xcode`, selects the Xcode pinned in
`~/.agents/state/ios-triple.json`, and shuts the VM down. It is idempotent: it
rebuilds only when the pin changes or you pass `--force`. The cirruslabs image
ships Xcode and logs in as `admin`/`admin`, so configure Tartelet's guest SSH
credentials as `admin`/`admin` (step 5) — there is no separate runner user.

## 4. Launch Tartelet

The LaunchAgent starts Tartelet at the next login. To start it now:

```sh
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.prateek.tartelet-runner.plist
```

## 5. Enter credentials in the UI (one time)

Open Tartelet → Settings:

- **GitHub pane**: select the runner scope, enter owner/account (and repo for
  repo scope), the App ID, and select the private-key file from step 2. Tartelet
  writes these to its keychain; delete the `.pem` from disk afterward.
- **Virtual Machine pane**: confirm the VM is `tartelet-runner` and the SSH
  credentials are `admin`/`admin`.

The VM selection, count, labels, scope, and start-on-launch are already set by the
managed settings, so they should read back correctly.

## 6. Verify

- The runner appears under the org/repo's GitHub → Settings → Actions → Runners.
- `chezmoi apply` verify (step 90) reports the app, LaunchAgent, and managed settings
  present, and whether the golden VM exists.
- Push a trivial workflow targeting the runner labels (`tartelet,homelab`) and
  confirm a job runs in a fresh VM that is torn down afterward.

## Tartelet persistence map (for upgrades)

The managed setting keys are read from Tartelet source. On a Tartelet upgrade,
re-derive them before trusting the script:

```sh
ask src github:framna-dk/tartelet
# key names:   Packages/Settings/Sources/SettingsData/AppStorageSettingsStore.swift
# raw values:  Packages/GitHub/Sources/GitHubDomain/GitHubRunnerScope.swift
#              Packages/Settings/Sources/SettingsDomain/VirtualMachine.swift
```

Verified encodings (as applied by `home/.chezmoiscripts/run_onchange_after_17-tartelet-settings.sh.tmpl`):

| Key | Type | Encoding |
| --- | --- | --- |
| `virtualMachine` | String | `virtualMachine=<vm name>` |
| `numberOfVirtualMachines` | Integer | 1 or 2 (Apple caps concurrent macOS VMs at 2) |
| `startVirtualMachinesOnLaunch` | Bool | — |
| `gitHubRunnerLabels` | String | comma-separated |
| `githubRunnerScope` | String | `organization` or `repo` |
| `tartHomeFolderURL` | String | host `TART_HOME` path, so Tartelet finds the golden VM |

Credentials (`github.credentials.*` and the private key) live in keychain access
group `566MC7D8D4.dk.shape.Tartelet`, which is entitlement-gated to Framna's
signing team, so they cannot be pre-seeded from a script.
