# Plugin Reconcile

Chezmoi owns desired plugin source and config. Codex and Claude Code own their
install records and caches, and only their CLIs write them.

`chezmoi apply` converges those records. After rendering `~/.agents/plugins`,
`run_onchange_after_36-agent-plugins.sh.tmpl` runs

```sh
.agents/skills/agent-skill-management/scripts/reconcile-agent-plugins \
  --apply --plugins-root ~/.agents/plugins --agent claude [--agent codex]
```

for each CLI in the machine's `agent_clis`
([ADR 0020](../../../../docs/adr/0020-apply-reconciles-plugin-installs.md)).
Per agent:

- Claude: `claude plugin marketplace add ~/.agents/plugins --scope user` when
  `marketplace list --json` lacks `prateek-local` (declaring it in
  `settings.json` is not enough for the CLI to install from it);
  `plugin install` for every rendered package missing from
  `plugin list --json`; `enable` or `disable` only when the listed state
  differs from `default_loaded` (install enables, and both toggles fail when
  the plugin is already in the target state); `uninstall` for `@prateek-local`
  records whose package no longer renders. Commands run from `$HOME` so
  project-scoped settings do not colour the state it reads.
- Codex: `codex plugin add` for every default-loaded package on each run (Codex
  copies plugins into its cache, so `add` is the content refresh), and
  `codex plugin remove` for orphaned `@prateek-local` records. `add` also
  writes `enabled = true`, so disabled packages are left alone. To use one in
  a single project, run `codex plugin add <pkg>@prateek-local` by hand and then
  `chezmoi apply ~/.codex/config.toml` to restore its user-level
  `enabled = false` before relying on the project override.

Any failing command fails the script and chezmoi retries it on the next apply.
The script reruns only when its inputs change (renderer, reconciler, package
tree); to force a pass, run the command above by hand or
`chezmoi state delete-bucket --bucket=scriptState`.

Without flags the script prints the full command list for a manual pass. It
emits the Codex refresh for default-loaded Codex plugins, then a Claude install
plus `enable` or `disable` per render policy, sorted by package id:

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

Content refreshes need no reinstall on Claude. Claude loads plugins from a
`directory`-source marketplace in place: with `claude -p ... --debug-file`,
the skill and hook paths for every `@prateek-local` plugin resolve under
`~/.agents/plugins/plugins/<pkg>/`, not under the copy `plugin install` left
in `~/.claude/plugins/cache/` (verified on Claude Code 2.1.258; GitHub-sourced
plugins do load from the cache). The docs describe cache copies for all
marketplace plugins, so re-check the debug paths after a Claude upgrade
before relying on this. `chezmoi apply` re-rendering the marketplace tree is
therefore the refresh, and the next session sees it. What the install record
still gates is loading at all: plugins are enumerated from
`installed_plugins.json`, which is why the apply step creates the record for a
new package before any project can enable it.

Do not render or edit `~/.claude/plugins/known_marketplaces.json`,
`~/.claude/plugins/installed_plugins.json`, or either tool's plugin cache.
