---
status: accepted
doc_type: adr
created: 2026-04-26
owner: Prateek
related:
  - ../dev/chezmoi-migration-plan.md
  - 0004-tart-install-validation-and-tracing.md
---

# ADR 0006 — Chezmoi migration target architecture

## Context

This repo is conventionally checked out at `~/dotfiles`. The current install path mixes package installation, symlink management, shell setup, and macOS/app side effects in custom scripts.

chezmoi can manage home-directory source state, templates, private files, scripts, and machine-local config. Its default source location is not a good fit for this repo because the repo itself is the durable source of truth and many local scripts already assume `~/dotfiles`.

The target architecture should make chezmoi own real source-state files where possible and reserve live links for repo-local executable wrappers that must run directly from the checkout.

## Decision

Keep the canonical checkout at `~/dotfiles`.

Use `.chezmoiroot` with the value `home`, so chezmoi reads source state from:

```text
~/dotfiles/home/
```

Repo tooling, plans, tests, scripts, reference docs, and generated artifacts stay outside `home/`.

Use native chezmoi source-state naming in `home/`:

- `dot_` for dotfiles;
- `private_` for private targets;
- `executable_` for executable targets;
- `.tmpl` only for host, OS, path, feature, or secret variation;
- `symlink_` only for deliberate live links, primarily repo-local executable wrappers and tool-adapter pointers that prevent duplicated instruction files.

Keep package profiles, app indexes, scalar defaults, license aliases, and permission intent in `home/.chezmoidata/` so chezmoi templates and scripts can consume one structured data model. Chezmoi may materialize stable target files directly. Selected app plist payloads that support `modify_` targets live under `home/.chezmoiassets/`, not `.chezmoitemplates`, so app-owned strings such as Moom geometry are not parsed as Go templates. Raw captures, rollback records, generated inventories, and other machine-local observations stay outside the repo under XDG state.

Agent tool homes (`~/.agents`, `~/.codex`, and `~/.claude`) are managed under `home/`, not repo-root live-link trees. Shared instruction content lives in `home/dot_agents/AGENTS.md`; tool-specific pointers such as `~/.claude/CLAUDE.md -> ../.agents/AGENTS.md` may use `symlink_` targets to avoid duplicated guidance. Local volatile state for those tools stays out of the repo.

Plain `chezmoi apply` may run idempotent `.chezmoiscripts` for safe home-environment setup such as packages, shell dependencies, mise runtimes, verification, and declared home source state. Stable app config is source state when it is a native file, a selected plist `modify_` target, or generated policy data. Higher-risk imperative default, license, permission, and non-file app mutations still belong behind explicit data gates and the transaction-aware `dotfiles apply <scope>` commands.

Update, 2026-04-27: the target architecture merges `bootstrap.sh` into a tiny `install.sh`. `install.sh` prepares Xcode Command Line Tools, Homebrew, Git, chezmoi, and uv, then hands off to `chezmoi init --apply`. Ongoing setup moves into `.chezmoiscripts` and `.chezmoiexternal.*`.

Update, 2026-04-28: `bin/dotfiles` is a uv-backed Python script with inline script metadata. uv is part of the stage-zero handoff set so the CLI runs with its declared Python version before package rendering or defaults rollback code executes.

Update, 2026-04-28: Homebrew package intent lives in `home/.chezmoidata/packages.toml`. `bin/dotfiles render brewfile --profile <profile>` renders temporary Brewfile input for Homebrew Bundle; repo-root `Brewfile` and `Brewfile.core` are no longer durable source files. Mac App Store entries require explicit opt-in through `DOTFILES_INSTALL_MAS_APPS=true` or `--include-mas`.

Update, 2026-04-28: raw app captures are not committed. `scripts/macos/capture.sh`, `dotfiles capture`, and `inventory --write` write machine-local observations under XDG state. Privileged Chrome policy was considered but is no longer part of the current desired state.

Update, 2026-04-29: app TOML files are apply-only indexes, not migration trackers. They exist only for apps installed by the selected package profile and point at readable config the repo applies: native files under `home/`, selected plist assets under `home/.chezmoiassets/` consumed by `modify_` targets, small scalar defaults, or generated policy data. Migration bookkeeping such as phase/action/audit status is not part of app desired state.

Update, 2026-04-30: chezmoi is the ongoing command surface. The repo will retire `bin/dotfiles` as a durable public CLI; daily commands are native chezmoi (`chezmoi apply`, `chezmoi status`, `chezmoi diff`, `chezmoi verify`, `chezmoi apply --dry-run --verbose --exclude=scripts`, `chezmoi managed`, `chezmoi unmanaged`, `chezmoi ignored`, `chezmoi data`, `chezmoi edit`, `chezmoi add`, `chezmoi re-add`). Focused helper scripts may remain behind chezmoi scripts where typed code is clearer than shell or Go templates — package renderer, macOS defaults applier, capture/audit scripts, plist hooks. These helpers are implementation details, not a second product surface. Rollback means desired-state rollback by default (`git checkout <prev>` then `chezmoi apply`); exact live rollback is opt-in per risky helper, which may write a per-helper preflight or capture record before mutating state. There is no requirement for a generic transaction wrapper around chezmoi.

Update, 2026-05-01: `bin/dotfiles` is deleted. Package install moved to chezmoi's declarative-install pattern: `home/.chezmoitemplates/brewfile.tmpl` is rendered inline by `home/.chezmoiscripts/run_onchange_after_10-brew-bundle.sh.tmpl` and piped to `brew bundle --file=-`; `scripts/packages/render-brewfile` exposes the same template to audit scripts and CI. macOS defaults live as plain `defaults write` calls in `home/.chezmoitemplates/macos-defaults.sh.tmpl`, included by `home/.chezmoiscripts/run_onchange_after_30-macos-defaults.sh.tmpl` (no `home/.chezmoidata/system/macos.toml`, no Python applier). `home/.chezmoidata/apps/` is gone — per-app preferences go through the plist `modify_` pattern (Plist Management). `uv` drops out of stage-zero (`install.sh` and `run_once_before_05`) since no chezmoi-time helper requires Python. Audit helpers `scripts/audit/macos-settings-coverage.sh` and `scripts/audit/settings-coverage.sh` are removed along with their tests, since the data they audited (`macos.toml`, `apps/<id>.toml`) no longer exists.

Update, 2026-05-02: Bootstrap simplified further — `install.sh` is removed. New machines run the chezmoi one-liner (`sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply prateek`) after a one-time `xcode-select --install`. `home/.chezmoi.toml.tmpl` uses `promptStringOnce`/`promptBoolOnce` for first-machine settings (install_profile, apply_macos_defaults, run_install_scripts, secrets_enabled), with env-var override for non-interactive runs (CI/Tart). The plist refactor moves to a hard cut — single PR writes the engine in `home/.chezmoitemplates/`, converts all 11 apps to fragment + 3-line stub, deletes every JSON sidecar; no transitional dual-format engine. Phase 3 design questions resolved: license automation scoped to Moom + BetterTouchTool + Alfred via secret-backed private templates; macOS permissions stay manual (no PPPC profiles); Tart postflight starts with basics (chezmoi status empty, inlined defaults read back, one asserted key per managed plist app, hook state file cleaned). Local validation cadence: warm Tart VM on `mini` for iteration, cold disposable VMs for checkpoint runs.

Update, 2026-05-10: Privileged non-Homebrew chezmoi phases use a shared sudo keepalive from `home/.chezmoitemplates/script_lib.sh`. Homebrew install, full-profile Xcode setup, and macOS defaults start the keepalive only when they run and need administrator access; Brew Bundle checks the rendered Brewfile first and then lets Homebrew own any cask/pkg sudo prompt because `brew` resets the sudo timestamp when it starts. The helper prompts once for a cold sudo cache, preserves credentials that were warm before dotfiles started, and cleans itself up shortly after the parent `chezmoi apply` exits. Brew Bundle uses `--jobs auto` for formula installs when the installed Homebrew supports it, with env overrides for job count and download concurrency. macOS defaults write a payload-plus-managed-key-snapshot stamp under XDG state so wrapper/helper changes do not re-run defaults, sudo, or restarts when the defaults payload and owned active preference surface are unchanged; `DOTFILES_FORCE_MACOS_DEFAULTS` is the explicit escape hatch for suspected stale live state. Mise disables Ruby GitHub attestation checks during bootstrap so unauthenticated fresh machines do not fail on the public GitHub API rate limit. The full package profile installs `aria2` and bottled `homebrew/core/xcodes`, selects and sets up the canonical Xcode version from `home/dot_agents/state/ios-triple.json` when it is present, downloads Xcode only with `install_xcode=true` or `DOTFILES_INSTALL_XCODE=true`, then installs Xcode-required formulae such as `facebook/fb/idb-companion` and `swiftlint`.

## Consequences

### Positive

- The repo keeps its `~/dotfiles` convention.
- Chezmoi source state is readable and testable as source state, not a separate symlink descriptor layer.
- Repo-only material stays outside chezmoi's home target mapping.
- Desired package/app/system declarations use chezmoi's native data and source-state mechanisms instead of a parallel repo control plane.
- Isolated HOME/XDG tests can exercise `chezmoi init`, `apply`, `status`, `diff`, and `verify`.
- Tart remains the clean macOS install proof path for bootstrap, package, shell, and macOS baseline changes.
- App/system mutations use the narrowest safe mechanism: ordinary chezmoi source state for readable config, focused helper scripts for imperative side effects, and per-helper preflight captures only where the risk warrants it.

### Negative

- Moving files into native chezmoi source-state names creates more churn than linking existing repo paths.
- Temporary research files are not durable source state.
- Risky imperative helpers each own their own preflight/undo design; there is no centralized rollback infrastructure to lean on.

### Neutral

- Package installation, advanced app/system data, license automation, and permissions are phased work.
- Selected live links remain acceptable for repo-local wrappers.
- `bin/dotfiles` is removed; there is no transitional CLI to maintain. Add new ad-hoc helpers under `scripts/<area>/` and call them directly.

## Revisit Criteria

Re-open this ADR if any of these happen:

- the repo moves away from the `~/dotfiles` checkout convention;
- `.chezmoiroot = home` blocks a real migration requirement;
- chezmoi stops being the right ongoing command surface (for example, a multi-host fleet need that chezmoi cannot meet);
- app/system data handling moves into a dedicated tool or separate repository.
