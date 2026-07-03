---
status: current
doc_type: runbook
related:
  - ../adr/0002-zsh-fresh-shell-validator.md
  - ../adr/0004-tart-install-validation-and-tracing.md
---

# Tart install validation

This is the current end-to-end install validation lane for this repo. It is one validation path, not the whole test strategy. Today it gives us a disposable macOS guest, a real chezmoi-bootstrap run for the `ci` (or `personal`) machine type, and the same fresh-shell postflight checks we trust on the host.

The lane runs locally on a Mac mini with a dedicated external SSD. Tart storage lives on that SSD so VM images and disks never fill the boot drive; `TART_HOME` is set from the `machines.host.<hostname>` layer in `home/.chezmoidata/machines.toml` and the helper refuses to run when it would land on the boot volume (see below). A future version may move this into a self-hosted GitHub Actions runner, a pinned base image, or a fuller wrapper script that owns preflight, execution, postflight, and cleanup.

## Current implementation

- VM runner: `scripts/vm/test-install-tart.sh`
- Contract test: `tests/tart-install-helper-contract.zsh`
- Trace tests: `tests/trace-perfetto.zsh`
- Make targets: `test-tart-install-helper`, `test-trace-perfetto`, `test-install-tart-dry-run`, `test-install-tart-smoke`, `test-install-tart-full`
- Guest shell oracle: `scripts/audit/zsh-fresh-shells.zsh verify`

`scripts/vm/test-install-tart.sh` owns the Tart lifecycle:

1. clone the configured image
2. set VM CPU and memory
3. run headless with the repo mounted read-only
4. copy the repo into the guest home
5. download chezmoi via `get.chezmoi.io` and run `chezmoi init --apply --no-tty --promptDefaults --promptChoice 'machine_type=ci' --source ~/dotfiles` (local) or `chezmoi init --apply --no-tty --promptDefaults --promptChoice 'machine_type=ci' prateek` (remote) — the lane derives the type (`ci` for smoke, `personal` for full)
6. run postflight checks
7. delete the VM unless `--keep-vm` is set

When tracing is enabled, the runner also writes a merged Perfetto trace. The host side records Tart lifecycle phases. In local mode, the guest side runs the chezmoi bootstrap under `scripts/trace/run-zsh`, which captures zsh xtrace into private artifacts and converts it to Perfetto JSON. Remote mode records host lifecycle phases only because the install path is intentionally `curl | sh` plus chezmoi's own clone+apply.

Guest trace semantics come from zsh function structure. `run-zsh` records each command with its source file, line, command text, and `funcstack`; `xtrace-to-perfetto` turns that into named semantic tracks plus major-command and all-command tracks. The converter derives readable labels from function names, so installer code does not need Perfetto calls or a separate trace metadata table.

## What this proves

- the configured Tart images can boot on the validation host
- the repo can be copied into a clean macOS guest
- the chezmoi one-liner (selecting the `ci` machine type via `--promptChoice`) can run against a real macOS install
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

The helper exposes lanes only. The machine type is derived internally from the lane.

`smoke` is the default lane. It uses the Tahoe base image, the `ci` machine type, explicit Homebrew cask/MAS skip lists, and fresh-shell postflight verification.

`full` is explicit and slower. It uses the Tahoe Xcode image, the `personal` machine type, and includes cask behavior. The Xcode image keeps routine full-lane validation from spending the run downloading Xcode; the `personal` machine type includes `apple-development`, so it selects and sets up Xcode when it is present, and downloads Xcode through `xcodes` only when it is absent and the apply is interactive or forced with `DOTFILES_INSTALL_XCODE=true`.

Dev machine types run `brew update` before `brew bundle`. Prebuilt Tart images can carry Homebrew metadata that is old enough to misparse current casks.

Mac App Store entries are omitted from generated Brewfiles by default because disposable Tart guests are not signed in to the App Store. Set `DOTFILES_INSTALL_MAS_APPS=true` only on a signed-in machine where MAS installs are intended.

Every Tart run prints a slowest-phase timing summary before cleanup exits. The guest package scripts also emit `TIMING|...` log lines around expensive setup steps, so a slow run can usually be diagnosed from the plain log before opening a Perfetto trace.

Dry-run is a mode layered on top of the smoke lane. `make test-install-tart-dry-run` boots Tart, downloads chezmoi via `get.chezmoi.io`, runs `chezmoi init --promptDefaults --promptChoice 'machine_type=ci' --source ~/dotfiles`, and then `chezmoi apply --dry-run --verbose`; it can continue past missing Xcode Command Line Tools because the point is to validate the bootstrap path, not install tools.

## Host assumptions

On the validation host, verify:

```sh
uname -m && sw_vers
command -v tart && tart --version
mount | grep ' /Volumes/TartVMs '
df -h /Volumes/TartVMs
tart list --source local --format json   # TART_HOME is set automatically; see below
```

Expected shape:

- Apple Silicon host
- Tart installed
- the external SSD mounted as APFS (`/Volumes/TartVMs` on `m4mini`)
- `TART_HOME` resolving onto that SSD (`echo $TART_HOME`)
- at least 100 GiB free for smoke runs
- no unrelated local Tart VM using the planned test name

The known-good host as of 2026-07-03 is `m4mini`: Apple Silicon M4, macOS 26.4.1, 16 GB RAM, Tart 2.32.1, and the external APFS SSD mounted at `/Volumes/TartVMs` (`TART_HOME=/Volumes/TartVMs/tart`).

The default VM shape is 2 CPU and 4096 MB RAM. For tighter runs, use 1 CPU and 3072 MB RAM.

The 100 GiB floor is conservative for cached smoke runs. First image pulls and full-lane experiments need more headroom. Run one VM at a time unless the host budget is remeasured.

## TART_HOME and the boot-disk guard

The helper refuses to pull images or create VM disks when `TART_HOME` would land on the boot volume (`scripts/vm/lib.sh` `check_tart_home_external`, called by `test-install-tart.sh` and `warm-tart`). This keeps a stray or unmounted external drive from silently filling the home drive. Override a deliberate boot-disk run with `DOTFILES_TART_ALLOW_BOOT_DISK=1`.

On a host with a `machines.host.<hostname>` layer that sets `tart_home` in `home/.chezmoidata/machines.toml` (for example `m4mini` → `/Volumes/TartVMs/tart`), `TART_HOME` is exported automatically at shell startup by `home/dot_zshenv.tmpl`, but only while that SSD is actually mounted. On a host without such a layer, export `TART_HOME` onto its external volume yourself before running the lane.

## Run the smoke lane

From the repo checkout on the validation host. `TART_HOME` is already set on the SSD; trace and cache paths default to a sibling of `TART_HOME` (`/Volumes/TartVMs/homebrew-cache`), so they only need to be set to override:

```sh
make test-tart-install-helper
make test-zsh-fresh-shells

DOTFILES_TRACE=1 \
DOTFILES_TART_TRACE_FILE=/Volumes/TartVMs/dotfiles-tart-smoke.trace.json \
  make test-install-tart-smoke TART_FLAGS="--vm-name dotfiles-tart-smoke-$(date +%Y%m%d-%H%M%S)"
```

The run should end with:

```text
SUMMARY|verify|passed=<count>|failed=0|info=<count>
Install finished successfully.
```

Afterward, confirm cleanup:

```sh
tart list --source local --format json
```

An empty JSON list means no local Tart VMs are left behind.

When `DOTFILES_TRACE=1` is set, the helper writes a merged Chrome/Perfetto-compatible trace. `DOTFILES_TART_TRACE_FILE` can override the final JSON path. Raw guest xtrace, stdout/stderr logs, and per-process trace files live next to it under `<trace>.artifacts/` with private file permissions. If tracing is requested and conversion or merge fails after an otherwise successful install, the run fails instead of silently returning a partial trace.

The helper mounts a persistent host-backed Homebrew cache into the guest by default. It defaults to a sibling of `TART_HOME` (`/Volumes/TartVMs/homebrew-cache`); override it with `DOTFILES_TART_HOMEBREW_CACHE_DIR`. The guest sees that directory as `/Volumes/My Shared Files/homebrew-cache` and receives it through `HOMEBREW_CACHE` plus `HOMEBREW_BUNDLE_USER_CACHE`. This is only an optimization: a cold cache behaves like a normal install, and later VMs can reuse downloaded API metadata and bottles. The cache is writable from the guest, so disable it when validating an untrusted install path.

To disable the cache for a debugging run:

```sh
make test-install-tart-smoke TART_FLAGS="--no-homebrew-cache"
```

Run the full lane when changing full package, cask, or app-install behavior:

```sh
make test-install-tart-full TART_FLAGS="--vm-name dotfiles-tart-full-$(date +%Y%m%d-%H%M%S)"
```

`make test-install-tart-full` defaults to `ghcr.io/cirruslabs/macos-tahoe-xcode:latest`. Override it with `TART_FULL_IMAGE=...` only when validating a specific Xcode image or a pinned digest.

Open a captured trace with:

```sh
./scripts/trace/open-perfetto /Volumes/TartVMs/dotfiles-tart-smoke.trace.json --print-url
```

The helper also scans the captured install log for macOS command failures that older defaults scripts can hide.

## Extending this lane

The useful split is:

- preflight host checks: APFS volume, `TART_HOME` on the SSD, Tart install, free space, image state
- VM runner: clone, configure, boot, mount repo, run install, cleanup
- guest postflight: tools, symlinks, shell verifier, future bootstrap assertions
- convenience wrapper: local checks, cleanup assertion, log path

`scripts/vm/test-install-tart.sh` owns the VM runner today. As we add more guest assertions, prefer moving postflight checks into a separate script instead of turning the runner into a long checklist.

Open follow-ups:

- decide whether to pin the Tart image by digest once the floating Tahoe tag becomes noisy
- decide whether to prebuild a repo-owned base image with common dependencies
- decide whether fresh-shell benchmarking belongs in Tart or stays host-only because VM timing is noisy
