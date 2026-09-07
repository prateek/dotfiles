# Native plugin reconciliation

Run the helpers from the dotfiles repository root:

```sh
plugin_tools=.agents/skills/agent-skill-management/scripts
"$plugin_tools/reconcile-agent-plugins" --apply --agent claude --agent codex
```

`CODEX_HOME` selects the Codex profile for both this helper and chezmoi script 36.
An Orca account can use a separate home from canonical `~/.codex`. To refresh the
canonical profile as well, run `env -u CODEX_HOME "$plugin_tools/reconcile-agent-plugins" --apply --agent codex`.
Verify each profile that should receive the update; refreshing one does not
refresh the other's native cache.

The reconciler reads a validated artifact and explicit host policy, then changes
only `prateek-local`. Use `--plugins-root` and `--policy` for isolated state;
`--dry-run` reads native state and prints planned mutations. Invalid input fails
before native mutations. Each inventory and registration is read once.

Claude registers the local root, installs eligible plugins, refreshes changed
versions, restores `default_loaded`, and removes owned orphans. Native remove/install
supports downgrade and removes stale files. Unrelated marketplace records are kept.

Codex discovers `.agents/plugins/marketplace.json` relative to the registered
artifact root. `plugin add` refreshes its cache and enables the plugin. Enabled
defaults refresh automatically. Installed disabled plugins refresh with an explicit
`--refresh-disabled PACKAGE`; the adapter restores disabled state through the
native `config/value/write` API after each refresh, including failure paths.
Relocation requires remove/add registration, so installed disabled plugins are
remembered and refreshed on relocation too.

For first-time project use of a disabled Codex plugin, run `codex plugin add
PACKAGE@prateek-local`, then reconcile to restore its global disabled state and set
the trusted project's enabled override. Subsequent updates use the explicit refresh
option. Claude installs eligible plugins even when globally disabled. Pi follows
Claude selection; Cursor's marketplace/ACP policy is separate.

## Roll back a release with a receipt

Retain the matching host policy with each release. Restore that reviewed policy to
`home/.chezmoidata/agent_plugins.toml`, preserving any current local edits first.
The following commands assume `~/.agents/plugins.previous/release.json` exists and
use the current library's six disabled packages:

```sh
plugin_tools=.agents/skills/agent-skill-management/scripts
"$plugin_tools/materialize-agent-plugins" \
  --artifact-root "$HOME/.agents/plugins.previous" \
  --plugins-root "$HOME/.agents/plugins"

chezmoi --source "$PWD" diff --exclude=scripts -- \
  "$HOME/.claude/settings.json" "$HOME/.codex/config.toml" \
  "$HOME/.pi/agent/claude-plugins.json"
chezmoi --source "$PWD" apply --exclude=scripts -- \
  "$HOME/.claude/settings.json" "$HOME/.codex/config.toml" \
  "$HOME/.pi/agent/claude-plugins.json"

"$plugin_tools/reconcile-agent-plugins" --apply --agent claude --agent codex \
  --refresh-disabled design --refresh-disabled experimental \
  --refresh-disabled ios --refresh-disabled obsidian-wiki \
  --refresh-disabled superpowers --refresh-disabled utils-human

claude plugin list --json
codex plugin list --json
```

Adjust the refresh list to the restored policy if package membership or eligibility
changed. Omitting it at an unchanged root leaves installed disabled Codex caches at
their newer version. Verify native versions, enabled states, and changed payload
files, then restart the agent session. Keep full `chezmoi apply` paused until source
and the desired release agree: script 36 builds current source and could otherwise
reapply the newer release.

## First-migration rollback

The first migration can preserve a legacy marketplace at `.previous`: it has
`README.generated.md`, no `release.json`, and its Codex catalog is at
`marketplace.json`. The new materializer cannot use that legacy tree as an input.
Keep the baseline checkout or Git history at
`9a24d70664e52f119f00907929c2587305d54bc7` through cutover. Its renderer and source can
reconstruct a missing legacy artifact; `~/.agents/packages.retired` also retains
verified materialized legacy source.

Restore prior managed settings through the retained baseline source. Keep running
commands from the current checkout, which supplies the native RPC helper:

```sh
legacy_checkout=/path/to/retained/dotfiles-baseline
chezmoi --source "$legacy_checkout" diff --exclude=scripts -- \
  "$HOME/.claude/settings.json" "$HOME/.codex/config.toml" \
  "$HOME/.pi/agent/claude-plugins.json"
chezmoi --source "$legacy_checkout" apply --exclude=scripts -- \
  "$HOME/.claude/settings.json" "$HOME/.codex/config.toml" \
  "$HOME/.pi/agent/claude-plugins.json"
```

Do not run either version of script 36 during this manual recovery. If `.previous`
is the verified legacy tree, retain the failed new artifact and move it back:

```sh
failed_release_backup="$(mktemp -d "$HOME/.agents/failed-marketplace.XXXXXX")"
mv "$HOME/.agents/plugins" "$failed_release_backup/marketplace"
mv "$HOME/.agents/plugins.previous" "$HOME/.agents/plugins"

claude plugin marketplace add "$HOME/.agents/plugins" --scope user
claude plugin marketplace update prateek-local
if codex plugin marketplace list --json | jq -e \
  '.marketplaces | any(.name == "prateek-local")' >/dev/null; then
  codex plugin marketplace remove prateek-local
fi
codex plugin marketplace add "$HOME"
```

**Codex's legacy registration root is `$HOME`.** It finds the old catalog at
`$HOME/.agents/plugins/marketplace.json`, whose sources start with
`./.agents/plugins/plugins/`. The new artifact registers `$HOME/.agents/plugins`
because its catalog lives one level deeper. Native registration corrects the
baseline config's old root; do not overwrite that correction with another baseline
config apply while recovering.

Reinstall owned plugins through the native clients and restore the old defaults:

```sh
legacy_claude_installs="$(claude plugin list --json)"
for package in core design experimental ios mattpocock obsidian-wiki review superpowers utils-agent utils-human; do
  identity="$package@prateek-local"
  if printf '%s' "$legacy_claude_installs" | jq -e --arg id "$identity" \
    'any(.id == $id and .scope == "user")' >/dev/null; then
    claude plugin uninstall "$identity" --scope user
  fi
  claude plugin install "$identity" --scope user
  codex plugin add "$identity"
  case "$package" in
    core|mattpocock|review|utils-agent) ;;
    *) claude plugin disable "$identity" --scope user ;;
  esac
done

plugin_tools=.agents/skills/agent-skill-management/scripts
PYTHONPATH="$plugin_tools" python3 -B - <<'PY'
from codex_rpc import enabled_edit, requests
requests([enabled_edit(f"{name}@prateek-local", False) for name in
          ("design", "experimental", "ios", "obsidian-wiki", "superpowers", "utils-human")])
PY

claude plugin list --json
codex plugin list --json
```

Use the current checkout's `codex_rpc.py` for that last native configuration call.
The isolated rehearsal restored all ten version-1.0.0 plugin payloads, every file's
bytes/modes, the four enabled defaults, 162 Codex skills, and unrelated plugin state.
This procedure restores native operation without editing cache databases. Resolve
the source/registration differences before resuming ordinary full apply.
