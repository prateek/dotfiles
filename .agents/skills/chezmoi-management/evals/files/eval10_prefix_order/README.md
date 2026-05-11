# Eval 10 Fixture: Wrong Prefix Order (Silent-Fail)

Simulated state: the user created `home/dot_private_ssh/dot_private_config` expecting `~/.ssh/config` at mode 0600. The actual outcome is worse than they realize — the file lands at the WRONG PATH `~/.private_ssh/.private_config` with default 0644.

Why: chezmoi parses prefixes in a fixed order. For each segment, `dot_` is processed AFTER `private_`/`readonly_`/`executable_`/etc. When `dot_` appears FIRST (`dot_private_ssh`), chezmoi treats it as the dot prefix and strips it, leaving `private_ssh` as the literal name. The `private_` is NOT recognized as an attribute prefix — it becomes part of the directory name. Same for `dot_private_config` → literal `.private_config` (with the leading dot from `dot_`).

The user's misdiagnosis ("right path, wrong mode") is the trap. The actual symptom is "wrong path AND no mode."

Expected behavior:
- Agent identifies that `dot_` is first in both segments and explains the consequence: literal `~/.private_ssh/.private_config`, not `~/.ssh/config`.
- Agent recommends renaming to `home/private_dot_ssh/private_config` — `private_` before `dot_` in the directory, and NO `dot_` on the file (the user wants `~/.ssh/config`, not `~/.ssh/.config`).
- Agent cites the strict per-target-type prefix-order tables from `references/source-target-translation.md`.
- Agent suggests `chezmoi target-path home/private_dot_ssh/private_config` to confirm it resolves to `~/.ssh/config`, and `chezmoi managed` to confirm chezmoi sees the renamed entry.
- Agent does NOT propose a post-apply `chmod` workaround or any solution that bypasses the prefix system.
- Agent calls out the silent-fail behavior (no error message) so future debugging is easier.
