# Materialization

`agent-marketplace/build/marketplace` is disposable build output. Its release
receipt validates bytes, modes, catalog membership, and contained relative sources.
From the dotfiles repository root, a prebuilt artifact can be copied with:

```sh
.agents/skills/agent-skill-management/scripts/materialize-agent-plugins \
  --artifact-root /path/to/marketplace --plugins-root "$HOME/.agents/plugins"
```

This needs only Python's standard library. Omitting
`--artifact-root` runs the project's offline `just build` first, which needs the
provisioned APM environment.

## Tool lookup during chezmoi apply

When `just` resolves to a mise shim, the adapter runs `mise which just` from the
repository root to select its pinned version. This works when chezmoi runs its
scripts from the home directory and when the build uses a temporary project copy.
Provision the repo's tools first; the apply does not need an outer `mise exec`.
Run the scoped commands from the canonical checkout:

```sh
cd ~/dotfiles
marketplace_script="$PWD/home/.chezmoiscripts/run_onchange_after_36-agent-plugins.sh.tmpl"
chezmoi diff --include=scripts --source-path "$marketplace_script"
chezmoi apply --dry-run --verbose --include=scripts --source-path "$marketplace_script"
chezmoi apply --include=scripts --source-path "$marketplace_script"
```

A successful unchanged repeat apply skips script 36. When checking tool lookup,
use a changed source input and confirm materialization ran successfully. Native
cache verification and the maintenance round trip are recorded in the
[rollout verification](../../../../docs/research/apm-marketplace-migration-verification.md).

## Replacement and verification

The adapter validates and copies a complete sibling tree before replacing the
owned destination. Failed build, validation, or copy preserves the live tree. It
retains the previous artifact at `<plugins-root>.previous`, including across
identical retries; unrecognized destination
directories are refused. Native CLI reconciliation is a subsequent state change,
so a CLI failure can leave an updated artifact with old native caches. Report that
boundary and use [reconciliation and rollback](plugin-reconcile.md).

Chezmoi script 36 builds/materializes `~/.agents/plugins` and invokes native
reconciliation for the machine's selected CLIs. Its hash covers the project,
policy, and adapters. The three native config templates read policy directly on
every render; there are no committed generated config fragments to regenerate.

Script 35 retains the empty `~/.agents/skills` runtime stub and its `.system/`
content for Codex. It removes the old generated Claude skill root while preserving
hand-authored content. Keep generated marketplace and cache copies out of `home/`.
Source is the isolated root project; `.chezmoiroot` still points only to `home/`.

`~/.codex/skills` remains a managed symlink to `../.agents/skills`, and
`~/.claude/CLAUDE.md` links to `../.agents/AGENTS.md`. Claude, Codex, Cursor, and pi
marketplace configuration points at `~/.agents/plugins`; its two catalogs resolve
relative paths beneath `plugins/<package>/`. Do not capture script-created
marketplaces or native caches with `chezmoi add`.

For layout changes, run `just test-python -p test_packages.py` and the four config merge
checks. The combined isolated apply checks both scripts, managed symlinks, config
paths, runtime skill preservation, executable payloads, unknown legacy source,
and an unchanged repeat apply. `chezmoi verify --exclude=scripts` verifies direct
managed entries; artifact receipts and native inventory establish the remaining
state. Run the native host lane when changing client activation.

After successful reconciliation, script 36 checks old `~/.agents/packages`
against chezmoi's target archive from migration baseline `9a24d70664e5`. Matching
content moves to `~/.agents/packages.retired`. Unknown changes, unavailable Git
history, symlinks, or an existing backup preserve the directory and report why.
Keep that backup through rollout verification.
