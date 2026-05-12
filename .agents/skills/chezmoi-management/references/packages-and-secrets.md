# Packages and Secrets Mode

Managing data files under `home/.chezmoidata/`, rendering Brewfiles, gating installs via `DOTFILES_INSTALL_*` env vars, wiring 1Password `op://` references.

## Files Owned By This Mode

```text
home/.chezmoidata/packages.toml          # Homebrew formulae, casks, MAS apps, profiles
home/.chezmoidata/secrets.toml           # [secrets.refs] obfuscated op:// refs only
home/.chezmoidata/licenses.toml          # [licenses] paths = [...] target paths (refs live in secrets.toml)
home/.chezmoitemplates/brewfile.tmpl     # renders to a Brewfile from packages.toml
```

`home/.chezmoidata/` files are loaded BEFORE the template engine starts. **They cannot themselves be templates.** Dynamic data goes in `home/.chezmoi.<format>.tmpl` at the source root, or via template functions in the templates that consume the data.

## Packages.toml Structure

`packages.toml` uses a top-level `[packages]` table with a `default_profile` and `[packages.profiles.<name>]` sub-tables. Each profile body uses **inline arrays of inline tables**. Do NOT use TOML array-of-tables syntax (`[[packages.profiles.core.brews]]`) — that mixes two definitions of the same key and is invalid against the existing inline shape. The Brewfile renderer reads `.packages.profiles.<active>`, so the shape and key names must match.

Profile keys (all optional except `description`):

| Key | Consumed by | Use for |
|---|---|---|
| `description` | docs / inventory | One-line profile label |
| `taps` | `brewfile.tmpl` | Homebrew taps |
| `brews` | `brewfile.tmpl` | Homebrew formulae that install at standard `chezmoi apply` time |
| `casks` | `brewfile.tmpl` | Homebrew casks |
| `mas` | `brewfile.tmpl` (gated on `DOTFILES_INSTALL_MAS_APPS=true`) | Mac App Store entries |
| `xcode_required_brews` | `home/.chezmoiscripts/run_onchange_after_15-xcode.sh.tmpl` | Formulae that need Xcode CLT first; installed AFTER Xcode setup, NOT in the main Brewfile |
| `disabled_casks` | inventory only — NOT consumed by `brewfile.tmpl` | Record of casks intentionally excluded with the reason. To actually disable a cask, remove it from `casks`; the `disabled_casks` entry is documentation, not a filter. |

```toml
[packages]
default_profile = "full"

[packages.profiles.core]
description = "Core package set"
taps  = [ { name = "1password/tap" }, { name = "felixkratz/formulae" } ]
brews = [ { name = "git" }, { name = "gh" }, { name = "mise" } ]
casks = [ { name = "1password" }, { name = "ghostty" } ]

[packages.profiles.full]
description = "Full package set"
taps  = [ { name = "1password/tap" } ]
brews = [ { name = "postgresql@16" } ]
casks = [ { name = "docker" }, { name = "tableplus" } ]
mas   = [ { name = "Xcode", id = 497799835 } ]   # id is INTEGER (renderer interpolates as %d)
xcode_required_brews = [ { name = "ios-deploy" } ]
disabled_casks       = [ { name = "intellij-idea", reason = "decommissioned" } ]   # documentation only — to disable, also remove from casks
```

Profile activation is controlled by `DOTFILES_INSTALL_PROFILE` (overrides `default_profile`). Valid values today: `core`, `full`.

## Brewfile Rendering

The same logic lives in `home/.chezmoitemplates/brewfile.tmpl` and runs during `chezmoi apply` via `home/.chezmoiscripts/run_onchange_after_10-brew-bundle.sh.tmpl`. To verify your edit before apply:

```text
make test-render-brewfile                          # validates both profiles render
scripts/packages/render-brewfile --profile core    # eyeball
scripts/packages/render-brewfile --profile full    # eyeball
```

**MAS entries need an explicit flag to appear in output.** The plain `render-brewfile` invocations above omit `mas` lines because the wrapper script clears `DOTFILES_INSTALL_MAS_APPS` from the environment by default (`env -u DOTFILES_INSTALL_MAS_APPS`); setting it inline like `DOTFILES_INSTALL_MAS_APPS=true scripts/packages/render-brewfile ...` does NOT work for that reason. Use the wrapper flag instead:

```text
scripts/packages/render-brewfile --profile full --include-mas
```

`--include-mas` re-injects `DOTFILES_INSTALL_MAS_APPS=true` into the renderer's environment, so the rendered Brewfile contains the `mas "<name>", id: <int>` lines. Diff the with-flag vs without-flag output to confirm the gate is doing its job.

## Profile And Install Env Vars

Two flavors of env var:

**Init values (persisted to `~/.config/chezmoi/chezmoi.toml` during `chezmoi init`):** after init, the persisted answer is baked in — see the persistence note below the apply-time table for how to change it.

| Init env var | Persisted as | Interactive prompt? | Default |
|---|---|---|---|
| `DOTFILES_INSTALL_PROFILE` | `install_profile` | Yes (`promptStringOnce`) — env overrides the prompt | `full` (matches `default_profile` in `packages.toml`) |
| `DOTFILES_RUN_INSTALL_SCRIPTS` | `run_install_scripts` | Yes (`promptBoolOnce`) — env overrides the prompt | `true` |
| `DOTFILES_APPLY_DEFAULTS` | `apply_macos_defaults` | Yes (`promptBoolOnce`) — env overrides the prompt | `true` |
| `DOTFILES_SECRETS_ENABLED` | `secrets_enabled` | Yes (`promptBoolOnce`) — env overrides the prompt | `false` |
| `DOTFILES_INSTALL_XCODE` | `install_xcode` | **No** — env-or-default only; not prompted. The `15-xcode` script also re-reads the env var at apply time so `DOTFILES_INSTALL_XCODE=true chezmoi apply` triggers a one-off download without re-init. | `false` |
| `DOTFILES_MANAGE_ZINIT_EXTERNAL` | `manage_zinit_external` | **No** — env-or-default only; not prompted. `home/.chezmoiexternal.toml.tmpl` gates on the persisted `.manage_zinit_external` value, NOT on the env var, so a one-off `DOTFILES_MANAGE_ZINIT_EXTERNAL=false chezmoi apply` does NOT disable zinit on an already-initialized machine — re-init or `chezmoi edit-config` to change. (Test harnesses such as `scripts/audit/zsh-fresh-shells.zsh` export this var around BOTH init and apply in their own private XDG dir; only the init export ends up persisted, and the apply-side export is inert for the external gate because the template reads the persisted data value.) | `true` |

**Apply-time env vars (read on every `chezmoi apply` via `env` template function):**

| Apply env var | Effect |
|---|---|
| `DOTFILES_INSTALL_MAS_APPS` | Renders MAS entries in Brewfile only when `true` |
| `DOTFILES_INSTALL_XCODE` | One-off apply-time override that triggers the Apple ID-backed Xcode download in `run_onchange_after_15-xcode.sh.tmpl`. Persisted value comes from `install_xcode`; set this env var on a specific apply to opt into the download without re-initing. |
| `DOTFILES_HOMEBREW_BUNDLE_JOBS` | Parallelism for `brew bundle install` |
| `DOTFILES_HOMEBREW_DOWNLOAD_CONCURRENCY` | Per-bottle download concurrency for Homebrew |
| `DOTFILES_PLIST_VERBOSE` | Verbose logging from the plist merge engine |
| `DOTFILES_RELAUNCH_AFTER_APPLY` | Whether the post-apply hook relaunches affected apps |
| `DOTFILES_SKIP_APP_RESTART` | Skip app-restart side effects in plist hooks |
| `DOTFILES_SKIP_LSREGISTER` | Skip Launch Services re-registration in plist hooks |
| `DOTFILES_SKIP_PLIST_HOOKS` | Disable the `scripts/chezmoi-hooks/post-apply-plists.sh` hook |
| `DOTFILES_SKIP_REINDEX` | Skip Spotlight reindex side effects in plist hooks |
| `DOTFILES_FORCE_MACOS_DEFAULTS` | Truthy values (`1`, `true`, `yes`, `on`) ignore the macOS defaults payload/snapshot stamp and run the defaults script again |

Init-prompt vars are persisted at init time. Setting them on a later `chezmoi apply` (e.g., `DOTFILES_APPLY_DEFAULTS=false chezmoi apply`, `DOTFILES_SECRETS_ENABLED=true chezmoi apply`) does NOT take effect — the persisted answer in `~/.config/chezmoi/chezmoi.toml` wins. To change, run `chezmoi edit-config` or re-init.

**Out of scope for this skill** (test/VM/harness/shell-startup vars; do not trigger on these): `DOTFILES_AUDIT_DIRENV`, `DOTFILES_CAPTURE_ROOT`, `DOTFILES_ROOT`, `DOTFILES_SKIP_LAUNCHCTL_SYNC`, `DOTFILES_SUDO_*`, `DOTFILES_TART_*`, `DOTFILES_TRACE*`, `DOTFILES_WARM_*`.

## Secrets.toml And 1Password

The repo uses 1Password CLI (`op`) via chezmoi template functions. No `encrypted_` source files; secrets are pulled at apply time.

**Committed `secrets.toml` uses `[secrets.refs]` with obfuscated op:// refs only:**

```toml
[secrets.refs]
# correct: vault-id / item-id / field-id (IDs, not names)
bettertouchtool_license = "op://abcd1234efgh5678/ijkl9012mnop3456/credential"

# empty string = "not configured on this machine"
moom_license = ""
```

```toml
# WRONG: human-readable, leaks metadata
moom_license = "op://Personal/Moom/license"
```

Empty value semantics: an empty ref means "not configured on this machine." The corresponding template renders empty and `.chezmoiignore` skips the path while `secrets_enabled=false`. When `secrets_enabled=true` but the ref is empty, the license template fails loudly.

Per-machine human-readable overrides go in `~/.config/chezmoi/chezmoi.toml.local`, which is NOT committed. The local file can use human-readable `op://` paths with vault and item names for convenience.

## Licenses.toml

`licenses.toml` lists target paths (relative to `$HOME`) for license files that get materialized via secret-backed chezmoi templates. It does NOT contain op:// refs — those live in `secrets.toml` under `[secrets.refs]` with matching key names.

```toml
[licenses]
paths = [
  "Library/Application Support/BetterTouchTool/license.bttlicense",
  "Library/Application Support/Many Tricks/Moom/Registration",
  "Library/Application Support/Alfred/License/Alfred.alfredlicense",
]
```

`.chezmoiignore` reads `licenses.paths` to skip these targets when `secrets_enabled=false`. A `secrets.paths` table was once planned but was retired as always-empty; do not add it back unless the ignore template is updated to consume it.

## Secret-Backed Template Pattern

A template that needs a secret reads `.secrets.refs.<name>` via `onepasswordRead`, gated by `secrets_enabled`:

```text
{{- if .secrets_enabled -}}
{{- $ref := .secrets.refs.bettertouchtool_license -}}
{{- if $ref -}}
{{ onepasswordRead $ref }}
{{- else -}}
{{- /* secrets_enabled=true but ref is empty — fail loudly */ -}}
{{ fail "bettertouchtool_license: secrets_enabled=true but ref is empty" }}
{{- end -}}
{{- end -}}
```

`secrets_enabled` is set during `chezmoi init` (default `false`; override with `DOTFILES_SECRETS_ENABLED=true` at init time). To change it on an existing machine, `chezmoi edit-config` or re-init — see the env var note above.

A `op signin` is still required before any apply that resolves secret refs, since `onepasswordRead` shells out to the `op` CLI.

## Validation

```text
make test-render-brewfile           # for any packages.toml or brewfile.tmpl change
make test-secret-backed-files       # for any secrets/licenses change
chezmoi data                        # dump computed data tree to verify load
chezmoi data --format=yaml | grep -i <key>
```

`chezmoi data` is the source of truth for "what does the template see?" Use it before debugging a template by hand.

## Bootstrap Flow

First-machine sequence (already documented in repo README):

```text
xcode-select --install
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply prateek
# during init, prompts interactively for: install_profile, run_install_scripts,
# apply_macos_defaults, secrets_enabled (each overridable via the matching
# DOTFILES_* env var for non-interactive runs).
#
# install_xcode is NOT prompted interactively. It defaults to false; set
# DOTFILES_INSTALL_XCODE=true at init time to persist `true`, or set it on a
# specific `chezmoi apply` for a one-off Xcode download without re-initing.
```

Non-interactive variant for Tart / CI:

```text
DOTFILES_INSTALL_PROFILE=core \
DOTFILES_RUN_INSTALL_SCRIPTS=true \
DOTFILES_APPLY_DEFAULTS=false \
DOTFILES_SECRETS_ENABLED=false \
DOTFILES_INSTALL_XCODE=false \
  sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply prateek
```

After init, to enable secrets on an existing machine:

```text
chezmoi edit-config       # set secrets_enabled = true
op signin
chezmoi apply
```

## Common Pitfalls

- **Committing human-readable `op://` paths.** Strip down to obfuscated IDs before commit; put readable form in `~/.config/chezmoi/chezmoi.toml.local`.
- **Writing license `op://` refs into `licenses.toml`.** That file holds target paths only. Refs go in `secrets.toml` under `[secrets.refs]` with matching key names.
- **Putting refs at the top level of `secrets.toml`.** Templates read `.secrets.refs.<name>`. A top-level `github_token = "op://..."` will not be reachable.
- **Forgetting to update both profiles in `packages.toml`.** A `core`-only addition leaves `full` users without the package.
- **Adding a new env var without documenting it in the env var table above.** SKILL.md Repo-Specific Gotchas is reserved for high-stakes vars (per `meta-skill-maintenance.md`); promote there only when the rule is destructive or surprising on a fresh machine.
