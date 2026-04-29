# ADR 0004 - Tart install validation and Perfetto trace diagnostics

- Status: Accepted
- Date: 2026-04-27
- Deciders: Prateek
- Related: `~/dotfiles/dev/docs/tart-mini-validation.md`
- Related ADR: `~/dotfiles/dev/adr/0002-zsh-fresh-shell-validator.md`

## Context

The host fresh-shell validator answers whether the shell behaves correctly after dotfiles are present. It does not prove that a clean macOS machine can run the installer, apply the bootstrap path, install core tools, and pass postflight checks.

ADR 0002 rejected a VM-first shell validator because Tart was too heavy for that v1 problem. This decision reopens Tart for a narrower use: local end-to-end install validation.

The current validation host is `mini`, with Tart storage on the external APFS volume at `/Volumes/Extra/.tart`. The smoke lane uses `ghcr.io/cirruslabs/macos-tahoe-base:latest`; the full lane uses `ghcr.io/cirruslabs/macos-tahoe-xcode:latest`.

## Decision

Use Tart on `mini` as the local end-to-end install validation lane for this repo.

Specific decisions:

- `scripts/vm/test-install-tart.sh` owns VM creation, install execution, postflight validation, tracing, and cleanup.
- `smoke` runs `install.sh --core` in a clean macOS guest and is the default real-VM lane.
- `full` is explicit and slower; it uses an Xcode-backed image and includes the full install profile and cask behavior. Mac App Store entries are omitted from generated Brewfiles unless explicitly opted in on a signed-in machine.
- CI stays lightweight. It runs helper contract, postflight, log-scan, and trace-conversion tests, but does not boot Tart.
- The host fresh-shell verifier remains the shell oracle. Tart invokes `scripts/audit/zsh-fresh-shells.zsh verify` after bootstrap instead of replacing it.
- Perfetto traces are diagnostic evidence. Installer scripts should not contain Perfetto JSON plumbing or trace metadata tables.
- Plain timing summaries are always-on diagnostic evidence. Perfetto remains the deeper tool when phase timings are not enough.
- Guest semantic spans come from zsh xtrace, function names, source files, line numbers, and `funcstack`.
- Trace artifacts are private by default. Directories are `0700`; raw and converted trace files are `0600`.
- If tracing is requested and install succeeds, trace conversion or merge failure fails the run.
- The host-backed Homebrew cache is enabled by default as an optimization for trusted local Tart runs.
- Remote install mode records host lifecycle spans only because the guest path is intentionally `curl | bash`.
- The Tahoe images float on `latest` for now. Pinning is a revisit item, not the first default.

## Options considered

### Option A - Host-only contracts and dry runs

Keep all validation on the host through helper tests, dry-run installs, and fresh-shell checks.

- **Pros:** Cheap, fast, and CI-friendly.
- **Cons:** Does not prove a clean macOS machine can bootstrap from this repo.
- **Rejected:** Good as coverage, insufficient as end-to-end install evidence.

### Option B - CI-hosted macOS validation now

Run the clean-machine lane in GitHub Actions or another hosted CI surface.

- **Pros:** Easier to make mandatory and visible on every PR.
- **Cons:** More setup and cost. The current need is local proof and iteration speed.
- **Rejected for now:** Keep as a future destination once the lane is stable.

### Option C - Tart local lane on `mini` (chosen)

Run disposable macOS guests on the Mac mini, backed by the external APFS volume.

- **Pros:** Real macOS guest, no CI cost, enough disk for image and cache experiments, easy cleanup.
- **Cons:** Local-only, host-specific, and dependent on Tart image availability.
- **Chosen:** Best fit for validating the installer while the workflow is still changing.

### Option D - Prebuilt validation image

Maintain a pinned or prewarmed Tart image with slow prerequisites already present.

- **Pros:** Faster repeated runs and lower network variance.
- **Cons:** Adds image maintenance before the base lane is fully settled.
- **Deferred:** Revisit if Homebrew, Xcode Command Line Tools, or image pull time dominate.

## Consequences

### Positive

- The repo now has a real clean-macOS install proof path.
- The VM lane can catch stale macOS defaults commands, bootstrap assumptions, missing cleanup, and fresh-shell failures after installation.
- Perfetto traces make slow or failed runs inspectable without adding tracing calls to installer code.
- The Homebrew cache shortens trusted local runs without becoming correctness evidence.

### Negative

- The lane depends on `mini`, `/Volumes/Extra`, Tart, and the current Cirrus Labs image.
- Floating `latest` can drift between runs.
- Raw zsh xtrace can include sensitive command text, so artifacts must stay private.
- A writable host-backed Homebrew cache is an optimization for trusted local tests, not a sandbox boundary.

### Neutral

- The shell behavior source of truth remains `scripts/audit/zsh-fresh-shells.zsh`.
- Remote mode traces host lifecycle only.
- CI proves the helper and converter contracts, while the real VM run remains local for now.

## Revisit criteria

Re-open this ADR if any of these happen:

- the Tart lane becomes stable enough to promote into a self-hosted CI runner
- the floating Tahoe image causes noisy failures and needs a pinned digest or named base image
- Homebrew, Xcode Command Line Tools, or image pull time dominates run time after caching
- trace artifacts are too noisy or sensitive and need stronger redaction or opt-in capture
- postflight validation grows large enough to deserve dedicated scripts or suites
- `mini` no longer has enough disk, memory, or availability for the lane
