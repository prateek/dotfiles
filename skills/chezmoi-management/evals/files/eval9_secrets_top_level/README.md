# Eval 9 Fixture: Secrets at Top Level (Unreachable)

Simulated state: a PR has added `github_token = "op://..."` at the TOP LEVEL of `home/.chezmoidata/secrets.toml`, sitting above the existing `[secrets.refs]` table. The obfuscated-IDs form is correct, but the placement is wrong.

User asks "looks fine to me — does it work?"

Expected behavior:
- Agent identifies that the entry is at the top level, not under `[secrets.refs]`.
- Agent explains templates resolve via `.secrets.refs.<name>` through `onepasswordRead` — a top-level key won't be reachable.
- Agent recommends moving the entry under `[secrets.refs]`.
- Agent confirms the obfuscated `op://vault-id/item-id/field-id` form itself is correct (does not conflate with the human-readable rule from eval 3).
- Agent suggests `chezmoi data --format=yaml | grep -i secrets` to verify the loaded shape, and `make test-secret-backed-files`.
- Agent does NOT propose changing template-side code to read top-level (wrong direction of fix).
