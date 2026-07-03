# Packages and Secrets Mode

Managing data files under `home/.chezmoidata/`, rendering Brewfiles, gating installs via `DOTFILES_INSTALL_*` env vars, wiring 1Password `op://` references.

## Files Owned By This Mode

```text
home/.chezmoidata/packages.toml          # Homebrew formulae, casks, MAS apps, reusable groups
home/.chezmoidata/machines.toml          # per-machine_type group + behavior layers (resolved by features.tmpl)
home/.chezmoidata/secrets.toml           # [secrets.refs] obfuscated op:// refs only
home/.chezmoidata/licenses.toml          # [licenses] paths = [...] target paths (refs live in secrets.toml)
home/.chezmoitemplates/brewfile.tmpl     # renders to a Brewfile from packages.toml + the resolver
home/.chezmoitemplates/features.tmpl     # resolves machines.toml layers into one feature set (JSON)
```

`home/.chezmoidata/` files are loaded BEFORE the template engine starts. **They cannot themselves be templates.** Dynamic data goes in `home/.chezmoi.<format>.tmpl` at the source root, or via template functions in the templates that consume the data.

## Packages.toml Structure

`packages.toml` defines reusable `[packages.groups.<name>]` sub-tables. Which groups each machine type installs is declared separately in `home/.chezmoidata/machines.toml` (`[machines.type.<type>].groups`), resolved by `home/.chezmoitemplates/features.tmpl` (see "Machine Types And Config Gating" below). Each group body uses **inline arrays of inline tables**. Do NOT use TOML array-of-tables syntax (`[[packages.groups.core.brews]]`) — that mixes two definitions of the same key and is invalid against the existing inline shape. The Brewfile renderer and the `package-cask-enabled.tmpl` gate union each section across the selected machine type's groups, deduped by name, so shape and key names must match.

Group keys (all optional except `description`):

| Key | Consumed by | Use for |
|---|---|---|
| `description` | docs / inventory | One-line group label |
| `taps` | `brewfile.tmpl` | Homebrew taps |
| `brews` | `brewfile.tmpl` | Homebrew formulae that install at standard `chezmoi apply` time |
| `casks` | `brewfile.tmpl` | Homebrew casks |
| `mas` | `brewfile.tmpl` (gated on `DOTFILES_INSTALL_MAS_APPS=true`) | Mac App Store entries |
| `gh_extensions` | `home/.chezmoiscripts/run_onchange_after_12-gh-extensions.sh.tmpl` | `gh` CLI extensions |
| `xcode_required_brews` | `home/.chezmoiscripts/run_onchange_after_15-xcode.sh.tmpl` | Formulae that need Xcode CLT first; installed AFTER Xcode setup, NOT in the main Brewfile. Lives in the `apple-development` group, whose presence also gates the Xcode setup step. |
| `disabled_casks` | inventory only — NOT consumed by `brewfile.tmpl` | Record of casks intentionally excluded with the reason. To actually disable a cask, remove it from `casks`; the `disabled_casks` entry is documentation, not a filter. |

```toml
# packages.toml — reusable group definitions only.
[packages.groups.core]
description = "Headless-safe baseline for every managed machine, including ci"
taps  = [ { name = "1password/tap" } ]
brews = [ { name = "git" }, { name = "gh" }, { name = "mise" } ]
casks = [ { name = "1password-cli" } ]

[packages.groups.mac-desktop]
description = "Shared GUI apps and Mac control tools for daily-driver laptops"
casks = [ { name = "1password" }, { name = "ghostty" } ]

[packages.groups.developer-tools]
description = "General development toolchain for real development machines"
brews = [ { name = "postgresql@16" } ]
casks = [ { name = "docker" } ]

[packages.groups.apple-development]
description = "Xcode / iOS toolchain; presence gates Xcode setup"
brews = [ { name = "homebrew/core/xcodes", args = ["force-bottle"] } ]
xcode_required_brews = [ { name = "swiftlint" } ]

[packages.groups.personal-apps]
description = "Personal laptop GUI, licensed, media, and productivity apps"
casks = [ { name = "arq" } ]
mas   = [ { name = "Things", id = 904280696 } ]   # id is INTEGER (renderer interpolates as %d)

[packages.groups.homelab-admin]
description = "Remote access and administration tools for homelab Mac minis"
casks = [ { name = "tailscale-app" } ]
```

```toml
# machines.toml — which groups (and other behavior) each machine type gets.
[machines.type.ci]
groups = ["core"]
[machines.type.personal]
groups = ["core", "mac-desktop", "ai-agent-apps", "developer-tools", "apple-development", "personal-apps"]
[machines.type.homelab]
groups = ["core", "ai-agent-apps", "developer-tools", "apple-development", "homelab-admin"]
[machines.type.work]
groups = ["core", "mac-desktop", "ai-agent-apps", "developer-tools", "work-apps"]
```

Machine type resolves from `[data].machine_type` (default `personal`), set by the `chezmoi init` prompt or `chezmoi init --promptChoice 'machine_type=<type>'`; there is no `DOTFILES_MACHINE_TYPE`. Interactive values: `personal`, `homelab`, `work`, `ci`. `ci` is the minimal tier for CI/Tart/audits and a first-class prompt choice. See `docs/adr/0010-machine-type-package-selection.md` and `docs/adr/0012-config-gating-convention.md`.

## Brewfile Rendering

The same logic lives in `home/.chezmoitemplates/brewfile.tmpl` and runs during `chezmoi apply` via `home/.chezmoiscripts/run_onchange_after_10-brew-bundle.sh.tmpl`. To verify your edit before apply:

```text
make test-render-brewfile                              # validates rendering
scripts/packages/render-brewfile --machine-type ci        # eyeball (core only)
scripts/packages/render-brewfile --machine-type personal  # eyeball (full set)
```

The apply script treats `packages.toml` as the trust source. Keep formulae and
casks from non-official taps tap-qualified in package data. The rendered
Brewfile marks those tap-qualified formulae and casks with `trusted: true`,
excluding official `homebrew/*` entries. Do not commit Homebrew's generated
trust store; let apply recreate that local state from package data.

**MAS entries need an explicit flag to appear in output.** The plain `render-brewfile` invocations above omit `mas` lines because the wrapper script clears `DOTFILES_INSTALL_MAS_APPS` from the environment by default (`env -u DOTFILES_INSTALL_MAS_APPS`); setting it inline like `DOTFILES_INSTALL_MAS_APPS=true scripts/packages/render-brewfile ...` does NOT work for that reason. Use the wrapper flag instead:

```text
scripts/packages/render-brewfile --machine-type personal --include-mas
```

`--include-mas` re-injects `DOTFILES_INSTALL_MAS_APPS=true` into the renderer's environment, so the rendered Brewfile contains the `mas "<name>", id: <int>` lines. Diff the with-flag vs without-flag output to confirm the gate is doing its job.

## Machine Types And Config Gating

`[data]` in `home/.chezmoi.toml.tmpl` holds **identity only**: `machine_type` (the sole first-run prompt), the `xdg_*` / `dotfiles_dir` paths, and `jamf_policy_id`. All machine *behavior* is composed at apply time from the layered `home/.chezmoidata/machines.toml`, resolved by `home/.chezmoitemplates/features.tmpl` into one JSON feature set. Consumers read it with a single include:

```text
{{- $f := includeTemplate "features.tmpl" . | fromJson -}}
{{- if $f.run_install_scripts }} ... {{- end }}
{{- range $f.groups }} ... {{- end }}
```

Feature keys: `groups`, `run_install_scripts`, `apply_macos_defaults`, `secrets_enabled`, `private_overlay`, `elevation`, plus the resolved `machine_type`. Layers merge low→high: `defaults < os.<os> < type.<machine_type> < host.<hostname>` < host-local `[data].machines_local`. A list (e.g. `groups`) is replaced wholesale by the highest layer that sets it; an unknown `machine_type` fails the resolver loudly (the typo guard).

- **Change behavior for a role:** edit `[machines.type.<type>]` in `machines.toml`. It is render-time, so it lands on the next `chezmoi apply` with no re-init.
- **One-off per-machine exception:** add a host-local `[data].machines_local` block in `~/.config/chezmoi/chezmoi.toml` (chezmoi-ignored), e.g. `[data.machines_local]` with `secrets_enabled = true`.
- **Select the type non-interactively:** `chezmoi init --promptChoice 'machine_type=<type>'` (the flag keys on the prompt text); `--promptDefaults` only yields `personal`.
- There are **no** per-flag config env vars: `DOTFILES_MACHINE_TYPE`, `DOTFILES_RUN_INSTALL_SCRIPTS`, `DOTFILES_APPLY_MACOS_DEFAULTS`, and `DOTFILES_SECRETS_ENABLED` were removed. The apply-time runtime switches below are separate and still env-driven.

**Apply-time env vars (read on every `chezmoi apply` via `env` template function):**

| Apply env var | Effect |
|---|---|
| `DOTFILES_INSTALL_MAS_APPS` | Renders MAS entries in Brewfile only when `true` |
| `DOTFILES_INSTALL_XCODE` | Forces the Apple ID-backed Xcode download in `run_onchange_after_15-xcode.sh.tmpl`. The script check&sets Xcode by presence: on an `apple-development` machine it installs the pinned version when absent (interactive apply, or this set), otherwise it fails loudly. |
| `DOTFILES_HOMEBREW_BUNDLE_JOBS` | Parallelism for `brew bundle install` |
| `DOTFILES_HOMEBREW_DOWNLOAD_CONCURRENCY` | Per-bottle download concurrency for Homebrew |
| `DOTFILES_PLIST_QUIT_TIMEOUT_SECS` | How long (default 20) the plist guard waits for an app to actually quit after the user agrees to close it |
| `DOTFILES_PLIST_VERBOSE` | Verbose logging from the plist merge engine |
| `DOTFILES_RELAUNCH_AFTER_APPLY` | Whether the post-apply hook relaunches the full pending list, not just apps the pre-hook quit |
| `DOTFILES_SKIP_APP_RESTART` | Skip app-restart side effects in plist hooks |
| `DOTFILES_SKIP_LSREGISTER` | Skip Launch Services re-registration in plist hooks |
| `DOTFILES_SKIP_PLIST_HOOKS` | Disable both `scripts/chezmoi-hooks/plist-hooks.sh` modes entirely, with no interactive prompt (pre-hook guard and post-hook cfprefsd/relaunch) |
| `DOTFILES_SKIP_SPOTLIGHT_REINDEX` | Skip Spotlight reindex side effects in plist hooks |

`machine_type` is persisted at init time; the behavior toggles are NOT persisted — they resolve from `machines.toml` on every apply, so editing a `[machines.type.*]` layer (or a host-local `[data].machines_local` block) takes effect on the next `chezmoi apply` with no re-init. To change `machine_type` itself, `chezmoi edit-config` or re-init with `--promptChoice`.

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

`.chezmoiignore` reads `licenses.paths` to skip these targets when `secrets_enabled=false`. Note: a `secrets.paths` table was once planned (and is referenced in the migration plan) but was retired as always-empty — do not add it back unless the ignore template is updated to consume it.

## Secret-Backed Template Pattern

A template that needs a secret reads `.secrets.refs.<name>` via `onepasswordRead`, gated by `secrets_enabled`:

```text
{{- if (includeTemplate "features.tmpl" . | fromJson).secrets_enabled -}}
{{- $ref := .secrets.refs.bettertouchtool_license -}}
{{- if $ref -}}
{{ onepasswordRead $ref }}
{{- else -}}
{{- /* secrets enabled but ref is empty — fail loudly */ -}}
{{ fail "bettertouchtool_license: secrets_enabled is true but ref is empty" }}
{{- end -}}
{{- end -}}
```

`secrets_enabled` resolves from `machines.toml` (default `false` for every type). Enable it per machine with a host-local `[data.machines_local]` block (`secrets_enabled = true`) in `~/.config/chezmoi/chezmoi.toml`; it takes effect on the next apply with no re-init.

A `op signin` is still required before any apply that resolves secret refs, since `onepasswordRead` shells out to the `op` CLI.

## Validation

```text
make test-render-brewfile           # for any packages.toml or brewfile.tmpl change
make test-machines-features         # for machines.toml / features.tmpl / machine-behavior changes
make test-brew-bundle-script        # for package apply script or Homebrew trust behavior
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
# during init, prompts interactively for machine_type (and, on work, the Jamf
# Self Service policy ID). All behavior toggles resolve from machines.toml, not
# from prompts or env vars.
#
# Xcode is not a config toggle: the 15-xcode script check&sets it by presence.
# On an apple-development machine it installs the pinned Xcode when absent (interactive
# apply, or DOTFILES_INSTALL_XCODE=true to force a non-interactive download).
```

Non-interactive variant for Tart / CI (`--promptChoice` keys on the prompt text):

```text
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --promptChoice 'machine_type=ci' prateek
```

After init, to enable secrets on an existing machine:

```text
chezmoi edit-config       # add [data.machines_local] with secrets_enabled = true
op signin
chezmoi apply
```

## Common Pitfalls

- **Committing human-readable `op://` paths.** Strip down to obfuscated IDs before commit; put readable form in `~/.config/chezmoi/chezmoi.toml.local`.
- **Writing license `op://` refs into `licenses.toml`.** That file holds target paths only. Refs go in `secrets.toml` under `[secrets.refs]` with matching key names.
- **Putting refs at the top level of `secrets.toml`.** Templates read `.secrets.refs.<name>`. A top-level `github_token = "op://..."` will not be reachable.
- **Putting a package in the wrong group in `packages.toml`.** `core` reaches every machine (including `ci`); `mac-desktop` reaches work/personal laptops only; `ai-agent-apps` reaches work/personal/homelab; `developer-tools` reaches work/personal/homelab; `apple-development` reaches personal/homelab; `work-apps`, `personal-apps`, and `homelab-admin` are role-specific. Choose the group by which machine types should get the package.
- **Adding a new env var without documenting it in the env var table above.** SKILL.md Repo-Specific Gotchas is reserved for high-stakes vars (per `meta-skill-maintenance.md`); promote there only when the rule is destructive or surprising on a fresh machine.
