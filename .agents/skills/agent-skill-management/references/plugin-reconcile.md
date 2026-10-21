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

`--overlay --plugins-root DIR` reconciles a hand-maintained marketplace instead,
such as the work overlay ([ADR 0039](../../../../docs/adr/0039-work-overlay-in-work-repo.md)).
It reads DIR's Claude and Codex catalogs directly, with no build, receipt, or
policy, takes the marketplace name from them, and refuses `prateek-local`. Each
plugin is installed and enabled for the agents whose catalog lists it (omp follows
the Claude catalog); a plugin in both catalogs must point at one directory with
matching manifest versions. Chezmoi script 39 runs it. `--json` prints the
marketplace name and each client's eligible plugins instead, which
`work-overlay.tmpl` reads so the templates never parse the catalogs themselves.

Claude registers the local root, installs every published plugin, refreshes changed
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
option. Claude installs every plugin even when globally disabled. Pi follows
Claude selection.

cursor-agent installs plugins only from Cursor's server-side marketplaces, so
`--agent cursor-agent` links each default-loaded package's skills into
`~/.cursor/skills`, one of the user skill roots cursor-agent scans. It owns only
links that point under the reconciled root, removes those no longer desired,
and leaves any other entry in place with a warning, including one that shares a
skill name. The upstream reconciler skips cursor-agent.

`reconcile-upstream-agent-plugins` installs every official plugin on every
client. Codex accepts an upstream snapshot holding either its own catalog or
Claude's. Entries in `retired_agent_upstream_plugins` are uninstalled from each
client; the config templates pin them disabled because settings merges keep
stale keys. Retire an official install there when a kept local adapter replaces
it.

## Roll back a release with a receipt

Retain both policy files with each release. Restore its reviewed
`home/.chezmoidata/agent_plugins.toml` and
`home/.chezmoidata/agent_upstream_plugins.toml`, preserving current local edits
first. For a release predating official marketplace adoption, the upstream
policy is `agent_upstream_plugins = []`. Disable/remove newly adopted official
plugins through each native client before re-enabling restored local wrappers;
restoring the artifact does not undo their installations. Reapply Pi's matching
desired-state file and reload its extension as well.

The following commands assume `~/.agents/plugins.previous/release.json` exists.
Derive the disabled refresh list from the restored local policy:

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

refresh_args=()
while IFS= read -r package; do
  refresh_args+=(--refresh-disabled "$package")
done < <(python3 - <<'PYTHON'
import tomllib
from pathlib import Path
policy = tomllib.loads(Path("home/.chezmoidata/agent_plugins.toml").read_text())["agent_plugins"]
for name, entry in policy.items():
    if entry["codex"] and not entry["default_loaded"]:
        print(name)
PYTHON
)
"$plugin_tools/reconcile-agent-plugins" --apply --agent claude --agent codex "${refresh_args[@]}"

claude plugin list --json
codex plugin list --json
```

Adjust the refresh list to the restored policy if package membership changed. Omitting it at an unchanged root leaves installed disabled Codex caches at
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
