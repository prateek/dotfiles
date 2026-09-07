---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-04
updated: 2026-09-04
related:
  - ../nix-target-state-research.md
  - ../nix-migration-research.md
status_detail: "Agent survey of nmasur/dotfiles at 72c4f4823b6c6e173da44be7442328133a81e789, compared with the Nix target-state doc. Unreviewed."
---

# Survey: nmasur/dotfiles

## Method

Snapshot pinned at `72c4f4823b6c6e173da44be7442328133a81e789`, resolved with
`gh api repos/nmasur/dotfiles/commits/HEAD --jq .sha` and extracted to
`/tmp/nix-surveys/nmasur-dotfiles` on 2026-09-04. All permalinks in this doc
point at that sha.

Read in full: `README.md`, `docs/` (four files), `flake.nix`, `flake.lock`,
`lib/default.nix`, the sole darwin host, every `.nix` file under
`platforms/nix-darwin/modules/nmasur/presets/` and
`platforms/home-manager/modules/nmasur/{presets,profiles}/` that a darwin host
reaches, both `secrets.nix` files, the whole `platforms/windows/` tree, the
`platforms/generators/` tree, and all six `.github/workflows/` files. Sampled
the NixOS platform tree and the six Linux hosts. Grepped every `.nix` file in
the repo for `mkOutOfStoreSymlink`, `force = true`, `backupFileExtension`,
`onChange`, `launchd`, and agent-CLI names.

Repo-side reading: `docs/research/nix-target-state-research.md` in full,
`docs/research/nix-migration-research.md` sections "Options" and "Sizing",
`docs/references/chezmoi-architecture.md`, and `docs/document-lifecycle.md`.

## 1. What It Is

Noah Masur's personal Nix configuration, public since 2019-09-07, 262 stars,
last pushed 2026-08-30
([README.md#L1-L20](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/README.md#L1-L20)).

| Fact | Value |
| --- | --- |
| `.nix` files | 279 |
| Systems | `x86_64-linux`, `aarch64-linux`, `aarch64-darwin` ([lib/default.nix#L77-L81](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/lib/default.nix#L77-L81)) |
| Hosts | 7 total; exactly 1 darwin |
| Darwin host | `lookingglass`, a corporate work MacBook ([hosts/aarch64-darwin/lookingglass/default.nix#L1-L20](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/hosts/aarch64-darwin/lookingglass/default.nix#L1-L20)) |
| Linux hosts | `arrow`, `hydra`, `staff`, `swan`, `tempest` (x86_64), `flame` (aarch64) |
| Commits, last 12 months | 183, no dormant stretch; 31 in 2026-07 and 28 in 2026-08 |
| Flake inputs | 21 |

The author's context matters for reading the darwin half. `lookingglass` sets
`networking.hostName = "NYCM-NMASUR2"` and a `@take2games.com` git identity,
so the single Mac in this repo is an employer-issued laptop
([hosts/aarch64-darwin/lookingglass/default.nix#L21-L54](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/hosts/aarch64-darwin/lookingglass/default.nix#L21-L54)).
Whether that Mac is MDM-enrolled is not stated anywhere in the repo, so treat
it as unverified. Nothing in the tree references Jamf, Kandji, or a temp-admin
escalation.

The lock is bumped by a scheduled workflow, not by hand. `update.yml` runs
`cron: '33 3 * * 6'`, opens a PR with `DeterminateSystems/update-flake-lock@v23`,
runs `nix flake check`, then `gh pr merge --rebase --auto` on success or
`gh pr close --delete-branch` on failure
([.github/workflows/update.yml#L1-L71](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/.github/workflows/update.yml#L1-L71)).
The lock is nonetheless uneven: `nixpkgs` is pinned to 2026-05-26 while
`home-manager` and `nixpkgs-stable` sit at 2026-08-27
([flake.lock](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/flake.lock)).

Three API-derived claims were checked against `flake.nix` directly and all
three hold
([flake.nix#L1-L80](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/flake.nix#L1-L80)):

| Claim | Verdict | Evidence |
| --- | --- | --- |
| No meta-framework | Holds | No `flake-parts`, `snowfall-lib`, `flake-utils`, or `digga` input. Composition is hand-rolled in `lib/default.nix`. |
| No secrets tool in `flake.nix` | Holds | No `agenix`, `sops-nix`, `ragenix`, or `opnix` input. Secrets are hand-rolled. |
| No Homebrew module input | Holds | No `nix-homebrew` input. Homebrew is driven from a home-manager activation block. |

## 2. Composition

The composition engine is `lib/default.nix`, 252 lines, and it is the most
load-bearing file in the repo. The shape is directory auto-import, not
explicit module lists.

Hosts are discovered from the filesystem:
`hosts = forAllSystems (system: defaultFilesToAttrset ../hosts/${system})`
([lib/default.nix#L92](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/lib/default.nix#L92)).
Each builder then imports every `.nix` file under its platform directory:
`buildHome`
([#L127-L143](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/lib/default.nix#L127-L143)),
`buildNixos`
([#L145-L172](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/lib/default.nix#L145-L172)),
`buildDarwin`
([#L174-L200](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/lib/default.nix#L174-L200)),
and `generateImage`
([#L217-L250](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/lib/default.nix#L217-L250)).

The consequence is worth stating plainly. Every module for a platform is
imported into every configuration for that platform. Selection happens
entirely through `lib.mkEnableOption` plus `lib.mkIf` inside each module. There
is no "which modules does this host import" question, only "which options does
this host set to true."

| Platform dir | Consumed by | Adapter |
| --- | --- | --- |
| `platforms/nixos/` | `nixosConfigurations` | `buildNixos` |
| `platforms/nix-darwin/` | `darwinConfigurations` | `buildDarwin` |
| `platforms/home-manager/` | `homeConfigurations` | `buildHome` |
| `platforms/generators/` | `packages.<system>.<image>` | `generateImage` |
| `platforms/windows/` | nothing | none; see section 3 |

Features are named under three option prefixes. `nmasur.settings.*` carries
identity, `nmasur.presets.*` carries individual capabilities, and
`nmasur.profiles.*` bundles presets. The darwin host is a flat attrset that
turns knobs
([hosts/aarch64-darwin/lookingglass/default.nix#L1-L54](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/hosts/aarch64-darwin/lookingglass/default.nix#L1-L54)):

```nix
nmasur.settings = { username = ...; fullName = ...; };
nmasur.profiles.base.enable = true;
nmasur.presets.security.corporateCa = { enable = true; certFile = "..."; };
home-manager.users."Noah.Masur" = { nmasur.profiles.common.enable = true; ... };
```

Identity lives in `nmasur.settings` at the host level and is read by modules
across both the nix-darwin and home-manager trees. The home-manager side of a
darwin host is written inline in the host file as a `home-manager.users.<name>`
block, then extracted back out by `buildHome`.

Work versus personal is expressed two ways at once. At the profile level,
`nmasur.profiles.work.enable` gates work-only packages and Brewfile entries
([platforms/home-manager/modules/nmasur/profiles/work.nix#L25](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/profiles/work.nix#L25),
[#L46-L52](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/profiles/work.nix#L46-L52)).
At the identity level, `git-work.nix` forces the work identity as the default
and scopes the personal identity by path
([platforms/home-manager/modules/nmasur/presets/programs/git-work.nix#L1-L92](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/programs/git-work.nix#L1-L92)):
`programs.git.settings.user` is `mkForce`d to work, and an `includes` entry
with `condition = "gitdir:~/dev/personal/"` swaps in the personal identity for
that subtree. Jujutsu gets the same treatment through a `--scope` with
`"--when".repositories`.

Laptop versus server is not a named axis. It falls out of which platform tree a
host lives in. The only darwin host is a laptop; the Linux hosts are servers,
a WSL guest, and cloud images.

One structural decision deserves quoting, because it is direct evidence for a
position our doc takes. `buildDarwin` deliberately strips home-manager out of
the nix-darwin configuration
([lib/default.nix#L190-L198](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/lib/default.nix#L190-L198)):

> Home Manager is intentionally NOT activated here. It is managed standalone
> via `nh home switch` (see homeConfigurations, extracted from the host
> module's `home-manager.users`). Strip that attr so darwin-rebuild doesn't
> also activate a second, divergent HM generation with different store paths
> (useUserPackages puts packages in /etc/profiles/per-user vs. ~/.nix-profile
> standalone) -- that mismatch broke the prompt after every darwin-rebuild
> until the next `nh home switch`.

That comment records a real production break, not a preference.

## 3. Per-App Config Mechanics

### programs.* versus home.file versus activation

The default is upstream `programs.*` modules. `home.file` and `xdg.configFile`
appear where no module exists, and activation blocks appear only where an
external binary must run.

The important negative result: this repo manages **zero** files that the
application also rewrites. Grepping every `.nix` file found no use of
`mkOutOfStoreSymlink`, no `force = true`, no `backupFileExtension`, and no
`onChange`. There is no merge machinery of any kind. The design avoids the
problem instead of solving it.

That avoidance was learned, not assumed. `docs/CHANGELOG.md` records the fix
([docs/CHANGELOG.md#L1-L118](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/docs/CHANGELOG.md#L1-L118)):

> 2026-08-16: Fixed Firefox "profile cannot be loaded" error on macOS by
> removing `home.file."Library/Application Support/Firefox/installs.ini"` ...
> causing Firefox to compute a new installation hash, fail to match or write to
> the read-only `installs.ini` symlink, and error out.

That is our Problem A, hit in the field, and resolved by unmanaging the file.

The fullest app module is Hammerspoon, and it shows the intended composition
style
([platforms/home-manager/modules/nmasur/presets/services/hammerspoon/default.nix#L1-L63](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/services/hammerspoon/default.nix#L1-L63)).
One module contributes a `.Brewfile` cask line, a `targets.darwin.defaults`
domain, five `xdg.configFile` sources (one built with `pkgs.replaceVars` to
substitute store paths), and a reload block that wraps `hs -c "hs.reload()"` in
`timeout 10` and pgrep-gates it. App install, app preferences, app config
files, and app reload all live in one file.

### macOS defaults

Defaults are written from home-manager, not nix-darwin. The nix-darwin
`system.defaults` block exists but is entirely commented out, along with its
`postActivation` hook; the only live nix-darwin settings are Touch ID for sudo
and keyboard remapping
([platforms/nix-darwin/modules/nmasur/presets/services/settings.nix#L17](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/nix-darwin/modules/nmasur/presets/services/settings.nix#L17),
[#L28-L106](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/nix-darwin/modules/nmasur/presets/services/settings.nix#L28-L106)).

The live path is `targets.darwin.defaults` for user domains plus
`targets.darwin.currentHostDefaults` for per-host domains
([platforms/home-manager/modules/nmasur/presets/services/darwin-settings.nix#L1-L93](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/services/darwin-settings.nix#L1-L93),
with `com.apple.mouse.tapBehavior` at
[#L84-L90](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/services/darwin-settings.nix#L84-L90)).
Third-party domains use the same mechanism with raw values, for example
`"leits.MeetingBar"`
([platforms/home-manager/modules/nmasur/presets/services/menubar.nix#L40-L49](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/services/menubar.nix#L40-L49)).

The migration cost a typed abstraction, and the repo documents it
([platforms/home-manager/modules/nmasur/presets/services/dock.nix#L11-L13](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/services/dock.nix#L11-L13)):

> macOS stores persistent-apps as an array of dicts, not strings. nix-darwin's
> dock module did this transform for us; targets.darwin.defaults writes values
> verbatim, so we build the tile dicts ourselves.

Reload is a bare activation block with no quit guard and no interactive check
([dock.nix#L73-L78](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/services/dock.nix#L73-L78)):
`config.lib.dag.entryAfter [ "writeBoundary" ]` running
`run /usr/bin/killall Dock Finder || true`.

### Casks, MAS, taps

The active Homebrew path is a home-manager activation block, not the nix-darwin
module
([platforms/home-manager/modules/nmasur/presets/programs/homebrew.nix#L18-L34](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/programs/homebrew.nix#L18-L34),
[#L44-L80](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/programs/homebrew.nix#L44-L80)).
It writes `home.file.".Brewfile".text`, then installs Homebrew if missing, sets
`HOMEBREW_NO_AUTO_UPDATE=1`, points at the store Brewfile via
`config.home.file.".Brewfile".source`, and runs `brew bundle install` followed
by `brew bundle cleanup --force`.

The nix-darwin `homebrew` module is present with
`onActivation = { autoUpdate = false; cleanup = "zap"; upgrade = true; }` but is
not enabled; `homebrew.enable` is commented out in the base profile
([platforms/nix-darwin/modules/nmasur/presets/programs/homebrew.nix#L1-L40](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/nix-darwin/modules/nmasur/presets/programs/homebrew.nix#L1-L40),
[platforms/nix-darwin/modules/nmasur/profiles/base.nix#L23](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/nix-darwin/modules/nmasur/profiles/base.nix#L23)).

The `.Brewfile` is composed additively by three separate modules: the base
homebrew preset
([homebrew.nix#L18](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/programs/homebrew.nix#L18)),
the work profile
([work.nix#L46-L52](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/profiles/work.nix#L46-L52)),
and the Hammerspoon service
([hammerspoon/default.nix#L20-L22](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/services/hammerspoon/default.nix#L20-L22)).
This works because `home.file.<name>.text` is
`types.nullOr types.lines`, so definitions concatenate
([HM file-type.nix#L60-L70](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/lib/file-type.nix#L60-L70)).
That is the module-system analogue of our package-group union, except each
line sits next to the config for the app it installs.

No MAS apps and no taps appear in the Brewfile.

### launchd

Almost nothing. The only real `launchd.user.agents` entry runs `antigravity-cli`
on a `StartCalendarInterval`, and it is commented out in the base profile
([platforms/nix-darwin/modules/nmasur/presets/services/daily-summary/daily-summary.nix#L28](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/nix-darwin/modules/nmasur/presets/services/daily-summary/daily-summary.nix#L28)).

### Secrets

Two mechanisms, split by platform, both hand-rolled. 37 `.age` ciphertext files
are committed to this public repo. The README calls the Linux one "similar to
agenix"
([README.md#L60-L61](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/README.md#L60-L61)).

On Linux, `platforms/nixos/modules/secrets.nix` defines `secretsDirectory`
(default `/var/private`), `identityFile` (default
`/etc/ssh/ssh_host_ed25519_key`), and a `secrets` submodule with
source/dest/owner/group/permissions, then generates one systemd oneshot per
secret that runs `age --decrypt --identity <identityFile> <source>` and
chowns/chmods the result
([platforms/nixos/modules/secrets.nix#L1-L109](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/nixos/modules/secrets.nix#L1-L109),
decrypt at
[#L79-L98](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/nixos/modules/secrets.nix#L79-L98)).

On Darwin there is no decryption mechanism at all.
`platforms/nix-darwin/modules/secrets.nix` is 19 lines and defines only an
`identityFile` option
([platforms/nix-darwin/modules/secrets.nix#L1-L19](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/nix-darwin/modules/secrets.nix#L1-L19)).
Instead, Darwin secrets ride the consuming application's own credential hook.
Thunderbird sets `passwordCommand` to
`age --decrypt --identity ~/.ssh/id_ed25519 <store path of taskspass.age>`
([platforms/home-manager/modules/nmasur/presets/programs/thunderbird/thunderbird.nix#L48](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/programs/thunderbird/thunderbird.nix#L48)),
and mbsync does the same
([platforms/home-manager/modules/nmasur/presets/services/mbsync/mbsync.nix#L117](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/services/mbsync/mbsync.nix#L117)).
Ciphertext enters the store; plaintext never does; decryption happens in the
app's own process at runtime using the user's SSH key.

There is also an interactive prompt inside activation, which contradicts a
common assumption. `loadkey.nix` gates on `[[ $- == *i* ]]`, prints "Enter the
seed phrase for your SSH key...", and runs `melt restore ~/.ssh/id_ed25519`
([platforms/home-manager/modules/nmasur/presets/services/loadkey.nix#L1-L39](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/services/loadkey.nix#L1-L39)).

### Root per switch

On Darwin, essentially nothing. Since home-manager is standalone and the
nix-darwin config is nearly empty, the day-to-day command is `nh home switch`,
which never calls sudo. `darwin-rebuild switch` is still needed for Touch ID,
keyboard remapping, and the corporate CA, but those change rarely.

The corporate CA module is the one genuinely instructive nix-darwin piece
([platforms/nix-darwin/modules/nmasur/presets/security/corporate-ca.nix#L1-L44](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/nix-darwin/modules/nmasur/presets/security/corporate-ca.nix#L1-L44)).
It sets `security.pki.certificateFiles = [ cfg.certFile ]` and types `certFile`
as `types.str`, not `types.path`, with the reason in a doc comment: a Nix path
literal would be read at eval time and break flake purity, so the string is
resolved at build time instead. The changelog entry for 2026-08-03 records the
failure that motivated it, `self-signed certificate in certificate chain (19)`,
why the cert lives outside the public repo at a root-owned world-readable path
(nixbld cannot traverse a mode-0750 `$HOME`), and the bootstrap incantation
`NIX_SSL_CERT_FILE=/tmp/combined-ca.crt nh darwin switch . --configuration lookingglass`
([docs/CHANGELOG.md#L1-L118](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/docs/CHANGELOG.md#L1-L118)).

### The Windows path

Nothing declarative. `platforms/windows/` holds seven files and **zero** `.nix`:
`alacritty.yml`, two AutoHotkey scripts, two `.reg` files, `chocolatey.config`,
and `windows-programs.md`. These are copied by hand. The only declarative
Windows story is NixOS-WSL, wired through
`platforms/nixos/modules/nmasur/profiles/wsl.nix` and used by the host `hydra`.

### Agent CLIs

Installed, not configured. `profiles/llm-development.nix` installs exactly one
package, `pkgs.pi-coding-agent`
([platforms/home-manager/modules/nmasur/profiles/llm-development.nix#L1-L26](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/profiles/llm-development.nix#L1-L26)),
and the work profile installs `pkgs.claude-code`
([work.nix#L25](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/profiles/work.nix#L25)).
A repo-wide grep for agent-config paths found no module managing any agent
settings file, skill directory, or plugin marketplace.

## 4. Testing And CI

There is no per-commit CI and no macOS runner anywhere in the repo.

| Workflow | Trigger | What it does |
| --- | --- | --- |
| `check.yml` | `workflow_dispatch` only | Ubuntu runner, Determinate actions, `nix flake check` ([.github/workflows/check.yml#L1-L20](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/.github/workflows/check.yml#L1-L20)) |
| `update.yml` | weekly cron | Lock bump PR, `nix flake check`, automerge or auto-close ([#L1-L71](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/.github/workflows/update.yml#L1-L71)) |
| `arrow.yml`, `arrow-aws.yml`, `flame.yml` | `workflow_dispatch` | Terraform, image build, `nixos-anywhere` deploy for Linux cloud hosts |

Two details make even that thin surface thinner. The `checks` flake output is
entirely commented out in `flake.nix`, so `nix flake check` evaluates only the
default checks the flake schema derives. And because the runner is Ubuntu, no
`darwinConfiguration` and no `homeConfiguration` for `aarch64-darwin` is ever
evaluated in CI. The Mac is validated by running the switch on the Mac.

There are no unit tests, no NixOS VM tests, and no assertion modules.

## 5. Compare And Contrast With Our Doc

### 5.1 App-module-plus-roles versus feature-modules-plus-platform-adapters

Our target-state doc proposes a tree organized by app module, with roles
selecting them
([nix-target-state-research.md](../nix-target-state-research.md), "Composition
Model" and the tree sketch). This repo uses a different decomposition our doc
did not consider: the primary split is by **platform**, and every module in a
platform directory is auto-imported into every configuration for that platform,
with `mkEnableOption` doing all the selection
([lib/default.nix#L127-L200](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/lib/default.nix#L127-L200)).

The tradeoffs are real in both directions.

| Property | Our app-module + roles | Their platform dirs + auto-import |
| --- | --- | --- |
| Where an app's config lives | One module per app | Split across `platforms/nix-darwin/` and `platforms/home-manager/` if it needs both |
| Adding a host | Write a role list | Set booleans; imports are automatic |
| Adding a module | Add to an import list | Drop a file in the directory |
| Eval cost | Only what a host imports | Every module for the platform, always |
| Finding "what does this host get" | Read the role | Grep for `enable = true` across the tree |
| Cross-platform app | Naturally one file | Naturally two files |

Our doc should note this alternative but should not adopt it. The auto-import
mechanism is elegant for a repo with one Mac and six Linux boxes where the
platform split is the dominant axis. For us the dominant axis is the app, and
the second axis is the machine type, not the platform: three of our four
machine types are the same platform. Auto-import would also make our per-app
ownership table harder to read, since `home/Library/private_Preferences/` work
and `home/dot_config/` work for the same app would land in different trees.

Concretely: add one paragraph to the "Composition Model" section naming
platform-directory auto-import as a rejected alternative, with
`lib/default.nix#L127-L200` as the citation and "our dominant axis is the app,
not the platform" as the reason.

### 5.2 The "what disappears" table

The repo is mostly corroborating. Two rows deserve edits.

| Our row | Their evidence | Change? |
| --- | --- | --- |
| `hooks.read-source-state.pre` installing uv disappears | No analogue exists or is needed; activation scripts reference store paths directly | No change. Corroborated. |
| Go templates disappear into module options | Confirmed; `nmasur.settings` and `mkIf` do all conditional work | No change |
| `promptChoiceOnce machine_type` disappears into a flake attribute | Confirmed for host selection | No change |
| The plist quit/relaunch guard disappears | **Contradicted in spirit.** They have no guard at all and just `killall Dock Finder \|\| true` ([dock.nix#L73-L78](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/services/dock.nix#L73-L78)) | Add a note: the observed practice is to drop the guard, not port it. That is a behavior loss we would be choosing, and it should be named as a choice. |
| Interactive prompts have no home in activation | **Reframed.** `loadkey.nix` runs an interactive prompt inside a post-`writeBoundary` activation block, gated on `[[ $- == *i* ]]` ([loadkey.nix#L1-L39](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/services/loadkey.nix#L1-L39)) | Soften the claim. Prompts are possible with an interactivity guard; what is unavailable is a prompt that can *block* activation cleanly. |

### 5.3 The per-app ownership table

Our per-app table assigns each app to `programs.*`, `home.file`, a merger, or
"stays chezmoi-shaped." This repo supplies evidence for the first two columns
and none at all for the third.

The useful addition is not a row, it is a column pattern. Hammerspoon shows
that install, preferences, config files, and reload can be one module
([hammerspoon/default.nix#L1-L63](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/services/hammerspoon/default.nix#L1-L63)),
including the Brewfile line for the cask that installs it. Our table currently
splits Brewfile membership (row 9, `packages.toml` groups) away from app config.
Their `types.lines` composition shows those can be colocated without losing the
union semantics.

Recommend: add a note under the per-app table that the cask entry for an app can
be contributed by the app's own module rather than a central package list, and
cite `types.lines` merge semantics
([HM file-type.nix#L60-L70](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/lib/file-type.nix#L60-L70))
plus the three contributing sites.

### 5.4 Problem A, files the app also writes

Our doc treats Problem A as the hardest unsolved piece, with six mergers
surviving. This repo is evidence **for the severity** and **against the
existence of a solution**.

They hit it on Firefox `installs.ini` and resolved it by deleting the managed
file ([docs/CHANGELOG.md#L1-L118](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/docs/CHANGELOG.md#L1-L118)).
The failure mode they describe, the app computing a hash, failing to write to a
read-only store symlink, and erroring out, is exactly the mode our doc predicts
for Claude's `settings.json` and Cursor's config.

They have zero `mkOutOfStoreSymlink`, zero `force = true`, zero
`backupFileExtension`, and zero `onChange` in 279 `.nix` files. A repo this
mature with this much macOS surface arrived at "do not manage those files."

Our doc should keep Problem A exactly as stated and add this as an external data
point: a 279-file, 7-host, 7-year Nix config manages no app-rewritten files at
all. That strengthens the case that our six surviving mergers are genuinely
outside what the ecosystem does, and it weakens any hope that a well-known
idiom exists that we missed.

### 5.5 Problem B, the MDM-managed work Mac

This is where the repo is closest to us and also where its evidence is
incomplete.

Supporting our position: their only Mac is an employer laptop, and they run
**standalone home-manager** as the day-to-day switch, with nix-darwin reduced to
a near-empty shell. The `buildDarwin` comment is a field report of what goes
wrong when both activate
([lib/default.nix#L190-L198](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/lib/default.nix#L190-L198)).
Our doc's "standalone home-manager only, nix-darwin only if forced" leaning gets
independent corroboration.

Also supporting: the corporate CA module is a working pattern for a
TLS-intercepting proxy, including the eval-purity workaround of typing the path
as `types.str`
([corporate-ca.nix#L1-L44](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/nix-darwin/modules/nmasur/presets/security/corporate-ca.nix#L1-L44)).
Our doc does not currently mention that Nix fetches will fail behind a corporate
MITM proxy, or that the cert must live outside the flake at a path nixbld can
traverse. That is a concrete gap worth filling.

Not supporting: nothing in the repo shows MDM. No Jamf, no temp-admin, no
privilege-escalation dance, no evidence their laptop restricts admin. Our doc's
Problem B is specifically about *losing admin between switches*, and this repo
does not test that. Treat the corroboration as covering the
standalone-home-manager shape only.

One inconsistency worth flagging: `docs/installation.md` still instructs
`nix run nix-darwin -- switch` and then `darwin-rebuild switch --flake ~/dev/personal/dotfiles`
([docs/installation.md#L1-L73](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/docs/installation.md#L1-L73)),
which contradicts the `nh home switch` model the code enforces. Their own docs
drifted from their own composition engine. Worth remembering when our doc
estimates documentation cost.

Recommend two edits to Problem B: add a sub-point on corporate TLS interception
citing `corporate-ca.nix` and the 2026-08-03 changelog entry, and add the
`buildDarwin` comment as external evidence for "do not run nix-darwin and
home-manager both activating."

### 5.6 Problem C, secrets without store leakage

Our doc lists four options: opnix, sops-nix, agenix, and keeping
`onepasswordRead` at render time (rejected, since it lands in the store).

This repo contributes a **fifth** we did not consider: commit the ciphertext
into the store deliberately and let the consuming application decrypt it at
runtime through its own credential hook
([thunderbird.nix#L48](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/programs/thunderbird/thunderbird.nix#L48),
[mbsync.nix#L117](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/services/mbsync/mbsync.nix#L117)).
No activation-time decryption, no runtime secret path on disk, no systemd or
launchd service. The store holds only what is already public.

Applicability to us is narrow but real. Our three secret-backed targets are
license files, which are read by the app at launch. If BetterTouchTool and the
others accept a license path rather than requiring inline content, this pattern
would remove the need for a secrets framework on the Mac entirely. Whether they
do is unverified.

Their Linux mechanism, a systemd oneshot per secret with owner/group/mode
([secrets.nix#L79-L98](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/nixos/modules/secrets.nix#L79-L98)),
is a reimplementation of agenix and is not worth copying. Note that it also
answers concept-map row 2: they solve the "no mode option on `home.file`"
problem by doing the `chown`/`chmod` in the service, which is exactly the
activation-copy escape hatch our row 2 names.

Recommend: add the app-credential-hook option to Problem C as option five, with
the caveat that it only works for apps that accept a command or a path, and add
an open question on whether our three license consumers qualify.

### 5.7 The test surface

Our doc proposes `checks.<system>.*` for evaluation and closure checks plus
retained zsh behavior tests. This repo is evidence that the ecosystem norm is
weaker than our proposal, not stronger.

Their `checks` output is commented out. CI is manual-dispatch only. No macOS
runner exists, so the Mac configuration is never evaluated off the Mac. The
weekly lock bump runs `nix flake check` on Ubuntu and automerges if it passes,
which for the Darwin half proves nothing
([update.yml#L1-L71](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/.github/workflows/update.yml#L1-L71)).

Our doc should not weaken its test proposal in response. It should record that
the comparison set does not validate Darwin in CI, so we will not find a
reference implementation to copy, and `nix build .#darwinConfigurations.<host>.system`
on a macOS runner (concept-map row 42) is something we would be building rather
than adopting.

### 5.8 Open questions this answers or reframes

| Our open question | Effect | Evidence |
| --- | --- | --- |
| Standalone HM or nix-darwin plus HM on the work Mac? | **Answered toward standalone**, for a reason we had not recorded: dual activation produces divergent store paths for the same packages | [lib/default.nix#L190-L198](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/lib/default.nix#L190-L198) |
| `targets.darwin.defaults` or ND `system.defaults` for plists? | **Answered toward `targets.darwin.defaults`**, with a named cost: you lose ND's typed transforms and write raw plist structures | [darwin-settings.nix#L1-L93](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/services/darwin-settings.nix#L1-L93), [dock.nix#L11-L13](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/services/dock.nix#L11-L13) |
| `nix-homebrew` or `brew bundle` from activation? | **Answered toward activation**, and it is compatible with standalone HM, which the ND module is not | [homebrew.nix#L44-L80](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/programs/homebrew.nix#L44-L80) |
| Can activation prompt interactively? | **Reframed** from "no" to "yes, behind an interactivity guard" | [loadkey.nix#L1-L39](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/presets/services/loadkey.nix#L1-L39) |
| How do agent CLI configs get managed under Nix? | **Not answered.** They install two agent CLIs and manage no agent config | [llm-development.nix#L1-L26](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/platforms/home-manager/modules/nmasur/profiles/llm-development.nix#L1-L26) |
| Does anyone merge into app-owned files? | **Answered no**, across 279 `.nix` files | repo-wide grep; [docs/CHANGELOG.md#L1-L118](https://github.com/nmasur/dotfiles/blob/72c4f4823b6c6e173da44be7442328133a81e789/docs/CHANGELOG.md#L1-L118) |
| Headless Linux profile shape? | **Partially informative.** Their WSL host is a full NixOS config, not standalone HM on a foreign distro, so it does not address our DevPod case | `platforms/nixos/modules/nmasur/profiles/wsl.nix` |

## 6. What To Take, What To Avoid

### Take

1. **Colocate the Brewfile line with the app module.** `home.file.".Brewfile".text`
   is `types.lines`, so three modules can each contribute one line and the union
   still holds. This preserves our package-group semantics while putting the
   cask next to the config it enables.
2. **The corporate CA pattern**, verbatim in shape:
   `security.pki.certificateFiles` with the cert path typed `types.str` to keep
   flake evaluation pure, the cert stored outside the repo at a root-owned
   world-readable path so nixbld can read it, and `NIX_SSL_CERT_FILE` for
   bootstrap.
3. **The dual-activation warning.** Do not let nix-darwin and standalone
   home-manager both activate. If we keep any nix-darwin config, strip
   `home-manager` from it the way `buildDarwin` does.
4. **`targets.darwin.currentHostDefaults`** for `ByHost` domains. Our doc's
   plist rows only discuss `targets.darwin.defaults`; the per-host variant is
   needed for domains like `com.apple.mouse.tapBehavior`.
5. **The app-credential-hook secrets option** for anything that accepts a
   command or a path.

### Avoid

1. **Platform-directory auto-import.** Elegant for their axis, wrong for ours,
   and it makes "what does this host actually get" a grep instead of a read.
2. **A hand-rolled secrets module.** Their NixOS `secrets.nix` reimplements
   agenix. Use agenix or sops-nix.
3. **Commenting out large config blocks instead of deleting them.** The
   nix-darwin `system.defaults` block, the `homebrew` module, the `checks`
   output, and the daily-summary agent are all dead code that reads as live.
4. **Manual-dispatch-only CI with automerged lock bumps.** Automerging a lock
   bump whose only gate is an Ubuntu `nix flake check` gives false confidence
   for a Darwin host.
5. **Committing ciphertext to a public repo.** Fine for them, wrong default for
   us; our `op://` references keep even ciphertext out.
6. **Letting installation docs drift from the composition engine.**

### Relevance: 3 of 5

Three reasons for the score, and three against.

For: it is the closest public analogue to our work-Mac situation that this
survey set is likely to produce, since its only Mac is an employer laptop
running standalone home-manager. It independently corroborates three positions
our doc argues rather than proves, namely standalone home-manager over
nix-darwin plus home-manager, `targets.darwin.defaults` as the plist tier, and
`brew bundle` from an activation block. And it supplies one Problem C mechanism
and one corporate-proxy pattern our doc does not have.

Against: it is thin exactly where our hardest problems are. There is no MDM
evidence, so Problem B's actual difficulty is untested. There is no
app-owned-file merging at all, so Problem A gets a data point rather than a
technique. There is no agent-config management, which is 87% of our source
tree by file count. And with no macOS CI and a commented-out `checks` output,
it offers nothing for our test surface.

A 4 would require MDM evidence or a real merge technique. A 2 would understate
the corporate CA and dual-activation findings, both of which are directly
actionable.

## 7. Concept-Map Scorecard

Rows from Appendix A of [nix-target-state-research.md](../nix-target-state-research.md).
Only rows this repo provides evidence for are listed.

| Row | Verdict | Note (five words) |
| --- | --- | --- |
| 1. Plain files as `home.file` | Supports | Default everywhere, no surprises |
| 2. `private_` modes need a copy | Supports | Their systemd service chmods secrets |
| 4. `symlink_` live links | Contradicts | Zero `mkOutOfStoreSymlink` in repo |
| 5. Go templates become options | Supports | `nmasur.settings` plus `mkIf` throughout |
| 6. Host selection is a flake attribute | Supports | Directory auto-discovery generates attributes |
| 8. Layer merge as option priorities | Supports | `mkForce` for work git identity |
| 9. Brewfile via `homebrew.*` module | Alternative | Activation block, module deliberately disabled |
| 11. Retired packages via cleanup | Alternative | `brew bundle cleanup --force` instead |
| 13. `nix-homebrew` installs Homebrew | Alternative | Activation block installs it itself |
| 16. `.chezmoiignore` gates become `mkIf` | Supports | Every module gates on enable |
| 19. `run_onchange_` becomes `onChange` | Contradicts | Zero `onChange`; activation blocks instead |
| 21. Activation ordering via dag entries | Supports | `entryAfter writeBoundary` used consistently |
| 23. Plists via `targets.darwin.defaults` | Supports | Migrated off nix-darwin, lost transforms |
| 24. Mergers for app-rewritten files | Contradicts | They unmanage instead of merging |
| 25. Quit guard before writing plists | Contradicts | Bare killall, no guard whatsoever |
| 26. Defaults from home-manager, no root | Supports | User domains written without sudo |
| 27. Sudo per switch | Supports | Standalone home-manager avoids sudo entirely |
| 28. LaunchAgents via `launchd.*` | Supports | One agent, currently commented out |
| 29. Agent plugin rendering | Contradicts | Agent CLIs installed, configs unmanaged |
| 34. Keep mise for `latest` CLIs | Contradicts | No mise; nixpkgs pins everything |
| 37. Secrets cannot be read at eval | Supports | Ciphertext in store, runtime decryption |
| 38. No per-file drift report | Supports | No drift tooling anywhere in repo |
| 40. Pre-existing files clobber | Supports | Firefox `installs.ini` failure recorded |
| 41. Headless Linux profile | Alternative | Full NixOS WSL, not standalone |
| 42. `nix build` darwin config in CI | Contradicts | No macOS runner, no per-commit |
