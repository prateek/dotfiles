---
status: current
doc_type: reference
created: 2026-04-27
updated: 2026-06-29
related:
  - ../index.md
  - ../adr/0006-chezmoi-migration-prototype.md
status_detail: "Current architecture reference. Historical migration detail lives in ADRs and git history."
---

# Chezmoi Architecture

This document describes the steady-state dotfiles architecture. It is not a
migration log. Use [ADR 0006](../adr/0006-chezmoi-migration-prototype.md) for the
decision record and git history for implementation archaeology.

## Operating Model

- The canonical checkout is `~/dotfiles`.
- Chezmoi owns home-directory source state from `home/`; `.chezmoiroot` points
  there, so paths under `home/` materialize into `$HOME`.
- Chezmoi is the ongoing command surface: use `chezmoi diff`, `chezmoi status`,
  `chezmoi verify`, and `chezmoi apply`.
- Repo-local agent files stay at the repo root or under `.agents/`.
- Machine-level agent config lives under `home/dot_agents/`, `home/dot_codex/`,
  and `home/dot_claude/`.
- Local observations, captures, accounts, app runtime state, and machine-only
  overrides stay out of git.

## Source Layout

```text
home/
  .chezmoi.toml.tmpl          # first-machine prompts and local data defaults
  .chezmoidata/               # committed structured desired state
  .chezmoiassets/             # non-template payloads consumed by templates
  .chezmoiscripts/            # idempotent apply-time setup
  .chezmoitemplates/          # shared templates and plist merge fragments
  dot_agents/                 # ~/.agents machine-wide agent surface
  dot_codex/                  # ~/.codex machine-wide Codex config
  dot_claude/                 # ~/.claude machine-wide Claude config
  dot_config/                 # XDG config targets
  Library/                    # macOS app config targets
scripts/                      # repo helpers, hooks, audits, VM, trace tooling
tests/                        # focused regression tests
docs/                         # lifecycle-tracked docs and ADRs
```

Use one `home/Library/` tree. Apply `private_` to the specific files or
directories that need private permissions; do not create a separate
`private_Library/` source root.

## Bootstrap And Apply

Bootstrap is:

```sh
xcode-select --install
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --source ~/dotfiles prateek
```

There is no durable `install.sh` or `bootstrap.sh`.

Chezmoi scripts under `home/.chezmoiscripts/` handle package installation,
mise runtime setup, selected macOS defaults, Hammerspoon compilation, and
post-apply verification. Use `run_once_before_` for prerequisites and
`run_onchange_after_` for work that should rerun when the rendered script
changes.

Scripts must be idempotent. A rerun should converge or report a clear blocker.

## Packages And Tools

- Reusable package groups (`[packages.groups.*]`: `base`, `dev`, `dev-apple`,
  `personal-apps`) live in `home/.chezmoidata/packages.toml`.
- Selection is driven by a single axis, `machine_type`. Each type composes a set
  of groups via the layered `home/.chezmoidata/machines.toml` table
  (`[machines.type.*].groups`), resolved by `home/.chezmoitemplates/features.tmpl`:
  `ci=[base]`, `personal=homelab=[base,dev,dev-apple,personal-apps]`,
  `work=[base,dev]`. Work omits the personal apps and the `dev-apple` Apple/iOS
  toolchain (no Xcode setup); `ci` is the minimal CI/Tart/audit tier and a
  first-class `machine_type` prompt choice. See
  [ADR 0010](../adr/0010-machine-type-package-selection.md) and the config-gating
  convention in [ADR 0012](../adr/0012-config-gating-convention.md).
- `home/.chezmoitemplates/brewfile.tmpl` renders the Brewfile input as the union
  of each section across the selected machine type's groups, deduped by name.
  `package-cask-enabled.tmpl` gates app config the same way. Both read the
  selected groups from the `features.tmpl` resolver, which resolves
  `machine_type` from `[data]` (default `personal`).
- `home/.chezmoiscripts/run_onchange_after_10-brew-bundle.sh.tmpl` runs
  `brew bundle` from that rendered input. The rendered Brewfile marks
  tap-qualified third-party formulae and casks with `trusted: true`, and the
  script pre-taps declared taps before Bundle runs.
- `scripts/packages/render-brewfile --machine-type <type>` is the audit and CI
  entrypoint for the same template.
- Mac App Store entries render only when `DOTFILES_INSTALL_MAS_APPS=true` or
  `--include-mas` is used.
- Mise owns active tool selection and shims. See
  [Mise Tool Management](mise-tool-management.md).

## Config Gating

`[data]` in `home/.chezmoi.toml.tmpl` holds identity only: `machine_type` (the
sole first-run prompt, also selectable with `chezmoi init --promptChoice
'machine_type=<type>'`), the `xdg_*`/`dotfiles_dir` paths, and `jamf_policy_id`. All
machine behavior — package groups, install scripts, macOS defaults, secrets, the
private overlay, the elevation method — is composed at apply time from the layered
`home/.chezmoidata/machines.toml` table, resolved by
`home/.chezmoitemplates/features.tmpl`. Layers merge low→high:
`defaults < os.<os> < type.<machine_type> < host.<hostname>` < host-local
`[data].machines_local`; consumers read it with one
`{{- $f := includeTemplate "features.tmpl" . | fromJson -}}`. Per-machine
exceptions go in a host-local `[data].machines_local` block; apply-time runtime
switches (`DOTFILES_SKIP_*`, etc.) stay separate and are never managed desired
state. See [ADR 0012](../adr/0012-config-gating-convention.md) for the convention
and the missing-key / `default`-both-arms gotchas.

## App Config

Prefer readable native target paths under `home/`.

Simple file-backed app config should live at the path it renders to. Nested
preference plists use the shared plist merge pattern:

- desired plist fragment:
  `home/.chezmoitemplates/<bundle-id>.plist.tmpl`
- 3-line modify stub:
  `home/Library/private_Preferences/modify_private_<bundle-id>.plist.tmpl`
- shared engine:
  `home/.chezmoitemplates/plist-merge-{prelude,postlude}.py`

Optional app config is gated in `home/.chezmoiignore`. Do not render empty
placeholder config for absent apps.

Raw app captures live under
`${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/`. A capture becomes
desired state only through an explicit adoption step.

## Secrets And Licenses

Committed secret metadata may contain obfuscated `op://` references and target
paths. Actual machine-local secret values belong in local chezmoi config.

Secret-backed templates should fail clearly when secret rendering is enabled
but the required reference is empty.

## Agent Surfaces

- Repo guidance for this checkout stays in root `AGENTS.md`, root `CLAUDE.md`,
  and repo-local `.agents/`.
- Machine-wide guidance and skills materialize from `home/dot_agents/`.
- Claude's machine-wide `CLAUDE.md` is a symlink adapter to
  `../.agents/AGENTS.md` so shared instructions do not drift.
- Codex machine config materializes from `home/dot_codex/`.

Live links are reserved for repo-local executable wrappers and tool-adapter
pointers that prevent duplicated instruction files. Everything else should be
rendered source state unless a focused app plan says otherwise.

## Validation

Use the smallest check that proves the changed surface:

- Docs lifecycle: `make test-docs-lifecycle`
- Package rendering: `scripts/packages/render-brewfile --machine-type <type>`
- File-only apply preview:
  `chezmoi apply --dry-run --verbose --exclude=scripts`
- Full managed-state preview: `chezmoi diff` and `chezmoi status`
- App plist changes: the focused plist test for that app plus the shared
  plist hook tests
- Shell startup: `scripts/audit/zsh-fresh-shells.zsh verify`

Tart lanes are local end-to-end install validation. CI does not boot a full
macOS VM.
