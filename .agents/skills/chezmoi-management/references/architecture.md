# Dotfiles Chezmoi Architecture

Use this as the local architecture summary before reaching for the broader repo
docs. The full maintained reference is
`docs/references/chezmoi-architecture.md`.

## Ownership Model

- Repo source state lives under `home/`; `.chezmoiroot` points there, so paths
  under `home/` render into `$HOME`.
- Repo-local agent instructions and skills live at the repo root or under
  `.agents/`. They describe this checkout.
- Machine-wide agent configuration lives under `home/dot_agents/` and
  materializes to `~/.agents`.
- Runtime paths such as `~/.agents`, `~/.codex`, `~/.claude`, app preference
  files, and generated Brewfiles are verification targets, not the default
  source to edit.

## Source-State Surfaces

- `home/.chezmoidata/`: committed structured inputs for packages, secrets,
  licenses, and templates.
- `home/.chezmoitemplates/`: shared templates, Brewfile rendering, macOS
  defaults, script helpers, and plist fragments.
- `home/.chezmoiscripts/`: idempotent apply-time setup scripts.
- `home/.chezmoiassets/`: raw payloads loaded with `include`, not
  `includeTemplate`.
- `home/.chezmoiignore`: host-aware target gating. Ignored source-state files
  can still affect rendered output if another template includes them, so check
  rendered state before assuming an ignore is inert.

## Validation Implications

- Use `chezmoi diff`, `chezmoi status`, `chezmoi managed`, and
  `chezmoi unmanaged` to compare source, target, and live state.
- Use `readlink` and tree-level checks for adapter directories and symlinks.
- For bootstrap or ownership changes, branch smoke tests are not enough; prefer
  temp-home `chezmoi init/apply/status` validation when practical.
- For plist work, account for running-app guards and post-apply hooks before
  claiming the change is safe.
