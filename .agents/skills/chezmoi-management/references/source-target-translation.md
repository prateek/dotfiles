# Source ↔ Target Translation

Shared module for any mode that needs to map between target paths (`~/.zshrc`) and source paths (`home/dot_zshrc`). Always invoke a chezmoi command. Do not parse prefixes by hand.

## The Three Commands That Replace Guessing

```text
chezmoi source-path <target>     # absolute path to the source file/dir for a target
chezmoi target-path <source>     # absolute path to the target for a source file/dir
chezmoi managed                  # all entries chezmoi manages (dest paths)
chezmoi managed --include=files  # files only
chezmoi unmanaged                # files in destination NOT in source
```

If `chezmoi source-path` errors, the file is not managed. Use `chezmoi add` (plain files) or hand-author a source file, then re-run.

## Attribute Prefix Grammar

Prefixes encode metadata about the target. They strip from the filename and apply the listed effect. Multiple prefixes combine in a strict order (see "Order Rules" below).

| Prefix | Effect on target |
|---|---|
| `dot_` | Rename to leading dot (`dot_zshrc` → `.zshrc`) |
| `private_` | Mode 0600 (group/world bits removed) |
| `readonly_` | Mode 0400/0444 (write bits removed) |
| `executable_` | Executable bit set |
| `empty_` | Keep file even when empty |
| `encrypted_` | File is encrypted in source; decrypted at apply |
| `exact_` | Directory: remove anything not managed by chezmoi |
| `external_` | Directory: ignore attributes in child entries |
| `create_` | Ensure file exists; create if missing (don't overwrite) |
| `modify_` | Treat content as a script that modifies the existing target |
| `remove_` | Remove the named target if it exists |
| `symlink_` | Create symlink instead of file (target = file content) |
| `run_` | Treat as script (combines with `once_`/`onchange_`, `before_`/`after_`) |
| `literal_` | Stop parsing prefixes (allows literal underscored names) |

## Suffix Attributes

| Suffix | Effect |
|---|---|
| `.tmpl` | Treat content as a Go template |
| `.literal` | Stop parsing suffixes (preserve a literal `.tmpl` filename) |

Encryption suffixes strip after decryption: age uses `.age`; gpg uses `.asc`. Configurable in `chezmoi.toml`.

## Order Rules (Strict)

Prefixes must appear in the documented order for the target type. Wrong order = chezmoi ignores the prefix silently.

| Target type | Prefix order |
|---|---|
| Directory | `remove_` `external_` `exact_` `private_` `readonly_` `dot_` |
| Regular file | `encrypted_` `private_` `readonly_` `empty_` `executable_` `dot_` (suffix: `.tmpl`) |
| Create file | `create_` `encrypted_` `private_` `readonly_` `empty_` `executable_` `dot_` (suffix: `.tmpl`) |
| Modify file | `modify_` `encrypted_` `private_` `readonly_` `executable_` `dot_` (suffix: `.tmpl`) |
| Remove file | `remove_` `dot_` (no suffix) |
| Script | `run_` (`once_` or `onchange_`) (`before_` or `after_`) (suffix: `.tmpl`) |
| Symlink | `symlink_` `dot_` (suffix: `.tmpl`) |

Examples:

```text
private_dot_ssh/private_config           valid   -> ~/.ssh/config 0600
dot_private_ssh/...                      INVALID (dot_ before private_)
encrypted_private_dot_pgpass.tmpl        valid   -> ~/.pgpass 0600 (templated, encrypted)
run_once_before_00-homebrew.sh.tmpl      valid   -> bootstrap script, run once, before file updates
run_before_once_...                      INVALID (once_ before before_)
```

## Worked Examples From This Repo

```text
home/dot_zshrc                                            -> ~/.zshrc
home/dot_config/karabiner.edn.tmpl                        -> ~/.config/karabiner.edn (templated; karabiner.json is goku-generated and chezmoiignored)
home/Library/private_Preferences/modify_private_com.manytricks.Moom.plist.tmpl
                                                          -> ~/Library/Preferences/com.manytricks.Moom.plist 0600 (modify_ stub, templated; parent dir 0700 via private_Preferences/)
home/.chezmoiscripts/run_once_before_00-homebrew.sh.tmpl  -> script, no destination file
home/.chezmoitemplates/com.manytricks.Moom.plist.tmpl     -> not a target; included via {{ template "..." }}
```

## When Translation Goes Wrong

- **`chezmoi source-path ~/.zshrc` errors.** File is not managed. Decide: add it (`chezmoi add`) or treat as unmanaged.
- **`chezmoi target-path home/dot_zshrc` returns the wrong path.** Check that prefixes are in the strict order above.
- **You renamed a source file and `chezmoi diff` shows nothing.** Run `chezmoi managed` to confirm chezmoi sees the new name; old name may still be remembered in `chezmoi state`.
- **Encrypted file appears as garbage in editor.** Use `chezmoi edit <target>` — it decrypts to a temp dir and re-encrypts on save.

## Why Not Parse Prefixes In Code

The prefix list above is conservative. Future chezmoi versions may add prefixes. The grammar already has edge cases (encryption suffix stripping, `.literal` to escape). `chezmoi source-path` and `chezmoi target-path` are the only safe translation. Treat them as the API; treat the prefix table here as a reading aid.
