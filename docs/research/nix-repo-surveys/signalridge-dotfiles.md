---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-04
updated: 2026-09-04
related:
  - ../nix-target-state-research.md
  - ../nix-migration-research.md
status_detail: "Agent survey of signalridge/dotfiles at 5ff71281c2cbfa71aee9746218a23b8e1907fd14, compared with the Nix target-state doc. Unreviewed."
---

# Repo Survey: signalridge/dotfiles

## Method

Surveyed on 2026-09-04 at commit
`5ff71281c2cbfa71aee9746218a23b8e1907fd14`. The snapshot was fetched as a
tarball through the GitHub API and read from disk with `cat`, `sed`, `grep`,
and `find`. Every permalink below points at a file range that was opened.
Repository metadata (stars, commit counts, contributor split, push time) comes
from the GitHub REST API at survey time and has no permalink.

Files opened in full or in part: `README.md`, `AGENTS.md`,
`.chezmoi.toml.tmpl`, `.chezmoiignore`, `.chezmoiexternal.toml.tmpl`,
`Justfile.tmpl`, all five `nix-config/` module sources, five of the 25
`.chezmoiscripts`, all five `modify_` scripts, both `symlink_` files,
`dot_claude/settings.json.tmpl`, `dot_claude/run_after_ensure-skill-dirs.sh`,
`dot_local/bin/executable_skill-activate`, `.chezmoidata/nix.yaml`,
`.chezmoidata/homebrew.yaml`, `.chezmoidata/versions.yaml`, `tests/run.sh`,
the aqua and mise config files, `treefmt.toml`, `.pre-commit-config.yaml`,
`.gitleaks.toml`, and the five `.github/workflows` files.

On our side: [nix-target-state-research.md](../nix-target-state-research.md)
in full, [nix-migration-research.md](../nix-migration-research.md) options and
sizing, [chezmoi-architecture.md](../../references/chezmoi-architecture.md),
[document-lifecycle.md](../../document-lifecycle.md), and the repo-root
`CLAUDE.md`.

## 1. What It Is

A personal cross-platform dotfiles repo by a single author. The flake
description is `"YixianLu's system flake"`
([flake.nix.tmpl#L2](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/nix-config/flake.nix.tmpl#L2)).

| Fact | Value |
| --- | --- |
| Platforms | macOS and Linux, both driven by the same chezmoi source |
| Nix bootstrap targets | `aarch64-darwin`, `aarch64-linux`, `x86_64-linux`; fresh `x86_64-darwin` is rejected |
| Host model | No host list. One hostname is prompted at init and becomes the flake attribute |
| Profiles | `work`, `private` (derived as `not work`), `headless`, `useEncryption`, `installMasApps` |
| Total files | 265, excluding `.git` |
| Nix sources | 5: one plain `.nix` and four `.nix.tmpl` |
| Chezmoi templates | 58 `.tmpl` files |
| Apply scripts | 25 under `.chezmoiscripts`, numbered 00 to 23 with two scripts numbered 19 |
| `modify_` scripts | 5 |
| `symlink_` files | 2 |
| `.chezmoidata` files | 9 YAML files |
| Externals | 42 archive entries in a 1223-line template; no `git-repo` entries |
| Tests | 24 test files plus a runner |

The arch support and profile semantics are stated in the README support table
([README.md#L45-L55](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/README.md#L45-L55)),
and the installer enforces the `x86_64-darwin` rejection
([00_install-nix#L56](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoiscripts/run_onchange_before_00_install-nix.sh.tmpl#L56)).

Activity: created 2025-01-18, last push 2026-09-04, about 1248 commits with 61
in the last 30 days, 42 stars, 5 forks. Contributions split 1216 human, 23
dependabot, 6 github-actions, 3 renovate. There is no `LICENSE` file, and the
README says so explicitly
([README.md#L591-L595](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/README.md#L591-L595)).
Treat the code as reference, not as something to copy verbatim.

Dependencies update on a schedule. A daily cron dispatches three maintenance
workflows
([scheduler.yml](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.github/workflows/scheduler.yml)),
which refresh the flake lock per platform, the pinned download versions and
checksums, and the aqua package set, each as a pull request. Dependabot covers
GitHub Actions only
([dependabot.yml](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.github/dependabot.yml)).

## 2. Division Of Labor, Precisely

Nix is underneath. Chezmoi is on top and stays in charge.

| Layer | Owns | Declared in |
| --- | --- | --- |
| chezmoi | All dotfiles, all app config, all agent CLI config, bootstrap order, merges into app-owned files, secrets, externals | `home`-equivalent source root at repo top level |
| Nix user profile | Cross-platform CLI packages through `flakey-profile`, not home-manager | `.chezmoidata/nix.yaml` plus `profile.nix.tmpl` |
| nix-darwin | macOS `system.defaults`, fonts, PAM, shells, timezone, sleep, two launchd daemons, and the Homebrew and MAS module | `system.nix.tmpl`, `apps.nix.tmpl`, `host-users.nix` |
| Homebrew | Taps, brews, casks, driven from YAML through the nix-darwin module | `.chezmoidata/homebrew.yaml` |
| Mac App Store | 11 private entries, gated on `installMasApps` | same YAML, rendered into `masApps` |
| aqua | 101 pinned CLI releases plus a local third-party registry | `private_dot_config/aquaproj-aqua/` |
| mise | Language runtimes and `pipx:`, `npm:`, `go:` backends, deliberately outside Nix | `private_dot_config/mise/config.toml.tmpl` |

There is no home-manager anywhere in the flake
([flake.nix.tmpl#L6-L33](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/nix-config/flake.nix.tmpl#L6-L33)).
The user package set is a bare `flakey-profile.lib.mkProfile` over a list of
`pkgs` attributes, with `work` and `private` branches rendered by chezmoi
before Nix ever sees the file
([profile.nix.tmpl#L1-L23](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/nix-config/modules/profile.nix.tmpl#L1-L23)).
`environment.systemPackages` is driven by `.chezmoidata/nix.yaml`, and that
list is currently empty
([apps.nix.tmpl#L17-L21](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/nix-config/modules/apps.nix.tmpl#L17-L21);
[nix.yaml#L2](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoidata/nix.yaml#L2)).

The boundary is enforced by templating, not by Nix. Chezmoi renders the Nix
modules from `.chezmoidata`, so profile conditionals are Go template `if`
blocks inside `.nix.tmpl` files rather than Nix module options. Homebrew lists
are unioned the same way, shared plus work plus private
([apps.nix.tmpl#L73-L121](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/nix-config/modules/apps.nix.tmpl#L73-L121)).
Ordering is enforced by numeric script prefixes: `00` installs Nix, `02`
switches nix-darwin, `03` switches the user profile, then everything else.

Profiles are resolved once, at chezmoi init, and persisted into `[data]`.
`work` must be explicit: chezmoi data, else a TTY prompt, else a hard `fail`
([.chezmoi.toml.tmpl#L9-L16](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoi.toml.tmpl#L9-L16)).
`private` is `not work`, and `headless` defaults to false
([.chezmoi.toml.tmpl#L17-L18](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoi.toml.tmpl#L17-L18)).
The resolved values land in one flat `[data]` block
([.chezmoi.toml.tmpl#L206-L223](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoi.toml.tmpl#L206-L223)).

Compared with our machine types, this is much flatter. We resolve a single
`machine_type` through a layered `machines*.toml` merge
(`defaults < os < type < composite < host < local`) in `features.tmpl`, and
every consumer reads the resolved JSON. They have five independent booleans,
no layering, no resolver, and no composite exceptions. Their `.chezmoiignore`
gating is about 45 lines total across four blocks
([.chezmoiignore#L45-L100](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoiignore#L45-L100)),
versus our 20 cask gates plus profile gates. They have no equivalent of our
package groups: the union happens inline in the Nix template.

`headless` is a config switch, not a package switch. On macOS the whole
nix-darwin and Homebrew module still renders under `headless`, which the
README states plainly
([README.md#L53](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/README.md#L53)).

## 3. How Nix Is Installed And Invoked From Chezmoi

Installation is a 413-line `run_onchange_before_00` script, the most careful
part of the repo. It pins the Determinate installer version and the Nix
version from `.chezmoidata/versions.yaml`
([00_install-nix#L13-L14](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoiscripts/run_onchange_before_00_install-nix.sh.tmpl#L13-L14);
[versions.yaml#L4-L10](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoidata/versions.yaml#L4-L10)).
It carries a per-arch sha256 for each supported installer asset
([00_install-nix#L62-L71](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoiscripts/run_onchange_before_00_install-nix.sh.tmpl#L62-L71)),
verifies the download, then runs `install --no-confirm` and a
`/nix/nix-installer self-test`
([00_install-nix#L406-L407](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoiscripts/run_onchange_before_00_install-nix.sh.tmpl#L406-L407)).

Upgrades take a different path. On macOS it downloads the Determinate signed
package, checks the signature against the literal Apple Developer team string
`Determinate Systems, Inc. (X3JQ4VPJZ6)` with `pkgutil --check-signature`, and
only then runs `sudo installer`
([00_install-nix#L203-L230](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoiscripts/run_onchange_before_00_install-nix.sh.tmpl#L203-L230)).
Elsewhere it falls back to `sudo determinate-nixd upgrade`
([00_install-nix#L315](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoiscripts/run_onchange_before_00_install-nix.sh.tmpl#L315)).

The nix-darwin switch is a nine-line chezmoi script. It hashes the rendered
source state of the flake and every module so that a config change and its
switch land in the same apply
([02_init#L6-L12](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoiscripts/run_onchange_after_02_init.sh.tmpl#L6-L12)),
then runs:

```bash
sudo nix run ~/nix-config#darwin-rebuild -- switch --flake ~/nix-config#{{ .hostname }}
```

on first install, or `sudo darwin-rebuild switch` afterwards
([02_init#L18-L24](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoiscripts/run_onchange_after_02_init.sh.tmpl#L18-L24)).
The `darwin-rebuild` package is re-exported from the locked flake input so the
bootstrap never executes a floating remote branch as root
([flake.nix.tmpl#L110-L117](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/nix-config/flake.nix.tmpl#L110-L117)).

sudo is used exactly twice in the Nix path: the installer and the
`darwin-rebuild switch`. The user-profile switch needs no root at all
([03_set_profiles#L13](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoiscripts/run_onchange_after_03_set_profiles.sh.tmpl#L13)).
On Linux, script `02` is excluded by target path in `.chezmoiignore`, so the
whole nix-darwin layer disappears and Linux gets only the flakey-profile
switch
([.chezmoiignore#L45-L57](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoiignore#L45-L57)).

nix-darwin manages a lot on macOS: `system.defaults` for the dock, finder,
trackpad, and about 20 `NSGlobalDomain` keys, plus a large
`CustomUserPreferences` block covering nine domains including
`com.apple.symbolichotkeys`
([system.nix.tmpl#L109](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/nix-config/modules/system.nix.tmpl#L109)).
It also sets Touch ID for sudo
([system.nix.tmpl#L196](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/nix-config/modules/system.nix.tmpl#L196)),
the timezone from a chezmoi-detected value
([system.nix.tmpl#L222](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/nix-config/modules/system.nix.tmpl#L222)),
and two weekly launchd daemons for garbage collection and store optimisation
([system.nix.tmpl#L270-L303](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/nix-config/modules/system.nix.tmpl#L270-L303)).

Two details are worth stealing outright.

First, `nix.enable = false`, with the comment that Determinate Nix is
installed and nix-darwin must not fight its daemon or config management
([system.nix.tmpl#L265](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/nix-config/modules/system.nix.tmpl#L265)).

Second, the Homebrew module runs with `onActivation.autoUpdate = false`
because auto-update resets brew bundle state and breaks mas detection on
Homebrew 5.1 and later, and with an explicit `extraEnv.XDG_CONFIG_HOME`
because nix-darwin activation runs under sudo and does not inherit the user's
`.zshenv`, so without it the Homebrew trust store would be written under
root's home
([apps.nix.tmpl#L28-L43](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/nix-config/modules/apps.nix.tmpl#L28-L43)).
Cleanup is set to `"zap"`, the most aggressive setting, so Homebrew is fully
declarative on every host
([apps.nix.tmpl#L43](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/nix-config/modules/apps.nix.tmpl#L43)).

The flake also pulls in `nix-homebrew` with `enableRosetta` on Apple silicon,
`mac-app-util`, and the three Homebrew taps as `flake = false` inputs
([flake.nix.tmpl#L86-L102](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/nix-config/flake.nix.tmpl#L86-L102)).

## 4. Per-App Config Mechanics, Especially Agent CLIs

There are exactly five `modify_` scripts, and Nix owns none of them.

| Target | Mechanism | What it preserves |
| --- | --- | --- |
| `~/.codex/config.toml` | Heredoc emits the full managed TOML, then awk re-appends preserved tables | `[hooks.state.*]` filtered to three events, and `[projects.*]` written when Codex trusts a directory |
| `~/.cursor/cli-config.json` | `jq -s '.[0] * .[1] * .[2]'` over fallback, existing, managed | `authInfo`, model selection, version, `privacyCache` |
| `~/.pi/agent/settings.json` | Template builds a managed dict, then `jq -s '.[0] * .[1] \| del(.subagents)'` | Everything Pi writes except a legacy key |
| `~/.kimi-code/config.toml` | awk prepends two scalars and strips prior copies | Providers, models, OAuth state, services |
| `~/.gemini/antigravity-cli/settings.json` | `jq -s '.[0] * .[1]'` with a validity guard | `trustedWorkspaces`, model, permissions |

The Codex merger is the largest at 323 lines, with two named awk helpers
([modify_config.toml.tmpl#L276-L318](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/dot_codex/modify_config.toml.tmpl#L276-L318)).
The Cursor script explicitly says it mirrors the Codex and pi pattern
([modify_cli-config.json#L4-L8](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/dot_cursor/modify_cli-config.json#L4-L8)),
and the Antigravity script says the same and reuses pi's empty-stdin guard
([modify_private_settings.json.tmpl#L15-L23](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/dot_gemini/antigravity-cli/modify_private_settings.json.tmpl#L15-L23)).
That guard matters: on a fresh machine the file does not exist, and a
half-written one must not take the managed keys down with it. Antigravity also
uses `private_` to keep the 0600 mode the CLI creates the file with
([modify_private_settings.json.tmpl#L1-L7](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/dot_gemini/antigravity-cli/modify_private_settings.json.tmpl#L1-L7)).

Claude Code is the interesting exception. `~/.claude/settings.json` is a
314-line whole-file template, not a merge
([settings.json.tmpl#L1-L30](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/dot_claude/settings.json.tmpl#L1-L30)).
It resolves a provider account from `.chezmoidata/claude.yaml` and emits
`apiKeyHelper`, `enabledPlugins`, `extraKnownMarketplaces`, and an `env`
block. Nothing Claude writes into that file survives an apply. They took the
opposite bet from us on the single app where our doc concluded a split is
possible.

Pi runtime state is handled by ignoring it rather than merging it.
`.chezmoiignore` excludes `auth.json`, `sessions/`, `trust.json`, `npm/`,
`git/`, `logs/`, and extension `node_modules`, while explicitly keeping
`keybindings.json` managed and noting that TUI edits will show up in
`chezmoi diff`
([.chezmoiignore#L102-L117](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoiignore#L102-L117)).

The shared skill library is projected in two stages, and neither involves Nix.

Stage one: 42 chezmoi `archive` externals download pinned skill tarballs into
`~/.harnesses/skills/<category>/<skill>`, keyed by a template dict that maps
each skill name to a function category
([.chezmoiexternal.toml.tmpl#L22-L37](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoiexternal.toml.tmpl#L22-L37)).
The revisions are pinned in `versions.yaml` and bumped by a scheduled
workflow. The one non-skill external, tmux TPM, has a comment explaining why
`archive` beats `git-repo`: cold start stays independent of git, SSH, and
`insteadOf` rewrites
([.chezmoiexternal.toml.tmpl#L9-L20](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoiexternal.toml.tmpl#L9-L20)).

Stage two: `skill-activate`, a 356-line fzf panel, writes flat per-project
symlinks from that library into `./.claude/skills`, `./.codex/skills`,
`./.pi/skills`, `./.cursor/skills`, and `./.kimi-code/skills`
([skill-activate#L15-L28](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/dot_local/bin/executable_skill-activate#L15-L28)).
Skills are not activated globally. A small `run_after` script keeps the five
user-level skill directories as real directories rather than leftover
whole-directory symlinks
([ensure-skill-dirs#L13-L16](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/dot_claude/run_after_ensure-skill-dirs.sh#L13-L16)).
Two `symlink_` files share one commit prompt across Claude and Codex
([symlink_core.tmpl](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/dot_claude/commands/symlink_core.tmpl),
[symlink_core-commit.md.tmpl](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/dot_codex/prompts/symlink_core-commit.md.tmpl)).

Secrets never touch Nix. chezmoi uses the `age` backend through a wrapper
script with `~/.ssh/main` as the identity
([.chezmoi.toml.tmpl#L1](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoi.toml.tmpl#L1),
[#L239](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoi.toml.tmpl#L239)).
gopass holds runtime secrets and is read at call time, not render time.
`keys-manage` handles key backups with AES-256-CBC and PBKDF2, and refuses a
`--password` flag so secrets never land in process arguments
([README.md#L521-L540](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/README.md#L521-L540)).
Encryption is itself a profile: when `useEncryption` is false, two scripts,
the gopass config, and all of `.ssh/*` are ignored
([.chezmoiignore#L93-L100](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoiignore#L93-L100)).

Root per apply: only the nix-darwin switch, and only on macOS. Everything
else, including the user package switch, runs unprivileged.

## 5. Testing And CI

`tests/` is 24 shell and Python files plus a serial runner. The runner unsets
`XDG_CONFIG_HOME` first, because the tests rewrite `HOME` to isolated temp
dirs and chezmoi must follow the per-test config
([run.sh#L1-L37](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/tests/run.sh#L1-L37)).
The suite targets bootstrap behavior: template suffix hygiene, harness config
alignment, encryption setup, init arguments, GitHub URL normalization,
installer architecture selection, pinned download checksums, the version
updater, Herdr plugins and integrations, pi extension updates, mise updates,
key management, `skill-activate`, and several CLI helpers.

There are no Nix module tests, no golden-output tests, and no chezmoi apply
dry-run test. `tools/` contains one thing, a Swift source file for a WezTerm
icon.

CI has five workflows. The `lint` job installs 12 tools from a sha-pinned
nixpkgs revision read out of `versions.yaml` and asserted to be 40 hex
characters, writes a synthetic chezmoi config, and runs pre-commit
([ci.yml#L20-L49](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.github/workflows/ci.yml#L20-L49)).

The `nix` job is the one to copy. It runs a macOS and Linux matrix, renders
the `.nix.tmpl` files with `chezmoi execute-template` into a temp directory to
avoid flake git-tracking problems, copies the platform-specific lock, and runs
`nix flake check --no-build`
([ci.yml#L51-L103](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.github/workflows/ci.yml#L51-L103)).
That is evaluation coverage for a templated flake without committing the
rendered output.

Formatting is treefmt with nixfmt, shfmt, stylua, and prettier. `*.tmpl` is
excluded wholesale, and prettier additionally excludes `modify_*` because
those files are bash even when the target is JSON
([treefmt.toml](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/treefmt.toml)).
Pre-commit adds shellcheck at warning severity, selene, `statix check
nix-config/`, typos, and a staged gitleaks scan
([.pre-commit-config.yaml](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.pre-commit-config.yaml)).

Security scanning is a separate workflow with three jobs: zizmor at high
severity, a Trivy filesystem scan uploading SARIF, and a sha-verified gitleaks
8.30.1 run over full history
([security.yml](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.github/workflows/security.yml)).
`.gitleaks.toml` keeps the default rules and adds two narrow allowlists
([.gitleaks.toml](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.gitleaks.toml)).

## 6. Compare And Contrast With Our Doc And Repo

### It is option 2 plus nix-darwin, not option 3

Our migration doc's option 2 is a flake-backed CLI closure installed with
`nix profile`, described as "no home-manager, no sudo". Option 3 is standalone
home-manager for `home.packages` only. Option 4 is nix-darwin after the
work-Mac check passes.

This repo is option 2 executed with `flakey-profile` instead of a bare
`nix profile add`, plus option 4 for macOS system state, and it skipped option
3 entirely. The `flakey-profile` choice is deliberate and documented in an
unusual place: a comment on the `age` entry in `nix.yaml` warns that
flakey-profile installs in a representation `nix profile` does not track, so a
bare `nix profile add` would drop every flakey-installed package.

What it gained: package pinning and rollback with no home-manager module
system to learn, no per-file store symlinks, no `home.file` ownership
conflicts, and no clobber errors on pre-existing files. Our concept-map row 40
never comes up because Nix never manages a dotfile here.

What it lost: nothing in the Nix layer knows about any dotfile. There is no
generation-level view of config, no `onChange`, no DAG ordering. All of that
stayed in chezmoi's numbered scripts. Row 21 in our concept map is answered by
not needing an answer.

### Problem A, files the app also writes

They hit it and solved it the way we did, at one quarter the scale.

| | Our repo | signalridge |
| --- | --- | --- |
| Total `modify_` mergers | 22 | 5 |
| Plist mergers | 12, via a shared Python engine | 0 |
| Structured config mergers | 9 JSON/TOML plus 1 line-based | 5 JSON/TOML |
| Shared merge engine | Yes, `plist-merge` prelude and postlude | No, each script is standalone jq or awk |
| Nix involvement | Proposed, per-app table | None |

The plist difference is the whole gap. They have zero plist mergers because
nix-darwin `system.defaults` and `CustomUserPreferences` cover their macOS
preferences directly
([system.nix.tmpl#L36-L175](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/nix-config/modules/system.nix.tmpl#L36-L175)).
Our doc's row 23 says exactly this is possible, and rates it partial because
`defaults` cannot delete keys and there is no quit guard. This repo simply
accepts both limitations. It has no quit or relaunch guard anywhere, and no
`chezmoi-delete` sentinel.

On the per-app table, they are direct evidence for four rows:

| Our per-app row | Our native decision | What they do | Verdict |
| --- | --- | --- | --- |
| Claude Code | Split by setting class; managed drop-in for hooks and permissions, user file for `enabledPlugins` | Whole-file template, no merge, no managed drop-in | Alternative, and a riskier one |
| Codex | Merger disappears via `/etc/codex/config.toml` | Merger stays, 323 lines, preserving `[hooks.state.*]` and `[projects.*]` | Contradicts the "disappears" call in practice |
| pi | Merger stays | Merger stays, jq deep merge | Supports |
| Cursor CLI | Merger stays, no managed layer | Merger stays, three-way jq merge preserving `authInfo` | Supports, and answers open question 13 |

Codex is the interesting one. Our doc concluded the Codex merger disappears
because `/etc/codex/config.toml` is a system layer. They did not use it. That
is not proof the layer does not work, but it is one more maintained repo that
chose a user-file merger anyway, and their merger has to preserve two distinct
app-written table families. Treat our "disappears" verdict as untested rather
than settled.

### Problem B, the managed machine

No help. Their `work` profile is a package and application switch, not a
privilege story
([README.md#L51](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/README.md#L51)).
There is no MDM handling, no Jamf equivalent, no temp-admin flow, and no
non-admin path anywhere in the repo. Their `sudo darwin-rebuild switch`
assumes the user can sudo, and `security.pam.services.sudo_local.touchIdAuth`
assumes a Touch ID Mac they control. Our Problem B remains open and untested
by this survey.

One partial contribution: they show that the sudo surface can be kept to
exactly one command per apply, and that everything else, including the user
package set, works unprivileged. If our work Mac ends up with a Jamf-gated
switch, this is the shape that minimizes how often that gate is hit.

### Problem C, secrets without store leakage

They sidestep it rather than solving it. No secret is ever a Nix evaluation
input, because Nix does not manage any file that contains a secret. age
handles encrypted source state, gopass handles runtime lookups, and
`keys-manage` handles backups. Nothing needs opnix, sops-nix, or agenix.

That is a real answer to our Problem C, and it happens to be the answer our
migration doc's N5 review verdict already reached: "or leave the 3 files in
chezmoi". This repo is a working existence proof of that option at a much
larger secret surface than three files.

### The "what disappears" table, checked against a real hybrid

Our table assumes a full Nix-native target. Under a chezmoi-on-top hybrid,
most rows do not disappear at all.

| Our "disappears" row | Still present here? | Evidence |
| --- | --- | --- |
| `features.tmpl` resolver and layered `machines*.toml` | Simplified, not gone. Five flat booleans in `[data]` | [.chezmoi.toml.tmpl#L206-L223](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoi.toml.tmpl#L206-L223) |
| `.chezmoiignore` config gates | Present, about 45 lines across four blocks | [.chezmoiignore#L45-L100](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoiignore#L45-L100) |
| Group union and dedupe | Present, done inline in the Nix template | [apps.nix.tmpl#L73-L121](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/nix-config/modules/apps.nix.tmpl#L73-L121) |
| `run_onchange_` hash lines | Present, and pointed at rendered source state | [02_init#L6-L12](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoiscripts/run_onchange_after_02_init.sh.tmpl#L6-L12) |
| Brewfile renderer | Gone. The nix-darwin module generates it | [apps.nix.tmpl#L28-L121](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/nix-config/modules/apps.nix.tmpl#L28-L121) |
| Retired-package ledger | Gone, replaced by `cleanup = "zap"` | [apps.nix.tmpl#L43](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/nix-config/modules/apps.nix.tmpl#L43) |
| Plist modify stubs | Gone, replaced by `system.defaults` | [system.nix.tmpl#L36-L175](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/nix-config/modules/system.nix.tmpl#L36-L175) |
| Plist quit guard | Gone, and not replaced by anything | no guard found in the repo |
| First-run prompts | Present and expanded, with explicit non-TTY failure | [.chezmoi.toml.tmpl#L9-L16](https://github.com/signalridge/dotfiles/blob/5ff71281c2cbfa71aee9746218a23b8e1907fd14/.chezmoi.toml.tmpl#L9-L16) |
| Drift banner | Absent, and no substitute | `chezmoi diff` only |

The honest reading: adopting Nix underneath chezmoi buys the Brewfile
renderer, the retired-package ledger, and the plist stubs. It buys nothing
against the resolver, the ignore gates, the hash lines, or the prompts,
because those are chezmoi mechanics and chezmoi stays.

### The test surface

Our doc's test-surface section expects most tests to survive a Nix cutover
because their assertions target behavior. This repo supports that. Its 24
tests are all behavior tests against scripts and rendered output, and none of
them is about Nix. Adding a Nix layer did not add tests; it added one CI job.

The `nix flake check --no-build` over `chezmoi execute-template` output is the
concrete technique our doc's row 42 is missing. Our row 42 says
`nix build .#darwinConfigurations.<host>.system` per host on a macOS runner.
Their approach is cheaper, catches evaluation errors on both platforms, and
works for templated Nix sources, which is the shape we would have if we kept
`.chezmoidata` as the data model.

### Open questions this touches

| Our question | Effect |
| --- | --- |
| 2, does a running app overwrite a `defaults` write | Not answered, but they run this configuration daily with no quit guard, which is weak evidence the failure mode is tolerable for the domains they set |
| 3, Jamf and `/nix` | Not answered. No managed machine here |
| 5, 1Password service accounts | Reframed. Their answer is to keep secrets entirely out of Nix, which makes the question moot rather than answered |
| 7, is Homebrew fully declarative per host | Answered by example. They run `cleanup = "zap"` on every host and accept it |
| 9, which Claude keys belong in a managed drop-in | Not answered. They use no managed drop-in and template the whole user file |
| 10, Codex `/etc/codex` versus `managed_config.toml` | Reframed. They use neither and keep a user-file merger |
| 12, defaults expressiveness | Partially answered. Nine domains including `com.apple.symbolichotkeys` fit inside `CustomUserPreferences` |
| 13, does Cursor expose a managed layer | Effectively answered no. A second maintainer independently concluded a client-side merge is the only option |
| 16, work-Mac writability of managed paths | Not answered |

## 7. What We Should Take, What We Should Avoid

Take:

1. `nix.enable = false` when Determinate Nix is the installer. This is a
   concrete conflict we would otherwise hit on the first switch.
2. The templated-flake CI job. Render `.nix.tmpl` with
   `chezmoi execute-template` into a temp directory, copy a per-platform lock,
   run `nix flake check --no-build` on a macOS and Linux matrix. This is the
   cheapest possible Nix regression gate and it fits our existing data model.
3. Per-platform lock files selected by a three-line template
   (`flake.lock.tmpl` includes `.flake-darwin.lock` or `.flake-linux.lock`).
   We would need exactly this for a `work x linux` DevPod plus macOS.
4. Hashing rendered source state, not target files, in `run_onchange_` triggers
   so a config change and its switch converge in the same apply. We do this
   in places; their comment states the reason well and it is worth making
   universal.
5. The `homebrew.extraEnv.XDG_CONFIG_HOME` fix. Under nix-darwin the switch is
   root and does not inherit the user's `.zshenv`, so Homebrew writes its trust
   store into root's home unless told otherwise. That is a bug we would hit and
   not immediately understand.
6. The installer hardening pattern: pinned version, per-arch sha256, ELF and
   Mach-O magic check, Apple Developer team verification on the signed package,
   and a post-install self-test.

Avoid:

1. Templating Nix with Go templates. It works, but it means the Nix module
   system never sees the conditionals, `nix flake check` only validates one
   rendered variant at a time, and profile logic lives in two languages. Our
   `features.tmpl` resolver is more expressive than what this buys.
2. `cleanup = "zap"` on a machine you do not fully control. Their model works
   because every host is theirs.
3. Whole-file templating of `~/.claude/settings.json`. Our ADR 0007 depends on
   per-project overrides and on the CLI's own writes to that file surviving.
4. Skipping the plist quit guard. They have none. We added ours for a reason.
5. Two scripts numbered 19, one macOS and one Linux, distinguished only by
   `.chezmoiignore`. The README itself has to warn about it.
6. Copying any of it verbatim. There is no license file.

### Relevance

Score: 4 of 5.

This is the closest public analogue to our situation that a survey is likely
to find. It is chezmoi-first, macOS-plus-Linux, agent-CLI-heavy, uses `modify_`
scripts to merge into app-owned files, pins external skill libraries, and it
added Nix underneath rather than migrating to it. That is precisely the option
our migration doc ranks as the pragmatic path, running in production for
roughly eight months of daily commits.

It loses a point on two axes. There is no managed or MDM machine anywhere, so
Problem B, the single hardest blocker in our doc, gets no evidence. And the
repo is smaller than ours in the places that matter for cost: 5 mergers versus
22, no plist merge engine, no package group model, no retired-package handling,
no Tart-style end-to-end lane. The techniques transfer; the sizing does not.

## 8. Scorecard

Concept-map rows from
[Appendix A of the target-state doc](../nix-target-state-research.md), with
what this repo is evidence for.

| Row | Verdict | Note |
| ---: | --- | --- |
| 2 `private_` modes | Alternative | Keeps chezmoi, avoids store entirely |
| 4 `symlink_` live links | Alternative | Chezmoi symlinks, not mkOutOfStoreSymlink |
| 5 `.tmpl` templates | Contradicts | Templates Nix itself, keeps Go |
| 6 first-run prompts | Contradicts | Prompts expanded, not eliminated |
| 7 host-local override | Alternative | Persisted chezmoi data, no layering |
| 8 machines layer merge | Contradicts | Five flat booleans, no resolver |
| 9 Brewfile renderer | Supports | Module output replaced the renderer |
| 11 retired packages | Supports | `cleanup = "zap"` on every host |
| 13 Homebrew install | Supports | nix-homebrew with Rosetta enabled |
| 14 private overlay external | Alternative | Archive externals, no SSH input |
| 15 zinit external | Alternative | Sheldon plus pinned archives instead |
| 16 `.chezmoiignore` gates | Contradicts | Gates stayed, roughly 45 lines |
| 19 `run_onchange_` hashes | Contradicts | Hashes stayed, aimed at source |
| 21 script ordering | Contradicts | Numeric prefixes, no DAG |
| 23 plist modify stubs | Supports | Zero stubs, `system.defaults` instead |
| 24 structured config stubs | Supports | Five mergers survive Nix adoption |
| 25 plist quit guard | Contradicts | No guard exists at all |
| 26 macos-defaults script | Supports | Typed defaults plus CustomUserPreferences |
| 27 sudo keepalive and Jamf | Alternative | One sudo call, no MDM story |
| 28 LaunchAgents | Supports | launchd daemons declared in nix-darwin |
| 29 agent plugin marketplace | Alternative | Chezmoi scripts, no derivation |
| 34 mise runtimes | Supports | Mise kept deliberately outside Nix |
| 37 secrets at render time | Alternative | age and gopass, never a Nix input |
| 38 status, diff, verify | Contradicts | `chezmoi diff` retained, no closure diff |
| 41 work x linux headless | Alternative | Headless is config-only, not privileges |
| 42 Tart lanes and CI | Supports | Flake check over rendered templates |
