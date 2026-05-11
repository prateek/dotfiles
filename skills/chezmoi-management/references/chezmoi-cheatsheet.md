# Chezmoi Cheatsheet

Self-contained reference. Vendored so the skill works without chezmoi.io being reachable. Update when chezmoi adds, renames, or removes commands (see `meta-skill-maintenance.md`).

Last verified against chezmoi behavior current as of 2026-05.

## "Let Chezmoi Tell You" Commands

Invoke these instead of guessing or paraphrasing.

| Command | Use when |
|---|---|
| `chezmoi source-path [target]` | Translate `~/.<file>` → source path |
| `chezmoi target-path [source]` | Translate source → `~/.<file>` |
| `chezmoi managed` | List managed entries (filter with `--include`/`--exclude`) |
| `chezmoi unmanaged` | List destination files not in source |
| `chezmoi diff [target]` | Show pending dest → target changes (template- and encryption-aware) |
| `chezmoi apply --dry-run --verbose` | Preview without modifying |
| `chezmoi verify [target]` | Exit 0 if target matches target state |
| `chezmoi data` | Dump the data dict templates see (JSON/YAML) |
| `chezmoi execute-template < file.tmpl` | Render a template ad-hoc for testing |
| `chezmoi execute-template '{{ .chezmoi.os }}'` | Evaluate an inline template |
| `chezmoi state` | Inspect script/entry state buckets |
| `chezmoi state delete-bucket --bucket=<name>` | Reset script history |
| `chezmoi merge [target]` | Three-way merge (configured tool) |
| `chezmoi re-add [target]` | Re-add a modified target. Preserves `encrypted_` (re-encrypts) and `private_`/`readonly_`/etc. attributes. **Skips `.tmpl` sources** — port template edits by hand. |
| `chezmoi add --force [target]` | Force add (does NOT preserve template suffix; avoid for `.tmpl`) |
| `chezmoi forget [target]` | Stop managing (no destructive side effects) |
| `chezmoi destroy [target]` | DANGEROUS: remove from source, dest, AND state |
| `chezmoi edit [target]` | Open source in editor (handles `.tmpl` and encrypted) |
| `chezmoi status` | Concise per-file status (`A`dded / `M`odified / `D`eleted / `R`un) |
| `chezmoi doctor` | Diagnose setup (encryption keys, merge tool, source dir) |
| `chezmoi cd` | Spawn a shell in the source directory |
| `chezmoi cat-config` | Dump effective config |
| `chezmoi dump` | Dump computed target state (for debugging) |

## Must-Not-Get-Wrong Punchlist

(SKILL.md Universal Rules cover destructive-command discipline, edit-target-by-hand, and `home/.chezmoidata/` templating. The items below are the cheatsheet-specific ones not stated there.)

1. **Attribute prefix order is strict and per-target-type.** `private_dot_ssh` valid; `dot_private_ssh` silently ignored. See `source-target-translation.md`.
2. **`run_onchange_` / `run_once_` hash script content, not arguments.** Identical rendered output → no re-run. To force, change content (a comment with the input hash works).
3. **`chezmoi apply` prompts on dest drift.** Options: `y` overwrite, `n` skip, `a` overwrite all this run, `q` quit, `h` show diff. Prefer `n` + `chezmoi merge`.
4. **Encrypted files are handled transparently by `chezmoi edit`/`apply`.** Do not decrypt manually.
5. **A `.tmpl` resolving to empty/whitespace does not execute (scripts).** Use as an OS/host gate.
6. **`chezmoi verify` exit code matters.** 0 = match, non-zero = drift. Check exit, do not parse output.

## Template Engine Quick Reference

- Engine: Go `text/template` (HTML escaping is OFF by default).
- Data sources: `.chezmoi` built-ins, `home/.chezmoidata/` files (TOML/YAML/JSON/JSONC), `home/.chezmoidata/` directories (lex-merged), config `[data]` section.
- `home/.chezmoidata/` directories merge in lexical order. Dicts merge; non-dicts replace.
- Includes: `{{ template "name" . }}` and `{{ template "name" $context }}` for fragments under `home/.chezmoitemplates/`.
- Functions: `include`, `includeTemplate`, `output`, `fromJson`, `fromYaml`, `glob`, `lookPath`, `env`, `promptString` (init only), `onepassword`, `onepasswordRead`, `bitwarden`, `pass`, `gopass`, `vault`, `keepassxc`.
- Built-in vars (subset): `.chezmoi.os`, `.chezmoi.arch`, `.chezmoi.hostname`, `.chezmoi.username`, `.chezmoi.sourceDir`, `.chezmoi.homeDir`, `.chezmoi.config`.
- Missing-key default: error. Configurable in chezmoi.toml.

## Recipes

**Test a template without applying:**
```text
chezmoi execute-template < home/.chezmoitemplates/com.example.app.plist.tmpl
```

**See what the template engine will see:**
```text
chezmoi data --format=yaml
```

**Find which source file produces a target:**
```text
chezmoi source-path ~/.zshrc
```

**Preview an apply without touching scripts:**
```text
chezmoi apply --dry-run --verbose --exclude=scripts
```

**Re-run a `run_onchange_` without changing its content:**
```text
chezmoi state delete-bucket --bucket=entryState
chezmoi apply
```

**Force re-encryption of a managed file with a new key:**
```text
chezmoi re-add <target>
```

**Stop managing without deleting:**
```text
chezmoi forget ~/.bad-config
```

**See pending changes for one file:**
```text
chezmoi diff ~/.zshrc
```

**Confirm config and state look right:**
```text
chezmoi doctor
chezmoi cat-config
```

## Application Order (`chezmoi apply`)

1. Read source state and destination state.
2. Compute target state (templates, includes, encryption).
3. Run `run_before_` scripts in alphabetical order.
4. Update entries (directories before their files; alphabetical within a directory).
5. Run `run_after_` scripts in alphabetical order.

`run_` scripts without `before_`/`after_` interleave with file updates in alphabetical order. Avoid this — prefer explicit `before_`/`after_` for clarity.

## Encryption Notes

- Supported: age (recommended), gpg, git-crypt, transcrypt.
- This repo does not currently use `encrypted_` source files; secrets come via 1Password (`op://`). If you add encrypted files, configure age in `chezmoi.toml` first and document in `packages-and-secrets.md`.
- `chezmoi add --encrypt <target>` adds a new file as encrypted.
- `chezmoi re-add <target>` preserves encryption when re-adding.

## Recovery Cheatsheet

| Situation | Command |
|---|---|
| Edited target by hand, want to capture | `chezmoi re-add <target>` (skips `.tmpl`; for templates, port by hand) |
| Edited target by hand, source is `.tmpl` | Manually port to `.tmpl`; `chezmoi diff` to confirm |
| Deleted target by hand | `chezmoi apply <target>` (re-creates from source) |
| Want to stop managing | `chezmoi forget <target>` |
| Want to delete from everywhere | `chezmoi destroy <target>` (extreme caution) |
| Want to roll back source | `git checkout HEAD -- <source>` then `chezmoi apply` |
| Template is broken | `chezmoi execute-template < <file>` to see error |
| Apply hangs on prompt | Run with terminal attached; `chezmoi merge --force` is NOT a thing — use the merge tool |
| Setup looks broken | `chezmoi doctor` |
