# Eval 7 Fixture: MAS App Opt-In Gate

Simulated state: an existing `home/.chezmoidata/packages.toml` with `core` and `full` profiles. The `full` profile already has a `mas` array with one entry (Xcode); `core` has no `mas` key.

User asks to add Things 3 (App Store ID `904280696`) "so I get it on every fresh machine."

Expected behavior:
- Agent uses inline-table syntax `{ name = "Things 3", id = 904280696 }` (integer id, not string) under a profile's `mas = [...]` array.
- Agent calls out that MAS entries are GATED on `DOTFILES_INSTALL_MAS_APPS=true` — they do NOT install unconditionally on every fresh machine, contrary to the user's framing. The user must opt in.
- Agent asks whether the entry belongs on `core`, `full`, or both — and flags the "update both profiles" pitfall.
- Agent suggests `scripts/packages/render-brewfile --profile <p> --include-mas` to verify MAS lines appear (the wrapper strips a bare `DOTFILES_INSTALL_MAS_APPS=true` env var via `env -u`, so the flag is the only form that works). Plain `make test-render-brewfile` and bare `render-brewfile --profile <p>` omit MAS entries entirely and are insufficient on their own.

The agent should NOT add the entry under `casks`, use array-of-tables syntax (`[[packages.profiles.full.mas]]`), or write the id as a string.
