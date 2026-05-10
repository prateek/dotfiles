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
- bootstrap: a one-time `xcode-select --install` plus the chezmoi-blessed one-liner `sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply prateek`. There is no `install.sh` (deleted in favor of chezmoi-native bootstrap; see Bootstrap And Normal Workflows).
- `.chezmoidata/`: committed structured desired state for chezmoi templates and scripts, including bootstrap defaults, package profiles, app indexes, scalar defaults, secret refs, license paths, and permission intent.
- `.chezmoiassets/`: committed source-only binary or other non-template payloads consumed by templates or scripts (for example `.mobileconfig` profiles). Plist sources for `modify_` targets live in `.chezmoitemplates/<bundle-id>.plist.tmpl` as templated XML; see Plist Management.
- `.chezmoiscripts/`: chezmoi-owned side effects. Use this for idempotent setup that should run as part of `chezmoi apply`.
- `.chezmoiexternal.*`: chezmoi-owned external dependencies such as zinit or plugin repositories, when a clone/pull is enough.
- `apps`: per-app preferences live as plist `modify_` targets (see Plist Management). The previous `home/.chezmoidata/apps/*.toml` mechanism has been retired along with `bin/dotfiles`. Simple file-backed app config lives directly under `home/` and uses focused tests.
- `defaults`: macOS scalar defaults are inlined in `home/.chezmoiscripts/run_onchange_after_30-macos-defaults.sh.tmpl` (no separate data file). Per-app nested preference plists go through the plist `modify_` pattern.
- `captures`: local machine observations under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/`. They are not committed and never become desired state without a one-item adoption step.
- `transactions`: opt-in local preflight or capture records that risky helpers may write before mutating live state, scoped per helper. Repo-state rollback is desired-state rollback through git + `chezmoi apply` and does not require a generic transaction framework.

## Current Implementation Snapshot

This branch is rebased on `origin/master` at `8f54c73` and carries the migration as one local commit.

Implemented:

- Chezmoi source state lives under `home/` with `.chezmoiroot = home`.
- `install.sh` and `bootstrap.sh` are both removed; bootstrap is the chezmoi-blessed `xcode-select --install` + `sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply prateek`. `home/.chezmoi.toml.tmpl` uses `promptStringOnce` / `promptBoolOnce` for first-machine settings (with env-var override for non-interactive runs). Root `Brewfile` and `Brewfile.core` are removed.
- Package intent lives in `home/.chezmoidata/packages.toml`. The chezmoi script `home/.chezmoiscripts/run_onchange_after_10-brew-bundle.sh.tmpl` inlines `home/.chezmoitemplates/brewfile.tmpl` and pipes the rendered Brewfile into `brew bundle` (chezmoi declarative-install pattern). Audit scripts and CI invoke the same template via the focused wrapper `scripts/packages/render-brewfile`.
- The package data has been reconciled with the refreshed `origin/master` Homebrew profile, except `intellij-idea` and `prince` are intentionally omitted.
- Mac App Store entries are omitted unless `DOTFILES_INSTALL_MAS_APPS=true` or `--include-mas` is used.
- Raw app captures are not committed; capture and inventory output goes under XDG state.
- Privileged Chrome managed-policy data is inlined in `scripts/macos/render-chrome-policy.py`, installed only during explicit privileged apply via `scripts/macos/apply.sh` with `DOTFILES_APPLY_PRIVILEGED_APP_ASSETS=1`.
- App config is apply-only and install-gated. Native files live at their target paths under `home/`. The 11 managed plists (Ice, VoiceInk, MacVirt, nvalt, cmux, Moom, BetterTouchTool, Raycast, Tailscale, Setapp, BetterDisplay) are merged through `modify_` targets that share an engine in `home/.chezmoitemplates/plist-merge-{prelude,postlude}.py`. Each app has a 3-line stub at `home/Library/Preferences/modify_private_<bundle-id>.plist.tmpl` that includes the engine + a per-app XML fragment at `home/.chezmoitemplates/<bundle-id>.plist.tmpl`. Apply-time hooks at `scripts/chezmoi-hooks/{guard-running-apps,post-apply-plists}.sh` provide a running-app refusal check and cfprefsd nudge.
- The Tart dry-run and smoke lanes use the base Tahoe image; the full lane uses the Xcode Tahoe image by default.
- Tart logs now include an always-on slowest-phase timing summary. Package scripts emit `TIMING|...` records for expensive package/runtime/defaults steps.

Validated locally:

- `make test-install-tart-dry-run` passed in `39.108s`; `35.407s` was guest-agent wait time.
- `make test-install-tart-smoke` passed in `197.510s`; the largest phases were local install `123.720s`, guest-agent wait `36.118s`, and fresh-shell verify `31.914s`.
- In the smoke install, `brew bundle install (core)` took `62s`, `mise install` took `13s`, and defaults application took `1s`.
- Focused host checks passed: helper contract, trace conversion, VM log scanner, VM macOS postflight tests, shellcheck, Python syntax, rendered chezmoi script syntax, and Brewfile render/parse checks.

Recently completed (most recent first; see git log for the full set):

- **Cleanup pass:** dead-data files (`bootstrap.toml`, `features.toml`, `permissions.toml`) deleted; `secrets.paths` stripped (always empty); license templates fail loudly when `secrets_enabled=true` but the op:// ref is empty; stale doc references fixed; AGENTS.md plist-storage rule corrected to match the actual layout.
- **Warm-VM helper:** `scripts/vm/warm-tart` + `make test-install-tart-warm` for fast iteration on `mini` (~2s per re-apply against a long-lived VM). Cold disposable lanes unchanged.
- **Tart postflight basics:** `scripts/vm/postflight-macos.sh` adds `chezmoi status --exclude=scripts` empty assertion + hook-state-file cleanup check, on top of the existing 6 inlined-defaults checks.
- **License automation:** `home/.chezmoidata/licenses.toml` + 3 private templates for Moom, BetterTouchTool, Alfred. Refs go in `[secrets.refs]`; user fills them in `~/.config/chezmoi/chezmoi.toml.local`.
- **Plist refactor (hard cut):** all 11 apps moved to `home/.chezmoitemplates/<bundle-id>.plist.tmpl` + shared engine in `plist-merge-{prelude,postlude}.py`; legacy JSON sidecars under `home/.chezmoiassets/Library/Preferences/` deleted.
- **Bootstrap simplification (Option C):** `install.sh` deleted; bootstrap is the chezmoi one-liner with `promptStringOnce` / `promptBoolOnce` for first-machine settings.

Pending:

- **Open design decisions** — only Phase 1 items remain (Apple/global key allowlist scope, Codex config split). Phase 3 design questions are resolved.

## Target Layout

```text
~/dotfiles/
  .chezmoiroot                  # contains: home
  # No install.sh — bootstrap is `xcode-select --install` plus the chezmoi one-liner.

  home/
    .chezmoi.toml.tmpl          # used by `chezmoi init` to write local config
    .chezmoidata/
      packages.toml             # package profiles; rendered to temporary Brewfile input
      secrets.toml              # [secrets.refs] op:// references for license templates
      licenses.toml             # license target paths (gates .chezmoiignore)
    .chezmoiassets/             # binary or non-template payloads only (e.g. .mobileconfig)
    .chezmoiscripts/
      run_once_before_00-homebrew.sh.tmpl
      run_once_before_05-core-tools.sh.tmpl
      run_onchange_after_10-brew-bundle.sh.tmpl
      run_onchange_after_15-xcode.sh.tmpl
      run_onchange_after_20-mise-install.sh.tmpl
      run_onchange_after_30-macos-defaults.sh.tmpl
      run_after_90-verify.sh.tmpl
      run_after_99-sudo.sh.tmpl
    .chezmoitemplates/
      script_lib.sh              # shared shell helpers for chezmoi scripts
      plist-merge-prelude.py     # shared plist merge engine, imports
      plist-merge-postlude.py    # shared plist merge engine, merge + emit
      com.manytricks.Moom.plist.tmpl              # per-app desired-plist fragments
      com.jordanbaird.Ice.plist.tmpl              #   (templated XML; see Plist Management)
      com.prakashjoshipax.VoiceInk.plist.tmpl
      dev.kdrag0n.MacVirt.plist.tmpl
      net.elasticthreads.nv.plist.tmpl
      com.cmuxterm.app.plist.tmpl
      com.hegenberg.BetterTouchTool.plist.tmpl
      com.raycast.macos.plist.tmpl
      io.tailscale.ipn.macsys.plist.tmpl
      com.setapp.DesktopClient.plist.tmpl
      pro.betterdisplay.BetterDisplay.plist.tmpl
      voiceink-prompts.json      # included by VoiceInk fragment via {{ include }}
    .chezmoiexternal.toml.tmpl   # zinit and other clone/pull-only dependencies
    dot_zshenv.tmpl             # tiny $HOME shim; sets XDG and ZDOTDIR
    dot_agents/
      AGENTS.md
      docs/
      skills/
    dot_codex/
      AGENTS.md
    dot_claude/
      symlink_CLAUDE.md
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
    packages/                   # focused renderer (render-brewfile)
    macos/                      # focused helpers (apply.sh, render-chrome-policy.py, capture.sh, set-cmux-icon.sh)
    chezmoi-hooks/              # hooks.apply.{pre,post} targets — outside source state intentionally
    audit/                      # ad-hoc audit utilities (brew-inventory, brewfile-usage, app-inventory)
    vm/                         # Tart VM lifecycle helpers
    trace/                      # Perfetto trace conversion
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

Committed `.chezmoidata` may contain desired app/system declarations, feature flags, package profiles, secret-backed target paths, opaque secret ref keys, and obfuscated `op://` refs. Hostnames, usernames, workplace labels, account names, installed-app inventories, raw captures, transaction records, and local paths belong in untracked XDG state or local chezmoi config.

`${DOTFILES}` means a chezmoi data value named `dotfiles_dir`. It defaults to `~/dotfiles` on real machines. Isolated tests set it to the repo under test, so rendered live links and shell startup do not accidentally point at `$tmp_home/dotfiles`.

There is no durable `bootstrap.sh` or `install.sh`. The public bootstrap is `xcode-select --install` followed by the chezmoi one-liner.

## Ownership Rules

Use native chezmoi files by default:

- `dot_` for dotfiles;
- `private_` for non-world-readable targets;
- `executable_` for executable targets;
- `.tmpl` only where host, OS, architecture, feature flags, paths, or secret references vary;
- `symlink_` only for deliberate live links.

Agent tool homes are normal chezmoi source state. Keep `.agents`, `.codex`, and `.claude` content under `home/dot_agents/`, `home/dot_codex/`, and `home/dot_claude/`. Shared instruction content lives in `home/dot_agents/AGENTS.md`; tool-specific entrypoints may use symlinks such as `home/dot_claude/symlink_CLAUDE.md` so guidance does not drift.

Allowed live links are limited to repo-local executable wrappers that must run directly from the checkout and tool-adapter pointers that prevent duplicated instruction files. Everything else should be a rendered chezmoi target unless an app-specific plan says otherwise.

## Current To Target Mapping

| Current path | Target | Phase | State |
| --- | --- | --- | --- |
| `zshenv` | `home/dot_zshenv.tmpl` | 1 | implemented |
| `zprofile`, `zshrc`, `zlogin` | `home/dot_config/zsh/dot_zprofile`, `dot_zshrc`, `dot_zlogin` | 1 | implemented |
| `init.sh`, `zinit-init.zsh`, `zsh/` | `home/dot_config/zsh/` | 1 | implemented |
| `.agents/` | `home/dot_agents/` rendered source state; move volatile state to XDG state | 1 | implemented rendered source state |
| `.codex/` | `home/dot_codex/` rendered source state; split local project trust into local config | 1 | implemented rendered source state; trust split still open |
| `.claude/` | `home/dot_claude/` rendered source state; `CLAUDE.md` is a symlink adapter to `../.agents/AGENTS.md` | 1 | implemented rendered source state plus instruction symlink |
| `.mcp.json` | `home/private_dot_mcp.json` | 1 | implemented |
| `bin/` | repo root; selected wrappers exposed through `home/bin/symlink_*.tmpl` | 1 | implemented |
| `.config/grm/config.toml` | `home/dot_config/grm/config.toml` | 1 | implemented |
| `.config/gemini-meeting-sync/config.json` | `home/dot_config/gemini-meeting-sync/config.json`; local `enabled` marker remains untracked | 2 | implemented |
| `macos` defaults baseline | inlined in `home/.chezmoiscripts/run_onchange_after_30-macos-defaults.sh.tmpl`. Idempotent at the cfprefsd level; chezmoi run_onchange gates re-execution on script-content change | 1 | implemented |
| `install.sh`, `bootstrap.sh` | both removed; bootstrap is the chezmoi one-liner (`sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply prateek`) plus a one-time `xcode-select --install` | 0 |`install.sh` and `bootstrap.sh` both deleted (commit `569cadb`) |
| `Brewfile`, `Brewfile.core` | `home/.chezmoidata/packages.toml` declares profiles. `home/.chezmoitemplates/brewfile.tmpl` renders the Bundle input; `home/.chezmoiscripts/run_onchange_after_10-brew-bundle.sh.tmpl` inlines that template and pipes to `brew bundle`. Audit/CI use `scripts/packages/render-brewfile` to invoke the same template | 2 | implemented |
| `.config/mise/`, `.config/tmux/`, `.config/worktrunk/`, `.config/borders/` | `home/dot_config/<name>/` | 2 | implemented |
| `.config/kanata/kanata.kbd` | `home/dot_config/kanata/kanata.kbd`; replaces the previous Karabiner key remaps and targets `Apple Internal Keyboard / Trackpad` explicitly. Karabiner-Elements remains installed only for its macOS virtual HID driver until there is a driver-only package path. | 2 | implemented |
| `nvim/` | `home/dot_config/nvim/` | 2 | implemented |
| `gitconfig`, `vimrc`, `inputrc`, `lesskey` | native `home/dot_*` files | 2 | implemented |
| `osx-apps/vscode/` | `home/Library/Application Support/Code/User/`; extension captures under XDG state only | 2 | implemented |
| `vscode/` | reconcile into the same `home/Library/...` targets, then remove the legacy tree | 2 | deferred |
| `osx-apps/ghostty/config` | `home/dot_config/ghostty/config` | 2 | implemented |
| `osx-apps/defaults/*.plist` | selected XML plist patches at `home/.chezmoitemplates/<bundle-id>.plist.tmpl` driven by 3-line `modify_` stubs through the shared engine (see Plist Management; transition layout still uses `home/.chezmoiassets/Library/Preferences/*.json`); Apple/global scalar defaults are inlined in `home/.chezmoiscripts/run_onchange_after_30-macos-defaults.sh.tmpl`. Raw captures under XDG state only | 3 | implemented for selected app config; broad plist dumps not committed |
| `osx-apps/iterm2/` | not managed; iTerm2 app state remains local | 3 | removed from app config |
| `osx-apps/Moom.plist` | desired-plist fragment at `home/.chezmoitemplates/com.manytricks.Moom.plist.tmpl`; `home/Library/Preferences/modify_private_com.manytricks.Moom.plist.tmpl` is a 3-line stub that runs the shared engine. Geometry strings containing literal `{{`/`}}` are wrapped in `{{ "..." }}` to escape Go template parsing. | 3 |implemented (shared engine, commit `b2b43de`) |
| `osx-apps/alfred/` | not managed; app-native sync and local captures remain outside source | 3 | removed from app config |
| `osx-apps/chrome/policies/` | privileged opt-in. Force-install extension list inlined in `scripts/macos/render-chrome-policy.py`; plist installed by `scripts/macos/apply.sh` when run with `DOTFILES_APPLY_PRIVILEGED_APP_ASSETS=1` | 3 | implemented |
| `BetterTouchTool preferences` | desired-plist fragment at `home/.chezmoitemplates/com.hegenberg.BetterTouchTool.plist.tmpl`; `home/Library/Preferences/modify_private_com.hegenberg.BetterTouchTool.plist.tmpl` is a 3-line stub that runs the shared engine. Trigger stores, clipboard databases, usage, license, remote-device, and window state stay local or in app sync. | 3 |implemented (shared engine, commit `b2b43de`) |
| `Raycast preferences` | desired-plist fragment at `home/.chezmoitemplates/com.raycast.macos.plist.tmpl`; `home/Library/Preferences/modify_private_com.raycast.macos.plist.tmpl` is a 3-line stub that runs the shared engine. Cloud sync records, encrypted databases, notes IDs, analytics IDs, window state, account state, and extension data stay local or in Raycast sync. | 3 |implemented (shared engine, commit `b2b43de`) |
| `Tailscale preferences` | desired-plist fragment at `home/.chezmoitemplates/io.tailscale.ipn.macsys.plist.tmpl`; `home/Library/Preferences/modify_private_io.tailscale.ipn.macsys.plist.tmpl` is a 3-line stub that runs the shared engine. Cached profiles, restart state, VPN runtime state, and account data stay local. | 3 |implemented (shared engine, commit `b2b43de`) |
| `Setapp preferences` | desired-plist fragment at `home/.chezmoitemplates/com.setapp.DesktopClient.plist.tmpl`; `home/Library/Preferences/modify_private_com.setapp.DesktopClient.plist.tmpl` is a 3-line stub that runs the shared engine. Account, subscription, app catalog, notification token, analytics, and installed Setapp-app state stay local. | 3 |implemented (shared engine, commit `b2b43de`) |
| `BetterDisplay preferences` | desired-plist fragment at `home/.chezmoitemplates/pro.betterdisplay.BetterDisplay.plist.tmpl`; `home/Library/Preferences/modify_private_pro.betterdisplay.BetterDisplay.plist.tmpl` is a 3-line stub that runs the shared engine. Display identifiers, display topology, color profile paths, license files, and per-monitor state stay local. | 3 |implemented (shared engine, commit `b2b43de`) |
| `osx-apps/orbstack/` | desired-plist fragment at `home/.chezmoitemplates/dev.kdrag0n.MacVirt.plist.tmpl`; `home/Library/Preferences/modify_private_dev.kdrag0n.MacVirt.plist.tmpl` is a 3-line stub that runs the shared engine. License, onboarding, selected tab, update, and window state stay local. | 3 |implemented (shared engine, commit `b2b43de`) |
| `osx-apps/leader-key/` | native JSON target under `home/Library/Application Support/Leader Key/config.json.tmpl`; raw captures under XDG state only | 3 | implemented |
| `osx-apps/defaults/com.jordanbaird.Ice.plist` | desired-plist fragment at `home/.chezmoitemplates/com.jordanbaird.Ice.plist.tmpl`; `home/Library/Preferences/modify_private_com.jordanbaird.Ice.plist.tmpl` is a 3-line stub that runs the shared engine. Hotkeys, icon JSON, menu-bar layout, update state, and window state stay local. | 3 |implemented (shared engine, commit `b2b43de`) |
| `osx-apps/defaults/com.prakashjoshipax.VoiceInk.plist` | desired-plist fragment at `home/.chezmoitemplates/com.prakashjoshipax.VoiceInk.plist.tmpl`; the prompt array is included from `home/.chezmoitemplates/voiceink-prompts.json` via `{{ include ... \| html }}`. `home/Library/Preferences/modify_private_com.prakashjoshipax.VoiceInk.plist.tmpl` is a 3-line stub that runs the shared engine. The fragment uses the `<!-- chezmoi-delete: ... -->` directive to actively remove `didMigrateHotkeys_v2`. Keychain migration flags, selected audio device, trial/update state, and window state stay local. | 3 |implemented (shared engine, commit `b2b43de`) |
| `osx-apps/nvALT.clr` | desired-plist fragment at `home/.chezmoitemplates/net.elasticthreads.nv.plist.tmpl`; `home/Library/Preferences/modify_private_net.elasticthreads.nv.plist.tmpl` is a 3-line stub that runs the shared engine. The color list at `home/Library/Colors/modify_private_nvALT.clr.tmpl` is generated separately from JSON in `home/.chezmoiassets/Library/Colors/` because it is not a plist (NSColor archive). Window state, notes location aliases, font archives, update state, and search state stay local. | 3 | implemented (shared engine for the plist, commit `b2b43de`; color list keeps its separate generator) |
| `osx-apps/cmux/` | desired-plist fragment at `home/.chezmoitemplates/com.cmuxterm.app.plist.tmpl`; `home/Library/Preferences/modify_private_com.cmuxterm.app.plist.tmpl` is a 3-line stub that runs the shared engine. Reusable icon asset stays under `scripts/macos/assets/cmux/`. Session state, browser history, PostHog cache, and icon backups stay local. | 3 |implemented (shared engine, commit `b2b43de`) |
| `LaunchControl, Monodraw, Arq, Superset` | package install only for apps with casks in `home/.chezmoidata/packages.toml`; no committed app config today. The sampled state is update/trial/window state, Arq warning/license flags, or Electron browser/cache/account state. | 3 | local-only app state |
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

- Bootstrap is the chezmoi one-liner. `xcode-select --install` is a manual one-time prompt; everything after is `sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply prateek`. Homebrew installs via `run_once_before_00-homebrew.sh.tmpl`; other runtimes (uv for ad-hoc helpers, mise, etc.) come in via the chezmoi-driven `brew bundle` step or per-helper.
- The `full` package profile installs `aria2` and the bottled `homebrew/core/xcodes` formula. It selects and sets up pinned Xcode when it is already installed. It downloads Xcode through `xcodes` only when `install_xcode=true` or `DOTFILES_INSTALL_XCODE=true`, because Apple may require Apple ID login. Xcode-required Homebrew formulae run after Xcode first-launch setup, not in the main Brewfile.
- Privileged phases call the shared sudo helper only when they need it. The helper prompts once, keeps sudo warm until `run_after_99-sudo.sh.tmpl`, and does not clear a sudo credential that was already active before the apply.
- Put package installs, mise runtime install, zinit compatibility wiring, Hammerspoon compilation, selected macOS defaults, and post-apply verification under `home/.chezmoiscripts/`.
- Put shared shell helpers for those scripts under `home/.chezmoitemplates/` and include them from each script. Keep individual scripts short: data selection, command execution, and clear blocker output.
- Use `run_once_before_` for one-time prerequisites and `run_onchange_after_` for work that should rerun when its rendered script content changes.
- `run_onchange_` scripts that depend on repo-root files or structured data must embed dependency hashes in rendered comments. Mise config, package data, and defaults manifests do not trigger reruns unless the script template includes their content hash.
- Every script must be idempotent. A rerun should converge or report a clear blocker, not duplicate state.
- Scripts must use explicit XDG paths and the rendered `dotfiles_dir` data value. Do not infer the repo from the process working directory.
- Scripts that require secrets, GUI sign-in, TCC permissions, or privileged profile installation must be gated by data flags and fail closed with a specific manual step.
- Prefer `.chezmoiexternal.*` over script-managed `git clone` when a dependency is just a repository or archive. Git-repo externals must set a `refreshPeriod` or be refreshed through `chezmoi apply --refresh-externals=auto`; otherwise chezmoi may keep an existing checkout unchanged.

Default `chezmoi apply` may run home-state scripts and apply declared home source state. That includes ordinary app files, selected preference plist `modify_` targets, and secret-backed private files when `secrets_enabled=true`. High-risk imperative changes — privileged policy writes, app license activation, permission/profile changes, or non-chezmoi app mutations — live behind explicit data gates and focused helper scripts under `scripts/`. Risky helpers may write a local preflight or capture record before mutating state; that record is scoped to the helper that wrote it. There is no requirement for a generic transaction wrapper. Repo-state rollback is `git checkout <prev>` then `chezmoi apply`.

## Repo Tooling

Keep `Makefile` at the repo root. It is not user configuration; it is the stable command surface for local and Tart validation. The Makefile remains the repo-local validation facade even after `bin/dotfiles` is retired as a public CLI; short Make aliases for common chezmoi checks (`apply --dry-run`, `status`, `verify`) are fine, but their implementation lives in chezmoi or focused scripts.

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
  packages.toml
  secrets.toml
  licenses.toml
home/.chezmoiassets/
  Library/Colors/nvALT.clr.json    # NSColor archive payload, not a plist
home/.chezmoitemplates/
  brewfile.tmpl                            # rendered by run_onchange_after_10 + scripts/packages/render-brewfile
  plist-merge-prelude.py
  plist-merge-postlude.py
  com.manytricks.Moom.plist.tmpl
  com.jordanbaird.Ice.plist.tmpl
  com.prakashjoshipax.VoiceInk.plist.tmpl
  dev.kdrag0n.MacVirt.plist.tmpl
  net.elasticthreads.nv.plist.tmpl
  com.cmuxterm.app.plist.tmpl
  com.hegenberg.BetterTouchTool.plist.tmpl
  com.raycast.macos.plist.tmpl
  io.tailscale.ipn.macsys.plist.tmpl
  com.setapp.DesktopClient.plist.tmpl
  pro.betterdisplay.BetterDisplay.plist.tmpl
  voiceink-prompts.json
```

Layout notes during the plist refactor: per-app fragments under `.chezmoitemplates/<bundle-id>.plist.tmpl` are the post-refactor home for plist source. The pre-refactor JSON files under `home/.chezmoiassets/Library/Preferences/` continue to work via the same shared engine until each app is migrated; see Plist Management for the migration order.

Rules:

- Stable target files go under `home/` at the real target path.
- Apple/global macOS defaults are inlined as plain `defaults write ...` calls in `home/.chezmoiscripts/run_onchange_after_30-macos-defaults.sh.tmpl`, not in a separate data file. The `run_onchange_` mechanism re-runs the script when its content changes, so editing a default is the only thing needed.
- Bootstrap defaults are inlined as Go template literals inside `home/.chezmoi.toml.tmpl` (e.g. `"full"`, `false`, `true`) — chezmoi `init` renders the toml template before `.chezmoidata/*.toml` loads, so a separate data file is unreadable at init time. Same for the prompt fallbacks. There is no longer a `home/.chezmoidata/bootstrap.toml`, `features.toml`, or `permissions.toml` — those were dead-data files with no consumers and were deleted.
- Machine-local bootstrap data lives in the generated chezmoi config under `[data]`, not in committed `.chezmoidata`. That includes the resolved `dotfiles_dir`, local source overrides, host identity, and any temporary Tart paths.
- Per-app preferences (nested plists) go through the plist `modify_` pattern: a desired-plist fragment at `home/.chezmoitemplates/<bundle-id>.plist.tmpl` plus a 3-line `modify_` stub at the target path. See Plist Management. There is no `home/.chezmoidata/apps/` directory — that mechanism was retired with `bin/dotfiles`.
- A file-only app should be package-gated in `home/.chezmoiignore` so absent apps are unmanaged instead of receiving placeholder config. Test those templates directly and test the managed/ignored profile behavior in focused tests.
- `home/.chezmoiassets/` is source-only supporting data. Chezmoi ignores it as a target because it begins with `.chezmoi`, but templates and modify scripts can read files from it via `.chezmoi.sourceDir`. After the plist refactor it holds only non-template payloads (binary blobs, NSColor archives, `.mobileconfig` profiles).
- `home/.chezmoitemplates/` is the chezmoi-native home for shared template fragments included with `{{ template "name" . }}`. After the refactor it holds both the shared plist merge engine (`plist-merge-prelude.py`, `plist-merge-postlude.py`) and per-app desired-plist fragments (`<bundle-id>.plist.tmpl`). Plist values containing literal `{{` or `}}` (Moom geometry strings are the main case) must be wrapped in `{{ "..." }}` to escape Go template parsing.

- Prefer app-supported config directories under XDG paths when the app provides that setting. For example, an app like iTerm2 can read preferences from a custom folder; manage that folder as source state and use a small defaults step to point the app at it. Use direct `Library/` targets only when the app has no stable custom-folder mechanism.
- App-native sync folders must be selected per app. For Alfred, keep preferences and workflows out of source until there is an explicit redaction/adoption path.
- Raw exports, local captures, generated inventories, and rollback transactions are local XDG state, not repo files.
- Test fixtures live under `tests/fixtures/`; sanitized examples live under `docs/dev/` only when they explain a decision.
- Mackup is a research/catalog input only. When Mackup is installed, first evaluate `chezmoi mackup add <application>` in a throwaway source state to discover candidate paths. The command reads `~/.mackup/<application>.cfg` before Mackup's packaged catalog, adds existing `configuration_files` from `$HOME`, maps `xdg_configuration_files` under `$XDG_CONFIG_HOME`, and ignores missing files.
- Treat `chezmoi mackup add` output as local discovery input, not as an adoption step. Mackup is not the policy engine; it discovers candidate paths, and this repo only records the config it applies.
- Secret scanning for Mackup-derived candidates remains a Phase 3 adoption-tooling decision. That phase chooses whether discovery runs with `--secrets=error`, `--secrets=warning`, or `--secrets=ignore`.
- Never use Mackup link mode, whole-domain `defaults import`, bulk folder adoption, direct TCC SQLite writes, or default PPPC profile installation.

## Plist Management

Selected app preference plists are managed through chezmoi `modify_` targets that share one engine. Each managed plist has:

- a clean XML data fragment in `home/.chezmoitemplates/<bundle-id>.plist.tmpl` that uses chezmoi template syntax for secrets (`{{ onepasswordRead "op://..." }}`), included payloads (`{{ include "..." | html }}`), and per-host conditionals (`{{ if eq .chezmoi.hostname "..." }}`);
- a 3-line `modify_private_<bundle-id>.plist.tmpl` stub at the target path that includes the engine prelude, base64-includes the per-app fragment, and includes the engine postlude;
- optional embedded directives in the fragment. Today: `<!-- chezmoi-delete: key1, key2 -->` at the top of the fragment actively removes those keys from the target plist on apply. The directive is parsed from the rendered XML by the engine, not by chezmoi.

The shared engine lives in two fragments at `home/.chezmoitemplates/`:

- `plist-merge-prelude.py`: shebang and imports (`base64`, `copy`, `io`, `os`, `plistlib`, `re`, `sys`).
- `plist-merge-postlude.py`: extracts the delete directive, parses desired XML, reads stdin as the current plist, applies deletes, then upserts each desired key. Upserts skip any key whose value already byte-equals the current value (`plistlib.dumps(...) == plistlib.dumps(...)`) so re-encoding does not produce spurious rewrites. With `CHEZMOI_VERBOSE=1` (set by `chezmoi apply -v`) the engine emits per-key set/delete lines to stderr.

Cross-cutting concerns are declared in `home/.chezmoi.toml.tmpl` and run through chezmoi's hook system:

- `[[diff.textconv]]` with pattern `**/Library/Preferences/*.plist` and command `plutil -convert xml1 -o - -` so `chezmoi diff` shows readable XML for binary plists.
- `hooks.apply.pre` runs `scripts/chezmoi-hooks/guard-running-apps.sh`. The guard reads `chezmoi status` to compute the bundle IDs whose target plist would actually change this apply, intersects with currently running apps via `lsappinfo info -only bundleid`, and refuses the apply if any are running. The guard is overridable with `DOTFILES_SKIP_PLIST_HOOKS=1`. It writes the pending list to `${XDG_STATE_HOME:-~/.local/state}/dotfiles/plist-pending.txt` for the post-hook.
- `hooks.apply.post` runs `scripts/chezmoi-hooks/post-apply-plists.sh`. It exits early when no plists were pending. Otherwise it kills `cfprefsd` once so the next read picks up the new files. Optional relaunch of the apps the user quit is gated behind `DOTFILES_RELAUNCH_AFTER_APPLY=1` and is off by default.

Sandboxed apps are addressed by mirroring the target path under `home/`. A sandboxed app's modify stub lives at `home/Library/Containers/<id>/Data/Library/Preferences/modify_private_<id>.plist.tmpl` and chezmoi routes the write to the container path automatically. There is no flag; filename location is the contract.

Tests live alongside the existing fixture tests under `tests/`:

- `tests/plist-merge-engine.zsh`: engine-level fixtures for empty stdin, populated stdin with overlap, delete directive applied, byte-identity skip, and verbose output. Independent of any one app.
- `tests/plist-templates-lint.zsh`: renders every `home/.chezmoitemplates/*.plist.tmpl` via `chezmoi execute-template --file` and pipes the result through `plutil -lint -s -` to catch escape errors and malformed XML. Pre-commit-friendly.
- Per-app `tests/<app>-plist-modify.zsh`: existing pattern unchanged. Render the per-app `modify_` stub via `chezmoi execute-template --file`, run it against fixture stdin, assert the merged binary plist round-trips to the expected dict.

Migration order — **two phases**, hard cut:

1. **DONE (commit `a3bc348`).** Added `[[textconv]]` for `**/Library/Preferences/*.plist`, `[hooks.apply.pre]` → `scripts/chezmoi-hooks/guard-running-apps.sh`, `[hooks.apply.post]` → `scripts/chezmoi-hooks/post-apply-plists.sh`. Test coverage: `tests/plist-hooks.zsh` (`make test-plist-hooks`, also wired into `.github/workflows/install-smoke.yml`). Override env vars: `DOTFILES_SKIP_PLIST_HOOKS=1` (force apply despite running apps), `DOTFILES_RELAUNCH_AFTER_APPLY=1` (relaunch quit apps post-apply, off by default).

2. **Hard cut, single PR.** Write the shared engine in `home/.chezmoitemplates/plist-merge-prelude.py` + `plist-merge-postlude.py` reading **only** the new XML fragments (no JSON-source compatibility branch). Convert all 11 managed apps to `home/.chezmoitemplates/<bundle-id>.plist.tmpl` fragments plus 3-line `modify_` stubs. Delete every legacy sidecar under `home/.chezmoiassets/Library/Preferences/`. Special cases handled inline:
   - **VoiceInk.** Move `customPrompts` to `home/.chezmoitemplates/voiceink-prompts.json` (included via `{{ include "voiceink-prompts.json" | html }}`). Use `<!-- chezmoi-delete: didMigrateHotkeys_v2 -->` instead of upserting that key. Do **not** reintroduce `KeyboardShortcuts_toggleEnhancement` — the app's `MiniRecorderShortcutManager` lifecycles it; persisting it causes apply churn (Codex finding, fix in `b7281c7`).
   - **Moom.** Geometry strings contain literal `{{`/`}}` — wrap them in `{{ "..." }}` to escape Go template parsing.
   - **Sandbox audit per app** (`mdls -name kMDItemAppStoreCategory` or `~/Library/Containers/<id>/` check). None of the 11 are believed sandboxed; if any is, its stub goes at `home/Library/Containers/<id>/Data/Library/Preferences/modify_private_<id>.plist.tmpl`.
   - **Per-app fixture tests** (`tests/<app>-plist-modify.zsh`) stay green — same pattern: render the per-app stub via `chezmoi execute-template --file`, run against fixture stdin, assert merged output.

After step 2: per-host variation, additional sandbox routing, and additional template-side transforms are deferred until a concrete need appears.

### Known caveats from step 1

- **`chezmoi status` from inside a pre-hook may collide with chezmoi's persistent-state lock.** The guard script handles this defensively (`chezmoi status 2>/dev/null || true` falls through to "no pending" → no apps flagged), so the worst case is the guard becomes a no-op rather than failing the apply. We have not yet observed a real failure on a real `chezmoi apply`. Verify on the next non-dry-run apply, and if the lock collision is real, switch to deriving pending bundle IDs from `find $CHEZMOI_SOURCE_DIR/Library/Preferences/modify_private_*.plist.tmpl` instead. The guard's pending-list state file (`${XDG_STATE_HOME}/dotfiles/plist-pending.txt`) is the contract the post-hook depends on; preserve that no matter how the list is computed.
- **Hooks fire on every `chezmoi apply` invocation** including ones that touch zero plists. Both scripts are designed to no-op cheaply in that case. If they ever start adding noticeable apply latency, profile before adding more conditional logic.
- **`/usr/bin/lsappinfo` is hardcoded as an absolute path** so the guard cannot be tricked by a hostile PATH. Tests substitute it via `sed` over a temp copy of the script. Do not change the absolute paths in production scripts without updating `tests/plist-hooks.zsh` to match.

### Step 2 inventory

The 11 currently managed plists. The hard cut writes a fragment + stub for each, deletes its sidecar, and keeps the existing fixture test green.

| Bundle ID | Modify script (target path) | Sidecar to delete | Fixture test |
| --- | --- | --- | --- |
| `com.jordanbaird.Ice` | `home/Library/Preferences/modify_private_com.jordanbaird.Ice.plist.tmpl` | `home/.chezmoiassets/Library/Preferences/com.jordanbaird.Ice.json` | `tests/ice-plist-modify.zsh` |
| `com.prakashjoshipax.VoiceInk` | `home/Library/Preferences/modify_private_com.prakashjoshipax.VoiceInk.plist.tmpl` | `home/.chezmoiassets/Library/Preferences/com.prakashjoshipax.VoiceInk.json` | `tests/voiceink-plist-modify.zsh` |
| `dev.kdrag0n.MacVirt` | `home/Library/Preferences/modify_private_dev.kdrag0n.MacVirt.plist.tmpl` | `home/.chezmoiassets/Library/Preferences/dev.kdrag0n.MacVirt.json` | `tests/orbstack-plist-modify.zsh` |
| `net.elasticthreads.nv` | `home/Library/Preferences/modify_private_net.elasticthreads.nv.plist.tmpl` | `home/.chezmoiassets/Library/Preferences/net.elasticthreads.nv.json` | `tests/nvalt-plist-modify.zsh` |
| `com.cmuxterm.app` | `home/Library/Preferences/modify_private_com.cmuxterm.app.plist.tmpl` | `home/.chezmoiassets/cmux/preferences.json` (atypical path) | `tests/cmux-plist-modify.zsh` |
| `com.manytricks.Moom` | `home/Library/Preferences/modify_private_com.manytricks.Moom.plist.tmpl` | `home/.chezmoiassets/com.manytricks.Moom.plist` (raw XML, not JSON) | `tests/moom-plist-modify.zsh` |
| `com.hegenberg.BetterTouchTool` | `home/Library/Preferences/modify_private_com.hegenberg.BetterTouchTool.plist.tmpl` | `home/.chezmoiassets/Library/Preferences/com.hegenberg.BetterTouchTool.json` | `tests/selected-app-plist-modify.zsh` |
| `com.raycast.macos` | `home/Library/Preferences/modify_private_com.raycast.macos.plist.tmpl` | `home/.chezmoiassets/Library/Preferences/com.raycast.macos.json` | `tests/selected-app-plist-modify.zsh` |
| `io.tailscale.ipn.macsys` | `home/Library/Preferences/modify_private_io.tailscale.ipn.macsys.plist.tmpl` | `home/.chezmoiassets/Library/Preferences/io.tailscale.ipn.macsys.json` | `tests/selected-app-plist-modify.zsh` |
| `com.setapp.DesktopClient` | `home/Library/Preferences/modify_private_com.setapp.DesktopClient.plist.tmpl` | `home/.chezmoiassets/Library/Preferences/com.setapp.DesktopClient.json` | `tests/selected-app-plist-modify.zsh` |
| `pro.betterdisplay.BetterDisplay` | `home/Library/Preferences/modify_private_pro.betterdisplay.BetterDisplay.plist.tmpl` | `home/.chezmoiassets/Library/Preferences/pro.betterdisplay.BetterDisplay.json` | `tests/selected-app-plist-modify.zsh` |

Concrete shapes:

- **Per-app stub** (3 lines, identical shape across all 11; Go templates require the included template name to be a string constant, so the bundle ID is spelled out per stub):
  ```python
  {{ template "plist-merge-prelude.py" . }}
  desired_xml = base64.b64decode("{{ template "<bundle-id>.plist.tmpl" . | b64enc }}")
  {{ template "plist-merge-postlude.py" . }}
  ```
- **Engine** (`plist-merge-prelude.py` + `plist-merge-postlude.py`) reads stdin as the current binary plist, parses `desired_xml` (already an XML plist by the time it reaches the engine), extracts `<!-- chezmoi-delete: key1, key2 -->` directives from the rendered XML, applies deletes, then upserts only keys whose binary plist serialization differs from current (`_byte_equal` skip — preserves byte layout when nothing changed). Verbose per-key log when `CHEZMOI_VERBOSE=1`.
- The `nvalt` color list at `home/Library/Colors/modify_private_nvALT.clr.tmpl` is **not** part of this refactor — it's an NSColor archive, not a plist; its generator stays.

## Secrets, Licenses, And Permissions

Committed `op://` references are allowed when the vault, item, and field identifiers are obfuscated IDs. Human-readable vault names, item names, account names, and field names still leak metadata and stay out of committed files.

Rules:

- Public committed refs use repo-local aliases or obfuscated `op://` IDs.
- Untracked local config maps aliases to human-readable 1Password refs when that is more convenient locally.
- Name-bearing refs such as `op://Private/...`, account labels, and direct refs with readable item or field names live only in untracked local config.
- Secret-backed config files list their target paths in `secrets.paths`; license files list theirs in `licenses.paths`. `.chezmoiignore` skips both unless `secrets_enabled=true`.
- Secret templates use `onepasswordRead .secrets.refs.<name>` behind an explicit `secrets_enabled` guard and must not evaluate `op` calls during public bootstrap.
- License files are never committed.
- License files are private chezmoi templates in v1. If an app needs imperative activation or keychain mutation, keep it manual until a focused helper under `scripts/` covers that app, gated by an explicit data flag.
- License fingerprints are local-only. If needed, use a per-machine untracked salt/HMAC and do not emit the result in normal JSON.
- Permission manifests may use `desired = "manual"` without a code requirement. Profile-managed permissions require non-empty, verified code requirements.
- Raw TCC rows are never emitted. Reports use service, declared app ID, status enum, and redacted reason.

## Chezmoi Interface And Focused Helpers

Chezmoi is the ongoing user-facing command surface. There is no second CLI; `bin/dotfiles` was retired and removed.

Daily and operational commands are native chezmoi:

```sh
chezmoi apply
chezmoi apply --dry-run --verbose --exclude=scripts
chezmoi status
chezmoi diff
chezmoi verify
chezmoi managed
chezmoi unmanaged
chezmoi ignored
chezmoi data
chezmoi edit <target>
chezmoi add <path>
chezmoi re-add
```

Repo helper scripts live under `scripts/` and exist when shell or Go templates would be worse than typed code or already-tested logic. Examples in scope:

- **Package renderer.** `home/.chezmoidata/packages.toml` is the desired state. `home/.chezmoitemplates/brewfile.tmpl` renders the Bundle input. `home/.chezmoiscripts/run_onchange_after_10-brew-bundle.sh.tmpl` inlines that template via `{{ template "brewfile.tmpl" . }}` and pipes to `brew bundle --file=-` (chezmoi declarative-install pattern). The same template is exposed to audit scripts and CI through the focused wrapper `scripts/packages/render-brewfile`. Profile selection (`core`/`full`), MAS opt-in (`DOTFILES_INSTALL_MAS_APPS=true` or `--include-mas`), tap URLs, cask args, appdir args, and quoting are covered by tests independent of the chezmoi script.
- **macOS defaults applier.** `home/.chezmoiscripts/run_onchange_after_30-macos-defaults.sh.tmpl` inlines `defaults write` calls for the desired Apple/global keys. No separate data file, no applier helper. The script is small enough that the desired state is the script.
- **Capture and audit helpers** under `scripts/macos/capture.sh` and `scripts/audit/*` encode redaction and classification knowledge that does not belong inline in chezmoi templates.
- **Plist hooks** under `scripts/chezmoi-hooks/` (see Plist Management).

These helpers are implementation details. They do not form a second public command surface and they do not replace native chezmoi commands for status, diff, apply, or adoption.

### Adoption and inventory

Use chezmoi natives:

- `chezmoi status` for "what would change on the next apply."
- `chezmoi diff` for the actual content delta.
- `chezmoi unmanaged` and `chezmoi ignored` for "what's in HOME that isn't tracked."
- `chezmoi add <path>` / `chezmoi re-add` to bring real files into source state.

Where redaction or classification is needed (for example, "snapshot relevant macOS state without leaking secrets, account state, or volatile UI state"), keep a focused capture script such as `scripts/macos/capture.sh`. These scripts write machine-local observations under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/` and are not part of any apply flow. LLM/skill-assisted review is allowed when the human review value justifies it.

There is no permanent `adopt` subcommand. Promotion of a captured value into desired state is a regular edit-and-commit step.

### Rollback

Default rollback is desired-state rollback:

```sh
git checkout <prev-commit>
chezmoi apply
```

This recovers the repo's stated intent and re-runs idempotent home-state apply. It does not promise byte-exact recovery of live-machine state that the old apply touched.

Exact live-machine rollback is not a general promise of the architecture. A risky imperative helper may write its own preflight or capture record before mutating state and may expose a focused undo path; that record and that undo are scoped to the helper. They are not centralized infrastructure and they do not require a generic transaction wrapper around chezmoi.

Package and runtime changes are not generally rollbackable. The renderer and applier produce reviewable diffs (the rendered Brewfile, the parsed defaults plan); recovery from a bad package change is `git checkout` plus rerun.

## Bootstrap And Normal Workflows

There is no `install.sh`. Bootstrap is the chezmoi-blessed one-liner plus a one-time Xcode Command Line Tools prompt:

```sh
# 1. Install Xcode Command Line Tools (one-time GUI prompt).
xcode-select --install

# 2. Run the chezmoi one-liner. Downloads chezmoi, clones this repo,
#    runs the init template (which prompts for first-machine settings),
#    then applies. CI / Tart can set the env vars below to bypass prompts.
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply prateek
```

Reference: <https://www.chezmoi.io/user-guide/setup/> and <https://www.chezmoi.io/user-guide/daily-operations/#install-chezmoi-and-your-dotfiles-on-a-new-machine-with-a-single-command>.

`home/.chezmoi.toml.tmpl` uses `promptStringOnce` and `promptBoolOnce` to gather first-machine settings, with env-var override for non-interactive runs:

| Setting | Prompt | Env override (non-interactive) | Default |
| --- | --- | --- | --- |
| Install profile (`install_profile`) | "Which package profile? (core/full)" | `DOTFILES_INSTALL_PROFILE` | `full` |
| Apply macOS defaults (`apply_macos_defaults`) | "Apply macOS defaults from this repo?" | `DOTFILES_APPLY_DEFAULTS` | `true` |
| Run install scripts (`run_install_scripts`) | "Run install scripts (Homebrew bundle, mise, etc.) on apply?" | `DOTFILES_RUN_INSTALL_SCRIPTS` | `true` |
| Secrets enabled (`secrets_enabled`) | "Render secret-backed files via 1Password?" | `DOTFILES_SECRETS_ENABLED` | `false` |
| Install Xcode (`install_xcode`) | none; explicit opt-in to Apple ID-backed Xcode download | `DOTFILES_INSTALL_XCODE` | `false` |

Once answered, the values land in the rendered chezmoi config and survive subsequent `chezmoi apply` runs. Re-prompt by deleting the generated `~/.config/chezmoi/chezmoi.toml` and re-running `chezmoi init`.

Package install tuning is environment-only. `DOTFILES_HOMEBREW_BUNDLE_JOBS` controls `brew bundle install --jobs` when the installed Homebrew supports it; default is `auto`; native `HOMEBREW_BUNDLE_JOBS` is honored when the dotfiles override is unset. `DOTFILES_HOMEBREW_DOWNLOAD_CONCURRENCY` maps to `HOMEBREW_DOWNLOAD_CONCURRENCY`; default is `auto`.

Ruby installs use mise's precompiled Ruby path with GitHub attestation checks disabled by default. Fresh machines usually do not have authenticated GitHub API access yet, and unauthenticated attestation verification can hit the public rate limit before the runtime install completes.

Chezmoi then owns ongoing setup:

1. `run_once_before_00-homebrew.sh.tmpl` installs Homebrew if missing (CLT bundles git, but not brew).
2. `run_once_before_05-core-tools.sh.tmpl` ensures `git` and `chezmoi` exist (Homebrew-installed if missing). Other runtimes come in via the brew-bundle step or per-helper.
3. `.chezmoiexternal.toml.tmpl` clones zinit and other clone-only dependencies and refreshes them according to their declared `refreshPeriod` or `chezmoi apply --refresh-externals=auto`.
4. `run_onchange_after_10-brew-bundle.sh.tmpl` inlines `home/.chezmoitemplates/brewfile.tmpl` and pipes the rendered Brewfile into `brew bundle --file=-`.
5. `run_onchange_after_15-xcode.sh.tmpl` selects the canonical Xcode for the `full` profile when it is installed, downloads it through `xcodes` only when explicitly opted in, runs Xcode first-launch setup, and then installs Xcode-required formulae.
6. `run_onchange_after_20-mise-install.sh.tmpl` trusts repo-owned mise config and installs runtimes.
7. `run_onchange_after_30-macos-defaults.sh.tmpl` inlines the desired Apple/global defaults as plain `defaults write` calls. Idempotent at the cfprefsd level; chezmoi run_onchange gates re-execution on script-content change. There is no separate data file or applier helper.
8. `run_after_90-verify.sh.tmpl` runs cheap post-apply validation and prints manual blockers for secrets, sign-in, licenses, or permissions.
9. `run_after_99-sudo.sh.tmpl` stops the shared sudo keepalive if a privileged phase started it.

Secret-bearing templates render only when `secrets_enabled=true`. Secret-backed paths are ignored otherwise, so public bootstrap does not create empty license/config files. If `op` is unauthenticated, chezmoi fails closed with the 1Password sign-in prompt.

CI and Tart non-interactive bootstrap: set the env vars above before invoking the chezmoi one-liner. The `promptStringOnce`/`promptBoolOnce` calls honor env overrides and skip the interactive prompt.

### Normal workflows

Update from the repo and apply:

```sh
cd ~/dotfiles
git pull --ff-only
chezmoi apply
chezmoi status
```

Preview before applying:

```sh
chezmoi apply --dry-run --verbose --exclude=scripts
chezmoi diff
```

Edit a managed target through chezmoi:

```sh
chezmoi edit ~/.config/zsh/.zshrc
chezmoi apply
chezmoi status
git diff
```

Inspect what's tracked vs. unmanaged:

```sh
chezmoi managed
chezmoi unmanaged
chezmoi ignored
chezmoi data        # show resolved template data for this machine
```

Adopt drift back into source state:

```sh
chezmoi status                  # see what would change
chezmoi diff <target>           # inspect specific deltas
chezmoi re-add <target>         # update source state from current target
chezmoi add <unmanaged-path>    # promote an unmanaged file
git diff                        # review the source-state change before commit
```

Capture machine-local observations (redacted; not committed):

```sh
./scripts/macos/capture.sh
```

Rollback (default = desired-state rollback):

```sh
git checkout <prev-commit>
chezmoi apply
```

Risky helpers may expose their own focused undo path that consumes the per-helper preflight record they wrote. There is no centralized rollback CLI.

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
DOTFILES_ROOT="$repo" \
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
DOTFILES_ROOT="$repo" \
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

- native chezmoi: `chezmoi init`, `chezmoi apply`, `chezmoi status`, `chezmoi diff`, `chezmoi verify`, and `chezmoi apply --dry-run --verbose --exclude=scripts` against the temp home;
- rendered chezmoi script syntax: every `.chezmoiscripts/*.tmpl` and every per-app `modify_*.plist.tmpl` renders cleanly via `chezmoi execute-template --file` and parses as the language its shebang declares (`bash -n` for shell, `python -m py_compile` for Python);
- `~/.zshenv` starts with `ZDOTDIR` unset, sets `DOTFILES` to the repo under test, and sets `ZDOTDIR` to `$tmp_home/.config/zsh`;
- shell startup uses materialized `~/.config/zsh`;
- tests set `DOTFILES_SKIP_LAUNCHCTL_SYNC=1`, temp `HISTFILE`, temp zsh cache paths, and no-network/no-install guards;
- defaults/app tests use fixtures, not the real user domain;
- the **package renderer** (`scripts/packages/render-brewfile`, wrapping `home/.chezmoitemplates/brewfile.tmpl`) is covered by `tests/render-brewfile.zsh` for: profile selection (`core`/`full`), MAS opt-in (default off; `DOTFILES_INSTALL_MAS_APPS=true` and `--include-mas` opt-in), unknown-profile error, `--output` file mode, section ordering, single trailing newline, and keeping Xcode-required formulae out of the main Brewfile. `tests/brew-bundle-script.zsh` covers the rendered Brew Bundle script's `--jobs` and download-concurrency behavior. `tests/mise-install-script.zsh` covers the mise install ordering and the Ruby attestation setting used during fresh bootstrap. `tests/xcode-install-script.zsh` covers the full-profile Xcode setup order. CI parses each rendered Brewfile through `brew bundle list` and runs the core formulae through `brew bundle install`;
- the **macOS defaults applier** lives inline in `home/.chezmoiscripts/run_onchange_after_30-macos-defaults.sh.tmpl`; the rendered script syntax-check (`bash -n`) covers it. No separate dry-run / parsing test;
- the **sudo keepalive helper** is covered by `tests/sudo-keepalive.zsh`, which stubs `sudo` and proves one prompt can be shared without invalidating a preexisting sudo credential;
- the **capture script** (`scripts/macos/capture.sh` and similar) is covered by a redaction test that verifies sensitive keys (account state, license fields, tokens) are not written to the captured output;
- selected plist `modify_` tests prove owned keys are replaced while unrelated live plist keys are preserved;
- the shared plist merge engine (`tests/plist-merge-engine.zsh`) covers delete-directive parsing, byte-identity skip, and verbose-mode output independent of any single app; `tests/plist-templates-lint.zsh` renders every `.chezmoitemplates/*.plist.tmpl` and pipes it through `plutil -lint`; `tests/plist-hooks.zsh` covers the apply-time guard and post-apply hook scripts;
- leak checks verify the real `$HOME`, real chezmoi state, real `~/Library`, and launch services were untouched;
- fixtures cover spaces in paths, preexisting files, preexisting symlinks, permission-denied targets, hostile env vars, and rollback refusal on drift;
- conformance output has stable check IDs, clear skip/block semantics, pristine stdout/stderr, and CI-fatal classes.

If any existing test names a public CLI surface (`test-dotfiles-cli` style) it should be renamed or split so it tests the focused helper directly. The Makefile `test-*` targets are the repo-local validation facade; their implementation should call into focused helpers and chezmoi commands, not into a public dotfiles CLI.

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

The smoke lane boots a disposable Tahoe guest, runs the chezmoi one-liner with `DOTFILES_INSTALL_PROFILE=core` and other Option-C env overrides set, skips casks and Mac App Store entries, scans the captured install log, runs guest postflight checks, and deletes the VM unless debugging keeps it.

Use `make test-install-tart-dry-run` for Phase 0 bootstrap parsing and VM viability when changing chezmoi script ordering or the chezmoi-init template. Dry-run boots Tart and validates the chezmoi init/apply path, but it skips postflight tool and shell checks.

Use `make test-install-tart-full` before relying on full package, cask, Xcode, or app-install behavior. The full lane uses an Xcode-backed Tahoe image by default so validation does not spend the run downloading Xcode unless that path is under test. Full-profile package application runs `brew update` before `brew bundle` so prebuilt VM images do not use stale cask metadata. Mac App Store entries are omitted from generated Brewfiles unless `DOTFILES_INSTALL_MAS_APPS=true` is set on a signed-in machine.

Every Tart lane emits a plain-log timing summary before cleanup exits. Chezmoi package scripts also log `TIMING|...` records around expensive package/runtime/defaults steps. Use those timings first; enable Perfetto traces only when the plain log does not identify the slow phase.

Every Tart lane scans `$LOG_FILE` after install and before guest postflight:

```sh
./scripts/vm/check-install-log.sh "$LOG_FILE"
```

A missing log or known macOS failure signature is fatal. Current signatures include removed LaunchServices flags, sealed system writes, unsupported Spotlight defaults writes, missing clean-VM Dock database paths, mise Ruby attestation rate-limit failures, unfiltered `systemsetup` InternetServices noise, and unhandled optional defaults writes. Add new hidden install failure patterns to the scanner and cover them in `tests/vm-install-log-scan.zsh`.

Non-dry-run Tart lanes must run guest postflight checks:

- `scripts/vm/postflight-macos.sh`;
- `command -v brew mise uv llm`;
- `test -f "$HOME/.zshenv"` and `test -f "${ZDOTDIR:-$HOME/.config/zsh}/.zshrc"`;
- `scripts/audit/zsh-fresh-shells.zsh verify --dotfiles-root "$dotfiles_root"`.

Postflight output must keep stable `RESULT|...` and `SUMMARY|...` lines, with any failed check making the lane fail. Phase 3 app/default/license mutations need their own VM postflight checks before Tart can count as exit evidence for those scopes. Interactive permissions and sign-in remain current-Mac/manual audit gates.

## Phases

### Phase 0: Layout And Bootstrap

Land `.chezmoiroot = home`, `home/.chezmoi.toml.tmpl` (with `promptStringOnce`/`promptBoolOnce` for first-machine settings), the chezmoi one-liner as the bootstrap, the first chezmoi scripts, temp-home tests, and this plan.

Exit criteria:

- isolated tests do not read or write real chezmoi state;
- the chezmoi one-liner (`sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply prateek`) is the only public bootstrap; `install.sh` and `bootstrap.sh` are deleted;
- `home/.chezmoi.toml.tmpl` uses `promptStringOnce`/`promptBoolOnce` for first-machine settings with env-var override for non-interactive runs;
- `chezmoi apply` may run idempotent package/shell setup scripts and secret-backed private files when explicitly enabled. High-risk mutations (privileged defaults, license activation, permission/profile changes) live behind explicit data gates and focused helper scripts; rollback is desired-state rollback (`git checkout` + `chezmoi apply`) by default, with per-helper preflight captures for risky helpers;
- no committed doc presents live-link descriptors as the default migration strategy;
- changes to chezmoi script ordering or the bootstrap command pass `make test-install-tart-dry-run`;
- `make test-install-tart-smoke` is the canonical clean-machine proof; `scripts/vm/test-install-tart.sh` invokes the chezmoi one-liner with the appropriate env-var overrides.

### Phase 1: Managed Home Baseline

Bring up shell, agents, wrappers, GRM generation, zinit external acquisition, and declared Apple/global baseline settings. No Homebrew bundle, broad app declarations, licenses, or permissions.

Exit criteria:

- fresh shell works from the materialized temp home;
- zinit is managed by `.chezmoiexternal.toml.tmpl` with explicit refresh behavior, or startup degrades clearly;
- rendered agent/Codex/Claude targets materialize, and wrapper live links resolve;
- Phase 1 defaults are Apple/global key-path declarations with explicit value types;
- low-risk defaults apply as idempotent desired state through `home/.chezmoiscripts/run_onchange_after_30-macos-defaults.sh.tmpl`. Risky defaults are gated by an explicit data flag and may write a per-helper preflight capture before mutating state. Phase 1 does not require a generic transaction framework before applying ordinary defaults;
- `make test-install-tart-smoke` passes before Phase 1 is accepted. If defaults are declaration-only, split or gate the Tart macOS postflight so it does not require unapplied defaults.

### Phase 2: Packages And Stable Config

Install packages through chezmoi scripts and adopt stable file-backed developer/app config.

Includes Homebrew profiles, package/app inventory, usage reports, native XDG configs, VS Code settings, Ghostty config, selected app plist patches, and ordinary dotfiles.

Exit criteria:

- `run_onchange_after_10-brew-bundle.sh.tmpl` is idempotent, profile-aware, embeds dependency hashes for package data, and is covered by Tart smoke/full lanes as appropriate;
- inventory and usage captures are local, redacted, and gitignored;
- stable app config applies without copying caches, account state, licenses, or whole app databases. Window/layout data is allowed only when it is intentional app config, such as selected Moom layouts and hotkeys;
- `make test-install-tart-smoke` passes for core package/profile changes;
- `make test-install-tart-full` passes before relying on cask or app-install behavior. Mac App Store install behavior needs an explicit signed-in-machine validation because disposable Tart guests omit MAS entries by default;
- selected plist `modify_` targets use the shared engine in `home/.chezmoitemplates/` (per Plist Management). Once all 11 managed apps are migrated, the legacy `home/.chezmoiassets/Library/Preferences/*.json` layout for plists is removed and the engine's JSON-source compatibility branch is dropped.

### Phase 3: Advanced App And System Data

Handle remaining app-native sync folders, privileged assets, licenses, permissions, and PPPC/profile work. Selected app plists that can be represented as `modify_` targets are Phase 2 source state.

Exit criteria:

- broad plist dumps are gone or reference-only;
- risky imperative app/default/license helpers write a per-helper preflight or capture record before mutating live state, scoped to that helper. Recovery from desired-state changes is `git checkout` + `chezmoi apply`;
- License automation: Moom, BetterTouchTool, and Alfred have private chezmoi templates under their license target paths, fetching license content via `onepasswordRead` gated by `secrets_enabled`. Other apps stay manual;
- All macOS permissions remain manual. The README maintains an explicit checklist of permissions the user grants in System Settings (Accessibility, Input Monitoring, Screen Recording, Full Disk Access for the affected apps). PPPC `.mobileconfig` profile management is intentionally out of scope for personal dotfiles;
- Tart postflight covers the basics: `chezmoi status` returns empty after apply; the 6 baseline Apple-domain defaults (KeyRepeat, InitialKeyRepeat, AppleShowAllExtensions, finder show-files / show-pathbar, dock autohide) match expected values; one asserted key per managed plist app reads back correct via `defaults read`; the plist hook state file is cleaned up.

## Open Decisions

All resolved. Recorded here so they don't re-open:

- ~~Phase 1: exact Apple/global baseline key allowlist.~~ → The legacy `./macos` script's full ~150 keys, now invoked via `scripts/macos/defaults.sh` from the chezmoi run_onchange wrapper. Postflight asserts a representative subset (the 6 baseline Apple-domain keys + 14 per-app plist keys).
- ~~Phase 1: Codex config split between portable global settings and local project-trust state.~~ → Trust state lives in `~/.codex/internal_storage.json` (machine-local, not chezmoi-managed). Portable settings (model, reasoning_effort, agents.max_threads/max_depth) live in chezmoi-managed `home/dot_codex/config.toml`. Codex made this split unilaterally during normal use; we just committed the resulting config.
- ~~Phase 1: final `install.sh` flag surface for Tart and local reruns.~~ → `install.sh` is deleted; bootstrap is the chezmoi one-liner with env-var overrides for non-interactive runs.
- ~~Phase 3: app-by-app selection for native file, `.chezmoidata` declaration, app-native sync, or privileged asset.~~ → Native file for Ghostty/Hammerspoon/VS Code/Zed; plist `modify_` for the 11 apps in Plist Management; app-native sync for Alfred (excluded); privileged asset for Chrome (managed-policy plist via `scripts/macos/render-chrome-policy.py`).
- ~~Phase 3: which apps get license automation.~~ → Moom, BetterTouchTool, Alfred. Per-app private chezmoi templates fetching via `onepasswordRead` under `secrets_enabled`.
- ~~Phase 3: which permissions remain manual versus profile-managed.~~ → All manual. PPPC `.mobileconfig` is out of scope for personal dotfiles (signing requirements, fragile to app version bumps, enterprise-shaped tooling). README maintains an explicit checklist.
- ~~Phase 3: app-specific Tart postflight checks for defaults, app files, licenses, and privileged assets.~~ → Basics are: `chezmoi status` empty after apply; 6 baseline Apple defaults match expected; one asserted key per managed plist app; hook state file cleaned. Extend as new failure modes surface.

## Local validation cadence

Two lanes on `mini`:

- **Iteration:** keep one warm Tart VM (`make test-install-tart-warm`). Boots once, reused across runs, refresh weekly. Fast cycle for iterating on chezmoi script changes.
- **Checkpoint:** cold disposable VMs via `make test-install-tart-{smoke,full}`. Used for clean-machine proof before merging meaningful changes (bootstrap, package profile, defaults, plist refactor steps).

`test-install-tart-dry-run` stays for `install.sh`-shaped checks → after the bootstrap simplification it just confirms the chezmoi one-liner parses and the rendered chezmoi config is valid.

## References Used

- chezmoi setup guide (one-line install + init): `https://www.chezmoi.io/user-guide/setup/`
- chezmoi daily operations (single-command new-machine install): `https://www.chezmoi.io/user-guide/daily-operations/#install-chezmoi-and-your-dotfiles-on-a-new-machine-with-a-single-command`
- chezmoi prompts (`promptStringOnce`, `promptBoolOnce`) walkthrough: `https://blog.huyixi.com/posts/chezmoi/`
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
