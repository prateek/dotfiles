---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-04
updated: 2026-09-04
related:
  - ../nix-target-state-research.md
  - ../nix-migration-research.md
status_detail: "Agent survey of clo4/nix-dotfiles at 7d184d422d43577e7eaf8bccb09feed19e94340b, compared with the Nix target-state doc. Unreviewed."
---

# Survey: clo4/nix-dotfiles

## Method

Read on 2026-09-04. The repo was pulled as a pinned tarball with
`gh api repos/clo4/nix-dotfiles/tarball/<sha>` at
`7d184d422d43577e7eaf8bccb09feed19e94340b`, the tip of `main` on that date.
Every `.nix` file in the snapshot was read in full: `flake.nix`,
`devshell.nix`, `secrets.nix`, all six host directories, `users/`,
`modules/`, and `packages/`. Also read: `README.md`, `run.fish`, the CI
workflow, `flake.lock`, and the parts of `config/` that bear on the
comparison (zsh, fish, git, mise, npm, and every per-directory
`.gitignore`).

The flake's composition layer is a fork of numtide blueprint. It was read at
its locked revision, `clo4/blueprint@b033f96062fd91c024f6a04ee2cbf7c168a28a6e`
on branch `generic-users`, which is the exact revision in
[`flake.lock`](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/flake.lock).
Citations to blueprint use that sha.

Repo metadata, commit counts, branch state, and CI run history came from the
GitHub API. Nothing was evaluated or built: no `nix flake check`, no
`darwin-rebuild`, no `home-manager` run. Claims about what the flake produces
are read off blueprint's source, not observed.

Permalinks below use the pinned shas. Nothing is cited that was not opened.

## 1. What It Is

One person's configuration, released under the Unlicense. The author is
"clo4" (Robert). The server sets `time.timeZone = "Australia/Sydney"`
([configuration.nix#L56-L60](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/homeserver1/configuration.nix#L56-L60)).
The README frames the repo as a reference for people stuck on flake layout,
not as a framework
([README.md#L1-L3](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/README.md#L1-L3)).

Size, measured on the snapshot: 124 files, 37 `.nix` files, 1,801 lines of
Nix, 68 files under `config/`. There are no test files.

Six host directories. Five are described in the README
([README.md#L27-L38](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/README.md#L27-L38));
`legacy` is undocumented and holds one user file
([legacy/users/robert/home-configuration.nix](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/legacy/users/robert/home-configuration.nix)).

| Host | OS | Mechanism | Status per README | Switch command |
| --- | --- | --- | --- | --- |
| `work-macbookpro` | macOS, M3 Pro | nix-darwin, HM as a module | active | `sudo darwin-rebuild switch` ([run.fish#L137-L143](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/run.fish#L137-L143)) |
| `pc3` | CachyOS Linux, not NixOS | standalone home-manager, two users | active | `home-manager switch` ([run.fish#L168-L175](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/run.fish#L168-L175)) |
| `homeserver1` | NixOS x86_64 | `nixos-rebuild`, often remote | active | ([run.fish#L101-L127](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/run.fish#L101-L127)) |
| `macmini` | macOS, M1 | nix-darwin | retired | `sudo darwin-rebuild switch` ([run.fish#L129-L135](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/run.fish#L129-L135)) |
| `macbook-air` | macOS, M1 | standalone home-manager | retired | `home-manager switch` ([run.fish#L145-L161](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/run.fish#L145-L161)) |
| `legacy` | unstated | standalone home-manager | undocumented | `home-manager switch` ([run.fish#L163-L166](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/run.fish#L163-L166)) |

The README's "I currently actively maintain my nix-darwin and standalone
Home Manager configurations"
([README.md#L3](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/README.md#L3))
is true, but the live standalone host is Linux, not a Mac. Both Macs still in
use or recently in use that ran standalone home-manager (`macbook-air`) are
marked "no longer being used"
([README.md#L35-L36](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/README.md#L35-L36)).
This matters for section 5: the two-Macs-two-mechanisms period is history,
not current practice.

Activity, from the GitHub search API across all branches: 161 commits in
2024, 295 in 2025, 57 in 2026. `main` last moved on 2026-05-05; the repo was
last pushed 2026-07-06, to a branch. Development happens on per-host
branches that get merged into `main`: `robert@pc3` is 9 commits ahead of
`main`, `robert@work-macbookpro` is 17 ahead and 1 behind, and the merge
commits in the log are titled `Merge branch 'robert@pc3'` and
`Merge branch 'robert@work-macbookpro'`.

The lock is bumped by one scheduled GitHub Actions job that runs
`nix flake update nixpkgs-unstable --commit-lock-file` at 18:00 daily and
pushes to `main`
([update-flake.yml#L1-L24](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/.github/workflows/update-flake.yml#L1-L24)).
It only bumps one input of twenty. It is also broken: every run sampled from
2026-08-25 to 2026-09-03 failed at the "Push to main" step, and the newest
`flake.lock: Update` commit in the log is 2026-04-15. In the snapshot's lock,
`nixpkgs` is pinned at 2026-04-09 and `nixpkgs-unstable` at 2026-04-11.
Everything else is bumped by hand.

## 2. Composition

### How blueprint wires the tree

There is no glue code. `flake.nix` is 54 lines: an `inputs` block and a
single call to `inputs.blueprint { inherit inputs; nixpkgs.config.allowUnfree = true; }`
([flake.nix#L48-L53](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/flake.nix#L48-L53)).
Blueprint derives outputs from folder names
([folder-structure.md#L1-L16](https://github.com/clo4/blueprint/blob/b033f96062fd91c024f6a04ee2cbf7c168a28a6e/docs/folder-structure.md#L1-L16)).

| Source path | Flake output | Source |
| --- | --- | --- |
| `hosts/<h>/darwin-configuration.nix` | `darwinConfigurations.<h>`, plus `checks.<system>.darwin-<h>` | [folder-structure.md#L102-L124](https://github.com/clo4/blueprint/blob/b033f96062fd91c024f6a04ee2cbf7c168a28a6e/docs/folder-structure.md#L102-L124), [lib/default.nix#L310-L327](https://github.com/clo4/blueprint/blob/b033f96062fd91c024f6a04ee2cbf7c168a28a6e/lib/default.nix#L310-L327) |
| `hosts/<h>/configuration.nix` | `nixosConfigurations.<h>`, plus `checks.<system>.nixos-<h>` | [lib/default.nix#L300-L308](https://github.com/clo4/blueprint/blob/b033f96062fd91c024f6a04ee2cbf7c168a28a6e/lib/default.nix#L300-L308) |
| `hosts/<h>/users/<u>/home-configuration.nix` | `legacyPackages.<system>.homeConfigurations."<u>@<h>"` | [lib/default.nix#L232-L292](https://github.com/clo4/blueprint/blob/b033f96062fd91c024f6a04ee2cbf7c168a28a6e/lib/default.nix#L232-L292), [#L489-L495](https://github.com/clo4/blueprint/blob/b033f96062fd91c024f6a04ee2cbf7c168a28a6e/lib/default.nix#L489-L495) |
| `users/<u>/home-configuration.nix` | hostless `homeConfigurations.<u>` (the fork's `generic-users` feature) | [lib/default.nix#L175-L192](https://github.com/clo4/blueprint/blob/b033f96062fd91c024f6a04ee2cbf7c168a28a6e/lib/default.nix#L175-L192) |
| `modules/darwin/<n>.nix` | `darwinModules.<n>` | [folder-structure.md#L222-L232](https://github.com/clo4/blueprint/blob/b033f96062fd91c024f6a04ee2cbf7c168a28a6e/docs/folder-structure.md#L222-L232) |
| `modules/home/<n>.nix` | `homeModules.<n>` | same |
| `modules/common/<n>.nix` | `modules.common.<n>` | same |
| `packages/<n>.nix` | `packages.<system>.<n>`, plus `checks.<system>.pkgs-<n>` | [folder-structure.md#L243-L260](https://github.com/clo4/blueprint/blob/b033f96062fd91c024f6a04ee2cbf7c168a28a6e/docs/folder-structure.md#L243-L260) |
| `devshell.nix` | `devShells.<system>.default`, plus `checks.<system>.devshell-default` | [folder-structure.md#L37-L48](https://github.com/clo4/blueprint/blob/b033f96062fd91c024f6a04ee2cbf7c168a28a6e/docs/folder-structure.md#L37-L48) |

Two behaviors matter for the comparison. First, when a host directory has an
OS config, blueprint imports the matching home-manager module and populates
`home-manager.users` automatically
([lib/default.nix#L154-L173](https://github.com/clo4/blueprint/blob/b033f96062fd91c024f6a04ee2cbf7c168a28a6e/lib/default.nix#L154-L173)).
Second, when a host directory has only a `users/` folder and no OS config,
`loadHost` returns null and the users exist only as standalone
configurations
([lib/default.nix#L338-L343](https://github.com/clo4/blueprint/blob/b033f96062fd91c024f6a04ee2cbf7c168a28a6e/lib/default.nix#L338-L343)).
Deleting `darwin-configuration.nix` from a host directory is therefore the
whole difference between the two Mac shapes.

Every user also gets a standalone `"<u>@<h>"` output regardless of whether
the host has an OS config. On `work-macbookpro` the same module tree is
reachable both ways. `run.fish` picks nix-darwin for that host and
home-manager for the others; nothing in the module tree encodes the choice.

### Where identity lives

Nowhere, as a value. There is no `machine_type`, no role, no feature flag,
and no resolver anywhere in the repo. Hostname is the directory name and
username is the directory name; blueprint defaults `home.username` and
`home.homeDirectory` from the path
([folder-structure.md#L192-L201](https://github.com/clo4/blueprint/blob/b033f96062fd91c024f6a04ee2cbf7c168a28a6e/docs/folder-structure.md#L192-L201)).
Cross-cutting variation is expressed three ways, all of them local:

- `pkgs.stdenv.isDarwin` inside the shared config, for the fontconfig
  toggle, the Ghostty OS fragment, and the platform config directory
  ([home-configuration.nix#L89](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/users/robert/home-configuration.nix#L89),
  [#L93-L107](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/users/robert/home-configuration.nix#L93-L107)).
- A tiny `lib.mkIf pkgs.stdenv.isDarwin` module for the two Darwin-only home
  facts
  ([darwin.nix#L1-L11](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/users/robert/darwin.nix#L1-L11)).
- Host user files overriding attributes after importing the shared config.

### Which Mac ran what, and why

`work-macbookpro` is nix-darwin
([darwin-configuration.nix#L1-L74](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/work-macbookpro/darwin-configuration.nix#L1-L74)).
`macbook-air` is standalone home-manager: its directory has only
`users/robert/home-configuration.nix` and an SSH public key. It never had a
`darwin-configuration.nix`; the GitHub commits API returns no history for
that path.

Neither the README nor any commit message states why. Commit
`5e280e72` ("host: init work-macbookpro") explains only that the author
needed the setup working. The only recorded consequence is on the retired
Mac mini, where the author wanted to use the mini as a remote builder and
wrote: "unfortunately because the laptop isn't managed with nix-darwin, I
have to manually configure the builder :("
([macmini/darwin-configuration.nix#L26-L35](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/macmini/darwin-configuration.nix#L26-L35)).
Treat the rationale as unrecorded. The observable facts are that the
standalone Mac was the secondary machine and that being standalone cost it
system-level `nix.buildMachines` configuration.

The nearest thing to a stated policy is about the work setup, and it is
about pragmatism rather than privilege:

> The work setups are managed much more imperatively than any of my personal
> machines, mainly because it isn't worth my time while I'm working to set up
> Nix correctly (without buy-in from anyone else on the team) ... Instead, I
> can do as much as is reasonable in Nix, but fall back to plugins and
> homebrew when stuff doesn't work right.
> ([work-configuration.nix#L14-L19](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/users/robert/work-configuration.nix#L14-L19))

There is no evidence of MDM on this work Mac. It runs nix-darwin with
`nix-homebrew`, `system.primaryUser`, `services.openssh.enable`, a root-owned
`/etc/ssh/sshd_config.d` drop-in, and `nix.settings.trusted-users = [ "@admin" ]`
([darwin-configuration.nix#L24-L45](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/work-macbookpro/darwin-configuration.nix#L24-L45),
[#L72](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/work-macbookpro/darwin-configuration.nix#L72)),
which implies a standing admin account.

### How the two Macs share user config

One file, imported and then overridden.

```text
users/robert/home-configuration.nix     shared: packages, config links, shell
  <- users/robert/work-configuration.nix   imports the shared, adds work packages
       <- hosts/work-macbookpro/users/robert/home-configuration.nix
       <- hosts/pc3/users/work/home-configuration.nix
  <- hosts/macmini/users/robert/home-configuration.nix
  <- hosts/macbook-air/users/robert/home-configuration.nix
  <- hosts/pc3/users/robert/home-configuration.nix
  <- hosts/legacy/users/robert/home-configuration.nix
```

The shared file is 180 lines
([home-configuration.nix#L1-L180](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/users/robert/home-configuration.nix#L1-L180)).
Host files are 10 to 44 lines and set `home.stateVersion`,
`my.config.directory`, host-only `my.config.source` entries, host secrets,
and a few packages. `work-configuration.nix` is the only role-like layer, and
it is used by one Mac user and one Linux user
([work-configuration.nix#L1-L43](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/users/robert/work-configuration.nix#L1-L43)).
`home.stateVersion` differs per host (`24.05`, `24.11`, `25.05`), which is
the only place the hosts' ages leak into the tree.

## 3. Per-App Config Mechanics

### The dominant mechanism is an out-of-store symlink

Grepping the whole snapshot for home-manager program modules returns exactly
one hit: `programs.man.generateCaches = true`
([my-programs-fish.nix#L67](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/modules/home/my-programs-fish.nix#L67)).
There is no `programs.git`, no `programs.zsh`, no `programs.fish`, no
`programs.direnv`. Direct `home.file` use is four declarations: two shim
files, the `.hushlogin` marker, and the generated neovim plugin links
([home-configuration.nix#L144-L155](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/users/robert/home-configuration.nix#L144-L155),
[darwin.nix#L9](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/users/robert/darwin.nix#L9),
[my-programs-neovim.nix#L67-L69](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/modules/home/my-programs-neovim.nix#L67-L69)).

Everything else goes through a 59-line custom module. `my.config.source` maps
a target path to a path relative to `my.config.directory`, and each entry
becomes `home.file.<target> = { source = mkOutOfStoreSymlink "<dir>/<rel>"; force = <cfg.force>; }`
([my-config.nix#L9-L14](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/modules/home/my-config.nix#L9-L14),
[#L50-L58](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/modules/home/my-config.nix#L50-L58)).
`force` defaults to true
([#L41-L47](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/modules/home/my-config.nix#L41-L47)).
`directory` defaults to the flake store path but every host overrides it to
the working checkout
([#L16-L28](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/modules/home/my-config.nix#L16-L28)).

The README states the reason outright: declarative config requires a rebuild
per change, which discouraged the author from making changes, so the *link*
is declarative and the *content* is not
([README.md#L5-L8](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/README.md#L5-L8)).
The shared config links eighteen paths this way: ghostty, kitty, helix,
nvim, tmux, git, jj, direnv, mise, four fish subpaths, two zsh paths, and
`.npmrc`
([home-configuration.nix#L91-L142](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/users/robert/home-configuration.nix#L91-L142)).
Host files add zed, foot, and niri
([pc3/users/robert/home-configuration.nix#L20-L28](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/pc3/users/robert/home-configuration.nix#L20-L28)).

### Files the app also writes

They exist, and the repo handles them by routing around Nix entirely.

Because targets link into the git checkout, an app that rewrites its config
writes into the working tree. The accommodations are visible:

- Fish is linked as four separate subpaths instead of one directory, with the
  reason spelled out: when `my.config.directory` is the store path, fish
  "will try to write to the `fish_variables` file repeatedly and fail each
  time, spamming the terminal with errors"
  ([home-configuration.nix#L124-L132](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/users/robert/home-configuration.nix#L124-L132)).
  That is exactly the read-only-store failure our Problem A describes,
  observed in the wild.
- Four `config/*/.gitignore` files exist purely to absorb app writes:
  `config/fish/.gitignore` ignores everything that is not a directory or a
  `.fish` file, `config/zsh/.gitignore` ignores `.zcompdump*` and
  `.zsh_history`, `config/helix/.gitignore` ignores `lib`, and
  `config/kitty/.gitignore` ignores `dank-*.conf`.
- `config/nvim/lazy-lock.json` is committed, so the plugin manager's
  lockfile is co-owned by the app and the repo.
- The agenix work gitconfig cannot live inside `~/.config/git` "because the
  entire directory is symlinked non-recursively"
  ([work-macbookpro/users/robert/home-configuration.nix#L21-L27](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/work-macbookpro/users/robert/home-configuration.nix#L21-L27)).
  It is written to a sibling path and pulled in with `includeIf`
  ([config/git/config#L14-L18](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/config/git/config#L14-L18)).

There is no merge program anywhere in the repo. No structured config is
merged into. No app-owned JSON, TOML, or plist is partially managed.

### macOS defaults

On the nix-darwin Macs, one shared module with twelve keys across
`NSGlobalDomain`, `dock`, and `finder`
([system-defaults.nix#L1-L24](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/modules/darwin/system-defaults.nix#L1-L24)),
imported by both
([work-macbookpro#L9-L14](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/work-macbookpro/darwin-configuration.nix#L9-L14)).
No `CustomUserPreferences`, no `CustomSystemPreferences`, no PlistBuddy.

On the standalone-HM Mac there is exactly one defaults declaration, and it is
marked broken:

```nix
  # FIXME: This isn't working, need to figure out why
  targets.darwin.currentHostDefaults = {
```
([macbook-air/users/robert/home-configuration.nix#L17-L24](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/macbook-air/users/robert/home-configuration.nix#L17-L24))

That is the whole macOS defaults surface the standalone Mac has, and it did
not work for the one key the author tried. Root cause unknown; the FIXME was
never resolved before the host was retired.

### Casks, MAS, taps

`nix-homebrew` is enabled on both nix-darwin Macs with
`nix-homebrew.user = "robert"` and nothing else
([work-macbookpro#L43-L45](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/work-macbookpro/darwin-configuration.nix#L43-L45)).
Grepping the snapshot for `homebrew.` returns only those two hosts' `enable`
and `user` lines plus the flake input. There is no `homebrew.taps`, no
`brews`, no `casks`, no `masApps`, no `onActivation`. Homebrew is installed
declaratively and its *contents* are entirely imperative. The fish
environment pushes `/opt/homebrew/bin` to the tail of `PATH` so nothing brew
installs outranks Nix
([environment.fish#L33-L37](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/config/fish/conf.d/environment.fish#L33-L37)).

The standalone-HM Mac has no Homebrew management at all, because
`nix-homebrew` is a nix-darwin module.

### launchd

None. Grepping the snapshot for `launchd` and `LaunchAgent` in `.nix` files
returns nothing. The only scheduled work is on the NixOS server, as a
systemd service plus timer
([clouddns.nix#L22-L50](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/homeserver1/clouddns.nix#L22-L50)).

### Activation

None. Grepping for `activation`, `activationScripts`, and `onChange` in
`.nix` files returns nothing. Zero activation blocks across all six hosts.
Every side effect the repo needs is either a derivation, a systemd unit on
the server, or a fish function the human runs.

### Secrets on Darwin

agenix, with ciphertext committed to a public repo. Four `.age` files, plus
`config/niri/private.kdl` which is age-encrypted without the extension
([secrets.nix#L22-L31](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/secrets.nix#L22-L31)).
Recipients are per-host, per-user SSH public keys committed next to each host,
grouped into `robert-personal`, `robert-work`, and the union
([secrets.nix#L1-L20](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/secrets.nix#L1-L20)).

On Darwin the agenix module is imported into the *home-manager* config, not
the darwin config
([work-macbookpro/users/robert/home-configuration.nix#L11-L14](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/work-macbookpro/users/robert/home-configuration.nix#L11-L14)),
so the same declaration works on both Mac shapes and on standalone Linux
([pc3/users/robert/home-configuration.nix#L9-L12](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/pc3/users/robert/home-configuration.nix#L9-L12),
[#L30-L33](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/pc3/users/robert/home-configuration.nix#L30-L33)).
Secret paths are absolute strings under `$HOME`. Ownership and mode are set
only on the server secret
([clouddns.nix#L7-L12](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/homeserver1/clouddns.nix#L7-L12)),
not on the two user gitconfigs. Editing is a fish helper wrapping `agenix -e`
([run.fish#L91-L95](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/run.fish#L91-L95)).

### What runs as root

| Host shape | Root per switch | Evidence |
| --- | --- | --- |
| nix-darwin Macs | Yes. `run.fish` prefixes `sudo` when the verb is `switch`, and not when it is `build`. | [run.fish#L129-L143](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/run.fish#L129-L143) |
| standalone HM hosts | No. The functions call `home-manager` with no sudo at all. | [run.fish#L145-L175](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/run.fish#L145-L175) |

Both nix-darwin Macs set `security.pam.services.sudo_local.touchIdAuth = true`,
with a comment that it must be reapplied after each system update and that
the fish greeting warns when the PAM line is gone
([work-macbookpro#L32-L34](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/work-macbookpro/darwin-configuration.nix#L32-L34),
[fish_greeting.fish#L2-L15](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/config/fish/functions/fish_greeting.fish#L2-L15)).
That is a per-switch privilege ritual made visible in the shell prompt rather
than in a test.

## 4. Testing And CI

There are no tests. There is no `checks/` directory, no `tests/` directory,
no formatter check, and no lint job.

CI is the one nightly lock-bump workflow described in section 1. It does not
run `nix flake check` and does not build any host.

Blueprint would generate checks for free if anything ran them: packages,
devshells, `nixos-<host>`, and `darwin-<host>` closures
([lib/default.nix#L523-L554](https://github.com/clo4/blueprint/blob/b033f96062fd91c024f6a04ee2cbf7c168a28a6e/lib/default.nix#L523-L554)).
Standalone home configurations are not in that list; they live under
`legacyPackages`
([lib/default.nix#L489-L495](https://github.com/clo4/blueprint/blob/b033f96062fd91c024f6a04ee2cbf7c168a28a6e/lib/default.nix#L489-L495)).
So even a local `nix flake check` in this repo would cover the two nix-darwin
Macs and the NixOS server, and skip `pc3`, `macbook-air`, and `legacy`
entirely. The three standalone hosts have no automated evaluation of any
kind.

What stands in for tests:

- `run build-host` versus `run switch-host`, generated per host by a fish
  metaprogramming loop
  ([run.fish#L177-L198](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/run.fish#L177-L198)).
- `run dry`, which swaps the executor for a pretty-printer
  ([run.fish#L38-L49](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/run.fish#L38-L49)).
- `run check-applied`, a hand-rolled drift report comparing
  `NIX_CONFIG_LAST_MODIFIED` and `NIX_CONFIG_REV` against `git log -1`
  ([run.fish#L71-L89](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/run.fish#L71-L89)),
  fed by three session variables set in the shared config
  ([home-configuration.nix#L167-L169](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/users/robert/home-configuration.nix#L167-L169)).
- Two runtime assertions in `fish_greeting`: the Touch ID PAM check, and a
  warning when `NIX_CONFIG_DIR` still points into `/nix/store`, meaning the
  config directory was never set
  ([fish_greeting.fish#L17-L30](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/config/fish/functions/fish_greeting.fish#L17-L30)).
- Two fish `conf.d` guards that detect and repair a wrong
  `fish_function_path[1]` and print a loud warning
  ([environment.fish#L58-L94](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/config/fish/conf.d/environment.fish#L58-L94)).
- One module `assertions` entry on the server, guarding the container backend
  ([minecraft/default.nix#L6-L15](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/homeserver1/minecraft/default.nix#L6-L15)).

The pattern is worth naming: this repo replaced a test suite with runtime
self-checks in the interactive shell. That works for one person on three
machines and would not survive our surface.

## 5. Compare And Contrast With Our Doc

### 5.1 Problem B: what two Mac shapes actually look like

This is the question the survey was commissioned for, so the answer needs to
be precise about what the evidence does and does not cover.

**What the repo supports.** The mechanical claim in our Problem B table is
correct and observable here. The standalone hosts switch with no `sudo` in
the command; the nix-darwin hosts switch with `sudo`
([run.fish#L129-L175](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/run.fish#L129-L175)).
The structural difference between the two shapes really is one file: with
`darwin-configuration.nix` present blueprint builds a darwin system and folds
the user in as a module, without it the same user file is only a standalone
configuration
([lib/default.nix#L300-L343](https://github.com/clo4/blueprint/blob/b033f96062fd91c024f6a04ee2cbf7c168a28a6e/lib/default.nix#L300-L343)).
And the same user module tree works unmodified under both, because the
Darwin-specific bits are `lib.mkIf pkgs.stdenv.isDarwin` in a shared file
rather than nix-darwin options
([darwin.nix#L1-L11](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/users/robert/darwin.nix#L1-L11)).
Our doc's implicit assumption that one module tree can serve both a
nix-darwin Mac and a standalone-HM Mac is confirmed by a working example.

**What the repo prices for us.** Our Problem B table lists what standalone HM
gives up as "system defaults, LaunchDaemons, the homebrew module,
nix-homebrew". This repo adds three concrete items that table does not have:

| Cost on the standalone Mac | Evidence |
| --- | --- |
| `targets.darwin.*` is the only defaults lever, and here it silently did not work. The FIXME was never closed. | [macbook-air#L17-L24](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/macbook-air/users/robert/home-configuration.nix#L17-L24) |
| `PATH` ordering. Standalone HM does not own `/etc/paths`, so the login shell reconstructs `PATH` with Nix entries at the tail. The fix was a hand-written fish loop prepending every `$NIX_PROFILES` bin dir, added in commit `15ed6067` ("Fix shell init on standalone home manager system"). | commit `15ed6067` |
| Shell init placement. Standalone HM injects Nix setup into `.zshrc` rather than `.zshenv`, which changes which file can hold unconditional setup. | [config/zsh/.zshrc#L8-L15](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/config/zsh/.zshrc#L8-L15) |
| No system-level `nix.buildMachines`, so remote builders must be configured by hand. | [macmini#L26-L35](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/macmini/darwin-configuration.nix#L26-L35) |

Our doc should add those four rows to the Problem B table's "gives up"
column. The PATH one in particular is a real papercut we would hit on day
one, and our `zprofile` `path=(...)` contract
(root `CLAUDE.md`, "Shell Startup") assumes we control the ordering.

**Where the evidence is weaker than the brief assumed.** Three caveats, and
they matter:

1. This repo's *work* Mac is the nix-darwin one, and there is no sign of MDM
   on it. It has a standing admin account, root-owned `/etc/ssh` drop-ins,
   and `trusted-users = [ "@admin" ]`. Our Problem B is specifically about a
   Jamf tenant with no standing admin. This repo is not evidence about that
   constraint either way.
2. The standalone-HM *Mac* is retired
   ([README.md#L35-L36](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/README.md#L35-L36)),
   and it was the secondary machine. The live standalone host is Linux.
3. The rationale is unrecorded. The one commit that mentions standalone HM
   is a bug fix, not a decision.

**Verdict on our Problem B conclusion.** It holds, and does not need to
change direction. The prior doc's ordering (standalone HM before nix-darwin,
options 3 then 4) is unaffected. But our doc currently under-prices the
standalone-HM shape's shell and defaults costs, and it should say so.
Concretely: add the four rows above, and add a sentence saying that the one
public repo running both shapes on Macs never got `targets.darwin` defaults
working on the standalone one. Our doc should not claim this repo validates
standalone HM under MDM, because it never tested that.

### 5.2 Composition model

Our doc's native target is app modules composed by role modules composed by
hosts, with typed options replacing the data layer. This repo agrees with the
direction and contradicts the granularity.

Agrees: there is no data layer, no resolver, and no `machine_type`. Host
policy is committed, selected by which flake attribute you switch to
([lib/default.nix#L300-L343](https://github.com/clo4/blueprint/blob/b033f96062fd91c024f6a04ee2cbf7c168a28a6e/lib/default.nix#L300-L343)).
That is our doc's open question 6 answered the same way. Typed options do
appear where the author wanted structure, and they are small: `my.config`
has three options
([my-config.nix#L16-L48](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/modules/home/my-config.nix#L16-L48)),
`my.programs.neovim` has two plus a submodule
([my-programs-neovim.nix#L56-L65](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/modules/home/my-programs-neovim.nix#L56-L65)).

Contradicts: there is no `modules/apps/<app>.nix` layer at all. Six modules
total, and only one of them (`system-defaults`) is app-adjacent. Per-app
ownership is not the unit; the unit is the shared user file plus per-host
overrides. And there is exactly one role module,
`work-configuration.nix`, used by two users.

The honest reading is that this repo is too small to test our composition
model. Six hosts, one human, eighteen linked config paths. Our doc's app
modules exist to make an eleven-to-thirteen-file-per-app problem go away;
this repo never had that problem because it never split app config across a
data layer, a gate template, an ignore file, and a merge stub. It reached the
same "no resolver" endpoint by not building one, which is not the same as
proving a resolver can be decomposed away. No change to our doc from this.

One pattern is worth stealing regardless: blueprint's folder-to-output
convention removes the `hosts.nix`/`checks.nix` glue our tree diagram budgets
for under `modules/flake/`. We would still want explicit checks, because
blueprint skips standalone HM configs (section 4).

### 5.3 The "what disappears" table

The rows this repo speaks to:

| Our row | This repo | Should our doc change? |
| --- | --- | --- |
| `features.tmpl` resolver and layered `machines*.toml` gone | Confirmed absent. Host imports only. | No |
| Cask gates gone, app module owns package and config | Not evidence. They have no cask declarations at all. | No |
| `run_onchange_` gone, derivations and `onChange` carry inputs | Zero `onChange` uses. They achieve the same by having no side effects to trigger. | No, but see 5.5 |
| First-run prompts gone, host policy committed | Confirmed. `--flake .#<user>@<host>`, elidable when username and hostname match ([folder-structure.md#L192-L196](https://github.com/clo4/blueprint/blob/b033f96062fd91c024f6a04ee2cbf7c168a28a6e/docs/folder-structure.md#L192-L196)) | No |
| Drift banner gone, replaced by generations and `nix store diff-closures` | Contradicted in practice. They rebuilt a drift banner by hand, in fish, from three session variables. | Yes: our row 38 should note that a working repo found closure diffs insufficient and re-implemented an apply-freshness check |
| Brewfile renderer gone, `homebrew.brewfile` is module output | Not evidence. Homebrew content stays imperative here. | No |
| Plist modify stubs gone for domains written through `defaults` | Weak support: twelve keys, typed only. No evidence about domains an app rewrites. | No |

### 5.4 The per-app ownership table

No overlap. This repo manages none of the nine apps in our table, and manages
no app-rewritten structured config by any mechanism.

What it does add is a *fourth tier* our Problem A design does not list. Our
three tiers are: use the app's own layer, go through `defaults`, or keep the
merger as activation. This repo's answer is tier zero: point an out-of-store
symlink at the working tree, let the app write there, and `.gitignore` what
it writes. That trades the store's immutability for the app's edit loop.

The cost is visible and worth recording, because it is the reason our doc
rejected `mkOutOfStoreSymlink` for co-owned files:

- The app's writes land in the git checkout, so the repo needs per-directory
  ignore rules (`config/fish/.gitignore`, `config/zsh/.gitignore`,
  `config/helix/.gitignore`, `config/kitty/.gitignore`).
- The bootstrap case, where `my.config.directory` is still the store path,
  breaks noisily
  ([home-configuration.nix#L124-L128](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/users/robert/home-configuration.nix#L124-L128)),
  which is why the greeting warns about it
  ([fish_greeting.fish#L17-L30](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/config/fish/functions/fish_greeting.fish#L17-L30)).
- Directory-level links are not recursive, so nothing else can be placed
  inside a linked directory
  ([work-macbookpro/users/robert/home-configuration.nix#L21-L27](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/work-macbookpro/users/robert/home-configuration.nix#L21-L27)).
- Rollback is gone for that content. A generation rollback restores the link,
  not the file it points at. Unverified here, but it follows from the design
  and the README says as much by calling the link declarative and the content
  not
  ([README.md#L7](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/README.md#L7)).

Our doc should change here. Problem A currently reads as though the three
tiers are exhaustive. Add tier zero with those four costs and a one-line
verdict: acceptable for files we hand-edit constantly and never need to roll
back, wrong for the twelve plists and the six surviving mergers. Note the
crossover: our repo already treats a handful of paths this way through
`symlink_` live links (row 4), so tier zero is a widening of an existing
practice, not a new one.

### 5.5 Problem A more broadly

The `force = true` default is direct evidence about the hazard our doc names.
`my.config.force` defaults to true and its description is "Whether the
configuration links should override whatever exists already"
([my-config.nix#L41-L47](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/modules/home/my-config.nix#L41-L47)).
Our doc quotes home-manager's own warning that `force` "will silently delete
the target". This repo ships that as the default for every managed path,
which is only safe because every managed path is a link back into the repo.
Worth a sentence in Problem A: `force` is safe under tier zero and dangerous
under tier 1 through 3, and the distinction is whether the link target is
mutable.

The nix-darwin hosts also set `home-manager.backupFileExtension = "hm-backup"`
([work-macbookpro#L41](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/work-macbookpro/darwin-configuration.nix#L41),
[macmini#L47](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/macmini/darwin-configuration.nix#L47)),
and the standalone hosts set nothing, so they hard-fail on a clobber. Our row
40 is right and this is a live example of the asymmetry.

### 5.6 Problem C

This repo picked the option our doc rejected, and the tradeoff is exactly the
one our doc predicted. agenix ciphertext is committed to a repo whose README
declares it public domain
([README.md#L3](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/README.md#L3);
[secrets.nix#L22-L31](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/secrets.nix#L22-L31)).
Nothing is read at evaluation time except SSH *public* keys
([secrets.nix#L1-L20](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/secrets.nix#L1-L20)),
so the store-leakage rule holds.

Two things our doc should take:

1. The recipient model is nicer than a flat key list. Per-host, per-user
   pubkeys committed alongside each host, grouped into named sets
   (`robert-personal`, `robert-work`, and the union). Adding a machine is
   adding a file and one line. If we ever adopt a commit-encrypted backend,
   copy this shape.
2. Importing the agenix module at the *home-manager* layer rather than the
   darwin layer is what makes the same secret declaration portable across
   nix-darwin, standalone HM on macOS, and standalone HM on Linux
   ([work-macbookpro#L11-L14](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/work-macbookpro/users/robert/home-configuration.nix#L11-L14),
   [pc3#L9-L12](https://github.com/clo4/nix-dotfiles/blob/7d184d422d43577e7eaf8bccb09feed19e94340b/hosts/pc3/users/robert/home-configuration.nix#L9-L12)).
   Our doc's recommended target (`op read` in an HM activation block) already
   sits at the HM layer, so this corroborates the choice. It also means the
   Problem B split does not fork the secrets design.

Our Problem C conclusion does not change. The 1Password-refs-only policy is
still the right one for us because our repo is private-adjacent but our
secrets are personal licenses, not machine credentials. This repo is a clean
counter-example of what the alternative costs: a public repo full of
ciphertext, and per-recipient key management as a permanent chore.

### 5.7 The test surface

Two findings, one of which changes a bullet in our doc.

The `nix flake check` bullet is confirmed and should be sharpened. Our doc
says the check does not touch `darwinConfigurations` or `homeConfigurations`,
so both must be exposed explicitly. Blueprint already exposes
`darwinConfigurations` and `nixosConfigurations` as checks
([lib/default.nix#L543-L554](https://github.com/clo4/blueprint/blob/b033f96062fd91c024f6a04ee2cbf7c168a28a6e/lib/default.nix#L543-L554))
but deliberately puts standalone home configurations under `legacyPackages`
so the home-manager CLI can find them
([lib/default.nix#L489-L495](https://github.com/clo4/blueprint/blob/b033f96062fd91c024f6a04ee2cbf7c168a28a6e/lib/default.nix#L489-L495)).
The practical consequence for us: if the work Mac and the DevPod are
standalone HM, they are the two hosts a naive `nix flake check` will silently
skip, and they are also the two hosts we most need covered. Our doc's line
`checks.<system>.<user> = self.homeConfigurations.<user>.activationPackage`
is therefore not optional boilerplate; it is the difference between covering
our riskiest hosts and covering none of them. Say that explicitly.

The drift bullet needs a caveat. Our doc treats generations plus
`nix store diff-closures` as the replacement for `chezmoi status` and accepts
the per-file loss. This repo, with no tests and a much smaller surface, still
found that insufficient and hand-rolled `run check-applied` plus two shell
warnings. That is weak evidence, one data point, but it points the same way
as our row 38 "partial" verdict. Keep the verdict, add the observation.

### 5.8 Open questions

| Q | Effect |
| --- | --- |
| 2 (does a running app overwrite a `defaults` write) | Not answered. This repo writes twelve keys and never tested it. |
| 3 (Jamf media restriction, endpoint agent) | Not answered. No MDM here. |
| 6 (machine-local override not needed) | Reinforced. Six hosts, all policy committed, no local override anywhere. |
| 7 (is Homebrew fully declarative per host) | Reframed. This repo shows a third setting: install Homebrew declaratively with nix-homebrew, declare nothing in it, and let `brew` stay imperative. Our question assumes a binary between `cleanup = "uninstall"` and not. Add the "declare nothing" option, which is what a work host that must tolerate IT-installed casks probably wants. |
| 11 (which plist domains are safe for whole-domain import) | Not answered. Typed options only. |
| 14 (which apps allow disabling persistence) | Reframed by tier zero. If the file lives in the working tree, the app can persist freely and we still keep a reviewable source of truth. New question: for which of our six surviving mergers is tier zero acceptable? |
| 16 (can the work Mac write root-owned managed paths) | Not answered. |
| New | Does a standalone-HM Mac get correct `PATH` ordering without a shell-side fix, and does `targets.darwin.currentHostDefaults` work at all? Both are unresolved in this repo's history. |

## 6. What To Take, What To Avoid

### Take

- **The one-file host shape.** Deleting `darwin-configuration.nix` is the
  entire nix-darwin-to-standalone switch. Design our host layer so the same
  is true, which means keeping Darwin-only options out of the shared user
  tree and behind `lib.mkIf pkgs.stdenv.isDarwin` or a separate darwin module.
  That keeps Problem B a reversible decision rather than a fork.
- **agenix at the home-manager layer, with per-host recipient files.** Even
  if we stay on `op read`, put the secrets module at the HM layer so the work
  Mac's shape does not change it.
- **`my.config`-style tier zero, scoped.** A tiny typed option that maps
  target paths to working-tree-relative paths is 59 lines and it buys back
  the edit loop for files we hand-tune. Worth having for editors and shell
  config even if everything else is store-managed.
- **Blueprint's folder-to-output convention**, or at least the idea. It
  deletes the glue our tree diagram budgets for.
- **`NIX_CONFIG_REV` / `NIX_CONFIG_LAST_MODIFIED` as session variables.** A
  cheap, honest replacement for the drift banner's "is what is applied what
  is committed" question.

### Avoid

- **Tier zero as the default for everything.** It gives up rollback for all
  config content, puts app writes in the git tree, and needs per-directory
  ignore rules. Fine for a handful of paths, wrong as a policy.
- **`force = true` as a module default.** Safe only when every target is a
  link into a mutable checkout.
- **Zero activation as a goal.** This repo reached it by having no
  reconcilers. We have brew bundle, fork swaps, goku, Raycast builds, plugin
  records, and launchd agents. Their number is not reachable and chasing it
  would mean dropping capability.
- **A single-input nightly lock bump as the whole of CI.** It bumps one of
  twenty inputs, it has been failing since at least August, and nothing
  noticed. If we automate lock bumps, gate them on a build.
- **Runtime shell warnings instead of tests.** They only fire for a human at
  an interactive prompt.

### Relevance: 3 out of 5

It earns the 3 on one axis and loses points on three others.

It earns it because it is the only public repo in the set that has actually
run nix-darwin and standalone home-manager on Macs from a shared module tree,
and because the mechanics of that split are visible in fifteen lines of
`run.fish` and one absent file. It also supplies four concrete standalone-HM
costs our Problem B table is missing, including one (`targets.darwin`
defaults not working) that is a genuine unresolved risk rather than a
theoretical one. And its tier-zero config model is a real design option our
doc does not consider, complete with the accommodations it forces.

It loses points because the standalone Mac is retired and was the secondary
machine, because its work Mac is the nix-darwin one with no MDM in sight, so
it says nothing about our hardest constraint, and because its scale is two
orders of magnitude below ours on the surfaces that hurt: zero merge targets
against our twenty-two, zero activation blocks against our twenty-four apply
scripts, zero declared casks against our fifty-eight, and zero tests against
our sixty-four. On the composition model, the per-app ownership table, and
Problems A and C it is a counter-example rather than a corroboration, which
is useful but is not the same as evidence for.

## 7. Scorecard Against Our Concept Map

Rows from Appendix A of [nix-target-state-research.md](../nix-target-state-research.md).

| Row | Verdict | Note (five words) |
| ---: | --- | --- |
| 1 | Alternative | Out-of-store links, not store |
| 2 | Supports | Secrets tool, not file mode |
| 4 | Supports | `mkOutOfStoreSymlink` as primary mechanism |
| 5 | Supports | `isDarwin` conditionals replace templates |
| 6 | Supports | Flake attribute, elidable per host |
| 7 | Supports | No local override anywhere |
| 8 | Alternative | Imports, no layering at all |
| 9 | Contradicts | nix-darwin without declaring Homebrew |
| 11 | Alternative | Homebrew contents left fully imperative |
| 13 | Supports | nix-homebrew owns prefix, both Macs |
| 15 | Alternative | Plugins pinned as fetchFromGitHub derivations |
| 16 | Supports | Gates eliminated by direct imports |
| 19 | Contradicts | Zero `onChange`; no triggers needed |
| 20 | Contradicts | Zero activation blocks, six hosts |
| 23 | Supports | Twelve typed keys, no merging |
| 24 | Alternative | Working-tree links dissolve merge problem |
| 26 | Supports | Typed domains suffice when tiny |
| 27 | Supports | sudo darwin-rebuild, bare home-manager |
| 34 | Supports | mise kept, shims prepended manually |
| 35 | Supports | Two zshenv files, standalone gotcha |
| 37 | Alternative | agenix ciphertext in public repo |
| 38 | Supports | Hand-rolled drift check still needed |
| 40 | Supports | backupFileExtension only on darwin hosts |
| 41 | Supports | Standalone HM works on CachyOS |
| 42 | Supports | Checks skip standalone home configurations |
