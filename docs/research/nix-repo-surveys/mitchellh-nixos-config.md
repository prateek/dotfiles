---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-04
updated: 2026-09-04
related:
  - ../nix-target-state-research.md
  - ../nix-migration-research.md
status_detail: "Agent survey of mitchellh/nixos-config at 14467f8b, compared with the Nix target-state doc. Unreviewed."
---

# Survey: mitchellh/nixos-config

## Method

Read on 2026-09-04 against a pinned tarball of
[mitchellh/nixos-config](https://github.com/mitchellh/nixos-config) at commit
`14467f8b4fa7feda221d429b189e6276a399e054`, fetched with
`gh api repos/mitchellh/nixos-config/tarball/<sha>`. Permalinks below all
resolve at that sha.

Everything in the repository was read except `flake.lock`, the LICENSE, and
the screenshot: the README, `flake.nix`, the `Makefile`, all 17 `.nix` files,
`.gitignore`, and `.gitattributes`. `flake.lock` was inspected
programmatically for input names and `lastModified` timestamps only. Commit
history and repository metadata came from the GitHub API on the same day.
Absence claims ("manages no macOS defaults") were checked with `grep` across
all `.nix` files and the `Makefile`.

Compared against [the Nix target-state doc](../nix-target-state-research.md),
[the prior migration doc](../nix-migration-research.md), and
[the chezmoi architecture reference](../../references/chezmoi-architecture.md).

Two facts in the task brief needed correcting against the source. The repo
does have a nix-darwin Homebrew module with 15 casks; only the README says it
does not. And the `.gitattributes` declares a git-crypt filter for a
`secret/**` path that is not present in the tree.

## 1. What It Is

| Fact | Value | Source |
| --- | --- | --- |
| Author | Mitchell Hashimoto, HashiCorp co-founder, Ghostty author | README |
| Created | 2020-05-05 | GitHub API |
| Stars | 3,090 | GitHub API, 2026-09-04 |
| License | MIT, not archived | GitHub API |
| `.nix` files | 17 | `find` |
| Total lines, all text files | about 3,250 excluding the screenshot | `wc -l` |
| Flake outputs | 3 `nixosConfigurations`, 1 `darwinConfiguration` | [flake.nix#L89-L109](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/flake.nix#L89-L109) |
| Users | 1 (`mitchellh`) | [flake.nix#L89-L109](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/flake.nix#L89-L109) |
| Commits, last 12 months | 27 | GitHub API |
| CI | none; `.github/` holds one image | GitHub API returns 404 for `.github/workflows` |
| Renovate or Dependabot | none | directory listing |

It is a daily driver, not a starter kit, and the README opens by saying so:
it "isn't meant to be a turnkey solution to copying my setup or learning
Nix," and the author states he values "having my config work over having it
be optimal"
([README#L1-L12](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/README.md#L1-L12)).
The Darwin section carries a second warning: "Don't do this without reading
the source"
([README#L175-L177](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/README.md#L175-L177)).

The central workflow is macOS as host operating system with NixOS in a VM as
the primary development environment. Graphical applications, browser, mail,
calendar, and iMessage live on the host; editors, compilers, and databases
live in the VM
([README#L14-L27](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/README.md#L14-L27)).
He has run this since late 2020
([README#L59-L63](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/README.md#L59-L63)).

Activity is bursty and manual. The last three commits all landed on
2026-09-04 with the messages "update stuff", "update jj", and "update
neovim"; the previous cluster was 2026-06-18. There is no automated lock
bump. The lock is bumped by hand, in batches, and the commit message names
the input that motivated the bump. Nothing pins the bump to a schedule.

The flake tracks release channels rather than unstable for the three inputs
that define the system: `nixpkgs` at `nixos-26.05`, `home-manager` at
`release-26.05`, and `nix-darwin` at `nix-darwin-26.05`, with the latter two
following nixpkgs
([flake.nix#L8](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/flake.nix#L8),
[#L28-L36](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/flake.nix#L28-L36)).
A separate `nixpkgs-unstable` input feeds a small overlay for four packages
that need to be newer: `gh`, `claude-code`, `nushell`, and one `ibus` variant
([flake.nix#L64-L82](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/flake.nix#L64-L82)).
This is the "stable base, per-package unstable escape hatch" pattern, applied
sparingly and with a stated reason per package.

## 2. Composition

There is one composition primitive, and it is 97 lines long.
[`lib/mksystem.nix`](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/lib/mksystem.nix)
takes a host name and an attribute set of four values, `system`, `user`, and
the booleans `darwin` and `wsl`
([#L3-L11](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/lib/mksystem.nix#L3-L11)).
From those it derives three file paths by convention:

```text
machineConfig = ../machines/${name}.nix
userOSConfig  = ../users/${user}/${if darwin then "darwin" else "nixos"}.nix
userHMConfig  = ../users/${user}/home-manager.nix
```

([#L20-L23](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/lib/mksystem.nix#L20-L23)).
It then selects `darwinSystem` or `nixosSystem` and the matching home-manager
module set from the same `darwin` boolean
([#L26-L27](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/lib/mksystem.nix#L26-L27)),
and assembles a module list: overlays, `allowUnfree`, platform-conditional
inputs, the three convention paths, and home-manager as a submodule with
`useGlobalPkgs` and `useUserPackages`
([#L33-L83](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/lib/mksystem.nix#L33-L83)).

Machine identity is passed down as five module arguments rather than looked
up: `currentSystem`, `currentSystemName`, `currentSystemUser`, `isWSL`, and
`inputs`
([#L85-L95](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/lib/mksystem.nix#L85-L95)).
Downstream modules read them directly. `vm-shared.nix` uses
`currentSystemName` to add one VMware-only package
([machines/vm-shared.nix#L107-L112](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/machines/vm-shared.nix#L107-L112)),
and `wsl.nix` uses `currentSystemUser` for `defaultUser`
([machines/wsl.nix#L1-L9](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/machines/wsl.nix#L1-L9)).

There are no roles. There is no work versus personal axis and no machine-type
value anywhere in the repo. The only variation axes are the four booleans in
`mkSystem` and, inside the shared home-manager file, `pkgs.stdenv.isDarwin`
and `isLinux` derived at the top
([users/mitchellh/home-manager.nix#L5-L8](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L5-L8)).
Platform variation is expressed as `lib.optionals` blocks and
`if isDarwin then {...} else {}` merges inline
([#L85-L97](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L85-L97),
[#L117-L136](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L117-L136)).

The `modules/` directory holds exactly three files, all NixOS desktop
environment specialisations: i3, KDE Plasma, and GNOME with ibus
([modules/specialization/i3.nix#L1-L41](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/modules/specialization/i3.nix#L1-L41),
[plasma.nix#L1-L9](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/modules/specialization/plasma.nix#L1-L9),
[gnome-ibus.nix#L1-L19](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/modules/specialization/gnome-ibus.nix#L1-L19)).
`vm-shared.nix` imports all three and then guards its own default desktop
with `lib.mkIf (config.specialisation != {})`
([machines/vm-shared.nix#L4-L8](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/machines/vm-shared.nix#L4-L8),
[#L115-L124](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/machines/vm-shared.nix#L115-L124)).
This is a NixOS-only mechanism: variants build alongside the main system and
are selected at boot. There is no Darwin equivalent.

Hardware is a fourth layer, under `machines/hardware/`, carrying the
`nixos-generate-config` output verbatim including its "do not modify" banner
([machines/hardware/vm-aarch64.nix#L1-L26](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/machines/hardware/vm-aarch64.nix#L1-L26)).

The Mac and the Linux VM barely share anything. They share exactly one file,
`users/mitchellh/home-manager.nix`, and share it entirely through
`isDarwin`/`isLinux` conditionals inside it. The Mac host is thin on purpose.
Its whole job is to be a good Nix host: it disables nix-darwin's Nix
management because the Determinate installer owns Nix
([machines/macbook-pro-m1.nix#L12-L16](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/machines/macbook-pro-m1.nix#L12-L16)),
sets `ids.gids.nixbld = 30000` for the same reason
([#L5-L6](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/machines/macbook-pro-m1.nix#L5-L6)),
wires a Cachix substituter
([#L47-L56](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/machines/macbook-pro-m1.nix#L47-L56)),
and sources the Nix daemon profile into zsh and fish
([#L59-L77](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/machines/macbook-pro-m1.nix#L59-L77)).
Its only `environment.systemPackages` entry is `cachix`
([#L80-L82](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/machines/macbook-pro-m1.nix#L80-L82)).

Building Linux from the Mac is a first-class concern. The Mac imports
`nix-rosetta-builder` with `onDemand = true`, and the comment records that an
existing Linux builder is needed to bootstrap it the first time
([lib/mksystem.nix#L45-L72](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/lib/mksystem.nix#L45-L72)).
nix-darwin's own `linux-builder` is present but disabled, with its beefy
config kept in place
([machines/macbook-pro-m1.nix#L24-L45](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/machines/macbook-pro-m1.nix#L24-L45)).
The VM also cross-compiles the other way, with
`boot.binfmt.emulatedSystems = ["x86_64-linux"]` so it can build the WSL
tarball
([machines/vm-aarch64.nix#L7-L8](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/machines/vm-aarch64.nix#L7-L8),
[README#L192-L198](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/README.md#L192-L198)).

## 3. Per-App Config Mechanics

### What is managed and how

Configuration is split three ways: home-manager `programs.*` modules where
one exists, `builtins.readFile` of a plain file next to the Nix code where
the app's own syntax is easier, and `home.file` or `xdg.configFile` for the
rest.

The `readFile` pattern is heavy. `users/mitchellh/` holds 12 non-Nix config
files, and most are pulled in as strings: `bashrc` into
`programs.bash.initExtra`, `config.fish` into
`programs.fish.interactiveShellInit`, `kitty` into
`programs.kitty.extraConfig`, `Xresources` into `xresources.extraConfig`, and
`i3`, `rofi`, and `ghostty.linux` into `xdg.configFile` entries
([users/mitchellh/home-manager.nix#L127-L136](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L127-L136),
[#L144-L150](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L144-L150),
[#L167-L186](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L167-L186),
[#L244-L247](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L244-L247),
[#L301](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L301)).
Only two files use `home.file` with `.source`: `.gdbinit` and `.inputrc`
([#L122-L125](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L122-L125)).
Where a `programs.*` module exists and is expressive enough, it is used:
`git`, `direnv`, `go`, `alacritty`, `i3status`, `neovim`, `atuin`, `nushell`,
`oh-my-posh`, `npm`, `jujutsu`, `gpg`
([#L142-L299](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L142-L299)).

Where the module is not expressive enough, the comment says so and the
setting is dropped. `programs.jujutsu` is enabled with a comment: "I don't
use `settings` because the path is wrong on macOS at the time of writing
this"
([#L220-L225](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L220-L225)).
A `jujutsu.toml` sits in `users/mitchellh/` and is referenced by no Nix file.

### The app-rewritten file problem, and how it is dodged

Exactly one macOS application config is managed, and the mechanism is a
deliberate non-solution. `RectangleConfig.json` is written to
`~/.config/rectangle/RectangleConfig.json` with the comment "Rectangle.app.
This has to be imported manually using the app"
([users/mitchellh/home-manager.nix#L131-L133](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L131-L133)).
Nix writes a store symlink at a path Rectangle does not read; the user then
imports it by hand through the application's own UI. No merge, no
co-ownership, no drift detection. The app-owned file is untouched.

The only place the collision is confronted is
`xdg.configFile."nvim/init.lua".force = true`
([#L129](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L129)),
which sits alongside a `programs.neovim.initLua` of
`require("config.lazy")`
([#L266-L274](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L266-L274)).
The rest of `~/.config/nvim` is an unmanaged lazy.nvim tree, and `force`
tells home-manager to overwrite whatever is at that one path rather than
refuse. Our doc's citation is that `force` "will silently delete the target."
Why it is set here is inferred from the surrounding code, not stated in a
comment.

### What is deliberately left out on the Mac

The README is explicit. The Darwin section is headed "**THIS IS OPTIONAL AND
UNRELATED TO THE VM WORK**" and says: "I share some of my Nix configurations
with my Mac host and use Nix to manage _some_ aspects of my macOS
installation, too... I don't manage _everything_ with Nix, for example I
don't manage apps, some of my system settings, Homebrew, etc. I plan to
migrate some of those in time."
([README#L154-L163](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/README.md#L154-L163)).

Checked against the source, the README is stale on one point and accurate on
the rest.

| Surface | In this repo? | Evidence |
| --- | --- | --- |
| macOS `defaults` | No. Zero `system.defaults`, zero `targets.darwin.defaults`, zero `defaults write`. | `grep` across all `.nix` files |
| launchd on Darwin | No. Zero `launchd`, `launchd.agents`, or `launchd.user.agents`. | `grep` |
| Activation scripts | No. Zero `home.activation`, zero `system.activationScripts`. | `grep` |
| `home.file` `onChange` | No. Zero occurrences. | `grep` |
| `mkOutOfStoreSymlink` | No. Zero occurrences. | `grep` |
| Homebrew casks | Yes, contrary to the README. 15 casks and one brew (`gnupg`). | [users/mitchellh/darwin.nix#L4-L27](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/darwin.nix#L4-L27) |
| Homebrew taps | No `homebrew.taps`, no nix-homebrew. Homebrew is assumed present. | `grep` |
| Mac App Store | No `masApps`. | `grep` |
| `homebrew.onActivation` | Absent, so no `cleanup`, no `autoUpdate`, no `upgrade`. | [darwin.nix#L4-L27](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/darwin.nix#L4-L27) |
| Secrets tool | No sops-nix, no agenix, no opnix. | `grep` |

`system.primaryUser` and a `users.users.mitchellh` stanza with `home` and
`shell` exist, the latter with a comment pointing at nix-darwin issue 423
([darwin.nix#L29-L37](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/darwin.nix#L29-L37)).
`users/mitchellh/darwin.nix` is 38 lines total. That is the whole
Nix-managed macOS surface beyond `machines/macbook-pro-m1.nix`.

### Root per switch

On Darwin the Makefile builds first, then runs the built
`darwin-rebuild switch` under `sudo`
([Makefile#L26-L33](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L26-L33)).
On Linux it is `sudo nixos-rebuild switch --flake ".#${NIXNAME}"`. The VM
sets `security.sudo.wheelNeedsPassword = false`
([machines/vm-shared.nix#L54-L55](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/machines/vm-shared.nix#L54-L55)),
so the sudo cost is nil there. There is no Touch ID, no PAM configuration,
and no elevation logic anywhere.

### Secrets

There is no secrets management. Instead there are three separate patterns.

First, sneakernet. `make secrets/backup` tars `~/.ssh` and `~/.gnupg` into
`backup.tar.gz` (gitignored) and `make secrets/restore` untars it and
`chmod`s the results, "so that we can transfer them to new machines via
sneakernet or other means"
([Makefile#L61-L85](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L61-L85)).
VM provisioning does the same over the wire with `rsync`
([Makefile#L133-L144](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L133-L144)).

Second, `op://` references as literal environment variable values:

```nix
AMP_API_KEY = "op://Private/Amp_API/credential";
OPENAI_API_KEY = "op://Private/OpenAPI_Personal/credential";
```

([users/mitchellh/home-manager.nix#L115-L116](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L115-L116),
with `pkgs._1password-cli` in `home.packages` at
[#L61](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L61)).
The environment variable holds the reference, not the value. Resolution is
deferred to whatever consumes it, presumably `op run` or a 1Password-aware
client. Nothing in this repo resolves them, and nothing secret enters the
store. Which consumer resolves them is unverified.

Third, plaintext-adjacent material committed outright. The NixOS user carries
a committed `hashedPassword` and an SSH public key
([users/mitchellh/nixos.nix#L21-L30](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/nixos.nix#L21-L30)),
paired with `users.mutableUsers = false`
([machines/vm-shared.nix#L80-L81](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/machines/vm-shared.nix#L80-L81)).
The `.gitattributes` declares `secret/** filter=git-crypt diff=git-crypt`,
and the `vm/copy` rsync excludes `.git-crypt/`
([Makefile#L146-L155](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L146-L155)),
but no `secret/` directory exists at this sha. That is vestigial.

### chezmoi is still in the loop

`pkgs.chezmoi` is in `home.packages`
([users/mitchellh/home-manager.nix#L64](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L64)),
and home-manager's Nushell integration is switched off with the comment "We
manage our own Nushell config via Chezmoi"
([#L48-L49](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L48-L49)),
while `programs.nushell.enable = true` still installs it
([#L284-L286](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L284-L286)).
There is no chezmoi source state in this repository, so it lives elsewhere.
The most-cited minimal Nix config runs Nix and chezmoi side by side, and
draws the line at one tool's config file.

## 4. Testing And CI

There is no CI. `.github/` contains only `images/screenshot.png`, and the
GitHub API returns 404 for `.github/workflows`. There is no Renovate or
Dependabot configuration. Everything is a local Makefile target.

| Target | What it does | Source |
| --- | --- | --- |
| `check` | `nix flake check --all-systems --no-build`, then four explicit `nix eval --raw` calls on `...config.system.build.toplevel.drvPath`, one per host, output discarded | [Makefile#L44-L50](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L44-L50) |
| `test` | builds, then `darwin-rebuild test` or `nixos-rebuild test` | [Makefile#L35-L42](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L35-L42) |
| `switch` | builds, then `darwin-rebuild switch` under `sudo`, or `nixos-rebuild switch` | [Makefile#L26-L33](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L26-L33) |
| `cache` | builds the VM closure and pipes every output through `jq` into `cachix push` | [Makefile#L52-L59](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L52-L59) |
| `wsl` | `nix build .#nixosConfigurations.wsl.config.system.build.installer` | [Makefile#L164-L167](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L164-L167) |

The `check` target is the interesting one, because its shape is a direct
confirmation of a claim in our doc. `nix flake check` does not cover
`darwinConfigurations`, so he adds the Darwin host back by hand with a bare
`nix eval` on its `drvPath`
([Makefile#L50](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L50)).
He does the same for all three NixOS hosts even though `flake check` would
cover them, so the target is uniform and does not depend on which host
classes `flake check` happens to walk. He chose evaluation over building
(`--no-build`, `drvPath`, not `nix build`), which catches evaluation and
option-type errors cheaply and says nothing about whether the closure
actually builds. `make cache` is where real builds happen, and its output
goes to a public Cachix.

The VM workflow is a Makefile plus SSH, not Nix. `vm/bootstrap0` SSHes to a
fresh NixOS ISO as root, partitions `/dev/sda` with `parted`, formats,
mounts, runs `nixos-generate-config`, then `sed`s flake support, the Cachix
substituter, and SSH settings into the generated `configuration.nix` before
`nixos-install`
([Makefile#L87-L121](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L87-L121)).
`vm/bootstrap` then chains `vm/copy` (rsync of the repo to `/nix-config`),
`vm/switch` (remote `nixos-rebuild switch`), and `vm/secrets` (rsync of
`~/.ssh` and `~/.gnupg`)
([Makefile#L123-L162](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L123-L162)).
A `NOTE(mitchellh)` in the source admits the two-step split is a workaround:
"I'm sure there is a way to do this and bootstrap all in one step but when I
tried to merge them I got errors. One day."
([Makefile#L92-L93](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L92-L93)).
After bootstrap, he works inside the VM: "At this point, I never use Mac
terminals ever again"
([README#L150-L152](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/README.md#L150-L152)).

## 5. Compare And Contrast With Our Target-State Doc

### Composition model

Evidence **for** the doc's core claim, with a caveat about scale.

Our doc argues for host imports of role modules imports of app modules, with
no `machine_type` read at evaluation time, and cites SrvOS, nixos-hardware,
and flake-parts. This repo confirms the "no runtime identity lookup" half
completely: identity is the flake attribute you switch to
([flake.nix#L89-L109](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/flake.nix#L89-L109)),
with the Makefile picking a default from `uname`
([Makefile#L13-L17](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L13-L17)).
There is no data layer, no resolver, no `fromTOML`.

It does **not** confirm the app-module or role-module decomposition, and it
is not evidence against it either, because his fleet does not need one. Four
hosts, one user, no work/personal split, and one shared home-manager file
carrying every application. Our repo has 4 machine types with genuinely
divergent package sets and an MDM-managed work Mac. `mkSystem`'s
"convention over configuration" file lookup is the right lesson to take; his
single `home-manager.nix` is not.

Our doc should **add a note** on where his primitive earns its keep: the
four-argument `mkSystem` plus path convention is a cheaper way to express
"host + user + platform" than a `machines.toml` resolver or a role module
graph, and it is worth naming as the floor. Our tree sketch already has
`modules/flake/hosts.nix`; the note belongs there.

### The "what disappears" table

Every row in that table that this repo can speak to, it supports.

| Our row | This repo | Verdict |
| --- | --- | --- |
| `features.tmpl` resolver and layered `machines*.toml` gone | No resolver exists. Four booleans and `isDarwin`/`isLinux`. | Supports |
| Brewfile renderer and golden tests gone | Casks are a literal 15-entry list in one file ([darwin.nix#L4-L27](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/darwin.nix#L4-L27)). | Supports |
| First-run prompts and `machines_local` gone | No prompts. Host policy is committed; the Makefile supplies the default name. | Supports |
| `run_onchange_` hash lines gone | Zero `onChange` usage, but also nothing that needed it. | Weak support |
| `run_once_` bootstrap survives migration only | Bootstrap is a Makefile plus SSH, permanently outside Nix ([Makefile#L87-L131](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L87-L131)). | Supports, but "migration only" is optimistic |
| Drift banner gone, replaced by generations and `diff-closures` | Neither exists. There is no drift surface of any kind. | Supports the loss, not the replacement |
| Plist modify stubs gone for `defaults` domains | No plists managed at all. | No evidence |

One correction to our doc. The "what disappears" table puts `run_once_`
bootstrap under "migration only," implying it goes away. This repo has run
for six years and its bootstrap is still a Makefile that SSHes into a fresh
machine and `sed`s a generated file. Provisioning a machine to the point
where a flake can be switched is not itself declarative, and does not become
so. Our doc should move that row's framing from "migration only" to
"permanently outside Nix, same as today's `run_once_before_00-homebrew`."

### The per-app ownership table

Almost no overlap, and one useful negative result.

Of our nine apps, this repo touches two: it installs `pkgs.claude-code` and
`pkgs.codex`
([home-manager.nix#L80-L81](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L80-L81),
with `claude-code` pulled from unstable at
[flake.nix#L74-L76](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/flake.nix#L74-L76))
and manages zero configuration for either. It says nothing about managed
drop-ins, the Codex system layer, or Claude's `enabledPlugins`. Our table's
verified/unverified column stands unchanged.

The negative result is Rectangle. Faced with exactly the co-owned-file
problem our table is about, the response was to write an importable copy at a
path the app does not read and import it by hand
([home-manager.nix#L131-L133](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L131-L133)).
Our table has three tiers: app's own layer, `defaults`, keep the merger. This
is a fourth tier we did not name: **Nix owns a reviewable artifact, the human
performs the import.** For a config that changes twice a year it is a real
answer, and it costs nothing. Our doc should add it as tier 0, with the
honest label that it is not automation.

### Problem A: files the app also writes

Evidence that the problem is real and that avoidance is the common answer.

The repo confirms the mechanism our doc cites. `force = true` on
`nvim/init.lua` is the escape hatch, used exactly once, at the one path where
home-manager collides with an unmanaged application tree
([home-manager.nix#L129](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L129)).
No merge mechanism exists anywhere, no activation block, no `onChange`.

The load-bearing observation is what is missing. A 3,000-star nix-darwin
configuration maintained for six years by a competent engineer manages zero
macOS preference domains and zero co-owned application files. That is not an
oversight. It is the same conclusion our doc reaches under "What Stays
Outside Nix," reached independently by not attempting it. Our doc should keep
Problem A exactly as written and **cite this as corroboration**: the most
visible minimal Nix Mac config in the ecosystem does not solve it, it
declines it.

### Problem B: the MDM-managed work Mac

No evidence, in either direction. There is no work machine, no MDM, no
managed profile, and no elevation logic. `sudo darwin-rebuild switch`
([Makefile#L30](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L30))
confirms the root-per-switch cost our doc already documents, on an
unencumbered machine where that cost is a password prompt. Problem B is
untouched.

One adjacent data point. He runs the Determinate installer and turns
nix-darwin's Nix management off with `nix.enable = false`
([machines/macbook-pro-m1.nix#L12-L16](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/machines/macbook-pro-m1.nix#L12-L16))
plus `ids.gids.nixbld = 30000`
([#L5-L6](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/machines/macbook-pro-m1.nix#L5-L6)).
Our Problem B section already says the `determinate` module with
`determinateNix.enable = true` is the supported path. This repo uses the
older, blunter form. Worth noting as a live example that the coexistence is
two settings, not a rewrite; our doc's framing holds.

### Problem C: secrets without store leakage

Reframes the low end of the problem, and confirms the `op://` shape.

Our Problem C evaluates four options: opnix, sops-nix, agenix, and
`op read` in activation, and recommends the fourth for interactive Macs
because it keeps `op://` refs as the committed form and values out of the
store. This repo lands on a fifth thing our table does not have: put the
`op://` reference in the environment variable itself and let the consumer
resolve it
([home-manager.nix#L115-L116](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L115-L116)).

That is genuinely different from our four rows. There is no activation step,
no launchd service, no file installed at 0600, and no secret in the store,
because no secret is ever resolved by the configuration at all. It only works
for secrets whose consumer speaks `op://`, which excludes our three license
files (BetterTouchTool wants a license blob on disk, not a reference). But it
is the cheapest option in the table for anything env-var shaped, and our
Problem C table should gain it as a row with that exact scope limit.

The rest is evidence for our doc's harder claim. With no secrets tool, the
fallback is a tarball you carry between machines
([Makefile#L61-L85](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L61-L85))
and a committed password hash
([users/mitchellh/nixos.nix#L21-L30](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/nixos.nix#L21-L30)).
Our doc says the store leakage constraint forces the work to activation or a
service. This repo's answer is to move it out of the system entirely. That is
a real option and it is worse than what we have today with chezmoi's
`onepasswordRead`.

### The test surface

Two concrete confirmations and one construct we are missing.

Confirmed: our doc says `nix flake check` "does not touch
`darwinConfigurations` or `homeConfigurations`" and that every host must be
exposed explicitly. His `check` target is that workaround in the wild
([Makefile#L44-L50](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L44-L50)).
This should be cited in our doc's test-surface bullet as a live example.

Contrasted: our doc proposes exposing hosts through `checks.<system>.<host> =
self.darwinConfigurations.<host>.system`, which builds. He uses
`nix eval --raw '...drvPath'`, which does not. His version is cheap, runs on
any machine regardless of platform, and catches evaluation and option-type
failures only. Ours catches build failures too and costs a real build in CI.
Both are defensible and they answer different questions. Our doc's
test-surface section should name the cheap tier explicitly, because a
`nix eval` gate is something we could add long before any migration and it
would still be useful for a spike.

Missing from our doc: the `test` verb. He exposes `darwin-rebuild test` and
`nixos-rebuild test` as a Makefile target distinct from both `build` and
`switch`
([Makefile#L35-L42](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L35-L42)).
Our "Activation dry runs" bullet lists `home-manager switch -n`,
`darwin-rebuild build`, and `darwin-rebuild --dry-run`, but not
`darwin-rebuild test`. The exact semantics of `test` under nix-darwin were
**not verified in this survey**; our doc should verify them against the
pinned nix-darwin and, if it is what it appears to be, add it as the tier
between "build and inspect" and "switch and commit."

Also missing: a binary cache. He pushes every VM closure to a public Cachix
and wires the substituter into all four hosts, including the bootstrap `sed`
([Makefile#L52-L59](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L52-L59),
[Makefile#L113-L114](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L113-L114),
[machines/macbook-pro-m1.nix#L47-L56](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/machines/macbook-pro-m1.nix#L47-L56)).
Our doc never mentions a cache. For a fleet with a homelab mini, a work Mac,
and a CI host, "who builds the closure once so the others substitute it" is
an open design question our doc does not currently pose.

### Does the VM-on-Mac shape count as a fifth option?

Yes, and it should be added to the prior doc's ranked list, below Option 2.

The shape is: NixOS in a local VM as the development environment, macOS host
mostly unmanaged, one thin nix-darwin layer whose job is to make the host a
good Nix host. It is coherent, it has six years of production evidence
([README#L59-L63](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/README.md#L59-L63)),
and it sidesteps every one of our three hard problems by moving the work to a
machine where none of them exist.

Why it ranks low for us specifically. Our repo's value is concentrated on the
macOS surface: 22 merges into app-owned files, 143 `defaults write` lines,
the cask set, LaunchAgents, and the agent CLI configs (Claude Code, Codex,
Cursor, pi) that we run on the Mac, not in a container. A dev VM takes over
the shell and CLI layer and leaves that entire surface on chezmoi, which
means two systems forever rather than as a transition. The prior doc already
warns about "two systems if work or Linux is excluded" under Sizing; this
option makes that permanent by design.

Why it is still worth naming. It is orthogonal to Options 2 through 4, not
competing with them. It changes where development happens, not how the Mac is
managed, so it composes with Option 1. We already run macOS VMs through Tart,
and the target-state doc already sketches `hosts/ci.nix` and
`hosts/devpod.nix`. A NixOS dev VM would be the third guest in a lane that
exists. Suggested wording for the prior doc: insert it as Option 5, marked as
orthogonal, with the note that it does not reduce the chezmoi surface and
therefore does not substitute for Options 2 through 4.

A related shape worth stealing regardless: `nixosConfigurations.wsl` builds a
root filesystem tarball rather than managing a live machine
([flake.nix#L99-L103](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/flake.nix#L99-L103),
[Makefile#L164-L167](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L164-L167)),
and the README says he recreates the distribution on every change rather than
switching in place
([README#L185-L190](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/README.md#L185-L190)).
Our concept-map row 41 treats the DevPod profile as standalone home-manager
blocked on getting Nix into the image. "Build the image from the flake
instead of configuring it after the fact" is a third answer to row 41 that
our doc does not consider.

### Open questions this answers or reframes

| Q | Status | Basis |
| ---: | --- | --- |
| 7 | **Reframed.** "Declarative Brewfile" and "exclusive Homebrew" are separable, and the common practice is the former only. He declares 15 casks with no `homebrew.onActivation` block at all, so nothing is ever cleaned up ([darwin.nix#L4-L27](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/darwin.nix#L4-L27)). Q7 should stop asking "is Homebrew fully declarative per host" and start asking "which hosts, if any, want exclusivity." | grep confirms absence |
| 14 | **Partly answered, in the negative.** Q14 asks which apps let us disable their own persistence so Nix can own the whole file. Rectangle is a case where he did not try; he writes an importable artifact instead. That is the tier-0 answer above. | [home-manager.nix#L131-L133](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L131-L133) |
| 1, 9, 10, 16 | **No evidence.** He installs `claude-code` and `codex` and manages no config for either. | [home-manager.nix#L80-L81](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L80-L81) |
| 2, 11, 12 | **No evidence.** Zero plist domains managed. | grep |
| 3 | **No evidence.** No MDM. | |
| 5 | **No evidence**, but note that his `op://` pattern needs no service account at all, which is a way to make Q5 not block anything env-var shaped. | [home-manager.nix#L115-L116](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/home-manager.nix#L115-L116) |
| 4 | **Adjacent answer.** He does not put Nix in someone else's image; he builds the image ([Makefile#L164-L167](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L164-L167)). Only applies if we control the DevPod image. | |
| 8, 13, 15 | **No evidence.** No Raycast, no Cursor, no Yojam. | |

Two new questions this repo raises for our doc:

- **Who builds the closure?** With a homelab mini, a work Mac, a personal
  Mac, and CI, is there a binary cache in the target, and who pushes to it?
  Not currently in our doc.
- **Do we need a Linux builder on the Macs?** If any host is Linux (DevPod,
  CI), building its closure from a Mac needs `linux-builder` or
  `nix-rosetta-builder`. Our tree sketch has `hosts/devpod.nix` and
  `hosts/ci.nix` and says nothing about how they get built.

## 6. What To Take, What To Avoid, Relevance

### Take

- **`mkSystem` as the host constructor.** One function, a name, a small
  argument set, and three paths derived by convention
  ([lib/mksystem.nix#L20-L23](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/lib/mksystem.nix#L20-L23)).
  Adding a host is a file plus a four-line flake entry. Our `modules/flake/hosts.nix`
  should look like this even with roles layered on top.
- **Facts as module arguments, not lookups.** `currentSystemName`,
  `currentSystemUser`, `isWSL` passed through `_module.args`
  ([#L85-L95](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/lib/mksystem.nix#L85-L95)).
  Cheaper than a typed options layer for facts that are inputs rather than
  policy.
- **The `check` target verbatim.** `nix flake check --all-systems --no-build`
  plus one explicit `nix eval` per host
  ([Makefile#L44-L50](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/Makefile#L44-L50)).
  This is portable to a spike today and does not require a migration.
- **Tier 0 for co-owned files.** Generate a reviewable artifact, let the
  human import it. Cheap, honest, and correct for low-churn config.
- **A binary cache in the design.** Our doc has no answer for who builds
  once.
- **Stable channels with a named per-package unstable overlay.** Four
  packages, each with a stated reason
  ([flake.nix#L64-L82](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/flake.nix#L64-L82)).
  This is the shape our mise `latest` policy would become (row 34).

### Avoid

- **One shared `home-manager.nix` for all hosts.** 310 lines with inline
  `isDarwin`/`isLinux` conditionals scattered through it. At his scale it is
  fine. At four machine types with divergent package sets it becomes the
  thing our doc's app-module design exists to prevent.
- **No CI.** He can get away with it because he switches daily on the only
  machine that matters. We have a work Mac we cannot break and a headless
  mini.
- **The secrets story.** A sneakernet tarball and a committed password hash
  are strictly worse than what chezmoi gives us today.
- **README drift.** The README says he does not manage Homebrew with Nix; the
  code manages 15 casks
  ([README#L163](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/README.md#L163)
  against
  [darwin.nix#L4-L27](https://github.com/mitchellh/nixos-config/blob/14467f8b4fa7feda221d429b189e6276a399e054/users/mitchellh/darwin.nix#L4-L27)).
  Our own docs-lifecycle discipline exists to catch exactly this.
- **Vestigial config.** `.gitattributes` declares a git-crypt filter for a
  path that does not exist.

### Relevance: 3 out of 5

High value on composition and the test lane, near-zero on the three problems
that actually decide our migration.

What makes it worth the read. It is a six-year-production example of the
minimum viable nix-darwin layer, it independently confirms two mechanical
claims in our doc (`nix flake check` skipping `darwinConfigurations`, root
per switch on Darwin), its `mkSystem` is directly reusable, and its `check`
target is copyable into a spike this week. Its `op://`-as-env-value pattern
is a real addition to our Problem C table.

What caps it at 3. The repo's design premise is to not have our problems. No
MDM, no work machine, no macOS defaults, no co-owned application files, no
secrets tool, no launchd, one user, no role axis. Every section of our doc
that costs real effort, Problems A, B, and C, the 22 merges, the 143
`defaults` lines, the agent CLI configs, gets either silence or an avoidance
strategy from this repo. That silence is itself informative, which is why it
is not a 2: the most-cited minimal Nix Mac config declining to manage macOS
preferences is evidence for our "What Stays Outside Nix" section. But it is
corroboration, not new information.

## 7. Scorecard Against Our Concept Map

Rows from Appendix A of [the target-state doc](../nix-target-state-research.md).
Only rows where this repo provides actual evidence are listed. Notes are five
words.

| Row | Verdict | Note |
| ---: | --- | --- |
| 1 | Supports | Uses source and readFile directly |
| 2 | Supports | chmod happens outside Nix entirely |
| 5 | Supports | Booleans and interpolation replace templates |
| 6 | Supports | Flake attribute plus Makefile default |
| 8 | Alternative | No resolver, four constructor booleans |
| 9 | Supports | Literal cask list, no renderer |
| 10 | Supports | home.packages holds the CLI set |
| 11 | Contradicts | No cleanup, Homebrew stays nonexclusive |
| 13 | Alternative | Assumes Homebrew already installed manually |
| 15 | Supports | flake=false inputs consumed as read-only |
| 16 | Supports | lib.optionals gates files per platform |
| 20 | Alternative | Makefile bootstrap targets, outside Nix |
| 23 | Alternative | Manages no plist domains whatsoever |
| 24 | Alternative | Writes importable copy, hand imports |
| 26 | Alternative | No macOS defaults are managed |
| 27 | Supports | sudo darwin-rebuild switch on Darwin |
| 28 | Alternative | No launchd agents on Darwin |
| 34 | Alternative | direnv and per-project flakes instead |
| 35 | Alternative | fish login shell, system shellInit |
| 36 | Supports | Native xdg options replace data |
| 37 | Alternative | op:// refs as env values |
| 38 | Contradicts | No status or diff surface |
| 40 | Supports | force=true escape hatch on init.lua |
| 41 | Alternative | WSL tarball ships Linux profile |
| 42 | Contradicts | No CI, local eval only |
