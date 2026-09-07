---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-04
updated: 2026-09-04
related:
  - ../nix-target-state-research.md
  - ../nix-migration-research.md
status_detail: "Agent survey of EmergentMind/nix-config at a8ba4f4b6746466119b3c9f62befac97b9427cd5, compared with the Nix target-state doc. Unreviewed."
---

# Survey: EmergentMind/nix-config

## Method

Read on 2026-09-04 against a pinned tarball of the default branch (`dev`) at
`a8ba4f4b6746466119b3c9f62befac97b9427cd5`, fetched with
`gh api repos/EmergentMind/nix-config/tarball/<sha>`. A second tarball of the
frozen `darwin` branch at `95a9d14d950ca84f3e415b08ab89b81a7e3f2ee7` was read
for the macOS and test-surface questions, because `dev` has neither.

Opened on `dev`: `README.md`, `flake.nix`, `shell.nix`, `justfile`, `.envrc`,
`.gitignore`, `lib/default.nix`, `checks/default.nix`,
`checks/unwanted-builtins.sh`, `hosts/common/core/*`,
`hosts/common/users/default.nix`, `hosts/nixos/ghost/{default,host-spec}.nix`,
`modules/hosts/common/{host-spec,nix}.nix`, `modules/hosts/darwin/default.nix`,
`modules/home/{default,copyq,llm,pi-model-config}.nix`,
`home/common/core/{default,bat,zsh/default}.nix`,
`home/common/core/timers/trash-empty.nix`,
`home/common/optional/{sops.nix,llm/agents.nix,desktops/noctalia.nix}`,
`home/ta/{ghost.nix,common/default.nix}`, `microvms/**`, and all of `docs/`.
Opened on `darwin`: `checks/default.nix`, `tests/sops.bats`,
`tests/helpers/test_helper.bash`, `hosts/common/core/darwin.nix`,
`home/common/core/darwin.nix`, plus recursive tree listings.

Structural counts come from `find` and `grep` over the pinned tarballs.
Repository metadata comes from the GitHub API on 2026-09-04. Everything below
that is not cited is marked unverified.

Citations use permalinks. `dev` links carry the `a8ba4f4b` sha; `darwin` links
carry the `95a9d14d` sha and say so.

## 1. What It Is

A single-author NixOS configuration by EmergentMind, who publishes an
accompanying article and video series ("Anatomy of a NixOS Config") and treats
the repo as teaching material as much as personal infrastructure
([README L85-L93](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/README.md#L85-L93)).
The README opens by telling readers it will "serve you best as a reference,
learning resource, and template" rather than something to run
([README L85](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/README.md#L85)).

| Fact | Value | Source |
| --- | --- | --- |
| Stars / forks | 643 / 41 | GitHub API, 2026-09-04 |
| Created / last push | 2024-01-30 / 2026-09-01 | GitHub API |
| Default branch | `dev` (also: `darwin`) | GitHub API |
| License | MIT | GitHub API |
| Commits in trailing 90 days | 32 | GitHub API |
| `.nix` files | 176 | `find` over the pinned tarball |
| Platforms actually built | NixOS only, `x86_64-linux` only | [flake.nix L135-L137](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L135-L137) |
| Host directories | 5 live (`genoa`, `ghost`, `grovr`, `gusto`, `iso`), 2 under `hosts/disabled/` | tree listing |
| `nixosConfigurations` attrs | 9: five hosts plus a `<host>Minimal` for each non-ISO host | [flake.nix L114-L122](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L114-L122) |
| Users | `ta` (primary), `clara`, `media`, plus a keys-only `super` | tree listing |

**Darwin is gone.** The `darwinConfigurations` output is commented out
([flake.nix L133](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L133)),
`hosts/darwin/` does not exist, and `hosts/common/core/darwin.nix` is a
two-line file containing `{ }`
([hosts/common/core/darwin.nix L1-L2](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/core/darwin.nix#L1-L2)).
The README says the project is "migrating away from Darwin support for the
foreseeable future" and keeps the old state on the `darwin` branch
([README L177](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/README.md#L177)).
That branch last moved on 2025-12-18. It is no better: `darwinConfigurations`
is commented there too, nix-darwin is a commented-out input, and grep over its
`.nix` files finds zero `system.defaults`, zero `launchd`, zero `casks`, zero
`masApps`, and one `homebrew` hit, which is
`home.sessionPath = [ "/opt/homebrew/bin" ]`
([darwin@95a9d14 home/common/core/darwin.nix L1-L10](https://github.com/EmergentMind/nix-config/blob/95a9d14d950ca84f3e415b08ab89b81a7e3f2ee7/home/common/core/darwin.nix#L1-L10)).
No Darwin host was ever committed on either branch.

**The flake is not evaluable by anyone else.** Two inputs are absolute local
paths on the author's machine, `introdus` at `path:///home/ta/dev/nix/introdus/ta`
([flake.nix L278-L281](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L278-L281))
and `emergentvim` at `path:///home/ta/dev/nix/neovim`
([flake.nix L293](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L293)),
and `nix-secrets` is a private SSH-only git repo
([flake.nix L284-L287](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L284-L287)).
Nothing here can be built, checked, or evaluated off the author's box. Treat
every claim about how well it works as unverifiable from outside.

**How the lock is bumped.** Not on a review cadence. `just rebuild` runs a
private `rebuild-pre` recipe that updates `nix-secrets`, `nix-assets`,
`emergentvim`, `nix-index-database`, and `introdus` before every single
rebuild
([justfile L9-L18](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L9-L18)),
where `just update` is `nix flake update <input> --timeout 5`
([justfile L56-L59](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L56-L59)).
`just upgrade` bumps everything and rebuilds
([justfile L61-L63](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L61-L63)).
nixpkgs itself is pinned to `nixos-26.05` with home-manager on `release-26.05`
([flake.nix L186](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L186),
[L199-L202](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L199-L202)),
so the churn is confined to the five personal inputs. The consequence is still
that no rebuild is reproducible from the committed lock alone.

## 2. Composition

### The core/optional split

`core` means "present on every host, this is a hard rule"; anything else is
`optional`, on both the host and the home side
([README L104-L121](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/README.md#L104-L121)).
`hosts/common/core/default.nix` is the shared base: it imports the
home-manager, sops-nix, disko, and nix-index modules under a platform-derived
attribute name, then imports `modules/hosts/common`, `modules/hosts/<platform>`,
`hosts/common/core/<platform>.nix`, and the users tree
([hosts/common/core/default.nix L12-L34](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/core/default.nix#L12-L34)).

### How a host opts in

By writing a literal list of relative paths. `ghost` names `hosts/common/core`
and then 17 individual files under `hosts/common/optional/`, each with a
trailing comment saying what it is
([hosts/nixos/ghost/default.nix L16-L57](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/nixos/ghost/default.nix#L16-L57)).
The home side does the same thing separately: `home/ta/ghost.nix` names
`home/common/core`, `home/ta/common`, and 14 optional entries
([home/ta/ghost.nix L3-L30](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/ta/ghost.nix#L3-L30)).

There are no roles. The closest thing is a directory with a `default.nix` that
scans its siblings, so naming `"desktops"` or `"development"` pulls in the
whole folder
([home/common/optional/development/default.nix L8](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/common/optional/development/default.nix#L8)).
`lib.custom.scanPaths ./.` also auto-imports every sibling `.nix` inside a host
directory
([hosts/nixos/ghost/default.nix L24](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/nixos/ghost/default.nix#L24))
and inside `modules/home`
([modules/home/default.nix L4-L7](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/modules/home/default.nix#L4-L7)).
Note that the repo's own `lib/` is six lines and exports only
`relativeToRoot`; `scanPaths`, `scanPathsFilterPlatform`, and the microvm
builders all live in the external `introdus` input
([lib/default.nix L1-L6](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/lib/default.nix#L1-L6),
[flake.nix L20-L33](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L20-L33)).

### hostSpec

`hostSpec` is a `types.submodule` with a `freeformType` of `attrsOf str` and
roughly 45 declared options, of which about 17 are `is*` or `use*` booleans:
`isWork`, `isServer`, `isDevelopment`, `isImpermanent`, `isRemote`, `isAdmin`,
`useYubikey`, `useWayland`, and so on
([modules/hosts/common/host-spec.nix L10-L14](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/modules/hosts/common/host-spec.nix#L10-L14),
[L95-L149](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/modules/hosts/common/host-spec.nix#L95-L149)).
Defaults chain off each other (`isLocal` defaults to `!isRemote`, `home`
defaults by `stdenv.isLinux`). Four assertions guard combinations, including
"isWork is true but no work attribute set is provided" and "primaryUsername
doesn't exist in list of users"
([L243-L266](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/modules/hosts/common/host-spec.nix#L243-L266)).
A host instantiates it in its own `host-spec.nix`, overriding with `mkForce`
([hosts/nixos/ghost/host-spec.nix L1-L33](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/nixos/ghost/host-spec.nix#L1-L33)).

The important design point: **`hostSpec` does not select modules.** It records
facts. Module selection is the literal import list. The flags are consumed
inside modules as conditionals, for example gating LLM provider tokens on
`osConfig.hostSpec.isDevelopment`
([home/common/optional/sops.nix L53](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/common/optional/sops.nix#L53)).
The two concerns are deliberately separate.

### How home relates to hosts

Home-manager is a host module, never standalone. There is no
`homeConfigurations` output anywhere in the flake.
`hosts/common/users/default.nix` builds `users.users.<name>` from
`hostSpec.users`, then wires home-manager for the same list, passing
`hostSpec` and `monitors` through `extraSpecialArgs` so home modules can read
host facts
([hosts/common/users/default.nix L90-L159](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/users/default.nix#L90-L159)).
Each user's imports are `home/<user>/<hostname>.nix`, `home/<user>/common`, and
`home/<user>/common/<platform>.nix`, each included only if the path exists
([L93-L134](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/users/default.nix#L93-L134)).
`home-manager.backupFileExtension = "bk"` is set globally in core
([hosts/common/core/default.nix L57](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/core/default.nix#L57)).

This coupling is load-bearing for validation: because home is inside the host,
building the host toplevel builds every user's home config. See section 4.

### How Darwin is handled

Structurally, not actually. `mkHost` takes an `isDarwin` flag and picks
`inputs.nix-darwin.lib.darwinSystem` or `lib.nixosSystem` and
`hosts/${if isDarwin then "darwin" else "nixos"}/${host}`
([flake.nix L34-L57](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L34-L57)).
Core builds `"${platform}Modules"` strings so the same imports resolve on both
platforms
([hosts/common/core/default.nix L12-L22](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/core/default.nix#L12-L22)),
and users get `/Users/<name>` versus `/home/<name>`
([hosts/common/users/default.nix L60](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/users/default.nix#L60)).
`modules/hosts/darwin/default.nix` is a `scanPaths` stub over an otherwise
empty directory
([modules/hosts/darwin/default.nix L4-L7](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/modules/hosts/darwin/default.nix#L4-L7)).
The dual-platform plumbing is real and reasonably clean. Nothing has ever been
plugged into it.

## 3. Per-App Config Mechanics

### programs.* dominates; home.file is rare

Counts over the 176 `.nix` files on `dev`:

| Construct | Occurrences |
| --- | ---: |
| `programs.` | 59 |
| `services.` | 76 |
| `home.file` | 11 |
| `home.activation` | 1 |
| `xdg.configFile` | 0 |
| `mkOutOfStoreSymlink` | 0 |
| `onChange` | 0 |
| `lib.hm.dag.entryAfter` / `entryBefore` | 0 |
| `system.defaults`, `launchd`, `homebrew` module, `casks`, `masApps` | 0 |

The one activation block rebuilds the `bat` syntax cache, written as a raw
`{ after; before; data; }` attrset rather than a DAG helper
([home/common/core/bat.nix L23-L31](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/common/core/bat.nix#L23-L31)).
`home.file` uses are all whole-file: a static `.screenrc`, a `.editorconfig`,
a zellij `config.kdl` and `layouts` directory, an avatar PNG pulled from the
`nix-assets` input
([home/ta/common/default.nix L4-L7](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/ta/common/default.nix#L4-L7)).
zsh uses the upstream module with a custom `dotDir` under XDG
([home/common/core/zsh/default.nix L30-L34](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/common/core/zsh/default.nix#L30-L34)),
which is the same construct our concept map row 35 proposes.

### Files the app also writes

Barely managed, and where it is, the answer is a manual loop rather than a
merge.

The clear case is Noctalia, a Wayland desktop shell. Its settings are declared
in Nix through the app's own home module,
`programs.noctalia-shell.settings` and `.pluginSettings`, running to several
hundred lines
([home/common/optional/desktops/noctalia.nix L15-L61](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/common/optional/desktops/noctalia.nix#L15-L61)).
The app also writes `~/.config/noctalia/settings.json` itself. The author's
answer is three `just` recipes: diff live JSON against what the running shell
reports, dump the shell's state, and convert that state back to Nix through
`json2nix`
([justfile L242-L255](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L242-L255)).
That is a human re-derivation loop, not reconciliation. It is Problem A,
unsolved, in a repo that has been running for two and a half years.

Two custom home modules generate app config from typed options:
`programs.copyq` writes an INI through `lib.generators.toINI`
([modules/home/copyq.nix L25-L39](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/modules/home/copyq.nix#L25-L39)),
and `pi-model-config` writes `~/.pi/agent/models.json` from
`pkgs.formats.json`, deriving the model list by reaching into another host's
config with `inputs.self.nixosConfigurations.<name>.config.services.llama-swap.settings.models`
([modules/home/pi-model-config.nix L21-L48](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/modules/home/pi-model-config.nix#L21-L48)).
The pi module is whole-file `home.file` ownership of a file the `pi` agent also
writes, with no merge and no `force`. On a machine where pi has already written
that path, the first switch would hit home-manager's clobber check. Unverified
whether the author has hit it; `backupFileExtension = "bk"` would silently
absorb it.

### Agent CLIs

The repo installs claude-code, claude-agent-acp, codex, codex-acp, crush,
gemini-cli, and pi-coding-agent as bare packages and manages the configuration
of exactly none of them
([home/common/optional/llm/agents.nix L7-L20](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/common/optional/llm/agents.nix#L7-L20)).
The one exception, `pi-model-config`, is generated model routing, not settings.
There is also a typed `programs.llm` module for the `llm` CLI, adapted from
another person's dotfiles
([modules/home/llm.nix L1-L41](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/modules/home/llm.nix#L1-L41)).

### macOS defaults, casks, MAS, taps, launchd

None of it exists, on either branch. See section 1.

### Secrets

sops-nix in two layers, with the ciphertext in a separate private repo
consumed as a flake input rather than committed to the public one
([flake.nix L284-L287](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L284-L287)).

Host layer. `defaultSopsFile` resolves to `<nix-secrets>/sops/<hostname>.yaml`,
`validateSopsFiles = false`, and the age identity is derived automatically from
the machine's own SSH host key via `sops.age.sshKeyPaths`
([hosts/common/core/sops.nix L10-L22](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/core/sops.nix#L10-L22)).
User login passwords come from `shared.yaml` with `neededForUsers = true` so
they decrypt into `/run/secrets-for-users` before user creation
([L33-L42](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/core/sops.nix#L33-L42)),
which is what lets `mutableUsers = false`
([hosts/common/users/default.nix L86-L88](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/users/default.nix#L86-L88)).

The neat trick: the *user's* age key is itself a sops secret, decrypted by the
host key and written to `~/.config/sops/age/keys.txt`
([hosts/common/core/sops.nix L47-L56](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/core/sops.nix#L47-L56)),
with a comment explaining that this "allows home-manager secrets to work
without manually copying over the age key"
([L29-L32](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/core/sops.nix#L29-L32)).
The home layer then reads that path
([home/common/optional/sops.nix L38-L45](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/common/optional/sops.nix#L38-L45))
and adds host-conditional secrets: LLM tokens when `isDevelopment`, u2f and SSH
keys when `useYubikey`
([L19-L36](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/common/optional/sops.nix#L19-L36),
[L53-L68](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/common/optional/sops.nix#L53-L68)).

New-host bootstrap: generate the age key from the new host's SSH host key with
`ssh-to-age`, add it as an anchor in `nix-secrets/.sops.yaml`, run
`sops updatekeys`, push, then `nix flake lock --update-input nix-secrets`
([docs/addnewhost.md L208-L253](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/docs/addnewhost.md#L208-L253),
[L284-L295](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/docs/addnewhost.md#L284-L295)).
The anchor and creation-rule edits are scripted as `just sops-*` recipes
([justfile L115-L164](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L115-L164)),
with `just rekey` running `sops updatekeys` across every file and pushing
([L122-L127](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L122-L127)).

### Root work per switch

NixOS activation is root by construction, so the question does not bite the way
it does under nix-darwin. Two `system.activationScripts` exist. One chowns
`~/.config` after sops writes the age key into it as root, with a comment
noting that root-created parent directories otherwise break home-manager
([hosts/common/core/sops.nix L80-L92](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/core/sops.nix#L80-L92));
the other cleans up dead wifi state. Separately, `nix.extraOptions` does an
`!include` of the decrypted GitHub token file so `nix flake update` is not rate
limited, guarded by `config ? "sops"`
([modules/hosts/common/nix.nix L47-L49](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/modules/hosts/common/nix.nix#L47-L49)).
That feeds a runtime secret to the Nix daemon without a store path, which is a
pattern worth stealing.

## 4. Testing And CI

There is no CI. No `.github/` directory exists. The roadmap says so out loud:
"Re-enable CI pipeline. Deferred for now, dealing with nix-secrets is too much
hassle"
([docs/TODO.md L145](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/docs/TODO.md#L145)),
under a heading whose sibling item, "Write bats tests for helpers.sh", is
checked off
([L143-L147](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/docs/TODO.md#L143-L147)).

`checks/` on `dev` is one file exposing one check. `pre-commit-check` comes
from `introdusLib.checks.mkPreCommitHooks` with two local additions,
`forbid-submodules` and `destroyed-symlinks`
([checks/default.nix L13-L36](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/checks/default.nix#L13-L36)).
`checks/unwanted-builtins.sh` sits next to it, a five-line ripgrep that flags
non-allowlisted `builtins` calls
([checks/unwanted-builtins.sh L1-L6](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/checks/unwanted-builtins.sh#L1-L6)),
and nothing in the tree references it. On the frozen `darwin` branch the
corresponding hook was declared with `enable = false`
([darwin@95a9d14 checks/default.nix L78-L85](https://github.com/EmergentMind/nix-config/blob/95a9d14d950ca84f3e415b08ab89b81a7e3f2ee7/checks/default.nix#L78-L85)).

The `darwin` branch had one real behavior test:
`checks.bats-test`, a `pkgs.runCommand` running `bats tests` with bats, yq-go,
and inetutils on the path
([darwin@95a9d14 checks/default.nix L8-L18](https://github.com/EmergentMind/nix-config/blob/95a9d14d950ca84f3e415b08ab89b81a7e3f2ee7/checks/default.nix#L8-L18)),
covering the sops key-anchor and creation-rule helpers with fixture `.sops.yaml`
files
([darwin@95a9d14 tests/sops.bats L9-L66](https://github.com/EmergentMind/nix-config/blob/95a9d14d950ca84f3e415b08ab89b81a7e3f2ee7/tests/sops.bats#L9-L66)).
On `dev` that check is gone, along with `tests/` and `scripts/`, because the
helper functions moved into the `introdus` input. The behavior test did not
follow them.

So the effective coverage is whatever `nix flake check` gives. Because
home-manager is a host module (section 2), building
`nixosConfigurations.*.config.system.build.toplevel` for the 9 configurations
also builds every user's home config. That is genuine coverage and it is free.
It is also the entire test surface. `just check` runs it, plus a second
`nix flake check` inside `nixos-installer/`, which does not exist on `dev`
([justfile L30-L43](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L30-L43)).
Both invocations pass `--impure` and `REPO_PATH=$(pwd)`. Two other recipes
reference a `locks/<host>.lock` file through `--reference-lock-file`
([justfile L86](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L86),
[L240](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L240));
there is no `locks/` directory. The one post-switch check is `just check-sops`,
which shells out to an `introdus` binary
([justfile L20-L22](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L20-L22),
[L70-L73](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L70-L73)).

**What a closure-only test surface misses, demonstrated.**
`modules/home/copyq.nix` contains

```nix
"${configDir}/copyq.conf" = lib.mkIf (cfg.settings != { }) lib.generators.toINI { } cfg.settings;
```

([modules/home/copyq.nix L36-L39](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/modules/home/copyq.nix#L36-L39)).
`lib.mkIf` takes two arguments; this applies it to four. The module is imported
into every user's home config through `modules/home`, but no host sets
`programs.copyq.enable`, so the `mkIf cfg.enable` body is never forced and the
expression never evaluates. `nix flake check` is green. Closure builds only
cover the code paths some host turns on.

Microvms are not tests. They are agent sandboxes
([README L72](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/README.md#L72),
[microvms/README L1-L12](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/microvms/README.md#L1-L12)),
built as part of the host that hosts them via `lib.custom.microvms.mkMicrovms`
([hosts/nixos/ghost/microvms/default.nix L8-L11](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/nixos/ghost/microvms/default.nix#L8-L11)).
They mirror the core/optional shape in a separate `microvms/` tree, and note
that "Seems sops doesn't work, so we inject them at runtime from the host"
([microvms/hosts/common/core/default.nix L1-L8](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/microvms/hosts/common/core/default.nix#L1-L8)).
They do add build coverage for a second, minimal composition of the same
modules, which is a side benefit worth naming.

There is no build matrix. `systems = [ "x86_64-linux" ]`
([flake.nix L135-L137](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L135-L137)).

## 5. Compare And Contrast With Our Target-State Doc

### App modules plus roles, versus core/optional

Our doc's central claim is that the unit should be the app module, roles import
app modules, and hosts import roles. This repo is the clearest available
**alternative**, not evidence for or against. Its unit is a file in a
directory. Its composition is a literal import list per host, written twice,
once host-side and once home-side
([hosts/nixos/ghost/default.nix L26-L57](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/nixos/ghost/default.nix#L26-L57),
[home/ta/ghost.nix L3-L30](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/ta/ghost.nix#L3-L30)).
Nothing asserts that the two lists agree.

Two changes our doc should make.

First, soften the "this is how the ecosystem composes machines" framing. SrvOS
and nixos-hardware, two of the three exemplars our doc cites, are libraries of
importable modules, which is what `hosts/common/optional/` already is. A
643-star, two-and-a-half-year repo picked paths over options and has not
reversed. The reason to prefer app modules in *our* repo is specific and local:
22 files an app also writes, 20 cask gates, and the eleven-to-thirteen files
per app that our doc measured. State that as the reason instead of appealing to
general practice.

Second, add `hostSpec` as a third position on the machine-type question. Our
doc says "Nothing reads a `machine_type` value at evaluation time" and that
`work`, `personal`, `homelab`, `ci` "survive as role presets and as vocabulary."
This repo separates the two concerns cleanly: a typed, asserted record of host
facts that modules branch on, plus explicit imports for composition
([modules/hosts/common/host-spec.nix L10-L14](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/modules/hosts/common/host-spec.nix#L10-L14),
[home/common/optional/sops.nix L53](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/common/optional/sops.nix#L53)).
Keeping the record and dropping only the resolver is a smaller, safer target
than dropping both.

### The "what disappears" table

| Our row | Verdict | Evidence |
| --- | --- | --- |
| Group union, dedupe, unknown-group validation to `assertions` | Supports | Four `hostSpec` assertions, one of which catches a real class of error ([host-spec.nix L243-L266](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/modules/hosts/common/host-spec.nix#L243-L266)) |
| `features.tmpl` resolver and layered `machines*.toml` gone | Supports the outcome, not the mechanism | No data layer exists; shared values come from a flake input through `nix-secrets.mkSecrets` ([flake.nix L35](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L35)) |
| First-run prompts and `machines_local` gone, host policy committed | Supports | Every host commits its policy in `host-spec.nix`; no local-override mechanism exists |
| `run_onchange_` hash lines gone, `onChange` carries its own inputs | No evidence | Zero `onChange` uses in 176 files |
| Brewfile renderer, plist stubs, quit guard, drift banner, retired ledger, uv hook | No evidence | macOS or chezmoi specific; none present |

One caveat on the committed-policy row. Purity is claimed but not held: both
`nix flake check` invocations pass `--impure` and an environment variable
([justfile L32-L43](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L32-L43)).
Committing host policy did not buy a pure evaluation here.

### The per-app ownership table

Nine apps in our table. This repo manages zero of them, and installs six of the
same agent CLIs as bare packages
([home/common/optional/llm/agents.nix L7-L20](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/common/optional/llm/agents.nix#L7-L20)).
Our table stands unchallenged, and it also stands unsupported. Add one sentence
to it: no surveyed repo manages an agent-CLI configuration file, so the
managed-drop-in and system-layer plan for Claude Code and Codex has no prior
art to copy and should be prototyped on one app before the design is committed.

### Problem A, files the app also writes

Supports our framing, and adds a data point about what people actually do. The
Noctalia loop is declare-in-Nix plus diff-by-hand plus regenerate-by-hand
([noctalia.nix L15-L61](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/common/optional/desktops/noctalia.nix#L15-L61),
[justfile L242-L255](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L242-L255)).
The `pi` module is whole-file ownership of an app-written path with no
mitigation
([pi-model-config.nix L44-L48](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/modules/home/pi-model-config.nix#L44-L48)).
Neither is a solution. Our three-tier design is more ambitious than anything
here, which is a reason to prototype tier 3 early rather than assume it.

### Problem B, the MDM-managed work Mac

No evidence at all. No Darwin host, no MDM, no elevation flow. `hostSpec.isWork`
exists and feeds one assertion, and no host in the tree sets it
([host-spec.nix L115-L119](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/modules/hosts/common/host-spec.nix#L115-L119),
[L249-L252](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/modules/hosts/common/host-spec.nix#L249-L252)).
This is the single largest reason the repo's relevance to us is capped.

### Problem C, secrets without store leakage

The strongest section of the survey. Three concrete corrections to our doc.

1. **Add a fourth row to the Problem C table: sops ciphertext in a separate
   private repo consumed as a flake input.** Our table rejects sops-nix and
   agenix partly because "encrypted license blobs would live in a public repo,
   a policy shift from 'refs only'." That objection is avoidable. This repo
   keeps its public config public and its ciphertext in `nix-secrets`
   ([flake.nix L284-L287](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L284-L287)),
   and we already have the private-repo pattern in ADR 0011. The cost this repo
   pays for it is that CI became too hard and was switched off
   ([docs/TODO.md L145](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/docs/TODO.md#L145));
   that cost belongs in the row.
2. **Record the key-bootstrap answer.** Our table says sops-nix "adds an
   unencrypted age key on every machine" without saying how it gets there. Here
   the host identity is derived from the machine's existing SSH host key
   ([sops.nix L19-L22](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/core/sops.nix#L19-L22)),
   and the user's age key is itself a host-key-decrypted secret written into
   `~/.config/sops/age/keys.txt`
   ([L47-L56](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/core/sops.nix#L47-L56)).
   The key is still plaintext on disk, but no human copies it anywhere. That
   changes the operational objection materially.
3. **Note that this model does not answer our actual question.** It works
   because every host is a machine the author roots and rebuilds. There is no
   biometric session, no 1Password, no interactive-Mac constraint. It does not
   tell us whether `op read` in activation is viable, and it does not tell us
   whether 1Password service accounts can read our vaults (our open question 5).
   It does offer a credible unattended path for the homelab mini that skips
   1Password entirely, which is worth pricing against opnix.

### The test surface

The brief expected `checks/` to be the closest thing to what our doc proposes.
It is not; it is a pre-commit wrapper (section 4). The useful evidence is
negative and specific.

- **Our "`nix flake check` is narrower than it looks" bullet needs sharpening.**
  It is true for us and false here. This repo gets 9 host closures plus three
  users' home configs with no explicit `checks` entries, purely because
  home-manager is a host module
  ([hosts/common/users/default.nix L90-L159](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/users/default.nix#L90-L159)).
  Our hosts would all be `darwinConfigurations`, which flake check does not
  touch. Reword the bullet to say the gap is Darwin-specific, and that the
  explicit `checks.aarch64-darwin.<host>` entries are the price of the platform,
  not of the design.
- **Add an enumeration check, not just a closure build.** Our doc says "Every
  role imports the app modules it should." A closure build cannot show that. The
  dormant `lib.mkIf` arity error in `modules/home/copyq.nix`
  ([L36-L39](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/modules/home/copyq.nix#L36-L39))
  survives a green `nix flake check` because no host enables it. Our
  `checks/apps/` should assert the option-to-module mapping directly, and
  should build a host that enables everything.
- **Behavior tests die in refactors.** The bats suite existed
  ([darwin@95a9d14 checks/default.nix L8-L18](https://github.com/EmergentMind/nix-config/blob/95a9d14d950ca84f3e415b08ab89b81a7e3f2ee7/checks/default.nix#L8-L18)),
  then the code under test moved into another repo and the test did not follow.
  Our doc says "the behavioral zsh tests survive as they are." They survive only
  if the migration keeps them wired to a runner. Say that.
- **Solve CI under a private input before depending on one.** Our concept-map
  row 14 already flags that CI needs `--override-input dotfiles-private` with a
  stub. This repo is the cautionary case where that was never solved and CI was
  turned off instead
  ([docs/TODO.md L145](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/docs/TODO.md#L145)).
  Promote row 14's stub idea from a note to a prototype task.

### Open questions this repo touches

| Q | Effect | Why |
| ---: | --- | --- |
| 5 (1Password service accounts) | Reframed | A viable unattended secrets path exists that involves no 1Password; price it against opnix for the homelab mini |
| 6 (machine-local override) | Supports elimination | No local override exists here and nothing wants one, though purity still needs `--impure` |
| 1, 3, 4, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 | No evidence | All macOS, MDM, Homebrew, Raycast, or app-layer specific |

Two questions this survey adds.

17. How does CI evaluate a flake whose secrets or overlays live in a private
    input? This repo's answer was to stop running CI. Decide ours before we
    make a private input load-bearing.
18. Do we keep a typed machine-facts record after adopting app modules? Our doc
    currently implies the record disappears with the resolver. `hostSpec`
    suggests keeping the record and dropping only the resolver.

## 6. What To Take, What To Avoid, Relevance

### Take

- **The `hostSpec` shape.** A freeform submodule of typed host facts with
  assertions, separate from module selection
  ([host-spec.nix L10-L14](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/modules/hosts/common/host-spec.nix#L10-L14),
  [L243-L266](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/modules/hosts/common/host-spec.nix#L243-L266)).
  This is the honest successor to the parts of `machines.toml` that are facts
  rather than selections.
- **Secrets as a private flake input**, with host age derived from the SSH host
  key and the user's age key bootstrapped from the host key
  ([flake.nix L284-L287](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L284-L287),
  [hosts/common/core/sops.nix L19-L22](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/core/sops.nix#L19-L22),
  [L47-L56](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/core/sops.nix#L47-L56)),
  and a scripted new-host key ritual
  ([justfile L115-L164](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L115-L164)).
- **`hostSpec` through `extraSpecialArgs`** so home modules read host facts as
  `osConfig.hostSpec.*`
  ([hosts/common/users/default.nix L101-L115](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/users/default.nix#L101-L115)).
  Cleanly solves "the home layer needs to know the machine type."
- **Coupling home into the host so validation covers both.** We cannot use the
  same mechanism on Darwin, but we should replicate the property with explicit
  `checks` entries and make that a rule, not an afterthought.
- **`nix.extraOptions` `!include` of a decrypted token file**
  ([modules/hosts/common/nix.nix L47-L49](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/modules/hosts/common/nix.nix#L47-L49)).
  Feeds Nix itself a runtime secret without a store path.
- **The "core is a hard rule" line**
  ([README L104-L105](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/README.md#L104-L105)).
  Cheap discipline that keeps the base honest, and it transfers to a role-based
  layout unchanged.

### Avoid

- **Local `path:///` flake inputs**
  ([flake.nix L280](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L280),
  [L293](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L293)).
  They make the repo unbuildable by anyone else and drag `--impure` into the
  check command. Whatever we do with the private overlay, keep it fetchable.
- **Letting the check surface collapse to "the closure builds."** The dormant
  `copyq` arity error is the proof
  ([modules/home/copyq.nix L36-L39](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/modules/home/copyq.nix#L36-L39)).
- **Dropping behavior tests when the code under test moves.** The bats suite
  vanished between `darwin` and `dev` with no replacement.
- **Bumping five inputs on every rebuild**
  ([justfile L9-L18](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L9-L18)).
  This is chezmoi's `refreshPeriod` problem with extra steps and no review gate.
  Our doc's "one reviewed lock bump" is the better target.
- **Dead references in the task runner and docs.** `nixos-installer/`
  ([justfile L38](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L38)),
  `locks/`
  ([L86](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L86),
  [L240](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L240)),
  an orphaned `checks/unwanted-builtins.sh`, and an onboarding doc that still
  tells you to hand-edit `nixosConfigurations` and `homeConfigurations` in
  `flake.nix`
  ([docs/addnewhost.md L17-L57](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/docs/addnewhost.md#L17-L57))
  years after `mkHostConfigs` and `readHosts` automated it
  ([flake.nix L114-L122](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L114-L122)).
  The doc carries its own FIXME admitting it
  ([docs/addnewhost.md L5-L6](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/docs/addnewhost.md#L5-L6)).

### Relevance: 2 of 5

Reasons, in order of weight.

1. It is a NixOS repo with no Darwin host on either branch. The two constructs
   that dominate our risk, macOS `defaults` and Homebrew, appear zero times.
2. It manages no file that an app also writes, so it confirms Problem A exists
   and contributes nothing toward solving it.
3. It has no MDM host and no elevation flow, so Problem B gets nothing.
4. Its composition model is a genuine alternative worth knowing, but it is an
   alternative that works because the repo does not carry our per-app cost. It
   is not a model we should adopt.
5. It earns the two points on secrets architecture, which is transferable and
   should change our Problem C table, and on the negative lessons about test
   surface and CI under a private input, which should change our test section.

## 7. Scorecard Against The Concept Map

Rows with evidence. Rows 2, 3, 9, 11, 12, 13, 15, 17, 18, 22, 23, 25, 26, 27,
29, 30, 31, 32, 33, 39, 41 have no evidence in this repo and are omitted.

| Row | Verdict | Note (five words) | Evidence |
| ---: | --- | --- | --- |
| 1 | Supports | Eleven uses, all whole-file | [home/ta/common/default.nix L4-L7](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/ta/common/default.nix#L4-L7) |
| 4 | Alternative | Never used; store links only | Zero `mkOutOfStoreSymlink` in 176 files |
| 5 | Alternative | Import lists, not resolved features | [hosts/nixos/ghost/default.nix L26-L57](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/nixos/ghost/default.nix#L26-L57) |
| 6 | Supports | Host directories enumerate flake outputs | [flake.nix L114-L122](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L114-L122) |
| 7 | Supports | Committed policy, but impure anyway | [hosts/nixos/ghost/host-spec.nix L1-L33](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/nixos/ghost/host-spec.nix#L1-L33); [justfile L32-L37](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L32-L37) |
| 8 | Alternative | Per-host mkForce, no layer stack | [hosts/nixos/ghost/host-spec.nix L5-L29](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/nixos/ghost/host-spec.nix#L5-L29) |
| 10 | Supports | Idiomatic lib.attrValues inherit blocks throughout | [home/common/core/default.nix L16-L48](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/common/core/default.nix#L16-L48) |
| 14 | Supports, with warning | Private input works; CI died | [flake.nix L284-L287](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L284-L287); [docs/TODO.md L145](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/docs/TODO.md#L145) |
| 16 | Alternative | Path lists replace ignore gates | [home/ta/ghost.nix L12-L28](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/ta/ghost.nix#L12-L28) |
| 19 | Alternative | Zero onChange; never needed one | Zero `onChange` in 176 files |
| 20 | Supports weakly | One idempotent activation block only | [home/common/core/bat.nix L23-L31](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/common/core/bat.nix#L23-L31) |
| 21 | Alternative | Raw after/before attrset, no DAG | [home/common/core/bat.nix L25-L27](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/common/core/bat.nix#L25-L27) |
| 24 | Supports | Noctalia diffed by hand instead | [justfile L242-L255](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L242-L255) |
| 28 | Alternative | systemd user timers, not launchd | [home/common/core/timers/trash-empty.nix L4-L24](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/common/core/timers/trash-empty.nix#L4-L24) |
| 34 | Alternative | nixpkgs runtimes; no mise, no latest | Zero `mise` references; [home/common/core/default.nix L16-L48](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/common/core/default.nix#L16-L48) |
| 35 | Supports | dotDir set to XDG path | [home/common/core/zsh/default.nix L30-L34](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/common/core/zsh/default.nix#L30-L34) |
| 36 | Supports | preferXdgDirectories plus xdg.configHome interpolation | [home/common/core/default.nix L50-L52](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/home/common/core/default.nix#L50-L52) |
| 37 | Alternative | sops ciphertext in private input | [flake.nix L284-L287](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/flake.nix#L284-L287); [hosts/common/core/sops.nix L15-L27](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/core/sops.nix#L15-L27) |
| 38 | Supports the gap | Manual json-diff recipes for drift | [justfile L242-L245](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/justfile#L242-L245) |
| 40 | Supports | backupFileExtension set globally to bk | [hosts/common/core/default.nix L56-L57](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/hosts/common/core/default.nix#L56-L57) |
| 42 | Contradicts our optimism | No CI; private input too hard | [docs/TODO.md L145](https://github.com/EmergentMind/nix-config/blob/a8ba4f4b6746466119b3c9f62befac97b9427cd5/docs/TODO.md#L145); no `.github/` directory |
