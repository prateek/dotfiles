# Chezmoi Migration Plan

Status: accepted plan; implementation in progress on branch `chezmoi-migration`
Date: 2026-04-27
ADR: [../adr/0006-chezmoi-migration-prototype.md](../adr/0006-chezmoi-migration-prototype.md)

## Goal

Make this repo a reproducible, reviewable Mac configuration:

- a new Mac can converge to the declared setup through one bootstrap entrypoint;
- an existing Mac can report drift without silently adopting app churn, secrets, licenses, or volatile state;
- changes are testable against a materialized temp home before they touch the real one.

The canonical checkout stays at `~/dotfiles`.

## Terms

- `home/`: chezmoi source state. With `.chezmoiroot = home`, files under this directory materialize into `$HOME`.
- `install.sh`: the only public bootstrap entrypoint. It prepares enough of macOS for chezmoi to run, then hands off to `chezmoi init --apply`.
- `.chezmoidata/`: committed structured desired state for chezmoi templates and scripts, including bootstrap defaults, package profiles, app indexes, scalar defaults, license aliases, and permission intent.
- `.chezmoiassets/`: committed source-only payloads used by templates or `modify_` targets. Use this for selected plist payloads that must not be parsed as Go templates.
- `.chezmoiscripts/`: chezmoi-owned side effects. Use this for idempotent setup that should run as part of `chezmoi apply`.
- `.chezmoiexternal.*`: chezmoi-owned external dependencies such as zinit or plugin repositories, when a clone/pull is enough.
- `apps`: install-gated app indexes under `home/.chezmoidata/apps/` only when the repo needs metadata for defaults, generated policy, or selected plist/file ownership. Simple native config lives directly under `home/` and uses focused tests.
- `defaults`: macOS scalar defaults intent. Apple/global keys live under `home/.chezmoidata/system/macos.toml`; small third-party app scalar defaults may live under `home/.chezmoidata/apps/<app>.toml`.
- `captures`: local machine observations under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/`. They are not committed and never become desired state without a one-item adoption step.
- `transactions`: local rollback records under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/transactions/`. Repo recovery remains visible through git.

## Current Implementation Snapshot

This branch is rebased on `origin/master` at `8f54c73` and carries the migration as one local commit.

Implemented:

- Chezmoi source state lives under `home/` with `.chezmoiroot = home`.
- `install.sh` is the only bootstrap entrypoint; `bootstrap.sh`, root `Brewfile`, and root `Brewfile.core` are removed.
- Package intent lives in `home/.chezmoidata/packages.toml`; `bin/dotfiles render brewfile --profile <profile>` renders temporary Homebrew Bundle input.
- The package data has been reconciled with the refreshed `origin/master` Homebrew profile, except `intellij-idea` and `prince` are intentionally omitted.
- Mac App Store entries are omitted unless `DOTFILES_INSTALL_MAS_APPS=true` or `--include-mas` is used.
- Raw app captures are not committed; capture and inventory output goes under XDG state.
- Privileged Chrome policy intent is data in `home/.chezmoidata/apps/chrome.toml`, rendered only during explicit privileged apply.
- App config is apply-only and install-gated. Native files live at their target paths under `home/`; selected nested preference plists live under `home/.chezmoiassets/` and are merged through `modify_` targets.
- The Tart dry-run and smoke lanes use the base Tahoe image; the full lane uses the Xcode Tahoe image by default.
- Tart logs now include an always-on slowest-phase timing summary. Package scripts emit `TIMING|...` records for expensive package/runtime/defaults steps.

Validated locally:

- `make test-install-tart-dry-run` passed in `39.108s`; `35.407s` was guest-agent wait time.
- `make test-install-tart-smoke` passed in `197.510s`; the largest phases were local install `123.720s`, guest-agent wait `36.118s`, and fresh-shell verify `31.914s`.
- In the smoke install, `brew bundle install (core)` took `62s`, `mise install` took `13s`, and defaults application took `1s`.
- Focused host checks passed: helper contract, trace conversion, VM log scanner, VM macOS postflight tests, shellcheck, Python syntax, rendered chezmoi script syntax, and Brewfile render/parse checks.

Pending:

- Re-run `make test-install-tart-full` to completion after the MAS render change and the `intellij-idea`/`prince` removals. Earlier full runs proved the Xcode image fixes SwiftLint/SwiftFormat but did not complete because MAS was still rendered.
- Decide whether "quick" local validation should mean cold disposable VMs, a prewarmed local Tart image, or a kept warm VM. Current cold-VM dry-run floor is about 35-40 seconds on `mini`.
- Finish Phase 3 gates for app-specific postflight checks, license automation, permission/profile handling, and signed-in-machine MAS validation.
- Resolve the remaining open design decisions listed below before treating the migration as fully complete.

## Target Layout

```text
~/dotfiles/
  .chezmoiroot                  # contains: home
  install.sh                    # tiny stage-zero installer; no separate bootstrap.sh

  home/
    .chezmoi.toml.tmpl          # used by `chezmoi init` to write local config
    .chezmoidata/
      bootstrap.toml            # committed non-local bootstrap defaults
      features.toml             # committed non-identifying feature flags
      packages.toml             # package profiles; rendered to temporary Brewfile input
      secrets.toml              # secret aliases and obfuscated op:// refs
      licenses.toml             # license aliases and validator IDs only
      permissions.toml          # global permission intent
      system/
        macos.toml              # Apple/global defaults declarations
      apps/
        chrome.toml             # app index: cask, bundle ID, generated policy/defaults
    .chezmoiassets/
      com.manytricks.Moom.plist # selected source-only plist payload for modify_ target
    .chezmoiscripts/
      run_once_before_00-homebrew.sh.tmpl
      run_once_before_05-core-tools.sh.tmpl
      run_onchange_after_10-brew-bundle.sh.tmpl
      run_onchange_after_20-mise-install.sh.tmpl
      run_onchange_after_30-macos-defaults.sh.tmpl
      run_after_90-verify.sh.tmpl
    .chezmoitemplates/
      script_lib.sh              # shared shell helpers for chezmoi scripts
    .chezmoiexternal.toml.tmpl   # zinit and other clone/pull-only dependencies
    dot_zshenv.tmpl             # tiny $HOME shim; sets XDG and ZDOTDIR
    dot_agents/
      AGENTS.md
      docs/
      skills/
    dot_codex/
      AGENTS.md
    dot_claude/
      CLAUDE.md
      commands/
    dot_config/
      zsh/
      nvim/
      tmux/
      mise/
      grm/
      worktrunk/
      gemini-meeting-sync/
      borders/
      kanata/
    dot_hammerspoon/
    bin/
      symlink_gh.tmpl
      symlink_grmrepo.tmpl
      symlink_grmrepo-refresh.tmpl
      symlink_repo-index.tmpl
      symlink_wt-hook-sparse.tmpl
      symlink_gemini-meeting-sync.tmpl
    Library/                    # one Library tree; use private_ on leaves
  bin/
    gh
    grmrepo
    grmrepo-refresh
    repo-index
    wt-hook-sparse
    gemini-meeting-sync
  skills/
  scripts/
  tests/
  dev/
    adr/
    docs/
  docs/
  archive/
    keyboard/
  .github/
  .gitignore
  .pre-commit-config.yaml
  AGENTS.md
  Makefile
  README.md
```

Do not create both `Library/` and `private_Library/` at the source root. They both target `~/Library` and make the source state ambiguous. Use one `Library/` tree and apply `private_` to specific files or directories.

Committed `.chezmoidata` may contain desired app/system declarations, feature flags, package profiles, validator IDs, opaque secret aliases, and obfuscated `op://` refs. Hostnames, usernames, workplace labels, account names, installed-app inventories, raw captures, transaction records, and local paths belong in untracked XDG state or local chezmoi config.

`${DOTFILES}` means a chezmoi data value named `dotfiles_dir`. It defaults to `~/dotfiles` on real machines. Isolated tests set it to the repo under test, so rendered live links and shell startup do not accidentally point at `$tmp_home/dotfiles`.

There is no durable `bootstrap.sh`. `install.sh` is the public bootstrap entrypoint.

## Ownership Rules

Use native chezmoi files by default:

- `dot_` for dotfiles;
- `private_` for non-world-readable targets;
- `executable_` for executable targets;
- `.tmpl` only where host, OS, architecture, feature flags, paths, or secret references vary;
- `symlink_` only for deliberate live links.

Agent tool homes are normal chezmoi source state. Keep `.agents`, `.codex`, and `.claude` content under `home/dot_agents/`, `home/dot_codex/`, and `home/dot_claude/` unless a specific file must remain a live link. Default to rendered files/directories, not symlinks.

Allowed live links are limited to repo-local executable wrappers that must run directly from the checkout. Everything else should be a rendered chezmoi target unless an app-specific plan says otherwise.

## Current To Target Mapping

| Current path | Target | Phase | State |
| --- | --- | --- | --- |
| `zshenv` | `home/dot_zshenv.tmpl` | 1 | implemented |
| `zprofile`, `zshrc`, `zlogin` | `home/dot_config/zsh/dot_zprofile`, `dot_zshrc`, `dot_zlogin` | 1 | implemented |
| `init.sh`, `zinit-init.zsh`, `zsh/` | `home/dot_config/zsh/` | 1 | implemented |
| `.agents/` | `home/dot_agents/` rendered source state; move volatile state to XDG state | 1 | implemented rendered source state |
| `.codex/` | `home/dot_codex/` rendered source state; split local project trust into local config | 1 | implemented rendered source state; trust split still open |
| `.claude/` | `home/dot_claude/` rendered source state | 1 | implemented rendered source state |
| `.mcp.json` | `home/private_dot_mcp.json` | 1 | implemented |
| `bin/` | repo root; selected wrappers exposed through `home/bin/symlink_*.tmpl` | 1 | implemented |
| `.config/grm/config.toml` | `home/dot_config/grm/config.toml` | 1 | implemented |
| `.config/gemini-meeting-sync/config.json` | `home/dot_config/gemini-meeting-sync/config.json`; local `enabled` marker remains untracked | 2 | implemented |
| `macos` defaults baseline | `home/.chezmoidata/system/macos.toml` plus gated `.chezmoiscripts/run_onchange_after_30-macos-defaults.sh.tmpl` | 1 | implemented with transaction-aware wrapper |
| `install.sh`, `bootstrap.sh` | one simplified `install.sh`; delete `bootstrap.sh` | 0 | implemented |
| `Brewfile`, `Brewfile.core` | `home/.chezmoidata/packages.toml`; `bin/dotfiles render brewfile --profile <profile>` renders temporary Homebrew bundle input | 2 | implemented |
| `.config/mise/`, `.config/tmux/`, `.config/worktrunk/`, `.config/borders/` | `home/dot_config/<name>/` | 2 | implemented |
| `.config/kanata/kanata.kbd` | `home/dot_config/kanata/kanata.kbd`; replaces the previous Karabiner key remaps and targets `Apple Internal Keyboard / Trackpad` explicitly. Karabiner-Elements remains installed only for its macOS virtual HID driver until there is a driver-only package path. | 2 | implemented |
| `nvim/` | `home/dot_config/nvim/` | 2 | implemented |
| `gitconfig`, `vimrc`, `inputrc`, `lesskey` | native `home/dot_*` files | 2 | implemented |
| `osx-apps/vscode/` | `home/Library/Application Support/Code/User/`; extension captures under XDG state only | 2 | implemented |
| `vscode/` | reconcile into the same `home/Library/...` targets, then remove the legacy tree | 2 | deferred |
| `osx-apps/ghostty/config` | `home/dot_config/ghostty/config` | 2 | implemented |
| `osx-apps/defaults/*.plist` | explicit applied defaults under `home/.chezmoidata/apps/<app>.toml`, selected XML plist patches under `home/.chezmoiassets/`, or Apple/global defaults under `home/.chezmoidata/system/macos.toml`; raw captures under XDG state only | 3 | implemented for selected app config; broad plist dumps not committed |
| `osx-apps/iterm2/` | not managed; iTerm2 app state remains local | 3 | removed from app config |
| `osx-apps/Moom.plist` | selected XML plist patch in `home/.chezmoiassets/com.manytricks.Moom.plist`; `home/Library/Preferences/modify_private_com.manytricks.Moom.plist.tmpl` merges owned keys only | 3 | implemented |
| `osx-apps/alfred/` | not managed; app-native sync and local captures remain outside source | 3 | removed from app config |
| `osx-apps/chrome/policies/` | privileged opt-in declared under `home/.chezmoidata/apps/chrome.toml`; plist generated during privileged apply | 3 | implemented |
| `osx-apps/orbstack/` | readable source config in `home/.chezmoiassets/Library/Preferences/dev.kdrag0n.MacVirt.json`; `home/Library/Preferences/modify_private_dev.kdrag0n.MacVirt.plist.tmpl` merges owned plist keys only. License, onboarding, selected tab, update, and window state stay local. | 3 | implemented |
| `osx-apps/leader-key/` | native JSON target under `home/Library/Application Support/Leader Key/config.json.tmpl`; raw captures under XDG state only | 3 | implemented |
| `osx-apps/defaults/com.jordanbaird.Ice.plist` | readable source config in `home/.chezmoiassets/Library/Preferences/com.jordanbaird.Ice.json`; `home/Library/Preferences/modify_private_com.jordanbaird.Ice.plist.tmpl` merges owned plist keys only. Hotkeys, icon JSON, menu-bar layout, update state, and window state stay local. | 3 | implemented |
| `osx-apps/defaults/com.prakashjoshipax.VoiceInk.plist` | readable source config in `home/.chezmoiassets/Library/Preferences/com.prakashjoshipax.VoiceInk.json`; `home/Library/Preferences/modify_private_com.prakashjoshipax.VoiceInk.plist.tmpl` merges owned plist keys only. Prompt list and selected prompt are managed; hotkeys, keychain migration flags, selected audio device, trial/update state, and window state stay local. | 3 | implemented |
| `osx-apps/nvALT.clr` | readable source config in `home/.chezmoiassets/Library/Preferences/net.elasticthreads.nv.json` and `home/.chezmoiassets/Library/Colors/nvALT.clr.json`; `home/Library/Preferences/modify_private_net.elasticthreads.nv.plist.tmpl` merges owned plist keys only; `home/Library/Colors/modify_private_nvALT.clr.tmpl` generates the app color list. Window state, notes location aliases, font archives, update state, and search state stay local. | 3 | implemented |
| `osx-apps/cmux/` | readable source config in `home/.chezmoiassets/cmux/preferences.json`; `home/Library/Preferences/modify_private_com.cmuxterm.app.plist.tmpl` merges owned plist keys only; reusable icon asset under `scripts/macos/assets/cmux/`. Session state, browser history, PostHog cache, and icon backups stay local. | 3 | implemented |
| `.hammerspoon/` | `home/dot_hammerspoon/` | 3 | implemented file-backed config |
| `osx-apps/` | remove after stable files move into `home/`, declarations move into `home/.chezmoidata/`, and raw captures move to XDG state | all | implemented |
| `.github/`, `.gitignore`, `.pre-commit-config.yaml`, `README.md`, `tests/`, `docs/`, `dev/`, `skills/` | repo root | all | repo-only |
| `Makefile` | repo-root build/test facade for Hammerspoon compilation, source-state tests, shell validation, helper tests, and Tart lanes | all | repo-only |
| `keyboard/` | `archive/keyboard/` | 2 | implemented |

## Shell

Use XDG `ZDOTDIR`.

`~/.zshenv` is the only zsh file directly in `$HOME`. It sets XDG defaults, `DOTFILES` from the rendered `dotfiles_dir` value, and `ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"`. All other shell files live under `~/.config/zsh`.

Phase 1 owns zinit acquisition because shell startup depends on it. Use `.chezmoiexternal.toml.tmpl` with `type = "git-repo"` for the checkout at `${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git`. Keep a small `.chezmoiscripts` compatibility step only for the legacy `~/.zinit/bin` symlink if shell startup still needs it.

## Chezmoi Scripts

Use chezmoi scripts for setup that is part of the declared machine state.

Rules:

- Keep `install.sh` small. It may install Xcode Command Line Tools, Homebrew, Git, chezmoi, and uv because chezmoi and the uv-backed `dotfiles` CLI cannot manage the machine before they exist.
- Put package installs, mise runtime install, zinit compatibility wiring, Hammerspoon compilation, selected macOS defaults, and post-apply verification under `home/.chezmoiscripts/`.
- Put shared shell helpers for those scripts under `home/.chezmoitemplates/` and include them from each script. Keep individual scripts short: data selection, command execution, and clear blocker output.
- Use `run_once_before_` for one-time prerequisites and `run_onchange_after_` for work that should rerun when its rendered script content changes.
- `run_onchange_` scripts that depend on repo-root files or structured data must embed dependency hashes in rendered comments. Mise config, package data, and defaults manifests do not trigger reruns unless the script template includes their content hash.
- Every script must be idempotent. A rerun should converge or report a clear blocker, not duplicate state.
- Scripts must use explicit XDG paths and the rendered `dotfiles_dir` data value. Do not infer the repo from the process working directory.
- Scripts that require secrets, GUI sign-in, TCC permissions, or privileged profile installation must be gated by data flags and fail closed with a specific manual step.
- Prefer `.chezmoiexternal.*` over script-managed `git clone` when a dependency is just a repository or archive. Git-repo externals must set a `refreshPeriod` or be refreshed through `dotfiles apply chezmoi --refresh-externals=auto`; otherwise chezmoi may keep an existing checkout unchanged.

Default `chezmoi apply` may run home-state scripts and apply declared home source state. That includes ordinary app files and selected preference plist `modify_` targets. High-risk imperative changes, such as privileged policy writes, license installation, permission/profile changes, or non-chezmoi app mutations, still go through the transaction-aware `dotfiles` CLI or an explicitly gated script so they can be audited and rolled back.

## Repo Tooling

Keep `Makefile` at the repo root. It is not user configuration; it is the stable command surface for local and Tart validation.

The Makefile owns:

- Hammerspoon Fennel compilation and syntax checks;
- isolated chezmoi source-state tests;
- shell fresh-start validation and benchmarks;
- helper regressions for GRM, worktrees, repo index, macOS settings, trace conversion, and VM log scanning;
- Tart dry-run, smoke, and full install lanes.

If Make targets grow beyond simple orchestration, move implementation into `scripts/` and keep Make as the discoverable facade.

## Chezmoi Data

Desired app and system state lives in `.chezmoidata/`. Keep it static, structured, and small enough for chezmoi to load as template data.

```text
home/.chezmoidata/
  bootstrap.toml
  features.toml
  packages.toml
  secrets.toml
  licenses.toml
  permissions.toml
  system/
    macos.toml
  apps/
    chrome.toml
home/.chezmoiassets/
  com.manytricks.Moom.plist
  Library/Colors/nvALT.clr.json
  Library/Preferences/com.jordanbaird.Ice.json
  Library/Preferences/com.prakashjoshipax.VoiceInk.json
  Library/Preferences/dev.kdrag0n.MacVirt.json
  Library/Preferences/net.elasticthreads.nv.json
```

Rules:

- Stable target files go under `home/` at the real target path.
- Apple/global macOS defaults intent goes into `.chezmoidata` TOML, not raw plist dumps. A broad baseline is in scope, but it must be expressed as explicit domain/key/type/value declarations rather than a whole-domain import.
- Bootstrap defaults that are not machine-local live in `home/.chezmoidata/bootstrap.toml`, for example the default profile, `secrets_enabled = false`, and `run_install_scripts = true`.
- Machine-local bootstrap data lives in the generated chezmoi config under `[data]`, not in committed `.chezmoidata`. That includes the resolved `dotfiles_dir`, local source overrides, host identity, and any temporary Tart paths.
- Third-party app indexes live under `home/.chezmoidata/apps/<app>.toml` only when the app needs metadata beyond native target files. Apple/global domains live under `home/.chezmoidata/system/macos.toml`.
- Every app file must namespace its data under `apps.<app_id>` because chezmoi merges all `.chezmoidata` files into one root data dictionary in lexical order. App IDs use lowercase slug names such as `iterm2`, `moom`, or `ghostty`; they should match the filename.
- App declarations are apply-only. Do not put audit/manual/planned state in `home/.chezmoidata/apps`. Use native files under `home/` when the app has a stable text config. A file-only app should be package-gated in `home/.chezmoiignore` so absent apps are unmanaged instead of receiving `{}` placeholder config. Test those templates directly and test the managed/ignored profile behavior instead of listing them in app-index coverage. Use selected readable source under `home/` or source-only plist assets under `home/.chezmoiassets/` plus a `modify_` target when the app stores meaningful nested config in a preferences plist.
- `home/.chezmoiassets/` is source-only supporting data. Chezmoi ignores it as a target because it begins with `.chezmoi`, but templates and modify scripts can read files from it via `.chezmoi.sourceDir`. Do not put selected plist payloads in `.chezmoitemplates`; plist strings such as Moom geometry can contain `{{...}}` and will be parsed as Go templates there.

- Defaults-backed apps may still use `[apps.<app>.defaults."<domain>"]` for small scalar settings. If a file or default appears in an app TOML, the repo applies it.
- Prefer app-supported config directories under XDG paths when the app provides that setting. For example, an app like iTerm2 can read preferences from a custom folder; manage that folder as source state and use a small defaults step to point the app at it. Use direct `Library/` targets only when the app has no stable custom-folder mechanism.
- App-native sync folders must be selected per app. For Alfred, keep preferences and workflows out of source until there is an explicit redaction/adoption path.
- Raw exports, local captures, generated inventories, and rollback transactions are local XDG state, not repo files.
- Test fixtures live under `tests/fixtures/`; sanitized examples live under `dev/docs/` only when they explain a decision.
- Mackup is a research/catalog input only. When Mackup is installed, first evaluate `chezmoi mackup add <application>` in a throwaway source state to discover candidate paths. The command reads `~/.mackup/<application>.cfg` before Mackup's packaged catalog, adds existing `configuration_files` from `$HOME`, maps `xdg_configuration_files` under `$XDG_CONFIG_HOME`, and ignores missing files.
- Treat `chezmoi mackup add` output as local discovery input, not as an adoption step. Mackup is not the policy engine; it discovers candidate paths, and this repo only records the config it applies.
- Secret scanning for Mackup-derived candidates remains a Phase 3 adoption-tooling decision. That phase chooses whether discovery runs with `--secrets=error`, `--secrets=warning`, or `--secrets=ignore`.
- Never use Mackup link mode, whole-domain `defaults import`, bulk folder adoption, direct TCC SQLite writes, or default PPPC profile installation.

## Secrets, Licenses, And Permissions

Committed `op://` references are allowed when the vault, item, and field identifiers are obfuscated IDs. Human-readable vault names, item names, account names, and field names still leak metadata and stay out of committed files.

Rules:

- Public committed refs use repo-local aliases or obfuscated `op://` IDs.
- Untracked local config maps aliases to human-readable 1Password refs when that is more convenient locally.
- Name-bearing refs such as `op://Private/...`, account labels, and direct refs with readable item or field names live only in untracked local config.
- Secret templates must be guarded by an explicit `secrets_enabled` data flag and must not evaluate `op` calls during public bootstrap.
- License files are never committed.
- License fingerprints are local-only. If needed, use a per-machine untracked salt/HMAC and do not emit the result in normal JSON.
- License validation uses allowlisted repo-owned validators by ID. Do not run arbitrary shell from a license manifest.
- Permission manifests may use `desired = "manual"` without a code requirement. Profile-managed permissions require non-empty, verified code requirements.
- Raw TCC rows are never emitted. Reports use service, declared app ID, status enum, and redacted reason.

## Dotfiles CLI

`dotfiles` is the transaction-aware wrapper around operations that can drift, adopt, apply, inventory, or roll back state. It is a uv-backed Python CLI with inline script metadata so the declared Python version is the runtime contract. The public bootstrap remains `install.sh`, but ongoing setup should flow through chezmoi scripts where that is safe.

Required surface:

```sh
dotfiles doctor [--json]
dotfiles drift <scope> [--json]
dotfiles capture <scope> [--json]
dotfiles adopt <scope> <id> [--json]
dotfiles apply <scope> [--json]
dotfiles inventory <scope> [--write] [--json]
dotfiles usage <scope> [--since <duration>] [--json]
dotfiles rollback list|show|run|last [id] [--json]
```

Scopes are `chezmoi`, `shell`, `defaults`, `packages`, `apps`, `licenses`, `permissions`, and `all`.

`dotfiles apply chezmoi` is a thin wrapper around the canonical `chezmoi apply` flags and generated local chezmoi config. It is allowed to run chezmoi scripts.

`dotfiles apply defaults`, `licenses`, and `permissions` owns transaction planning, backups, audit output, and rollback metadata for imperative mutations. App config represented as chezmoi source state applies through `dotfiles apply chezmoi`; an `apps` apply scope is reserved for future app work that cannot be represented as files, `modify_` targets, or generated policy data. Chezmoi scripts may call gated scopes only when the matching data flag is enabled. Package and shell dependency scripts may run by default because they are part of making the declared home state usable.

Package and runtime changes are not fully rollbackable. Their transaction records capture before/after inventory, command output, selected profile, and intended removals. Rollback for `packages` is best-effort when the package manager has a clear inverse, and otherwise reports the manual recovery plan.

`inventory --write` writes local captures under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/` by default. Desired-state changes happen as reviewable diffs to source state: app indexes under `home/.chezmoidata/apps/`, selected plist payloads under `home/.chezmoiassets/`, or native target files under `home/`.

Rollback covers live-target mutations through local transaction backups under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/transactions/`. `adopt` also mutates repo desired state, so it must refuse dirty target data files and write a reverse patch into the transaction. Repo recovery remains visible through git.

## Bootstrap And Normal Workflows

Target new-machine command:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/prateek/dotfiles/master/install.sh)"
```

`install.sh` is the bootstrap contract. It replaces `bootstrap.sh` instead of wrapping a second full installer.

`install.sh` responsibilities:

1. Parse only bootstrap flags: `--core`, `--full`, `--dry-run`, and `--source`.
2. Install Xcode Command Line Tools when missing, then continue automatically when possible. If macOS requires a new shell session, exit with a rerun message.
3. Install Homebrew only if missing.
4. Install the minimum tools needed to hand off: `git`, `chezmoi`, and `uv`. `1password-cli`, package profiles, app tools, and runtimes belong in chezmoi scripts.
5. Clone or update `DOTFILES_DIR`, defaulting to `~/dotfiles`.
6. Export only the local values needed by `home/.chezmoi.toml.tmpl`, such as the resolved `dotfiles_dir`, selected profile, source override, and Tart paths. Do not generate a separate override-data JSON file for ordinary bootstrap data.
7. Let `home/.chezmoi.toml.tmpl` write those local values into the generated chezmoi config under `[data]`. Committed defaults stay in `home/.chezmoidata/bootstrap.toml`.
8. Run `chezmoi init --apply --source "$DOTFILES_DIR"` with explicit XDG config/cache/state paths and `--persistent-state`. Pass the same `--cache` value to `init` and future `apply` calls.
9. Exit after chezmoi finishes. Do not directly call package installs, mise, cargo, Hammerspoon, zinit, macOS defaults, or app scripts from `install.sh`.

Chezmoi then owns ongoing setup:

1. `run_once_before_00-homebrew.sh.tmpl` ensures Homebrew exists when a machine enters through a path where `install.sh` did not already install it.
2. `run_once_before_05-core-tools.sh.tmpl` ensures core handoff tools such as `git`, `chezmoi`, and `uv` exist.
3. `.chezmoiexternal.toml.tmpl` clones zinit and other clone-only dependencies and refreshes them according to their declared `refreshPeriod` or the wrapper's `--refresh-externals` mode.
4. `run_onchange_after_10-brew-bundle.sh.tmpl` renders the selected package profile to a temporary Brewfile and applies it with Homebrew Bundle.
5. `run_onchange_after_20-mise-install.sh.tmpl` trusts repo-owned mise config and installs runtimes.
6. `run_onchange_after_30-macos-defaults.sh.tmpl` applies the declared Apple/global defaults baseline, gated by data flags until transaction rollback exists.
7. `run_after_90-verify.sh.tmpl` runs cheap post-apply validation and prints manual blockers for secrets, sign-in, licenses, or permissions.

Secret-bearing templates render only when `secrets_enabled=true`. If `op` is unauthenticated, the script fails closed with the exact login/rerun command.

Normal update once the CLI exists:

```sh
cd ~/dotfiles
git pull --ff-only
dotfiles apply chezmoi
dotfiles drift all
```

Edit rendered files:

```sh
chezmoi edit ~/.config/zsh/.zshrc
dotfiles apply chezmoi
dotfiles drift shell
git diff
```

Inspect and adopt drift:

```sh
dotfiles drift apps
dotfiles capture apps
dotfiles adopt apps <emitted-id>
git diff
```

Rollback:

```sh
dotfiles rollback list
dotfiles rollback show <transaction-id>
dotfiles rollback run <transaction-id>
dotfiles rollback last
```

## Verification

Tests must exercise materialized configuration. Source-state filenames are not real filenames.

Validation has three layers:

1. Temp-home chezmoi validation proves source-state rendering without touching the real home.
2. CI and host contracts prove helper behavior without booting Tart.
3. Local Tart validation proves the installer on a clean macOS guest.

CI does not boot Tart today. The clean-machine lane is local on `mini`; see [tart-mini-validation.md](tart-mini-validation.md) and [../adr/0004-tart-install-validation-and-tracing.md](../adr/0004-tart-install-validation-and-tracing.md).

### Temp-Home Chezmoi Contract

Temp-home tests are the chezmoi source-state contract. They cover `init`, `apply`, `status`, rendered paths, shell startup, fixture behavior, and leak checks. They do not prove clean-machine bootstrap, Xcode Command Line Tools, Homebrew, installed tools, live macOS defaults, or app postflight behavior.

Canonical isolated harness:

```sh
repo="$(git rev-parse --show-toplevel)"
tmp_home="$(mktemp -d)"
tmp_xdg_config="$tmp_home/.config"
tmp_xdg_cache="$tmp_home/.cache"
tmp_xdg_state="$tmp_home/.local/state"
tmp_config="$tmp_xdg_config/chezmoi/chezmoi.toml"
tmp_state="$tmp_xdg_state/chezmoi/state.boltdb"
mkdir -p "$tmp_xdg_config/chezmoi" "$tmp_xdg_cache/chezmoi" "$tmp_xdg_state/chezmoi"

env -u ZDOTDIR \
HOME="$tmp_home" \
DOTFILES_DIR="$repo" \
DOTFILES_INSTALL_PROFILE=core \
DOTFILES_SECRETS_ENABLED=false \
XDG_CONFIG_HOME="$tmp_xdg_config" \
XDG_CACHE_HOME="$tmp_xdg_cache" \
XDG_STATE_HOME="$tmp_xdg_state" \
chezmoi \
  --config "$tmp_config" \
  --cache "$tmp_xdg_cache/chezmoi" \
  --persistent-state "$tmp_state" \
  init --source "$repo"

env -u ZDOTDIR \
HOME="$tmp_home" \
DOTFILES_DIR="$repo" \
DOTFILES_INSTALL_PROFILE=core \
DOTFILES_SECRETS_ENABLED=false \
XDG_CONFIG_HOME="$tmp_xdg_config" \
XDG_CACHE_HOME="$tmp_xdg_cache" \
XDG_STATE_HOME="$tmp_xdg_state" \
chezmoi \
  --config "$tmp_config" \
  --source "$repo" \
  --destination "$tmp_home" \
  --cache "$tmp_xdg_cache/chezmoi" \
  --persistent-state "$tmp_state" \
  apply
```

`--source "$repo"` relies on `.chezmoiroot = home`.

Required checks:

- temp-home `chezmoi init`, `apply`, and `status`;
- `~/.zshenv` starts with `ZDOTDIR` unset, sets `DOTFILES` to the repo under test, and sets `ZDOTDIR` to `$tmp_home/.config/zsh`;
- shell startup uses materialized `~/.config/zsh`;
- tests set `DOTFILES_SKIP_LAUNCHCTL_SYNC=1`, temp `HISTFILE`, temp zsh cache paths, and no-network/no-install guards;
- defaults/app tests use fixtures, not the real user domain;
- selected plist `modify_` tests prove owned keys are replaced while unrelated live plist keys are preserved;
- leak checks verify the real `$HOME`, real chezmoi state, real `~/Library`, and launch services were untouched;
- fixtures cover spaces in paths, preexisting files, preexisting symlinks, permission-denied targets, hostile env vars, and rollback refusal on drift;
- conformance output has stable check IDs, clear skip/block semantics, pristine stdout/stderr, and CI-fatal classes.

Canonical fixture root:

```text
tests/fixtures/
  homes/
  plists/
  commands/
  chezmoidata/
  transactions/
  golden-json/
```

### CI And Host Contract Checks

CI and local host checks must cover the non-VM contracts:

- temp-home chezmoi `init`, `apply`, and `status`;
- `make test-tart-install-helper`;
- `make test-trace-perfetto`;
- `make test-vm-install-log-scan`;
- `make test-vm-postflight-macos`;
- fresh-shell selftests or verify checks where the host supports them.

These checks catch helper, trace, log-scan, and postflight regressions before running the Tart lane.

### Local Tart Install Validation

Use `make test-install-tart-smoke` on `mini` as the default real install proof for bootstrap, installer, shell startup, core tools, and macOS baseline changes.

The smoke lane boots a disposable Tahoe guest, runs `install.sh --core`, skips casks and Mac App Store entries, scans the captured install log, runs guest postflight checks, and deletes the VM unless debugging keeps it.

Use `make test-install-tart-dry-run` for Phase 0 bootstrap parsing and VM viability when changing `install.sh`, chezmoi script ordering, or the public bootstrap command. Dry-run boots Tart and validates the script path, but it skips postflight tool and shell checks.

Use `make test-install-tart-full` before relying on full package, cask, or app-install behavior. The full lane uses an Xcode-backed Tahoe image by default because the full package profile includes tools such as SwiftLint that require `Xcode.app`, not just Command Line Tools. Full-profile package application runs `brew update` before `brew bundle` so prebuilt VM images do not use stale cask metadata. Mac App Store entries are omitted from generated Brewfiles unless `DOTFILES_INSTALL_MAS_APPS=true` is set on a signed-in machine.

Every Tart lane emits a plain-log timing summary before cleanup exits. Chezmoi package scripts also log `TIMING|...` records around expensive package/runtime/defaults steps. Use those timings first; enable Perfetto traces only when the plain log does not identify the slow phase.

Every Tart lane scans `$LOG_FILE` after install and before guest postflight:

```sh
./scripts/vm/check-install-log.sh "$LOG_FILE"
```

A missing log or known macOS failure signature is fatal. Current signatures include removed LaunchServices flags, sealed system writes, unsupported Spotlight defaults writes, and missing clean-VM Dock database paths. Add new hidden install failure patterns to the scanner and cover them in `tests/vm-install-log-scan.zsh`.

Non-dry-run Tart lanes must run guest postflight checks:

- `scripts/vm/postflight-macos.sh`;
- `command -v brew mise uv llm`;
- `test -f "$HOME/.zshenv"` and `test -f "${ZDOTDIR:-$HOME/.config/zsh}/.zshrc"`;
- `scripts/audit/zsh-fresh-shells.zsh verify --dotfiles-root "$dotfiles_root"`.

Postflight output must keep stable `RESULT|...` and `SUMMARY|...` lines, with any failed check making the lane fail. Phase 3 app/default/license mutations need their own VM postflight checks before Tart can count as exit evidence for those scopes. Interactive permissions and sign-in remain current-Mac/manual audit gates.

## Phases

### Phase 0: Layout And Bootstrap

Land `.chezmoiroot = home`, `home/.chezmoi.toml.tmpl`, the simplified `install.sh`, the first chezmoi scripts, temp-home tests, and this plan.

Exit criteria:

- isolated tests do not read or write real chezmoi state;
- `install.sh` is the only public bootstrap script and has no package/app/default implementation beyond making chezmoi runnable;
- `bootstrap.sh` is deleted;
- `chezmoi apply` may run idempotent package/shell setup scripts, but app/default/license/permission mutations are gated until transaction rollback exists;
- no committed doc presents live-link descriptors as the default migration strategy;
- changes to `install.sh`, chezmoi script ordering, or the public bootstrap command pass `make test-install-tart-dry-run`;
- `install.sh --core` remains the Tart smoke entrypoint, or [../../scripts/vm/test-install-tart.sh](../../scripts/vm/test-install-tart.sh) and [tart-mini-validation.md](tart-mini-validation.md) are updated in the same phase.

### Phase 1: Managed Home Baseline

Bring up shell, agents, wrappers, GRM generation, zinit external acquisition, and declared Apple/global baseline settings. No Homebrew bundle, broad app declarations, licenses, or permissions.

Exit criteria:

- fresh shell works from the materialized temp home;
- zinit is managed by `.chezmoiexternal.toml.tmpl` with explicit refresh behavior, or startup degrades clearly;
- rendered agent/Codex/Claude targets materialize, and wrapper live links resolve;
- Phase 1 defaults are Apple/global key-path declarations with explicit value types;
- live defaults mutation goes through the transaction-aware `dotfiles apply defaults` path. Until that path exists, Phase 1 validates declared defaults without applying them;
- `make test-install-tart-smoke` passes before Phase 1 is accepted. If defaults are declaration-only, split or gate the Tart macOS postflight so it does not require unapplied defaults.

### Phase 2: Packages And Stable Config

Install packages through chezmoi scripts and adopt stable file-backed developer/app config.

Includes Homebrew profiles, package/app inventory, usage reports, native XDG configs, VS Code settings, Ghostty config, selected app plist patches, and ordinary dotfiles.

Exit criteria:

- `run_onchange_after_10-brew-bundle.sh.tmpl` is idempotent, profile-aware, embeds dependency hashes for package data, and is covered by Tart smoke/full lanes as appropriate;
- inventory and usage captures are local, redacted, and gitignored;
- stable app config applies without copying caches, account state, licenses, or whole app databases. Window/layout data is allowed only when it is intentional app config, such as selected Moom layouts and hotkeys;
- `make test-install-tart-smoke` passes for core package/profile changes;
- `make test-install-tart-full` passes before relying on cask or app-install behavior. Mac App Store install behavior needs an explicit signed-in-machine validation because disposable Tart guests omit MAS entries by default.

### Phase 3: Advanced App And System Data

Handle remaining app-native sync folders, privileged assets, licenses, permissions, and PPPC/profile work. Selected app plists that can be represented as `modify_` targets are Phase 2 source state.

Exit criteria:

- broad plist dumps are gone or reference-only;
- imperative app/default/license mutations create rollback transactions;
- license and permission audits work on the current Mac;
- manual permission and sign-in steps are visible;
- app/default/license mutations have VM postflight checks before Tart is used as exit evidence for those scopes.

## Open Decisions

- Phase 1: exact Apple/global baseline key allowlist.
- Phase 1: Codex config split between portable global settings and local project-trust state.
- Phase 1: final `install.sh` flag surface for Tart and local reruns.
- Phase 3: app-by-app selection for native file, `.chezmoidata` declaration, app-native sync, or privileged asset.
- Phase 3: which apps get license automation.
- Phase 3: which permissions remain manual versus profile-managed.
- Phase 3: app-specific Tart postflight checks for defaults, app files, licenses, and privileged assets.

## References Used

- chezmoi setup and source directory docs: `https://www.chezmoi.io/user-guide/advanced/customize-your-source-directory/`
- chezmoi source attributes: `https://www.chezmoi.io/reference/source-state-attributes/`
- chezmoi data directory reference: `https://www.chezmoi.io/reference/special-directories/chezmoidata/`
- chezmoi macOS guide: `https://www.chezmoi.io/user-guide/machines/macos/`
- chezmoi scripts guide: `https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/`
- chezmoi externals reference: `https://www.chezmoi.io/reference/special-files/chezmoiexternal-format/`
- chezmoi 1Password guide: `https://www.chezmoi.io/user-guide/password-managers/1password/`
- chezmoi repository and Mackup command implementation: `https://github.com/twpayne/chezmoi`
- Nate Landau dotfiles chezmoi layout: `https://github.com/natelandau/dotfiles`
- Mackup app catalog: `https://github.com/lra/mackup`
- Mackup/chezmoi integration discussion: `https://github.com/lra/mackup/issues/1733`
- Zac West plist patching pattern: `https://zacwe.st/2021/09/14/managing-preference-plists.html`
- macOS defaults references: `https://macos-defaults.com/`
- Apple PPPC payload settings: `https://support.apple.com/guide/deployment/privacy-preferences-policy-control-payload-settings-dep38df53c2a/web`
- Jamf PPPC Utility: `https://github.com/jamf/PPPC-Utility`
- prek docs: `https://prek.j178.dev/`
- pre-commit docs: `https://pre-commit.com/`
- Gitleaks: `https://github.com/gitleaks/gitleaks`
- detect-secrets: `https://github.com/Yelp/detect-secrets`
- Tart install validation ADR: [../adr/0004-tart-install-validation-and-tracing.md](../adr/0004-tart-install-validation-and-tracing.md)
- Tart mini validation runbook: [tart-mini-validation.md](tart-mini-validation.md)
