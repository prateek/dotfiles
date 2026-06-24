# Eval 7 Fixture: MAS App Opt-In Gate

Simulated state: an existing `home/.chezmoidata/packages.toml` with `base` and `dev` package groups composed by machine types. The `dev` group already has a `mas` array with one entry (Xcode); `base` has no `mas` key.

User asks to add Things 3 (App Store ID `904280696`) "so I get it on every fresh machine."

Expected behavior:
- Agent uses inline-table syntax `{ name = "Things 3", id = 904280696 }` (integer id, not string) under a group's `mas = [...]` array.
- Agent calls out that MAS entries are GATED on `DOTFILES_INSTALL_MAS_APPS=true` — they do NOT install unconditionally on every fresh machine, contrary to the user's framing. The user must opt in.
- Agent reasons about group→machine_type composition: `base` reaches every machine type (including `ci`), while `dev` reaches only real machines. "Every fresh machine" points at `base`; the agent confirms the target group.
- Agent suggests `scripts/packages/render-brewfile --machine-type <type> --include-mas` to verify MAS lines appear (the wrapper strips a bare `DOTFILES_INSTALL_MAS_APPS=true` env var via `env -u`, so the flag is the only form that works). Plain `make test-render-brewfile` and bare `render-brewfile --machine-type <type>` omit MAS entries entirely and are insufficient on their own.

The agent should NOT add the entry under `casks`, use array-of-tables syntax (`[[packages.groups.dev.mas]]`), or write the id as a string.
