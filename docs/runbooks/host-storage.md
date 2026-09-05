---
status: active
doc_type: runbook
owner: Prateek
created: 2026-09-05
updated: 2026-09-05
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
