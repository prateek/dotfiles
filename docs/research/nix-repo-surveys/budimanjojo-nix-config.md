---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-04
updated: 2026-09-04
related:
  - ../nix-target-state-research.md
  - ../nix-migration-research.md
status_detail: "Agent survey of budimanjojo/nix-config at 20550123, compared with the Nix target-state doc. Unreviewed."
---

# Survey: budimanjojo/nix-config

## Method

Snapshot taken 2026-09-04 from the GitHub tarball at
`205501230750abc63d35cbe906ee855902b9911f`, the repository HEAD on that date.
All permalinks below point at that sha. Nothing is cited that was not opened.

Read in full: `README.md`, `flake.nix`, `.chezmoiroot`, the whole `chezmoi/`
directory (config, ignore file, five scripts, two managed files), `.sops.yaml`,
`.justfile`, `.github/renovate.json`, `lib/default.nix`, all of
`modules/flake/internal/` and `modules/flake/exposed/`, all nine files under
`modules/flake/exposed/perSystem/github-actions/`, the single home host
declaration, the `budimanjojo-main` host declaration, and a sample of feature
modules (chezmoi, alacritty, fontconfig, qmk on both sides, sops, kubernetes,
users, assertions, hm-integration). Also read the
[dendritic pattern README](https://github.com/mightyiam/dendritic/blob/6c76240658cf1c840faad557c0e0726064170a65/README.md)
at sha `6c76240658cf1c840faad557c0e0726064170a65`.

Counts were produced by `find`/`grep` over the 230 `.nix` files in the snapshot.
Commit and contributor figures came from the GitHub API, not from the tarball,
and so carry no permalink.

Compared against
[the Nix target-state doc](../nix-target-state-research.md), the Options and
Sizing sections of
[the prior migration doc](../nix-migration-research.md), and
[the chezmoi architecture reference](../../references/chezmoi-architecture.md).

## 1. What It Is

A homelab and workstation configuration by budimanjojo. The repository was
created 2016-07-28 and last pushed 2026-09-03. It has 289 stars and 230 `.nix`
files. The author's domain is Kubernetes and Talos infrastructure, which shows
up in the module set: disko for disk layout, talhelper, and a kubernetes module
that materializes a kubeconfig and a talosconfig
([kubernetes/default.nix#L26-L35](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/modules/homeManager/core/myHome/homelab/kubernetes/default.nix#L26-L35)).

Six hosts. Five are NixOS
(`budimanjojo-main`, `budimanjojo-nas`, `budimanjojo-firewall`,
`budimanjojo-oracle`, and a `nixos-livecd` ISO builder) and one is a
home-manager-only Ubuntu machine, `budimanjojo-ubuntu`
([homeHosts/budimanjojo-ubuntu/default.nix#L1-L32](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/homeHosts/budimanjojo-ubuntu/default.nix#L1-L32)).

Platforms: `x86_64-linux` only in practice. The system list is derived from the
host table rather than declared
([systems.nix#L3](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/flake/internal/systems.nix#L3)),
and every host takes the `x86_64-linux` default
([_utils/default.nix#L11-L14](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/flake/internal/_utils/default.nix#L11-L14)).
The CI runner map defines `x86_64-darwin` and `aarch64-darwin` entries
([matrix.nix#L15-L20](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/flake/exposed/perSystem/github-actions/matrix.nix#L15-L20)),
but nothing selects them because no host declares a darwin system. There is no
nix-darwin input and no macOS surface anywhere in the repository.

Activity is high and mostly automated. The GitHub API reports roughly 6,400
commits, of which about 4,700 are by `budimanjojo-bot` and another 300 by
Renovate; the human author accounts for roughly 1,500. The five most recent
commits at snapshot time were lock maintenance and action digest bumps, the
newest being PR #4999. The README states the lock is updated daily by
`budimanjojo-bot` powered by Renovate, and `packages/` daily by nvfetcher
([README#L59-L65](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/README.md#L59-L65)).
Renovate is configured with `lockFileMaintenance` scheduled nightly and
`automerge: true`
([renovate.json#L5-L12](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/.github/renovate.json#L5-L12)).

The author frames the repository as a work in progress and asks readers not to
import it
([README#L18-L22](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/README.md#L18-L22)).

## 2. Composition

### Dendritic as practiced

The README declares the dendritic pattern on the first content line
([README#L13](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/README.md#L13))
and again in the structure section
([README#L56-L57](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/README.md#L56-L57)).
The entire flake output is one line:

```nix
flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
```

([flake.nix#L84-L86](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/flake.nix#L84-L86)).
`import-tree` walks `./modules` recursively, so every file under it is a
top-level flake-parts module. There is no import list anywhere.

The tree has four tiers:

| Path | Role |
| --- | --- |
| `modules/flake/internal/` | Typed options that are not flake outputs: `nixosHosts`, `homeHosts`, `systems`, `myLib` |
| `modules/flake/exposed/` | The actual flake outputs: `nixosConfigurations`, `homeConfigurations`, `checks`, `packages`, CI workflows |
| `modules/modules/{nixos,homeManager,generic}/` | Feature modules, stored as option values |
| `modules/{nixosHosts,homeHosts}/<host>/` | Host entry points |

### One module file

Every feature module has the same shape. Alacritty is representative:

```nix
{
  flake.modules.homeManager.core =
    { config, lib, pkgs, ... }:
    let
      cfg = config.myHome.terminal-emulator.alacritty;
    in
    {
      options.myHome.terminal-emulator.alacritty.enable = lib.mkEnableOption "alacritty";
      config = lib.mkIf (cfg.enable) { /* programs.alacritty = ... */ };
    };
}
```

([alacritty/default.nix#L1-L48](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/modules/homeManager/core/myHome/terminal-emulator/alacritty/default.nix#L1-L48)).

The important detail is the target name. Every home-manager feature writes into
`flake.modules.homeManager.core`, and every NixOS feature into
`flake.modules.nixos.core`. `deferredModule` merging folds them all into one
module. This is the dendritic README's stated advice for avoiding import-list
churn
([dendritic README#L193-L203](https://github.com/mightyiam/dendritic/blob/6c76240658cf1c840faad557c0e0726064170a65/README.md#L193-L203)),
and it is what makes the pattern cheap here: adding a feature file requires no
edit anywhere else.

### Two deviations from the pattern

First, features are split by configuration class rather than unified. The
dendritic README says every top-level module implements a single feature
"across all configurations that that feature applies to"
([dendritic README#L60-L69](https://github.com/mightyiam/dendritic/blob/6c76240658cf1c840faad557c0e0726064170a65/README.md#L60-L69)).
In this repository, QMK is two files: a NixOS half that adds a `plugdev` group
and `hardware.keyboard.qmk.enable`
([nixos qmk#L1-L25](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/modules/nixos/core/mySystem/programs/qmk/default.nix#L1-L25))
and a home-manager half that writes `qmk.ini` and installs the package
([homeManager qmk#L1-L32](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/modules/homeManager/core/myHome/programs/qmk/default.nix#L1-L32)).
Across all 230 `.nix` files, only six mention both classes, and four of those
are host entry points. The other two are plumbing:
`modules/flake/exposed/nixosConfigurations.nix` and
[hm-integration.nix](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/modules/nixos/hm-integration.nix#L1-L18).
Zero feature modules span classes.

The workaround is a third namespace. Shared logic goes into
`flake.modules.generic.<name>` and is pulled in by two one-line adapter files,
one per class
([generic assertions#L1-L43](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/modules/generic/assertions/assertions.nix#L1-L43),
[nixos adapter#L1-L7](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/modules/nixos/core/assertions.nix#L1-L7),
[homeManager adapter#L1-L7](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/modules/homeManager/core/assertions.nix#L1-L7)).
Cross-class coupling that cannot be shared goes through `osConfig` at
evaluation time, using two helpers, `myLib.isNixos` and `myLib.systemEnabled`
([lib/default.nix#L1-L21](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/lib/default.nix#L1-L21)).
The QMK home module uses them to emit a warning when the user enables the home
half on NixOS without the system half
([homeManager qmk#L19-L25](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/modules/homeManager/core/myHome/programs/qmk/default.nix#L19-L25)).
That warning exists because the two halves can drift.

Second, the repository uses `mkEnableOption` 70 times. The dendritic README
calls `enable` options an anti-pattern and says importing a module should
enable the feature
([dendritic README#L215-L220](https://github.com/mightyiam/dendritic/blob/6c76240658cf1c840faad557c0e0726064170a65/README.md#L215-L220)).
Merging everything into `core` forces this: because a single merged module is
imported into every host, per-host selection has to be a boolean somewhere. The
two deviations are the same tradeoff seen twice.

### How hosts are declared and selected

Hosts are option values, not files in a magic directory. `homeHosts` and
`nixosHosts` are `attrsOf` a submodule sharing a common base
([homeHosts.nix#L11-L33](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/flake/internal/homeHosts.nix#L11-L33),
[nixosHosts.nix#L15-L38](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/flake/internal/nixosHosts.nix#L15-L38)).
The base carries `system`, `primaryUser`, `specialArgs`, a typed `hardware`
submodule (CPU vendor, GPU driver, sound, UEFI, and a list of monitors with
geometry, wallpaper, and workspace assignments), a `finalPackage`, and a
`ghMatrix` block
([_utils/default.nix#L9-L133](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/flake/internal/_utils/default.nix#L9-L133)).

A host declaration is data plus a module. The desktop declares its hardware and
then imports role modules by name
([budimanjojo-main/default.nix#L1-L58](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/nixosHosts/budimanjojo-main/default.nix#L1-L58)).

Module selection is by name convention with a silent fallback:

```nix
imports = [
  self.modules.homeManager.core
  (self.modules.homeManager.${options.primaryUser} or { })
  (self.modules.homeManager."${options.primaryUser}@${hostname}" or { })
];
```

([homeConfigurations.nix#L13-L38](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/flake/exposed/homeConfigurations.nix#L13-L38)).
The `or { }` means a typo in a host module name produces no error, only a
missing configuration. The same file carries a TODO noting that multi-user
hosts are not supported yet.

`finalPackage` defaults to the home activation package for home hosts and to
`config.system.build.toplevel` for NixOS hosts
([homeHosts.nix#L20](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/flake/internal/homeHosts.nix#L20),
[nixosHosts.nix#L25](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/flake/internal/nixosHosts.nix#L25)).
That one option is the seam that feeds both `checks` and the CI matrix.

### Where identity lives

On the Nix side, identity is the host submodule plus the flake attribute name.
There are no prompts and no runtime detection. Bootstrap is: add a file
declaring `homeHosts.<hostname>`, `git add .`, then
`home-manager switch --flake .#<username>@<hostname>`
([README#L67-L97](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/README.md#L67-L97)).

Chezmoi keeps a second, independent identity model. Its config template hard
codes per-hostname values for two booleans, `headless` and `agekey`, and falls
back to `promptBool` when running interactively
([.chezmoi.yaml.tmpl#L1-L34](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/chezmoi/.chezmoi.yaml.tmpl#L1-L34)).
Nothing derives those from the Nix host table, and nothing checks that they
agree.

### NixOS versus non-NixOS

NixOS hosts get home-manager as a NixOS module through a dedicated
`hm-integration` module with `useGlobalPkgs`, `useUserPackages`, and
`sharedModules = [ self.modules.homeManager.core ]`
([hm-integration.nix#L1-L18](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/modules/nixos/hm-integration.nix#L1-L18)).
The Ubuntu host uses standalone `homeManagerConfiguration` instead, plus
`targets.genericLinux.enable` and nixGL wrapping for OpenGL applications
([budimanjojo-ubuntu#L27-L31](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/homeHosts/budimanjojo-ubuntu/default.nix#L27-L31)).
The same `core` module serves both, and modules branch on `osConfig` where the
two differ. Fontconfig is the clean example: it enables
`fonts.fontconfig` and installs fonts only when not on NixOS
([fontconfig#L1-L19](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/modules/homeManager/core/myHome/programs/fontconfig/default.nix#L1-L19)).

## 3. The Hybrid

### The ordering: Nix on top, chezmoi underneath

Chezmoi is a home-manager module. It is enabled on exactly one host
([budimanjojo-ubuntu#L9](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/homeHosts/budimanjojo-ubuntu/default.nix#L9)),
and its entire implementation is one activation block:

```nix
home.activation.chezmoi = lib.hm.dag.entryAfter [ "installPackages" ] ''
  _saved_path=$PATH
  PATH="${config.home.path}/bin:$PATH"
  PATH=$PATH:/usr/local/bin:/usr/bin:/bin

  run ${pkgs.chezmoi}/bin/chezmoi apply -S ${self} $VERBOSE_ARG

  PATH=$_saved_path
'';
```

([chezmoi/default.nix#L18-L32](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/modules/homeManager/core/myHome/programs/chezmoi/default.nix#L18-L32)).

Three consequences follow from `-S ${self}`. The chezmoi source is the flake's
store path, so it is immutable and content-addressed at switch time. There is
no `chezmoi apply` in the user's workflow; the only entry point is
`home-manager switch`. And chezmoi's own scripts run inside the activation DAG,
after `installPackages`, so the Nix-installed binaries the scripts depend on
already exist. The `.chezmoiroot` file redirects the source root to `chezmoi/`
inside the flake
([.chezmoiroot](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/.chezmoiroot#L1)).

### Why the author split it this way

> For NixOS machines, everything is managed by NixOS modules and
> `home-manager`. As for non NixOS machines, I use combination of
> `home-manager` and `chezmoi`. I use `chezmoi` mainly to configure the system
> using chezmoi scripts while `home-manager` to configure applications in the
> userspace.

([README#L24-L26](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/README.md#L24-L26)).

The split is by privilege and by ownership of the base OS, not by file type.
Chezmoi is the "things Nix cannot own on a foreign distro" lane.

### What chezmoi actually owns

Five scripts and two files. That is the whole surface.

| Path | Kind | What it does |
| --- | --- | --- |
| `run_once_before_10-setup-fish.sh.tmpl` | script | Adds `~/.nix-profile/bin/fish` to `/etc/shells` with `sudo tee`, then `chsh` |
| `run_once_before_20-install-packages-archlinux.sh.tmpl` | script | `pacman -Syu` plus a package list, gated on `.chezmoi.osRelease.id == "arch"` |
| `run_once_before_20-install-packages-ubuntu.sh.tmpl` | script | PPAs, apt packages, snaps, gated on debian/ubuntu |
| `run_onchange_after_80-setup-terminal.sh.tmpl` | script | Registers Nix-installed terminals with `update-alternatives` |
| `run_once_after_90-cleanup.sh.tmpl` | script | Deletes stale binaries under `/usr/local/bin` and uninstalls Homebrew |
| `dot_config/fontconfig/fonts.conf.tmpl` | file | Font aliases and hinting, gated to one hostname |
| `dot_config/termite/config` | file | Termite terminal settings |

The fish script exists because home-manager can install fish but cannot change
the login shell on a foreign distro. The README says so directly
([README#L106-L108](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/README.md#L106-L108)),
and the script does the `/etc/shells` and `chsh` work
([setup-fish#L7-L29](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/chezmoi/.chezmoiscripts/run_once_before_10-setup-fish.sh.tmpl#L7-L29)).
The package scripts branch on `.chezmoi.osRelease.id`, which is a runtime fact
Nix does not observe
([archlinux#L1-L29](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/chezmoi/.chezmoiscripts/run_once_before_20-install-packages-archlinux.sh.tmpl#L1-L29),
[ubuntu#L1-L20](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/chezmoi/.chezmoiscripts/run_once_before_20-install-packages-ubuntu.sh.tmpl#L1-L20)).
The terminal script registers Nix profile binaries with Debian's
`update-alternatives` so the desktop can open them
([setup-terminal#L1-L27](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/chezmoi/.chezmoiscripts/run_onchange_after_80-setup-terminal.sh.tmpl#L1-L27)).
The cleanup script removes past mistakes, including Homebrew
([cleanup#L1-L29](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/chezmoi/.chezmoiscripts/run_once_after_90-cleanup.sh.tmpl#L1-L29)).

One trigger deserves a callout. The terminal script reruns when a Nix file
changes, using chezmoi's `include`-and-hash idiom pointed at the host module:

```sh
# {{ include (print "../" "/modules/homeHosts/" .chezmoi.hostname "/default.nix") | sha256sum }}
```

([setup-terminal#L11-L12](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/chezmoi/.chezmoiscripts/run_onchange_after_80-setup-terminal.sh.tmpl#L11-L12)).
A chezmoi template reaches across `.chezmoiroot` into the Nix tree to decide
whether to rerun. Nothing type-checks that path, and the `print "../" "/..."`
construction is fragile enough that the only chezmoi commit since October 2024
was titled "fix(chezmoi): path changed".

### How the two avoid fighting

By having almost nothing to fight over. The leaf paths are disjoint, verified
by grep: no Nix module in the repository manages
`~/.config/fontconfig/fonts.conf` or `~/.config/termite/config`, and termite
appears in the Nix tree only as a `$TERM` comparison inside a fish function.
Home-manager's fontconfig module enables `fonts.fontconfig`, which writes into
`conf.d/`, so the two live in the same directory but never the same file
([fontconfig#L11-L17](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/modules/homeManager/core/myHome/programs/fontconfig/default.nix#L11-L17)).

There is no lock, no negotiation, and no check. The separation is a convention
the author holds in his head. Two signs of erosion are already visible.
`fonts.conf.tmpl` is guarded to hostname `budimanjojo-main`
([fonts.conf.tmpl#L1](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/chezmoi/dot_config/fontconfig/fonts.conf.tmpl#L1)),
which is a NixOS host that does not enable the chezmoi module, so on the only
machine that runs chezmoi the file renders empty. And `.chezmoiignore` gates
alacritty, kitty, termite, and wezterm config directories on `headless`
([.chezmoiignore#L1-L6](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/chezmoi/.chezmoiignore#L1-L6)),
but three of those four directories no longer exist in the chezmoi source, and
alacritty is now a home-manager module.

The direction of travel is clear from history. The `chezmoi/` directory has
roughly eleven commits in the repository's whole life. Nine of the ten most
recent are from 2024, with titles like "use `home-manager` to setup fonts" and
"use nixgl to run GUI application on non NixOS systems", and the single commit
since is the 2026-07 path fix. Chezmoi here is a shrinking residue, not a
co-equal half. This paragraph rests on the GitHub commits API for
`path=chezmoi` and is not permalinkable.

## 4. Per-App Config Mechanics

The hierarchy is strict and worth stating as counts across all 230 `.nix`
files:

| Mechanism | Uses | Notes |
| --- | ---: | --- |
| `programs.*` home-manager modules | many | The default. Alacritty, fish, tmux, git, nixvim, and so on |
| `xdg.configFile."<path>".source` | 7 | Always `./file` or `./dir` from the module's own directory |
| `home.file` | 0 | Never used |
| `home.activation` | 1 | The chezmoi block |
| `mkOutOfStoreSymlink` | 0 | No live links into a mutable checkout |
| `onChange` | 0 | No content-triggered hooks |
| `force = true` | 0 | Never overrides an existing target |
| `backupFileExtension` | 0 | No backup escape hatch configured |
| `system.activationScripts` | 0 | No NixOS activation scripts |

The `xdg.configFile` sites are all whole-file or whole-directory sources, for
example `xdg.configFile."qmk/qmk.ini".source = ./qmk.ini`
([homeManager qmk#L28](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/modules/homeManager/core/myHome/programs/qmk/default.nix#L28))
and `xdg.configFile."contour".source = ./config`
([contour#L19](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/modules/homeManager/core/myHome/terminal-emulator/contour/default.nix#L19)).

### App-rewritten files

None. The repository manages no file that its owning application also writes.
There is no merge step, no read-modify-write, no `onChange` reconcile, and no
partial ownership of a mutable config. This is a complete absence of our
Problem A, in a 230-file configuration.

The one thing resembling generated-and-committed state is the Catppuccin
palette, which is fetched, sanitized, and written into `catppuccin-palette.nix`
by a just recipe, explicitly as a workaround for an import-from-derivation issue
upstream
([.justfile#L35-L42](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/.justfile#L35-L42)).
That is codegen into the repository, not into `$HOME`.

### Secrets

sops-nix on both classes. One creation rule matches any `*.secret.sops.yaml`
and encrypts to six age recipients
([.sops.yaml#L1-L11](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/.sops.yaml#L1-L11)).
Thirteen encrypted secret files are committed. The home-manager side points the
age key at `~/.config/sops/age/keys.txt` and sets `generateKey = true`
([sops.nix#L21-L24](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/modules/homeManager/core/sops.nix#L21-L24)).
Secrets are placed at real target paths rather than a runtime directory:
`sops.secrets.kubeconfig.path` is `~/.kube/config` and
`sops.secrets.talosconfig.path` is `~/.talos/config`
([kubernetes#L26-L35](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/modules/homeManager/core/myHome/homelab/kubernetes/default.nix#L26-L35)).

Chezmoi keeps a second, parallel secrets mechanism: `encryption: age` with an
age identity path and recipient written into the generated config
([.chezmoi.yaml.tmpl#L36-L41](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/chezmoi/.chezmoi.yaml.tmpl#L36-L41)).
No encrypted chezmoi files exist in the snapshot, so this is configured but
unused.

Separately, the NixOS user module commits a password hash directly in Nix
source with `mutableUsers = false`
([users.nix#L1-L18](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/modules/nixos/core/users.nix#L1-L18)).
The hash is public in the repository; the value is not reproduced here.

### What runs as root per switch

On NixOS, the whole switch: `sudo nixos-rebuild switch --flake .#<hostname>`
([README#L81](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/README.md#L81),
[.justfile#L44-L47](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/.justfile#L44-L47)).

On the Ubuntu host, the switch itself is unprivileged, but the chezmoi scripts
it invokes are not. They run `sudo pacman`, `sudo add-apt-repository`,
`sudo tee -a /etc/shells`, `sudo update-alternatives`, and `sudo rm` under
`/usr/local/bin`. A `home-manager switch` on that machine can therefore stop
mid-activation waiting for a password. Every script sets
`set -eufo pipefail`, so a failed package install aborts the generation.

## 5. Testing And CI

There is no test suite. No unit tests, no golden files, no shell test harness,
no linting workflow. Validation is entirely "does it build", plus two runtime
assertions about monitor configuration
([generic assertions#L6-L41](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/modules/generic/assertions/assertions.nix#L6-L41))
and the QMK cross-class warning.

The checks wiring is the interesting part, and it is short enough to quote in
full effect. `flake.checks` is built per system by filtering the host table,
mapping each home host to `"<name>-check"`, and adding a nixvim check:

```nix
lib.mapAttrs' (name: cfg: lib.nameValuePair "${name}-check" cfg.finalPackage) hostForSystem
```

with the comment

```text
# we skip nixosHosts because it's already being checked by default
# TODO: find a way to mimic nixosConfigurations where it only evaluate instead of building
# the entire package because we want to make CI run to be more efficient
```

([checks.nix#L1-L35](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/flake/exposed/perSystem/checks.nix#L1-L35)).

That comment is independent confirmation of two claims in our target-state
doc: `nix flake check` covers `nixosConfigurations` on its own but not
`homeConfigurations`, and closing that gap means exposing each home
configuration's activation package as an explicit check. The TODO also names
the cost we predicted: the check builds the closure rather than merely
evaluating it.

CI workflows are themselves Nix. Nine module files under
`modules/flake/exposed/perSystem/github-actions/` define six workflows, which
`just render-workflows` builds and copies into `.github/workflows`
([.justfile#L92-L97](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/.justfile#L92-L97)).
A scheduled hourly workflow re-renders and opens a pull request when the
committed YAML drifts from the Nix source
([render-workflows.nix#L1-L40](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/flake/exposed/perSystem/github-actions/render-workflows.nix#L1-L40)).

| Workflow | Trigger | What it does |
| --- | --- | --- |
| check-flakes | push touching `**.nix` or `flake.lock`, and PR open | `nix flake check --print-build-logs --no-update-lock-file` on a per-system runner matrix ([check-flakes.nix#L1-L36](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/flake/exposed/perSystem/github-actions/check-flakes.nix#L1-L36)) |
| build-push-cache | push touching `modules/`, `packages/`, `overlays/`, or the flake | Per-host matrix; restores a `.#gc-keep` store cache, then `nix-fast-build --cachix budimanjojo --skip-cached` ([build-push-cache.nix#L1-L80](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/flake/exposed/perSystem/github-actions/build-push-cache.nix#L1-L80)) |
| render-workflows | hourly and on `**/github-actions/**.nix` | Re-renders workflow YAML and opens a PR |
| renovate, update-nvfetcher, update-sops-keys | scheduled | Dependency, package source, and sops recipient maintenance |

The per-host matrix comes from the same `ghMatrix.installable` option that
`finalPackage` sits beside, so "what CI builds" and "what `nix flake check`
checks" are derived from one host table
([matrix.nix#L22-L48](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/flake/exposed/perSystem/github-actions/matrix.nix#L22-L48)).

Renovate carries one idea worth stealing. The GitHub Actions manager is
disabled in favor of a regex custom manager over `dependencies.nix`, and a
second custom manager watches version pins inside chezmoi shell scripts,
driven by comment markers
([renovate.json#L19-L51](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/.github/renovate.json#L19-L51)).
There is one live use, a wezterm release pin
([ubuntu script#L45](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/chezmoi/.chezmoiscripts/run_once_before_20-install-packages-ubuntu.sh.tmpl#L45)).

Nothing in CI touches chezmoi. There is no shellcheck run, no `chezmoi execute-template`
smoke test, and no dry-run apply. The chezmoi half of the hybrid is entirely
unvalidated.

## 6. Compare And Contrast With Our Target-State Doc

### App modules plus roles, versus dendritic

Our doc's native composition model has each app module export both its
nix-darwin and its home-manager fragment, with roles selecting app modules.
That is the dendritic ideal stated in our own vocabulary. This repository
advertises dendritic and does not achieve it: zero of its feature modules span
configuration classes, and its cross-class needs are met by a third `generic`
namespace plus per-class adapter files, or by reading `osConfig` at evaluation
time.

The lesson is not that the model is wrong. It is that the discipline does not
hold by itself, and the pattern gives you no enforcement. The QMK warning
([homeManager qmk#L19-L25](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/modules/homeManager/core/myHome/programs/qmk/default.nix#L19-L25))
is a hand-written runtime substitute for the invariant the one-file-per-feature
shape would have given for free. If we adopt app modules that export two
fragments, we should expect to need a check that both fragments are actually
wired, because this repository needed one and wrote it by hand for a single
feature.

The mechanically useful piece is smaller and separable from dendritic:
merging every feature into one module name (`core`) so that adding a feature
requires no import-list edit. That works in plain flake-parts. `import-tree` is
convenience on top; it also means a misplaced file is silently loaded and a
misnamed host module is silently ignored.

### Against the "what disappears" table

Four rows of our table did not disappear here, and the reasons are informative
rather than incidental.

| Our row | Our target | What this repo did |
| --- | --- | --- |
| `.chezmoi.toml.tmpl` becomes `hosts/<host>.nix`, no prompts | Identity is the flake attribute | Half true. Flake identity is the attribute, but chezmoi kept its own config template with two `promptBool` calls and hostname special cases ([.chezmoi.yaml.tmpl#L8-L26](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/chezmoi/.chezmoi.yaml.tmpl#L8-L26)) |
| `.chezmoiignore` becomes `lib.mkIf` on options | Gates collapse into modules | Retained as a five-line ignore file gating terminal configs on `headless` ([.chezmoiignore#L1-L6](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/chezmoi/.chezmoiignore#L1-L6)) |
| `.chezmoiscripts/` split into derivations and activation | Pure builds become derivations | Retained wholesale as the OS package-manager and system-config lane |
| `.tmpl` Go templates become Nix interpolation | Host facts are evaluation inputs | Retained where the fact is a runtime property of a foreign distro, `.chezmoi.osRelease.id` |

The pattern: chezmoi survived exactly where the fact is discovered at apply
time on a machine Nix does not own. Our repository is macOS-only with Homebrew
under our control, so this argues weakly for us. Our closest analogue is not
distro detection but MDM state and Jamf policy, which is also an apply-time
runtime fact.

### Against the per-app ownership table

No evidence. This repository does not manage a single file that its owning
application also writes, so it says nothing about Claude, Codex, Cursor, pi,
Orca, agentsview, crit, Yojam, or obsidian-wiki. The six apps our table expects
to keep a merger remain unaddressed.

The absence itself is worth recording. A 230-file, 289-star configuration by an
author fluent enough in Nix to generate his CI from it contains zero merge
targets. Our 22 are not a normal thing that Nix repositories have solved
quietly; they are a property of the agent-tooling surface we happen to run.

### Problems A, B, and C

**Problem A, files the app also writes.** Zero instances. No `onChange`, no
`force`, no `mkOutOfStoreSymlink`, no merge activation. This repository is not
a source of solutions here, and its silence is mild evidence that the escape
hatches we would need are not well-trodden.

**Problem B, the MDM-managed work Mac.** No darwin, no MDM, no root-activation
question in our form. There is an inverted version worth noting. Our fear is
that nix-darwin makes the whole switch root, and that MDM will not allow it.
Their arrangement makes the switch unprivileged and then shells out to `sudo`
from inside activation for the system layer. Both shapes end in the same place:
the system layer needs elevation, and the only question is whether elevation
happens once at the top or repeatedly in the middle. Their answer is worse for
unattended runs, since an activation that blocks on a password prompt is harder
to automate than one that is root from the start.

**Problem C, secrets without store leakage.** This is the sops-nix option our
doc listed and set aside on public-repository grounds, running in production.
It works. The costs are exactly the ones we named and one we did not. Named:
thirteen encrypted files and six public age recipients are committed. Not
named: `generateKey = true` means the age key is created on first switch rather
than provisioned, so a fresh machine generates a key that is not yet a
recipient and cannot decrypt anything until the key is added and
`just update-sops-keys` is run
([.justfile#L29-L33](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/.justfile#L29-L33),
[update-sops-keys workflow](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/flake/exposed/perSystem/github-actions/update-sops-keys.nix#L1-L20)).
That bootstrap gap is the sops-nix equivalent of our 1Password sign-in
dependency, and it argues that "no interactive dependency" is not actually one
of sops-nix's advantages over `op read`.

### Against our test surface section

This is the strongest transferable result. Our doc argues that
`nix flake check` does not touch `homeConfigurations` and that each one must be
exposed explicitly as
`checks.<system>.<user> = self.homeConfigurations.<user>.activationPackage`.
This repository implements precisely that, generically, in 35 lines, and its
inline comment states the asymmetry as settled fact
([checks.nix#L28-L33](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/flake/exposed/perSystem/checks.nix#L28-L33)).
It also demonstrates the refinement we should copy: derive the checks from the
host table rather than writing one line per host, and put the buildable
attribute on the host option (`finalPackage`) so the CI matrix and the check
set cannot disagree.

The TODO in that comment is our warning. Building an activation package per
host per push is expensive, which is why the repository also runs a Cachix
push and `nix-fast-build --skip-cached`. If we expose four or five darwin hosts
as checks, we should plan for a binary cache at the same time, not after.

### The prior doc's hybrid Options 2 and 3

Both of our hybrid options keep chezmoi on top. Option 2 has chezmoi install a
`nix profile` closure; Option 3 has chezmoi drive a standalone home-manager for
`home.packages`. In both, `chezmoi apply` remains the command a human runs.

This repository is the mirror image, and the ordering matters more than the
fact of the hybrid. Under Nix-on-top:

- `chezmoi apply` stops being a user command. There is no drift preview, no
  `chezmoi diff`, no `chezmoi status`. The only preview is
  `home-manager build` and a closure diff, which is exactly the loss our
  concept-map row 38 predicts. This repository accepted that loss.
- The chezmoi source becomes a store path. `chezmoi edit`, `chezmoi add`, and
  the `git.autoAdd: true` setting in their config
  ([.chezmoi.yaml.tmpl#L49-L50](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/chezmoi/.chezmoi.yaml.tmpl#L49-L50))
  no longer round-trip against a writable checkout. Whether chezmoi warns or
  fails when asked to `add` against a read-only source is unverified.
- Chezmoi's persistent state directory survives, so `run_once_` bookkeeping
  still works across generations. That is the one capability chezmoi
  contributes that home-manager genuinely lacks, and it is our concept-map row
  20. If we ever want once-per-machine semantics under Nix, this is the
  existence proof that a subordinate chezmoi provides them.
- Chezmoi failures become switch failures. Their scripts run under
  `set -eufo pipefail` inside activation, so a transient apt failure fails the
  home-manager generation.

For us the conclusion is that chezmoi-on-top is the better ordering if we do a
hybrid at all, because the two things chezmoi-on-top preserves, the merged-result
preview and the plist and JSON merge engine, are precisely the two capabilities
our doc identifies as having no Nix equivalent. Nix-on-top trades both away to
gain a once-ledger we could also get from a stamp file. The one case where the
trade could be right is a machine where the system layer is not ours, which is
their Ubuntu case and not any of our Macs.

### Open questions answered or reframed

None of the sixteen are answered. Fifteen are macOS-specific or app-specific and
this repository has no macOS surface. Question 4, whether the DevPod image can
carry Nix, is weakly reframed: standalone home-manager on Ubuntu with
`targets.genericLinux` and nixGL is demonstrated working here
([budimanjojo-ubuntu#L27-L31](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/homeHosts/budimanjojo-ubuntu/default.nix#L27-L31)),
but the README's install instruction is one line ("Install Nix and enable
Flake",
[README#L85](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/README.md#L85))
and says nothing about the `--init none` constraint that actually blocks us.

The repository raises one question our list does not have: under Nix-on-top,
what happens to chezmoi's authoring commands when the source is immutable? It
is a real question for any hybrid we might build in that order, and this
repository does not answer it either.

## 7. What To Take, What To Avoid

### Take

1. **The checks derivation.** Build `flake.checks` from the host table, filter
   by system, map each home host to its activation package, and skip NixOS
   hosts because they are already covered
   ([checks.nix#L12-L34](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/flake/exposed/perSystem/checks.nix#L12-L34)).
   This is directly portable to `darwinConfigurations` and closes the gap our
   doc identifies, without one hand-written line per host.
2. **`finalPackage` on the host option.** One typed field that names the thing
   to build makes the check set and the CI matrix provably consistent
   ([_utils/default.nix#L114-L131](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/flake/internal/_utils/default.nix#L114-L131)).
   Our `machines.toml` resolver already holds the equivalent data; this is the
   shape it would take as options.
3. **Merge every feature into one module name.** It removes import-list churn
   entirely and is independent of whether we adopt dendritic
   ([dendritic README#L193-L203](https://github.com/mightyiam/dendritic/blob/6c76240658cf1c840faad557c0e0726064170a65/README.md#L193-L203)).
4. **Renovate over version pins in shell scripts.** The
   `# renovate: depName=... datasource=...` custom manager
   ([renovate.json#L19-L26](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/.github/renovate.json#L19-L26))
   works on our chezmoi scripts today and is worth doing regardless of any Nix
   decision.
5. **Generate CI from the config, and PR the drift.** An hourly job that
   re-renders workflows and opens a pull request when the committed YAML
   diverges is a cheap way to keep generated artifacts honest
   ([render-workflows.nix#L1-L40](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/modules/flake/exposed/perSystem/github-actions/render-workflows.nix#L1-L40)).

### Avoid

1. **Cross-tool triggers with no checker.** A chezmoi template that hashes a
   Nix file to decide whether to rerun
   ([setup-terminal#L11-L12](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/chezmoi/.chezmoiscripts/run_onchange_after_80-setup-terminal.sh.tmpl#L11-L12))
   is a coupling that no tool validates and that broke once already.
2. **`sudo` inside an unprivileged activation.** It turns `home-manager switch`
   into an interactive command and makes unattended runs unreliable.
3. **Treating `generateKey = true` as provisioning.** A generated key that is
   not yet a recipient decrypts nothing.
4. **Splitting features per configuration class if we adopt dendritic.** That
   split discards the pattern's main benefit and forces hand-written warnings
   to catch the drift it creates.
5. **Config that no host can reach.** A chezmoi file gated to a hostname that
   does not run chezmoi
   ([fonts.conf.tmpl#L1](https://github.com/budimanjojo/nix-config/blob/205501230750abc63d35cbe906ee855902b9911f/chezmoi/dot_config/fontconfig/fonts.conf.tmpl#L1))
   and ignore rules for directories that no longer exist are the exact drift
   our `code-gardening` habit exists to prevent. Nothing here catches it because
   nothing tests the chezmoi half.

### Relevance: 3 out of 5

Three, and the number hides a wide spread.

High value on two axes. It is the only live chezmoi-and-Nix hybrid with a
documented rationale, and its ordering (Nix on top) is the one we had not
considered, which sharpens the case for our own ordering rather than weakening
it. Its `checks` implementation is a direct, copyable answer to the concrete
gap our test-surface section names, and the `finalPackage` and `ghMatrix`
pattern is a better version of what we would otherwise hand-roll.

Low value on almost everything else. No macOS, no nix-darwin, no Homebrew, no
plists, no MDM, no merge targets, and no tests. Problems A and B get no
evidence at all, and Problem C gets confirmation of a tradeoff rather than a
resolution. The dendritic angle is instructive mostly as a negative result:
the repository that advertises the pattern is the one that demonstrates how
hard it is to hold.

Its hybrid is also smaller than its reputation suggests. Two managed files, one
of which renders empty, and five scripts that exist because the base OS is not
Nix. That is not a model for a macOS repository with 22 merge targets.

## 8. Scorecard Against Our Concept Map

Rows from Appendix A of [the target-state doc](../nix-target-state-research.md).
Only rows where this repository provides actual evidence are listed. Notes are
five words.

| Row | Verdict | Note |
| ---: | --- | --- |
| 1 | Alternative | Uses xdg.configFile, never home.file |
| 5 | Alternative | Kept Go templates for distro |
| 6 | Supports | Flake attribute is user@host |
| 8 | Supports | Typed submodule with mkDefault |
| 9 | Alternative | System package manager stayed shell |
| 10 | Supports | home.packages throughout, lock pinned |
| 13 | Alternative | Script uninstalls Homebrew, not installs |
| 16 | Alternative | Chezmoiignore retained beside Nix options |
| 19 | Alternative | Chezmoi onchange hash, not onChange |
| 20 | Supports | Chezmoi retained for once semantics |
| 21 | Supports | entryAfter installPackages orders the hook |
| 22 | Supports | Store interpolation replaces prerequisite hook |
| 24 | Supports | Zero merge targets exist here |
| 27 | Alternative | Scripts call sudo during activation |
| 34 | Alternative | nvfetcher daily instead of mise |
| 37 | Alternative | sops-nix works, commits encrypted files |
| 38 | Supports | No per-file drift preview |
| 40 | Supports | No backupFileExtension, no force |
| 41 | Supports | Standalone home-manager on Ubuntu works |
| 42 | Supports | Per-host matrix builds on runners |
