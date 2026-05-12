# Plugin Reconcile

Chezmoi owns desired plugin source and config. Codex and Claude Code own cache
and install records.

Run `.agents/skills/agent-skill-management/scripts/reconcile-agent-plugins` to
print the native commands for the current package render policy. The script is
preview-only — copy/paste the output; it has no apply path. Output covers both
Claude and Codex install/enable commands per `plugin`-rendered package, for
example:

```sh
claude plugin marketplace add ~/.agents/plugins --scope user
claude plugin marketplace update prateek-local
codex plugin marketplace upgrade prateek-local
claude plugin install review@prateek-local --scope user
claude plugin enable review@prateek-local --scope user
codex plugin install review@prateek-local
codex plugin enable review@prateek-local
```

Do not render or edit `~/.claude/plugins/known_marketplaces.json`,
`~/.claude/plugins/installed_plugins.json`, or either tool's plugin cache.
