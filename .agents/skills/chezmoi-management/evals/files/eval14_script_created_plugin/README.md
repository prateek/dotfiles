# Fixture: script-created-plugin-source-translation

Simulated state; no live plugin tree is provided or modified:

- `chezmoi source-path` resolves to `/Users/prateek/dotfiles/home`.
- `chezmoi source-path ~/.agents/plugins/plugins/core/skills/code-gardening/SKILL.md`
  fails because the file is not a direct managed entry.
- The user edited that materialized skill and wants to make the change portable.
- The checkout contains `agent-marketplace/packages/core/skills/code-gardening/SKILL.md`
  as authored source, plus `apm.yml` and `.codex-plugin/plugin.json` in the package.
- `home/.chezmoiscripts/run_onchange_after_36-agent-plugins.sh.tmpl` builds and
  materializes the marketplace, then reconciles native clients.

The task asks for source and validation guidance only. Canonical expectations
live in `evals/evals.json`; fixture setup must not create a discoverable skill.
