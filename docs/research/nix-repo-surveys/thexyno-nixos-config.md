---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-04
updated: 2026-09-04
related:
  - ../nix-target-state-research.md
  - ../nix-migration-research.md
status_detail: "Agent survey of thexyno/nixos-config at db554444, compared with the Nix target-state doc. Unreviewed."
---

# Survey: thexyno/nixos-config

## Method

Read on 2026-09-04 against a pinned tarball of
[thexyno/nixos-config](https://github.com/thexyno/nixos-config) at
`db554444e4ff2751d7cd818ea0c98d7b4fd4a150`, pulled with
`gh api repos/thexyno/nixos-config/tarball/<sha>`. Repository metadata,
workflow run history, and workflow state came from the GitHub API on the same
day; those facts have no permalink and are labelled as API reads.

Files read in full: `README.md`, `flake.nix`, `flake.lock` (parsed), all of
`data/`, all of `lib/`, `nixos-common.nix`, `darwin-common.nix`,
`darwin-modules/borgmatic.nix`, `hosts/daedalus/default.nix`, the import
blocks of the four NixOS hosts, `hm-modules/cli.nix`, `hm-modules/files.nix`,
`hm-modules/zsh/default.nix`, `hm-modules/vscode/default.nix`,
`secrets/secrets.nix`, `nixos-modules/system/agenix.nix`,
`nixos-modules/system/persist.nix`, `nixos-modules/user/default.nix`,
`nixos-modules/services/ssh.nix`, `nixos-modules/cli/default.nix`,
`.github/workflows/update.yaml`, `.github/flake-to-md.awk`, `lefthook.yml`,
`.envrc`, `.nixd.json`. Repo-wide greps covered `builtins.fromTOML`,
`fromJSON`, `activation`, `onChange`, `mkOutOfStoreSymlink`, `force = true`,
`launchd`, `system.defaults`, `masApps`, `homebrew`, and `options.ragon`.

Compared against [nix-target-state-research.md](../nix-target-state-research.md)
in full, plus the "Options" and "Sizing" sections of
[nix-migration-research.md](../nix-migration-research.md) and
[chezmoi-architecture.md](../../references/chezmoi-architecture.md).

Citations use the form
`https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/<path>#L<n>-L<m>`.
Nothing is cited that was not opened.

## 1. What It Is

The repository is deprecated. The first five lines of the README say so and
point at a self-hosted replacement at `git.xyno.systems`
([README.md#L1-L5](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/README.md#L1-L5)).
The rest of the README is a nine-line folder map
([README.md#L7-L23](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/README.md#L7-L23)),
and it names an `hm-imports/` directory that does not exist; the tree has
`hm-modules/`. That is the only documentation in the repo.

| Fact | Value | Source |
| --- | --- | --- |
| Author | thexyno / "ragon", one person, personal fleet | git identity in [hm-modules/cli.nix#L62-L65](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hm-modules/cli.nix#L62-L65) |
| Platforms | NixOS (x86_64-linux) and nix-darwin (aarch64-darwin) | [flake.nix#L208-L217](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/flake.nix#L208-L217) |
| Hosts | 5: four NixOS (`picard`, `ds9`, `voyager`, `theseus`), one Darwin (`daedalus`) | [flake.nix#L208-L217](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/flake.nix#L208-L217) |
| `.nix` files | 80, 7,595 lines total | counted in the pinned tarball |
| Where the lines are | `hosts/` 4,627 (61%), `hm-modules/` 1,450, `nixos-modules/` 859, `darwin-modules/` 73, `lib/` 133, `data/` 29 | counted in the pinned tarball |
| Total tracked files | 195, of which 69 are `.age` secrets | counted in the pinned tarball |
| Created / commits / last push | 2021-07-02 / 544 / 2026-02-26 | API |
| Stars / forks / license | 108 / 7 / MPL-2.0, not archived | API |

Activity is a wind-down. The last ten commit subjects are dominated by
"disable more stuff", "disable forgejo", "disable some migrated services"
(API), which matches the deprecation notice: services are moving to the new
repo and this one is being emptied.

How the lock is bumped. There is one workflow: a daily cron plus
`workflow_dispatch` that runs `nix flake update --commit-lock-file` and opens
a pull request whose body is a rendered per-input changelog with GitHub
compare links
([update.yaml#L3-L6](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/.github/workflows/update.yaml#L3-L6),
[#L34-L53](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/.github/workflows/update.yaml#L34-L53),
[flake-to-md.awk#L1-L3](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/.github/flake-to-md.awk#L1-L3)).
The design is good and the instance is dead. The workflow is currently
`state=disabled_inactivity`, the last 100 recorded runs all concluded
`cancelled`, and a filter for successful runs returns zero (API). The job
also pins `ubuntu-20.04`, Nix 2.6.1, and `::set-output`, all retired.

The consequence is visible in `flake.lock`. Input ages at this sha, computed
from `lastModified`:

| Input | Declared ref | Locked date |
| --- | --- | --- |
| `nixpkgs` | `nixos-25.11` | 2026-01-02 |
| `nixpkgs-master` | `master` | 2026-01-02 |
| `home-manager` | `release-25.11` | 2026-01-01 |
| `darwin` | `lnl7/nix-darwin/master` | 2025-12-29 |
| `agenix` | `main` | 2025-11-08 |
| `nixpkgs-darwin` | `nixpkgs-24.05-darwin` | 2024-12-30 |

The Mac builds against a nixpkgs branch pinned thirteen months behind the one
the Linux hosts use. The `darwin` input still points at `lnl7/nix-darwin`,
the pre-rename org.

Local tooling: `.envrc` is `use flake`
([.envrc#L1](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/.envrc#L1)),
the devShell carries `nixfmt-rfc-style`, `nil`, `lefthook`, and `agenix`
([flake.nix#L222-L227](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/flake.nix#L222-L227)),
and a lefthook pre-commit hook runs `nixpkgs-fmt`
([lefthook.yml#L1-L6](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/lefthook.yml#L1-L6)).
The formatter the hook runs is not the formatter the devShell installs.

## 2. Composition

### What `data/` actually holds

Two files, and the directory is not what the name suggests.

`data/pubkeys.nix` is 29 lines of plain Nix
([data/pubkeys.nix#L1-L29](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/data/pubkeys.nix#L1-L29)).
It is a `let`-bound attrset of SSH public keys that exports four value sets
(`user`, `server`, `client`, `computers`) and two functions,
`host = hn: hosts.${hn} ++ user` and `hosts = hn: ...`
([#L20-L25](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/data/pubkeys.nix#L20-L25)).
It is imported directly by five call sites:
[nixos-common.nix#L5](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/nixos-common.nix#L5),
[secrets/secrets.nix#L2](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/secrets/secrets.nix#L2),
[nixos-modules/user/default.nix#L8](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/nixos-modules/user/default.nix#L8),
[nixos-modules/services/ssh.nix#L4](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/nixos-modules/services/ssh.nix#L4),
and
[hosts/picard/hardware-configuration.nix#L6](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hosts/picard/hardware-configuration.nix#L6).

`data/monitoring.toml` is 17 lines describing a Prometheus master host and
per-exporter host lists
([data/monitoring.toml#L1-L17](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/data/monitoring.toml)).
Nothing reads it. A repo-wide grep for `monitoring` outside that file returns
no hits, and a repo-wide grep for `builtins.fromTOML`, `importTOML`, or
`fromJSON` returns no hits at all. The file is dead.

There is a second dead data file outside `data/`.
`hm-modules/vscode/extensions.toml` is 196 lines of publisher and extension
names
([extensions.toml](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hm-modules/vscode/extensions.toml)).
It is also unreferenced. The module instead imports a hand-committed
332-line
[vscode-extensions.nix](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hm-modules/vscode/vscode-extensions.nix)
of `extensionFromVscodeMarketplace` calls with pinned versions and hashes
([vscode/default.nix#L6](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hm-modules/vscode/default.nix#L6)).
The TOML is an out-of-band generator input, not a data layer. The directory
also contains a zero-byte file named `PLEASE FORGIVE ME FOR THIS SINFUL ACT`.

So the answer to the question that motivated this survey: there is no
evaluated data layer here. There is one shared-constants file written in
Nix, and two rotted serialization files.

### Compared with our `machines.toml` plus `features.tmpl`

| Our construct | Their equivalent | Note |
| --- | --- | --- |
| `machines.toml` five-layer merge (defaults, os, type, composite, host) | none | No layered resolver exists. |
| `machine_type` (`ci`/`personal`/`homelab`/`work`) | none | Nothing reads a machine class at evaluation time. |
| `features.tmpl` resolver | none | Feature selection is the host's import list. |
| `packages.toml` group union | none | Package lists are literal, inline, per host. |
| `.chezmoidata/*.toml` read by templates | `data/pubkeys.nix` imported as Nix | Values and functions, not a dictionary. |

### How hosts compose

`flake.nix` defines two builder functions. `nixosSystem` takes a system,
extra modules, and a hostname, and prepends a fixed base: agenix,
impermanence, home-manager, kmonad, two of the author's own flakes, an inline
module that sets `networking.hostName` and `system.configurationRevision`,
and `./nixos-common.nix`
([flake.nix#L139-L169](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/flake.nix#L139-L169)).
`darwinSystem` does the same with home-manager and `./darwin-common.nix`
([flake.nix#L170-L190](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/flake.nix#L170-L190)).
`processConfigurations = lib.mapAttrs (n: v: v n)` passes the attribute name
in as the hostname, so the flake attribute is the identity
([flake.nix#L192](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/flake.nix#L192)).

There is no role layer. Each host repeats an explicit list of relative module
paths:
[hosts/ds9/default.nix#L13-L32](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hosts/ds9/default.nix#L13-L32),
[hosts/picard/default.nix#L14-L38](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hosts/picard/default.nix#L14-L38),
[hosts/theseus/default.nix#L9-L19](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hosts/theseus/default.nix#L9-L19),
[hosts/voyager/default.nix#L3-L12](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hosts/voyager/default.nix#L3-L12).
All four repeat `ssh.nix`, `agenix.nix`, `persist.nix`, and `user`. Within
those lists, the on and off switch is a comment: `ds9` carries eight
commented-out imports next to its thirteen live ones.

Auto-discovery exists in `lib` and is not used. `lib/modules.nix` provides
`mapModules`, `mapModules'`, `mapModulesRec`, and `mapModulesRec'`
([lib/modules.nix#L9-L53](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/lib/modules.nix#L9-L53)),
and the two flake outputs that would have exposed the module trees
automatically are commented out
([flake.nix#L205-L206](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/flake.nix#L205-L206)).
`mapModules` survives only for `packages`
([flake.nix#L228](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/flake.nix#L228)).
Auto-import was tried and abandoned in favour of explicit lists.

### How the three module trees relate

| Tree | Lines | Imported by | Shape |
| --- | --- | --- | --- |
| `nixos-modules/` | 859 | NixOS host files, by path | 20 files declaring `options.ragon.*` with `mkIf cfg.enable` bodies |
| `hm-modules/` | 1,450 | inline `home-manager.users.<name>` blocks in host files | mixed: some declare `options.ragon.<app>.enable`, some are unconditional |
| `darwin-modules/` | 73 | nothing | `.gitkeep` plus `borgmatic.nix`, whose only consumer is commented out ([hosts/daedalus/default.nix#L86-L139](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hosts/daedalus/default.nix#L86-L139)) |

The typed-option namespace is real and consistent. Twenty modules declare
`options.ragon.*`, built on three helpers in
[lib/options.nix#L7-L17](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/lib/options.nix#L7-L17).
Modules contribute to each other's options: `nixos-modules/user` sets
`ragon.persist.extraDirectories` and `ragon.agenix.secrets.ragonPasswd`
([user/default.nix#L53](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/nixos-modules/user/default.nix#L53),
[#L65](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/nixos-modules/user/default.nix#L65)).
`darwin-modules/borgmatic.nix` contributes `homebrew.brews` and asserts that
Homebrew is enabled
([#L37](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/darwin-modules/borgmatic.nix#L37),
[#L64-L69](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/darwin-modules/borgmatic.nix#L64-L69)).

### Where identity lives

Hardcoded in a shared home-manager module.
[hm-modules/cli.nix#L62-L65](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hm-modules/cli.nix#L62-L65)
sets `user.name`, `user.email`, and one SSH signing key, with the inline
comment `# TODO: don't hardcode a computer`. The username is a typed option
with a default (`ragon`) in
[nixos-modules/user/default.nix#L18-L22](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/nixos-modules/user/default.nix#L18-L22),
but the Mac uses a different user (`xyno`) declared directly in the host
([hosts/daedalus/default.nix#L8-L11](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hosts/daedalus/default.nix#L8-L11)).
Identity is split across three places and is not derived from host data.

### Laptop vs server vs Mac

Expressed three ways, none of them a data lookup. The platform split is the
builder function and the nixpkgs input: Linux hosts get `nixpkgs`
(`nixos-25.11`), the Mac gets `nixpkgs-darwin` (`nixpkgs-24.05-darwin`)
([flake.nix#L8-L9](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/flake.nix#L8-L9),
[#L127-L134](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/flake.nix#L127-L134)).
The class split is the import list: servers pull service modules, the laptop
`theseus` pulls its own compositor, bar, and keyboard files from its host
directory. The Mac has no top-level `imports` key at all; its only import
block is inside the home-manager user
([hosts/daedalus/default.nix#L143-L153](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hosts/daedalus/default.nix#L143-L153)).

## 3. Per-App Config Mechanics

`programs.*` first, `home.file` for the rest, and nothing else. There are 33
`programs.<name>` enable or block sites. `home.file` appears exactly eleven
times, and every one of them is a file only the config writes: the nvim
config directory as a recursive source
([nvim/default.nix#L52-L53](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hm-modules/nvim/default.nix#L52-L53)),
tmux theme scripts, a Hammerspoon `init.lua` built with `substituteAll` and a
generated notmuch counter script
([hosts/daedalus/default.nix#L155-L165](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hosts/daedalus/default.nix#L155-L165)),
and sway, mako, and wezterm configs written as `.text`.

VS Code is the fullest example of the `programs.*` route: extensions,
`userSettings`, and `keybindings` are all Nix values
([vscode/default.nix#L103-L233](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hm-modules/vscode/default.nix#L103-L233)).

### Activation

There is none. A repo-wide grep across all 80 `.nix` files finds zero uses of
`home.activation`, `system.activationScripts`, `onChange`,
`mkOutOfStoreSymlink`, or `force = true`. Every side effect is either a
module upstream provides or nothing.

### Any app-rewritten file managed?

No, and there is one visible retreat. VS Code's extension directory is the
one place they got close, and `mutableExtensionsDir = false` is commented out
([vscode/default.nix#L20](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hm-modules/vscode/default.nix#L20)),
leaving the directory mutable and app-owned.

The closest thing to a merge is the inverse trick: writing an empty file so
the app stops writing it. `hm-modules/files.nix` declares `.zshrc` as empty
text with the comment "empty zshrc to stop zsh-newuser-install from running"
([files.nix#L11-L12](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hm-modules/files.nix#L11-L12)),
and `theseus` overrides it with `lib.mkForce` to exec into nushell
([hosts/theseus/default.nix#L268](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hosts/theseus/default.nix#L268)).

Whole-file generation from Nix values does appear, but only at system paths
the app does not write: `pkgs.formats.yaml {}` with a `freeformType`
submodule generates borgmatic's config
([borgmatic.nix#L5-L9](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/darwin-modules/borgmatic.nix#L5-L9),
[#L39-L44](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/darwin-modules/borgmatic.nix#L39-L44)),
and `builtins.toJSON` generates waybar's
([waybar.nix#L28](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hosts/theseus/waybar.nix#L28)).

### macOS defaults

Typed `system.defaults` only: 15 keys across `NSGlobalDomain`, `dock`,
`finder`, and `loginwindow`, all in one block in `darwin-common.nix`
([#L29-L45](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/darwin-common.nix#L29-L45)).
No `CustomUserPreferences`, no `CustomSystemPreferences`, no
`targets.darwin.defaults`, no PlistBuddy, no `killall`. For scale, our repo
has 145 executable `defaults write` lines and twelve plist merge stubs.

### Casks, MAS, taps

nix-darwin's `homebrew` module with literal lists inline in the host file:
2 taps, 6 live brews (2 commented), 26 live casks (7 commented)
([hosts/daedalus/default.nix#L13-L80](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hosts/daedalus/default.nix#L13-L80)).
The `masApps` block exists and is entirely commented out, with an inline note
about running `mas list` to get ids
([#L68-L79](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hosts/daedalus/default.nix#L68-L79)).
There is no `homebrew.onActivation` block at all, so Homebrew is additive:
nothing is ever uninstalled. There is no nix-homebrew. Homebrew is assumed
preinstalled and hardcoded: `eval "$(/opt/homebrew/bin/brew shellenv)"` in
`programs.zsh.shellInit` and `/opt/homebrew/{bin,sbin}` appended to
`environment.systemPath`
([darwin-common.nix#L9-L12](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/darwin-common.nix#L9-L12)).

### launchd

One agent in the whole repo, and it is not loaded. `launchd.user.agents.borgmatic`
uses an inline `script`, a `pmset` battery check, an hourly `StartInterval`,
and log paths under `/var/log`
([borgmatic.nix#L46-L63](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/darwin-modules/borgmatic.nix#L46-L63)).
Its only consumer is the commented-out block in the Mac host.

### Secrets with agenix on Darwin

They are not. `agenix.nixosModules.age` is in the `nixosSystem` module list
([flake.nix#L149](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/flake.nix#L149))
and is absent from `darwinSystem`
([flake.nix#L174-L190](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/flake.nix#L174-L190)).
The Mac has no secrets management. Where borgmatic on the Mac needs a
passphrase, the commented-out config reaches for the macOS keychain through
`security find-generic-password`, not agenix
([hosts/daedalus/default.nix#L102](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hosts/daedalus/default.nix#L102)).

On NixOS the pattern is clean and worth reading. A wrapper module declares
`ragon.agenix.secrets` as a free attrset
([agenix.nix#L12-L18](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/nixos-modules/system/agenix.nix#L12-L18)),
derives each `age.secrets.<name>.file` from the name so callers never write a
path
([#L27-L32](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/nixos-modules/system/agenix.nix#L27-L32)),
asserts that `secrets/secrets.nix` exists
([#L33-L35](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/nixos-modules/system/agenix.nix#L33-L35)),
and sets the decryption identity to the host's own SSH key on the persistent
volume
([#L23-L26](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/nixos-modules/system/agenix.nix#L23-L26)).
Any service module then opts in with one line. Recipient policy is a single
72-line file where each secret names its readers as a function call over the
pubkeys attrset, for example `pubkeys.ragon.host "ds9"`
([secrets/secrets.nix#L15-L31](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/secrets/secrets.nix#L15-L31)).
69 encrypted `.age` files are committed to this public repository.

### Anything root per switch

Nothing beyond what nix-darwin and NixOS already require. There is no
elevation helper, no MDM handling, and no sudo keepalive.
`security.pam.enableSudoTouchIdAuth = true` removes the password prompt
([darwin-common.nix#L8](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/darwin-common.nix#L8)).
The Mac delegates Linux builds to `ds9` over SSH with a hardcoded key path
and a base64 host key
([darwin-common.nix#L14-L24](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/darwin-common.nix#L14-L24)),
and forces `ids.uids.nixbld` to 400 to dodge a uid collision
([hosts/daedalus/default.nix#L81-L82](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hosts/daedalus/default.nix#L81-L82)).

## 4. Testing And CI

There is no test surface.

- `flake.nix` exposes no `checks` output and no `nixosTest`. The outputs are
  `lib`, `overlays`, `nixosConfigurations`, `darwinConfigurations`, plus a
  per-system `devShell` and `packages`
  ([flake.nix#L196-L229](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/flake.nix#L196-L229)).
- No test files exist anywhere in the 195 tracked files.
- The only workflow is the lock bumper described above, and GitHub has
  disabled it for inactivity (API).
- The only enforced local gate is `nixpkgs-fmt` on staged `.nix` files
  ([lefthook.yml#L1-L6](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/lefthook.yml#L1-L6)).

`nix flake check` was clearly run by hand at some point.
`nixos-common.nix` carries boot loader defaults under the comment "This is
here to appease 'nix flake check' for generic hosts with no
hardware-configuration.nix or fileSystem config"
([nixos-common.nix#L55-L65](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/nixos-common.nix#L55-L65)).
Nothing runs it in CI, and there is no equivalent accommodation on the Darwin
side, which is consistent with our doc's finding that `nix flake check` walks
`nixosConfigurations` and not `darwinConfigurations`.

The nearest thing to a typed contract check is editor-time: `.nixd.json`
points the language server at `.#nixosConfigurations.picard.options` so the
`ragon.*` namespace completes and typechecks while editing
([.nixd.json#L1-L8](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/.nixd.json#L1-L8)).

## 5. Compare And Contrast With Our Doc

### The key question: is a data layer inside a Nix config a chezmoi-ism?

The review's claim survives, and this repo sharpens it rather than
contradicting it.

The GitHub API surfaced a `data/` directory, which suggested a data-driven
host model. It is not one. There is no `builtins.fromTOML` in the repo. The
one live file in `data/` is plain Nix that exports values and two functions
([data/pubkeys.nix#L20-L25](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/data/pubkeys.nix#L20-L25)),
which is the shape our doc already recommends: derived values with real
types, not an untyped dictionary merged by a generic algorithm. Calling that
a data layer would be a category error.

What it buys: one place for facts that six files need, expressed so that
`pubkeys.ragon.host "ds9"` reads as intent rather than as a lookup.

What it costs, and this is the argument our doc does not currently make:
serialization files that nothing evaluates rot silently. Both TOML files in
this repo are unreferenced, one of them describing a monitoring topology that
presumably used to be real. Nix cannot tell you a TOML file is dead. A module
option can, through `nix eval` and `assertions`. That is a durable reason to
prefer options over data files that goes beyond "types are nicer".

Recommended doc change: keep the "no data layer" position, but restate the
objection precisely. The objection is to reading a layered foreign-format
dictionary at evaluation time and merging it with hand-written semantics. A
`data/` directory holding shared literals as Nix, exposing helper functions,
is a legitimate and useful pattern, and our `pubkeys`-shaped constants
(machine aliases, host lists) would be better off there than inside
`machines.toml`.

### Composition model

| Our doc's claim | This repo | Verdict |
| --- | --- | --- |
| Host identity is a flake attribute, not a prompt | `processConfigurations` maps attribute names to hostnames ([flake.nix#L192](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/flake.nix#L192), [#L208-L217](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/flake.nix#L208-L217)) | Supports |
| Nothing reads a `machine_type` at evaluation time | Nothing does | Supports |
| Typed options replace the data layer | 20 modules declare `options.ragon.*` on three helpers ([lib/options.nix#L7-L17](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/lib/options.nix#L7-L17)) | Supports |
| Roles import app modules; hosts import roles | No role layer after 544 commits; per-host duplicated import lists | Contradicts as description of practice |

The role layer is the interesting gap. Our doc's tree presents `roles/` as
the natural landing place, citing SrvOS and flake-parts. This repo shows the
counterfactual: skip roles and the host file absorbs everything. 61% of the
`.nix` lines here live under `hosts/`, the four NixOS hosts each repeat the
same four base imports, and feature toggling degenerates into commenting out
import lines. The author even built the auto-discovery helpers that would
have supported a role tree and then commented out the outputs that used them
([flake.nix#L205-L206](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/flake.nix#L205-L206),
[lib/modules.nix#L28-L40](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/lib/modules.nix#L28-L40)).

Recommended doc change: add a sentence to "Composition model" saying roles
are an investment that does not appear on its own, and that the failure mode
of skipping them is a fat host file plus comment-driven toggling. That is a
cost our doc currently prices at zero.

### The "what disappears" table

Nothing in the table is contradicted. Every construct our doc says disappears
is simply absent here: no resolver, no ignore gates, no group union, no
once-only scripts, no drift banner, no Brewfile renderer, no plist stubs, no
first-run prompts. Two rows deserve a caveat.

**Brewfile renderer.** Our doc says the renderer and its golden tests
disappear because `homebrew.brewfile` is module output. True for the emit
step. What disappears with it here is the group model itself: this repo has a
flat inline list per host and no notion of package groups
([hosts/daedalus/default.nix#L13-L80](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hosts/daedalus/default.nix#L13-L80)).
nix-darwin gives us a list, not a union of named groups. If we want
`packages.toml` semantics we rebuild them in Nix. Row 9's "full" is right
about the option surface and understates the work.

**Retired-package ledger.** Our doc's row 11 offers two choices,
`cleanup = "uninstall"` or `cleanup = "check"`. This repo shows a third:
configure no cleanup at all and accept that removed casks stay installed. No
`homebrew.onActivation` block exists. Given the work Mac, additive-only is
probably our answer too, and it should be named as an option rather than left
implicit.

### The per-app ownership table

This repo manages zero app-rewritten files, so it is not evidence for or
against the merger tiers. It is evidence for two adjacent things.

First, tier 1 at its cheapest. `environment.etc` plus a format generator owns
a whole config file at a path the app reads and does not write
([borgmatic.nix#L39-L44](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/darwin-modules/borgmatic.nix#L39-L44),
[waybar.nix#L28](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hosts/theseus/waybar.nix#L28)).
That is exactly the shape our doc proposes for `/etc/codex/config.toml`.

Second, a technique our doc's merges section does not mention.
`pkgs.formats.yaml {}` combined with a `submodule` carrying `freeformType`
gives a typed option that accepts an arbitrary upstream schema without
declaring two hundred options
([borgmatic.nix#L5-L9](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/darwin-modules/borgmatic.nix#L5-L9)).
For the six apps that keep a merger, the desired fragment could be a
`freeformType` option rendered by `settingsFormat.generate` instead of a
`pkgs.writeText` blob. That is a real improvement to the tier 3 design and
should go into the doc.

### Problem A: files the app also writes

No solution here, and one deliberate retreat: `mutableExtensionsDir = false`
is commented out
([vscode/default.nix#L20](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hm-modules/vscode/default.nix#L20)).

The finding is negative but useful. A 544-commit, five-host, five-year Nix
config with a Darwin machine simply does not attempt Problem A. Our doc frames
the three tiers as the design space; this repo shows a fourth option that is
common in practice, which is to not manage those files and let the app own
them. For us that means giving up 22 merge targets, which we will not do, but
the doc should name the option and say what it costs so the tier-3 activation
machinery reads as a deliberate choice rather than the only path.

### Problem B: the MDM-managed work Mac

No evidence. The Darwin host is a personal Mac with no MDM, no configuration
profiles, and no elevation flow. The only adjacent signal is the nixbld uid
collision workaround
([hosts/daedalus/default.nix#L81-L82](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hosts/daedalus/default.nix#L81-L82)),
which is the class of problem a managed directory service makes worse. Our
doc's Problem B is unchanged; this survey neither supports nor weakens it.

### Problem C: secrets without store leakage

The most useful section of the repo, with one decisive caveat.

The caveat first: agenix is wired into `nixosSystem` and not into
`darwinSystem`
([flake.nix#L149](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/flake.nix#L149)
vs
[#L174-L190](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/flake.nix#L174-L190)),
and the Mac reaches for the macOS keychain where it needs a passphrase
([hosts/daedalus/default.nix#L102](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hosts/daedalus/default.nix#L102)).
This is direct evidence that agenix-on-Darwin is not the well-trodden path,
which strengthens our doc's ranking of `op read` in activation for
interactive Macs.

The repo does confirm the policy shift our doc flags: 69 encrypted `.age`
files are committed to a public repository with 108 stars. That is normal in
this community. It is also not our situation. Their secrets are server
credentials with a machine-readable recovery path; ours are three license
keys tied to a personal 1Password with biometric unlock, and the identity in
their model is the host's own SSH key on a persistent volume
([agenix.nix#L23-L26](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/nixos-modules/system/agenix.nix#L23-L26)),
which a Mac does not have in the same shape.

Worth taking regardless of backend: the split between a recipient-policy file
and a per-service opt-in. One file says who can read what, as function calls
([secrets/secrets.nix#L15-L31](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/secrets/secrets.nix#L15-L31));
service modules declare only the names they need
([user/default.nix#L65](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/nixos-modules/user/default.nix#L65));
one wrapper derives paths from names and asserts the policy file exists
([agenix.nix#L27-L35](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/nixos-modules/system/agenix.nix#L27-L35)).
Our `secrets.toml` and `licenses.toml` could adopt that shape without
changing backend.

### The test surface

This is the section our doc should adjust most.

Our doc plans `checks.<system>.<host>` per host, module tests on generated
scripts, `nmt` file-tree assertions, and a Tart lane. This repo, at 108 stars
and 544 commits, has zero checks, zero tests, and one CI job that GitHub has
disabled for inactivity. Its only enforced gate is a formatter that is not
the formatter its own devShell installs.

Two things follow. First, "nix flake check per host" is an aspiration we
would be choosing, not a baseline the ecosystem hands us. Second, our current
CI already exceeds this: shellcheck, a chezmoi dry run for three machine
types, Tart helper contract tests, trace conversion tests, package rendering,
and `ci` formula install checks. A migration would be a testing downgrade
until we rebuild that surface. Our doc's "What The Test Surface Becomes"
should say so directly, because right now it reads as a straight upgrade.

The lock-bump lesson belongs here too. Our doc says freshness becomes "a lock
bump you review, or a launchd job". This repo built the reviewable version
properly, with a rendered per-input changelog and compare links
([flake-to-md.awk](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/.github/flake-to-md.awk)),
and then it died quietly and the inputs drifted thirteen months apart. A lock
bumper needs its own liveness check, because a dead bumper and a stable
config look identical from the outside.

### Open questions this touches

| Q | Effect | Evidence |
| ---: | --- | --- |
| 2 | Weak signal only. They write 15 keys across the four domains least likely to be app-rewritten, so the question is untested here. | [darwin-common.nix#L29-L45](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/darwin-common.nix#L29-L45) |
| 3 | No evidence. No MDM anywhere in the repo. | n/a |
| 5 | No evidence. No 1Password integration. | n/a |
| 7 | Reframed. A third answer exists: configure no cleanup and accept drift. No `homebrew.onActivation` block. | [hosts/daedalus/default.nix#L13-L80](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hosts/daedalus/default.nix#L13-L80) |
| 1, 8, 9, 10, 11, 12, 13, 14, 15, 16 | No evidence. None of these apps or paths appear. | n/a |

Two questions this repo raises that our sixteen do not cover:

17. How do we detect that a committed data file has gone dead? Two of the
    three data-shaped files here are unreferenced. Under the module system an
    unused option is discoverable by evaluation; an unused TOML is not.
18. If the Mac needs a different nixpkgs channel from the Linux hosts, what
    stops the two from drifting? Here they are thirteen months apart with
    nothing flagging it.

## 6. What To Take, What To Avoid, Relevance

### Take

- The recipient-policy file. One file naming who can read each secret, with
  recipients as function calls over a shared key set
  ([secrets/secrets.nix](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/secrets/secrets.nix),
  [data/pubkeys.nix#L20-L25](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/data/pubkeys.nix#L20-L25)).
- The per-service secret opt-in. A wrapper module derives file paths from
  names and asserts the policy file exists, so callers write one line
  ([agenix.nix#L27-L35](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/nixos-modules/system/agenix.nix#L27-L35)).
- `pkgs.formats.<fmt> {}` with a `freeformType` submodule for app settings we
  want typed at the edges and freeform in the middle
  ([borgmatic.nix#L5-L9](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/darwin-modules/borgmatic.nix#L5-L9)).
- The lock-bump pull request with a rendered input changelog and compare
  links, plus a liveness check on the job itself
  ([update.yaml#L34-L53](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/.github/workflows/update.yaml#L34-L53)).
- Pointing the Nix language server at a real host's `options` so a custom
  option namespace completes while editing
  ([.nixd.json](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/.nixd.json)).
- Cross-module contribution with an assertion, as borgmatic adding to
  `homebrew.brews` and asserting Homebrew is enabled
  ([borgmatic.nix#L37](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/darwin-modules/borgmatic.nix#L37),
  [#L64-L69](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/darwin-modules/borgmatic.nix#L64-L69)).

### Avoid

- Two nixpkgs channels split by platform. It produced a thirteen-month gap
  with nothing detecting it.
- A `data/` directory holding files nothing evaluates.
- Comment-driven import toggling in host files. Use options with defaults.
- Skipping the role layer. Four hosts repeating four base imports is the
  cheapest possible warning.
- Identity hardcoded in a shared module with a TODO
  ([hm-modules/cli.nix#L62-L65](https://github.com/thexyno/nixos-config/blob/db554444e4ff2751d7cd818ea0c98d7b4fd4a150/hm-modules/cli.nix#L62-L65)).
- Zero checks. Our existing CI is stronger; a migration must not trade it
  away silently.
- A formatter in the pre-commit hook that the devShell does not install.

### Relevance: 2 of 5

The platform overlap is thin where it matters. One of five hosts is a Mac,
and Darwin-specific module code is 73 of 7,595 lines, in a file no host
imports. That Mac is personal: no MDM, no configuration profiles, no secrets,
no activation scripts, no app-owned-file management, no MAS, no Homebrew
cleanup policy, fifteen `defaults` keys against our 145 write lines. All
three of our hard problems live exactly in the space this repo does not
occupy. It is also deprecated, its CI is disabled, and its lock has drifted,
so it is not a maintained exemplar to copy from.

It earns a 2 rather than a 1 on two counts. It settles the question that
motivated the survey, by showing that the `data/` directory the API
advertised is not a data layer at all, and by supplying a new argument
against serialization data files: they rot invisibly. And its agenix
recipient-policy and per-service opt-in patterns are clean, small, and
portable to our secrets handling whatever backend we pick.

## 7. Scorecard Against Appendix A

Rows where this repo is evidence. Rows not listed have no evidence here.

| Row | Verdict | Note |
| ---: | --- | --- |
| 1 | Supports | Eleven `home.file` uses, own-written only |
| 4 | Alternative | No out-of-store symlinks at all |
| 5 | Supports | String interpolation replaces every template |
| 6 | Supports | Host is a flake attribute |
| 7 | Supports | No machine-local override; committed policy |
| 8 | Alternative | Explicit host imports, no resolver |
| 9 | Alternative | Flat inline lists, no groups |
| 11 | Alternative | No cleanup configured, additive only |
| 13 | Contradicts | Homebrew preinstalled, hardcoded `/opt/homebrew` path |
| 16 | Supports | `mkIf` on `ragon.*` enable options |
| 17 | Alternative | Cask list inline, ungated |
| 19 | Alternative | No `onChange`; nothing needed it |
| 20 | Alternative | No once-only construct at all |
| 21 | Alternative | No activation ordering to express |
| 23 | Alternative | Typed defaults only, fifteen keys |
| 24 | Alternative | Problem avoided rather than solved |
| 25 | Alternative | No guard, no merges |
| 26 | Supports | Typed `system.defaults`, no escape hatch |
| 28 | Supports | `launchd.user.agents` with inline script |
| 35 | Alternative | `initExtra` from `readFile`, no `dotDir` |
| 37 | Alternative | agenix, NixOS only, host keys |
| 42 | Contradicts | No checks, no per-host build |
