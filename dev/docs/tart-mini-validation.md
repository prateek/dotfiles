# Tart mini validation

Status: current
Related ADR: `dev/adr/0002-zsh-fresh-shell-validator.md`

This is the current end-to-end install validation lane for this repo. It is one validation path, not the whole test strategy. Today it gives us a disposable macOS guest, a real `install.sh --core` run, and the same fresh-shell postflight checks we trust on the host.

The current target is a Tart VM launched on `mini` over SSH. The VM storage lives on the external APFS volume at `/Volumes/Extra`, with Tart state under `/Volumes/Extra/.tart`. A future version may move this into a self-hosted GitHub Actions runner, a pinned base image, or a fuller wrapper script that owns preflight, sync, execution, postflight, and cleanup.

## Current implementation

- VM runner: `scripts/vm/test-install-tart.sh`
- Contract test: `tests/tart-install-helper-contract.zsh`
- Make targets: `test-tart-install-helper`, `test-install-tart-dry-run`, `test-install-tart-smoke`, `test-install-tart-full`
- Guest shell oracle: `scripts/audit/zsh-fresh-shells.zsh verify`

`scripts/vm/test-install-tart.sh` owns the Tart lifecycle:

1. clone the configured image
2. set VM CPU and memory
3. run headless with the repo mounted read-only
4. copy the repo into the guest home
5. run `install.sh`
6. run postflight checks
7. delete the VM unless `--keep-vm` is set

## What this proves

- the default Tart image can boot on the validation host
- the repo can be copied into a clean macOS guest
- `install.sh --core` can run against a real macOS install
- smoke-lane Homebrew casks and Mac App Store entries are skipped
- core tools are installed
- `scripts/audit/zsh-fresh-shells.zsh verify` passes after bootstrap
- the VM is deleted after the run unless debugging keeps it

## What this does not prove

- full cask or GUI app install behavior
- Mac App Store install behavior
- every personal secret, local credential, or API-dependent tool path
- that the floating `latest` Tart image tag will behave the same tomorrow
- that this lane is ready to replace CI

## Lanes and Modes

The helper exposes lanes only. The install profile is derived internally from the lane.

`smoke` is the default lane. It uses the Tahoe base image, the core profile, explicit Homebrew cask/MAS skip lists, and fresh-shell postflight verification.

`full` is explicit and slower. It uses the full profile and includes cask/MAS behavior.

Dry-run is a mode layered on top of the smoke lane. `make test-install-tart-dry-run` boots Tart and runs `install.sh --core --dry-run`; it can continue past missing Xcode Command Line Tools because the point is to validate the script path, not install tools.

## Host assumptions

Before using `mini` as the target, verify:

```sh
ssh mini 'uname -m && sw_vers'
ssh mini 'command -v tart && tart --version'
ssh mini 'mount | grep " /Volumes/Extra "'
ssh mini 'df -h /Volumes/Extra'
ssh mini 'TART_HOME=/Volumes/Extra/.tart tart list --source local --format json'
```

Expected shape:

- Apple Silicon host
- Tart installed
- `/Volumes/Extra` mounted as APFS
- Tart home at `/Volumes/Extra/.tart`
- at least 100 GiB free for smoke runs
- no unrelated local Tart VM using the planned test name

The known-good host as of 2026-04-26 is `mini`: Apple Silicon M4, macOS 26.4.1, about 16 GB RAM, Tart 2.32.1, and the external APFS drive mounted at `/Volumes/Extra`.

The default VM shape is 2 CPU and 4096 MB RAM. For tighter runs, use 1 CPU and 3072 MB RAM.

The 100 GiB floor is conservative for cached smoke runs. First image pulls and full-lane experiments need more headroom. Run one VM at a time unless the host budget is remeasured.

## Run the smoke lane

From the repo checkout on your laptop:

```sh
make test-tart-install-helper
make test-zsh-fresh-shells

rsync -a --delete --exclude .git ./ mini:/Volumes/Extra/dotfiles-tart-test/

ssh mini 'set -euo pipefail
  cd /Volumes/Extra/dotfiles-tart-test
  export TART_HOME=/Volumes/Extra/.tart
  export LOG_FILE=/Volumes/Extra/dotfiles-tart-smoke.log
  export DOTFILES_TART_TRACE_FILE=/Volumes/Extra/dotfiles-tart-smoke.trace.json
  vm_name="dotfiles-tart-smoke-$(date +%Y%m%d-%H%M%S)"
  make test-install-tart-smoke TART_FLAGS="--vm-name $vm_name"'
```

The run should end with:

```text
SUMMARY|verify|passed=<count>|failed=0|info=<count>
Install finished successfully.
```

Afterward, confirm cleanup:

```sh
ssh mini 'TART_HOME=/Volumes/Extra/.tart tart list --source local --format json'
```

An empty JSON list means no local Tart VMs are left behind.

When `DOTFILES_TART_TRACE_FILE` is set, the helper writes a Chrome/Perfetto-compatible trace for Tart lifecycle phases. It also asks `bootstrap.sh` to write a guest-side trace and copies that next to the Tart trace with `.bootstrap.json` before deleting the VM. The helper also scans the captured install log for macOS command failures that older defaults scripts can hide.

## Extending this lane

The useful split is:

- preflight host checks: SSH, APFS volume, Tart install, free space, image state
- VM runner: clone, configure, boot, mount repo, run install, cleanup
- guest postflight: tools, symlinks, shell verifier, future bootstrap assertions
- convenience wrapper: local checks, rsync, remote run, cleanup assertion, log path

`scripts/vm/test-install-tart.sh` owns the VM runner today. As we add more guest assertions, prefer moving postflight checks into a separate script instead of turning the runner into a long checklist.

Open follow-ups:

- decide whether to pin the Tart image by digest once the floating Tahoe tag becomes noisy
- decide whether to prebuild a repo-owned base image with common dependencies
- decide whether fresh-shell benchmarking belongs in Tart or stays host-only because VM timing is noisy
