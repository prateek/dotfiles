---
status: active
doc_type: runbook
owner: Prateek
created: 2026-09-05
updated: 2026-09-17
related:
  - ../references/chezmoi-hook-lifecycle.md
  - ../plans/ssd-arq-layout-plan.md
---

# Host storage

On m4mini, `chezmoi apply` requires the external APFS code volume at
`~/code`. The `code_volume_uuid` fact in
[`machines.toml`](../../home/.chezmoidata/machines.toml) identifies the volume:
`8C16DA8F-1B9B-4ADC-9C7D-EFA8FF8B15D7`. Volume names and `diskN` numbers are
not used as its identity.

## Bootstrap and normal apply

Keep the bootstrap checkout at `~/dotfiles` on the internal disk, as in the
README. Attach the already provisioned SSD, then use the normal
`chezmoi init --apply` or `chezmoi apply` workflow. The existing apply pre-hook
reconciles storage before plist inspection or target computation, including
`modify_` programs. No re-init is needed when the host UUID fact changes.

The hook uses the system Bash and Perl with macOS disk tools, so it works
before Homebrew, uv, or Python installation. It preserves the caller's
config file and data overrides when resolving host facts. The mount helper
checks that the UUID names a writable external APFS volume, and that the
requested mount path is a native directory.

When setup is needed, it uses `sudo vifs` to add the UUID-based `/etc/fstab`
entry while preserving unrelated entries. It mounts the existing volume at
`~/code`. If it was automatically mounted elsewhere, a normal unmount must
succeed first. A busy volume stops apply and identifies the path to release.
It never forces an unmount or formats a disk.

Before mounting onto an empty local directory, it makes that directory
root-owned with mode `0555`. This prevents ordinary writes into the internal
fallback directory while the SSD is absent. It never hides a directory
containing local files. Symlinks, conflicting fstab entries, and another
volume at the target path also stop setup.

The helper verifies the final mount and enabled file ownership. A volume
already mounted correctly with a matching fstab entry needs no sudo or
remount. It does not change existing file ownership recursively.

The pre-hook runs on every apply, even when dotfiles have not changed.
Mount setup belongs here because a `run_before_` script would run after
chezmoi has read destination state. There is no additional source script
to leave `chezmoi status` reporting pending work after a successful apply.

## Agent data stores

On m4mini, agentsview's archive and qmd's index and models live on the code
volume. The `agentsview_data_dir` and `qmd_cache_dir` host facts name the
stores. On every apply, `run_after_34-agent-data-store.sh` links
`~/.agentsview` and `~/.cache/qmd` to them.

qmd has no index-directory setting apart from `XDG_CACHE_HOME`, so the link is
all it needs. agentsview needs both the link and `AGENTSVIEW_DATA_DIR`:

- The chezmoi `modify_` template and the session archive's sync script edit
  `~/.agentsview/config.toml` directly, so they go through the link.
- agentsview refuses to start from a symlinked data directory, so the daemon
  and CLI need the real path. `$ZDOTDIR/.zshenv` exports it, and the desktop
  app picks it up through its login-shell probe. The session sync launch agent
  and script 38's daemon restart set it explicitly, and the Raycast
  `orca-agent-session` script resolves it from the link.

A launcher without the variable cannot start a second archive on the boot
disk: agentsview exits with `~/.agentsview is a symlink`. `serve status`
without the variable reports that no server is running even when one is.

chezmoi replaces a symlinked directory it manages with a real directory, so
`.chezmoiignore` skips `~/.agentsview` on hosts with the fact. Script 34 runs
the same `modify_private_config.toml.tmpl` through the link instead. When the
SSD is absent, the links dangle and the mount point is read-only, so both
tools fail instead of writing to the boot disk.

The script never hides an existing directory. It warns and leaves the data in
place. To migrate an existing store, stop its consumers
(`agentsview serve stop`, and any `qmd` process), move the directory aside,
copy it into the store with `rsync -a`, and compare the files. Then rerun
apply, start agentsview with `AGENTSVIEW_DATA_DIR` set, and remove the
original once the tool reads from the store.

## Scope and recovery

The rule applies only on macOS to a host with `code_volume_uuid` configured
and `run_install_scripts = true`. Other hosts are unaffected. The existing
`run_install_scripts = false` setting also skips this bootstrap prerequisite.
`DOTFILES_SKIP_PLIST_HOOKS=1` does not disable it.

`apply --dry-run` does not reconcile mounts. Neither do `status`, `diff`, or
plain `init` without `--apply`. The `/etc/fstab` entry supplies persistent
mount configuration for macOS; chezmoi checks and repairs it during apply.
The hook parses JSON overrides as data before inspecting preview flags;
literal `-n` text in an override cannot bypass the mount check. The last
actual dry-run flag wins, including an explicit `--dry-run=false`.
Attached option values such as `-c/path/config.toml` are consumed as values,
so an `n` in a config or source path cannot disable the prerequisite.

To inspect the prerequisite without changing storage:

```sh
bash scripts/storage/ensure-code-volume --check \
  8C16DA8F-1B9B-4ADC-9C7D-EFA8FF8B15D7 "$HOME/code"
```

For a missing or locked disk, attach or unlock it and rerun apply. For a busy
mount, stop its consumers and retry. Existing local code needs a separate,
verified migration before the helper can mount over that path. If fstab has
a conflict, inspect it with `sudo vifs`; the helper leaves conflicting
entries intact.

Replacing or erasing the SSD requires an explicit provisioning operation
and an update to its UUID fact. This helper never provisions a replacement
disk automatically. The remaining storage consolidation and Arq selection
work is tracked in the [SSD layout plan](../plans/ssd-arq-layout-plan.md).
