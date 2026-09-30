# Dotfiles

The machines Prateek's dotfiles configure, and the vocabulary for how a machine's behavior is chosen and owned.

## Language

**Machine type**:
The single identity choice a machine makes when it first adopts the dotfiles; it selects which behavior layer applies and declares the OS the machine runs.
_Avoid_: profile, role, flavor

**Allowlist profile**:
A machine whose managed state is an explicit allowlist: the dotfiles ignore every target and script except the paths it names. The devbox uses one.
_Avoid_: minimal profile, restricted mode

**Devbox**:
Prateek's personal Linux Cloud Workstation, provisioned by DAYJOB's tooling, and the machine type it runs.
_Avoid_: devpod, DevPod, workstation (for the machine itself)

**Cloud Workstation**:
Google's hosted platform the devbox runs on; use it only when meaning the platform, not the machine.

## Devbox lifecycle

**Bootstrap**:
DAYJOB's full setup run for a devbox; it runs on first creation and whenever a resume or config push re-runs it, not on a plain stop/start.
_Avoid_: setup, provision

**Boot hook**:
DAYJOB's per-boot run that restores what a stop/start discards outside `/home`.
_Avoid_: bootstrap, startup script

**Onstart hook**:
Prateek's own script that the bootstrap and the boot hook hand control to last; the only place the devbox lifecycle calls into the dotfiles.
_Avoid_: user hook, startup hook

## Work overlay

**Work overlay**:
DAYJOB-specific agent docs and plugins, kept in Prateek's user directory in the work repo and cloned sparsely onto work machines.
_Avoid_: private overlay, dotfiles-private

**Overlay marketplace**:
The plugin marketplace the work overlay publishes beside prateek-local; hand-maintained, with no activation policy, so every plugin it lists is enabled for the clients whose catalog lists it.
