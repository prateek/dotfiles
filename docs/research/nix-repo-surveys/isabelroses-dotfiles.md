---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-04
updated: 2026-09-04
related:
  - ../nix-target-state-research.md
  - ../nix-migration-research.md
status_detail: "Agent survey of isabelroses/dotfiles at d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0, compared with the Nix target-state doc. Unreviewed."
---

# Survey: isabelroses/dotfiles

## Method

Surveyed on 2026-09-04 at commit
[`d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0`](https://github.com/isabelroses/dotfiles/tree/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0).
The tree was extracted to a scratch directory and read with `cat`, `sed -n`,
and `grep`. Repository metadata came from the GitHub API on the same date.

Files read in full or in part: `flake.nix`, `justfile`, `.sops.yaml`,
`modules/flake/default.nix`, `modules/flake/lib/mkhost.nix`,
`modules/flake/lib/secrets.nix`, `modules/flake/checks/*.nix`,
`modules/flake/packages/update-pins/update-pins.sh`,
`modules/generic/{profiles,packages}.nix`,
`modules/base/{nixpkgs.nix,users/*.nix,system/vars.nix,nix/substituters.nix}`,
`modules/darwin/default.nix`, `modules/darwin/brew/{default,environment}.nix`,
`modules/darwin/legacy.nix`, `modules/darwin/preferences/*.nix`,
`modules/darwin/hardware/*.nix`, `modules/darwin/security/*.nix`,
`modules/home/{home,secrets,profiles}.nix`,
`modules/home/programs/defaults.nix`, `modules/home/environment/xdg.nix`,
`home/default.nix`, `home/isabel/{git,packages,discord,sops,chromium,ssh,gh}.nix`,
`home/isabel/vicinae/{default,extension}.nix`,
`systems/{tatsumaki,freyja}/*.nix`, `.github/workflows/*.yml`,
`.github/actions/install-lix/action.yml`, `.github/dependabot.yml`, and the
Astro docs under `docs/src/content/docs/`.

Comparison targets are [the Nix target-state doc](../nix-target-state-research.md)
and [the earlier migration research](../nix-migration-research.md).

## 1. What It Is

Isabel Roses is a NixOS and Lix contributor who publishes this flake as a
personal configuration with its own documentation site. The repo warns that it
is personal and will not work unaltered
([introduction.mdx#L6-L13](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/docs/src/content/docs/introduction.mdx#L6-L13)).

| Fact | Value |
| --- | --- |
| Stars / forks | 444 / 16 (GitHub API, 2026-09-04) |
| Created | 2023-01-24 |
| License | EUPL-1.2 |
| `.nix` files | 292 |
| Commits, last 52 weeks | 1210 |
| Top contributors | isabelroses, bellsbot, github-actions, comfysage, NotAShelf |

Six hosts: five NixOS (one desktop, three servers, one ISO) and one macOS
laptop
([default.nix#L40-L67](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/flake/default.nix#L40-L67);
[topology.mdx#L11-L18](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/docs/src/content/docs/design/topology.mdx#L11-L18)).
The Mac is a university-issued MacBook Air used at university, not a
corporate-managed device with an MDM policy stack.

The lock is bumped by a daily cron at 00:45 UTC using
`DeterminateSystems/update-flake-lock`, and the workflow waits for checks and
then rebases and merges its own PR
([update.yml#L1-L47](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/.github/workflows/update.yml#L1-L47)).
Pins that flakes cannot express get a separate 396-line updater covering the
Homebrew release tag, the two tap revisions, Chromium extension CRX versions,
and Vicinae or Raycast extension revisions with their `npmDepsHash`
([update-pins.sh#L106-L120](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/flake/packages/update-pins/update-pins.sh#L106-L120),
[#L293-L340](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/flake/packages/update-pins/update-pins.sh#L293-L340);
[justfile#L149-L155](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/justfile#L149-L155)).
That script prefetches every npm hash before writing anything so a mid-loop
failure cannot pair a bumped revision with a stale hash
([#L326-L335](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/flake/packages/update-pins/update-pins.sh#L326-L335)).

Two ecosystem choices are worth flagging. `nixpkgs` is a lockable HTTP
tarball rather than a GitHub flake, and home-manager is a personal fork on a
branch named `smfh`
([flake.nix#L16](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/flake.nix#L16),
[#L36-L42](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/flake.nix#L36-L42)).
The fork exists to supply an experimental file linker backend
([home.nix#L6-L7](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/home/home.nix#L6-L7)).

## 2. Composition

The flake body is one import
([flake.nix#L4](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/flake.nix#L4)).
`mkHost` takes a name and two optional keys, `arch` and `class`, then imports
exactly two paths: the host directory and the class directory
([mkhost.nix#L29-L33](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/flake/lib/mkhost.nix#L29-L33),
[#L61-L66](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/flake/lib/mkhost.nix#L61-L66)).
It also hand-rolls `inputs'` because the author wants flake-parts behavior
without flake-parts
([#L47-L51](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/flake/lib/mkhost.nix#L47-L51)).

| Layer | Holds |
| --- | --- |
| `modules/flake` | Flake outputs, `mkHost`, checks, packages |
| `modules/generic` | Module-system-agnostic options: profiles, package seam |
| `modules/base` | Shared NixOS and Darwin: users, nix settings, nixpkgs policy |
| `modules/darwin` | Homebrew, preferences, hardware, security, primary user |
| `modules/nixos` | Linux-only system config |
| `modules/home` | home-manager wiring, secrets, XDG, program defaults |
| `home/<user>` | One file per application |

A system selects modules by turning on profile booleans. The vocabulary is
five options declared once
([profiles.nix#L6-L12](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/generic/profiles.nix#L6-L12)),
mirrored into home-manager and extended with media sub-profiles
([modules/home/profiles.nix](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/home/profiles.nix)).
The entire macOS host is eleven lines
([systems/tatsumaki/default.nix#L1-L11](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/systems/tatsumaki/default.nix#L1-L11)),
and a server host differs only in which booleans and device facts it sets
([systems/freyja/default.nix#L7-L19](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/systems/freyja/default.nix#L7-L19)).
Laptop, server, and Mac are expressed as `laptop.enable`, `server.enable`, and
the `class = "darwin"` argument. There is no machine-type string read at
evaluation time.

Identity lives in two places. `garden.system.users` is a typed list with a
`mainUser` drawn from it
([modules/base/users/options.nix](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/base/users/options.nix)),
and `home/default.nix` generates one home-manager user per entry by importing
`home/<name>`
([home/default.nix#L16-L34](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/default.nix#L16-L34)).
The Darwin host hardcodes `system.primaryUser`
([legacy.nix#L1-L3](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/darwin/legacy.nix#L1-L3)).

Packages have a single seam. `garden.packages` is typed `lazyAttrsOf package`
and routed by `_class` to either `home.packages` or
`environment.systemPackages`
([packages.nix#L9-L24](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/generic/packages.nix#L9-L24)).
User package selection is a merge of profile-conditional attribute sets, not a
data file
([home/isabel/packages.nix#L16-L92](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/isabel/packages.nix#L16-L92)).
Overlays are forbidden by assertion
([nixpkgs.nix#L36-L41](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/base/nixpkgs.nix#L36-L41)).

## 3. Per-App Config Mechanics

The dominant mechanism is upstream `programs.*` modules, gated on profiles.
`programs.git` and `programs.gh` inherit their `enable` from
`garden.profiles.workstation`
([git.nix#L17](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/isabel/git.nix#L17);
[gh.nix#L3-L4](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/isabel/gh.nix#L3-L4)).
There are 37 entries under `home/isabel`, roughly one per app.

Hand-written file seams are rare. Across the whole tree there are two
`home.file` sites and three `xdg.configFile` sites.

| Seam | Count | Sites |
| --- | ---: | --- |
| `home.file` | 2 | [discord.nix#L29-L31](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/isabel/discord.nix#L29-L31), [ssh.nix#L87-L89](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/isabel/ssh.nix#L87-L89) |
| `xdg.configFile` | 3 | [rnnoise.nix#L12](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/isabel/rnnoise.nix#L12), [discord.nix#L40-L42](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/isabel/discord.nix#L40-L42), [xdg.nix#L165](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/home/environment/xdg.nix#L165) |
| `home.activation` | 1 | [git.nix#L205-L208](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/isabel/git.nix#L205-L208) |
| `onChange`, `force`, `mkOutOfStoreSymlink` | 0 | none |

No app-rewritten file is managed through a merge. The one structured config
they own, the Discord client's `moonlight` settings, is declared as a typed
option and generated whole by `pkgs.formats.json`, written to
`Library/Application Support/moonlight-mod/stable.json` on macOS and to the
XDG path on Linux
([discord.nix#L14-L42](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/isabel/discord.nix#L14-L42)).
The single activation block is the only concession to a file that already
exists on disk: on Darwin it removes `~/.gitconfig` before
`checkLinkTargets` runs
([git.nix#L205-L208](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/isabel/git.nix#L205-L208)).
A repo-wide `backupFileExtension = "bak"` covers the rest
([home/default.nix#L18](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/default.nix#L18)).

macOS defaults are typed nix-darwin options plus `CustomUserPreferences` for
domains without typed coverage. Eleven files under
`modules/darwin/preferences` carry `system.defaults.{dock,finder,loginwindow,NSGlobalDomain,LaunchServices}`
and `CustomUserPreferences` for `com.apple.finder`, `com.apple.spaces`,
`com.apple.WindowManager`, and others
([wm.nix#L1-L14](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/darwin/preferences/wm.nix#L1-L14);
[finder.nix#L32-L40](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/darwin/preferences/finder.nix#L32-L40);
[ads.nix#L2](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/darwin/security/ads.nix#L2)).
There is no plist merge engine, no `defaults import`, and no quit-and-relaunch
guard.

Homebrew is fully pinned. `nix-homebrew` fetches a tagged `brew` release and
two tap revisions with `mutableTaps = false`, and the nix-darwin `homebrew`
module runs with `cleanup = "zap"`, `caskArgs.require_sha = true`, and an
empty `masApps`
([brew/default.nix#L14-L46](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/darwin/brew/default.nix#L14-L46),
[#L57-L90](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/darwin/brew/default.nix#L57-L90)).
Taps are derived from the pinned set rather than listed twice
([#L78](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/darwin/brew/default.nix#L78)).
There are no launchd agents anywhere in the tree.

Secrets are sops-nix. The home-manager module is imported centrally with a
per-user default file and an age key at `$XDG_CONFIG_HOME/sops/age/keys.txt`
([modules/home/secrets.nix#L9-L15](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/home/secrets.nix#L9-L15)).
Encrypted YAML is committed to the public repo, with creation rules giving the
user file one recipient and service files all host keys
([.sops.yaml#L11-L17](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/.sops.yaml#L11-L17)).
Secrets land at real paths, for example a WakaTime config
([home/isabel/sops.nix#L6-L9](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/isabel/sops.nix#L6-L9)).
Rotation is a just recipe over `sops rotate` and `sops updatekeys`
([justfile#L168-L180](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/justfile#L168-L180)).

Root is required on every macOS switch: the rebuild command is
`sudo darwin-rebuild`
([justfile#L4](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/justfile#L4)),
and first provisioning is `sudo nix run github:LnL7/nix-darwin -- switch`
followed by removing the imperative Lix install
([justfile#L99-L101](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/justfile#L99-L101)).
Touch ID for sudo is enabled through
`security.pam.services.sudo_local.touchIdAuth`
([pam.nix#L1-L4](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/darwin/security/pam.nix#L1-L4)).

Two derivations are notable because they replace an install-time build step.
Chromium extensions are pinned by id, version, and hash and fetched as CRX
from the Chrome Web Store update endpoint
([chromium.nix#L24-L36](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/isabel/chromium.nix#L24-L36)).
Vicinae launcher extensions are built with `buildNpmPackage` through
`extendMkDerivation`, with a sparse checkout of a single extension directory
and `npm run build -- -o "$out"`
([extension.nix#L3-L53](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/isabel/vicinae/extension.nix#L3-L53)).
One of those extensions has `type = "raycast"` and is pulled from the Raycast
extensions monorepo
([vicinae/default.nix#L14-L45](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/isabel/vicinae/default.nix#L14-L45)).
The upstream `package.json` for that extension declares `"build": "ray build"`,
confirmed through the GitHub contents API on 2026-09-04, so `ray build` is in
fact running inside a sandboxed derivation.

## 4. Testing And CI

`checks` contains exactly three derivations: a treefmt run, a port-collision
detector over one host's service options, and unit tests for the repo's own
lib
([checks/default.nix#L6-L20](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/flake/checks/default.nix#L6-L20)).
No host is exposed as a check. The PR job is
`nix develop -c just check --show-trace` on a Linux and a macOS runner
([check.yml#L16-L37](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/.github/workflows/check.yml#L16-L37)),
where `check` is `nix flake check --option allow-import-from-derivation false`
([justfile#L128-L131](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/justfile#L128-L131)).

Host coverage comes from a second workflow. `diff.yml` enumerates
`nixosConfigurations.*.config.system.build.toplevel` and
`darwinConfigurations.*.system` with `nix eval`, feeds them to
`natsukium/nix-diff-action`, and updates a single PR comment
([diff.yml#L29-L55](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/.github/workflows/diff.yml#L29-L55)).
A second job runs `NIX_SHOW_STATS=1` on base and head and posts an evaluation
statistics comparison
([diff.yml#L79-L125](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/.github/workflows/diff.yml#L79-L125)).
Both jobs run on `ubuntu-latest`
([diff.yml#L14-L15](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/.github/workflows/diff.yml#L14-L15)),
so the aarch64-darwin attribute in that list cannot be realised there. Whether
the action evaluates or builds each attribute is unverified.

ISOs are built on a twice-monthly cron and published as releases
([build-isos.yml](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/.github/workflows/build-isos.yml)).
Lix is installed in CI from the author's own fork
([install-lix/action.yml](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/.github/actions/install-lix/action.yml)).
Dependabot covers actions and the docs npm tree
([dependabot.yml](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/.github/dependabot.yml)).
There is no macOS VM lane and no activation test.

## 5. Compare And Contrast With Our Doc

### The app-module-plus-roles composition model

Evidence for. Our doc argues that a host should import roles, that roles
should import app modules, and that nothing should read a machine-type value
at evaluation time. This repo does exactly that at a smaller scale: five
profile booleans
([profiles.nix#L6-L12](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/generic/profiles.nix#L6-L12)),
an eleven-line host
([tatsumaki/default.nix#L1-L11](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/systems/tatsumaki/default.nix#L1-L11)),
and one file per app. One difference is worth adopting. Our doc puts package
selection inside each app module; this repo keeps a single typed
`garden.packages` seam that both module classes consume
([packages.nix#L9-L24](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/generic/packages.nix#L9-L24)),
which is how they avoid writing the same list twice for NixOS and Darwin. Our
doc should mention that seam. No change to the model itself.

Their host files also show a cost we should name. Because the host file is
the only place profiles are set, per-user detail leaks into a second host
file: `systems/tatsumaki/users.nix` enables three programs for one user
([users.nix#L1-L11](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/systems/tatsumaki/users.nix#L1-L11)).
With four machine types and two users, our repo would hit that seam sooner.

### The "what disappears" table

Evidence for most rows, silent on two. The resolver, the cask gates, the
group union, the `run_onchange_` hash lines, the first-run prompts, and the
XDG data block all have no analogue here, which is consistent with our claim
that they are artifacts of the chezmoi shape rather than real requirements.
Two rows have counter-evidence. Our table says the retired-package ledger
becomes a per-host Homebrew policy; this repo picks the most aggressive
setting available, `cleanup = "zap"`
([brew/default.nix#L67](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/darwin/brew/default.nix#L67)),
which is broader than the `uninstall` our doc considered and is only viable
because no host has software they do not control. Our table says plist modify
stubs are kept for shapes `defaults` cannot express; this repo never needs
that escape hatch, but it also manages far less. No change; add the "zap"
option to row 11 as the upper bound.

### The per-app ownership table

Evidence for the "own the whole file" branch only. Their single structured
config is generated whole from a typed option
([discord.nix#L14-L42](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/isabel/discord.nix#L14-L42)),
which is the shape our table assigns to Codex and obsidian-wiki. There is no
example here of an app layer, a managed drop-in, or a surviving merger. This
repo cannot settle the six apps our table leaves as mergers. Our table stands.

### Problem A, files the app also writes

Not tested by this repo, and that is the most useful finding. They manage
almost nothing an app rewrites: two `home.file` sites, three `xdg.configFile`
sites, one activation block, and zero `onChange`, `force`, or
`mkOutOfStoreSymlink`. Their entire answer to a pre-existing app-owned file is
to delete it before linking
([git.nix#L205-L208](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/isabel/git.nix#L205-L208))
and to set `backupFileExtension`
([home/default.nix#L18](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/default.nix#L18)).
Read correctly, this repo is evidence that the Nix-native shape is clean when
you avoid co-owned files, not evidence that our 22 merges dissolve. Our doc
should say that explicitly: the cleanliness of published Nix configs is
partly a selection effect.

### Problem B, the MDM-managed work Mac

Not addressed. One personal Mac, `sudo` on every switch
([justfile#L4](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/justfile#L4)),
Touch ID sudo enabled
([pam.nix#L1-L4](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/darwin/security/pam.nix#L1-L4)),
and a hardcoded primary user
([legacy.nix#L1-L3](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/darwin/legacy.nix#L1-L3)).
Nothing about Jamf, restrictions profiles, or an endpoint agent. Our Problem B
and open questions 3 and 16 stay open.

### Problem C, secrets without store leakage

An alternative policy, not a solution to ours. They commit sops-encrypted YAML
to a public repo and hold the age key at a fixed local path
([modules/home/secrets.nix#L9-L15](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/home/secrets.nix#L9-L15);
[.sops.yaml#L11-L17](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/.sops.yaml#L11-L17)).
That is precisely the shift our Problem C flagged: ciphertext in git instead
of a live 1Password read. It works for them because the blast radius is
personal. It answers our open question 5 only in the negative sense that they
never needed a service account. Our doc should cite this as the reference
implementation of the sops branch, and keep the reservation.

### The test surface

Evidence for, and sharper than our phrasing. Our doc warns that
`nix flake check` does not touch `darwinConfigurations` and that every host
must be exposed explicitly. This repo is a live confirmation: `checks` holds
three derivations and no host
([checks/default.nix#L6-L20](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/flake/checks/default.nix#L6-L20)),
so their macOS CI job proves nothing about the Mac. Their compensation is
worth stealing: a separate workflow that enumerates host attributes and posts
a closure diff to the PR
([diff.yml#L29-L55](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/.github/workflows/diff.yml#L29-L55)).
That is a concrete answer to our "Diffs" bullet and a partial replacement for
the drift banner: not per-file preference content, but a reviewable
per-host closure delta before merge. Add it to the test-surface section.

The `port-collector` check is a second idea worth naming. It groups one
host's service options by port and fails on collisions
([port-collector.nix](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/flake/checks/port-collector.nix)).
That is the class of test our doc calls "assertions on module options",
implemented as a check rather than an assertion.

### Open questions this repo answers or reframes

| Q | Effect | Evidence |
| ---: | --- | --- |
| 5 | Neither answered nor needed here; they use sops, not 1Password. | [secrets.nix#L9-L15](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/home/secrets.nix#L9-L15) |
| 7 | Reframed. `cleanup = "zap"` is the upper bound, viable only without unmanaged software. | [brew/default.nix#L63-L68](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/darwin/brew/default.nix#L63-L68) |
| 8 | Answered yes. A Raycast extension whose upstream build script is `ray build` is built in a derivation with a pinned `npmDepsHash`. | [extension.nix#L35-L53](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/isabel/vicinae/extension.nix#L35-L53), [vicinae/default.nix#L36-L40](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/home/isabel/vicinae/default.nix#L36-L40) |
| 11 | Partially answered. They never whole-domain import; `CustomUserPreferences` at key level is their default for uncovered domains. | [wm.nix#L1-L14](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/darwin/preferences/wm.nix#L1-L14) |
| 12 | Partially answered. They hit the typed-coverage wall on Finder extras, Spaces, and WindowManager and fall back to `CustomUserPreferences`. | [finder.nix#L32-L40](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/darwin/preferences/finder.nix#L32-L40) |

Questions 1, 2, 3, 4, 6, 9, 10, 13, 14, 15, and 16 get no evidence here.

Two further claims of ours are worth revising. First, our doc treats the lock
bump as "a lock bump you review, or a launchd job". This repo bumps daily,
waits on checks, and auto-merges
([update.yml#L41-L47](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/.github/workflows/update.yml#L41-L47)),
which is a stronger and cheaper answer. Second, our doc does not account for
the pins a flake cannot hold. Homebrew tags, tap revisions, CRX versions, and
npm dependency hashes all need their own updater
([update-pins.sh#L106-L120](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/flake/packages/update-pins/update-pins.sh#L106-L120)).
Our repo would inherit that problem the moment it pins Homebrew.

## 6. What To Take, What To Avoid, Relevance

Take:

- The two-workflow test split: `nix flake check` for what it covers, plus a
  host-attribute closure diff posted to the PR.
- A single typed package seam routed by `_class`, so one list serves both
  NixOS and Darwin.
- Profile booleans as the only host-level vocabulary, with host files kept
  small enough to read in one screen.
- A dedicated updater for pins that flakes cannot express, with all hashes
  prefetched before any file is written.
- Collision-style checks over module options, as with `port-collector`.
- `caskArgs.require_sha = true` and pinned taps as a supply-chain default.

Avoid:

- A personal home-manager fork for an experimental linker backend
  ([home.nix#L6-L7](https://github.com/isabelroses/dotfiles/blob/d38717cc989e2a9d0b8d8eb0ef3dfa5ab0c95cc0/modules/home/home.nix#L6-L7)).
- Lix and a personal Lix fork as the CI and local package manager.
- `nixpkgs` as an HTTP tarball rather than a flake input.
- `cleanup = "zap"` on any machine with software you do not fully control.
- Their `checks` shape, which leaves the only Mac untested by `just check`.
- Committing ciphertext to a public repo without deciding the key-recovery
  story first.

Relevance: 3 of 5. The composition model is the cleanest small example of the
shape our target-state doc proposes, and two mechanisms are directly reusable
today: the closure-diff workflow and the pins updater. Against that, the repo
avoids all three of our hardest problems. It manages almost no file an app
also writes, it has no MDM-managed host, and its secrets policy trades a
1Password read for public ciphertext. It is also a single-user, single-Mac
configuration with roughly one tenth of our macOS surface, and it carries two
dependencies we should not take. Useful as a template for structure, not as
evidence that the hard parts of our migration are solved.

## 7. Scorecard Against Our Concept Map

Row numbers refer to Appendix A of
[the target-state doc](../nix-target-state-research.md). Rows with no evidence
in this repo are omitted, including 3, 12, 14, 15, 18, 22, 25, 28, 29, 30, 33,
34, 35, and 41.

| Row | Verdict | Note |
| ---: | --- | --- |
| 1 | Supports | Two home.file uses, nothing more |
| 2 | Alternative | sops-nix owns restricted-mode secret files |
| 4 | Alternative | No live links exist anywhere |
| 5 | Supports | Typed options replace all templating |
| 6 | Supports | Host attribute replaces every prompt |
| 7 | Supports | All host policy stays committed |
| 8 | Supports | Eleven-line host imports three profiles |
| 9 | Supports | One typed package attribute set |
| 10 | Supports | Most packages come from nixpkgs |
| 11 | Alternative | cleanup zap exceeds uninstall semantics |
| 13 | Supports | nix-homebrew pins brew and taps |
| 16 | Supports | Profile booleans replace ignore gates |
| 17 | Supports | Cask list lives in module |
| 19 | Alternative | Zero onChange hooks anywhere here |
| 20 | Supports | Idempotent activation, no stamp files |
| 21 | Supports | entryBefore orders the single activation |
| 23 | Alternative | CustomUserPreferences without any merge step |
| 24 | Alternative | Nix owns whole JSON file |
| 26 | Supports | Typed defaults across eleven files |
| 27 | Alternative | Plain sudo, no Jamf flow |
| 31 | Supports | ray build runs inside derivation |
| 32 | Supports | Sources built as pinned derivations |
| 36 | Supports | XDG native options plus sessionVariables |
| 37 | Alternative | sops-nix replaces 1Password entirely here |
| 38 | Alternative | CI closure diff replaces banner |
| 39 | Alternative | Nix source is the diff |
| 40 | Supports | backupFileExtension plus one preemptive removal |
| 42 | Alternative | Eval and diff, no VM |
