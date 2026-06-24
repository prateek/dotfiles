---
status: accepted
doc_type: adr
created: 2026-06-23
owner: Prateek
related:
  - ../plans/machine-type-package-selection-plan.md
  - 0006-chezmoi-migration-prototype.md
  - 0004-tart-install-validation-and-tracing.md
  - 0008-sudo-askpass-1password.md
  - ../references/chezmoi-architecture.md
status_detail: "Accepted and implemented on the prateek/machine-profiles branch."
---

# ADR 0010 — Single machine_type axis for package selection

## Context

Package installs were driven by two axes that looked redundant in practice:

- `install_profile` (`core` / `full`) — install *breadth*. Introduced with the
  chezmoi migration ([ADR 0006](0006-chezmoi-migration-prototype.md)). `full` is
  what every real Mac runs. `core` was a minimal/fast subset used only by CI
  dry-run, the Tart `smoke` lane ([ADR 0004](0004-tart-install-validation-and-tracing.md)),
  and `scripts/audit/zsh-fresh-shells.zsh`. `full` also gated heavy apply-time
  steps: a Homebrew pre-update, the Mac App Store opt-in warning, and the Xcode
  setup script.
- `machine_type` (`personal` / `homelab` / `work`) — machine *role*. Prompted
  once at `chezmoi init`, overridable via `DOTFILES_MACHINE_TYPE`. It drove the
  elevation hook and the sudo-askpass gate ([ADR 0008](0008-sudo-askpass-1password.md)),
  but nothing about which packages were installed.

On every real machine `install_profile` is `full`, so it carried no per-machine
signal — `machine_type` was the only axis that actually varied. The concrete
trigger was wanting work Macs to skip personal apps (Tailscale, Arq, VoiceInk),
which `install_profile` had no way to express.

## Decision

Drop `install_profile`/`core`/`full`. `machine_type` is the only package
selection axis. Packages are defined as reusable **groups** that machine types
compose:

- `[packages.groups.<name>]` — `base` (every machine, including CI), `dev` (the
  full toolchain for real machines), `dev-apple` (the Xcode/iOS cluster; its
  presence gates the Xcode setup step), and `personal-apps` (Tailscale, Arq,
  VoiceInk).
- `[packages.machine_types.<type>].groups` — composes the groups:
  `ci = [base]`, `personal = homelab = [base, dev, dev-apple, personal-apps]`,
  `work = [base, dev, dev-apple]`.

The Brewfile (`home/.chezmoitemplates/brewfile.tmpl`) and the config gate
(`home/.chezmoitemplates/package-cask-enabled.tmpl`) each take the union of a
section across the selected groups, deduped by name. Machine type resolves as
`env DOTFILES_MACHINE_TYPE > data .machine_type > .packages.default_machine_type`.
`ci` is the env-only successor to `core` for CI/Tart/audit lanes; it is not in
the interactive `chezmoi init` prompt. Apply-time steps re-key off group
membership: brew pre-update and the MAS warning on `has "dev"`, Xcode setup on
`has "dev-apple"`.

The decomposition was chosen to preserve installs exactly: `core` was a strict
subset of `full`, so `personal` (= `base ∪ dev ∪ dev-apple ∪ personal-apps`)
reconstructs the old `full` set, `work` is that minus the three personal casks,
and `ci` is the old `core` minus the two personal casks it happened to list.

## Consequences

- One knob per machine. Adding an app to a group, or a group to a machine type,
  changes both its install and its managed config in one place.
- `work` installs the full dev toolchain (including Xcode setup and MAS) minus
  the personal apps — it is `personal` without `personal-apps`.
- `homelab` equals `personal` today. Making it leaner is a future edit (drop a
  group from its `groups` list); the single axis can't express it without a new
  group.
- **Lost**: the independent breadth×role test matrix. Previously CI could render
  any role at `core` breadth; now breadth is folded into the `ci` type, which is
  a tier masquerading as a role. The Tart `--lane smoke|full` CLI is unchanged
  and maps to `ci`/`personal` internally.
- `ci` no longer ships the Tailscale/VoiceInk casks. Only relevant if a human
  ran `ci` as a daily driver; CI and Tart skip casks regardless.

## Alternatives considered

- **Additive excludes keyed by machine_type** (a `work` exclude list subtracted
  from the profiles). Rejected: keeps the redundant `install_profile` axis and
  scatters the "what does work skip" policy instead of composing from groups.
- **A dedicated `work` profile.** Rejected: duplicates the entire package list to
  subtract three casks, and conflates breadth with role.
- **Keep both axes, rename `install_profile` → `install_tier`.** Resolves the
  naming smell but keeps two axes for what is, in practice, one.

## Future work

Generalize `groups` beyond packages. A machine type could compose its *whole*
config from shared groups — gating non-package chezmoi templating too (zsh
startup overlays, agent/AI surfaces, app config in `.chezmoiignore`). Today only
package selection and the existing `machine_type`-keyed gates (elevation,
sudo-askpass) are machine-aware; a group/capability model could unify the rest.
