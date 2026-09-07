---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-04
updated: 2026-09-04
related:
  - ../nix-target-state-research.md
  - ../nix-migration-research.md
status_detail: "Agent survey of billimek/dotfiles at 9b1e33e0051573b7c84ecf6e87613c94deb0f773, compared with the Nix target-state doc. Unreviewed."
---

# Survey: billimek/dotfiles

## Method

Read on 2026-09-04 against a pinned tarball of
[billimek/dotfiles](https://github.com/billimek/dotfiles) at
`9b1e33e0051573b7c84ecf6e87613c94deb0f773`, fetched with
`gh api repos/billimek/dotfiles/tarball/<sha>`. Repository metadata and
commit history came from the GitHub API at the same sha.

Files read in full: `README.md`, `CLAUDE.md`, `flake.nix`, `.gitattributes`,
both workflows under `.github/workflows/`, `.github/dependabot.yml`, all four
files under `modules/wiring/`, all three files under `modules/darwin-modules/`,
`modules/nixos-modules/opnix.nix`, `modules/nixos-modules/auto-upgrade.nix`,
`modules/overlays/opnix-overlay.nix`, `modules/home-modules/base.nix`,
`modules/home-modules/secretspec.nix`, `modules/home-modules/agent-instructions.nix`,
`modules/home-modules/gh.nix`, both Darwin host files, all five files under
`hosts/home/`, `hosts/README.md`, `hosts/darwin/README.md`,
`.claude/settings.json`, the three files under `.claude/commands/`, and
`.claude/skills/add-nix-component/SKILL.md`. Read in part:
`modules/home-modules/claude-code.nix`, `modules/home-modules/dev.nix`,
`modules/nixos-modules/base.nix`, `hosts/nixos/nas/default.nix`,
`hosts/nixos/nas/README.md`, `hosts/nixos/cloud/README.md`,
`scripts/update-packages.sh`.

Not read: the 25 remaining NixOS feature modules, the remaining home modules,
`flake.lock` contents, the six `packages/*.nix` derivations, and
`hosts/nixos/{home,cloud}/default.nix` beyond a grep. Claims about those files
are marked unverified where they appear.

Compared against [nix-target-state-research.md](../nix-target-state-research.md)
(read in full), [nix-migration-research.md](../nix-migration-research.md)
("Options" and "Sizing"), and [chezmoi-architecture.md](../../references/chezmoi-architecture.md).

## 1. What It Is

Jeff Billimek's personal infrastructure flake. The repository dates to
2018-12-08 and has 1,776 commits, but the Nix content is recent: the oldest of
the most recent 100 commits is 2026-07-11, and the pre-Nix dotfiles were moved
to an `archive` branch
([README.md](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/README.md)).
45 stars, 2 forks, Apache-2.0.

99 `.nix` files, 6,374 lines, plus 12 Markdown files. The distribution is
lopsided toward Linux: 31 NixOS modules, 26 home-manager modules, 3 Darwin
modules, 5 overlays, 6 package registrations, 4 wiring files, 16 host files,
6 derivations, and `flake.nix` plus `secrets.nix` at the root.

Eight machine configurations across three classes
([modules/wiring/hosts.nix#L63-L109](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/wiring/hosts.nix#L63-L109)):

| Class | Names |
| --- | --- |
| `nixosConfigurations` | `nas`, `cloud`, `home` |
| `darwinConfigurations` | `Jeffs-M3Pro` (personal MBP), `work-laptop` (work MBP) |
| `homeConfigurations` | `jeff@cloud`, `jeff@home`, `jeff@Jeffs-M3Pro`, `jeff@work-laptop`, `nix@nas` |

Home-manager is standalone on every host, including both Macs. It is not
imported as a nix-darwin module. The Darwin bootstrap is two separate
commands, `darwin-rebuild switch --flake .#<host>` under sudo and then
`home-manager switch --flake .#jeff@<host>`
([hosts/darwin/README.md#L55-L69](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/darwin/README.md#L55-L69)),
and day to day it is `nh darwin switch` plus `nh home switch`
([hosts/darwin/README.md#L76-L84](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/darwin/README.md#L76-L84)).
On NixOS the home-manager NixOS module is imported in the base module
([modules/nixos-modules/base.nix#L18-L21](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/nixos-modules/base.nix#L18-L21)),
so both mechanisms coexist there. Which one actually owns a NixOS user's home
was not traced.

Activity is high but mostly automated. Of the 25 most recent commits, 10 are
`Bump flake.lock` and 2 are `Bump pinned packages`. The lock is bumped by a
daily 06:00 UTC scheduled workflow that runs `nix flake update`, evaluates
every host the new lock would build, and only then commits to `master` with
`git-auto-commit-action`
([main.yml#L1-L7](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/.github/workflows/main.yml#L1-L7),
[#L32-L37](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/.github/workflows/main.yml#L32-L37),
[#L116-L140](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/.github/workflows/main.yml#L116-L140)).
A second weekly workflow bumps the six hand-pinned derivations the same way
([bump-packages.yml#L1-L38](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/.github/workflows/bump-packages.yml#L1-L38)).
Nixpkgs is pinned to the `nixos-26.05` release branch with a separate unstable
input, and home-manager and nix-darwin follow matching release branches
([flake.nix#L6-L23](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/flake.nix#L6-L23)).

## 2. Composition

### The dendritic pattern

`flake.nix` is nine lines of body: `flake-parts.lib.mkFlake` with
`imports = [ (import-tree ./modules) ]` and a four-entry `systems` list
([flake.nix#L46-L57](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/flake.nix#L46-L57)).
Every `.nix` file under `modules/` is loaded recursively as a flake-parts
module and contributes to flake outputs by option merging. Adding a feature
module means dropping a file; there is no import list to edit
([README.md](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/README.md),
[.claude/skills/add-nix-component/SKILL.md#L6](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/.claude/skills/add-nix-component/SKILL.md#L6)).

Four flake output namespaces that flake-parts does not declare natively are
declared by hand as `lazyAttrsOf unspecified`
([modules/wiring/options.nix#L3-L20](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/wiring/options.nix#L3-L20)).
`hosts/` is deliberately outside `modules/` because `import-tree` would try to
load host files as flake-parts modules and they are not
([CLAUDE.md#L10](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/CLAUDE.md#L10)).

### The enable-option pattern

Every feature module has the same shape. A thin flake-parts wrapper registers
a NixOS-style module under `flake.<class>Modules.<name>`; the inner module
declares `options.modules.<name>.enable` and guards its whole body with
`lib.mkIf cfg.enable`
([CLAUDE.md#L12-L31](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/CLAUDE.md#L12-L31)).
`modules/home-modules/gh.nix` is the minimal example, 32 lines end to end
([gh.nix#L14-L30](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/gh.nix#L14-L30)).

The critical detail is that hosts do not choose imports. `mkNixos`, `mkDarwin`,
and `mkHome` each import **every** registered module of that class with
`imports = builtins.attrValues self.<class>Modules`
([modules/wiring/hosts.nix#L21-L24](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/wiring/hosts.nix#L21-L24),
[#L36-L39](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/wiring/hosts.nix#L36-L39),
[#L50-L54](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/wiring/hosts.nix#L50-L54)).
Selection happens purely through the `enable` flags. Many modules default on
by merging `// { default = true; }` onto `mkEnableOption`; on the home side
almost everything is default-on and only `dev`, `kubernetes`, and `zmx` are
opt-in
([CLAUDE.md#L29-L36](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/CLAUDE.md#L29-L36)).

There are no role modules. The composition is two levels: a global default-on
set, and per-host `enable` toggles plus per-host values.

### Where identity lives

Identity is split across three places. Shared user identity is in
`hosts/home/<user>/default.nix` behind `lib.mkDefault`: username, git name and
email, and the SSH signing key
([hosts/home/jeff/default.nix#L9-L15](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/home/jeff/default.nix#L9-L15),
[#L61-L76](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/home/jeff/default.nix#L61-L76)).
Per-host identity overrides use `lib.mkForce` in the host file. System-level
identity lives in the Darwin host file as `system.primaryUser` and
`users.users.<name>`
([hosts/darwin/Jeffs-M3Pro.nix#L16-L22](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/darwin/Jeffs-M3Pro.nix#L16-L22)).
Work identity is read out of the git-crypt-encrypted `secrets.nix` at
evaluation time.

The layered resolver our repo has does not exist here. There is no machine
type, no groups, no feature flags, and no data layer. `builtins.fromTOML` is
not used anywhere.

### Personal Mac versus work Mac

Both Darwin hosts are 48 lines. Neither enables or disables a single module:
both have an empty `modules = { };` block with a comment saying the base
modules are auto-enabled
([Jeffs-M3Pro.nix#L7-L10](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/darwin/Jeffs-M3Pro.nix#L7-L10),
[work-laptop.nix#L11-L14](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/darwin/work-laptop.nix#L11-L14)).
The two Darwin hosts get an identical system baseline.

| Aspect | `Jeffs-M3Pro` | `work-laptop` |
| --- | --- | --- |
| Repo clone path | `~/src/dotfiles` | `~/src.github/dotfiles` |
| `system.primaryUser` | literal `"jeff"` | `secrets.work_username` from git-crypt |
| `users.users.<name>` | declared, shell set to fish | not declared |
| Corporate CA | none | `security.pki.certificateFiles = [ "/usr/local/munki/thd_certs.pem" ]` |
| System git | nixpkgs git | `environment.shellAliases.git = "/usr/bin/git"` |
| Extra taps and brews | none | `chainguard-dev/tap`, `chainctl` |
| MAS apps | SteamLink, Paprika | none |
| Home identity | inherited defaults | `mkForce` name, email, signing key from git-crypt |
| Home git | shared config | per-directory `includes` splitting work and personal gitdirs |
| Home CA env | none | `SSL_CERT_FILE`, `NIX_SSL_CERT_FILE`, `NODE_EXTRA_CA_CERTS`, `REQUESTS_CA_BUNDLE` all set to the munki bundle |
| MCP servers | victorialogs, grafana via secretspec | leanix via `op read`, miro via OAuth |
| SSH pubkeys placed | none | two `home.file` public keys |

Sources:
[hosts/darwin/work-laptop.nix#L16-L33](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/darwin/work-laptop.nix#L16-L33),
[hosts/home/jeff/work-laptop.nix#L42-L97](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/home/jeff/work-laptop.nix#L42-L97),
[#L110-L117](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/home/jeff/work-laptop.nix#L110-L117),
[hosts/darwin/Jeffs-M3Pro.nix#L24-L45](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/darwin/Jeffs-M3Pro.nix#L24-L45).

**There are no managed-device concessions.** This is the most useful negative
finding in the repo. The work Mac runs the same full nix-darwin activation as
the personal Mac: same `system.defaults`, same
`security.pam.services.sudo_local.touchIdAuth = true`, same
`homebrew.onActivation.cleanup = "uninstall"`. There is no privilege-escalation
helper, no Jamf-equivalent hook, no conditional on whether the user is in
`admin`, and no fallback to a home-manager-only mode. The only concessions are
to the corporate TLS interception (the munki CA bundle and the aliased system
git), not to MDM policy. Whether the machine is under an MDM that would block
any of this cannot be determined from the repo. The presence of
`/usr/local/munki` implies Munki-based management rather than Jamf. Marked
unverified.

## 3. Per-App Config Mechanics

### The three mechanisms, and their proportions

`programs.*` is the default and covers 19 apps: atuin, bash, bat, claude-code,
direnv, fish, gh, ghostty, git, k9s, lsd, nix-index, nvf, ssh, starship,
tealdeer, tmux, zellij, zoxide.

`home.file` and `xdg.configFile` are used sparingly, about a dozen times:
`.colorscheme`, `nixpkgs/config.nix`
([base.nix#L61](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/base.nix#L61),
[#L70](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/base.nix#L70)),
`secretspec/secretspec.toml`
([secretspec.nix#L147](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/secretspec.nix#L147)),
opencode's JSON
([dev.nix#L45-L56](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/dev.nix#L45-L56)),
five agent-instruction files, three Claude statusline artifacts, two SSH
public keys, and `.ssh/rc`.

`home.activation` is used exactly three times in the whole repo:
`claudeSettings`, `claudeMcpServers`, and `ensureNpmDirs` in the copilot-cli
module. There is **no** launchd usage anywhere, no `targets.darwin.defaults`,
and no `onChange` hook.

### Files the app also writes

Only one is handled, and the handling is instructive.
`~/.claude/settings.json` is **copied**, never symlinked, because Claude Code
opens it with `O_NOFOLLOW` and refuses to write through a symlink; a store
symlink there makes every runtime settings write fail silently, including the
one-time org-default reconciliation, which then retries forever and resets
`model` on each startup. Both upstream reports were closed as not planned, so
this is settled behavior
([claude-code.nix#L6-L23](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/claude-code.nix#L6-L23)).

`programs.claude-code.settings` is deliberately left empty, because
home-manager only creates the symlink when it is non-empty
([#L535-L545](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/claude-code.nix#L535-L545)).
An activation block after `writeBoundary` does the work instead. It is not a
merge. It compares the live file to the generated one with `jq -S` on both
sides, stashes a timestamped copy under `~/.claude/settings-drift/` if they
differ, then `rm -f` and `install -m 644`
([#L586-L601](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/claude-code.nix#L586-L601)).
Mode 644 rather than the store's 444 is the point: the file stays writable.
The `rm -f` exists because `install` would otherwise follow a stale store
symlink into the read-only store. A `/reconcile-claude-settings` slash command
triages the stashes back into the Nix defaults, and the statusline surfaces an
unreconciled count
([.claude/commands/reconcile-claude-settings.md](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/.claude/commands/reconcile-claude-settings.md),
[claude-code.nix#L240-L251](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/claude-code.nix#L240-L251)).

So the model is: Nix owns the file outright, overwrite wins, and a human-in-the-loop
reconcile loop catches the loss. There is a subtlety the comments call out:
because the check is a whole-document `jq -S` comparison, emitting any key the
app strips as a default fires the drift warning on every switch, which is why
`padding` is deliberately omitted
([#L558-L563](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/claude-code.nix#L558-L563)).

Where whole-file ownership is uncontested, they use `force = true` and accept
the silent delete. All five agent-instruction files do this
([agent-instructions.nix#L46-L74](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/agent-instructions.nix#L46-L74)).

MCP server registration is driven through the app's own CLI, not through its
config file. An activation block runs `claude mcp remove -s user` then
`claude mcp add -s user` for each declared server, guarded by a test that the
out-of-Nix Claude binary exists
([#L604-L637](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/claude-code.nix#L604-L637)).
Headers and env strings are double-quoted so `$( ... )` resolves at activation
time, which is how `op read` and `gh auth token` get in.

### macOS defaults

Everything goes through nix-darwin, nothing through home-manager. The base
Darwin module sets typed `system.defaults` for `menuExtraClock`,
`WindowManager`, `dock`, `finder`, `trackpad`, and `SoftwareUpdate`
([darwin-modules/base.nix#L98-L131](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/darwin-modules/base.nix#L98-L131)),
then falls back to `CustomUserPreferences` for `NSGlobalDomain` and five other
domains including `com.apple.finder`, iTerm2, and noTunes
([#L132-L164](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/darwin-modules/base.nix#L132-L164)).
Roughly 40 keys total. No plist merging, no delete directives, no quit guard,
no `killall cfprefsd`.

### Homebrew, casks, MAS, taps

The Darwin `homebrew` module exists and is default-on
([darwin-modules/homebrew.nix#L14-L18](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/darwin-modules/homebrew.nix#L14-L18)),
confirming the earlier read of `flake.nix` alone was incomplete: nix-darwin's
own `homebrew` option is what is used, and **nix-homebrew is not an input**.
Homebrew is installed by hand as a documented bootstrap step
([hosts/darwin/README.md#L21-L27](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/darwin/README.md#L21-L27)).

The settings are aggressive:

```nix
onActivation.autoUpdate = true;
onActivation.upgrade = false;
onActivation.cleanup = "uninstall";
onActivation.extraFlags = [ "--force" ];
global.brewfile = true;
```

([#L23-L29](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/darwin-modules/homebrew.nix#L23-L29))

`cleanup = "uninstall"` on both Macs means any cask or formula not in the
generated Brewfile is removed on every switch. The shared module carries 13
casks and 5 MAS apps
([#L30-L55](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/darwin-modules/homebrew.nix#L30-L55));
hosts append their own. There is no gating construct: a cask is on a host
because that host's file lists it. Two casks are commented out rather than
gated.

### launchd

None. Zero `launchd.agents`, `launchd.user.agents`, or `launchd.daemons` in
any of the 99 files. Periodic work on NixOS goes through systemd units instead
([auto-upgrade.nix#L22-L30](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/nixos-modules/auto-upgrade.nix#L22-L30)).

### Secrets, in detail

The repo runs four mechanisms and its `CLAUDE.md` is explicit that they are
scoped to different lifecycle points and should not be blended
([CLAUDE.md#L45-L51](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/CLAUDE.md#L45-L51)).

**1. git-crypt for evaluation-time values.** `secrets.nix` at the repo root is
a 629-byte git-crypt blob
([.gitattributes#L1](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/.gitattributes#L1)).
It is imported at a relative path by the two work configurations only
([hosts/darwin/work-laptop.nix#L7-L9](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/darwin/work-laptop.nix#L7-L9),
[hosts/home/jeff/work-laptop.nix#L8-L10](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/home/jeff/work-laptop.nix#L8-L10)),
and supplies `work_username`, `work_email`, and `work_git_pubkey`. Flake
evaluation of those configs fails without git-crypt unlocked. The unlock key
itself comes out of 1Password
([hosts/darwin/README.md#L96-L105](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/darwin/README.md#L96-L105)).
The values in question are identity strings, not high-value credentials, but
they still land in the store because Nix copies whatever evaluation reads.

**2. opnix, NixOS only.** The module is opt-in with no `default = true`
([nixos-modules/opnix.nix#L13-L15](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/nixos-modules/opnix.nix#L13-L15))
and is enabled on `nas` and `cloud`
([hosts/nixos/nas/default.nix#L39](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/nixos/nas/default.nix#L39)).
It sets `services.onepassword-secrets` with
`tokenFile = "/etc/opnix-token"`
([#L17-L21](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/nixos-modules/opnix.nix#L17-L21)).
Nine secrets are declared, each an `op://nix/<item>/<field>` reference with an
explicit `owner`, `group`, and `mode` of `0640` or `0600`: four for garage,
two for backblaze, three for NUT
([#L21-L84](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/nixos-modules/opnix.nix#L21-L84)).
Two more are declared by the gatus module itself rather than centrally, which
is the better pattern of the two
([gatus.nix#L216-L226](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/nixos-modules/gatus.nix#L216-L226)).
Every declaration is wrapped in `lib.mkIf config.modules.<consumer>.enable`,
so a host that does not run garage does not resolve garage secrets.

Consumers read the resolved path, never an env var directly:
`config.services.onepassword-secrets.secretPaths.<name>` is passed to
`rpc_secret_file` and `passwordFile` options where the service supports a file
([garage.nix#L73-L81](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/nixos-modules/garage.nix#L73-L81),
[nut.nix#L66-L71](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/nixos-modules/nut.nix#L66-L71)),
and `cat`-ed inside a wrapper script where it does not
([gatus.nix#L187-L192](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/nixos-modules/gatus.nix#L187-L192),
[rclone.nix#L39-L48](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/nixos-modules/rclone.nix#L39-L48)).
Ordering is explicit: consuming units declare
`requires` and `after` on `opnix-secrets.service`
([nut.nix#L163-L169](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/nixos-modules/nut.nix#L163-L169),
[garage.nix#L110-L114](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/nixos-modules/garage.nix#L110-L114)).
So on NixOS it is a oneshot systemd service, not an activation step.

**opnix is imported on Darwin but never used.** The Darwin base module imports
`inputs.opnix.darwinModules.default` and puts the opnix package in
`environment.systemPackages`
([darwin-modules/base.nix#L19-L21](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/darwin-modules/base.nix#L19-L21),
[#L71](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/darwin-modules/base.nix#L71)),
and the home base module imports `inputs.opnix.homeManagerModules.default`
([home-modules/base.nix#L20](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/base.nix#L20)),
but no `services.onepassword-secrets` block exists outside the NixOS module.
No Darwin launchd service, no HM secret. So this repo gives us **zero
evidence about opnix on macOS**.

The service account token is never provisioned by the repo. `/etc/opnix-token`
appears once, as a path. No host README documents creating it, no script
writes it, and no mode is set on it in the module. Whether the token is
scoped, rotated, or vault-limited is unverified.

**3. secretspec for process-launch injection.** This is the mechanism our doc
does not have. A home-manager module generates a `secretspec.toml` declaring
three providers: `op` pointing at `onepassword://<vault>`, `op-cache` pointing
at `keyring://secretspec/cache/{project}/{profile}/{key}`, and a composite
`cached` provider with `fallback = [ "op" ]` and a `max_age` window
([secretspec.nix#L38-L66](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/secretspec.nix#L38-L66)).
The stated reason is precise: `op` alone would raise a 1Password biometric
prompt on every MCP server launch, and the keyring cache serves repeat reads
for `cacheMaxAge`, default 12h, so `op` is contacted once per window
([#L43-L47](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/secretspec.nix#L43-L47),
[#L78-L86](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/secretspec.nix#L78-L86)).
Secrets are declared as typed submodules keyed by the env var name the child
process should see, each mapping to a 1Password item and field
([#L88-L113](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/secretspec.nix#L88-L113)).
A read-only `wrapArgs` option exports the exact argv prefix to wrap a command
with, including a `--reason` string because secretspec 0.17 refuses to resolve
for an agent-launched process without one
([#L122-L142](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/secretspec.nix#L122-L142)).
The value never reaches disk in Nix-owned state; it reaches the child's
environment only.

**4. `op read` at activation, for the cases secretspec cannot cover.** An
HTTP-transport MCP server carries its token in an `Authorization` header
string, so there is no child process to wrap. That one stays on
`$(op read op://nix/leanix-mcp/token)` evaluated at activation, and the comment
explicitly refuses `2>/dev/null` so a locked vault fails the switch loudly
rather than registering an empty token
([hosts/home/jeff/work-laptop.nix#L19-L30](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/home/jeff/work-laptop.nix#L19-L30)).
The cost is stated plainly in `CLAUDE.md`: the resolved value is baked into
`~/.claude.json`
([CLAUDE.md#L50](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/CLAUDE.md#L50)).

Biometric `op` is still used interactively everywhere: `eval $(op signin ...)`
is a documented bootstrap step on every host, and atuin login pulls three
fields with `op item get --reveal`
([hosts/darwin/README.md#L86-L113](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/darwin/README.md#L86-L113),
[hosts/nixos/nas/README.md#L107-L120](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/nixos/nas/README.md#L107-L120)).
The 1Password SSH agent socket is wired as `SSH_AUTH_SOCK` at the system level
and as `IdentityAgent` per host
([darwin-modules/base.nix#L77-L79](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/darwin-modules/base.nix#L77-L79),
[hosts/home/jeff/work-laptop.nix#L62-L64](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/home/jeff/work-laptop.nix#L62-L64)),
and 1Password's `op-ssh-sign` is the git signer on Darwin
([hosts/home/jeff/default.nix#L67-L75](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/home/jeff/default.nix#L67-L75)).

### Root per switch

`darwin-rebuild switch` needs sudo, and the bootstrap documents it
([hosts/darwin/README.md#L55-L69](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/darwin/README.md#L55-L69)).
Two things soften it: `touchIdAuth` on `sudo_local` and a sudo timestamp
timeout of 30 minutes
([darwin-modules/base.nix#L167-L170](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/darwin-modules/base.nix#L167-L170)).
The home-manager half needs no root at all, which is why the split matters
operationally. Determinate Nix owns the daemon and `nix.conf`, so nix-darwin's
Nix management is switched off with `nix.enable = false`
([#L56-L58](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/darwin-modules/base.nix#L56-L58),
[determinate.nix#L18-L26](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/darwin-modules/determinate.nix#L18-L26)),
and home-manager mirrors that decision on the HM side
([home-modules/base.nix#L39-L51](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/base.nix#L39-L51)).

## 4. Testing And CI

There are **no `checks` outputs and no `nix flake check` in CI**. The repo's own
`CLAUDE.md` says so directly: "There is no CI build check, local verification is
the only guardrail," with the local recipe being `nix fmt` then `nix flake check`
([CLAUDE.md#L82-L87](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/CLAUDE.md#L82-L87)).
Neither workflow triggers on push or pull request. Both are `schedule` plus
`workflow_dispatch` only
([main.yml#L3-L7](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/.github/workflows/main.yml#L3-L7),
[bump-packages.yml#L3-L7](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/.github/workflows/bump-packages.yml#L3-L7)).
So a hand-written commit gets no automated gate.

What the bump workflows do run is a good pattern regardless. A three-way
platform matrix (`ubuntu-latest`, `ubuntu-24.04-arm`, `macos-latest`)
evaluates a named list of attributes per runner with
`nix eval --no-write-lock-file ".#$attr.drvPath"`, covering
`nixosConfigurations.<h>.config.system.build.toplevel`,
`darwinConfigurations.Jeffs-M3Pro.config.system.build.toplevel`, and
`homeConfigurations."<u>@<h>".activationPackage`
([main.yml#L49-L114](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/.github/workflows/main.yml#L49-L114)).
The package workflow additionally builds each derivation on every system that
can natively build it before evaluating the hosts
([bump-packages.yml#L106-L124](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/.github/workflows/bump-packages.yml#L106-L124)).

Two exclusions are documented in comments. `work-laptop` and
`jeff@work-laptop` are excluded from every eval leg because they import the
git-crypt-encrypted `secrets.nix`, which the runner cannot read
([main.yml#L39-L43](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/.github/workflows/main.yml#L39-L43)).
And the matrix is split per platform rather than cross-evaluated because some
configs need import-from-derivation, which fails outright on a foreign-arch
runner
([#L45-L48](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/.github/workflows/main.yml#L45-L48)).

The only formatting gate is a local Claude Code `PostToolUse` hook that runs
`nix fmt` on any `.nix` file the agent writes
([.claude/settings.json](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/.claude/settings.json)),
with `perSystem.formatter = pkgs.nixfmt`
([formatter.nix#L3-L7](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/wiring/formatter.nix#L3-L7)).
No module tests, no `nmt`, no golden output assertions, no VM tests.

## 5. Compare With Our Target-State Doc

### Problem C: does opnix validate our recommendation?

Our doc's recommendation is: `op read` in activation for interactive Macs,
opnix only if a headless host must apply unattended. Both keep `op://`
references committed and values out of the store
([target-state, Problem C](../nix-target-state-research.md)).

**This repo does exactly that split, independently, and the split holds under
production use.** opnix appears only on the two headless NixOS servers. Both
Macs use `op read` at activation, or secretspec, or interactive `op`. On the
Darwin side opnix is imported and its package is installed, but nothing
declares a secret through it. Our recommendation should stand.

It does **not** answer open question 5. The question is whether 1Password
service accounts can read the vaults holding the three license items. What this
repo shows is that a service account token at `/etc/opnix-token` can resolve
eleven references in a single `op://nix/...` vault on Linux. That vault appears
to be purpose-built for the flake, which is the easy case. Nothing here touches
a vault that also holds biometric-gated personal items, and nothing runs opnix
under launchd on macOS. Open question 5 stays open, but the repo narrows it: if
you are willing to put the license items in a dedicated vault the service
account owns, the mechanism works. The remaining unknown is macOS.

**It also complicates our doc in one respect our table does not cover.** Our
Problem C table lists opnix's token as `/etc/opnix-token`, mode 640. This repo
sets the path and never provisions the file. There is no bootstrap step, no
script, and no README line for it, in a repo that documents `op signin`,
git-crypt unlock, atuin login, and kubeconfig setup for every host. That is the
part of the opnix story that is genuinely operationally awkward: the token is a
chicken-and-egg bootstrap credential that nothing declarative can place. Our
doc should say so.

**And it adds a fourth mechanism we did not consider.** secretspec's cached
provider solves a problem our doc's four-row table has no answer for: a secret
needed repeatedly at *process launch*, not once at activation. Our `op read` row
resolves once per switch and bakes the value into a config file, which is
exactly the failure mode the secretspec comment describes and replaces
([secretspec.nix#L4-L27](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/secretspec.nix#L4-L27)).
We have the same shape: agent CLIs launching MCP servers that need tokens. The
keyring-cached-with-op-fallback pattern is worth adding as a fifth row.

**Finally, the git-crypt row is a cautionary tale for our "no eval-time secrets"
rule.** This repo breaks the rule for three identity strings, and the visible
cost is that both work-laptop configurations are permanently excluded from CI
evaluation. The one host with the most unusual environment is the one host
nothing automated ever evaluates. Our doc's "anything read during evaluation is
copied into the store" argument is correct; this adds a second, cheaper
argument that eval-time secrets cost you CI coverage on exactly the hosts that
need it most. Worth adding one sentence.

### Composition model

Our doc's native target is app modules that own a package, its config, its
defaults domain, its launchd agent, and its secret references; roles import app
modules; hosts import roles. This repo is one step short of that. It has app
modules with enable options, but no roles, and hosts do not import at all: every
module is imported into every host of its class and selection happens purely
through `enable`
([hosts.nix#L21-L24](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/wiring/hosts.nix#L21-L24)).

Two observations. First, the enable-flag model works fine at 8 hosts and 60
feature modules, so our doc's claim that roles and imports replace the layered
resolver is directionally confirmed even in this weaker form: there is no
resolver here, no data layer, no `fromTOML`. Second, the pattern does have a
cost this repo pays: because everything is imported everywhere, every module's
options are evaluated on every host, and turning something off is an explicit
negative rather than an absence. Our doc's role-import shape is better and this
repo is weak evidence for preferring it, not against it.

The strongest confirmation is the module ownership property. `secretspec.nix`
owns its own typed options, its generated config file, its package, and exports
a `wrapArgs` contract that hosts consume
([secretspec.nix#L69-L148](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/secretspec.nix#L69-L148)).
`gatus.nix` declares its own opnix secrets rather than adding them to a central
list
([gatus.nix#L216-L226](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/nixos-modules/gatus.nix#L216-L226)).
That is precisely our doc's "an app module owns its secret references." It
works.

The dendritic `import-tree` trick is worth stealing. It removes the entire class
of "I added a file and forgot to wire it," which is a real cost in our current
repo. The gotcha is documented and real: host files must live outside the
scanned tree
([CLAUDE.md#L10](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/CLAUDE.md#L10)).
Our doc's tree does not mention `import-tree`. It should, as an option under
`modules/flake/`.

### What disappears

Every row in our "what disappears" table that this repo can speak to is
confirmed. There is no resolver, no cask gate, no group union, no `onchange`
hash line, no Brewfile renderer, no drift banner, no first-run prompt, and no
plist modify stub anywhere in 99 files. The Brewfile is nix-darwin's
`global.brewfile = true` output
([homebrew.nix#L29](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/darwin-modules/homebrew.nix#L29)).

One row needs a caveat. Our table says the retired-package ledger is "gone for
Nix packages, Homebrew cleanup is a per-host policy (row 11)," and open question
7 asks whether `cleanup = "uninstall"` is acceptable on the work Mac. This repo
answers yes: it runs `cleanup = "uninstall"` with `extraFlags = [ "--force" ]`
on both Macs including the work one
([#L23-L29](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/darwin-modules/homebrew.nix#L23-L29)).
That is one data point, from a Mac whose MDM posture we cannot see, so it does
not close the question. It does show the aggressive setting is livable rather
than theoretical.

Our doc's row 13 assumes nix-homebrew. This repo deliberately does not use it:
Homebrew is a manual bootstrap step and nix-darwin's `homebrew` module drives
`brew bundle` on top. That is the simpler path and it removes a flake input plus
three tap inputs. Worth listing as an alternative in row 13 rather than treating
nix-homebrew as the default answer.

### Per-app ownership

Our per-app table's Claude Code row is the one that needs correcting. It
reasons about managed drop-ins at
`/Library/Application Support/ClaudeCode/managed-settings.json` and concludes
that hooks and permissions move there while `enabledPlugins` stays user-level.
That analysis may still be right, but it skips a prior fact this repo
establishes: **the user-level `~/.claude/settings.json` cannot be a symlink at
all.** Claude Code opens it with `O_NOFOLLOW` and refuses to write through a
symlink, silently
([claude-code.nix#L6-L23](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/claude-code.nix#L6-L23)).

Our Problem A analysis names a different failure mode: `home.file` places a
symlink, the app saves by write-and-rename, the symlink is replaced by a regular
file, and the next switch refuses with "would be clobbered." That mode is real
for apps that rewrite. This is a third mode our doc does not name: the app
detects the symlink and declines to write, and nothing fails loudly. Anything in
our repo that would put a store symlink at a path Claude Code writes needs the
copy treatment instead. Our doc should add this to Problem A and to the Claude
row of the per-app table.

The rest of the per-app table gets no evidence. This repo has no crit, Cursor
CLI, pi, Orca, agentsview, Yojam, or obsidian-wiki. It has no Codex managed
layer in use (Codex appears only as two Homebrew casks on the work Mac).

### Problem A: files the app also writes

This repo has one such file and solves it with **overwrite plus a reconcile
loop**, not a merge. That is a strategy our doc's three tiers do not include and
should. The shape is:

1. Nix generates the whole file.
2. Activation compares the live file to the generated file, normalized with
   `jq -S`, and stashes a timestamped copy on any semantic difference.
3. Activation overwrites with `install -m 644`.
4. A slash command triages the stashes and folds keepers into the Nix defaults;
   the statusline shows an unreconciled count so drift is visible.

([claude-code.nix#L586-L601](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/claude-code.nix#L586-L601),
[.claude/commands/reconcile-claude-settings.md](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/.claude/commands/reconcile-claude-settings.md))

This is strictly worse than our mergers in fidelity, and strictly better in
comprehensibility. The trade it accepts is stated in the file's own header:
runtime `/config` and `/effort` changes are reverted on the next switch. For our
repo, where the merge programs exist specifically because a full rewrite would
log the Cursor CLI out or drop Orca's hook injections, overwrite-plus-stash is
not a general substitute. But it is a good answer for the subset of files where
the only thing at risk is a user preference we could just as well have declared.
Add it as tier 0 in Problem A: "ask first whether the file can simply be owned,
with a drift stash as the safety net."

Two smaller Problem A findings. Their `install -m 644` rather than a store
symlink is also our answer for row 2 (`private_` 0600 targets); the same
activation-copy pattern serves both. And the `rm -f` before `install` is a
non-obvious correctness detail: without it, `install` follows a stale store
symlink into the read-only store
([#L596-L601](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/claude-code.nix#L596-L601)).
Worth noting wherever our doc describes activation-time copies.

### Problem B: the MDM-managed work Mac

This is the most and least useful comparison at once.

Most useful: it is an existence proof that a work MacBook Pro at a large
enterprise runs full nix-darwin with Determinate Nix, root activation on every
switch, `homebrew.onActivation.cleanup = "uninstall"`, `system.defaults`, and a
corporate TLS-intercepting proxy, and that the author considers this routine
enough to document as a two-command day-to-day loop. Our doc's Problem B is
mostly about whether that is possible at all. Here it is being done.

Least useful: **there is not a single managed-device concession in the code.**
No Jamf policy trigger, no admin-group check, no privilege helper, no
home-manager-only fallback host. Our doc's Problem B table ranks "standalone
home-manager only" above "nix-darwin plus HM," on the grounds that on our work
Mac the user is not in `admin` by default so every switch is a Jamf ritual. This
repo does not face that constraint, or faces it and handles it entirely outside
the repo. Either way it cannot validate our ranking. It does not contradict it
either.

What it does contribute is the shape of the concessions that *are* needed for a
corporate Mac, and they are all TLS and identity, not privilege:
`security.pki.certificateFiles` for the system trust store, four CA env vars in
the shell for Node, Python, and Nix, and aliasing `git` to `/usr/bin/git` so
keychain certs are used for HTTPS
([work-laptop.nix#L18-L23](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/darwin/work-laptop.nix#L18-L23),
[hosts/home/jeff/work-laptop.nix#L105-L117](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/home/jeff/work-laptop.nix#L105-L117)).
That is directly relevant to us: the `ask` rustls `UnknownIssuer` failure our
doc's Method section records, and the `NODE_EXTRA_CA_CERTS` note in our machine
memory, are the same problem. Our Problem B section should list corporate CA
plumbing as a work-Mac requirement alongside privilege, because it is the part
that has to be declared in the config rather than negotiated with IT.

One more Problem B data point our doc predicted correctly: they use
`touchIdAuth` for `sudo_local` plus a 30-minute sudo timestamp
([darwin-modules/base.nix#L167-L170](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/darwin-modules/base.nix#L167-L170)),
which is exactly our doc's observation that Touch ID removes the typing, not the
group requirement.

And the two-command split (nix-darwin then standalone home-manager) is our
doc's Problem B option 1 and option 2 running side by side rather than as
alternatives. Worth noting: the expensive root half changes rarely, the cheap
user half changes constantly, and separating them means most switches need no
sudo at all. Our doc frames these as a choice; this repo shows they compose.

### The test surface

Our doc says `nix flake check` does not touch `darwinConfigurations` or
`homeConfigurations`, so every host must be exposed explicitly as
`checks.<system>.<host>`. This repo confirms the underlying problem and solves
it differently: it exposes nothing under `checks` and instead enumerates the
attributes by hand in CI, running `nix eval ".#$attr.drvPath"` per host on a
matching-arch runner
([main.yml#L49-L114](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/.github/workflows/main.yml#L49-L114)).

That is cheaper than our doc's proposal, and weaker. `nix eval .drvPath` proves
the configuration evaluates and every dependency resolves. It does not prove
anything builds. Their package workflow adds `nix build --no-link` but only for
the six own-derivations, not for the host closures
([bump-packages.yml#L106-L113](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/.github/workflows/bump-packages.yml#L106-L113)).
Our doc should keep the `checks` recommendation, because it makes
`nix flake check` meaningful locally as well as in CI, but note the eval-only
lane as a cheap first step: it caught the class of failure the daily lock bump
actually produces.

The arch-matrix finding is worth carrying over verbatim: configurations that
need import-from-derivation cannot be evaluated on a foreign-arch runner at all,
so cross-evaluating every host on one Linux runner does not work
([main.yml#L45-L48](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/.github/workflows/main.yml#L45-L48)).
Our doc's test section does not mention IFD.

Finally, gate placement. Their eval gate runs on scheduled bumps, not on human
commits, and their own `CLAUDE.md` admits the gap. Our repo already has CI on
push. Keep it.

### Other open questions this touches

- **Open question 2** (does a running app overwrite a `defaults` write?). No
  evidence. They write about 40 keys through `system.defaults` and
  `CustomUserPreferences` and never mention the problem, which is weak evidence
  that it is not a daily nuisance for common system domains. Not an answer.
- **Open question 7** (Homebrew fully declarative per host?). Answered
  affirmatively for this author, on both Macs, as described above.
- **Open question 11** (which plist domains are safe for whole-domain import?).
  Sidestepped. They never use `defaults import`; `CustomUserPreferences` writes
  per key, which is the conservative choice by default.
- **Open question 12** (values exceeding nix-darwin's typed defaults?).
  Confirmed as a real limit in practice. Six domains including
  `com.apple.finder`, iTerm2, and noTunes are expressed through
  `CustomUserPreferences` rather than typed options
  ([darwin-modules/base.nix#L149-L164](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/darwin-modules/base.nix#L149-L164)),
  and `NSGlobalDomain` keys are split across both mechanisms. Expect the same
  split.
- **Row 34** (mise runtimes versus nixpkgs). They have no mise. Node, Python,
  Java, and Terraform come from nixpkgs on the work Mac
  ([hosts/home/jeff/work-laptop.nix#L45-L59](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/hosts/home/jeff/work-laptop.nix#L45-L59)).
  But the Claude Code binary is deliberately kept **outside** Nix with
  `package = null` so it can self-update
  ([claude-code.nix#L535-L538](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/modules/home-modules/claude-code.nix#L535-L538)).
  That is the same trade our ADR 0005 makes with mise for `latest` AI CLIs,
  reached by a different route. Row 34's "partial by policy" verdict holds.

## 6. What To Take, What To Avoid

### Take

1. **`import-tree` for the module tree.** One line in `flake.nix`, and adding a
   module is dropping a file. Directly addresses the "eleven to thirteen files
   per app" complaint our doc opens with. Pair it with the documented gotcha
   about keeping host files outside the scanned tree.
2. **The `install -m 644` activation copy with a drift stash.** For any file the
   app also writes where a merge is overkill. And use it unconditionally for
   `~/.claude/settings.json`, which cannot be a symlink.
3. **secretspec's cached provider for process-launch secrets.** Keyring cache
   with an `op` fallback and a tunable max age. Solves the biometric-prompt-per-launch
   problem our `op read` row does not address.
4. **Per-module secret declarations.** `gatus.nix` declaring its own opnix
   secrets is our doc's app-module ownership rule, working.
5. **The arch-matrix eval lane in CI.** Cheap, and IFD makes it necessary rather
   than merely tidy.
6. **A `wrapArgs`-style read-only option** as the contract between a mechanism
   module and its consumers. Better than documenting an argv convention in a
   comment.
7. **Separating the root switch from the user switch** so that most changes need
   no sudo.

### Avoid

1. **git-crypt for eval-time values.** It costs you CI coverage on the affected
   host permanently, and the values still land in the store. Our
   "no secrets at evaluation" rule is right.
2. **Importing every module into every host.** Fine at their size; our doc's
   role-and-import shape is better and we should not regress to enable-flag-only.
3. **Scheduled-only CI.** No gate on human commits.
4. **`onActivation.cleanup = "uninstall"` with `--force` without deciding it per
   host.** Their choice is defensible; adopting it unexamined on a work Mac is
   not.
5. **Importing a module you do not use.** `inputs.opnix.darwinModules.default`
   and `inputs.opnix.homeManagerModules.default` are imported on Darwin and
   home-manager and never used, which is dead weight and misleading to a reader.
6. **Duplicated workarounds.** Their own `CLAUDE.md` flags that the fish
   codesigning fix exists twice and removing one breaks the other
   ([CLAUDE.md#L43](https://github.com/billimek/dotfiles/blob/9b1e33e0051573b7c84ecf6e87613c94deb0f773/CLAUDE.md#L43)).
   A known hazard, documented rather than fixed.

### Relevance: 4 out of 5

Four, not five, and not three.

Why it is high: this is the closest structural match we have found to our own
problem. Same platform pair (macOS plus headless Linux), same personal-and-work
Mac split, same 1Password-as-secret-store posture, same agent CLI surface
(Claude Code, Copilot, Gemini, opencode, MCP servers), same Homebrew-for-GUI-apps
concession, same Determinate Nix. It is the only repo in the set that runs opnix
in production, which is the mechanism our Problem C hinges on, and it runs it in
exactly the place our doc recommends and nowhere else. It independently arrived
at the interactive-versus-headless secret split we proposed. Its
`~/.claude/settings.json` finding is a concrete correction to our per-app table
that we would otherwise have discovered the hard way. Its work Mac is an
existence proof for full nix-darwin under corporate management. Its CI is a
usable pattern. And the whole thing is heavily commented by someone who wrote
down why, which makes it unusually good evidence.

Why it is not five: the surface it exercises is much narrower than ours on the
hardest axis. We have 22 files the app also writes; this repo has one. It has no
plist merging, no `defaults import`, no launchd, no quit-and-relaunch problem,
no per-machine cask gating, no `.chezmoiremove` equivalent, no MAS versus Setapp
distinction, no privilege-escalation flow, and no test suite. On Problem A it
gives us one good pattern and no evidence for the other twenty-one files. On
Problem B its work Mac has no MDM concessions to learn from, which is the exact
thing we most wanted. On open question 5 it narrows but does not answer. It is
also young: the Nix content is under two months old, so nothing here has been
load-tested across a macOS major upgrade or a real MDM policy change.

Why it is not three: the Problem C confirmation and the Claude Code finding are
each individually worth the read, and the composition pattern is directly
adoptable.

## 7. Scorecard Against Our Concept Map

Rows are from Appendix A of [nix-target-state-research.md](../nix-target-state-research.md).
Only rows this repo provides evidence for are listed.

| Row | Verdict | Note (five words) |
| ---: | --- | --- |
| 1 | Supports | `home.file` used exactly as described |
| 2 | Alternative | Activation `install -m` replaces mode |
| 3 | Supports | `executable = true` on statuslines |
| 5 | Supports | `stdenv.isDarwin` conditionals replace templates |
| 6 | Supports | Central registry replaces prompt state |
| 8 | Alternative | Two layers only, `mkDefault`/`mkForce` |
| 9 | Supports | Casks merge from module plus host |
| 10 | Supports | Runtimes come from nixpkgs directly |
| 11 | Supports | `cleanup = "uninstall"` on both Macs |
| 13 | Alternative | Manual Homebrew bootstrap beats nix-homebrew |
| 16 | Supports | `lib.mkIf cfg.enable` gates everything |
| 17 | Alternative | Host lists casks, no gate |
| 21 | Supports | `dag.entryAfter writeBoundary` for side effects |
| 23 | Supports | Typed defaults plus `CustomUserPreferences`, no merge |
| 24 | Contradicts | Symlink refused entirely, not clobbered |
| 26 | Supports | Both mechanisms needed, roughly forty keys |
| 27 | Supports | Root switch, Touch ID, no Jamf |
| 29 | Alternative | Drive tool CLI at activation |
| 33 | Supports | `programs.gh.extensions` takes nixpkgs packages |
| 34 | Supports | Agent binary deliberately outside Nix |
| 37 | Supports | Activation `op read`, plus two more |
| 40 | Supports | `force = true` where Nix owns |
| 41 | Supports | Standalone home-manager on headless Linux |
| 42 | Alternative | Eval `drvPath` instead of building |
