---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-04
updated: 2026-09-04
related:
  - ../nix-target-state-research.md
  - ../nix-migration-research.md
status_detail: "Agent survey of khaneliman/khanelinix at f79bdff347dd283b7cb15bf3fb0deaddff3b41b7, compared with the Nix target-state doc. Unreviewed."
---

# Survey: khaneliman/khanelinix

## Method

Snapshot commit `f79bdff347dd283b7cb15bf3fb0deaddff3b41b7`, dated 2026-09-03,
fetched 2026-09-04 with `gh api repos/khaneliman/khanelinix/tarball/<sha>` and
read from a local extract. Every permalink below points at that sha. Nothing is
cited that was not opened.

Read in full: `flake.nix`; `flake/{default,configs,home,tests}.nix`;
`flake/dev/{checks,tests}.nix`; `lib/system/{common,mk-darwin}.nix`;
`lib/tests/default.nix`; `lib/snapshot-tests/**`; `namaka.toml`;
`systems/aarch64-darwin/khanelimac/default.nix`;
`modules/darwin/{archetypes/workstation,tools/homebrew,suites/development,security/sops,system/interface,programs/terminal/tools/darwin-doctor}`;
`modules/home/{system/darwin-defaults,services/sops,programs/terminal/tools/codex,programs/terminal/tools/claude-code,programs/graphical/apps/meetingbar}`;
`modules/common/ai-tools/codex-managed-requirements.nix`; `patches/**`;
`.sops.yaml`; `.github/workflows/*`; `docs/architecture.md`;
`docs/module-enablement/*`; `modules/AGENTS.md`; `modules/home/AGENTS.md`;
`README.md`.

Counted with `find` and `ls` over the extract. Not read: `modules/nixos/**`
beyond file counts, `packages/**`, `overlays/**`, `templates/**`, the NixOS host
trees, and the marketplace Python beyond its README.

Compared against [nix-target-state-research.md](../nix-target-state-research.md),
including the 42-row concept map in its Appendix A.

## 1. What It Is

A personal cross-platform Nix configuration for one operator, public since
2023-05-11. At the snapshot the GitHub API reported 343 stars, 18 forks, no
license field, and a last push of 2026-09-04. At least 100 commits landed in the
30 days before the snapshot; that number is the API page cap, so the real figure
is higher. The absent license matters if code is copied out.

The brief describes the author as a current home-manager maintainer. That is not
verified here. The repo does not assert it, and `nix-community/home-manager` has
no `.github/CODEOWNERS` to check. Treat it as unverified. What the repo does show
is a first-class mechanism for patching home-manager and nix-darwin before they
are evaluated, which is a maintainer-shaped habit.

Platforms are declared as two systems,
[`flake.nix#L173-L180`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/flake.nix#L173-L180),
with all flake logic imported from `./flake`. Host inventory from the extract:

| Directory | Hosts |
| --- | --- |
| `systems/aarch64-darwin` | `khanelimac`, `khanelimac-m1` |
| `systems/x86_64-linux` | `bruddynix`, `CORE-PW0D2M1A`, `khanelilab`, `khanelinix`, `nixos`, `VT0-IT-47-D443` |
| `systems/aarch64-linux` | `nixos` |
| `systems/x86_64-iso`, `systems/x86_64-install-iso` | `isolated`, `rescue`, `graphical`, `minimal` |
| `homes/aarch64-darwin` | `khaneliman@khanelimac`, `khaneliman@khanelimac-m1` |
| `homes/x86_64-linux` | 6 entries including `bruddy@bruddynix` and two corporate-looking hostnames |

730 `.nix` files total. By module tree: `modules/home` 312, `modules/nixos` 154,
`modules/darwin` 48, `modules/common` 17. The rest is `lib`, `flake`, `packages`
(roughly 46), `overlays` (16), `templates` (12), hosts, and homes.

Lock bumps are automated. A daily cron runs `nix flake update` plus
`nix flake update --flake ./flake/dev`, commits `chore(flake): update locks`, and
opens a PR labeled `merge-queue`
([`update-flakes.yml#L9`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/.github/workflows/update-flakes.yml#L9),
[`#L55-L56`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/.github/workflows/update-flakes.yml#L55-L56),
[`#L79`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/.github/workflows/update-flakes.yml#L79),
[`#L97`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/.github/workflows/update-flakes.yml#L97)).

## 2. Composition

### Everything is imported; options do the selecting

This is the load-bearing design choice, and it is the opposite of what our doc
assumes. `flake/configs.nix` reads every file under `modules/darwin` with
`importModulesRecursive` and passes the whole set to every Darwin host, and does
the same for NixOS
([`configs.nix#L19-L20`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/flake/configs.nix#L19-L20),
[`#L43-L55`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/flake/configs.nix#L43-L55)).
A module is never selected by importing it. It is selected by turning its
`khanelinix.*` enable option on. Every module body sits behind `lib.mkIf`.

The username is hardcoded in the flake plumbing at
[`configs.nix#L36`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/flake/configs.nix#L36)
and
[`#L50`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/flake/configs.nix#L50),
so the repo is a single-operator artifact by construction.

### Archetype, suite, module

Three composition levels sit on top of the single option namespace, documented at
[`architecture.md#L1-L20`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/docs/architecture.md#L1-L20).

| Level | What it is | Example |
| --- | --- | --- |
| Archetype | An enable option that switches on a set of suites and may add packages | `workstation` turns on `business`, `common`, `desktop`, `development` and adds a tap plus the `deskflow` cask ([`workstation#L13-L36`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/darwin/archetypes/workstation/default.nix#L13-L36)) |
| Suite | An enable option with sub-options that switches on modules and system policy | `development` carries `aiEnable`, `containerBackend`, `developerDirectory`, `devToolsSecurity` ([`development#L14-L25`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/darwin/suites/development/default.nix#L14-L25)) |
| Module | One app or subsystem, wrapper options plus `mkIf` body | `khanelinix.tools.homebrew` ([`homebrew#L13-L21`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/darwin/tools/homebrew/default.nix#L13-L21)) |

Suites are set with `lib.mkDefault` so a host can override any of them
([`overrides.md#L3`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/docs/module-enablement/overrides.md#L3)).
`lib.khanelinix.enabled` is the sugar for `{ enable = true; }`. The archetype to
suite mapping is published as a matrix table, one for NixOS and one for Darwin
([`archetypes.md#L1-L23`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/docs/module-enablement/archetypes.md#L1-L23)).

### Where identity lives

In the host file, and nowhere else. `khanelimac` sets its archetypes
([`#L17-L20`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/systems/aarch64-darwin/khanelimac/default.nix#L17-L20)),
its suites including `development.aiEnable` and `containerBackend = "colima"`
([`#L118-L134`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/systems/aarch64-darwin/khanelimac/default.nix#L118-L134)),
its Homebrew policy
([`#L138-L141`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/systems/aarch64-darwin/khanelimac/default.nix#L138-L141)),
and `system.primaryUser` plus `stateVersion`
([`#L174-L177`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/systems/aarch64-darwin/khanelimac/default.nix#L174-L177)).
There is no machine-type value, no layered data file, and no first-run prompt.

### Laptop, desktop, server, Mac

There is no laptop archetype. NixOS gets `workstation`, `personal`, `gaming`,
`server`, `vm`, `wsl`; Darwin gets `workstation`, `personal`, `vm`. Portable
versus desktop differences land in the host file. Darwin-only concerns get their
own modules under `modules/darwin`, Linux-only under `modules/nixos`, and the
17 files in `modules/common` are the shared layer. The AI-tools data set lives in
`modules/common` and feeds both the Darwin system layer and the home layer, which
is the only cross-platform commons that matters for our comparison.

### Flake plumbing

`flake/default.nix` splits the flake with flake-parts partitions: `checks`,
`devShells`, `formatter`, and `templates` move into a `dev` partition with its own
inputs flake and its own lock
([`flake/default.nix#L15-L28`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/flake/default.nix#L15-L28)).
Consumers of the flake do not pay for namaka, nix-unit, or git-hooks.

Home configurations are exposed twice: standalone as
`homeConfigurations."<user>@<host>"`
([`flake/home.nix#L41-L48`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/flake/home.nix#L41-L48))
and embedded in the system build through `matchingHomes`
([`configs.nix#L21-L25`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/flake/configs.nix#L21-L25)).

## 3. Per-App Config Mechanics

### The stated rule

"Prefer native Home Manager program/service options over `home.file` or generated
config. Use `xdg.configFile` when no native module surface exists"
([`modules/home/AGENTS.md#L18-L19`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/home/AGENTS.md#L18-L19)).
The repo follows it. `home.file.` appears in 5 `.nix` files across 730.

### Whole-file ownership for the AI CLIs

Claude Code and Codex both go through upstream home-manager program modules, with
the whole config owned by Nix.

- `programs.claude-code` with `configDir = "${config.xdg.configHome}/claude"`
  ([`claude-code#L122-L124`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/home/programs/terminal/tools/claude-code/default.nix#L122-L124)),
  hooks assembled by zipping 15 hook modules into concatenated lists
  ([`#L19`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/home/programs/terminal/tools/claude-code/default.nix#L19)),
  and agents, commands, and skills inherited from the shared AI-tools data
  ([`#L165-L166`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/home/programs/terminal/tools/claude-code/default.nix#L165-L166)).
- `programs.codex` with settings, profiles, and MCP servers
  ([`codex#L261-L268`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/home/programs/terminal/tools/codex/default.nix#L261-L268)),
  and a wrapper that sets `CODEX_HOME` so the config lands under XDG
  ([`#L64-L70`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/home/programs/terminal/tools/codex/default.nix#L64-L70)).

There is no merge-into-an-app-owned-file mechanism anywhere in the repo. The
closest thing to our problem is a comment recording a real store-symlink defeat:
"Codex rejects symlinked role files. Point role declarations at regular Nix store
files instead of copying them into the mutable Codex home"
([`codex#L109-L110`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/home/programs/terminal/tools/codex/default.nix#L109-L110)).
Their answer is indirection: point the app at an absolute store path rather than
placing a symlink where the app expects a file.

### The root-provisioned managed layer

`environment.etc."codex/requirements.toml"` and `environment.etc."codex/hooks"`
are provisioned by the Darwin system layer when `aiEnable` is set
([`development#L98-L102`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/darwin/suites/development/default.nix#L98-L102)),
generated from
[`codex-managed-requirements.nix`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/common/ai-tools/codex-managed-requirements.nix#L1-L9),
which sets `allow_managed_hooks_only`, `features.hooks`, and
`hooks.managed_dir = "/etc/codex/hooks"`. This is a working instance of the
managed-`/etc` seam our doc proposes. Note the filename: they write
`/etc/codex/requirements.toml`, not the `config.toml` or `managed_config.toml`
our per-app table names. Whether that is the same seam under a different name was
not verified here.

### macOS defaults: four mechanisms, split by domain ownership

This is the most useful finding in the repo, and it is more nuanced than a first
pass suggests. They use all of the following:

| Mechanism | Scope | Where |
| --- | --- | --- |
| `system.defaults.<typed domain>` | Dock, hardening, host-specific | 4 files, one of them a template, including [`interface#L39-L56`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/darwin/system/interface/default.nix#L39-L56) |
| `system.defaults.CustomUserPreferences` | Per-key writes into shared domains, as root | [`interface#L23-L37`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/darwin/system/interface/default.nix#L23-L37) |
| `targets.darwin.defaults."<domain>"` | Exactly one app-private domain | [`meetingbar#L24-L26`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/home/programs/graphical/apps/meetingbar/default.nix#L24-L26) |
| A bespoke Python `defaults` manager | Five bool keys in `NSGlobalDomain` and `com.apple.desktopservices`, from the home layer | [`darwin-defaults/default.nix#L10-L94`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/home/system/darwin-defaults/default.nix#L10-L94) |

The operative pattern: whole-domain home-manager `defaults import` is used only
for an app-private domain, and shared domains are written key by key. The bespoke
module is literally named "domain-safe macOS user preferences"
([`#L56-L57`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/home/system/darwin-defaults/default.nix#L56-L57)).
Their stated motive is not in the source, so read the split as a pattern rather
than as a claim about `defaults import`.

The manager itself is the part worth stealing. It is built with
`pkgs.writers.writePython3Bin`, driven by a JSON specification generated from the
module options, and run as a home-manager activation entry after `writeBoundary`
through the `run` wrapper so `DRY_RUN` is honored
([`#L90-L94`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/home/system/darwin-defaults/default.nix#L90-L94)).
Before the first write of any key it records a baseline of the prior value,
base64-encoded from the binary plist, into a 0600 file under `xdg.stateHome`
written atomically with `os.replace`
([`manage.py#L28-L30`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/home/system/darwin-defaults/manage.py#L28-L30),
[`#L48-L57`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/home/system/darwin-defaults/manage.py#L48-L57),
[`#L64-L82`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/home/system/darwin-defaults/manage.py#L64-L82)).
It applies with `/usr/bin/defaults write` and refuses anything that is not a bool
([`#L84-L99`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/home/system/darwin-defaults/manage.py#L84-L99)).
A `restore` subcommand exports the live domain, patches the recorded keys back in,
and re-imports it
([`#L111-L132`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/home/system/darwin-defaults/manage.py#L111-L132)),
shipped to the user as a `darwin-defaults-restore` wrapper
([`default.nix#L47-L53`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/home/system/darwin-defaults/default.nix#L47-L53)).

### Homebrew, casks, MAS, taps

nix-darwin's own module. There is no `nix-homebrew` input in `flake.nix`, so
Homebrew's own installation is not managed. The policy module sets
`cleanup = "uninstall"`, `greedyCasks = true`, and a global Brewfile, and exposes
one host-facing dial:

```nix
idempotentActivation = lib.mkOption {
  type = lib.types.bool;
  default = true;
  description = "Whether system activation installs declared Homebrew entries without updating or upgrading existing entries.";
};
```

which flips `autoUpdate`, `upgrade`, and `--force` together
([`homebrew#L16-L20`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/darwin/tools/homebrew/default.nix#L16-L20),
[`#L43-L50`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/darwin/tools/homebrew/default.nix#L43-L50)).
`khanelimac` opts out of idempotent activation and opts into MAS. MAS apps are
declared in the suite behind `masEnable`
([`development#L79`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/darwin/suites/development/default.nix#L79)).
Taps come with `trusted = true` from the archetype that needs them
([`workstation#L18-L26`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/darwin/archetypes/workstation/default.nix#L18-L26)).

### launchd, activation, secrets

LaunchAgents go through home-manager `launchd.agents` (12 files reference it).
Imperative Mac steps that have no declarative surface stay in
`system.activationScripts.postActivation.text = lib.mkAfter`: `xcode-select
--switch` against an expected developer directory, and `DevToolsSecurity`
enable or disable against an expected state
([`development#L104-L137`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/darwin/suites/development/default.nix#L104-L137)).
Both are written to converge rather than to fire blindly, which matches the
repo's own instruction that activation scripts run on every rebuild and must be
idempotent.

Secrets are sops-nix with committed ciphertext. Eight encrypted YAML files live
under `secrets/`, routed by per-path `creation_rules` in
[`.sops.yaml#L10-L62`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/.sops.yaml#L10-L62)
with eight age recipients. The Darwin system layer derives its age key from
`/etc/ssh/ssh_host_ed25519_key`, a file that exists on a stock macOS install
([`security/sops#L16-L28`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/darwin/security/sops/default.nix#L16-L28)).
The home layer sets `age.generateKey = true` with a key file under
`~/.config/sops/age/keys.txt` and also accepts `~/.ssh/id_ed25519`
([`services/sops#L36-L40`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/home/services/sops/default.nix#L36-L40)).
There is no 1Password anywhere in the repo.

Because Darwin activation is a root `darwin-rebuild switch`, the system layer
writes `/etc` and system defaults directly, while user-scoped work is delegated to
the embedded home-manager configuration. The Darwin builder wires home-manager,
sops-nix, stylix, and nix-rosetta-builder as darwin modules alongside every
`modules/darwin` file
([`mk-darwin.nix`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/lib/system/mk-darwin.nix)).

### The `patches/` tree, corrected

The brief describes patches against home-manager, nix-darwin, and nixpkgs. That
is the machinery, not the contents. Six inputs are supported; five of the six
`default.nix` files are empty placeholder lists with a commented example, for
example
[`patches/home-manager/default.nix#L1-L18`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/patches/home-manager/default.nix#L1-L18).
The only live patch in the tree is
[`patches/nix-rosetta-builder/separate-max-jobs.patch`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/patches/nix-rosetta-builder/separate-max-jobs.patch).
The README frames the mechanism as short-lived upstream backports, such as testing
a merged pull request before the pinned input updates
([`patches/README.md#L7-L9`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/patches/README.md#L7-L9)).
The engine lives in
[`lib/system/common.nix`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/lib/system/common.nix):
it applies patches with `pkgs.applyPatches` and then re-imports the patched
flake's own `flake.nix` outputs with a synthetic `self`.

## 4. Testing And CI

### The snapshot tests are one API-surface guard

The `lib/snapshot-tests` tree holds a single test. Its expression is three lines:

```nix
{ khanelinix }:

builtins.mapAttrs (_: value: builtins.attrNames value) (removeAttrs khanelinix.lib [ "overlay" ])
```

([`expr.nix#L1-L3`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/lib/snapshot-tests/lib-exports/expr.nix#L1-L3)).
The committed snapshot is a `#json` file listing the attribute names exported by
each `khanelinix.lib` namespace
([`_snapshots/lib-exports`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/lib/snapshot-tests/_snapshots/lib-exports)).
It snapshots names, not values, and not rendered configuration. It fails when a
lib helper is added, renamed, or removed, and it stays quiet for every behavior
change inside those helpers.

namaka is loaded into `checks.<system>.namaka-snapshots` by dumping the load
result to JSON in a `runCommand`
([`flake/dev/tests.nix#L16-L34`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/flake/dev/tests.nix#L16-L34)),
and `namaka.toml` points the tool at `nix flake check` and at that check attribute
([`namaka.toml#L1-L5`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/namaka.toml#L1-L5)).
How a stale snapshot is regenerated is namaka's own review flow; that tooling was
not read here, so treat the update path as unverified.

### nix-unit covers lib helpers only

`lib/tests/default.nix` holds about 30 `expr`/`expected` assertions over base64
decoding, string helpers, bool conversion, package-profile resolution, suite
profile inclusion, `enabled`/`disabled` sugar, option constructors, and the
numeric priorities of the default and force attribute sets
([`lib/tests/default.nix`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/lib/tests/default.nix)).
There is not one assertion about a module, a host, or a rendered file. The
nix-unit check is given the locked root inputs explicitly "so the check stays
offline"
([`flake/dev/tests.nix#L36-L52`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/flake/dev/tests.nix#L36-L52)).

### The Darwin checks never run

Host closures are exposed as checks, which is what our doc recommends, but behind
a platform conditional:

```nix
checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin (
  lib.mapAttrs' (name: cfg: {
    name = "darwin-${name}";
    value = cfg.system;
  }) self.darwinConfigurations
);
```

([`flake/dev/checks.nix#L128-L133`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/flake/dev/checks.nix#L128-L133)).
CI runs `nix flake check --system x86_64-linux --print-build-logs` on
`ubuntu-latest`
([`check.yml#L6-L19`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/.github/workflows/check.yml#L6-L19)).
The only macOS job in the repo builds dev shells on an `aarch64-darwin` matrix leg
([`build-dev-shells.yml#L22-L30`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/.github/workflows/build-dev-shells.yml#L22-L30)).
So no Darwin host closure is ever built by CI. The check exists; the runner does
not.

### The rest of CI

| Workflow | What it does |
| --- | --- |
| `check.yml` | flake-checker-action, Cachix, `nix flake check` on Linux |
| `build-dev-shells.yml` | dev shells on `x86_64-linux` and `aarch64-darwin` |
| `fmt.yml`, `lint.yml`, `deadnix.yml` | treefmt, statix, deadnix |
| `label.yml` | PR labeler |
| `update-flakes.yml` | daily lock bump PR |

Pre-commit runs through `git-hooks-nix` in the dev partition, with treefmt,
statix, deadnix, typos, and `pre-commit-hook-ensure-sops`
([`flake/dev/checks.nix#L13`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/flake/dev/checks.nix#L13),
[`#L75-L83`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/flake/dev/checks.nix#L75-L83)).
One comment there is worth copying verbatim into any repo that runs statix through
treefmt: `statix fix` silently skips lints that have no auto-fix, so only
`statix check` reports them
([`#L76-L82`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/flake/dev/checks.nix#L76-L82)).

### Darwin-specific validation is a doctor, not a test

`darwin-doctor` is the repo's answer to "did activation actually land". At build
time it serializes the evaluated intent into `/etc/khanelinix/darwin-doctor.json`:
the generated Brewfile as a store path, the persistent launchd agents filtered to
those with `RunAtLoad` or `KeepAlive`, the five owned preference keys, the Time
Machine destination and exclusions, and the development settings
([`darwin-doctor/default.nix#L15-L88`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/darwin/programs/terminal/tools/darwin-doctor/default.nix#L15-L88)).
It ships a `writePython3Bin "darwin-doctor"` into `environment.systemPackages`
that checks each of those against the live machine with `launchctl print`,
`defaults export`, `brew`, `xcode-select`, `DevToolsSecurity`, and container
queries, and prints a status table or JSON
([`doctor.py`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/darwin/programs/terminal/tools/darwin-doctor/doctor.py)).
The option is named "report-only Darwin workstation doctor"
([`default.nix#L83-L84`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/darwin/programs/terminal/tools/darwin-doctor/default.nix#L83-L84)).
It is a system package, not a check, so nothing runs it automatically.

## 5. Compare And Contrast With Our Doc

### Composition model: alternative, not agreement

Our doc's row 8 and row 16 both assume imports do the selecting: roles and host
imports replace the layered resolver, and `mkIf` on machine options replaces the
ignore gates. khanelinix agrees on the second and rejects the first. It imports
every module into every host and selects entirely by option
([`configs.nix#L19-L20`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/flake/configs.nix#L19-L20)).

The tradeoff is real in both directions. Option-time selection means every host
pays evaluation for 48 Darwin modules plus 312 home modules, and every module body
must be defensive. It also means the archetype-to-suite mapping is a table you can
publish, and adding a module never requires editing an import list. Import-time
selection is cheaper and more explicit, which suits a repo where most apps are
Mac-only.

Recommendation: our doc should name the two strategies in the composition model
section and say which one it picks and why. The current text reads as if
import-time selection is the only native option, and the largest surveyed repo
does the other thing.

### The "what disappears" table

Supported by absence for most rows. khanelinix has no feature resolver, no cask
gate templates, no group union, no change-hash lines, no retired-package ledger,
no first-run prompts, and no host-local override file. Two rows need edits.

| Row | Our claim | What khanelinix shows |
| --- | --- | --- |
| Brewfile renderer and golden tests | "Gone. `homebrew.brewfile` is module output." | Correct, and they go one step further: `pkgs.writeText "Brewfile" config.homebrew.brewfile` is fed to a checker as a store path ([`darwin-doctor#L15`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/darwin/programs/terminal/tools/darwin-doctor/default.nix#L15)) |
| Drift banner | "Gone. Generations and `nix store diff-closures`, with the per-file loss in row 38." | Understated. A doctor that renders evaluated intent to `/etc` and diffs it against live state recovers most of the banner, per-file, without chezmoi |

### Per-app ownership table

khanelinix confirms one row and is silent on the rest. The Codex managed-`/etc`
seam is buildable and in production on their Mac, which moves that row from "docs
read" to "seen working", with the filename caveat noted in section 3. They do not
use Claude Code's managed-settings drop-in; Claude is configured entirely at the
user level through `configDir`. There is no pi, Orca, agentsview, crit, Cursor, or
Yojam anywhere in the repo, so those six rows get no new evidence.

### Problem A, files the app also writes

This is where the repo earns its relevance score. Their preferences design maps
onto our three tiers and adds a fourth idea we do not have.

| Our tier | khanelinix equivalent |
| --- | --- |
| 1. Use the app's own layer | `/etc/codex/*` for Codex; nothing for Claude |
| 2. Plists through `defaults` | Yes, but split: typed `system.defaults` and root `CustomUserPreferences` for system domains, `targets.darwin.defaults` for exactly one app-private domain |
| 3. Keep the mergers as activation | A Python program run from an activation entry after `writeBoundary` through `run`, applied to preferences rather than to JSON |
| Not in our doc | Record a baseline of every key before the first write, and ship a `restore` command |

The baseline ledger is the piece to steal. Our tier 3 accepts that the merger
owns a subset of keys and leaves the rest alone, but it has no way to answer "what
did this repo change on this machine, and how do I put it back". A 0600 JSON file
under `XDG_STATE_HOME` holding the base64 prior value per key answers both, and it
costs about 40 lines
([`manage.py#L38-L82`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/home/system/darwin-defaults/manage.py#L38-L82)).

Our doc should change: add a fourth bullet to Problem A's target design, "record
what you overwrote", with the baseline plus restore shape.

### Problem B, the MDM-managed work Mac

No evidence. There is no MDM, no Jamf, and no corporate Mac in the repo. Two
x86_64-linux hosts carry corporate-looking names, `CORE-PW0D2M1A` and
`VT0-IT-47-D443`, but they are Linux and their configs were not read. Problem B
stays entirely on us.

### Problem C, secrets without store leakage

Contradicts our recommended target, and supplies one mitigation we did not
consider. They commit encrypted secrets to a public repo, which our doc explicitly
declines as a policy shift from "refs only". Set that aside and one detail is
still useful: on Darwin the system-level age key is derived from
`/etc/ssh/ssh_host_ed25519_key`
([`security/sops#L16-L18`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/darwin/security/sops/default.nix#L16-L18)),
a file that already exists on a stock macOS install. That removes our
"adds an unencrypted age key on every machine" objection for the system layer,
though their home layer still generates one
([`services/sops#L36-L40`](https://github.com/khaneliman/khanelinix/blob/f79bdff347dd283b7cb15bf3fb0deaddff3b41b7/modules/home/services/sops/default.nix#L36-L40)).

Our doc should change: add the SSH-host-key derivation as a footnote to the
sops-nix row, while keeping the `op://`-refs-only recommendation.

### The test surface

Supports our "expose every host as a check" bullet and demonstrates its failure
mode: the checks are Darwin-gated, CI is Linux-only, and so the Darwin closures
are never built. Our doc should state the corollary explicitly. Exposing hosts as
checks buys nothing without a runner of that system, which for us means a macOS
runner or an accepted gap.

Contradicts the framing that "module tests replace template golden tests". A
730-file repo with two years of history has zero module assertions, zero host
assertions, and one snapshot that guards a lib API surface. That is far thinner
than what our test-surface section proposes. The proposal is not unreasonable, but
our doc should say plainly that it is above the ecosystem norm, because the cost
of writing and maintaining those assertions is the thing that will get cut first.

### Open questions

| Q | Effect |
| ---: | --- |
| 1 | No evidence. They install Claude skills through the home-manager module, not through a `directory` marketplace of store symlinks. |
| 2 | No evidence, but the baseline design treats shared domains as contested territory. |
| 3 | No evidence. |
| 4 | No evidence. |
| 5 | No evidence. No 1Password in the repo. |
| 7 | Reframed and answered by example. `cleanup = "uninstall"` plus `greedyCasks` on a personal Mac, with `idempotentActivation` as the per-host dial. The question stops being yes or no and becomes which dial to expose. |
| 8 | No evidence. No Raycast. |
| 9 | No evidence. Claude is user-level only. |
| 10 | Partially answered. Their managed `/etc` layer holds only a hooks policy; everything else is user-level. |
| 11 | Reframed. Their operative answer is that whole-domain import is for app-private domains, and shared domains get key-level writes. |
| 12 | Data point. Their manager supports only `bool` and refuses everything else, which is how little they needed. |
| 13, 14, 15, 16 | No evidence. |

## 6. What To Take, What To Avoid

### Take

1. **The baseline ledger.** Record the prior value of every preference key before
   the first write, and ship a `restore` command. Directly portable to our plist
   story and to the JSON mergers.
2. **A doctor, not a banner.** Render evaluated intent to
   `/etc/<repo>/doctor.json` at build time and ship a checker that compares it
   against live state. This is the best available replacement for
   `chezmoi status` plus the drift banner, and it is per-file, which
   `nix store diff-closures` is not.
3. **`idempotentActivation` as a per-host Homebrew dial.** One boolean that moves
   `autoUpdate`, `upgrade`, and `--force` together is a cleaner interface than
   three independent knobs, and it turns our open question 7 into a host option.
4. **flake-parts `partitions.dev`.** Keep namaka, nix-unit, and git-hooks in a
   separate flake with its own lock so the main lock stays small.
5. **Options rendered to docs.** If we adopt a `dotfiles.*` namespace,
   `nixosOptionsDoc` over that namespace replaces hand-written option docs.
6. **Per-directory `AGENTS.md` with the wrapper-shape convention and the exact
   per-platform validation command.** Ours already does something similar; theirs
   is a good model for the module-tree level.

### Avoid

1. **Import everything and gate by option.** It costs evaluation on every host and
   forces `mkIf` discipline everywhere, for a repo whose apps are mostly Mac-only.
2. **Committing encrypted secrets to a public repo.** Our `op://`-refs policy is
   deliberate and their model would reverse it.
3. **Treating a snapshot suite as coverage.** One lib-API snapshot is a rename
   guard.
4. **Platform-gated checks with no runner of that platform.** Either add a macOS
   runner or write down that host closures are unbuilt in CI.
5. **Input patching as standing machinery.** Five of six patch directories are
   empty placeholders. The engine re-imports a patched flake's outputs with a
   synthetic `self` for a case that arises about once.

### Relevance: 4 of 5

This is the closest large public analogue to the problems in our target-state
doc. It is macOS-first on at least one host, it configures the same AI CLIs we do,
it has to answer the same Homebrew declarativeness question, and it hit the same
preferences problem the module system does not solve, then built something for it.
Two of its answers, the baseline ledger and the doctor, are things our doc is
missing rather than things it already covers. It loses a point because three of our
hardest constraints are absent: there is no MDM-managed Mac, no 1Password, and no
requirement to merge into files an app rewrites. Its test surface is thinner than
what we run today, so it is a source of design ideas rather than of validation
practice.

## 7. Concept-Map Scorecard

Verdicts are relative to Appendix A of
[nix-target-state-research.md](../nix-target-state-research.md). "No evidence"
means the construct does not appear in what was read, not that it was rejected.

| Row | Verdict | Note |
| ---: | --- | --- |
| 1 | Supports | Native modules preferred over files |
| 2 | Alternative | Activation writes the 0600 file |
| 3 | No evidence | `executable = true` barely used |
| 4 | No evidence | No `mkOutOfStoreSymlink` in repo |
| 5 | Supports | Options replace templating entirely here |
| 6 | Supports | Host attribute selects the config |
| 7 | Supports | All host policy is committed |
| 8 | Alternative | Suites use `mkDefault`, not layers |
| 9 | Supports | Modules contribute taps, casks, masApps |
| 10 | Supports | Packages declared in owning modules |
| 11 | Supports | `cleanup = "uninstall"` plus greedy casks |
| 12 | No evidence | No fork-swap reconciler present |
| 13 | Alternative | No nix-homebrew; brew installed manually |
| 14 | No evidence | No private overlay input present |
| 15 | No evidence | No zinit anywhere in repo |
| 16 | Supports | `mkIf` on options gates everything |
| 17 | Supports | Archetype adds cask with tap |
| 18 | No evidence | No removal mechanism was read |
| 19 | No evidence | `onChange` used in two files |
| 20 | Alternative | Baseline ledger emulates once semantics |
| 21 | Supports | `entryAfter writeBoundary` with `run` wrapper |
| 22 | Supports | `writePython3Bin` gives store interpreter |
| 23 | Alternative | Bespoke manager for shared domains |
| 24 | Alternative | Whole-file ownership, no merging anywhere |
| 25 | No evidence | No quit-and-relaunch guard exists |
| 26 | Supports | Typed defaults plus CustomUserPreferences used |
| 27 | No evidence | Root activation, no elevation helper |
| 28 | Supports | HM `launchd.agents` read by doctor |
| 29 | Alternative | Store paths, not symlinks, for roles |
| 30 | No evidence | karabiner-elements enabled, no goku |
| 31 | No evidence | No Raycast extensions in repo |
| 32 | Supports | `xcode-select` stays in postActivation script |
| 33 | No evidence | No gh extension packaging read |
| 34 | No evidence | No mise in the repo |
| 35 | No evidence | zsh config not read here |
| 36 | Supports | `xdg.stateHome` and `configHome` used directly |
| 37 | Contradicts | Committed sops secrets, no 1Password |
| 38 | Alternative | Doctor compares evaluated intent versus live |
| 39 | Alternative | Doctor reports mismatches, not diffs |
| 40 | No evidence | No clobber policy was read |
| 41 | No evidence | No headless standalone HM profile |
| 42 | Contradicts | Darwin closures never built in CI |
