---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-04
updated: 2026-09-04
related:
  - ../nix-target-state-research.md
  - ../nix-migration-research.md
status_detail: "Agent survey of MatthiasBenaets/nix-config at 2c5564c7125f0af26312755dce7e5ff0a667a329, compared with the Nix target-state doc. Unreviewed."
---

# Survey: MatthiasBenaets/nix-config

## Method

Read on 2026-09-04. The repo was pulled as a tarball at commit
`2c5564c7125f0af26312755dce7e5ff0a667a329` (HEAD of `master`, committed
2026-08-29) with `gh api repos/MatthiasBenaets/nix-config/tarball/<sha>` and
extracted to a scratch directory. Nothing was evaluated or built; no Nix ran.
Every claim below comes from reading source at that commit or from the GitHub
API for repository metadata.

Files read in full: `README.md`, `flake.nix`, `Makefile`, `.sops.yaml`,
`.gitignore`, `secrets.yaml` (structure only), `modules/hosts/options.nix`,
`modules/hosts/users.nix`, `modules/hosts/home-manager.nix`,
`modules/general/{flake-parts,nix,nixpkgs,sops,state-version}.nix`,
`modules/hosts/darwin/{homebrew,packages}.nix`,
`modules/hosts/darwin/m1/{default,darwin-configuration}.nix`,
`modules/hosts/darwin/work/{default,darwin-configuration}.nix`,
`modules/hosts/nixos/{beelink,work,vm}/default.nix`,
`modules/hosts/nixos/beelink/hardware.nix`,
`modules/hosts/nix/{default.nix,ubuntu/default.nix,ubuntu/home.nix}`,
`modules/programs/{claude,pi,opencode,direnv,pandoc,aerospace,git,omniwm,accounts}.nix`,
`modules/programs/zsh/zsh.nix`, `modules/editors/nixvim/default.nix`,
`modules/theme/stylix.nix`. Files read in part: `modules/programs/kitty.nix`,
`modules/programs/yabai.nix`, `modules/programs/skhd.nix`. Structural greps
covered all 121 `.nix` files for module-namespace usage, platform
conditionals, `mkIf`, `onChange`, `assertions`, `checks`, activation blocks,
and managed file paths.

Citations are permalinks at the pinned sha. Line numbers refer to that
commit.

## 1. What It Is

Matthias Benaets is an individual maintainer. The repo is his personal
machine configuration, public since 2022-02-04, 743 stars and 65 forks, no
license file, not archived. Last push 2026-08-29; the head commit is
`feat: sops-nix setup`. A sample of the most recent 100 commits spans
2025-12 to 2026-08, so the pace is roughly 10 commits a month with bursts
(26 in 2026-02, 22 in 2026-08). There is a second branch, `vanilla`, which
the README describes as a more conventional flake layout for readers
([README.md#L3-L4](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/README.md#L3-L4)).

It spans three platform classes: NixOS, nix-darwin, and standalone
home-manager
([README.md#L10-L16](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/README.md#L10-L16)).
Six host outputs exist in source: `darwinConfigurations.m1` and `.work`,
`nixosConfigurations.beelink`, `.work`, and `.vm`, and
`homeConfigurations.ubuntu`
([m1](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/m1/default.nix#L23),
[darwin work](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/work/default.nix#L23),
[beelink](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/nixos/beelink/default.nix#L34),
[nixos work](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/nixos/work/default.nix#L33),
[vm](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/nixos/vm/default.nix#L21),
[ubuntu](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/nix/ubuntu/default.nix#L17)).
The README's host tables are stale against that: they list an `intel`
x86_64-darwin host and a `pacman` home-manager host
([README.md#L36-L46](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/README.md#L36-L46)),
neither of which exists in `modules/`, and `flake.nix` does not even declare
`x86_64-darwin` as a system
([flake.nix#L42-L46](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/flake.nix#L42-L46)).

The repo has 121 `.nix` files. Roughly a quarter of them are neovim plugin
modules under `modules/editors/nixvim/`.

Lock bumping is manual and undifferentiated. The only mechanism is
`make update`, which is `nix flake update $(CHANNEL)` with an optional single
input
([Makefile#L173-L175](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/Makefile#L173-L175)).
There is no CI, no bot, and no scheduled job. The lock reflects that: most
top-level inputs were last modified in the 2026-08-11 to 2026-08-24 window,
but `nix-flatpak` sits at 2026-01-09 and `import-tree` at 2026-07-16, so
"update all" is not run on a fixed cadence.

Three nixpkgs channels are tracked at once: `nixpkgs` (nixos-unstable),
`nixpkgs-stable` (nixos-26.05), and `nixpkgs-master`, with the latter two
exposed through an overlay as `pkgs.stable` and `pkgs.master`
([flake.nix#L5-L7](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/flake.nix#L5-L7),
[#L64-L76](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/flake.nix#L64-L76)).

## 2. Composition

### The mechanism

`flake.nix` is 89 lines and names no hosts. It calls
`flake-parts.lib.mkFlake` and imports the whole `modules/` tree with
`import-tree`
([flake.nix#L39-L48](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/flake.nix#L39-L48)).
Every module file is a flake-parts module. The README names the approach:
the dendritic pattern, with modules "organized by feature, not by target OS"
([README.md#L18-L20](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/README.md#L18-L20)).

Cross-platform composition is **not** `mkIf` on platform. It is separate
named attributes per platform class in the same file. Each concern file
assigns into `flake.modules.nixos.<name>`, `flake.modules.darwin.<name>`,
and `flake.modules.homeManager.<name>` as needed. Those namespaces come from
`flake-parts.flakeModules.modules`, plus two hand-declared option namespaces
for the outputs flake-parts does not know about
([modules/general/flake-parts.nix#L4-L16](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/general/flake-parts.nix#L4-L16)).

The evidence that platform branching is structural rather than conditional:
across all 121 files there are only four occurrences of `isDarwin` or
`isLinux`. Two are the `host.isDarwin` option declaration and its default
([modules/hosts/options.nix#L105-L121](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/options.nix#L105-L121)),
one picks a home directory prefix
([home-manager.nix#L62-L65](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/home-manager.nix#L62-L65)),
and one is a leaf `mkIf` on a neovim clipboard provider
([nixvim/base.nix#L42](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/editors/nixvim/base.nix#L42)).
There are six `mkIf` uses in the whole repo and none of them branch a module
on platform at top level.

### How hosts select concerns

A host file is a `let host = { ... }` attrset plus two things: a
configuration output that lists module names, and a host-named module that
carries the host attrset and the per-user home-manager imports. The darwin
M1 host is 47 lines total
([modules/hosts/darwin/m1/default.nix#L7-L47](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/m1/default.nix#L7-L47)):

- `flake.darwinConfigurations.m1` lists `base m1 homebrewM1 aerospace kitty
  nixvim` from `config.flake.modules.darwin`.
- `flake.modules.darwin.m1` sets `inherit host` and imports
  `homeManager.zsh` plus one module per entry in `host.tools`.

The `beelink` NixOS host has the identical shape with a longer concern list
([modules/hosts/nixos/beelink/default.nix#L34-L66](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/nixos/beelink/default.nix#L34-L66)).
Adding a host requires no edit to `flake.nix`, which the README calls out as
the point of the layout
([README.md#L137-L205](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/README.md#L137-L205)).

Host modules accrete across files. `flake.modules.nixos.beelink` is
contributed to by `default.nix`, `hardware.nix`, `configuration.nix`,
`filesystem.nix`, and `network.nix` in the same directory
([hardware.nix#L2-L62](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/nixos/beelink/hardware.nix#L2-L62)).
`flake.modules.darwin.base` is contributed to by 11 different files.

### Where machine identity lives

In one typed submodule, declared once and installed into all three platform
base modules
([modules/hosts/options.nix#L8-L138](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/options.nix#L8-L138)).
The fields are `name`, `user.name`, `state.{version,darwin}`, `system`,
`monitors` (a `listOf submodule`), `tools` (a `listOf enum` over `claude`,
`opencode`, `pi`), `shell`, and three `is*` booleans. There is no data file
and no layered resolver. The `tools` list is the only option that drives
imports, via `map (m: config.flake.modules.homeManager.${m}) host.tools`
([m1/default.nix#L45](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/m1/default.nix#L45)).

One asymmetry: for nixos and darwin the `host` attrset is set as a module
option and read as `config.host`. For standalone home-manager it is passed
as `extraSpecialArgs` and read as a bare `host` function argument
([ubuntu/default.nix#L17-L30](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/nix/ubuntu/default.nix#L17-L30)),
while `home-manager.nix` also injects it as a specialArg from the nixos and
darwin sides
([home-manager.nix#L16-L19](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/home-manager.nix#L16-L19),
[#L41-L44](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/home-manager.nix#L41-L44)).
So home-manager modules see an untyped `host`, and the
`flake.modules.homeManager.base` option declaration for `host` is not what
they read. Not verified by evaluation, but it means the type checking in
`options.nix` does not reach the home-manager fragments.

### Work versus personal, laptop versus server

Neither is a first-class concept. There is no role layer at all. "Work" is
just a host name: `darwinConfigurations.work` is a MacBook Air M3 with
username `lucp10771`
([work/default.nix#L8-L20](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/work/default.nix#L8-L20)),
and `nixosConfigurations.work` is a separate Linux laptop
([nixos work/default.nix#L8-L30](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/nixos/work/default.nix#L8-L30)).
Work-versus-personal differences are expressed two ways, both of them ad
hoc:

1. Two parallel Homebrew concern modules, `homebrewM1` and `homebrewWork`,
   each with its own cask list, selected by the host
   ([homebrew.nix#L28-L122](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/homebrew.nix#L28-L122)).
2. `host.name` string comparison inside shared concern modules. Five files
   do this: `claude.nix`, `opencode.nix`, `pi.nix`, `zsh/zsh.nix`, and
   `gui/hyprland.nix`. The AI-tool modules each carry a three-way
   `if host.name == "MacBookAirM3" then ... else if ...` for endpoints and
   default models
   ([claude.nix#L18-L25](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/claude.nix#L18-L25),
   [pi.nix#L36-L48](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/pi.nix#L36-L48),
   [pi.nix#L97-L122](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/pi.nix#L97-L122),
   [opencode.nix#L45-L70](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/opencode.nix#L45-L70)).
   `zsh.nix` gates a PATH line on `host.name == "MacBookAirM1"`
   ([zsh.nix#L85-L90](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/zsh/zsh.nix#L85-L90)).

That second mechanism is the resolver reappearing inside app modules as
string equality. It is the single most instructive negative result in this
repo, and section 5 returns to it.

## 3. Per-App Config Mechanics

### programs.* versus home.file versus activation

All three are used, chosen per app with no visible rule.

| Mechanism | Where used |
| --- | --- |
| Upstream `programs.*` module | `programs.kitty` ([kitty.nix#L11-L23](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/kitty.nix#L11-L23)), `programs.zsh` ([zsh.nix#L61-L92](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/zsh/zsh.nix#L61-L92)), `programs.direnv` ([direnv.nix#L1-L15](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/direnv.nix#L1-L15)), `programs.nixvim`, `programs.pi-coding-agent` ([pi.nix#L51-L137](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/pi.nix#L51-L137)) |
| Whole-file `home.file` / `xdg.configFile` | `.config/opencode/opencode.json` ([opencode.nix#L80-L84](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/opencode.nix#L80-L84)), `.pi/web-search.json` and `.pi/agent/extensions/pi-permission-system/config.json` ([pi.nix#L143-L188](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/pi.nix#L143-L188)), `.config/aerospace/aerospace.toml` ([aerospace.nix#L14-L24](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/aerospace.nix#L14-L24)), `.config/kitty/kitty.conf` and `.ssh/config` ([kitty.nix#L38-L48](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/kitty.nix#L38-L48)), `xdg.configFile."yabai/yabairc"` ([yabai.nix#L37-L50](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/yabai.nix#L37-L50)) |
| Environment variables instead of a config file | Claude Code, entirely ([claude.nix#L15-L30](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/claude.nix#L15-L30)) |
| `home.activation` | Two reload hooks only: `yabai-reloader` ([yabai.nix#L30-L35](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/yabai.nix#L30-L35)) and `skhd-reloader` ([skhd.nix#L76-L80](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/skhd.nix#L76-L80)) |

Both activation blocks are bare strings, not `lib.hm.dag.entryAfter`
entries. Grep finds zero uses of `entryAfter`, `entryBefore`, or `hm.dag` in
the repo, and zero uses of `onChange`. So the reloaders run on every switch
with no declared ordering relative to `writeBoundary`, and no file-content
trigger exists anywhere.

### Files the app also rewrites

Not handled. There is no merge program, no `modify_`-equivalent, and no
partial-ownership mechanism of any kind. Config files the apps write
themselves are taken over wholesale with `home.file`, which makes them store
symlinks. The repo's answer to the resulting clobber is
`home-manager.backupCommand = "trash"`, set on both the nixos and darwin
sides
([home-manager.nix#L15](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/home-manager.nix#L15),
[#L40](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/home-manager.nix#L40)).
Whatever the app wrote goes to the trash on the next switch. Claude Code is
the one app where the file is left alone entirely, and the module says so:
a commented-out `~/.claude/settings.json` sits in the source as a note about
the alternative that was not taken
([claude.nix#L33-L48](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/claude.nix#L33-L48)).

### macOS defaults

nix-darwin's typed `system.defaults`, plus `CustomUserPreferences` for
domains and keys the typed options do not cover. No `defaults import`, no
home-manager `targets.darwin.defaults`, no deletes, no app quit guard.

The notable detail is where the defaults live: not in a shared concern
module, but in a per-host file under
`modules/hosts/darwin/<host>/darwin-configuration.nix`. The two files are
byte-identical apart from the attribute name on line 2
([m1](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/m1/darwin-configuration.nix#L1-L67),
[work](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/work/darwin-configuration.nix#L1-L67));
diffed with the module name normalized, they match exactly. Sixty-six lines
of duplication in a repo whose stated organizing principle is composition by
feature.

One useful trick is in there: `CustomUserPreferences` accepts a full
absolute plist path as the domain key, which is how a ByHost domain gets
written
([m1/darwin-configuration.nix#L55-L57](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/m1/darwin-configuration.nix#L55-L57)).

### Casks, MAS, taps

nix-darwin's built-in `homebrew` module. There is no `nix-homebrew` input
and no reference to it anywhere in the repo, so Homebrew itself is installed
out of band; the README's macOS install section never mentions it
([README.md#L72-L101](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/README.md#L72-L101)).

Cask ownership is split. A base list of six casks and one MAS app lives in
`darwin.base`
([homebrew.nix#L2-L26](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/homebrew.nix#L2-L26)),
two large per-host lists live in `homebrewM1` and `homebrewWork`
([#L28-L122](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/homebrew.nix#L28-L122)),
and individual app modules contribute their own cask: `kitty` plus two nerd
fonts
([kitty.nix#L29-L36](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/kitty.nix#L29-L36)),
a tap-qualified `nikitabobko/tap/aerospace`
([aerospace.nix#L5-L10](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/aerospace.nix#L5-L10)),
`BarutSRB/tap/omniwm`
([omniwm.nix#L5-L10](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/omniwm.nix#L5-L10)),
and `spaceid` under yabai
([yabai.nix#L23-L27](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/yabai.nix#L23-L27)).
Taps are never declared as a `homebrew.taps` list; they ride along inside
qualified cask names.

`homebrew.onActivation.upgrade = false` and `cleanup` is present but
commented out
([homebrew.nix#L5-L8](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/homebrew.nix#L5-L8)).
So Homebrew is additive-only: nothing removes a cask that leaves the list.

There is no deduplication or validation, and it shows. On the M1 host,
`masApps` ends up with WireGuard twice under two keys, `"wireguard"` in base
and `"Wireguard"` in `homebrewM1`, both id 1451685025
([#L18-L20](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/homebrew.nix#L18-L20),
[#L83](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/homebrew.nix#L83)),
and the same app id 1295203466 appears as both `"Microsoft Remote Desktop"`
and `"Windows App"`
([#L76](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/homebrew.nix#L76),
[#L82](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/homebrew.nix#L82)).
Distinct attribute keys, so the module system merges them without complaint.
There is not a single `assertions` entry in the repo.

### launchd

No hand-written `launchd.agents` or `launchd.user.agents`. The only launchd
usage is implicit, through nix-darwin's own `services.yabai` and
`services.jankyborders` modules
([yabai.nix#L6-L21](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/yabai.nix#L6-L21)).

### Secrets

sops-nix, added in the head commit. One secret, `llama-api`. The encrypted
`secrets.yaml` is committed to the public repo; `.sops.yaml` names a single
age recipient
([.sops.yaml#L1-L7](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/.sops.yaml#L1-L7)).
The darwin base module imports `sops-nix.darwinModules.sops`, points age at
`~/.ssh/sops` and `~/.config/sops/age/keys.txt`, and gives the decrypted
secret `owner` and `group = "staff"`
([sops.nix#L7-L41](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/general/sops.nix#L7-L41)).
`validateSopsFiles = false`.

The consumption pattern is the interesting part. The Nix expression
interpolates the runtime *path* of the decrypted secret into a shell command
substitution inside a session variable:

```nix
ANTHROPIC_AUTH_TOKEN = "$(cat ${osConfig.sops.secrets.llama-api.path})";
```

([claude.nix#L17](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/claude.nix#L17),
same shape at
[pi.nix#L141](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/pi.nix#L141)
and
[opencode.nix#L75](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/opencode.nix#L75)).
The store gets a path, never a value. The value is read by the shell when
the session variable script is sourced.

### Root per switch

The repo treats the darwin switch as an unprivileged operation and the NixOS
switch as a privileged one. `make nixos` is
`sudo nixos-rebuild switch`; `make darwin` is a bare `darwin-rebuild switch`
with no sudo
([Makefile#L104](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/Makefile#L104),
[#L116](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/Makefile#L116)).
The README documents the same
([README.md#L99-L101](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/README.md#L99-L101)).
Recent nix-darwin re-execs itself under sudo, so this is a documentation
convention rather than evidence that root is unnecessary; it was not tested.
`system.primaryUser` is set from `host.user.name`
([users.nix#L19-L27](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/users.nix#L19-L27)).
Nothing in the repo grants or requests privilege.

## 4. Testing And CI

There is none.

- No `.github` directory. No workflow of any kind.
- No `checks` attribute anywhere in the 121 `.nix` files.
- No `assertions`.
- No `nix flake check` target, and the README's development section does not
  mention it
  ([README.md#L288-L326](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/README.md#L288-L326)).

The entire validation surface is the Makefile: per-host `nix eval` on
`config.system.build.toplevel` or `activationPackage` with `--show-trace`
([Makefile#L179-L192](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/Makefile#L179-L192)),
per-host build targets that stop short of switching
([#L106-L133](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/Makefile#L106-L133)),
and `nix flake show` for output discovery
([#L95-L97](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/Makefile#L95-L97)).
That is eval-and-build coverage only, run by hand, on the maintainer's
machine.

## 5. Compare And Contrast

### The central claim: does by-concern actually colocate darwin and home-manager?

Our doc's Nix-Native Target says the unit should be the app module, owning
"its package (nixpkgs or a Homebrew cask entry), its config files, its
`defaults` domain, its launchd agent, its secret references, and any
activation edge it still needs." This repo is the closest public instance of
that idea. The honest verdict is: **yes for the mechanism, no for the
outcome the mechanism is supposed to produce.**

Where it works, it works cleanly. Five exhibits:

| Module | What one file owns |
| --- | --- |
| `aerospace.nix` | The tap-qualified cask, a `jankyborders` nixpkgs package, and the full `aerospace.toml`, in a single `flake.modules.darwin.aerospace` with a nested `home-manager.users.<user>` fragment ([#L2-L24](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/aerospace.nix#L2-L24)) |
| `yabai.nix` | nix-darwin service, scripting addition, a cask, `yabairc`, and the reload activation hook ([#L2-L50](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/yabai.nix#L2-L50)) |
| `pandoc.nix` | A `perSystem` package output plus nixos, home-manager, and darwin fragments, all four sharing `let`-bound `tex`, `mermaidFilter`, `buildScript`, and `pandocEnvironment` ([#L60-L111](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/pandoc.nix#L60-L111)) |
| `nixvim/default.nix` | A `perSystem` neovim package plus three platform fragments sharing `nixvimConfig`, `packages`, and `npmEnvironment` ([#L57-L116](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/editors/nixvim/default.nix#L57-L116)) |
| `direnv.nix` | The cleanest case in the repo: one 15-line file, one `settings` attrset, two platform fragments ([#L1-L15](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/direnv.nix#L1-L15)) |

The costs, all measured at this commit:

1. **The layout does not enforce sharing, only adjacency.** `kitty.nix` is
   the counterexample. It defines `flake.modules.homeManager.kitty` using
   `programs.kitty.settings`
   ([#L11-L23](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/kitty.nix#L11-L23))
   and `flake.modules.darwin.kitty` writing a raw `kitty.conf` heredoc
   ([#L38-L48](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/kitty.nix#L38-L48)).
   Two encodings of the same concern in one file, sharing nothing, and they
   disagree: only the darwin path sets `font_family`, `font_size`, and the
   color scheme. Neither host that imports `darwin.kitty` imports
   `homeManager.kitty`. Colocation made the divergence visible and did
   nothing to prevent it.
2. **Concern boundaries are not enforced by anything.** The kitty module
   also writes `~/.ssh/config`
   ([#L40-L47](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/kitty.nix#L40-L47)).
   The nixvim module owns `.npmrc`, `sessionPath`, `EDITOR`, and `VISUAL`
   ([nixvim/default.nix#L37-L54](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/editors/nixvim/default.nix#L37-L54)).
   "By concern" is a filing convention, not a constraint.
3. **Few files are actually cross-platform.** Only 18 of 121 files touch two
   or more of the three platform namespaces. Six are plumbing (`options.nix`,
   `users.nix`, `home-manager.nix`, `nixpkgs.nix`, `nix.nix`,
   `state-version.nix`) and five are host files whose import lists merely name
   home-manager modules. Seven are genuine cross-platform concern modules:
   `direnv`, `pandoc`, `kitty`, `hyprland`, `niri`, `nixvim`, and `zsh`. The
   count understates colocation slightly, because `aerospace.nix` and
   `yabai.nix` nest their home-manager fragment inside the darwin one rather
   than using the `homeManager` namespace, so they colocate without appearing
   here.
4. **Without a role layer, per-host variation lands inside app modules.**
   Covered in section 2. `pi.nix` runs the same `host.name` list membership
   test three separate times for provider, default provider, and default
   model
   ([#L36-L48](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/pi.nix#L36-L48),
   [#L97-L122](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/pi.nix#L97-L122)).
   Our doc's tree puts `roles/` between hosts and apps precisely to absorb
   this. This repo has hosts and apps and nothing between, and the
   consequence is visible.
5. **What is not filed as a concern gets duplicated per host.** The 66-line
   identical `system.defaults` block, section 3. Our doc's tree has
   `system/macos-defaults.nix`; this repo does not, and pays for it.

### The "what disappears" table

| Our row | This repo | Note |
| --- | --- | --- |
| Resolver and layered `machines*.toml` | Gone, mostly. Replaced by a typed `host` submodule ([options.nix#L8-L122](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/options.nix#L8-L122)). | But `host.name` equality tests are a resolver by other means. |
| Cask gates and inverted file gates | Gone. A cask is declared by the module that owns the app ([aerospace.nix#L5-L10](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/aerospace.nix#L5-L10)). | Strongest confirmation in the repo. |
| Group union, dedupe, unknown-group validation | Gone, and not replaced. Zero `assertions`; the duplicate `masApps` entries survive. | Our doc says these become `assertions`. Nothing forces that to happen. |
| `run_onchange_` hash lines | Gone. Not replaced by `onChange` either; zero uses. Reloaders run unconditionally ([yabai.nix#L30-L35](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/yabai.nix#L30-L35)). | Our row 19 predicts `onChange`. In practice the cheap path wins. |
| Brewfile renderer and golden tests | Gone. `homebrew.casks` is module output. | Confirmed. |
| Drift banner | Gone, replaced by nothing. Only `nix eval` and `nix build` ([Makefile#L179-L192](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/Makefile#L179-L192)). | |
| Plist modify stubs | Gone, replaced by typed `system.defaults` plus `CustomUserPreferences`. | No deletes, no merge, no quit guard. Same gaps our row 23 names. |
| First-run prompts and machine-local data | Gone. Host facts are committed in a `let host = {...}` ([m1/default.nix#L8-L20](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/m1/default.nix#L8-L20)). | Confirms our open question 6. |

### The per-app ownership table

Only three of our nine apps overlap, and the repo takes a fourth position we
did not enumerate.

| App | Our doc's native decision | What this repo does |
| --- | --- | --- |
| Claude Code | Managed drop-in for hooks and permissions; user file keeps `enabledPlugins`. | Neither. No file is managed. Everything is `home.sessionVariables`, and the settings.json alternative is left commented out in source ([claude.nix#L15-L48](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/claude.nix#L15-L48)). |
| pi | Global merge stays; no separate machine-default file. | Uses a `programs.pi-coding-agent` home-manager module with `settings`, `models.providers`, and `context` ([pi.nix#L51-L137](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/pi.nix#L51-L137)), plus two whole-file `home.file` writes for extension config. The module's provenance was not traced in this survey; it is not an explicit flake input, so it likely ships in home-manager or nixpkgs. **Unverified, and worth checking:** if that module exists upstream, our pi row needs revisiting. |
| Cursor, Codex, crit, Orca, Yojam, agentsview, obsidian-wiki | Various. | Absent. |
| opencode | Not in our table. | Whole-file `home.file` from `builtins.toJSON` of a Nix attrset ([opencode.nix#L80-L84](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/opencode.nix#L80-L84)). |

The fourth position, worth adding to our table as an option: **manage the
environment, not the file.** For any setting an app also reads from an
environment variable, `home.sessionVariables` sidesteps the co-ownership
problem entirely. Claude Code's `ANTHROPIC_*`, `DISABLE_TELEMETRY`, and
`CLAUDE_CODE_*` keys are all env-addressable, and this repo uses that
instead of touching `settings.json`.

### Problem A: files the app also writes

This repo does not solve it. It avoids it in the only two ways available
without a merger:

- Do not manage the file (Claude Code).
- Manage the whole file and let home-manager trash whatever the app wrote,
  via `backupCommand = "trash"`
  ([home-manager.nix#L15](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/home-manager.nix#L15),
  [#L40](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/home-manager.nix#L40)).

That second option is exactly the outcome our doc says the 22 mergers exist
to prevent. Seeing a 743-star repo pick it is a useful data point about what
the ecosystem's default answer is when there is no merger: the app's state
loses. It also confirms our row 40 read from the other side. `backupCommand`
is a real alternative to `backupFileExtension` and is slightly less bad,
because trashed files are recoverable, but it does not change the semantics.

Our doc's tier-2 answer, plists through `defaults`, matches what this repo
does, and the same limitations apply here: nothing deletes a key, and the
writes happen on every switch.

### Problem B: the MDM-managed work Mac

No evidence available. The "work" darwin host is a university MacBook Air
M3 with an institutional-looking username, and nothing MDM-shaped appears
anywhere in the repo: no configuration-profile handling, no elevation flow,
no admin-group check, no privileged bootstrap. `system.primaryUser` is set
and that is the extent of privilege modeling
([users.nix#L19-L27](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/users.nix#L19-L27)).
The one relevant observation is that the repo treats a darwin switch as
non-privileged in its own tooling (Makefile line 116, no sudo) while giving
`nixos-rebuild` an explicit `sudo` (line 104). That is a convention, not a
demonstration, and it does not bear on Jamf.

Our doc's Problem B stands untouched by this repo.

### Problem C: secrets without store leakage

Partial evidence, at a much smaller scale: one secret against our three
license files plus per-machine refs.

What transfers: the pattern of interpolating the *decrypted path* rather than
the value, so the store holds a path and the value is read at use time
([claude.nix#L17](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/claude.nix#L17)).
That is a clean answer for env-var-shaped secrets and is directly usable for
anything in our repo where the consumer reads an environment variable.

What confirms our concern: this repo commits an encrypted `secrets.yaml` to a
public repository
([.sops.yaml#L1-L7](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/.sops.yaml#L1-L7)),
which is exactly the policy shift our doc flags for the sops-nix and agenix
rows: our repo currently commits only obfuscated `op://` references. It also
needs an age key present on every machine at
`~/.config/sops/age/keys.txt` or an SSH key at `~/.ssh/sops`
([sops.nix#L16-L19](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/general/sops.nix#L16-L19)),
which is the unencrypted-key-on-disk cost our doc named. And
`validateSopsFiles = false`
([sops.nix#L14](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/general/sops.nix#L14))
turns off the eval-time check that the referenced file is actually
sops-encrypted.

Nothing here bears on 1Password, biometric sessions, or service accounts.

### The test surface

This repo is the low end. Our doc's test-surface section says every host
should be exposed as an explicit `checks` entry because `nix flake check`
skips `darwinConfigurations` and `homeConfigurations`. This repo hits the
same wall and solves it differently: it never uses `checks` at all and
instead ships hand-run per-host `nix eval` and `nix build` Make targets
([Makefile#L106-L133](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/Makefile#L106-L133),
[#L179-L192](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/Makefile#L179-L192)).
That is a working ergonomic answer for a solo maintainer and a poor one for
anything with CI, since nothing enforces it. Our approach of exposing hosts
as `checks` is strictly better and this repo is evidence that it is not the
path of least resistance.

The absence of `assertions` plus the duplicate `masApps` entries is the
concrete cost of that choice.

### Open questions this repo touches

| # | Effect |
| ---: | --- |
| 6 | Confirmed. No machine-local override mechanism exists and none is missed; every host fact is committed source ([m1/default.nix#L8-L20](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/m1/default.nix#L8-L20)). |
| 7 | Answered in practice: no. `cleanup` is written and then commented out ([homebrew.nix#L5-L8](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/homebrew.nix#L5-L8)), so Homebrew stays additive. Our worry that the work Mac may not want `cleanup = "uninstall"` generalizes: this maintainer did not want it on any host. |
| 11 | Weak evidence for key-level over whole-domain. Every managed non-typed domain goes through per-key `CustomUserPreferences`; `defaults import` is never used. |
| 12 | Partly answered. A full absolute plist path works as a `CustomUserPreferences` key, which covers ByHost domains the typed options do not reach ([m1/darwin-configuration.nix#L55-L57](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/m1/darwin-configuration.nix#L55-L57)). |
| 9 | Reframed. Before asking which Claude keys belong in a managed drop-in, ask which do not need a file at all. This repo configures Claude Code entirely through environment variables ([claude.nix#L15-L30](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/claude.nix#L15-L30)). |
| 1, 2, 3, 4, 5, 8, 10, 13, 14, 15, 16 | No evidence. |

## 6. What To Take, What To Avoid

### Take

- **Three-channel overlay for version selection.** `nixpkgs`,
  `nixpkgs-stable`, and `nixpkgs-master` exposed as `pkgs`, `pkgs.stable`,
  and `pkgs.master`
  ([flake.nix#L64-L76](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/flake.nix#L64-L76)),
  used as `master.claude-code`
  ([claude.nix#L13](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/claude.nix#L13)).
  This is a direct answer to our concept-map row 34 tension between mise's
  `latest` for AI CLIs and nixpkgs pinning: track head for the handful of
  tools that need it, per package, without unpinning the world.
- **`import-tree` over an explicit import list.** Adding a host or a concern
  is adding a file. `flake.nix` never changes
  ([flake.nix#L48](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/flake.nix#L48),
  [README.md#L137-L141](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/README.md#L137-L205)).
- **Per-platform named attributes instead of `mkIf` on platform.** Reading
  `flake.modules.darwin.foo` next to `flake.modules.homeManager.foo` is
  clearer than one attrset threaded with platform conditionals, and it
  avoids evaluating Linux-only options on Darwin.
- **A `let`-bound shared fragment imported by each platform variant.**
  `pandocEnvironment`
  ([pandoc.nix#L52-L57](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/pandoc.nix#L52-L57))
  and `npmEnvironment`
  ([nixvim/default.nix#L37-L54](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/editors/nixvim/default.nix#L37-L54))
  are the actual mechanism that makes colocation pay. The module namespaces
  put the fragments in one file; the `let` binding is what stops them
  diverging. Our doc should say this explicitly.
- **Secret path interpolation, not secret value interpolation.** For
  env-var-shaped secrets, `"$(cat ${secrets.<name>.path})"` in
  `home.sessionVariables`
  ([claude.nix#L17](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/programs/claude.nix#L17)).
- **Configure by environment variable where the app supports it.** Cheapest
  possible answer to Problem A, and it costs nothing to check per app.
- **A typed host submodule with an enum-constrained feature list.**
  `tools = listOf (enum ["claude" "opencode" "pi"])` driving imports via
  `map`
  ([options.nix#L87-L97](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/options.nix#L87-L97),
  [m1/default.nix#L45](https://github.com/MatthiasBenaets/nix-config/blob/2c5564c7125f0af26312755dce7e5ff0a667a329/modules/hosts/darwin/m1/default.nix#L45))
  is a small, readable version of our `machine.groups`.

### Avoid

- **`host.name` string equality inside app modules.** Five files do it. Put
  the variation in a role or a typed option and let hosts set it. This is
  the strongest argument for the `roles/` layer our doc already proposes.
- **`backupCommand = "trash"` or `force = true` as the answer to co-owned
  files.** It silently discards app state. Our mergers exist for a reason;
  this repo shows what dropping them looks like.
- **Filing macOS defaults under the host rather than as a concern.** Two
  hosts, 66 duplicated lines, already drifting-shaped.
- **No `assertions` anywhere.** Duplicate MAS entries under different keys
  are the visible symptom. Our validation should be `assertions`, and this
  repo shows they will not appear on their own.
- **Two encodings of one app's config in one file.** `programs.kitty.settings`
  next to a raw `kitty.conf` heredoc.
- **`validateSopsFiles = false`** without a reason recorded.
- **README host tables that drift from the module tree.** Two of the six
  documented hosts do not exist.

### Relevance: 4 out of 5

High architectural relevance, low operational relevance.

It earns the 4 because it is the only large public config in this set built
the way our doc's Nix-Native Target describes, it names the pattern
(dendritic), it runs that pattern across three platform classes and six
hosts at 121 files, and it is recently maintained. That makes it a real test
of the composition claim rather than a thought experiment, and the test
produces both a confirmation and a set of specific, citable failure modes we
can design against: no role layer means host-name conditionals in app
modules, no shared defaults module means per-host duplication, and
colocation without a shared `let` binding produces divergence rather than
reuse. The `nixpkgs-master` overlay is a technique we can adopt this week.

It does not earn a 5 because it is silent on all three of our hardest
problems. There is no MDM-managed host, so Problem B gets nothing. There is
no merge mechanism at all, so Problem A gets a warning rather than a
solution. There is one secret and no 1Password, so Problem C gets a single
transferable trick. And there is no CI, no `checks`, and no `assertions`, so
the test-surface section gets only a counterexample. Our repo has 22 co-owned
files, four machine types including a Jamf-managed work Mac, a headless Linux
profile, and a CI lane. This repo has none of those pressures, which is
precisely why its layout stays clean and why its layout is not yet proof that
ours would.

## 7. Scorecard

Concept-map rows from Appendix A of the target-state doc.

| Row | Verdict | Note (five words) |
| ---: | --- | --- |
| 1 | Supports | home.file used throughout, works |
| 2 | Supports | ssh config left world-readable |
| 5 | Supports | interpolation replaces templates cleanly |
| 6 | Supports | committed host attrset, no prompts |
| 7 | Supports | no local override, none missed |
| 8 | Alternative | typed submodule, no layer merging |
| 9 | Supports | homebrew module owns cask lists |
| 11 | Contradicts | cleanup written then deliberately disabled |
| 13 | Contradicts | no nix-homebrew, brew installed manually |
| 16 | Supports | module imports replace ignore gates |
| 17 | Supports | app module declares own cask |
| 19 | Contradicts | zero onChange, unconditional activation instead |
| 20 | Supports | idempotent activation, no stamp files |
| 21 | Contradicts | bare activation strings, no DAG |
| 23 | Supports | per-key writes, deletes unsolved |
| 24 | Contradicts | no mergers, whole-file ownership only |
| 26 | Supports | typed system.defaults replaces defaults script |
| 27 | Alternative | no elevation model, sudo-free switch |
| 34 | Alternative | nixpkgs-master overlay gives head packages |
| 37 | Alternative | sops path interpolated, value read late |
| 38 | Contradicts | no drift surface at all |
| 40 | Supports | backupCommand trash, clobber problem real |
| 42 | Contradicts | zero CI, hand-run Makefile evals |
