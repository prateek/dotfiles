# Eval 13 Fixture: Homebrew Trust Store Is Local State

Simulated state: after `chezmoi apply`, Homebrew has written a trust database at
`~/.homebrew/trust.json` or `${XDG_CONFIG_HOME}/homebrew/trust.json`.

Expected behavior:
- Agent refuses to commit the generated trust store under `home/`.
- Agent treats `home/.chezmoidata/packages.toml` as the durable package intent.
- Agent keeps non-official tap-owned formulae and casks tap-qualified in package
  data so apply can derive trust from the rendered Brewfile.
- Agent notes that the rendered Brewfile marks tap-qualified non-official
  formulae and casks with `trusted: true`.
