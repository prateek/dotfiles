---
status: active
doc_type: runbook
owner: Prateek
created: 2026-07-03
updated: 2026-09-05
related:
  - ../plans/tartelet-runner-plan.md
  - ../adr/0014-tartelet-self-hosted-runners.md
  - tart-mini-validation.md
---

# Tartelet Runner Setup

Set up a homelab Mac mini to run ephemeral iOS/macOS GitHub Actions jobs.

## What chezmoi manages

On a `homelab` machine, `chezmoi apply` installs Tartelet, its login LaunchAgent,
and the softnet wrapper. It applies non-secret settings from
[machine data](../../home/.chezmoidata/machines.toml). Read the resolved `runner_*`
and `tart_home` values for this host before setup;
[the resolver](../../home/.chezmoitemplates/features.tmpl) includes host and
`machines_local` overrides.

The [settings hook](../../home/.chezmoiscripts/run_onchange_after_17-tartelet-settings.sh.tmpl)
uses `defaults` because `cfprefsd` reverts direct plist writes after Tartelet has
run. Changed settings restart a running Tartelet and interrupt its active job.

## 1. Create the GitHub App (once per org/account)

On github.com, create a GitHub App and grant it self-hosted-runner registration:

- **Organization runners** (`runner_scope = "organization"`): permission
  `Organization → Self-hosted runners: Read and write`.
- **Repository runners** (`runner_scope = "repo"`): permissions
  `Repository → Administration: Read and write` and `Metadata: Read-only`.

Install the App on the org (or repo), then note the **App ID** and generate a
**private key** (`.pem`).

Set `runner_scope` to match before applying. Continue once the installed App
shows the required permissions and you have its App ID and private key.

## 2. Store the credentials in 1Password

Store `app_id`, `owner` (org or account login), `repo` (repo scope only), and the
`.pem` in one 1Password item. `chezmoi apply` never reads them. Confirm you can
retrieve each value and the key for step 6.

## 3. Grant softnet passwordless sudo (one time)

The wrapper adds `--net-softnet` to `tart run`, including the builder's VM.
Guests can reach the internet through the vmnet gateway, but cannot reach the
homelab LAN. Re-run `chezmoi apply` after `brew upgrade tart` restores the plain
symlink. For the fixed-path and LaunchAgent `PATH` requirements, see the
[wrapper](../../home/.chezmoiassets/tart-softnet-wrapper.sh) and
[install hook](../../home/.chezmoiscripts/run_after_18-tartelet-tart-softnet-wrapper.sh.tmpl).

`softnet` is installed as a `tart` dependency. It creates the vmnet interface as
root before dropping privileges. Tartelet's LaunchAgent has no tty, so VM startup
requires passwordless sudo. Grant it for the softnet binary only.

Use `%admin` for the mini's admin login user, or a specific user for a dedicated
runner account:

```sh
softnet_bin="$(command -v softnet)"   # /opt/homebrew/bin/softnet on Apple Silicon
printf '%%admin ALL=(root) NOPASSWD: %s\n' "$softnet_bin" \
  | sudo tee /etc/sudoers.d/tartelet-softnet >/dev/null
sudo chmod 440 /etc/sudoers.d/tartelet-softnet
sudo visudo -c -f /etc/sudoers.d/tartelet-softnet   # must print "parsed OK"
```

In a login shell for the account that runs Tartelet, check access without cached
authentication:

```sh
sudo -k -n /opt/homebrew/bin/softnet --help >/dev/null
```

Continue when the sudoers file parses and this command succeeds.

## 4. Build the golden runner VM

Mount the external SSD and confirm `TART_HOME` points to its VM store. Run the
[builder](../../scripts/vm/build-runner-image.sh) on the mini, substituting the
resolved `runner_vm_name`:

```sh
scripts/vm/build-runner-image.sh --vm-name '<runner_vm_name>'
```

Use the builder directly for an explicit build; the opt-in apply hook can skip
an already-recorded run. The builder reuses an existing VM and skips provisioning
when that VM's marker matches the pin. `--force` requests a fresh clone.
Read `--help` for image and VM options.

The builder selects the Xcode pinned in `~/.agents/state/ios-triple.json` only
when that version is installed. Otherwise it warns and keeps the image's default,
and can still succeed. Before continuing, confirm the golden VM is stopped and
its actual `xcodebuild -version` output matches the intended runner version.

## 5. Launch Tartelet

The LaunchAgent starts Tartelet at the next login. To start it now:

```sh
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.prateek.tartelet-runner.plist
```

Continue when Tartelet is running and its Settings window opens.

## 6. Enter credentials in the UI (one time)

Credentials require UI entry. Tartelet's keychain access group requires Framna's
signing entitlement, so scripts cannot pre-seed them.

Open Tartelet → Settings:

- **GitHub pane**: select the runner scope, enter owner/account (and repo for
  repo scope), the App ID, and select the private-key file from step 2. Tartelet
  writes these to its keychain; delete the `.pem` from disk afterward.
- **Virtual Machine pane**: select the configured golden VM. In the SSH section,
  enter `admin` as both username and password for the builder's cirruslabs image.

Reopen Settings and confirm the VM selection, count, labels, scope, and
start-on-launch match the resolved configuration. Confirm the SSH username is
`admin` and the password remains saved; the job check in step 7 verifies guest
authentication.

## 7. Verify

- Confirm the runner appears under the org/repo's GitHub → Settings → Actions → Runners.
- Check that [apply's verify hook](../../home/.chezmoiscripts/run_onchange_after_90-verify.sh.tmpl)
  reports the app, LaunchAgent, preference file, and golden VM present. These
  checks establish file presence; the UI and job checks establish readiness.
- Push a trivial workflow with `git` over SSH, targeting the configured runner
  labels. Confirm a job runs in a fresh VM. After the job, verify
  Tartelet tears down the VM, replaces it, and registers a fresh runner.
- From the guest, through SSH or a workflow step, confirm
  `curl -fsS --max-time 12 -o /dev/null https://github.com` succeeds. An API can
  reject a request with HTTP 403 even when GitHub HTTPS is reachable.
- Choose a known-open TCP port on a homelab LAN host and confirm it is reachable
  from the mini. From the guest,
  `nc -z -G 3 <a-homelab-LAN-ip> <known-open-port>` must fail.

If the guest can reach that LAN port, check the softnet sudo grant and confirm
`/opt/homebrew/bin/tart` is the wrapper rather than a brew symlink. A
`softnet --vm-fd` process should be running while the guest is up.

Setup is complete when all verification checks pass.

## Upgrade reference

For a Tartelet upgrade, check the keys and encodings in the
[settings hook](../../home/.chezmoiscripts/run_onchange_after_17-tartelet-settings.sh.tmpl)
against Tartelet source using its lookup instructions. For design rationale,
read [ADR 0014](../adr/0014-tartelet-self-hosted-runners.md) and the
[runner plan](../plans/tartelet-runner-plan.md).
