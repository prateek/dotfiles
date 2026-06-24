---
status: active
doc_type: plan
owner: Prateek
created: 2026-06-23
updated: 2026-06-23
related:
  - ../adr/0010-machine-type-package-selection.md
  - ../references/chezmoi-architecture.md
status_detail: "Implemented on the prateek/machine-profiles branch; landing in progress."
---

# Machine-type package selection plan

Collapse package selection onto the single `machine_type` axis, composing
reusable groups. Decision and rationale: [ADR 0010](../adr/0010-machine-type-package-selection.md).

## Target model

`home/.chezmoidata/packages.toml`:

- `[packages] default_machine_type = "personal"`.
- `[packages.groups.<name>]`: `base`, `dev`, `dev-apple`, `personal-apps`.
- `[packages.machine_types.<type>].groups`: `ci=[base]`,
  `personal=homelab=[base,dev,dev-apple,personal-apps]`, `work=[base,dev,dev-apple]`.

Selection = union of each section across the selected groups, deduped by name.
Resolution precedence: `env DOTFILES_MACHINE_TYPE > data .machine_type >
.packages.default_machine_type`.

## What changed

- Templates union groups: `brewfile.tmpl`, `package-cask-enabled.tmpl`.
- Apply scripts re-key off group membership: `run_onchange_after_10-brew-bundle`
  (brew pre-update + MAS warning on `has "dev"`), `run_onchange_after_12-gh-extensions`
  (union), `run_onchange_after_15-xcode` (gate on `has "dev-apple"`,
  `xcode_required_brews` from `dev-apple`).
- CLI/bootstrap: `render-brewfile --machine-type`, `chezmoi.toml.tmpl` drops the
  `install_profile` prompt/data, `test-apply-dry-run.sh` takes a machine type.
- Tart keeps `--lane smoke|full`, mapping to `ci`/`personal` internally.
- CI matrix renders `ci`/`personal`/`work` and asserts work omits the personal apps.
- Tests pin `machine_type` explicitly (the gate resolves env first, and this
  machine's config sets `machine_type=work`).

## Verification

Set-equality against the pre-refactor render proved `personal == old full`,
`work == full − {tailscale-app, arq, voiceink}`, `ci == old core − {tailscale-app,
voiceink}`. Suites: `make test-render-brewfile test-package-gated-configs
test-brew-bundle-script test-gh-extensions-script test-xcode-install-script
test-chezmoi-apply test-docs-lifecycle`.

## Future work

Generalize `groups` to gate non-package chezmoi templating (zsh startup, agent
surfaces, app config), so a machine type composes its whole config from shared
groups. Tracked in [ADR 0010](../adr/0010-machine-type-package-selection.md) →
Future work.
