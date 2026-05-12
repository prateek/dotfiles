# Workflow Mode

Apply / diff / verify / merge / edit / drift resolution / script execution. Load when running chezmoi commands or reasoning about what changes when `chezmoi apply` runs.

## Apply Lifecycle

```text
1. chezmoi diff                              # show destination -> target changes
2. chezmoi apply --dry-run --verbose         # structural preview (fast)
3. chezmoi apply                             # execute
4. chezmoi verify                            # exit 0 if all targets match target state
```

Add `--exclude=scripts` to the dry-run when scripts are unchanged and you only want to preview file diffs. Add `--include=scripts` when verifying a script change without running file updates.

`chezmoi diff` already accounts for templates and encrypted files. Trust it over `git diff` against the destination.

### Reading `chezmoi diff` (direction sense)

Output follows git diff convention: `- dest` first, `+ target` second. Translation:

- `-` lines are content currently in the destination (`~/<file>`); `chezmoi apply` will REMOVE them.
- `+` lines are content in the computed target state (after `.tmpl` expansion and merges); `chezmoi apply` will ADD them.
- Net effect: `chezmoi apply` aligns destination to target — direction is source → dest.

When in doubt, sidestep the `+/-` confusion entirely:

```text
diff <(chezmoi cat ~/.zshrc) ~/.zshrc   # rendered source vs current dest
```

(`chezmoi cat` renders the template; `cat $(chezmoi source-path …)` does not.)

### Reading `chezmoi status` (column legend)

`chezmoi status` prints two columns per entry. Both describe state transitions, not "source vs dest" positions:

- **Column 1** — change between last-written state and current actual destination. Tells you what has happened to the dest since chezmoi last touched it (manual edits, deletes).
- **Column 2** — change between current actual destination and target state. Tells you what `chezmoi apply` would do next.

Codes in either column: ` ` (no change), `A` (added), `D` (deleted), `M` (modified), `R` (script will run).

Combinations that show up:

| Code | Meaning |
|---|---|
| ` M` | Dest unchanged since last write, but target differs — `apply` will modify dest |
| ` A` | New source entry; dest does not exist yet — `apply` will create it |
| ` D` | Source removed an entry; dest still exists — `apply` will delete it |
| ` R` | A script will run on `apply` (`run_once_` first-seen content, or `run_onchange_` content changed) |
| `M ` | Dest was modified manually since last apply, and source has not moved — drift; reconcile via the decision tree below |
| `MM` | Dest was modified manually AND target now differs again — port the manual edit into source first, then `apply` |
| `MD` | Dest was modified manually; source now says delete — confirm intent before `apply` |
| `DA` | Dest was deleted manually (or by an external process) since last write; target still says the file should exist — `apply` will recreate it. If recreation is unwanted, add the path to `.chezmoiignore` or `chezmoi forget` it. |

For files that are NOT in chezmoi at all, use `chezmoi unmanaged` — they do not appear in `status`.

## Drift Resolution Decision Tree

The agent ran `chezmoi status` or `chezmoi diff` and saw drift. Walk the decision tree per file before mutating anything.

```text
Drift detected on TARGET (e.g., ~/.zshrc)
│
├── Source is the desired state (template, intentional)?
│       run: chezmoi apply <target>          # destination -> matches source
│
├── Target is the desired state (user edited live; want to capture)?
│   ├── Source is a plain file (no .tmpl, not encrypted_)?
│   │       run: chezmoi re-add <target>     # captures target into source
│   │
│   ├── Source is a .tmpl?
│   │       MANUAL: open the .tmpl, port the changes by hand,
│   │       then `chezmoi diff <target>` to confirm.
│   │       `chezmoi re-add` SKIPS templates (it will not overwrite
│   │       the .tmpl). `chezmoi add` would clobber the template
│   │       with rendered output — never use it for .tmpl.
│   │
│   └── Source is encrypted_?
│           run: chezmoi re-add <target>     # re-encrypts via configured key
│
├── Both sides are wrong (need a third state)?
│       run: chezmoi merge <target>          # invokes configured merge tool
│
└── Want to stop managing this file entirely?
        run: chezmoi forget <target>         # NOT destroy
```

Walk one file at a time. Confirm direction with `chezmoi diff <target>` after each step.

### Pre-check before `re-add`

`re-add` only acts on **regular file** sources (plain or `encrypted_`). It silently skips every other source type — `.tmpl`, `symlink_`, `modify_`, `create_`, `run_*` scripts, and `remove_`. If you reach for `re-add` on one of those, the command exits 0 and you may believe the live edit was captured when it wasn't.

Resolve the ambiguity with one command:

```text
chezmoi source-path ~/.zshrc
# Inspect the printed basename:
#   - ends in .tmpl                     -> SKIP re-add; edit the template by hand (chezmoi edit opens the .tmpl)
#   - starts with symlink_/modify_/     -> SKIP re-add; the source is a script or symlink, port the change to its source manually
#     create_/run_/remove_
#   - plain or encrypted_ regular file  -> re-add is safe
```

For non-regular sources, start with `chezmoi edit <target>` (see "Editing Source Files" below).

## Editing Source Files

Three options, in preference order:

1. **`chezmoi edit <target>`** — opens the source file, handles encryption transparently, preserves the `.tmpl` extension so editors detect it. Add `--apply` to apply on save.
2. **Direct edit under `home/`** — fine for plain templates and scripts; you must know the exact source path.
3. **Editing `~/<target>` directly** — discouraged. The next `chezmoi apply` will prompt or overwrite. If you did this anyway, see drift resolution above.

## Script Execution Model

Files under `home/.chezmoiscripts/` are scripts. Naming controls when they run.

| Prefix | When |
|---|---|
| `run_` | every `chezmoi apply` |
| `run_once_` | only if SHA256 of script content has not been seen before |
| `run_onchange_` | only if SHA256 of script content changed since last successful run |
| `run_before_` | before file updates |
| `run_after_` | after file updates |

**Hash is over script content, not arguments.** If a templated script renders to identical output, it does NOT re-run even if upstream data changed. To force a re-run, change the script content (a comment with the data hash works).

**Empty rendered script does not execute.** A `.tmpl` script that resolves to whitespace is skipped. Use this to gate per-OS or per-host scripts.

**Numeric ordering in this repo:**

```text
run_once_before_00-homebrew.sh.tmpl
run_once_before_05-core-tools.sh.tmpl
run_onchange_after_10-brew-bundle.sh.tmpl
run_onchange_after_10-zinit-compat.sh.tmpl
run_onchange_after_15-xcode.sh.tmpl
run_onchange_after_20-mise-install.sh.tmpl
run_onchange_after_25-hammerspoon.sh.tmpl
run_after_29-macos-defaults-force.sh.tmpl
run_onchange_after_30-macos-defaults.sh.tmpl
run_onchange_after_90-verify.sh.tmpl
```

Insert new scripts at unused numbers (e.g., `12-`, `35-`). Do not renumber.

Sudo keepalive is no longer a separate `99-sudo` script. Privileged non-Homebrew phases call the shared helper in `home/.chezmoitemplates/script_lib.sh`; it prompts once, keeps sudo warm while the parent `chezmoi apply` is alive, and cleans itself up shortly after the parent process exits. Homebrew Bundle is the exception: the wrapper checks `brew bundle check` first and then lets Homebrew own any cask/pkg sudo prompt because `brew` resets the sudo timestamp when it starts. If another script needs sudo, source the helper rather than reintroducing a tail script.

`macos-defaults.sh.tmpl` lives in `home/.chezmoitemplates/` (not as a sibling under `.chezmoiscripts/`). The `30-macos-defaults` script includes it via `{{ template ... }}` and embeds the rendered defaults payload hash plus snapshot-helper hash, so `run_onchange_` schedules it when source intent changes. Its runtime stamp compares the desired payload plus a read-only managed-key snapshot and skips the imperative defaults body when that pair is already converged. One-shot side effects inside the body, such as Launchpad reset, Spotlight reindex, `cfprefsd` nudges, and app restarts, intentionally run only when that body runs. `run_after_29-macos-defaults-force.sh.tmpl` renders empty unless `DOTFILES_FORCE_MACOS_DEFAULTS` is truthy; when set, it runs before the normal defaults wrapper and bypasses the stamp on every forced apply.

## Resetting Script State

When a `run_once_` or `run_onchange_` should run again without changing its content:

```text
chezmoi state delete-bucket --bucket=scriptState   # clears run_once_ history
chezmoi state delete-bucket --bucket=entryState    # clears run_onchange_ hashes
```

Use sparingly. Both clear ALL script history, not just one script.

## Path Translation

Always invoke `chezmoi source-path` / `target-path` / `managed`. Full grammar and edge cases in `source-target-translation.md`.

## Conflict Handling on Apply

When the target was modified outside chezmoi since the last apply, `chezmoi apply` prompts:

```text
overwrite? [y,n,a,q,h]
```

`a` = always overwrite this run. `n` = skip this file. `h` = show diff inline.

Prefer `n` + `chezmoi merge <target>` when you are not sure. The merge tool is configured at the user level (default `vimdiff`); confirm with `chezmoi doctor` if unsure.

## Rolling Back an Apply

Chezmoi has no built-in undo. Rollback for **declarative file state** is a git operation on the source tree, followed by a forward `chezmoi apply` to converge the destination. Rollback for **script side effects** is NOT automatic.

```text
chezmoi cd                              # spawn a shell in the source directory
git log --oneline -5                    # confirm the rev you want to roll back to
git reset --hard <rev>                  # destructive on source history — confirm <rev> first
exit                                    # leave the source-dir subshell

chezmoi diff --include=scripts          # see which scripts changed between current state and target
chezmoi status --include=scripts        # confirm what would re-run on apply
chezmoi apply                           # re-converge dest to the rolled-back source
```

Caveats:

- `git reset --hard` discards uncommitted source changes and rewrites history beyond `<rev>` — there is no second confirm. Verify the rev (`git show <rev>`) before running.
- Single-file rollback: prefer `git checkout <rev> -- <path>` over `git reset --hard`, then `chezmoi apply`.
- **Scripts persist in chezmoi state, not in the source tree.** `run_once_` execution lives in the `scriptState` bucket (keyed by content hash), `run_onchange_` in the `entryState` bucket (keyed by target path + content hash). A `git reset` rewinds the script source but does NOT mark the script as "not yet run." If the rolled-back source contains a script whose content matches one already in `scriptState`/`entryState`, it will be SKIPPED on the next apply.
- **External side effects do not revert.** Homebrew installs, macOS defaults writes, Xcode setup, `mise` installs, plist hooks, app launches — none of these undo themselves when source is rewound. Rollback is "what would the source declare on a fresh machine," not "restore the system to its prior state."
- To force script re-execution after rollback, see "Resetting Script State" above. Note both buckets clear ALL history of that kind, not just one script.

## Validation Before Declaring Done

```text
chezmoi diff                                            # always
chezmoi verify                                          # when claiming "applied"

# file-only changes (scripts untouched):
chezmoi apply --dry-run --verbose --exclude=scripts

# script changes (scripts MUST be in scope to be validated):
chezmoi diff --include=scripts
chezmoi apply --dry-run --verbose --include=scripts
shellcheck <(chezmoi execute-template < home/.chezmoiscripts/<script>.sh.tmpl)
```

Use `--exclude=scripts` only when scripts are unchanged. When scripts changed, excluding them hides the very surface you need to verify. If `chezmoi verify` exits non-zero, list each failing target before mutating.

## Common Pitfalls

- **Editing the target then expecting apply to merge.** It prompts; blind `a` overwrites the user's edit with source.
- **Forgetting `--exclude=scripts` in dry-run.** Some scripts cannot dry-run cleanly; exclude them when previewing file diffs.
- **Treating `git diff` on the destination as the source of truth.** Use `chezmoi diff` — it accounts for templates and encryption.
