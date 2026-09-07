---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-04
updated: 2026-09-04
related:
  - ../nix-target-state-research.md
  - ../nix-migration-research.md
status_detail: "Agent survey of malob/nix-config at 26eed08087ca43aa2f17f381e226b491f6c74669, compared with the Nix target-state doc. Unreviewed."
---

# Survey: malob/nix-config

## Method

Surveyed on 2026-09-04 against a pinned tarball of
[malob/nix-config](https://github.com/malob/nix-config) at commit
`26eed08087ca43aa2f17f381e226b491f6c74669`, fetched with
`gh api repos/malob/nix-config/tarball/<sha>`. Repo metadata, contributor
counts, and 52-week commit participation came from the GitHub API on the same
day.

Read in full: `README.md`, `CLAUDE.md`, `flake.nix`, `default.nix`,
`lib/mkDarwinSystem.nix`, `lib/lsnix.nix`, all five files under `darwin/`,
`home/claude.nix`, `home/packages.nix`, `home/config-files.nix`,
`home/fish.nix`, `home/git.nix`, `home/ghostty.nix`,
`modules/darwin/users.nix`, `modules/home/colors/default.nix`,
`modules/home/programs/starship/extras.nix`,
`.github/workflows/ci.yml`, `.claude/settings.json`,
`.claude/hooks/format-nix.sh`, `.gitignore`, `configs/claude/settings.json`,
`configs/claude/skills/.gitignore`, and
`configs/claude/plugins/.claude-plugin/marketplace.json`. Skimmed the
remaining `home/` modules and the `modules/home/colors` generators for size
and shape. Parsed `flake.lock` for input freshness.

Not read in depth: the 894-line `modules/home/colors/colorscheme.nix` and the
484-line `modules/home/colors/tmtheme.nix` beyond their option surface, and
the plugin and skill payloads under `configs/claude/plugins` and
`configs/claude/skills`.

No repo history archaeology was done. Claims about how the config looked in
the past are absent rather than inferred.

Comparison targets: [nix-target-state-research.md](../nix-target-state-research.md)
(read in full, including the 42-row concept map and the 16 open questions),
[nix-migration-research.md](../nix-migration-research.md) ("Options" and
"Sizing"), and [chezmoi-architecture.md](../../references/chezmoi-architecture.md).

## 1. What It Is

Malo Bourgon's personal Nix configuration, MIT licensed, created 2019-03-29,
last pushed 2026-08-30. 462 stars, 37 forks, 1 open issue. The author is a
nix-darwin contributor and also writes
[prefmanager](https://github.com/malob/prefmanager), a "WIP tool for managing
macOS defaults" (35 stars, last pushed 2026-05-07), which this config installs
on Darwin ([home/packages.nix#L229-L237](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/packages.nix#L229-L237)).

Platforms: macOS through nix-darwin with home-manager as a nix-darwin module,
and non-NixOS Linux through standalone home-manager
([README.md#L21](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/README.md#L21)).

Hosts. One real Mac, `darwinConfigurations.MaloBookPro`
([flake.nix#L229-L274](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L229-L274)).
Two minimal bootstrap systems, `bootstrap-x86` and `bootstrap-arm`
([flake.nix#L217-L226](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L217-L226)).
One CI variant, `githubCI`, produced by overriding `MaloBookPro`
([flake.nix#L277-L284](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L277-L284)).
One Linux user config, `homeConfigurations.malo`, and its CI override
`homeConfigurations.runner`
([flake.nix#L290-L316](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L290-L316)).
So one real machine, one real Linux target, and three CI or bootstrap
derivatives.

Size. 228 files total, 26 of them `.nix`, 3,350 lines of Nix. The split is
420 lines in `flake.nix` and `default.nix`, 343 in `darwin/`, 1,005 in
`home/`, 76 in `lib/`, and 1,506 in `modules/`. Of the `modules/` total,
1,378 lines are the two colorscheme generators. Strip those and the reusable
option surface is 128 lines: a 26-line user-info module and a 70-line
Starship preset module.

Activity. 825 commits by the author, plus 3, 2, and 2 from three outside
contributors. 215 commits in the trailing 52 weeks. Steady, single-owner,
seven years old.

Lock bumping. A weekly cron at `0 0 * * 0` runs `nix flake update`, builds
and switches, and only if that succeeds commits and pushes the updated lock
([.github/workflows/ci.yml#L12-L13](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/.github/workflows/ci.yml#L12-L13),
[#L35-L38](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/.github/workflows/ci.yml#L35-L38),
[#L51-L58](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/.github/workflows/ci.yml#L51-L58)).
The surveyed HEAD is itself one of those bot commits, message "Update inputs".
The lock holds 30 nodes; `nixpkgs-unstable` was locked 2026-08-29, nix-darwin
2026-08-16, home-manager 2026-08-27. The build-gated auto-commit is the only
freshness mechanism; there is no human review step in the loop.

## 2. Composition

There is no role layer and there are no per-app modules in the sense our
target-state doc uses. `flake.nix` exports two flat attribute sets,
`darwinModules` and `homeManagerModules`
([flake.nix#L166-L211](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L166-L211)),
and every host imports all of them with `attrValues`
([flake.nix#L233](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L233),
[#L272](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L272),
[#L293](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L293)).
Nothing selects a subset.

Differentiation happens two ways instead.

- Inside modules, with `lib.mkIf pkgs.stdenv.isDarwin` or
  `lib.optionalAttrs isDarwin`
  ([home/claude.nix#L193](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/claude.nix#L193),
  [home/packages.nix#L229-L237](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/packages.nix#L229-L237)).
  The same module file serves Darwin and Linux.
- At the host attribute, with `lib.makeOverridable` plus `.override`. The CI
  Mac is `MaloBookPro` with a different username, a different flake
  directory, and two `mkForce false` lines that disable Homebrew and
  `/etc/shells`
  ([flake.nix#L277-L284](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L277-L284)).
  The CI Linux user is `homeConfigurations.malo` with three `mkForce`
  overrides
  ([flake.nix#L308-L316](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L308-L316)).

Machine identity is four strings. `modules/darwin/users.nix` declares
`users.primaryUser.{username,fullName,email,nixConfigDirectory}` as nullable
options
([modules/darwin/users.nix#L8-L25](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/modules/darwin/users.nix#L8-L25)).
`lib/mkDarwinSystem.nix` sets them, sets `system.primaryUser`, and re-exports
the same values to every home-manager module as `config.home.user-info`
([lib/mkDarwinSystem.nix#L35-L57](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/lib/mkDarwinSystem.nix#L35-L57),
[flake.nix#L199-L206](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L199-L206)).
There is no machine type, no feature flag, no capability set, and no data
file of any kind. Host-specific facts such as `networking.computerName` and
`knownNetworkServices` are inlined in the host attribute
([flake.nix#L236-L241](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L236-L241)).

There is no work versus personal split. One Mac, no MDM, no second identity.
Nothing in this repo speaks to that problem.

The Linux target is real, not decorative. `homeConfigurations.malo` builds
for `x86_64-linux` from the same home modules and is activated with
`nix build .#homeConfigurations.malo.activationPackage && ./result/activate`
([flake.nix#L287-L305](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L287-L305)).

Other structural notes. `flake-utils.lib.eachDefaultSystem` is used only for
`legacyPackages` and three dev shells, not for the system configurations
([flake.nix#L318-L403](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L318-L403)).
Four nixpkgs channels are exposed side by side through overlays so any
package can be pulled from master, stable, unstable, or x86
([flake.nix#L117-L145](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L117-L145)).
`default.nix` provides flake-compat for legacy Nix
([default.nix#L1-L15](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/default.nix#L1-L15)).
Nix itself is not managed by nix-darwin: `nix.enable = false` and the
Determinate darwin module owns the installation
([darwin/bootstrap.nix#L10-L25](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/bootstrap.nix#L10-L25),
[flake.nix#L178](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L178)).

## 3. Per-App Config Mechanics

### programs.* and generated files

The default path is home-manager's typed program modules: `programs.git`,
`programs.gh`, `programs.delta`, `programs.lazygit`
([home/git.nix#L7-L41](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/git.nix#L7-L41)),
`programs.ghostty` with generated themes
([home/ghostty.nix#L9-L40](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/ghostty.nix#L9-L40)),
`programs.bat`, `programs.yazi`, `programs.zsh`, `programs.fish`, and about a
dozen more
([home/packages.nix#L58-L153](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/packages.nix#L58-L153)).
`programs.zsh.dotDir` is set to the XDG config directory
([home/packages.nix#L151-L153](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/packages.nix#L151-L153)).

Where no program module exists, files are generated whole with
`xdg.configFile.<path>.text`, including a YAML Stack config built with
`lib.generators.toYAML`
([home/config-files.nix#L54-L65](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/config-files.nix#L54-L65))
and a Fish theme file assembled from the colorscheme module
([home/fish.nix#L19-L28](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/fish.nix#L19-L28)).
XDG is on and preferred
([home/config-files.nix#L12-L15](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/config-files.nix#L12-L15)).

Two custom option modules exist. `colors` declares an `attrsOf submoduleWith`
scheme type
([modules/home/colors/default.nix#L16-L31](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/modules/home/colors/default.nix#L16-L31)).
`programs.starship.extras.presets` is an `attrsOf bool` that reads preset TOML
out of the Starship package with `builtins.fromTOML` and merges it in at
`mkDefault` priority
([modules/home/programs/starship/extras.nix#L31-L68](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/modules/home/programs/starship/extras.nix#L31-L68)).

### The app-rewritten file: Claude Code

This is the only app in the repo whose config the app itself writes, and the
answer is not a merger. It is a split.

The Nix-owned half is small and root-owned.
`darwin/claude-managed-settings.nix` builds a JSON file containing exactly
three things, all of which need the flake's absolute path interpolated:
`additionalDirectories`, two `permissions.allow` entries, and one
`extraKnownMarketplaces` entry pointing at `configs/claude/plugins`
([darwin/claude-managed-settings.nix#L20-L33](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/claude-managed-settings.nix#L20-L33)).
It is installed by `system.activationScripts.postActivation` as a symlink from
`/Library/Application Support/ClaudeCode/managed-settings.json` to a store
path
([darwin/claude-managed-settings.nix#L40-L44](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/claude-managed-settings.nix#L40-L44)).
The file header states the rule: "Only path-dependent settings that need
nixConfigDirectory interpolation belong here"
([darwin/claude-managed-settings.nix#L1-L7](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/claude-managed-settings.nix#L1-L7)).

Everything else, including hooks, the entire permission allowlist,
`enabledPlugins`, `statusLine`, and UI preferences, lives in a plain
git-tracked JSON file at `configs/claude/settings.json`
([configs/claude/settings.json#L119-L193](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/configs/claude/settings.json#L119-L193)),
which is linked into `$HOME` with `mkOutOfStoreSymlink`. Eight paths are
linked that way, covering `settings.json`, `CLAUDE.md`, `skills`, `agents`,
`rules`, `hooks`, `statusline.sh`, and the 1MCP server config
([home/claude.nix#L144-L155](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/claude.nix#L144-L155)).
The stated reason is live editing without a rebuild
([CLAUDE.md#L57-L68](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/CLAUDE.md#L57-L68)).

The consequence is that Claude Code writes into the git working tree. The repo
absorbs that instead of fighting it: `configs/claude/skills/.gitignore`
ignores everything and un-ignores only committed directories
([configs/claude/skills/.gitignore#L1-L7](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/configs/claude/skills/.gitignore#L1-L7)),
and the top-level `.gitignore` excludes two private context files
([.gitignore#L8-L10](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/.gitignore#L8-L10)).

One file is generated whole rather than symlinked: the Claude Desktop config,
built through a `jq`-formatting derivation
([home/claude.nix#L63-L73](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/claude.nix#L63-L73),
[#L195-L196](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/claude.nix#L195-L196)).

### macOS defaults

`darwin/defaults.nix` is 53 lines. It sets 30 keys across 6 typed nix-darwin
domains: `NSGlobalDomain` (14 keys), `dock` (8), `loginwindow` (2), `spaces`
(1), `trackpad` (2), and `finder` (3)
([darwin/defaults.nix#L1-L53](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/defaults.nix#L1-L53)).

`CustomUserPreferences` does not appear anywhere in the repo. Neither does
`CustomSystemPreferences`, `targets.darwin.defaults`, a raw `defaults write`,
`PlistBuddy`, `plutil`, `lsregister`, or `killall`. Grepped across all `.nix`,
`.sh`, and `.fish` files at this commit. No app-owned preference domain is
managed at all.

Adjacent system settings that are not `system.defaults` do appear:
`system.keyboard.userKeyMapping` for a Caps Lock swap, the application
firewall, DNS, fonts, and Touch ID for sudo
([darwin/general.nix#L8-L48](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/general.nix#L8-L48)).

### Homebrew, MAS, taps

Straight nix-darwin `homebrew` module. No nix-homebrew input; confirmed absent
from `flake.nix` inputs
([flake.nix#L4-L50](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L4-L50)).
Installing Homebrew itself is out of band.

| Setting | Value | Citation |
| --- | --- | --- |
| `homebrew.enable` | `true` | [homebrew.nix#L11](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/homebrew.nix#L11) |
| `onActivation.autoUpdate` | `true` | [#L12](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/homebrew.nix#L12) |
| `onActivation.cleanup` | `"zap"` | [#L13](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/homebrew.nix#L13) |
| `global.brewfile` | `true` | [#L14](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/homebrew.nix#L14) |
| `taps` | one, `nrlquaker/createzap` | [#L19-L21](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/homebrew.nix#L19-L21) |
| `masApps` | 32 entries | [#L26-L59](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/homebrew.nix#L26-L59) |
| `casks` | 50 plain strings | [#L65-L117](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/homebrew.nix#L65-L117) |
| `brews` | empty | [#L144-L145](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/homebrew.nix#L144-L145) |

`cleanup = "zap"` is the strongest available policy: everything not in the
generated Brewfile is removed along with its configuration. The MAS list
includes Xcode. Two casks pin a version channel in the name, notably
`claude-code@latest`
([#L77](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/homebrew.nix#L77)).

The most interesting line in the file is the cask-conditional. A local helper
`caskPresent` tests the declared cask list
([#L5](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/homebrew.nix#L5)),
and the 1Password cask's dependent home-manager config, the SSH
`IdentityAgent` match block and the git SSH signing key, is gated on it
([#L122-L140](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/homebrew.nix#L122-L140)).
Package and config live next to each other and cannot drift.

The reverse dependency also appears: `programs.ghostty.package` is forced to
`null` on Darwin because Ghostty comes from the cask
([home/ghostty.nix#L11](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/ghostty.nix#L11)).

Nix-installed GUI apps are symlinked, not copied, into
`~/Applications/Home Manager Apps`, with a comment that Raycast finds symlinks
even though Spotlight does not
([home/packages.nix#L36-L39](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/packages.nix#L36-L39)).

### launchd

One agent, `com.malo.1mcp`, declared through home-manager's `launchd.agents`
([home/claude.nix#L200-L217](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/claude.nix#L200-L217)).
Two details worth stealing. `KeepAlive.PathState` gates the service on the
existence of `~/.claude/secrets.env`, so launchd handles the dependency rather
than the script. And `EnvironmentVariables.PATH` is computed from
`osConfig.environment.systemPath` with `$HOME` and `$USER` substituted, because
GUI-launched processes do not inherit a shell PATH
([home/claude.nix#L78-L80](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/claude.nix#L78-L80)).

### Activation

Two activation blocks in the whole repo.

`system.activationScripts.postActivation` installs the managed settings
symlink, appended with `lib.mkAfter`
([darwin/claude-managed-settings.nix#L40-L44](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/claude-managed-settings.nix#L40-L44)).
That is the only thing this config does as root beyond what nix-darwin's own
modules do.

`home.activation.installClaudeSkills` runs after `writeBoundary` and
reconciles three external skills from skills.sh
([home/claude.nix#L161-L188](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/claude.nix#L161-L188)).
The comment calls the strategy "nuke and repave on each activation"
([#L159-L160](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/claude.nix#L159-L160)).
It deletes the existing symlinks and clone directory, then runs
`npx -y skills add <owner/repo> --skill <name>` per entry with `|| true`, then
runs a repair loop that rewrites relative symlinks as absolute ones because
`~/.claude/skills` is itself a symlink into the flake checkout
([#L174-L187](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/claude.nix#L174-L187)).
This is an unpinned network fetch inside activation, on every switch.

No `onChange` hook is used anywhere in the repo. No stamp files. No
once-only pattern.

### Secrets

No sops-nix, no agenix, no opnix. Grepped for all three plus `age-` across
every `.nix` file: nothing. Two patterns carry the load instead.

**`op run` wrappers.** `mkOpRunWrapper` takes a package and an attribute set of
`op://` references, writes a shell wrapper that exports them and `exec`s
`op run -- <real binary>`, then `symlinkJoin`s the wrapper over the original
package so completions and man pages survive
([home/packages.nix#L13-L31](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/packages.nix#L13-L31)).
Used for `nix-update` and `nixpkgs-review`, both needing a GitHub token
([home/packages.nix#L220-L226](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/packages.nix#L220-L226)).
The store holds only the `op://` reference. The value is resolved per
invocation inside the user's 1Password session and never touches disk.

**A 1Password Environments named pipe.** `~/.claude/secrets.env` may be a FIFO
served by 1Password. The launcher script detects the FIFO with `[[ -p ]]`,
reads it under a 15-second `timeout` to survive the boot race, exits 1 on
failure, and lets launchd's `KeepAlive` retry
([home/claude.nix#L83-L116](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/claude.nix#L83-L116)).
Again nothing in the store, and nothing in the repo.

`programs._1password-shell-plugins` is also enabled
([home/packages.nix#L41-L46](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/packages.nix#L41-L46)),
and SSH agent plus git signing route through the 1Password app
([darwin/homebrew.nix#L125-L139](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/homebrew.nix#L125-L139)).

### Root work per switch

nix-darwin activation is root by definition, and CI confirms the shape with
`sudo ./result/sw/bin/darwin-rebuild switch`
([.github/workflows/ci.yml#L49](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/.github/workflows/ci.yml#L49)).
The repo-specific root writes are: the managed settings symlink under
`/Library/Application Support/ClaudeCode`, `/etc/shells` through
`environment.shells`
([darwin/bootstrap.nix#L29-L36](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/bootstrap.nix#L29-L36)),
`/etc/nix/registry.json`
([flake.nix#L242-L257](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L242-L257)),
and whatever `homebrew` and the `system.defaults` modules do.
`security.pam.services.sudo_local.touchIdAuth = true` removes the password
prompt
([darwin/general.nix#L39-L40](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/general.nix#L39-L40)).

Turning Nix over to Determinate has a visible cost. Two options stop working
under `nix.enable = false` and each needs a hand-written workaround:
`nix.registry` is replaced by a literal `environment.etc."nix/registry.json"`
([flake.nix#L242-L257](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L242-L257))
and `nix.nixPath` is replaced by an `environment.variables.NIX_PATH` export
([lib/mkDarwinSystem.nix#L46-L47](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/lib/mkDarwinSystem.nix#L46-L47)).

## 4. Testing And CI

One workflow, two jobs, no test suite
([.github/workflows/ci.yml](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/.github/workflows/ci.yml)).

The macOS job runs on `macos-latest`, installs Nix with
`DeterminateSystems/nix-installer-action@v22`, wires up Cachix, then builds
**and activates**:
`nix build .#darwinConfigurations.githubCI.system` followed by
`sudo ./result/sw/bin/darwin-rebuild switch --flake .#githubCI`
([#L40-L49](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/.github/workflows/ci.yml#L40-L49)).
Before switching it moves two runner-provided files out of the way,
`/etc/nix/nix.custom.conf` and `/etc/zshenv`, because nix-darwin refuses to
clobber them
([#L44-L46](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/.github/workflows/ci.yml#L44-L46)).

The Linux job builds and activates the standalone home-manager config the same
way
([#L79-L84](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/.github/workflows/ci.yml#L79-L84)).

What is absent: there is no `checks` flake output, no `nix flake check`
invocation, no `nmt` file-tree assertions, no module tests, no `tests/`
directory, no linter job. Grepped for all of these at this commit. Lint
tooling exists but only as a dev shell and a Claude Code hook that runs
`nixfmt`, `deadnix`, and `statix` after edits
([flake.nix#L333-L343](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L333-L343),
[.claude/hooks/format-nix.sh#L9-L17](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/.claude/hooks/format-nix.sh#L9-L17)).
The entire verification story is "the closure builds and activation exits
zero, on two platforms, weekly and per push".

The repo does document its own operational gotchas rather than test them:
activation runs with a minimal PATH so store paths must be spelled out, and
`run --silence` hides errors when debugging
([CLAUDE.md#L125-L131](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/CLAUDE.md#L125-L131)).

## 5. Compare And Contrast With Our Target-State Doc

### Composition model

Our doc's native target is app modules imported by role modules imported by
hosts, with typed options replacing the data layer. This repo has no roles, no
app modules, and no data layer, and it imports every module into every host
([flake.nix#L233](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L233)).

That is not a contradiction, it is a scale signal. At one real Mac plus one
Linux user, `attrValues` plus `mkIf isDarwin` is enough, and the reference
config does not pay for a role layer. Our four machine types with a work Mac
that must not receive personal modules cannot use that shape. The evidence our
doc should absorb is the *cheapness of the identity layer*: this config carries
its entire machine identity in 26 lines of options and four strings
([modules/darwin/users.nix#L8-L25](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/modules/darwin/users.nix#L8-L25)),
which supports our claim that `machines.toml`, `features.tmpl`, and the layer
merge do not survive the move. Recommendation: no change to the composition
model, but add a sentence noting that the reference nix-darwin config differentiates
by `.override` on a host attribute rather than by role imports, and that roles
only earn their keep above one host.

The one place this repo does implement our idea is colocation.
`caskPresent "1password"` gates the 1Password-dependent home-manager config
inside the same file that declares the cask
([darwin/homebrew.nix#L5](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/homebrew.nix#L5),
[#L122-L140](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/homebrew.nix#L122-L140)).
That is our concept-map row 17 and our "package and config share one module"
claim, working, in a real config. Our doc should cite it.

### The "what disappears" table

| Our row | This repo | Verdict |
| --- | --- | --- |
| Brewfile renderer and golden tests gone | Literal `casks`, `masApps`, `taps` lists; nix-darwin generates the Brewfile ([homebrew.nix#L19-L117](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/homebrew.nix#L19-L117)) | Supports |
| Retired-package ledger gone | `cleanup = "zap"` ([#L13](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/homebrew.nix#L13)) | Supports, and stronger than the `"uninstall"` our doc assumes |
| Feature resolver and layered machines data gone | No data layer exists at all | Supports |
| First-run prompts gone | Host is a flake attribute | Supports |
| `run_onchange_` hash lines gone, replaced by `onChange` | No `onChange` in the repo. Activation blocks just run every switch ([home/claude.nix#L161](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/claude.nix#L161)) | Supports the removal, contradicts the replacement. The practical answer is an idempotent block, not `onChange` |
| Drift banner gone | Partly recovered. Live config is a git-tracked file, so `git status` reports per-file drift for those paths | Contradicts, narrowly |
| Plist modify stubs gone for `defaults` domains | No plist merging existed here to remove | No evidence |

The `onChange` row is worth a real edit. Our doc treats `home.file.<name>.onChange`
as the natural replacement for hash-triggered scripts, and the concept map
scores row 19 as "full". The reference config uses zero `onChange` hooks and
accepts run-every-switch. Our doc should note that `onChange` only fires for
blocks that hang off a managed file, that the fallback is an idempotent block,
and that the ecosystem's default is the fallback.

### The per-app ownership table

This repo covers exactly one row of our nine-row table, Claude Code, and its
answer differs from ours in a way that matters.

| | Our doc | malob/nix-config |
| --- | --- | --- |
| What goes in the managed drop-in | Hooks, permissions, marketplace registration | Only settings that need the flake's absolute path: `additionalDirectories`, two `permissions.allow` entries, `extraKnownMarketplaces` ([claude-managed-settings.nix#L20-L33](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/claude-managed-settings.nix#L20-L33)) |
| Where hooks live | Managed drop-in, relying on array concatenation across scopes | User file ([configs/claude/settings.json#L119-L161](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/configs/claude/settings.json#L119-L161)) |
| Where `enabledPlugins` lives | User file, to preserve ADR 0007 per-project override | User file ([#L168-L179](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/configs/claude/settings.json#L168-L179)) |
| How the user file is owned | A Python merger preserving app-written keys | Not owned. `mkOutOfStoreSymlink` into the git checkout; the app writes the repo file directly ([home/claude.nix#L148](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/claude.nix#L148)) |

Our doc should change in two places.

First, **Problem A needs a fourth tier**: link the app's own file out of the
store into the repo checkout and let the app write it. Our doc currently
dismisses this in one clause, "`mkOutOfStoreSymlink` into the repo checkout
would make the app write into the working tree", as if that settles it. The
reference config does it deliberately for eight paths and manages the fallout
with two `.gitignore` files
([configs/claude/skills/.gitignore#L1-L7](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/configs/claude/skills/.gitignore#L1-L7),
[.gitignore#L8-L10](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/.gitignore#L8-L10)).
The costs are real and should be written down: repo churn from app writes,
mandatory gitignore hygiene, secrets risk if the app writes credentials into
a tracked file, and a documented gotcha that Claude caches symlinked plugin
directories so the cache must be nuked after edits
([CLAUDE.md#L104-L108](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/CLAUDE.md#L104-L108)).
The benefits are also real: no merger to maintain, `git diff` as the drift
report, and edits without a rebuild. For our Cursor `cli-config.json` case,
where a full rewrite logs the CLI out, this tier is a live candidate.

Second, **the managed-drop-in split should get narrower**. Their rule, only
path-dependent settings go managed, is a smaller and safer target than
"hooks and permissions move to managed". It avoids relying on cross-scope array
concatenation semantics, and it keeps the root-owned surface to three keys. On
a Jamf-managed Mac where writing
`/Library/Application Support/ClaudeCode` may be blocked entirely, a
three-key managed file is much easier to give up than a hooks-and-permissions
one. Recommendation: reframe our Claude row around "what genuinely cannot live
in a user file" rather than "what the managed layer can hold".

Note also that `managed-settings.json` is installed as a **symlink to a store
path**, not a copy
([claude-managed-settings.nix#L43](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/claude-managed-settings.nix#L43)).
Claude Code evidently reads it fine on a non-MDM Mac. Unverified whether a
world-readable store symlink at a root-owned managed path is acceptable in a
managed-device policy sense.

### Problem A, plists specifically

The headline result is a null result, and it is worth stating plainly. This is
the reference nix-darwin config, written by a nix-darwin contributor who also
maintains a macOS defaults tool, and it manages 30 keys across 6 typed domains
([darwin/defaults.nix#L1-L53](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/defaults.nix#L1-L53))
and does not touch a single app-owned preference domain. No
`CustomUserPreferences`, no `targets.darwin.defaults`, no delete handling, no
quit guard, no `killall cfprefsd`.

Our doc's row 23 and row 26 rest on `CustomUserPreferences` and
`defaults import` preserving unmanaged keys. That claim was already re-verified
locally in our Appendix B, so it stands. What this survey adds is that the
claim has **no ecosystem precedent at our scale**. Our 143 `defaults write`
lines and 12 merged plist domains would put us well beyond what the reference
config attempts. Our doc should record that: the mechanism is sound, the
scale is unproven, and we would be the ones proving it.

Open question 11, which plist domains are safe for whole-domain
`defaults import`, and open question 12, which of our current plist values
exceed what typed defaults can represent, are both **unanswered** by this
repo. Neither has a worked example here. Both should be marked as unanswered
by the reference config, which raises rather than lowers their priority.

The `<!-- chezmoi-delete: ... -->` directive has no counterpart and no
counterexample here. No evidence either way.

### Problem B, the MDM work Mac

No evidence. One Mac, no MDM, no Jamf, no second identity, no temp-admin flow.

Three adjacent facts do transfer.

- `touchIdAuth` is present and does exactly what our doc says: it removes the
  password prompt, not the `admin` group requirement
  ([darwin/general.nix#L39-L40](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/general.nix#L39-L40)).
- Root activation per switch is confirmed by CI's `sudo darwin-rebuild switch`
  ([ci.yml#L49](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/.github/workflows/ci.yml#L49)).
- Our doc's Determinate paragraph is validated in practice, and it costs more
  than the doc says. `nix.enable = false` plus the Determinate darwin module is
  exactly the shape our doc describes
  ([darwin/bootstrap.nix#L10-L25](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/bootstrap.nix#L10-L25),
  [flake.nix#L178](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L178)),
  but it silently breaks `nix.registry` and `nix.nixPath`, both of which this
  repo replaces by hand
  ([flake.nix#L242-L257](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L242-L257),
  [lib/mkDarwinSystem.nix#L46-L47](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/lib/mkDarwinSystem.nix#L46-L47)).
  Our doc should add those two workarounds to the Determinate paragraph.

Our doc's Problem B ranking, standalone home-manager before nix-darwin on the
work Mac, is untouched by this survey.

### Problem C, secrets

Our doc lists four options: opnix, sops-nix, agenix, and `op read` in
activation, and recommends the fourth for interactive Macs. This repo uses
none of them and does not commit an encrypted anything.

It adds two patterns our table lacks.

| Pattern | Mechanism | Fits our repo? |
| --- | --- | --- |
| `op run` wrapper | Wrap the binary; bake the `op://` ref into a store script; `op run` resolves it per invocation in the user's session ([home/packages.nix#L13-L31](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/packages.nix#L13-L31), [#L219-L226](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/packages.nix#L220-L226)) | Yes, for every secret that is an env var. Strictly better than writing a file, because nothing lands on disk at all |
| 1Password Environments FIFO plus `KeepAlive.PathState` | The secret file is a named pipe served by 1Password; launchd only runs the service when the path exists; the reader uses a 15s timeout and exits non-zero to trigger retry ([home/claude.nix#L86-L109](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/claude.nix#L86-L109), [#L200-L217](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/claude.nix#L200-L217)) | Yes, for launchd services that need a secret and must survive a boot race |

Neither replaces our three license *files*, which have to exist on disk as
files with specific contents. For those, our doc's `op read` in activation
still looks right. But the `op run` row belongs in our table, and it is usable
today under chezmoi without any Nix at all.

Recommendation: add the `op run` wrapper row to the Problem C table, and add
the `KeepAlive.PathState` gate to concept-map row 28 as a launchd technique.

### The test surface

Two changes, in opposite directions.

**Our doc understates what CI can do.** Row 42 says activation still needs a
real machine, and the test-surface section proposes replacing the chezmoi
dry-run job with a per-host closure build. This repo runs a real
`sudo darwin-rebuild switch --flake .#githubCI` on a hosted `macos-latest`
runner, on every push and weekly
([ci.yml#L40-L49](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/.github/workflows/ci.yml#L40-L49)),
and a real `./result/activate` for the Linux config
([#L79-L84](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/.github/workflows/ci.yml#L79-L84)).
The cost is one extra host attribute with two `mkForce false` lines to disable
what cannot run there
([flake.nix#L277-L284](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L277-L284)).
Our doc should change row 42 and the test-surface section: hosted macOS
runners can exercise activation itself, so Tart is needed for GUI behavior,
app persistence, defaults verification, and MDM, not for "does activation
run".

The CI job also demonstrates row 40 at the system level, which our doc only
covers for home-manager: the first activation on a fresh machine collides with
pre-existing files and must move them aside
([ci.yml#L44-L46](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/.github/workflows/ci.yml#L44-L46)).
That is a first-switch migration step our doc should name.

**Our doc overstates the ecosystem norm.** The proposed check surface, every
host evaluating, every role importing what it should, every app contributing
its package plus files plus defaults plus service plus secret declarations, is
far beyond what this repo does. There is no `checks` output and no
`nix flake check` here at all. That does not make our plan wrong; we have 60+
make targets today and would be poorer without them. But the doc should say
plainly that the check surface it proposes exceeds the reference config, so
the effort is ours to justify rather than something the ecosystem hands over.

### Open questions this repo touches

| Q | Status after this survey |
| ---: | --- |
| 1 | Reframed, not answered. A `directory` marketplace works when the path is a plain checkout directory ([claude-managed-settings.nix#L27-L32](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/claude-managed-settings.nix#L27-L32)). Whether it works when the plugin dirs are *store* symlinks is still open, because this repo sidesteps it. New operational fact: Claude caches plugins from a symlinked marketplace and the cache must be removed after edits ([CLAUDE.md#L104-L108](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/CLAUDE.md#L104-L108)) |
| 2 | No evidence |
| 3 | No evidence |
| 7 | Answered by example for a personal Mac: yes, fully declarative Homebrew is practical, at `cleanup = "zap"` with `global.brewfile = true` ([homebrew.nix#L13-L14](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/homebrew.nix#L13-L14)). Says nothing about a work Mac |
| 9 | Reframed. Their answer is "only path-dependent settings", which is narrower than ours and reaches the same conclusion on `enabledPlugins` |
| 11 | Unanswered, and now known to be unanswered by the reference config too. Priority up |
| 12 | Unanswered, same reasoning. Priority up |
| 13 | No evidence |
| 14, 15 | No evidence |
| 16 | Partial. A managed file at `/Library/Application Support/ClaudeCode` works as a root-installed store symlink on a non-MDM Mac. The MDM half is still open |

One question to add: what breaks when `nix.enable = false` hands Nix to
Determinate? Two known casualties, `nix.registry` and `nix.nixPath`, each
needing a manual replacement
([flake.nix#L242-L257](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/flake.nix#L242-L257),
[lib/mkDarwinSystem.nix#L46-L47](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/lib/mkDarwinSystem.nix#L46-L47)).
Whether there are others is unverified.

## 6. What To Take, What To Avoid, Relevance

### Take

1. **The `op run` wrapper.** Usable today, no Nix needed. Wrap a binary,
   bake the `op://` ref, let `op run` resolve it in the user's session. Nothing
   on disk, nothing in a store, no service account. Add it to our Problem C
   table.
2. **Out-of-store symlink as a Problem A tier.** For app-owned files where a
   merger is expensive and the app's writes are content we would happily
   commit anyway, linking the file into the repo checkout turns "merge" into
   "the app owns a git-tracked file", and hands us back a per-file drift report
   we thought Nix cost us. Cursor `cli-config.json` and our agent skill and
   plugin trees are the candidates. Requires disciplined gitignores.
3. **The narrow managed-settings rule.** Put in a root-owned managed file only
   what genuinely cannot live in a user file. Three keys, not thirty. Makes the
   work-Mac question much less load-bearing.
4. **CI that actually activates.** A dedicated CI host attribute derived from
   the real one with `mkForce` disables, then `darwin-rebuild switch` on a
   hosted runner. Cheap, and much stronger than a dry run.
5. **`launchd.agents` with `KeepAlive.PathState`.** Let launchd own the
   "wait for the secret to exist" dependency instead of a retry loop in the
   script. Directly applicable to `com.prateek.wiki-sessions-sync`.
6. **Cask-conditional colocation.** `caskPresent "<cask>"` computed from the
   declared cask list, gating that cask's dependent config in the same file.
   This is our row 17 idea, proven, and it is a smaller change than a full app
   module tree.
7. **A version channel in the cask name.** `claude-code@latest` is a cheap
   answer to our "mise for `latest` AI CLIs" tension where the tool ships a
   cask.
8. Minor: Claude Code permission rules for absolute paths appear as
   `Read(//nix/store/**)` and `Edit(//Users/...)` in both the generated and the
   hand-written settings
   ([configs/claude/settings.json#L102-L105](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/configs/claude/settings.json#L102-L105),
   [claude-managed-settings.nix#L23-L26](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/darwin/claude-managed-settings.nix#L23-L26)).
   The doubled slash is consistent across both, so it reads as the intended
   absolute-path form rather than an interpolation slip. Inferred from usage,
   not from documentation.

### Avoid

1. **Unpinned `npx -y skills add` inside activation**
   ([home/claude.nix#L174-L176](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/home/claude.nix#L174-L176)).
   Network fetch on every switch, no lock, errors swallowed with `|| true`,
   and a hand-written symlink repair loop to fix what it produces. Our
   derivation-backed marketplace is better; do not regress to this.
2. **`attrValues` of every module into every host.** Fine at one Mac. Wrong
   for a work Mac that must not receive personal modules.
3. **`cleanup = "zap"` on a shared or managed machine.** Zap removes
   configuration along with the package for anything outside the Brewfile.
   Personal and homelab only, never the work Mac.
4. **Build-only CI.** Do not trade our make targets for "the closure built".
5. **Auto-committing `flake.lock` from CI without review.** Their weekly bot
   commits directly to `master`
   ([ci.yml#L51-L58](https://github.com/malob/nix-config/blob/26eed08087ca43aa2f17f381e226b491f6c74669/.github/workflows/ci.yml#L51-L58)).
   Our doc's position is that freshness becomes a lock bump you review. Keep it.
6. **Letting the app write secrets into a tracked file.** The out-of-store
   symlink tier is only safe for files whose app-written content we would
   commit. Anything that can hold a token stays merged or stays outside.

### Relevance: 4 out of 5

Reasons for the score. This is macOS-first nix-darwin from a nix-darwin
contributor, and it is the single best available worked example of the problem
class we care most about, an agent CLI whose config the app rewrites. It gives
us two secrets patterns our doc does not have, a CI shape stronger than the one
our doc proposes, and a working instance of our colocation principle. Its
silences are informative rather than empty: no `CustomUserPreferences` and no
`checks` output tell us where our plan exceeds the reference.

Reasons it is not a 5. It has one Mac, no MDM, no work versus personal split,
no plist merging, 30 defaults keys against our 143, no secret *files*, no role
layer, and no test suite. The two hardest things in front of us, the
Jamf-managed work Mac and the 22 app-owned-file merges, are almost entirely
absent. It answers or reframes 4 of our 16 open questions and leaves the two
plist questions, 11 and 12, exactly where they were.

## 7. Scorecard Against Our Concept Map

Rows are numbered as in Appendix A of
[nix-target-state-research.md](../nix-target-state-research.md). Only rows with
evidence in this repo are listed.

| Row | Verdict | Note (five words) |
| ---: | --- | --- |
| 1 | Supports | `home.file` and `xdg.configFile` throughout |
| 4 | Supports | Eight out-of-store symlinks, deliberate |
| 5 | Supports | Interpolation replaces templating, cleanly |
| 6 | Supports | Host attribute, no prompts |
| 8 | Alternative | `makeOverridable` override, not layers |
| 9 | Supports | Literal casks, masApps, taps |
| 10 | Supports | `home.packages` carries the formulae |
| 11 | Supports | Zap is broader than uninstall |
| 13 | Alternative | No nix-homebrew; Homebrew installed manually |
| 15 | Alternative | Weekly cron bumps the lock |
| 16 | Supports | `mkIf isDarwin` gates the modules |
| 17 | Supports | `caskPresent` colocates package and config |
| 19 | Contradicts | Zero `onChange`; runs every switch |
| 20 | Alternative | Nuke and repave, no stamps |
| 23 | Alternative | No plist merging even attempted |
| 24 | Alternative | Symlink the file, no merger |
| 26 | Alternative | Thirty keys, six typed domains |
| 27 | Supports | Touch ID removes password only |
| 28 | Supports | `KeepAlive.PathState` gates the agent |
| 29 | Alternative | Checkout marketplace, unpinned npx reconcile |
| 34 | Alternative | Cask `@latest` replaces mise here |
| 35 | Supports | `programs.zsh.dotDir` set to XDG |
| 36 | Supports | XDG enabled and preferred |
| 37 | Alternative | `op run` wrapper, no file |
| 38 | Alternative | Git status reports symlinked-file drift |
| 40 | Supports | CI moves conflicting system files |
| 41 | Supports | Real Linux home-manager target ships |
| 42 | Contradicts | CI activates on hosted runner |
