---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-04
updated: 2026-09-04
related:
  - ../nix-target-state-research.md
  - ../nix-migration-research.md
status_detail: "Agent survey of srid/nixos-config at 24d2f61e12de72b5f8a3b4bcebff354332cd05a9, compared with the Nix target-state doc. Unreviewed."
---

# Survey: srid/nixos-config, Against Our Nix Target State

## Method

Read on 2026-09-04 from a pinned tarball snapshot of
[srid/nixos-config](https://github.com/srid/nixos-config) at
`24d2f61e12de72b5f8a3b4bcebff354332cd05a9`, pulled with
`gh api repos/srid/nixos-config/tarball/<sha>`. All permalinks below use that
sha unless the path says otherwise.

Read in full: `README.md`, `CLAUDE.md`, `config.nix`, `flake.nix`, the four
files under `modules/flake-parts/`, the `justfile`, the single darwin
configuration and its README, all four home configurations, all four work
modules, `modules/work/pu.nix`, all four darwin modules, `modules/home/agenix.nix`,
`modules/home/default.nix`, `modules/home/darwin-only.nix`,
`modules/home/linux-only.nix`, `modules/home/claude-code/`, the whole `AI/`
directory, `secrets/secrets.nix`, `secrets/justfile`, `overlays/default.nix`,
`packages/ci/default.nix`, `modules/nixos/default.nix`, `modules/nixos/common.nix`,
`modules/nixos/shared/github-runner.nix`, and a sample of `modules/home/cli/`
and `modules/home/gui/`. Skimmed `docs/`.

The autowiring mechanism lives in the `nixos-unified` input, not in this repo,
so it was read from a second pinned snapshot at the locked rev
`05eb3d59d3b48460ea01c419702d4fc0c3210805` (from `flake.lock`). Those citations
name `srid/nixos-unified` explicitly.

Repo metadata and activity came from the GitHub API on 2026-09-04.

Compared against [nix-target-state-research.md](../nix-target-state-research.md)
(read in full), [nix-migration-research.md](../nix-migration-research.md)
("Options" and "Sizing"), and
[chezmoi-architecture.md](../../references/chezmoi-architecture.md).

## 1. What It Is

Sridhar Ratnakumar's personal Nix configuration for every machine he owns. He is
also the author of `nixos-unified`, the flake-parts library this repo is built
on, and the README points readers at it as the template to copy
([README.md#L1-L3](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/README.md#L1-L3)).
That matters for how to read the repo. It is partly a personal config and partly
the reference implementation of his own framework.

| Fact | Value |
| --- | --- |
| Stars / forks | 586 / 27, created 2021-04-06 |
| Last push | 2026-09-03 |
| `.nix` files | 113 |
| Configurations | 8 total: 1 darwin, 3 nixos, 4 standalone home-manager |
| Flake inputs | 24 direct, 97 nodes in `flake.lock` |
| Secrets | 13 committed `.age` files |
| License | AGPL badge in the README, no `LICENSE` file detected by the API |

Activity is heavy and sustained. The last 200 commits span 2026-03 to 2026-09,
with 43 in April, 33 in May, 26 in June, 38 in July, and 54 in August. Commit
messages are short and profane ("fu anth", "fucking clanker"), so history is
weak as documentation.

Configurations by platform:

| Output | Names |
| --- | --- |
| `darwinConfigurations` | `infinitude-macos` |
| `nixosConfigurations` | `myolai`, `naiveintent`, `pureintent` |
| `homeConfigurations` | `srid@sincereintent`, `srid@thismoment`, `srid@zest`, `toor@kolu-bot` |

The one nix-darwin host is not a daily-driver Mac. It is a Tart VM used as an
on-demand macOS CI runner, started by hand and shut down after use
([configurations/darwin/infinitude-macos/README.md#L1-L23](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/configurations/darwin/infinitude-macos/README.md#L1-L23),
[default.nix#L1-L26](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/configurations/darwin/infinitude-macos/default.nix#L1-L26)).
His actual Macs, `zest` and `sincereintent`, are standalone home-manager. This is
the single most important structural fact in the survey and section 5 returns to
it.

The lock is bumped two ways. `nix flake update` updates everything, and
`nix run .#update` updates only the primary inputs
([README.md#L62-L66](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/README.md#L62-L66),
[justfile#L40-L43](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/justfile#L40-L43)).
The primary set is declared as `nixpkgs`, `home-manager`, `nix-darwin`, and
`nix-index-database`, with `nixos-hardware` commented out
([modules/flake-parts/nixos-flake.nix#L10-L20](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/flake-parts/nixos-flake.nix#L10-L20)).
`nixos-unified` generates that `update` package by writing
`nix flake update <primary inputs>` into a shell application
([srid/nixos-unified packages.nix#L24-L35](https://github.com/srid/nixos-unified/blob/05eb3d59d3b48460ea01c419702d4fc0c3210805/nix/modules/flake-parts/packages.nix#L24-L35)).
Every `just activate` also runs a bare `nix flake lock` first
([justfile#L21](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/justfile#L21)),
so new inputs get locked without bumping existing ones. There is one bespoke
lane: `just kolu` rewrites the `kolu.url` branch in `flake.nix` with an inline
Python script, then updates three service inputs in an isolated
`XDG_CACHE_HOME` and redeploys two hosts
([justfile#L50-L96](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/justfile#L50-L96)).

## 2. Composition

### Autowiring

`flake.nix` imports every file in `modules/flake-parts/` by reading the
directory, and nothing else
([flake.nix#L69-L86](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/flake.nix#L69-L86)).
One of those files pulls in the two nixos-unified flake modules
([modules/flake-parts/nixos-flake.nix#L1-L8](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/flake-parts/nixos-flake.nix#L1-L8)).
The `autoWire` module does the directory-to-output mapping
([srid/nixos-unified autowire.nix#L14-L63](https://github.com/srid/nixos-unified/blob/05eb3d59d3b48460ea01c419702d4fc0c3210805/nix/modules/flake-parts/autowire.nix#L14-L63)):

| Directory | Flake output | Wrapper applied |
| --- | --- | --- |
| `configurations/darwin/` | `darwinConfigurations.<name>` | `mkMacosSystem { home-manager = true; }` |
| `configurations/nixos/` | `nixosConfigurations.<name>` | `mkLinuxSystem { home-manager = true; }` |
| `configurations/home/` | `legacyPackages.homeConfigurations.<name>` | `mkHomeConfiguration pkgs` |
| `modules/{darwin,nixos,home}/` | `{darwin,nixos,home}Modules.<name>` | identity |
| `overlays/` | `overlays.<name>` | `import` with common `specialArgs` |

Two properties of `forAllNixFiles` are worth naming, because they bound how much
the autowiring actually does. It only picks up top-level regular `.nix` files and
top-level directories that contain a `default.nix`
([autowire.nix#L14-L30](https://github.com/srid/nixos-unified/blob/05eb3d59d3b48460ea01c419702d4fc0c3210805/nix/modules/flake-parts/autowire.nix#L14-L30)).
So of the 45 `.nix` files under `modules/home/`, exactly five become flake
outputs: `agenix`, `claude-code`, `darwin-only`, `default`, and `linux-only`.
Everything under `cli/`, `gui/`, `editors/`, `services/`, `nix/`, and `work/` is
reached by explicit path import. Autowiring names outputs. It does not compose
them.

The three wrappers are thin. `mkMacosSystem` calls `nix-darwin.lib.darwinSystem`
with the host module plus a shared `nixos-unified` options module and a two-line
`nix.settings` common module, and only adds home-manager if asked
([srid/nixos-unified lib.nix#L75-L101](https://github.com/srid/nixos-unified/blob/05eb3d59d3b48460ea01c419702d4fc0c3210805/nix/modules/flake-parts/lib.nix#L75-L101)).
Every module gets a `flake` special arg carrying `self`, `inputs`, and the
flake-level `config`
([lib.nix#L3-L11](https://github.com/srid/nixos-unified/blob/05eb3d59d3b48460ea01c419702d4fc0c3210805/nix/modules/flake-parts/lib.nix#L3-L11)),
which is how `modules/home/cli/git.nix` reads `flake.config.me.fullname`
([modules/home/cli/git.nix#L13-L16](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/cli/git.nix#L13-L16)).

### Where machine identity lives

Almost nowhere. There is no machine-type value, no feature flags, and no data
layer. The only typed option namespace in the repo is `me`, a four-field
submodule for username, fullname, email, and SSH key
([modules/flake-parts/config.nix#L4-L34](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/flake-parts/config.nix#L4-L34)),
set once in a ten-line `config.nix` at the repo root
([config.nix#L1-L10](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/config.nix#L1-L10)).
nixos-unified adds two more per-configuration options, `sshTarget` and
`overrideInputs`
([srid/nixos-unified configurations/default.nix#L10-L56](https://github.com/srid/nixos-unified/blob/05eb3d59d3b48460ea01c419702d4fc0c3210805/nix/modules/configurations/default.nix#L10-L56)).

Identity is the filename. The host file is the composition unit, and what a
machine is equals the list of modules it imports.

There are exactly two presets, and they are OS layers rather than roles:
`homeModules.default` bundles nine common modules
([modules/home/default.nix#L13-L26](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/default.nix#L13-L26)),
and `darwin-only` / `linux-only` add the shells and a macOS file-descriptor
workaround
([modules/home/darwin-only.nix#L1-L19](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/darwin-only.nix#L1-L19),
[modules/home/linux-only.nix#L1-L8](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/linux-only.nix#L1-L8)).
Hosts either take the preset and add to it
([srid@sincereintent.nix#L7-L13](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/configurations/home/srid@sincereintent.nix#L7-L13),
[srid@zest.nix#L8-L25](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/configurations/home/srid@zest.nix#L8-L25))
or skip it and hand-pick, which `srid@thismoment` does with a comment saying so
because that machine runs Omarchy
([srid@thismoment.nix#L1-L26](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/configurations/home/srid@thismoment.nix#L1-L26)).

### Work versus personal

`modules/home/work/` holds four modules: a Juspay jump host with a SOCKS5 proxy
([juspay.nix#L9-L44](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/work/juspay.nix#L9-L44)),
an OpenCode configuration that imports the employer's own home-manager module
([opencode.nix#L12-L29](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/work/opencode.nix#L12-L29)),
a `pi` wrapper that injects a default model unless the user passed `--model`
([pi.nix#L5-L25](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/work/pi.nix#L5-L25)),
and a `juspay-run` proxychains wrapper
([juspay-run.nix#L28-L57](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/work/juspay-run.nix#L28-L57)).

A host opts in by importing a path. `srid@zest` imports `work/juspay.nix` and
`work/opencode.nix` alongside personal modules like `services/obsidian.nix` and
`services/drishti`
([srid@zest.nix#L8-L25](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/configurations/home/srid@zest.nix#L8-L25)).
So work is not a machine type. It is a feature set, and one Mac is both work and
personal at once.

The top-level `modules/work/` directory is a single file and is not a module. It
is a plain attribute set of shared constants, `import`ed rather than added to
`imports`, because one IP address and one env-var block have to cross the
home-manager and NixOS boundary
([modules/work/pu.nix#L1-L18](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/work/pu.nix#L1-L18)).
It is also not autowired, since `modules/work` is not one of the four directories
`autoWire` reads.

### Standalone home-manager versus nix-darwin

Both shapes exist here, and the split is clean.

`modules/darwin/default.nix` is the nix-darwin-plus-home-manager shape. It sets
`users.users.<me>.home`, seeds `home-manager.sharedModules` with the same
`homeModules.default` and `darwin-only`, and adds agenix
([modules/darwin/default.nix#L8-L24](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/darwin/default.nix#L8-L24)).
No host imports it. Grepping the tree for `modules/darwin` or
`self.darwinModules` finds no consumer at this sha, and the one darwin host
imports only agenix and a NixOS-path GitHub runner module
([infinitude-macos/default.nix#L11-L14](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/configurations/darwin/infinitude-macos/default.nix#L11-L14)).
So the nix-darwin composition is written and currently unused. Whether that is
deliberate or drift is unverified.

The standalone shape is what the Macs run. `mkHomeConfiguration` calls
`home-manager.lib.homeManagerConfiguration` with just the host module and a
common module that sets `home.homeDirectory` and adds three macOS `PATH` entries
including `/nix/var/nix/profiles/system/sw/bin`
([lib.nix#L40-L52](https://github.com/srid/nixos-unified/blob/05eb3d59d3b48460ea01c419702d4fc0c3210805/nix/modules/flake-parts/lib.nix#L40-L52),
[#L94-L101](https://github.com/srid/nixos-unified/blob/05eb3d59d3b48460ea01c419702d4fc0c3210805/nix/modules/flake-parts/lib.nix#L94-L101)).

The two paths diverge on privilege at activation time, which is the point that
maps onto our prior doc's options 3 and 4. The `activate` script picks by whether
the ref contains an `@`
([srid/nixos-unified activate.nu#L40-L52](https://github.com/srid/nixos-unified/blob/05eb3d59d3b48460ea01c419702d4fc0c3210805/activate/activate.nu#L40-L52)).
A home ref runs `home-manager switch` with no privilege escalation
([activate.nu#L63-L69](https://github.com/srid/nixos-unified/blob/05eb3d59d3b48460ea01c419702d4fc0c3210805/activate/activate.nu#L63-L69)).
A darwin host ref runs `sudo darwin-rebuild switch`
([activate.nu#L88-L100](https://github.com/srid/nixos-unified/blob/05eb3d59d3b48460ea01c419702d4fc0c3210805/activate/activate.nu#L88-L100)).
Remote deploys `nix copy` the cleaned flake to `sshTarget` and re-run the same
script over SSH
([activate.nu#L102-L114](https://github.com/srid/nixos-unified/blob/05eb3d59d3b48460ea01c419702d4fc0c3210805/activate/activate.nu#L102-L114)).

The user-facing entry points are `nix run .` for a fresh machine
([README.md#L31-L38](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/README.md#L31-L38))
and `just activate [host]`, which prefers a home configuration named
`$USER@$HOSTNAME` when that file exists and falls back to the system
configuration otherwise
([justfile#L11-L38](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/justfile#L11-L38)).

## 3. Per-App Config Mechanics

### The distribution

`programs.*` dominates. Counting distinct option prefixes across the tree, the
common cases are `programs.zsh`, `programs.ssh`, `programs.bash`,
`programs.git`, `programs.opencode`, `programs.ghostty`, `programs.direnv`,
`programs.starship`, `programs.atuin`, and so on. `home.file` appears twice.
`xdg.configFile` appears twice. `home.activation` appears once in the whole
repo.

| Mechanism | Count at this sha | Instances |
| --- | ---: | --- |
| `home.file` | 2 | `.claude/settings.json`, `.ssh/rc` |
| `xdg.configFile` | 2 | `odu/hosts.json`, `direnv/lib/zz-macos-fix.sh` |
| `home.activation` | 1 | `systemdUserPath` on `toor@kolu-bot` |
| `force = true` | 2 | `.claude/settings.json`, `odu/hosts.json` |
| `mkOutOfStoreSymlink` | 0 | none |

The single activation block is an idempotent `systemctl --user set-environment`,
ordered with `lib.hm.dag.entryBefore [ "reloadSystemd" ]`
([toor@kolu-bot.nix#L89-L92](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/configurations/home/toor@kolu-bot.nix#L89-L92)).
That is the whole of imperative activation in 113 files.

Where an upstream module exists, he uses it and reads its option surface hard.
`programs.opencode` is enabled with `package = null` purely so home-manager owns
`tui.json` while the employer's module keeps ownership of `opencode.json`, and
the notification sounds are freedesktop `.oga` files transcoded to WAV in a
`runCommand` derivation because the TUI's decoder does not read Vorbis
([opencode.nix#L31-L69](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/work/opencode.nix#L31-L69)).
That is the pattern to notice: split ownership by file, not by key.

### Claude Code

This is the row we care most about, and the answer is blunt.
`~/.claude/settings.json` is generated whole from `builtins.toJSON` with
`force = true`
([modules/home/claude-code/default.nix#L8-L38](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/claude-code/default.nix#L8-L38)):

```nix
home.file.".claude/settings.json" = {
  force = true;
  text = builtins.toJSON { ... };
};
```

No merge. No managed drop-in under `/Library/Application Support/ClaudeCode`.
No `managed-settings.d`. The path is a store symlink and anything Claude Code
itself wrote to that file is deleted on the next switch, because `force` makes
home-manager remove the target rather than refuse.

The generated content is a settings file, not a plugin or skill system:
`skipDangerousModePermissionPrompt`, blanked commit and PR attribution, an `env`
block, and a `permissions.deny` list. That deny list is the most transferable
finding in the repo. Five entries exist only to stop the agent from crawling
`/nix`, because the store is huge and `rg`, `find`, `fd`, and `bfs` over it wedge
sessions
([default.nix#L28-L36](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/claude-code/default.nix#L28-L36)).

Two adjacent pieces. `modules/home/claude-code/juspay.nix` points the CLI at the
employer's gateway with session variables and exports `ANTHROPIC_API_KEY` by
`cat`-ing an agenix-decrypted path from shell init
([juspay.nix#L10-L23](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/claude-code/juspay.nix#L10-L23));
it is currently commented out of the work module
([work/juspay.nix#L14](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/work/juspay.nix#L14)).
And `modules/flake-parts/claude-sandboxed.nix` defines a `landrun`-sandboxed
Claude app, whose read-write list is a clean inventory of the CLI's mutable
state: `$HOME/.claude`, `$HOME/.claude.json`, `$HOME/.cache/claude-cli-nodejs`
([claude-sandboxed.nix#L9-L40](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/flake-parts/claude-sandboxed.nix#L9-L40)).

### The AI/ directory

This is the part of the repo that looked closest to our concerns from the
outside, and it is not wired up. `AI/` contains four slash-command Markdown files
([AI/commands/elegance.md#L1-L12](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/AI/commands/elegance.md#L1-L12)),
a system-instructions file
([AI/memory.md#L1-L14](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/AI/memory.md#L1-L14)),
two MCP server definitions as bare Nix attribute sets
([AI/mcp/chrome-devtools.nix#L1-L4](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/AI/mcp/chrome-devtools.nix#L1-L4),
[AI/mcp/nixos-mcp.nix#L1-L4](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/AI/mcp/nixos-mcp.nix#L1-L4)),
and a three-key settings fragment
([AI/settings/claude-code.nix#L1-L6](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/AI/settings/claude-code.nix#L1-L6)).

At this sha, no file in the repository references `AI/`, and no flake input named
`nix-agent-wire` exists. Git history shows the directory was wired through
`nix-agent-wire` in March 2026 (PR #107, "Migrate AI config to nixos-config, use
nix-agent-wire") and that `AI/skills/` was deleted in April 2026 in a commit
titled "Upstreamed" (`ce989a6c`). The settings fragment's
`includeCoAuthoredBy = false` does not appear in the settings JSON the live
module generates, which is consistent with the fragment being dead. Whether
something outside this repo still consumes `AI/` is unverified.

So: MCP configuration is not managed by Nix here today. The one repo that tried
it stopped.

### macOS defaults, Homebrew, launchd, root

| Concern | State at this sha |
| --- | --- |
| macOS defaults | None. No `system.defaults`, no `CustomUserPreferences`, no `targets.darwin.defaults` anywhere in the tree. |
| Homebrew | None. No `homebrew`, `nix-homebrew`, `casks`, or `masApps` anywhere in the tree. Confirmed by grep across all 113 `.nix` files. |
| Casks and MAS | Not managed. GUI apps appear only as `home.sessionPath` additions to app bundles installed by hand, for example Obsidian ([services/obsidian.nix#L8-L10](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/services/obsidian.nix#L8-L10)). |
| launchd | Three touchpoints: home-manager `launchd.agents.activate-agenix` ([agenix.nix#L20-L29](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/agenix.nix#L20-L29)), nix-darwin `launchd.user.envVariables` ([thunderbird.nix#L1-L7](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/darwin/all/thunderbird.nix#L1-L7)), and a `launchctl kickstart` hint printed by a wrapper ([juspay-run.nix#L44-L48](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/work/juspay-run.nix#L44-L48)). |
| Root per switch | Only for `nixosConfigurations` and `darwinConfigurations`. Zero for the four home configurations. |

A blunt way to put it: this is a Nix-on-macOS config with the macOS removed.

### Secrets

agenix, chosen in the README because it works with SSH keys on both macOS and
NixOS
([README.md#L74](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/README.md#L74)).
Thirteen `.age` files are committed to the public repo. Recipients are declared
per file in a 29-line Nix expression, keyed by user SSH keys plus per-host keys
([secrets/secrets.nix#L1-L29](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/secrets/secrets.nix#L1-L29)).

Three details are directly relevant to our Problem C.

First, the identity is a dedicated key at `~/.ssh/agenix`, provisioned once by
hand, chosen explicitly so the main private key (which lives in 1Password) never
touches the filesystem
([modules/home/agenix.nix#L13-L18](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/agenix.nix#L13-L18)).

Second, the 1Password route was tried and abandoned. `secrets/justfile` has both
`agenix -e` lines with an `op read ... | process substitution` variant commented
out above the working `-i ~/.ssh/agenix` form
([secrets/justfile#L5-L12](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/secrets/justfile#L5-L12)).

Third, agenix on Darwin needs a workaround. The launchd agent restarts every ten
seconds because `KeepAlive.Crashed = false` means "restart on successful exit",
so the module force-overrides `KeepAlive` to `{ SuccessfulExit = false; }`
([agenix.nix#L20-L29](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/agenix.nix#L20-L29)).

Consumption is by path, never by evaluation. Shell init `cat`s the decrypted file
([opencode.nix#L83-L88](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/work/opencode.nix#L83-L88)),
and systemd `EnvironmentFile` reads a second file written by an `ExecStartPost`
hook under `umask 077`
([toor@kolu-bot.nix#L60-L76](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/configurations/home/toor@kolu-bot.nix#L60-L76)).
No `builtins.readFile` on a secret appears anywhere, which is consistent with the
store-leak rule our doc states.

## 4. Testing And CI

There is no test surface, and this is verified rather than inferred.

- No `checks.*` attribute anywhere in the tree.
- No `.github/` directory in the tarball; `gh api repos/srid/nixos-config/contents/.github` returns 404.
- `gh api repos/srid/nixos-config/actions/workflows` returns `total_count: 0`. The most recent recorded workflow runs are from 2025-10, all named "CI".
- Yet `services.github-nix-ci.personalRunners` still allocates one self-hosted runner for `srid/nixos-config`, alongside runners for eleven other repos ([github-runner.nix#L29-L42](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/nixos/shared/github-runner.nix#L29-L42)). That is stale config for a workflow that no longer exists.

The stated validation story is `nix run nixpkgs#omnix ci` to build all flake
outputs, locally or in CI
([README.md#L73](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/README.md#L73)),
backed by a `ci` package that attaches a zellij layout so the build fans out over
SSH to his own beefy machines
([packages/ci/default.nix#L1-L15](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/packages/ci/default.nix#L1-L15)).
Whether `om ci` in fact covers `darwinConfigurations` and `homeConfigurations`,
which plain `nix flake check` does not, was not verified here.

The agent-facing contract is three lines: test with `nix build` on the relevant
configuration, deploy with `just activate`, and do not commit
([CLAUDE.md#L1-L6](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/CLAUDE.md#L1-L6)).

One unexpected find under `docs/` is a measurement discipline we do not have. An
agent-run optimization report reduces Nix evaluation work using
`NIX_SHOW_STATS=1` counters (`nrThunks`, `nrFunctionCalls`, `nrPrimOpCalls`)
rather than wall time, on the stated ground that a thermally-throttling laptop
made `cpuTime` climb 11s to 21s across byte-identical evaluations. Two config
changes carried most of the win: `documentation.nixos.enable = false` and
`manual.manpages.enable = false`, the latter cutting the home-manager
configuration's thunk count by 33 percent
([docs/eval-time-ralph-report.md#L9-L60](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/docs/eval-time-ralph-report.md#L9-L60)).
The `manual.manpages.enable = false` line is live in the shared home module with
the reasoning attached
([modules/home/default.nix#L9-L12](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/default.nix#L9-L12)).

## 5. Compare And Contrast With Our Target-State Doc

### Composition model

Our doc's Nix-native target says the unit is the app module, roles import app
modules, hosts import roles, and nothing reads a `machine_type` at evaluation
time. This repo is evidence for the second half and silent on the first.

Supported: there is no resolver, no layered data merge, no feature template, and
no machine type. Host files import modules directly, and one Mac is both work and
personal
([srid@zest.nix#L8-L25](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/configurations/home/srid@zest.nix#L8-L25)).
Our doc's claim that `work`, `personal`, and `homelab` survive as vocabulary
rather than as an evaluated value is exactly what this repo does.

Not supported: there is no role layer. There are two OS presets and per-host
import lists, and one host opts out of the preset entirely
([srid@thismoment.nix#L1-L26](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/configurations/home/srid@thismoment.nix#L1-L26)).
At 8 configurations that is fine. At our 4 machine types plus a DevPod profile it
may also be fine, which is worth stating: the roles directory in our doc's tree
is a hypothesis, not a requirement.

Also worth correcting in our doc: autowiring is shallower than "autowiring by
directory" suggests. Only top-level files and directories with a `default.nix`
become outputs
([autowire.nix#L14-L30](https://github.com/srid/nixos-unified/blob/05eb3d59d3b48460ea01c419702d4fc0c3210805/nix/modules/flake-parts/autowire.nix#L14-L30)).
Our doc's proposed `modules/apps/`, `modules/roles/`, and `modules/services/`
trees would produce zero autowired outputs under this scheme. If we ever adopt
nixos-unified, that is a real constraint on the tree shape, not a detail.

One structure our doc's tree has no slot for: a plain non-module constants file
imported by both a home-manager module and a NixOS module
([modules/work/pu.nix#L1-L18](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/work/pu.nix#L1-L18)).
We would need the same thing wherever a value has to cross the darwin and
home-manager boundary.

Change recommended: add a note to "Composition model" that the role layer is
optional at small host counts, and add the autowiring depth limit as a named
constraint if nixos-unified is on the table.

### The "what disappears" table

Every construct our doc lists as disappearing is in fact absent here: no
resolver, no cask gates, no group union, no `run_onchange_` hashes, no retired
ledger, no Brewfile renderer, no drift banner, no plist stubs, no quit guard, no
first-run prompts. That is consistent, but it is weak evidence, because this repo
never had those problems. It has no Homebrew, no plists, and no macOS defaults at
all.

The honest reading is that the table describes what a Nix repo does not need,
not that our particular surface converts. Our repo's 22 merges, 20 cask gates,
and 143 `defaults write` lines have no counterpart here to learn from.

One row does get real evidence, and it goes the other way. Our table says the
plist quit guard "narrows" and the merge machinery mostly disappears. This repo
shows the actual working practice for co-owned files is overwrite plus backup,
not merge, and that the backups become their own problem (next section).

Change recommended: annotate the table to say which rows are supported by
observed practice and which are only supported by absence. Right now the table
reads as if all rows are equally settled.

### The per-app ownership table, and the Claude row

This is the strongest evidence in the survey, and it adds an option our table
does not list.

Our table gives Claude Code two paths: move hooks, permissions, and marketplace
registration into a root-owned managed drop-in, and leave `enabledPlugins` in the
user file because
[ADR 0007](../../adr/0007-default-loaded-plugin-policy.md) depends on per-project
override. srid takes a third path: own `~/.claude/settings.json` outright, whole
file, `force = true`
([claude-code/default.nix#L8-L38](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/claude-code/default.nix#L8-L38)).

That is viable for him and disqualified for us, for reasons we can name
precisely:

| Requirement of ours | Why `force = true` breaks it |
| --- | --- |
| Hook union across injectors | Orca and Superset write hooks into the user settings file; our merger unions them by matcher ([modify_private_settings.json.tmpl](../../../home/dot_claude/modify_private_settings.json.tmpl)). `force` deletes them every switch. |
| ADR 0007 plugin enablement | `enabledPlugins` lives in the user file and must stay overridable per project. |
| CLI-written install records | [ADR 0020](../../adr/0020-apply-reconciles-plugin-installs.md) has apply reconcile against records Claude writes. A whole-file rewrite discards them. |

He avoids the collision rather than solving it. His `.gitignore` excludes
`/.claude/settings.local.json`, the project-scoped mutable file
([.gitignore#L1-L6](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/.gitignore#L1-L6)),
so mutable state lives at project scope while the global file is Nix's. That is a
real design, and it works because nothing else writes to his global settings.

The MCP finding cuts against our optimism. Our doc treats agent CLI config as a
tractable per-app problem. Here, MCP server definitions exist as Nix data but are
not consumed by anything at this sha, and the input that used to consume them is
gone. That is one data point, not a trend, but it is the only public data point we
have found so far and it is negative.

Change recommended: add a fourth column or a note to the per-app table naming
"whole-file ownership with `force`" as an option, with the two conditions that
make it safe (no third-party writer, mutable state relocated to a narrower
scope), and record that neither holds for our Claude row. Cite this repo.

### Problem A: files the app also writes

Our doc's three-tier design is: use the app's own layer, then `defaults`, then
keep the mergers as activation blocks. This repo runs none of the three. It has
zero merge activation blocks in 113 files. Its answer to the same problem is:

1. Prefer an upstream module that generates the file, and split ownership by
   file rather than by key when two owners exist
   ([opencode.nix#L31-L42](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/work/opencode.nix#L31-L42)).
2. When Nix must own an app-written file, set `force = true` and accept the loss
   ([odu.nix#L1-L22](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/cli/odu.nix#L1-L22)).
3. Keep backups on collision. NixOS-embedded home-manager sets
   `home-manager.backupFileExtension = "hm-backup"`
   ([modules/nixos/default.nix#L12-L14](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/nixos/default.nix#L12-L14)),
   and every standalone switch passes a timestamped `-b nixos-unified.%Y-%m-%d-%H:%M:%S.bak`
   ([activate.nu#L63-L69](https://github.com/srid/nixos-unified/blob/05eb3d59d3b48460ea01c419702d4fc0c3210805/activate/activate.nu#L63-L69)).

The comment on the `odu` module is the tell. `force` is there "so activation never
fails on collision across NixOS / darwin / standalone HM", and it explicitly names
having to clean up a "stale `.hm-backup`". A unique backup extension per switch
means collisions leave an unbounded, uncleaned pile of dated files next to the
managed path. Our doc mentions `-b` and `backupFileExtension` in row 40 but does
not cost the pile.

This confirms our doc's core claim (home-manager has no merge primitive, and the
options are refuse, backup, or force-delete) and undercuts our tier-3 plan.
Nobody in this repo, at 586 stars, writes merge activation blocks. If we build
six of them, we are building something the ecosystem has no pattern for, and we
should say so in the doc rather than presenting tier 3 as routine.

Change recommended: in Problem A, add a line that the observed public practice is
avoid-or-overwrite, that no merge-in-activation pattern was found in the surveyed
repo, and that a per-switch unique backup extension accumulates files.

### Problem B: the MDM-managed work Mac

This is the closest thing to an existence proof we have found for our
recommendation.

Our doc's table ranks standalone home-manager above nix-darwin for the work Mac,
on the argument that it is the difference between one root operation ever and one
per switch. This repo runs exactly that shape, by choice and not under MDM
pressure: both daily-driver Macs are standalone home-manager, activated with no
sudo
([activate.nu#L63-L69](https://github.com/srid/nixos-unified/blob/05eb3d59d3b48460ea01c419702d4fc0c3210805/activate/activate.nu#L63-L69)),
and the entire employer-facing surface (jump host, SOCKS proxy, wrapped CLIs,
API-key secret, ssh config) sits in home-manager modules that need no privilege
([work/juspay.nix#L9-L44](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/work/juspay.nix#L9-L44),
[work/juspay-run.nix#L28-L57](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/work/juspay-run.nix#L28-L57)).
The one nix-darwin machine is a VM he fully controls, and its `activate` path is
`sudo darwin-rebuild switch`
([activate.nu#L88-L100](https://github.com/srid/nixos-unified/blob/05eb3d59d3b48460ea01c419702d4fc0c3210805/activate/activate.nu#L88-L100)).

What the proof does not cover: he gives up `system.defaults`, LaunchDaemons, and
the Homebrew module, and he does not appear to want them. Our work Mac wants
casks at minimum. And there is no MDM anywhere in this repo, so nothing here
speaks to the Determinate installer's media-restriction pre-flight or to Jamf
temp-admin. Problem B's hard part is untouched.

One small negative signal: the nix-darwin composition he does have
(`modules/darwin/default.nix`) is imported by no host at this sha. A Mac config
that nobody activates is not evidence that the shape works.

Change recommended: cite this repo in Problem B as an existence proof for the
standalone-HM row, and note explicitly that it is an existence proof for the
privilege model only, not for the macOS-native surface we would be giving up.

### Problem C: secrets without store leakage

Our doc's recommended target is `op read` in an activation block for interactive
Macs, with opnix only for headless hosts, on the grounds that both keep `op://`
refs as the committed form and keep values out of the store.

This repo picks the row our doc ranks third, agenix, and the details sharpen two
of our stated costs.

| Our doc's claim about agenix | What this repo shows |
| --- | --- |
| "Encrypted license blobs would live in a public repo, a policy shift" | Confirmed and accepted. 13 `.age` files are committed to a 586-star public repo ([secrets/secrets.nix#L17-L28](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/secrets/secrets.nix#L17-L28)). |
| "Adds an unencrypted age key on every machine" | Confirmed, and mitigated deliberately: a dedicated `~/.ssh/agenix` key, so the 1Password-held main key stays off disk ([agenix.nix#L13-L18](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/agenix.nix#L13-L18)). |
| Not in our doc | Darwin needs a `KeepAlive` force-override or the decrypt agent restarts every 10 seconds ([agenix.nix#L20-L29](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/agenix.nix#L20-L29)). |
| Not in our doc | The `op read` identity path was tried and left commented out ([secrets/justfile#L5-L12](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/secrets/justfile#L5-L12)). |

No evidence either way on our recommended `op read`-in-activation row, and no
evidence on 1Password service accounts (our open question 5). The consumption
pattern is worth copying regardless: never evaluate a secret, always read the
decrypted path at runtime from shell init or an `EnvironmentFile`.

Change recommended: add the Darwin agenix launchd restart-loop cost to the
agenix row, and note that the one public repo surveyed treats a dedicated
on-disk age identity as the way to keep the 1Password key off the filesystem.

### Work versus personal, against our machine types

| Ours today | Theirs |
| --- | --- |
| `machine_type` resolved from layered TOML, four values | No type. Import a module or do not. |
| Work overlay in a private repo (ADR 0011) | Work modules in the public repo, only the API key encrypted |
| Machine is one type | `srid@zest` is work and personal simultaneously |
| Composite `work x linux` DevPod profile | `toor@kolu-bot`: headless Linux, standalone HM, services and secrets, no desktop |

Our doc's claim that roles are presets and vocabulary is supported. Our
[ADR 0011](../../adr/0011-private-repo-config-overlays.md) risk posture is not
something this repo shares, and we should not read its public work modules as
endorsement.

`toor@kolu-bot` is a useful reference for our DevPod row (42-row concept map, row
41). It is standalone home-manager on Linux with systemd user services, agenix
secrets, a manually-corrected `systemd --user` PATH because the manager was not
started from a NixOS login, and a `set-environment` activation hook to update the
already-running manager
([toor@kolu-bot.nix#L78-L92](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/configurations/home/toor@kolu-bot.nix#L78-L92)).
That PATH problem is one our DevPod profile will hit.

### The test surface

Our doc's "What The Test Surface Becomes" imagines per-host closure checks,
module tests replacing golden tests, and activation dry runs. This repo has none
of it, and the gap is informative rather than damning.

- Our doc's warning that `nix flake check` skips `darwinConfigurations` and `homeConfigurations` is real, and this repo's answer is to not use `nix flake check`. It uses `om ci` over all flake outputs instead ([README.md#L73](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/README.md#L73)). Whether `om ci` genuinely covers those outputs is unverified here and is worth checking before we write our own explicit `checks` plumbing.
- Dry run exists and is asymmetric: `--dry-run` becomes `darwin-rebuild build` on macOS and `nixos-rebuild dry-activate` on Linux ([activate.nu#L88-L100](https://github.com/srid/nixos-unified/blob/05eb3d59d3b48460ea01c419702d4fc0c3210805/activate/activate.nu#L88-L100)). Standalone home-manager has no dry-run path in that script at all. Our doc assumes `home-manager switch -n` is available; it is, but the tooling around it here does not expose it.
- Our doc says nothing about evaluation cost. This repo measures it, and the two winning changes are one line each ([docs/eval-time-ralph-report.md#L9-L60](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/docs/eval-time-ralph-report.md#L9-L60)). Our surface is larger than his, so eval time would likely be worse. That belongs in our doc as a named cost of the migration and a named check (`NIX_SHOW_STATS=1` thunk counts as a regression metric).

Change recommended: add an eval-cost bullet to "What The Test Surface Becomes",
and add `om ci` to the list of candidate check runners with its coverage marked
unverified.

### Open questions this repo touches

| Q | Effect | Detail |
| ---: | --- | --- |
| 1 | No evidence | No plugin marketplace, no skill payload, no `lndir`. |
| 2 | No evidence | No `defaults` usage at all. |
| 3 | No evidence | No MDM anywhere. |
| 5 | Weak, negative | Service accounts not used; a dedicated on-disk age key is the answer here ([agenix.nix#L13-L18](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/agenix.nix#L13-L18)). |
| 7 | Reframed | Answered by deleting Homebrew from the configuration entirely. Not available to us. |
| 9 | Reframed | A third answer exists: own the whole user settings file with `force`. Safe only when nothing else writes it ([claude-code/default.nix#L8-L38](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/claude-code/default.nix#L8-L38)). |
| 13 | No evidence | No Cursor CLI config here. |
| 14 | Reframed | The lever used is not "disable app persistence" but "move mutable state to a narrower scope", via a gitignored project-level `settings.local.json` ([.gitignore#L1-L6](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/.gitignore#L1-L6)). |

Two questions this repo raises that our doc does not ask:

- What does Nix evaluation cost at our size, and what is the regression metric?
- If co-owned files are handled with `-b`, who cleans up the backups?

## 6. What To Take, What To Avoid, And Relevance

### Take

| Take | Why | Source |
| --- | --- | --- |
| A `permissions.deny` list for `/nix` in Claude settings | If we ever put the store on a machine running coding agents, `rg`/`fd`/`find` over `/nix` wedges sessions. Cheap, and true today even without a migration. | [claude-code/default.nix#L28-L36](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/claude-code/default.nix#L28-L36) |
| Eval-cost as a tracked metric | `NIX_SHOW_STATS=1` thunk counts are deterministic; wall time on a throttling laptop is not. Two one-line options bought 33 percent on his HM config. | [docs/eval-time-ralph-report.md#L9-L60](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/docs/eval-time-ralph-report.md#L9-L60) |
| Split file ownership, not key ownership | When two owners exist, give each a whole file rather than merging one. This is the only clean pattern in the repo. | [opencode.nix#L31-L42](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/work/opencode.nix#L31-L42) |
| Work as an importable module, not a machine type | Removes the "which type am I" question and lets one Mac be both. | [srid@zest.nix#L8-L25](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/configurations/home/srid@zest.nix#L8-L25) |
| The `flake.config.me` pattern | A tiny typed submodule for identity beats a data file, and is the whole data layer he needs. | [modules/flake-parts/config.nix#L4-L34](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/flake-parts/config.nix#L4-L34) |
| Runtime secret reads, never evaluation reads | `cat` the decrypted path from shell init, or point `EnvironmentFile` at it. | [opencode.nix#L83-L88](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/work/opencode.nix#L83-L88) |
| A three-line agent contract | "Test with `nix build`, deploy with `just activate`, do not commit" is the whole CLAUDE.md and it is enough. | [CLAUDE.md#L1-L6](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/CLAUDE.md#L1-L6) |

### Avoid

| Avoid | Why |
| --- | --- |
| `force = true` on `~/.claude/settings.json` | Silently deletes hook injections from Orca and Superset, and the ADR 0007 `enabledPlugins` state. Our merger exists for a reason. |
| Timestamped `-b` backups as the collision strategy | Unbounded, uncleaned, and the repo already trips over its own stale `.hm-backup` ([odu.nix#L2-L3](https://github.com/srid/nixos-config/blob/24d2f61e12de72b5f8a3b4bcebff354332cd05a9/modules/home/cli/odu.nix#L2-L3)). |
| Committing encrypted secrets to a public repo | Works for him. Different posture from ours, and ADR 0011 already picked the other one. |
| Zero `checks`, zero CI | Fine at 8 configurations with one owner. Not fine for us: we already have a Tart lane, a Linux profile job, and 60-plus make targets in [tests/README.md](../../../tests/README.md). |
| Reading `AI/` as a model for agent-config-in-Nix | It is unwired at this sha. Do not copy a shape nobody is running. |
| Assuming nixos-unified's autowiring will pick up a deep module tree | It reads one level and needs `default.nix` in subdirectories. |

### Relevance: 3 of 5

Three, not higher, and three, not lower.

It earns the three on three counts. It is a working existence proof that a fully
work-capable Mac configuration can live entirely in standalone home-manager with
no per-switch root, which is the recommendation in our Problem B and the thing we
most wanted external evidence for. It gives us the only public, in-the-wild data
point we have on Claude Code settings in Nix, and that data point is precise
enough to sharpen our per-app table by adding an option and naming why the option
fails for us. And its work-versus-personal split is a direct, working instance of
the composition claim our doc makes.

It does not earn a four because it sidesteps every part of our surface that is
actually hard. No Homebrew, so nothing on casks, taps, MAS, Setapp, or the
retired-package problem. No `system.defaults` and no plists, so nothing on the 12
plist merges or the 143 `defaults write` lines. No MDM, so nothing on Problem B's
actual difficulty. No merge activation anywhere, so our tier-3 design gets a
warning rather than a template. No CI and no `checks`, so nothing on the test
surface. And the `AI/` directory that made it look unusually close is dead code.

It does not drop to two because the evidence it does give is direct, load-bearing,
and changes specific lines in our doc rather than just confirming the vibe.

## 7. Scorecard Against Appendix A

Rows from the 42-row concept map in
[nix-target-state-research.md](../nix-target-state-research.md) for which this
repo is evidence. Rows with no evidence here are omitted.

| Row | Verdict | Note (five words) |
| ---: | --- | --- |
| 1 | Supports | Store symlinks, used very sparingly |
| 2 | Alternative | agenix owns mode-sensitive files |
| 3 | Supports | `executable = true` on `.ssh/rc` |
| 5 | Supports | Interpolation only, no templating anywhere |
| 6 | Supports | Flake attribute names the host |
| 7 | Alternative | Gitignored project file, not override |
| 8 | Alternative | No resolver, per-host import lists |
| 9 | Alternative | Homebrew deleted from config entirely |
| 10 | Supports | nixpkgs plus flake-input packages throughout |
| 11 | Alternative | Generations handle it, no ledger |
| 20 | Supports | One idempotent activation block total |
| 21 | Supports | `hm.dag.entryBefore` used as documented |
| 24 | Contradicts | Whole-file `force`, no merger anywhere |
| 27 | Supports | Home switch no sudo; darwin sudo |
| 28 | Supports | HM `launchd.agents` plus ND envVariables |
| 34 | Alternative | No mise; lock bump replaces latest |
| 35 | Alternative | Generated zsh, no custom ZDOTDIR |
| 37 | Alternative | agenix blobs; `op read` abandoned |
| 38 | Alternative | `build` and `dry-activate`, nothing per-file |
| 40 | Supports | force, backupFileExtension, timestamped `-b` observed |
| 41 | Supports | Headless Linux standalone HM works |
| 42 | Supports | Tart macOS VM as runner |
