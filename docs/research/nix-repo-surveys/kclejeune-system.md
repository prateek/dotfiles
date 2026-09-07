---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-04
updated: 2026-09-04
related:
  - ../nix-target-state-research.md
  - ../nix-migration-research.md
status_detail: "Agent survey of kclejeune/system at e46891e71bc549dccaaf6537f631576a9cfb5d48, compared with the Nix target-state doc. Unreviewed."
---

# Survey: kclejeune/system

## Method

Read on 2026-09-04 against a pinned tarball of
[kclejeune/system](https://github.com/kclejeune/system) at commit
`e46891e71bc549dccaaf6537f631576a9cfb5d48`, extracted to
`/tmp/nix-surveys/kclejeune-system`. Every permalink below points at that sha.

Files opened in full: `README.md`, `AGENTS.md`, `flake.nix`, `default.nix`,
`shell.nix`, `.envrc`, `.sops.yaml`, `.github/workflows/build.yml`,
`.github/workflows/update.yml`, `.github/dependabot.yml`, `modules/_lib.nix`,
all five files under `modules/shared/` that carry composition logic
(`lib.nix`, `identity.nix`, `primary-user.nix`, `common-base.nix`,
`nixpkgs-wiring.nix`, `nix-caches.nix`, `site.nix`, `theme.nix` head),
`modules/profiles/personal.nix`, all five `modules/darwin/*.nix`, and the
home modules that carry file or activation mechanics (`default.nix`,
`dotfiles.nix`, `launchd.nix`, `desktop-flag.nix`, `1password.nix`,
`shell.nix`, `nixpkgs.nix`, `email.nix`, `dev.nix` head, `git.nix` grep,
`nvim.nix` head, `weave.nix` head, `hyprland.nix` activation and helper
regions). Read partially: `modules/nixos/host-baseline.nix`, `comin.nix`,
`caddy-lan.nix` secret plumbing. Repo-wide greps for `activation`,
`onChange`, `mkOutOfStoreSymlink`, `force`, `backupFileExtension`,
`CustomUserPreferences`, `targets.darwin`, `masApps`, `onActivation`,
`launchd.`, `sops`, `checks`, and `hostName`.

Repo metadata came from the GitHub API on 2026-09-04. Comparison targets are
[nix-target-state-research.md](../nix-target-state-research.md) and
[nix-migration-research.md](../nix-migration-research.md).

Not read: the ~40 NixOS service modules for the homelab fleet
(`gateway.nix`, `traceway.nix`, `monitoring-stack.nix`, and peers) beyond
their secret handling, the `pkgs/` package definitions, `terraform/`, and the
non-Nix assets under `modules/home/assets/`. Nothing in this report depends
on them.

## 1. What It Is

Kennan LeJeune's personal system configuration repo. Created 2020-07-02, 530
stars, 41 forks, last pushed 2026-09-04. GitHub describes it as "Declarative
system configurations using nixOS, nix-darwin, and home-manager".

| Fact | Value |
| --- | --- |
| `.nix` files | 90 |
| Platform classes | NixOS, nix-darwin, standalone home-manager |
| `nixosConfigurations` | 7 (`phil`, `wally`, `gateway`, `haven`, `forge`, `vault`, `atlas`) |
| `darwinConfigurations` | 1 attr, `kclejeune@aarch64-darwin` |
| `homeConfigurations` | 3, `kclejeune@{x86_64-linux, aarch64-linux, aarch64-darwin}` |
| Systems declared | 4 |
| Commits in the 90 days to 2026-09-04 | at least 100 (API page cap) |
| Test directory | none |

Two of the seven NixOS hosts are marked scaffolding only
([flake.nix#L290-L291](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/flake.nix#L290-L291),
[#L310-L311](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/flake.nix#L310-L311)).
Five of them are headless and are wired into `deploy-rs`
([#L334-L357](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/flake.nix#L334-L357)).

Lock bumps happen three ways. Dependabot runs the `nix` ecosystem daily and
batches inputs into a `nixpkgs` group and a `dev` group
([dependabot.yml#L9-L47](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/.github/dependabot.yml#L9-L47)).
A `DeterminateSystems/update-flake-lock` workflow exists but its cron is
commented out, so it is manual only
([update.yml#L3-L8](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/.github/workflows/update.yml#L3-L8)).
The five headless hosts then pull the merged result themselves: `comin` polls
master every 60 seconds and switches
([comin.nix#L1-L22](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/nixos/comin.nix#L1-L22)),
with signature verification that has to trust both the author's SSH signatures
and GitHub's web-flow PGP key because Dependabot merges land under the latter
([#L36-L57](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/nixos/comin.nix#L36-L57)).
The eight most recent commits before the survey sha are almost all Dependabot
group bumps.

## 2. Composition

The README calls the layout the "dendritic pattern" on top of `flake-parts`
([README.md#L8-L18](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/README.md#L8-L18)).
`vic/import-tree` pulls every `.nix` file under `modules/` into the flake, and
each file registers itself as a named entry under
`flake.<class>Modules.<name>`
([flake.nix#L120-L136](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/flake.nix#L120-L136)).
Underscore-prefixed files are skipped by `import-tree`, which is how
`modules/_lib.nix` stays a plain library
([AGENTS.md#L169-L172](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/AGENTS.md#L169-L172)).
`flake.darwinModules` and `flake.lib` are declared as options inline in
`flake.nix` because upstream flake-parts does not declare them
([#L137-L150](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/flake.nix#L137-L150)).

### The four composition primitives

| Primitive | What it does | Where |
| --- | --- | --- |
| `mkAspect` | Registers one module body under `nixosModules`, `darwinModules`, and `homeModules` in a single call. `os` is shorthand for "same body on both system classes". | [_lib.nix#L17-L50](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/_lib.nix#L17-L50) |
| `hm` alias option | `mkAliasDefinitions` forwards `config.hm.*` to `home-manager.users.<primary>.*`, so a system module can write `hm.programs.foo.enable = true`. | [primary-user.nix#L18-L33](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/shared/primary-user.nix#L18-L33) |
| `identity` option set | Typed `name`, `displayName`, `email`, `sshKeys`, `sshSigningKey`, `enableRootSshKeys`, gated behind `identity.enable`, forwarded to the home-manager side. | [identity.nix#L15-L108](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/shared/identity.nix#L15-L108) |
| `desktop.enable` flag | One boolean home-manager option set by the NixOS desktop module and by every Darwin host, read by dotfiles and app modules. | [desktop-flag.nix#L4-L11](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/desktop-flag.nix#L4-L11) |

### How hosts are declared

Inline in `flake.nix`, as literal module lists. `AGENTS.md` states this
explicitly: "Hosts are defined inline in `flake.nix`, not as separate files"
([AGENTS.md#L139-L152](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/AGENTS.md#L139-L152)).
A NixOS host is a stack of named modules plus a small inline block for the
hostname and any host-only home-manager overlay
([flake.nix#L160-L187](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/flake.nix#L160-L187)).
There is no data file, no resolver, and no machine-type value read at
evaluation time anywhere in the repo.

Identity lives in exactly one place. `modules/profiles/personal.nix` holds the
literal name, email, and SSH keys as a `let` binding and feeds them into the
`identity` options for all three classes through `mkAspect`
([personal.nix#L8-L59](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/profiles/personal.nix#L8-L59)).
Site-wide constants (tailnet domain, Cloudflare account, LAN CIDR) get the
same treatment in `modules/shared/site.nix`, exposed both as `config.site.*`
for modules and `flake.lib.site` for consumers that are not NixOS modules
([site.nix#L8-L42](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/shared/site.nix#L8-L42)).

### Work vs personal, laptop vs server

Work vs personal is not expressed. `profiles/` contains one file, and the
README says so ("currently only `personal.nix` exists",
[README.md#L63-L69](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/README.md#L63-L69)).
The discipline exists in anticipation: `AGENTS.md` explains that personal GUI
apps go in `nixosModules.personal-apps` rather than `profile-personal`
specifically to keep "a future work-desktop host clean"
([AGENTS.md#L299-L305](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/AGENTS.md#L299-L305)).
There is one Darwin config for all Macs, keyed `kclejeune@<system>` rather
than by hostname
([flake.nix#L359-L378](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/flake.nix#L359-L378)).

Laptop vs server is expressed twice. Coarsely, by which feature modules a
host imports (`desktop`, `personal-apps`, `homelab-node`, `gateway`,
`server-base`). Finely, by the `desktop.enable` boolean, which gates terminal
configs, the email client, and roughly 5 GiB of language servers on the
headless host
([dotfiles.nix#L56-L74](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/dotfiles.nix#L56-L74),
[email.nix#L13](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/email.nix#L13),
[nvim.nix#L29-L33](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/nvim.nix#L29-L33)).

### Reusing home config across NixOS and Darwin

`modules/shared/common-base.nix` does the whole job in one line:
`hm.imports = [ flakeCfg.flake.homeModules.default ]`
([common-base.nix#L32-L44](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/shared/common-base.nix#L32-L44)).
The same `homeModules.default` is also instantiated standalone for three
systems through `home-manager.lib.homeManagerConfiguration`
([flake.nix#L380-L420](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/flake.nix#L380-L420)).
`modules/_lib.nix` centralizes the nixpkgs args so the embedded and standalone
paths cannot drift
([_lib.nix#L6-L15](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/_lib.nix#L6-L15)).

### The trap worth stealing

Flake-parts wraps module values with unique `_file` annotations each time they
are referenced, so Nix's identity-based import dedup does not fire. Two
transitive references to the same named module cause option conflicts for any
scalar option it sets. The repo's rule is that each reusable module must be
imported exactly once per host
([AGENTS.md#L178-L186](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/AGENTS.md#L178-L186)).
This is a direct constraint on any roles-import-apps design.

## 3. Per-App Config Mechanics

### programs.* dominates

The repo is `programs.*` almost everywhere. `homeModules.default` alone
enables roughly two dozen programs in one block
([default.nix#L47-L114](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/default.nix#L47-L114)).
Across all of `modules/`, there are 2 `home.file` sites and 4
`xdg.configFile` / `xdg.dataFile` sites. Everything else goes through a
home-manager or nix-darwin module option.

### Files the app also writes

There is no merge machinery anywhere in this repo. No Python merger, no
`jq`-based reconciler, no key-level plist merge. Instead there are four
distinct strategies.

| Strategy | Applied to | Mechanism |
| --- | --- | --- |
| Out-of-store symlink into the checkout | hammerspoon, raycast scripts, aerospace, kitty, `zed/keymap.json`, vicinae | `config.lib.file.mkOutOfStoreSymlink` against `config.dotfiles.path`, which defaults to `~/.nixpkgs/modules/home/assets/dotfiles` ([dotfiles.nix#L13-L74](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/dotfiles.nix#L13-L74)) |
| Clobber and dump | noctalia `settings.json`, `plugins.json` | Activation `rm -f` then `install -m 644` from the store on every switch. The comment declares `settings.json` ephemeral and always replaced. Runtime drift is recovered by `noctalia-settings-dump` piped back into the committed asset ([hyprland.nix#L664-L690](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/hyprland.nix#L664-L690), [#L896-L925](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/hyprland.nix#L897-L928)) |
| Include the mutable file | git | `programs.git.includes = [ { path = "~/.gitconfig"; } ]`. Nix owns the generated config and delegates to the user's own file ([git.nix#L53](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/git.nix#L53)) |
| Symlink to the app's own runtime path | 1Password SSH agent socket | `mkOutOfStoreSymlink` to the Group Container socket, then `programs.ssh.settings."*".IdentityAgent` ([1password.nix#L10-L24](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/1password.nix#L10-L24)) |

Backing all of it, `home-manager.backupFileExtension = "backup"` is set for
every NixOS and Darwin host
([common-base.nix#L39-L44](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/shared/common-base.nix#L39-L44)).
That is the standing admission that the "would be clobbered" error is a
routine operational fact, not an edge case.

Only four activation blocks exist in the whole repo, all of them in the
Hyprland home module, all `lib.hm.dag.entryAfter [ "writeBoundary" ]`, all
`$DRY_RUN_CMD`-wrapped
([hyprland.nix#L672-L697](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/hyprland.nix#L672-L697)).
There is no use of `home.file.<name>.onChange` anywhere.

### macOS defaults

nix-darwin's typed `system.defaults` only, 66 lines total, covering
`loginwindow`, `finder`, `trackpad`, `spaces`, `dock`, `NSGlobalDomain`, plus
`system.keyboard`
([preferences.nix#L3-L64](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/darwin/preferences.nix#L3-L64)).
No `CustomUserPreferences`, no `CustomSystemPreferences`, no
`targets.darwin.defaults`, and no per-application preference domain is managed
at all. Grepped repo-wide, zero hits.

### Casks, MAS, taps

nix-darwin's built-in `homebrew` module, split across two darwin modules. The
base module carries 4 taps, 2 brews, and 16 casks and is imported by
`darwinModules.default`
([brew.nix#L3-L40](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/darwin/brew.nix#L3-L40),
[default.nix#L17-L28](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/darwin/default.nix#L17-L28)).
The `apps` module carries 11 more GUI casks and is enrolled at host level
rather than in the base
([apps.nix#L3-L18](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/darwin/apps.nix#L3-L18),
[flake.nix#L367-L375](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/flake.nix#L367-L375)).

Three things are notable by absence.

- `masApps = { }` is empty
  ([apps.nix#L17](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/darwin/apps.nix#L17)).
- `nix-homebrew` is not an input, so Homebrew itself is installed outside Nix
  and taps are not pinned.
- `homebrew.onActivation.cleanup` is never set. The only `onActivation` key in
  the repo is `extraEnv.HOMEBREW_NO_REQUIRE_TAP_TRUST = "1"`, added because
  activation runs `brew bundle` under sudo with a sanitized environment
  ([brew.nix#L6-L10](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/darwin/brew.nix#L6-L10)).
  Homebrew is therefore additive only. Nothing uninstalls a cask that leaves
  the list.

### launchd

One darwin agent, `launchd.user.agents.syncthing`, in a module that is
registered but not imported by any host in this snapshot
([syncthing.nix#L36-L53](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/darwin/syncthing.nix#L36-L53)).
On the home-manager side there is a three-line module whose only job is to
default `launchd.agents.<name>.domain` to `"gui"`
([launchd.nix#L5-L11](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/launchd.nix#L5-L11)).

### Secrets

sops-nix, and only on NixOS. It is pulled in by `host-baseline`, which every
NixOS host imports and no Darwin host does
([host-baseline.nix#L6-L13](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/nixos/host-baseline.nix#L6-L13)).
Recipient keys are derived from each host's SSH host key via `ssh-to-age`, and
`.sops.yaml` scopes each encrypted file to only the hosts that need it
([.sops.yaml#L19-L74](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/.sops.yaml#L19-L74)).
Values reach services through `sops.templates` written to an
`EnvironmentFile`, with the rationale stated in a comment: "so the token never
hits the store"
([caddy-lan.nix#L141-L148](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/nixos/caddy-lan.nix#L141-L148)).
The user login password hash is a `neededForUsers` sops secret so decryption
precedes account creation
([personal.nix#L38-L48](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/profiles/personal.nix#L38-L48)).

On macOS there is no secrets management in Nix at all. The 1Password app owns
the material; Nix contributes the agent socket symlink, the `IdentityAgent`
setting, and the `op-ssh-sign` path for git signing
([1password.nix#L14-L36](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/1password.nix#L14-L36)).
The shell module exports `AGE_KEY_FILE`, `SOPS_AGE_KEY_FILE`,
`MISE_AGE_KEY_FILE`, and `FNOX_AGE_KEY_FILE` all pointing at
`$XDG_CONFIG_HOME/sops/age/keys.txt`, a file Nix never creates
([shell.nix#L21](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/shell.nix#L21),
[#L34-L38](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/shell.nix#L34-L38)).

### Root per switch

Everything nix-darwin implies. `determinateNix.enable = true` with
`nix.enable = false`, which is the shape Determinate requires, plus
`security.pam.services.sudo_local.touchIdAuth = true` to remove the password
prompt
([default.nix#L35-L62](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/darwin/default.nix#L35-L62)).
`determinateNix.customSettings.extra-trusted-users` lists `@admin`, `@root`,
`@sudo`, `@wheel`, and `@staff`
([#L39-L52](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/darwin/default.nix#L39-L52)).
There is no MDM host here, so nothing in this repo tests the case where the
user is not in `admin`.

## 4. Testing And CI

There is no test directory, no `nmt`, and no module unit tests.

`checks` carries only deploy-rs schema and activation checks, and only on
`x86_64-linux`
([flake.nix#L630-L633](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/flake.nix#L630-L633)).
The actual build gate is a separate transposed per-system option,
`flake.cacheable.<system>`, holding every host toplevel, every home-manager
`activationPackage`, and the devShells. The comment says it exists so
`nix-fast-build` can target it "without dragging it into `checks`"
([#L126-L136](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/flake.nix#L126-L136),
[#L622-L629](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/flake.nix#L622-L629)).

CI is one workflow, a 3-system matrix on GitHub-hosted runners with
per-runner `eval-workers`, `eval-max-memory`, and `-j` tuned to the RAM
available, a 120-minute timeout, and a Linux disk-reclaim step
([build.yml#L13-L57](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/.github/workflows/build.yml#L13-L57)).
The build step is a single `nix-fast-build --flake .#cacheable.<system>
--skip-cached`, wrapped in `nimbus watch-exec` so results push to a private
binary cache
([#L83-L94](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/.github/workflows/build.yml#L83-L94)).

Formatting and linting run through `treefmt-nix` (deadnix, nixfmt, oxfmt,
ruff, shellcheck, shfmt, stylua) with a `git-hooks.nix` pre-commit hook using
`prek`
([flake.nix#L582-L620](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/flake.nix#L582-L620)).

Nothing boots a macOS VM. Nothing tests activation. The CI signal is "every
host's closure builds on three systems".

## 5. Compare And Contrast With Our Target-State Doc

### 5.1 App-module-plus-roles vs profiles-plus-shared

Our doc's composition model is right in direction and wrong in granularity.

What this repo confirms. Hosts compose named modules. There is no data layer,
no `machine_type` read at evaluation time, and no resolver. Typed options
(`identity`, `site`, `desktop.enable`) do the job our `machines.toml` layers
do today. That is eight machines run without any of the machinery our "What
disappears" table retires.

What it contradicts. Our doc says "The unit is the app module" and asserts
this is "how the surrounding ecosystem composes machines"
(nix-target-state-research.md, "Composition model"). This repo does not
compose by app. Its modules are feature-shaped and service-shaped, and the two
Homebrew lists are flat cask arrays with no relationship to any config module
([brew.nix#L22-L39](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/darwin/brew.nix#L22-L39),
[apps.nix#L4-L16](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/darwin/apps.nix#L4-L16)).
Installing a cask and configuring that app are still separate files, which is
the exact split our doc criticizes in the chezmoi layout. A 530-star,
daily-maintained repo that had every chance to converge on the app module did
not.

What it reframes. Their `profiles/` is not the role layer our doc's tree
implies. It is one file holding one identity
([README.md#L63-L69](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/README.md#L63-L69)).
The actual role work is done by ordinary feature modules sitting in the
platform directory. Naming a directory `profiles/` did not create a layer.

Doc change recommended. Soften "the unit is the app module" to a criterion:
app-shaped when the app owns both a package and config the repo cares about,
feature-shaped or service-shaped otherwise. Add the double-import trap
([AGENTS.md#L178-L186](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/AGENTS.md#L178-L186))
as a named constraint on the roles-import-apps design, because a diamond in
the import graph is a hard evaluation error, not a warning.

### 5.2 The "What disappears" table

| Our row | Verdict from this repo |
| --- | --- |
| `features.tmpl` resolver and layered `machines*.toml` | Supports. No equivalent exists; typed options and host imports carry it. |
| `package-cask-enabled.tmpl` and cask gates | Supports. Casks are plain module lists; enrollment is a host-level import. |
| Group union, dedupe, unknown-group validation | Supports by absence, but untested. Their cask lists are short enough that the validation never mattered. |
| `run_onchange_` hash lines | Supports in effect, but note they do not use `onChange` at all. Zero occurrences. Activation blocks did the work. |
| Brewfile renderer and golden tests | Supports the renderer going away. Contradicts the implied "tests move too": there is no Brewfile assertion of any kind. |
| Retired-package ledger | Contradicts the optimism. `onActivation.cleanup` is never set, so Homebrew drift is simply unmanaged. |
| Drift banner | Supports. Nothing here reports per-file drift, and nobody appears to miss it except for one app (see 5.7). |
| Plist modify stubs | Not evidence. They manage zero application plist domains. |
| First-run prompts and `machines_local` | Supports. Host policy is entirely committed, with no local override layer anywhere. |

### 5.3 The per-app ownership table

Our per-app table asks, for each app, "does it offer a layer Nix can own
outright?" and lands on three tiers. This repo has zero mergers, which is not
evidence the problem is solved. It is evidence that the mitigation menu is
larger than our three tiers, and that two more options are in production use.

**Fourth tier, clobber and dump.** Nix owns the file outright, activation
deletes and reinstalls it on every switch, and the repo ships a `dump` command
that captures runtime state back into the committed asset. Applied to
noctalia's `settings.json`, an app that actively writes back to the same file
([hyprland.nix#L672-L690](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/hyprland.nix#L672-L690),
[#L896-L925](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/hyprland.nix#L897-L928)).
The trade is explicit and documented: runtime mutations live until the next
switch. This does not require disabling the app's persistence, which is what
our open question 14 assumes is necessary.

**Fifth tier, include the mutable file.** Where the app supports an include
directive, Nix owns the generated file and points it at the user's mutable
one
([git.nix#L53](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/git.nix#L53)).
Our tier 1 covers layers that sit above or below the user file. This is the
inverse direction and it is cheaper than either.

**On `mkOutOfStoreSymlink`.** Our doc dismisses it in one clause:
"`mkOutOfStoreSymlink` into the repo checkout would make the app write into
the working tree." That is correct and this repo does it anyway, six times,
deliberately, for hammerspoon, kitty, aerospace, zed, vicinae, and raycast
([dotfiles.nix#L21-L74](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/dotfiles.nix#L21-L74)).
The workflow is edit-in-place then commit. Our doc should describe it as a
live option with a named cost rather than a disqualified one, and should state
the reason it is a poor fit for us specifically: our checkout is not at a
fixed path, because Orca worktrees move it.

Doc change recommended. Add tiers 4 and 5 to the Problem A design, and rewrite
the `mkOutOfStoreSymlink` clause to name our worktree constraint as the reason
we reject it rather than implying it is unworkable in general.

### 5.4 Problem A, files the app also writes

Supports the core diagnosis. `home-manager.backupFileExtension = "backup"` is
set globally
([common-base.nix#L43](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/shared/common-base.nix#L43)),
which is a repo declaring in advance that the clobber error is expected. No
merge primitive was found, confirming our doc's claim that none exists.

Reframes the design. See 5.3. Also note what does not exist here: any
equivalent of our `plist-merge` key-level preservation, any delete directive,
and any write-only-if-changed behavior. They accepted losing all three. Our
doc lists those three losses accurately, and this repo is a data point that
losing them is survivable when the config is small.

### 5.5 Problem B, the MDM-managed work Mac

No evidence either way. Every Mac here is one config, personal, with an admin
user. Nothing tests the Jamf path.

Two things it does confirm.

The Determinate shape our doc describes is the shape in production:
`nix.enable = false` with `determinateNix.enable = true`, plus
`touchIdAuth` for `sudo_local`
([default.nix#L35-L62](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/darwin/default.nix#L35-L62)).
Our doc's paragraph on that is right.

Standalone home-manager on `aarch64-darwin` is a maintained, first-class
output here, not a fallback
([flake.nix#L380-L420](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/flake.nix#L380-L420)).
That strengthens our doc's ranking (standalone HM before nix-darwin on the
work Mac): the same module tree serves both, so choosing HM-only on one host
costs module duplication of zero. Our doc says this; this repo proves the
mechanism at 90 files.

### 5.6 Problem C, secrets without store leakage

Supports the rule. Every secret path goes through sops templates or
`EnvironmentFile`, with the store-avoidance rationale written into the code
([caddy-lan.nix#L141](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/nixos/caddy-lan.nix#L141)).

Contradicts one framing. Our doc treats "encrypted secret blobs would live in
a public repo" as a policy shift away from "refs only". This repo does exactly
that in a 530-star public repo, and prices it with per-host age keys derived
from SSH host keys plus narrow `creation_rules` that scope each file to the
hosts that need it
([.sops.yaml#L19-L74](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/.sops.yaml#L19-L74)).
The objection is a preference, not a security fact. Our doc should say so and
separate the two real costs: an unencrypted age key on every machine, and the
loss of 1Password as the single vault.

Adds a fourth option our table lacks. On macOS this repo does not manage
secrets in Nix at all. It manages the path to the agent that holds them
([1password.nix#L14-L24](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/1password.nix#L14-L24)).
For our three license files that is not sufficient, since a license file is
material and not a socket. But for anything reachable through an agent or a
CLI session, "declare the socket, not the secret" belongs in the table.

### 5.7 The test surface

Strong independent support for one bullet and a better answer for another.

Our doc says "`nix flake check` is narrower than it looks" and that every host
must be exposed explicitly. This repo hit the same wall and solved it the
other way: `checks` keeps only the cheap deploy-rs schema checks, and the
expensive host and activation-package builds live in a separately transposed
`flake.cacheable.<system>` attribute driven by `nix-fast-build`
([flake.nix#L126-L136](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/flake.nix#L126-L136),
[#L622-L633](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/flake.nix#L622-L633)).
The comment names the motivation directly. Our doc proposes stuffing every
host into `checks`, which makes `nix flake check` unusable locally on a
laptop. The `cacheable` shape is better and we should adopt it.

Our doc's "module tests replace template golden tests" is aspirational, not
observed. This repo has zero module tests. It also has zero activation
testing, which supports our doc's conclusion that the Tart lane keeps its job.

One more thing this repo has that our doc does not anticipate:
`noctalia-settings-diff` is a hand-rolled, per-app diff between the store
derivation and the running app's IPC state
([hyprland.nix#L897-L910](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/hyprland.nix#L897-L910)).
That is the closest thing to our lost `chezmoi diff` preview found anywhere in
this survey, and it is per-app and hand-written. It confirms our doc's
"nothing shows a merge-result diff" claim while showing the workaround costs a
bespoke script per app.

### 5.8 Which of the 16 open questions this touches

| Q | Effect | Evidence |
| ---: | --- | --- |
| 2 (running app overwrites a `defaults` write) | No evidence. They manage six system domains and zero app domains. | [preferences.nix#L3-L64](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/darwin/preferences.nix#L3-L64) |
| 7 (is Homebrew fully declarative per host) | Reframed. The observed answer is no, by choice. `cleanup` is never set, so Homebrew is additive only. | [brew.nix#L3-L10](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/darwin/brew.nix#L3-L10) |
| 11, 12 (plist domain safety, values exceeding typed defaults) | No evidence. Their defaults set is small enough to stay entirely inside the typed surface. | as above |
| 14 (which apps allow disabling persistence so Nix can own the file) | Reframed. You do not need to disable persistence. Declare the file ephemeral, clobber it every switch, ship a dump command. | [hyprland.nix#L672-L690](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/hyprland.nix#L672-L690) |
| 1, 8, 9, 10, 13, 15 (agent CLIs, Raycast, Claude/Codex/Cursor/Yojam layers) | No evidence, and an implicit answer. `claude-code` and `codex` are installed as plain nixpkgs packages with no config management whatsoever. | [dev.nix#L32](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/dev.nix#L32), [#L35](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/dev.nix#L35) |
| 3, 4, 5, 16 (MDM, DevPod, 1Password service accounts, work-Mac managed paths) | No evidence. No MDM host, no headless macOS, no automated `op`. | |

One question this repo adds. Under a roles-import-apps layout on flake-parts,
how do you enforce that each app module is imported exactly once per host?
The double-import trap makes this a correctness requirement, and their answer
is a written convention with no mechanical check
([AGENTS.md#L178-L186](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/AGENTS.md#L178-L186)).

### 5.9 Two rows our doc treats as hard that this repo makes look easy

Row 15, zinit. They replaced a plugin manager with nixpkgs derivations linked
into an oh-my-zsh custom directory through `xdg.dataFile`, then listed the
plugin names in `programs.zsh.oh-my-zsh.plugins`
([shell.nix#L68-L91](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/shell.nix#L68-L91),
[#L122-L158](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/shell.nix#L122-L158)).
Freshness becomes a lock bump, which is exactly what our doc predicts under
"Weekly cadence".

Row 35, `ZDOTDIR`. `programs.zsh.dotDir = "${config.xdg.configHome}/zsh"` in
production, with a non-interactive `envExtra` block that sets
`NO_NOMATCH NO_EQUALS` for scripted shells
([shell.nix#L93-L120](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/shell.nix#L93-L120)).
That last detail is worth stealing on its own merits.

Row 34, mise. mise coexists with Nix here rather than being replaced:
`mise activate bash` in the bash init, the `mise` oh-my-zsh plugin, and
`MISE_ENV_FILE` in the session variables
([shell.nix#L34](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/shell.nix#L34),
[#L162-L167](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/modules/home/shell.nix#L162-L167)).
Our "keep mise, it is a policy call not a fidelity gap" row holds.

## 6. What To Take, What To Avoid, Relevance

### Take

1. **The `cacheable` transposed attribute plus `nix-fast-build`.** Keep
   `checks` cheap and put host toplevels and HM activation packages in a
   separate per-system attribute that CI builds. Strictly better than our
   doc's current proposal.
2. **`mkAspect`.** One helper that registers a single body under
   `nixosModules`, `darwinModules`, and `homeModules`. This is the concrete
   answer to our tree sketch's hand-wave that "each app module exports its
   nix-darwin and home-manager fragments".
3. **The `hm` alias option.** `mkAliasDefinitions` forwarding `config.hm.*`
   into `home-manager.users.<primary>.*` is what makes a single app module
   able to set both a system default and a home file.
4. **Clobber-and-dump as a Problem A tier.** For any config where losing
   runtime state between switches is acceptable, this removes a merger and
   replaces it with a `dump` command. Yojam is our obvious first candidate.
5. **Include layers where the app offers one.** `programs.git.includes` is
   the pattern.
6. **Grouped Dependabot on the `nix` ecosystem.** Two groups, `nixpkgs` for
   the channels that must move in lockstep and `dev` for plumbing. More
   reviewable than a blanket `nix flake update`.
7. **Per-host sops files keyed to SSH host keys**, if the homelab mini ever
   needs unattended secrets. This is the concrete shape our Problem C table
   describes abstractly.
8. **The non-interactive `envExtra` zsh guard.** Unrelated to Nix, correct
   regardless of what we do.

### Avoid

1. **Inline host definitions in `flake.nix`.** Theirs is 637 lines and most of
   it is host module lists plus overlay workarounds. Our doc's
   `modules/flake/hosts.nix` split is better and flake-parts supports it.
2. **`mkOutOfStoreSymlink` into the checkout as the default.** It works for
   them because the repo lives at a fixed `~/.nixpkgs`. Our checkout moves,
   because Orca creates worktrees.
3. **Zero test surface.** Their signal is "the closure builds". Our behavioral
   zsh tests, plist tests, and reconciler tests are an asset. Do not trade
   them for a build.
4. **The overlay as a patch dump.** `flake.overlays.default` carries five
   upstream workarounds, each with a "drop once upstream" comment
   ([flake.nix#L442-L502](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/flake.nix#L442-L502)).
   That is the standing tax of tracking `nixpkgs-unstable`, and it is real
   maintenance work someone has to do.
5. **Naming a directory `profiles/` and calling it a role layer.** One file
   with one identity is not a layer. If we build a role layer, it needs more
   than one role before we claim it works.

### Relevance: 3 of 5

High value on mechanics, low value on our binding constraints.

It is the best evidence I have seen for how to compose one home-manager module
tree across NixOS, nix-darwin, and standalone home-manager without
duplication, and its CI shape is directly better than what our doc proposes.
The `mkAspect` and `hm`-alias primitives are immediately usable. It reframes
two of our sixteen open questions and adds two tiers to the Problem A design.

It is close to silent on everything that makes our migration hard. There is no
MDM-managed host, so Problem B gets nothing. There is no macOS secret
management, so Problem C gets one reframing and no answer. There are no
application preference domains, no MAS apps, no Setapp, no merge into an
app-owned file, no agent CLI config, and no tests. Our 22 merges and our four
machine types have no counterpart here. The repo is one person, one identity,
mostly Linux servers, with a Mac that is comparatively simple.

Scoring it 4 would overweight the mechanics. Scoring it 2 would ignore that
the `cacheable` pattern and `mkAspect` are things we would otherwise have to
invent.

## 7. Scorecard Against Appendix A Rows

Rows from the 42-row concept map in
[nix-target-state-research.md](../nix-target-state-research.md), Appendix A.
Only rows where this repo provides actual evidence are listed. Rows 3, 12, 14,
18, 22, 25, 27, 29, 30, 31, 33 have no counterpart in this repo.

| Row | Verdict | Note |
| ---: | --- | --- |
| 1 | Supports | Two `home.file` sites only |
| 2 | Supports | Activation `install -m` sets mode |
| 4 | Supports | Six live out-of-store symlinks |
| 5 | Supports | Host facts are module options |
| 6 | Supports | Hosts are inline flake attributes |
| 7 | Supports | No host-local override layer exists |
| 8 | Supports | Module imports replace layered TOML |
| 9 | Supports | Flat cask lists, two modules |
| 10 | Supports | Large `home.packages` in dev.nix |
| 11 | Contradicts | Cleanup never enabled, drift unmanaged |
| 13 | Contradicts | No nix-homebrew, brew installed manually |
| 15 | Alternative | nixpkgs derivations into oh-my-zsh custom |
| 16 | Supports | One `desktop.enable` flag gates dotfiles |
| 17 | Supports | Casks are plain module attributes |
| 19 | Alternative | Activation blocks used, never `onChange` |
| 20 | Alternative | Idempotent clobber replaces once-only semantics |
| 21 | Supports | Four `entryAfter writeBoundary` blocks total |
| 23 | Alternative | Typed system domains only, zero apps |
| 24 | Alternative | Clobber-plus-dump replaces merging entirely |
| 26 | Supports | Sixty-six lines, six typed domains |
| 28 | Supports | One user agent plus domain default |
| 32 | Alternative | Hammerspoon symlinked raw, no build |
| 34 | Supports | mise activate coexists with Nix |
| 35 | Supports | `dotDir` set to `xdg.configHome/zsh` |
| 36 | Supports | `xdg.enable` plus `preferXdgDirectories` in use |
| 37 | Alternative | 1Password app owns macOS secrets |
| 38 | Alternative | Per-app diff command written by hand |
| 39 | Alternative | `noctalia-settings-diff` compares store against IPC |
| 40 | Supports | `backupFileExtension` set globally on hosts |
| 41 | Supports | Standalone homeConfigurations across three systems |
| 42 | Supports | `cacheable` attr built by nix-fast-build |

## Caveats

- The README describes `pkgs/{cb,fnox,weave}` but the directory holds
  `ashell`, `cb`, `sem-cli`, `traceway`, and `weave`. `perSystem.packages`
  still inherits `fnox` from `pkgs`
  ([flake.nix#L526-L534](https://github.com/kclejeune/system/blob/e46891e71bc549dccaaf6537f631576a9cfb5d48/flake.nix#L526-L534)),
  which presumably now resolves from nixpkgs. Unverified, and immaterial to
  this survey.
- `modules/darwin/syncthing.nix` registers a module no host imports in this
  snapshot. Treated here as dormant, not as evidence of a launchd pattern in
  active use.
- The 90-day commit count is a lower bound: the API page cap returned exactly
  100 results.
- Everything in section 3 about the absence of merge machinery rests on
  repo-wide greps for `activation`, `onChange`, `mkOutOfStoreSymlink`, and
  `force`. Not every one of the 90 files was read line by line.
