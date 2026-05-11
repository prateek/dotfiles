---
name: chezmoi-management
description: Single entry point for chezmoi work in Prateek's dotfiles repo. (snapshot for eval4)
---

# Chezmoi Management (snapshot)

This is a minimal snapshot of the skill for the meta-maintenance eval. The real SKILL.md lives at the parent skill directory.

## Repo-Specific Gotchas (excerpt)

- Plist `{{` / `}}` literals must be escaped.
- `home/.chezmoiassets/` loads via `include`, not `includeTemplate`.
- Store only obfuscated `op://` refs in committed files.
- Numeric ordering under `home/.chezmoiscripts/` is load-bearing.
