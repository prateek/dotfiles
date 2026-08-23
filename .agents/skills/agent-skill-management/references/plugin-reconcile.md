# Plugin Reconcile

Chezmoi owns desired plugin source and config. Codex and Claude Code own cache
and install records.

Run `.agents/skills/agent-skill-management/scripts/reconcile-agent-plugins` to
print the native commands for the current package render policy. The script is
preview-only — copy/paste the output; it has no apply path. It refreshes the
Codex cache for default-loaded packages with `codex plugin add`, then emits a
`claude plugin install` per package plus an `enable` or `disable` matching the
package's `default_loaded` value. Output is sorted alphabetically by package id:

```sh
claude plugin marketplace add ~/.agents/plugins --scope user
claude plugin marketplace update prateek-local
codex plugin add core@prateek-local
codex plugin add review@prateek-local
codex plugin add utils-agent@prateek-local
claude plugin install core@prateek-local --scope user
claude plugin enable core@prateek-local --scope user
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

`codex plugin add` refreshes the installed cache but also writes
`enabled = true`. The helper therefore emits it only for packages whose
`default_loaded` policy is true. Disabled package source still renders into the
local marketplace. To refresh one for project-only use, run `codex plugin add`
and then `chezmoi apply ~/.codex/config.toml` to restore its user-level
`enabled = false` policy before relying on the project override.

Do not render or edit `~/.claude/plugins/known_marketplaces.json`,
`~/.claude/plugins/installed_plugins.json`, or either tool's plugin cache.
