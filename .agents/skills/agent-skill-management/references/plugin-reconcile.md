# Plugin Reconcile

Chezmoi owns desired plugin source and config. Codex and Claude Code own cache
and install records.

Run `.agents/skills/agent-skill-management/scripts/reconcile-agent-plugins` to
print the native commands for the current package render policy. The script is
preview-only — copy/paste the output; it has no apply path. It emits the three
marketplace commands, then a `claude plugin install` per package plus an
`enable` or `disable` matching the package's `default_loaded` value. Output is
sorted alphabetically by package id (`design`, `experimental`, `ios`, `review`,
`utils-agent`, `utils-human`):

```sh
claude plugin marketplace add ~/.agents/plugins --scope user
claude plugin marketplace update prateek-local
codex plugin marketplace upgrade prateek-local
claude plugin install design@prateek-local --scope user
claude plugin disable design@prateek-local --scope user
# ... experimental and ios (both disabled) ...
claude plugin install review@prateek-local --scope user
claude plugin enable review@prateek-local --scope user
claude plugin install utils-agent@prateek-local --scope user
claude plugin enable utils-agent@prateek-local --scope user
claude plugin install utils-human@prateek-local --scope user
claude plugin disable utils-human@prateek-local --scope user
```

The script does not emit any `codex plugin install/enable/disable` commands:
the current `codex plugin` CLI only exposes a `marketplace` subcommand, and
Codex picks up plugin enable state from `~/.codex/config.toml` directly.

Do not render or edit `~/.claude/plugins/known_marketplaces.json`,
`~/.claude/plugins/installed_plugins.json`, or either tool's plugin cache.
