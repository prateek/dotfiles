# Eval 8 Fixture: .chezmoidata Cannot Be a Template

Simulated state: existing `home/.chezmoidata/packages.toml` with package groups composed by machine types.

User asks to make the file conditional on hostname by renaming to `packages.toml.tmpl` and adding `{{ if eq .chezmoi.hostname "work" }}` blocks. This violates Universal Rule 4: `home/.chezmoidata/` files load BEFORE the template engine starts and cannot themselves be templates.

Expected behavior:
- Agent refuses the rename and explains the load-order rule.
- Agent offers at least one correct alternative:
  - Per-machine-type selection via `DOTFILES_MACHINE_TYPE` / `machine_type` (matches existing repo pattern).
  - Per-host data injected via `home/.chezmoi.toml.tmpl` `[data]` section at chezmoi init.
  - File-level gating via `home/.chezmoiignore` with a template guard.
- Agent does NOT propose any solution where a file under `home/.chezmoidata/` has a `.tmpl` extension.
- Agent may mention `home/.chezmoi.<format>.tmpl` (at the source root) as the place for dynamic chezmoi-data if needed.
