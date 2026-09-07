---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-04
updated: 2026-09-04
related:
  - ../nix-target-state-research.md
  - ../nix-migration-research.md
status_detail: "Agent survey of dustinlyons/nixos-config at bc6a1e36ecc99ac265cce8c06d169b5fb96008d1, compared with the Nix target-state doc. Unreviewed."
---

# Survey: dustinlyons/nixos-config

## Method

Read on 2026-09-04. The repo was pulled as a pinned tarball with
`gh api repos/dustinlyons/nixos-config/tarball/<sha>` at commit
`bc6a1e36ecc99ac265cce8c06d169b5fb96008d1` (the `main` head that day). All
permalinks below resolve at that sha.

Files read in full: `flake.nix`, `flake.lock`, `README.md`, `CLAUDE.md`,
`hosts/darwin/default.nix`, `modules/darwin/{home-manager,casks,secrets,files,packages}.nix`,
`modules/darwin/dock/default.nix`, `modules/shared/{default,files}.nix`,
`modules/nixos/{home-manager,packages}.nix` (outline plus the composition
lines), the four workflow files under `.github/`, `.github/dependabot.yml`,
all eight `apps/aarch64-darwin/*` scripts, and
`tests/garage-analyzer/run-tests.sh`. Files read in part:
`modules/shared/home-manager.nix`, `modules/nixos/kde-config.nix`,
`modules/nixos/backups.nix`, `hosts/nixos/default.nix`,
`hosts/nixos/garfield/default.nix`. The `templates/` trees were listed and
diffed against the live modules but not read line by line.

Repository metadata, commit history, pull requests, and workflow run outcomes
came from the GitHub REST API on 2026-09-04.

Compared against [nix-target-state-research.md](../nix-target-state-research.md),
[nix-migration-research.md](../nix-migration-research.md) sections "Options"
and "Sizing", and [chezmoi-architecture.md](../../references/chezmoi-architecture.md).

## 1. What It Is

Dustin Lyons' personal configuration, published as a general-purpose starter.
Created 2021-10-22, BSD-3-Clause, 3,613 stars and 202 forks, last pushed
2026-08-31. Effectively single-author: 1,959 commits by `dustinlyons`, the
next four contributors have three or fewer each. 117 commits in the twelve
months to 2026-09-04.

It is both a starter and a daily driver, and the two roles are physically
separated. The root tree is the author's real config. `templates/starter` and
`templates/starter-with-secrets` are trimmed copies exposed as flake templates
([flake.nix#L102-L111](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/flake.nix#L102-L111)).
Of 80 `.nix` files, 36 live under `templates/`; the live configuration is 44
files and 4,895 lines. The README says the author runs it daily on a MacBook
Pro and an x86 PC
([README.md#L12](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/README.md#L12)),
and recent commits are homelab operations, not starter maintenance: Jenkins
behind a LAN-only vhost, a deploy-only GitHub runner, nightly off-box backups.

Platforms: macOS through nix-darwin (`aarch64-darwin` and `x86_64-darwin`) and
NixOS (`x86_64-linux` and `aarch64-linux`)
([flake.nix#L59-L60](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/flake.nix#L59-L60)).

Host count is three real machines behind four attribute paths: one Mac
(reached through the per-architecture darwin attribute), `felix`
(`hosts/nixos/default.nix`, hostname set at
[#L104](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/hosts/nixos/default.nix#L104)),
and `garfield`
([#L58](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/hosts/nixos/garfield/default.nix#L58)).

Lock cadence is the most interesting finding here. The README advertises
"Flake auto updates weekly if changes don't break starter build"
([README.md#L82](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/README.md#L82)).
The workflow exists and is scheduled Sundays at 23:00
([update-flake-lock.yml#L4-L13](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/.github/workflows/update-flake-lock.yml#L4-L13)).
The API says all 59 recorded runs, from 2025-07-20 through 2026-08-31,
concluded `failure`. No pull request titled "Update flake.lock" has ever been
opened. The lock is bumped by hand: commits literally named "Update flake",
most recently 2026-07-10. Root inputs in `flake.lock` are locked to
2026-07-05 through 2026-07-09, except `agenix` at 2026-02-04,
`claude-desktop` at 2025-11-25, `homebrew-bundle` at 2025-04-22, and
`flake-utils` at 2024-11-13. The advertised automation is aspirational.

## 2. Composition

There are no roles, profiles, mixins, features, or suites. The vocabulary does
not appear anywhere in the tree.

**Machine identity is the system architecture, not the hostname.** Both
`darwinConfigurations` and the platform-based `nixosConfigurations` are built
with `genAttrs` over the system list
([flake.nix#L114](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/flake.nix#L114),
[#L138-L140](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/flake.nix#L138-L140)),
so the switch target is `.#aarch64-darwin`
([build-switch#L8-L18](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/apps/aarch64-darwin/build-switch#L8-L18)).
Only `garfield` is keyed by name
([flake.nix#L164](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/flake.nix#L164)).
The scheme has already drifted: `rollback` still switches
`.#Dustins-MBP`
([rollback#L8](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/apps/aarch64-darwin/rollback#L8),
[#L22](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/apps/aarch64-darwin/rollback#L22)),
an attribute the flake no longer produces.

The user is a hard-coded string, repeated. `flake.nix` binds `user = "dustin"`
([#L58](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/flake.nix#L58))
and threads it through `specialArgs`, but
`hosts/darwin/default.nix`
([#L3](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/hosts/darwin/default.nix#L3)),
`modules/darwin/home-manager.nix`
([#L4](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/darwin/home-manager.nix#L4)),
`modules/darwin/secrets.nix`
([#L3](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/darwin/secrets.nix#L3)),
and `modules/nixos/home-manager.nix`
([#L4](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/nixos/home-manager.nix#L4))
each re-declare it locally.

**Composition is attribute-set merging, not the module system.** On the NixOS
side the home-manager config is built from plain `import` results glued with
`//` and `lib.recursiveUpdate`: `programs = shared-programs // { ... }`
([#L34](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/nixos/home-manager.nix#L34)),
`file = shared-files // import ./files.nix { ... }`
([#L23](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/nixos/home-manager.nix#L23)),
`plasma = lib.recursiveUpdate kde-config.programs.plasma { ... }`
([#L223](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/nixos/home-manager.nix#L223)).
`//` is a shallow override, so a platform module that wants to add one key to
`programs.git` must restate the whole attribute. Outside `templates/` the repo
declares typed options in exactly two files: `local.dock`
([dock/default.nix#L10-L41](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/darwin/dock/default.nix#L10-L41))
and the GitHub runner module
([github-runner.nix#L143-L165](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/nixos/github-runner.nix#L143-L165)).

**The one place that does look like our target is `garfield`.** Its `imports`
list is per-capability service modules chosen by host: github-runner,
home-assistant, n8n, jenkins, hooks-proxy, appimage-host, backups, and a
host-specific agenix module, with a comment noting that `systemd.nix` is
deliberately excluded for this host
([garfield/default.nix#L8-L51](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/hosts/nixos/garfield/default.nix#L8-L51)).
The Darwin side has no equivalent: one host file, one home-manager module, one
flat cask list.

Per-host variation is expressed twice, both times by string comparison on the
hostname rather than by module selection. `modules/shared/default.nix` filters
the auto-loaded overlay directory with an `excludeForHost` attrset keyed by
`config.networking.hostName`
([#L26-L44](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/shared/default.nix#L26-L44)).
`modules/nixos/packages.nix` computes the same hostname at
[#L5](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/nixos/packages.nix#L5)
and never uses it.

There is no work-versus-personal axis, no laptop-versus-server axis, and no
MDM. Linux is a first-class platform but only as full desktop or homelab
server. Searching the tree for "WSL" or "headless" returns nothing.

Personalization for forkers is done outside Nix. `nix run .#apply` prompts for
username, email, name, GitHub user, and secrets repo, then `sed`-substitutes
`%USER%`, `%EMAIL%`, `%NAME%`, `%INTERFACE%`, `%DISK%`, `%HOST%`,
`%GITHUB_USER%`, and `%GITHUB_SECRETS_REPO%` across every file in the tree
([apply#L204-L234](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/apps/aarch64-darwin/apply#L204-L234)).
It also rewrites `flake.nix` itself with `awk` to add the secrets input and
thread it into the outputs argument list
([#L35-L96](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/apps/aarch64-darwin/apply#L35-L96)).

## 3. Per-App Config Mechanics

| Mechanism | Used | Where |
| --- | --- | --- |
| `programs.*` typed HM modules | Yes | direnv, zsh, git, vim, alacritty, ssh, tmux in [shared/home-manager.nix](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/shared/home-manager.nix#L8-L14); rofi, gpg, plasma on NixOS |
| `home.file` | Yes, 6 entries | [shared/files.nix#L50-L71](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/shared/files.nix#L50-L71), [darwin/files.nix#L7-L53](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/darwin/files.nix#L7-L53) |
| `xdg.configFile` / `xdg.dataFile` | No | XDG paths are hand-built strings, `xdg_configHome = "${config.users.users.${user}.home}/.config"` ([darwin/files.nix#L4-L6](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/darwin/files.nix#L4-L6)) |
| `mkOutOfStoreSymlink` | No | not present |
| System activation scripts | One | the Dock reconciler ([dock/default.nix#L64-L77](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/darwin/dock/default.nix#L64-L77)) |
| `home.activation` | No | not present |
| `onChange` | No | not present |

`home.file` is assembled by importing plain functions that return attrsets and
merging them, `lib.mkMerge [ sharedFiles additionalFiles { ... } ]`
([darwin/home-manager.nix#L50-L54](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/darwin/home-manager.nix#L50-L54)).
Files are `.text` strings, not repo paths, so there is no verbatim home tree.
`executable = true` is used once
([darwin/files.nix#L11](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/darwin/files.nix#L11)).

**Files the app also writes are not managed.** This is the headline. No
merger, no key-level write, no reconcile step for any user-writable JSON, TOML,
or plist. The three cases the repo does touch each dodge the problem a
different way.

- The Dock. `com.apple.dock` is owned by the Dock, so the module does not write
  the plist. It diffs the live `dockutil --list` output against the desired URI
  list and, only if they differ, removes everything and re-adds the desired
  entries, then `killall Dock`
  ([dock/default.nix#L64-L77](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/darwin/dock/default.nix#L64-L77)).
  It is whole-list ownership with a change guard, not a merge. Anything the
  user added by hand is destroyed on the next differing switch.
- KDE Plasma. Delegated wholesale to the upstream `plasma-manager` module
  ([flake.nix#L19-L22](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/flake.nix#L19-L22),
  [#L149](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/flake.nix#L149),
  [kde-config.nix#L1-L3](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/nixos/kde-config.nix#L1-L3)).
  The app-writes-it-too problem is somebody else's module to solve.
- Service state that Nix cannot recreate. n8n workflows and databases and Home
  Assistant `.storage` are not declared at all. They are tarred, age-encrypted
  to three recipients, and pushed off-box nightly by a systemd timer
  ([backups.nix#L1-L30](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/nixos/backups.nix#L1-L30),
  [garfield/default.nix#L39-L41](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/hosts/nixos/garfield/default.nix#L39-L41)).
  The module comment names the category exactly: "state nixos-rebuild cannot
  recreate".

Agent CLI configuration is absent. `claude-code` is a flake input whose overlay
supplies the binary
([flake.nix#L15-L18](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/flake.nix#L15-L18),
[shared/default.nix#L50](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/shared/default.nix#L50),
[shared/packages.nix#L39](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/shared/packages.nix#L39)),
and `.claude` is in `.gitignore`
([#L5](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/.gitignore#L5)).
The CLI is installed; its settings are left alone.

**macOS defaults** are set only through nix-darwin's typed
`system.defaults`: roughly twenty keys across `LaunchServices`,
`NSGlobalDomain`, `dock`, `finder`, and `trackpad`, plus `system.keyboard`
([hosts/darwin/default.nix#L49-L91](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/hosts/darwin/default.nix#L49-L91)).
`CustomUserPreferences`, `CustomSystemPreferences`, `defaults write`,
PlistBuddy, and `plutil` appear nowhere in the repo. `system.primaryUser` is
set
([#L52](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/hosts/darwin/default.nix#L52)).
`system.checks.verifyNixPath` is disabled
([#L51](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/hosts/darwin/default.nix#L51)),
and `nix.enable = false`
([#L14-L15](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/hosts/darwin/default.nix#L14-L15))
sits directly above a populated `nix.settings` block whose effect under
`enable = false` is unverified here.

**Homebrew.** nix-homebrew installs and owns Homebrew, with the three core
taps pinned as flake inputs, `mutableTaps = false`, and `autoMigrate = true`
([flake.nix#L120-L134](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/flake.nix#L120-L134)).
The nix-darwin `homebrew` module carries 19 casks from a flat list
([darwin/home-manager.nix#L24-L41](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/darwin/home-manager.nix#L24-L41),
[casks.nix#L3-L34](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/darwin/casks.nix#L3-L34)).
No `brews`. `masApps` is commented out
([#L37-L40](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/darwin/home-manager.nix#L37-L40))
even though the README lists App Store apps as a feature
([README.md#L70](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/README.md#L70)).
`homebrew.onActivation.cleanup` is never set in the live config; it appears
only as a commented line in both templates
([starter#L29](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/templates/starter/modules/darwin/home-manager.nix#L29)).
Homebrew is therefore additive here: nothing is ever uninstalled by a switch.

**launchd.** The only `launchd.user.agents` block on the Mac is commented out
([hosts/darwin/default.nix#L33-L47](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/hosts/darwin/default.nix#L33-L47)).
The scheduling and service work all lives on NixOS as `systemd.services`,
`systemd.timers`, and `systemd.user.services`.

**Secrets.** agenix, with the ciphertext held in a separate private repo
consumed as a non-flake input,
`git+ssh://git@github.com/dustinlyons/nix-secrets.git`
([flake.nix#L47-L50](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/flake.nix#L47-L50)).
The Darwin module declares four secrets with explicit `path`, `mode`, `owner`,
`group`, and per-secret `symlink`, decrypted with the user's
`~/.ssh/id_ed25519`
([darwin/secrets.nix#L5-L46](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/darwin/secrets.nix#L5-L46)).
Key material is provisioned by three imperative scripts outside Nix:
`create-keys` generates `id_ed25519` and `id_ed25519_agenix`
([#L34-L43](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/apps/aarch64-darwin/create-keys#L34-L43)),
`copy-keys` pulls them off a mounted USB drive
([#L32-L52](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/apps/aarch64-darwin/copy-keys#L32-L52)),
`check-keys` asserts all four files exist
([#L11-L31](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/apps/aarch64-darwin/check-keys#L11-L31)).
No 1Password, no service accounts, no evaluation-time secret read.

**Root per switch.** Every macOS switch is
`sudo ./result/sw/bin/darwin-rebuild switch`, with a comment pointing at
nix-darwin issue 1457 as the reason
([build-switch#L16-L18](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/apps/aarch64-darwin/build-switch#L16-L18)),
which is exactly the citation our doc already carries. `clean` runs
`sudo nix-collect-garbage`
([#L11](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/apps/aarch64-darwin/clean#L11)).
There is no managed-Mac story of any kind, and no mention of MDM,
configuration profiles, or privilege escalation anywhere in the tree.

## 4. Testing And CI

`nix flake check` covers nothing meaningful here, because the flake declares no
`checks` output. Its outputs are `templates`, `devShells`, `apps`,
`darwinConfigurations`, and `nixosConfigurations`
([flake.nix#L101-L182](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/flake.nix#L101-L182)).
Per the flake-check behavior our target-state doc already documents, that means
`nix flake check` evaluates the NixOS toplevels and skips the Darwin ones
entirely. `CLAUDE.md` nonetheless tells agents to run `nix flake check` as
step one of testing
([#L161-L166](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/CLAUDE.md#L161-L166)).

There is no `checks/` directory, no NixOS VM test, no snapshot or golden test,
and no CI matrix. The one test directory is Python unit tests for a Home
Assistant garage-image analyzer, run by a shell script that shells out to
`nix shell --impure`
([run-tests.sh#L9-L11](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/tests/garage-analyzer/run-tests.sh#L9-L11)).
Nothing in CI invokes it.

CI is three workflows plus Dependabot.

| Workflow | Trigger | What it actually builds |
| --- | --- | --- |
| Build Starter Template | push or PR touching `templates/starter/**` only ([build.yml#L3-L20](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/.github/workflows/build.yml#L3-L20)) | `nixosConfigurations."x86_64-linux".config.system.build.toplevel` of a freshly `nix flake init`-ed starter, on `ubuntu-latest` ([build-template.yml#L15](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/.github/workflows/build-template.yml#L15), [#L102-L115](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/.github/workflows/build-template.yml#L102-L115)) |
| Statix Lint | push or PR outside `.github/` and `README.md` ([lint.yml#L3-L15](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/.github/workflows/lint.yml#L3-L15)) | `nix run nixpkgs#statix -- check .` over the whole repo ([#L29-L39](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/.github/workflows/lint.yml#L29-L39)) |
| Update Flake Lock | weekly cron ([update-flake-lock.yml#L4-L6](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/.github/workflows/update-flake-lock.yml#L4-L6)) | gates on the same starter build, then runs `DeterminateSystems/update-flake-lock` against the repo root ([#L8-L12](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/.github/workflows/update-flake-lock.yml#L8-L12), [#L61-L67](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/.github/workflows/update-flake-lock.yml#L61-L67)) |

Three properties follow, and all three matter for us. There is no macOS runner
anywhere. The author's real configuration is never built by CI, on any
platform. And the lock-bump gate validates the starter template while bumping
the root lock, so the thing tested is not the thing changed. The 59-for-59
failure record confirms the gate has never actually gated anything. The
20 most recent Statix runs all passed, out of 121 total; the starter build
workflow has run only 19 times in the repo's life because of its path filter.
A Dependabot PR bumping `actions/checkout` has sat open since 2025-11-24.

## 5. Compare And Contrast With Our Doc

### The app-module-plus-roles composition model

Our doc's central claim is that the Nix-native unit is
`modules/apps/<app>.nix` owning package, config, defaults domain, launchd
agent, and secrets together, with roles importing app modules and hosts
importing roles.

This repo is **evidence against that being the natural attractor, and mixed
evidence on whether it is right.** It states the opposite design goal in its
own feature list: "Optimized for simplicity and readability in all cases, not
small files everywhere"
([README.md#L81](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/README.md#L81)).
It is the most-forked macOS-plus-NixOS Nix config in existence and it has no
roles, one typed option module outside the templates, and composition by `//`.
Our doc cites SrvOS, nixos-hardware, flake-parts, and lewisflude/nix for the
module-composition pattern. Those are real, but they are not what the
mass-adopted starter does.

The counter-evidence inside the same repo is `garfield`, which is exactly our
shape: a host whose `imports` list is per-capability modules, with an explicit
comment about which shared module it excludes
([garfield/default.nix#L8-L51](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/hosts/nixos/garfield/default.nix#L8-L51)).
That decomposition appeared on the host that actually has divergent
capabilities. The Darwin side, which has one machine, never needed it.

Should our doc change? Add one sentence and one caveat. The sentence: the
module-composition model earns its keep in proportion to how much hosts
diverge, and this repo shows the same author reaching for it on the host that
diverges and skipping it on the host that does not. We have four machine types
including an MDM-managed work Mac, so we are on the diverging side and the
model still looks right. The caveat is worth recording because our doc treats
per-app decomposition as simply better; a well-liked repo treats file count as
a cost and says so out loud.

Second, concrete finding for the doc: **`//` and `lib.recursiveUpdate` are the
trap to name.** Our Appendix A row 8 maps chezmoi's layered merge onto module
option priorities. This repo shows what happens when you skip the module
system and merge attrsets by hand: `programs = shared-programs // { ... }`
silently replaces whole `programs.<app>` subtrees. Our doc should say that the
alternative to typed options is not "simpler", it is shallow-merge semantics
that nobody wrote down.

### The "what disappears" table

Mostly supported, with two rows this repo argues against.

- Feature resolver, layered machine data, cask gates, group union, hash lines,
  Brewfile renderer, first-run prompts: all absent here. Consistent with the
  table, though absent-because-unneeded is weaker evidence than
  absent-because-replaced.
- **"First-run prompts and `[data].machines_local`: gone. Host policy is
  committed."** Contradicted. This repo reintroduces first-run prompts and
  full-tree text substitution in `nix run .#apply`
  ([apply#L119-L143](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/apps/aarch64-darwin/apply#L119-L143),
  [#L204-L234](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/apps/aarch64-darwin/apply#L204-L234)).
  The prompts disappear from the config only for the author, who committed his
  own values. For anyone adopting the config, Go templates came back as `sed`.
  Our doc should note that "identity is the flake attribute" holds for a repo
  with one owner and breaks the moment the repo has to be instantiated.
- **"Retired-package ledger: gone for Nix packages. Homebrew cleanup is a
  per-host policy."** Supported, and the per-host policy chosen here is "no
  cleanup at all". Both templates ship the option commented out. That is a data
  point for open question 7: in practice people do not turn
  `onActivation.cleanup` on.

### The per-app ownership table

Our table lists nine structured configs and concludes that two mergers
disappear, one splits, and six remain. **This repo does not intersect the table
at all, and that itself is the finding.** It manages zero co-owned structured
configs. Claude Code is installed and its settings directory is gitignored.
There is no Codex, Cursor, pi, Orca, crit, agentsview, Yojam, or obsidian-wiki
config. The nvALT and plist cases have no analogue because
`CustomUserPreferences` is never used.

What it does contribute is a **fourth strategy our table does not name:
declare the state undeclarable and back it up.** The n8n and Home Assistant
state is explicitly excluded from the configuration and covered by an
age-encrypted nightly off-box backup instead
([backups.nix#L1-L30](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/nixos/backups.nix#L1-L30)).
Our per-app table's decisions are all "own it", "own a layer of it", or "keep
the merger". For a subset of our targets, particularly the auth-bearing files
where the Cursor merger exists only to avoid logging out, "do not manage it,
capture it" may be the honest third answer. Worth a row.

It also contributes a **fifth strategy for list-shaped app state: whole-list
ownership with a change guard.** The Dock reconciler is the shape our
`reconcile-*` scripts already use, arrived at independently
([dock/default.nix#L64-L77](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/darwin/dock/default.nix#L64-L77)).
Our doc's tier 3 describes the mergers as an unavoidable cost. This is
evidence that the reconcile-with-guard pattern is a normal Nix idiom, not a
chezmoi hangover, which slightly raises our confidence in keeping the six
mergers as activation blocks.

### Problem A: files the app also writes

Supported, from the other side. This repo never solves Problem A, and the
README documents the two failure modes our doc predicts.

- Row 40, pre-existing file at a managed path: the README warns readers they
  will hit `error: Unexpected files in /etc, aborting activation` and tells
  them to rename the files by hand
  ([README.md#L271-L283](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/README.md#L271-L283)).
- Whole-file ownership: a boxed caution that `~/.zshrc` "will be replaced"
  ([README.md#L306](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/README.md#L306)).

Our doc says home-manager's file model does not fit co-owned files, and that
`force` silently deletes the target. This repo confirms it by shipping user
documentation for exactly that hazard rather than a mechanism to avoid it. No
change needed to Problem A; add these as corroboration.

### Problem B: the MDM-managed work Mac

**No evidence either way, and the absence is informative.** The most-forked
macOS Nix config has nothing about MDM, configuration profiles, temp-admin,
or a non-admin user. Every macOS switch assumes `sudo` is available
([build-switch#L18](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/apps/aarch64-darwin/build-switch#L18)).
The repo's own architecture note about needing `sudo` cites nix-darwin issue
1457, the same issue our doc cites.

One relevant negative: the README's install path is the upstream Nix installer,
not Determinate
([README.md#L141-L146](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/README.md#L141-L146)),
and a merged 2025-12 PR removed the Determinate references. Our doc treats the
Determinate specifics as a live branch for the work Mac. This repo is evidence
that the ecosystem's default path is still plain upstream Nix, so the
Determinate coexistence rules stay a work-Mac-specific decision rather than
table stakes.

Our doc's Problem B conclusion stands unchanged. This survey adds: no popular
starter will help us with it.

### Problem C: secrets without store leakage

**This is the most useful thing in the repo, and it reframes one of our
options.**

Our doc's secrets table has four rows, and it rejects sops-nix and agenix on a
policy ground: "Encrypted license blobs would live in a public repo, a policy
shift from refs only." That objection is about where the ciphertext lives, not
about agenix.

This repo separates the two. The ciphertext lives in a private repo,
`dustinlyons/nix-secrets`, consumed as a `flake = false` input over SSH
([flake.nix#L47-L50](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/flake.nix#L47-L50)),
and the public repo contains only module declarations pointing at
`${secrets}/<name>.age`
([darwin/secrets.nix#L10-L45](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/darwin/secrets.nix#L10-L45)).
The README's workflow is: edit the `.age` file in the private repo, commit it
there, then `nix flake update` in the public repo to move the lock
([README.md#L455](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/README.md#L455)).

We already have this shape. ADR 0011 gives us a `dotfiles-private` git-repo
external over SSH. Our doc's Appendix A row 14 already maps it to a `git+ssh`
flake input. Nobody connected it to the secrets row. **Our doc should add a
fifth secrets option: agenix or sops-nix with the ciphertext in
`dotfiles-private`, consumed as the existing private flake input.** That keeps
`op://` refs out of the equation for the headless case, keeps ciphertext out of
the public repo, works unattended on the homelab mini, and does not need a
1Password service account. It should be evaluated against opnix in open
question 5 rather than dismissed.

Two caveats the repo also demonstrates. The agenix identity is
`~/.ssh/id_ed25519`, an unencrypted private key on every machine
([darwin/secrets.nix#L6-L8](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/darwin/secrets.nix#L6-L8)),
which is the same "unencrypted age key on every machine" cost our doc already
records for sops-nix. And key distribution stays imperative and physical: a
USB drive
([copy-keys#L32-L52](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/apps/aarch64-darwin/copy-keys#L32-L52)).
Our doc's row 2 gap, that `home.file` has no mode option, is confirmed from the
other direction: every mode in this repo comes from agenix, not home-manager
([darwin/secrets.nix#L16](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/darwin/secrets.nix#L16)).

### The test surface

**Contradicted, hard, and this is the second most useful finding.**

Our "What The Test Surface Becomes" section describes a target where every host
is exposed as a check, `nix flake check` builds closures per host, module tests
replace golden tests, and CI runs `nix build .#darwinConfigurations.<host>.system`
on a macOS runner. That is what a well-run Nix repo should do. It is not what
the most-forked one does, and the gap is instructive rather than merely
disappointing.

What this repo actually has: no `checks` output, so the flake exposes nothing
to check. No macOS runner, so the Darwin configuration is never built anywhere
but the author's laptop. CI builds only a trimmed template of the config, on
Linux, behind a path filter that fires on 19 pushes in five years. A weekly
auto-update gated on a build of something other than what it updates, failing
59 times out of 59.

Three revisions our doc should make.

1. Note the cost that the section currently understates. Exposing every host as
   `checks.<system>.<host>` is not free: it means a macOS runner in CI, because
   `nix build` of a Darwin toplevel needs a Darwin builder. Our current CI runs
   a macOS dry-run job already, so we can pay it, but the doc should say the
   macOS runner is load-bearing rather than assumed.
2. Note that `nix flake check` silently passing is the failure mode. A flake
   with no `checks` output and Darwin-only hosts gives a green `nix flake
   check` that proves nothing. Our doc says flake check "is narrower than it
   looks"; this repo is the worked example, and it also shows the CLAUDE.md
   drift that follows, where the agent instructions still tell you to run it
   ([CLAUDE.md#L161-L166](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/CLAUDE.md#L161-L166)).
3. Note the gate-versus-target mismatch as a named anti-pattern. Our doc says
   freshness "becomes a lock bump you review". This repo tried to automate the
   review away and built a gate over the wrong artifact. If we ever automate a
   lock bump, the gate must build the hosts the bump affects.

### Open questions this repo touches

| Q | Effect |
| ---: | --- |
| 2 | Unanswered but the exposure is smaller than we assumed. This repo never uses `defaults write` or `CustomUserPreferences`, so it has no data on running apps overwriting them. Typed `system.defaults` only. |
| 5 | Reframed. A private-repo agenix input is a fifth option that does not need 1Password service accounts at all. Evaluate it alongside opnix before answering. |
| 7 | Answered in practice, one data point: no. Cleanup is off in the live config and commented out in both templates. |
| 11 | No evidence. Whole-domain `defaults import` is never used here. |
| 12 | Weak evidence in favor of typed defaults sufficing for a small surface. Twenty keys across five typed domains with no escape hatch. Says nothing about our 143. |
| 16 | No evidence. No managed-path writes of any kind. |

Questions 1, 3, 4, 6, 8, 9, 10, 13, 14, and 15 are untouched.

### One more thing worth borrowing as a warning

`modules/shared/default.nix` pins the emacs-overlay by `builtins.fetchTarball`
of a moving `refs/heads/master` URL, with a hash. The comment above it,
written by the author, says the hash "goes stale every time emacs-overlay
pushes upstream and every build then fails with a hash mismatch, for every
host, not just the one being worked on"
([#L4-L9](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/shared/default.nix#L4-L9),
[#L46-L49](https://github.com/dustinlyons/nixos-config/blob/bc6a1e36ecc99ac265cce8c06d169b5fb96008d1/modules/shared/default.nix#L46-L49)).
The repo's own history bears it out: "bump the stale emacs-overlay pin" on
2026-08-31, "Update emacs sha" on 2026-07-11. Our doc's "what disappears" table
retires the weekly refresh in favor of a reviewed lock bump. This is the
concrete failure mode of half-migrating: anything not expressed as a flake
input gets a hand-maintained hash, and a stale hash breaks every host at once,
which is worse than the drift it was meant to replace.

## 6. What To Take, What To Avoid, And Relevance

### Take

- **The private secrets repo as a flake input.** The strongest single idea
  here. It resolves the policy objection our doc raises against agenix and
  sops-nix, reuses an input shape we already have in ADR 0011, and gives the
  homelab mini an unattended path that does not need a 1Password service
  account.
- **nix-homebrew configured as `mutableTaps = false` plus `autoMigrate = true`
  with taps as flake inputs.** Our Appendix A row 13 describes this
  configuration; this repo is a working instance of it on a real machine, which
  is the closest thing to validation we are going to get without trying it.
- **The diff-guarded whole-list reconciler.** Compare live state, act only on
  difference, restart the owner process. Independent arrival at the shape our
  reconcilers already use.
- **The "state the config cannot recreate" category, named and backed up.**
  A cleaner framing than treating everything as either declared or forgotten.
- **A named command surface as flake apps.** `nix run .#build-switch`,
  `.#rollback`, `.#clean`, `.#check-keys`. If we ever get here, `just` targets
  will do the same job, but the taxonomy of what commands you need is useful:
  build, switch, rollback, clean, and a key preflight.
- **README honesty about clobbering.** The `/etc` abort and the `~/.zshrc`
  caution are exactly the two things a chezmoi user will trip over on day one.

### Avoid

- Keying configurations by system architecture. It has already produced a
  `rollback` script pointing at an attribute that does not exist.
- Composition by `//` and `lib.recursiveUpdate` over imported attrsets. Use
  `imports` and typed options.
- Repeating `user = "dustin"` in five files while also threading it through
  `specialArgs`.
- A flake with no `checks` output, combined with agent instructions that tell
  you to run `nix flake check`.
- CI that builds a template instead of the configuration, on the wrong OS,
  behind a path filter.
- A scheduled auto-update gated on an artifact it does not update. Failing
  silently for a year is worse than not having it.
- `builtins.fetchTarball` of a moving ref with a hand-maintained hash. Make it
  a flake input or pin a tag.
- Shipping personalization as tree-wide `sed`, including rewriting `flake.nix`.

### Relevance to our repo: 2 / 5

This is a useful popularity baseline and it settles two things, but it is not
an architecture we can learn much structure from.

Against it we are roughly an order of magnitude more complicated. We have four
machine types where it has one Mac. We have 22 merges into app-owned files
where it has zero. We have 58 unique casks and a group-based selector where it
has 19 casks in a flat list. We have an MDM-managed work Mac where it has no
concept of managed anything. We have agent CLI configuration for Claude Code,
Codex, Cursor, and pi where it installs one CLI and gitignores its settings.
We have a headless Linux DevPod profile where it has no headless concept at
all. Every one of the hard problems our target-state doc is actually about is
a problem this repo does not have, which is precisely why it can be as simple
as it is.

What it does earn its two points for: the private-secrets-repo input is a
genuine addition to Problem C that we should evaluate; the CI reality check
(no macOS runner, no host builds, a year of silently failing automation) is a
concrete warning about the test surface we sketched; and its explicit
anti-decomposition stance, from the most-forked repo in this space, is worth
having on record when we argue for per-app modules. The score is not higher
because it answers none of our numbered questions definitively, contradicts our
composition model only by not needing it, and offers no evidence at all on
Problem B.

## 7. Concept-Map Scorecard

Rows from Appendix A of the target-state doc. Only rows with evidence here.

| Row | Verdict | Note |
| ---: | --- | --- |
| 1 | Supports | Six `home.file` text entries |
| 2 | Supports | agenix supplies modes, not home-manager |
| 3 | Supports | `executable = true` used once |
| 5 | Contradicts | Templating returned as tree-wide sed |
| 6 | Contradicts | System-keyed attrs; rollback already stale |
| 7 | Alternative | Imperative prompts rewrite the tree |
| 8 | Alternative | Shallow `//` merge, no priorities |
| 9 | Supports | Flat cask list, no groups |
| 10 | Supports | Shared plus per-platform package lists |
| 11 | Alternative | Cleanup off; Homebrew stays additive |
| 13 | Supports | mutableTaps false, autoMigrate true |
| 14 | Supports | Private secrets repo, git+ssh input |
| 15 | Alternative | Zsh plugins as nixpkgs packages |
| 16 | Contradicts | No gating; one Darwin host |
| 19 | Alternative | Internal diff guard, no onChange |
| 20 | Supports | Bootstrap lives outside the modules |
| 23 | Alternative | Typed domains only, no merging |
| 24 | Alternative | Unmanaged, or backed up instead |
| 25 | Alternative | Unconditional killall Dock, no prompt |
| 26 | Supports | Twenty keys, five typed domains |
| 27 | Supports | sudo every switch, issue 1457 cited |
| 28 | Contradicts | Only launchd agent is commented out |
| 31 | Alternative | Raycast script command as home.file |
| 35 | Supports | README warns zshrc gets replaced |
| 36 | Alternative | Hand-built XDG strings, not xdg.* |
| 37 | Alternative | agenix plus private repo, no vault |
| 38 | Supports | Build, switch, rollback; no drift report |
| 40 | Supports | README documents the /etc abort |
| 41 | Contradicts | No headless or WSL profile exists |
| 42 | Contradicts | CI builds a template, never a host |
