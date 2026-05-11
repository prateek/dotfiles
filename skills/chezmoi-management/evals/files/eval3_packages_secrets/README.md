# Eval 3 Fixture: Obfuscated op:// References

Simulated state: an existing `home/.chezmoidata/secrets.toml` with the `[secrets.refs]` table holding one configured license ref and one empty ref (the "not configured on this machine" sentinel).

The agent is asked to add an Anthropic API key reference. The vault and item names are given in human-readable form (`Personal`, `Anthropic`).

Expected behavior:
- Agent recognizes the `[secrets.refs]` table is the right home for the new key.
- Agent translates to or asks for the obfuscated `vault-id/item-id/field-id` form.
- Agent refuses to commit a human-readable `op://Personal/Anthropic/credential` to this file.
- Agent points at `~/.config/chezmoi/chezmoi.toml.local` for any human-readable mapping.
- Agent does NOT add the key at the top level of the file (templates read `.secrets.refs.<name>`).
