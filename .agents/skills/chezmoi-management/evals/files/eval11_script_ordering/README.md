# Eval 11 Fixture: Insert Script at a Gap, Don't Renumber

Simulated state: `home/.chezmoiscripts/` with the existing numeric ordering (00 homebrew, 05 core-tools, 10 brew-bundle, 15 xcode, 20 mise-install, 90 verify).

User wants to add a `run_onchange_after_` script that installs rustup, which must run AFTER `10-brew-bundle` (so `rustup` is available via Homebrew) and BEFORE `20-mise-install` (so mise can manage the rust version).

Expected behavior:
- Agent picks a number in the (10, 20) gap that doesn't collide with `15-xcode`. Valid choices: `11-`, `12-`, `13-`, `14-`, `16-`, `17-`, `18-`, `19-`. (`15-` is taken.)
- Agent uses `run_onchange_after_` prefix matching siblings in that range.
- Agent uses `.sh.tmpl` suffix consistent with siblings.
- Agent does NOT propose renumbering any existing scripts.
- Agent notes that script content hash drives re-run, not the filename.
- Agent suggests `chezmoi apply --dry-run --verbose --include=scripts` to verify ordering.
