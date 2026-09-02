---
status: current
doc_type: reference
owner: Prateek
created: 2026-09-02
updated: 2026-09-02
related:
  - chezmoi-architecture.md
  - ../runbooks/linux-work-devpod-orca.md
  - ../plans/linux-work-devpod-orca-pilot-plan.md
status_detail: "Execution order and design rules for chezmoi config hooks, source scripts, init, apply, and modify targets."
---

# Chezmoi hook lifecycle

Chezmoi has two automation mechanisms with different lifecycles:

- **Config hooks** are `[hooks.<event>.pre]` and
  `[hooks.<event>.post]` entries in `chezmoi.toml`. An event can be a command
  such as `init` or `apply`, or the special `read-source-state`,
  `git-auto-commit`, or `git-auto-push` event. Hooks run even under
  `--dry-run`.
- **Source scripts** are files with a `run_` source-state attribute, normally
  under `home/.chezmoiscripts/`. They are target-state entries evaluated and
  run as part of `apply`; dry runs do not execute them.

`modify_` files are not hooks. Chezmoi executes a modifier while computing
target state, before any `run_before_` source script runs.

Primary upstream references:

- [Hooks](https://www.chezmoi.io/reference/configuration-file/hooks/)
- [Application order](https://www.chezmoi.io/reference/application-order/)
- [Source-state attributes](https://www.chezmoi.io/reference/source-state-attributes/)
- [Init](https://www.chezmoi.io/reference/commands/init/)

## Init

`chezmoi init` proceeds in this order:

1. Initialize or clone the source directory.
2. Render `.chezmoi.<format>.tmpl` and reload the resulting config.
3. Run the apply lifecycle only when `--apply` was passed.
4. Perform requested purge operations.

Plain `init` does not execute source scripts. This repo's config template uses
the init phase only to persist first-machine identity and config hooks; it
cannot use `.chezmoidata`, because source state has not been read yet.

Like every command, `init` is eligible for `hooks.init.pre` and
`hooks.init.post`. Do not use them as a first-install prerequisite: a
first-ever init begins before the generated config exists. Put prerequisites
for reading source state in the generated `read-source-state.pre` hook instead.

For `init --apply`, chezmoi reloads the generated config before entering apply,
so a newly configured `read-source-state.pre` hook is available to that apply.
The Spacejunk path currently invokes plain `init`, then `chezmoi data`, then
`apply`; `data` is the first source-reading command and therefore invokes the
same hook before apply.

## Apply

The relevant apply order is:

1. Run the `apply.pre` config hook.
2. Run `read-source-state.pre`, then read source state and run
   `read-source-state.post`.
3. Read destination state.
4. Compute target state. This renders templates and executes `modify_`
   programs.
5. Execute `run_before_` source scripts alphabetically.
6. Update target entries alphabetically. Unqualified `run_` scripts are
   interleaved here by target name.
7. Execute `run_after_` source scripts alphabetically.
8. Run the `apply.post` config hook.

`run_before_` means before destination updates, not before target-state
computation. A program needed by a modifier must already exist or be installed
by `read-source-state.pre`.

Source scripts can combine one frequency attribute with one timing attribute:

- No frequency attribute: run on every apply.
- `once_`: run once per successfully executed rendered-content hash.
- `onchange_`: rerun when that script filename's rendered content changes.
- `before_`: run after target computation but before destination updates.
- No timing attribute: run in target-name order among normal updates.
- `after_`: run after all destination updates.

Template rendering occurs before the `once_` or `onchange_` hash is compared,
so embedding another file's checksum makes its changes retrigger a script.

## Repository wiring

The generated config for `work × linux` declares:

- `hooks.read-source-state.pre` pointing to
  `scripts/chezmoi-hooks/headless-uv.sh`.
- `scriptEnv.PATH` with `~/.local/bin` first, so uv installed by the hook is
  visible to modifiers and source scripts.

The hook is a direct repository script, not a template or managed target. It
installs checksum-verified uv when missing and otherwise exits immediately.
Because source-reading commands include `data`, `status`, `diff`, and
`managed`, the hook must:

- be fast and idempotent;
- never invoke chezmoi recursively;
- write diagnostics only to stderr, so machine-readable stdout stays valid;
- tolerate running during `--dry-run`, which still executes config hooks.

After source state is readable, the headless profile executes its uv-backed
Claude settings modifier during target computation. Its only enabled apply
script is `run_onchange_after_36-agent-plugins.sh.tmpl`, which renders
`~/.agents/plugins` after destination updates. Other apply scripts remain
ignored for this profile.

On Darwin, the generated config instead declares `hooks.apply.pre` and
`hooks.apply.post` for plist safety. Those hooks guard running applications
around preference writes and are unrelated to the Linux uv bootstrap.

## Inspection

Use these commands to see the active config and source scripts:

```sh
chezmoi dump-config
chezmoi managed --include=scripts
chezmoi apply --dry-run --verbose
```

Remember that the final command still executes config hooks, although it does
not execute source scripts.
