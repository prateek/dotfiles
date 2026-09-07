---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-04
updated: 2026-09-04
related:
  - ../nix-target-state-research.md
  - ../nix-migration-research.md
status_detail: "Agent survey of ryan4yin/nix-config at 324e5d8820c60211cff23ccc856c63adcf360cd6, compared with the Nix target-state doc. Unreviewed."
---

# Survey: ryan4yin/nix-config

## Method

Snapshot: `ryan4yin/nix-config` at commit
`324e5d8820c60211cff23ccc856c63adcf360cd6`, which was the `main` head on
2026-09-04. The tarball was fetched into `/tmp/nix-surveys` and read locally.
Every permalink below points at that sha.

Read in full or in part: `README.md`, `flake.nix`, `flake.lock`, `outputs/`
(`default.nix`, `README.md`, and the whole `aarch64-darwin/` tree), `lib/`,
`vars/default.nix`, `hosts/README.md`, `hosts/darwin-fern/`,
`hosts/darwin-frieren/`, every file in `modules/darwin/`, `home/darwin/`,
selected files in `home/base/`, `home/linux/gui/base/immutable-file.nix`, the
secrets tree (`darwin.nix`, `nixos.nix`, `README.md`), `Justfile`, `utils.nu`,
both files in `.github/workflows/`, root `AGENTS.md`, and
`agents/install-rules.py`. Upstream home-manager
`modules/programs/zed-editor.nix` was also read at
`ec1a8fdf74ed3f276148ee106299a2ba0e65d51f`, the rev this repo's lock pins.

Compared against [nix-target-state-research.md](../nix-target-state-research.md),
the Options and Sizing sections of
[nix-migration-research.md](../nix-migration-research.md), and
[chezmoi-architecture.md](../../references/chezmoi-architecture.md).

Unverified: nothing was built, evaluated, or switched. Every claim about
activation behavior comes from reading this repo's source and the upstream
modules it imports, not from running them.

## 1. What It Is

| Fact | Value |
| --- | --- |
| Description | "My nix config for both desktops(NixOS+macOS) and homelab servers(NixOS)" (repo metadata) |
| Stars / forks | 2,044 / 100 at the snapshot |
| Commits on `main` | 2,300 |
| `.nix` files | 302 |
| Platforms | NixOS on x86_64 and aarch64, macOS on aarch64, plus KubeVirt and k3s image outputs |
| macOS hosts | 2 |
| Recent activity | the last 100 commits span 2026-07-17 to 2026-09-04 |

The author maintains a large fleet. `outputs/README.md` states the motive for
the structure directly: "The number of my machines has grown to more than 20,
and the increase in scale has shown signs of" strain
([outputs/README.md#L5-L10](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/outputs/README.md#L5-L10)).
The host inventory lists four `idols` workstations, four homelab servers, and
two macOS laptops
([hosts/README.md#L13-L38](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/hosts/README.md#L13-L38)).

The two macOS hosts matter for us. `fern` is an M2 13-inch 16GB laptop for
"Personal Use". `frieren` is an M4 Pro 14-inch 48GB laptop for "Work Use"
([hosts/README.md#L24-L27](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/hosts/README.md#L24-L27)).
So this repo does carry a personal and a work Mac in one flake.

Lock bumping is manual and committed. `just up` runs
`nix flake update --commit-lock-file`, and `just upp <input>` bumps one input
([Justfile#L26-L35](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/Justfile#L26-L35)).
Thirteen of the last 100 commits are `flake.lock: Update`. There is no bot and
no scheduled workflow; the only two workflows are an eval-test job and a Gitee
mirror.

## 2. Composition

The flake is one line. `outputs = inputs: import ./outputs inputs;` delegates
everything to a directory
([flake.nix](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/flake.nix)).
`outputs/<system>/default.nix` uses haumea to load every file under `src/` and
merges the per-host attribute sets
([outputs/aarch64-darwin/default.nix#L10-L22](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/outputs/aarch64-darwin/default.nix#L10-L22)).
haumea is pinned at v0.2.2
([flake.nix#L112-L113](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/flake.nix#L112-L113)).

Each host file is short and explicit. The whole composition for `fern` is a
list of paths:

| Layer | Value for `fern` |
| --- | --- |
| Secrets | `secrets/darwin.nix` |
| Shared Darwin | `modules/darwin` |
| Host | `hosts/darwin-fern` |
| Inline | `{ modules.desktop.fonts.enable = true; }` |
| Home | `home/hosts/darwin/darwin-fern.nix` |

([outputs/aarch64-darwin/src/fern.nix#L16-L34](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/outputs/aarch64-darwin/src/fern.nix#L16-L34))

Below that, composition is directory scanning, not options.
`modules/darwin/default.nix` is five lines: `imports = (mylib.scanPaths ./.) ++
[ ../base ];`
([modules/darwin/default.nix#L1-L6](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/modules/darwin/default.nix#L1-L6)).
`home/darwin/default.nix` is the same shape with four extra base directories
([home/darwin/default.nix#L14-L19](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/home/darwin/default.nix#L14-L19)).
`scanPaths` and `relativeToRoot` are the only composition helpers
([lib/default.nix#L15-L16](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/lib/default.nix#L15-L16)).

The typed-options layer is thin. Across 302 `.nix` files there are 14
`mkEnableOption` uses in 7 files, 3 `mkOption` uses in 1 file, and `assertions`
appears in exactly one file, `secrets/nixos.nix`. The single `mkOption` file is
`home/linux/gui/base/immutable-file.nix`, whose own header says "TODO not used
yet, need to test it"
([home/linux/gui/base/immutable-file.nix#L9-L18](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/home/linux/gui/base/immutable-file.nix#L9-L18)).

Machine identity is split three ways. Person-level facts live in `vars/`:
username, email, SSH public keys, and an `initialHashedPassword`, all committed
in the clear
([vars/default.nix#L3-L33](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/vars/default.nix#L3-L33)).
Host identity lives in a 14-line host module that sets only hostname,
computerName, and NetBIOSName
([hosts/darwin-frieren/default.nix#L1-L14](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/hosts/darwin-frieren/default.nix#L1-L14)).
Everything else is decided by which directories the host file imports.

The macOS hosts differ from the NixOS hosts in scope, not in mechanism. NixOS
hosts get hardware, disko, k3s, KubeVirt, and colmena deployment. macOS hosts
get `nix-darwin.lib.darwinSystem` with home-manager attached as a Darwin module
when `home-modules` is non-empty
([lib/macosSystem.nix#L15-L41](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/lib/macosSystem.nix#L15-L41)).

The most useful finding here is negative. There is no work versus personal
role. `fern` and `frieren` import an identical Darwin module set and an
identical home set; the only committed difference between the two host modules
is the hostname string. The "Work Use" machine carries the same Homebrew list,
the same macOS defaults, and the same secrets as the personal one.

## 3. Per-App Config Mechanics

### programs.* versus home.file versus activation

`programs.*` is the default. Shell, git, gnupg, and the editor all go through
home-manager program modules. `home.file` is used for the leftovers.

Activation is nearly unused. There are exactly two `home.activation` sites in
the repo, and one of them is the untested `immutable-file` module. The real one
deletes a file so home-manager can win:

```nix
home.activation.removeExistingGitconfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
  rm -f ${config.home.homeDirectory}/.gitconfig
'';
```

([home/base/core/git.nix#L9-L15](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/home/base/core/git.nix#L9-L15))

There are zero uses of `home.file.<name>.onChange` in the entire repo. Our doc
treats `onChange` as the natural successor to `run_onchange_`; this author never
reaches for it.

`system.activationScripts` is used five times, once on Darwin outside the
secrets module: a `lib.mkBefore` block that exports Homebrew mirror variables
before `brew bundle` runs
([modules/darwin/apps.nix#L83-L87](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/modules/darwin/apps.nix#L83-L87)).

### Files the app also writes

This is the important part, and the answer is surrender rather than merging.
Three sites use `force = true`, and the Darwin one is explicit about why:

```nix
home.file."Library/Rime" = {
  source = "${pkgs.flypy-squirrel}/share/rime-data";
  recursive = true;
  # overwrite possible existing data dynamically generated by squirrel
  force = true;
};
```

([home/darwin/rime-squirrel.nix#L4-L11](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/home/darwin/rime-squirrel.nix#L4-L11))

The other two are Linux: fcitx5 and `mimeapps.list`. In each case the app's own
writes are discarded on every switch.

Where the app's writes must survive, the file is not managed by Nix at all. Six
sites use `mkOutOfStoreSymlink` pointed at the live working copy under
`~/nix-config`, so the app edits the checkout directly. The Darwin one is
proxychains:

```nix
home.file.".proxychains/proxychains.conf".source =
  config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/home/darwin/proxy/proxychains.conf";
```

([home/darwin/proxy/default.nix#L11-L12](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/home/darwin/proxy/default.nix#L11-L12))

There is exactly one merge-into-a-live-file case, and it comes from upstream,
not from this repo. `programs.zed-editor.mutableUserSettings = true` is set here
([home/base/gui/zed-editor.nix#L5-L7](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/home/base/gui/zed-editor.nix#L5-L7)).
Upstream, that option defaults to `true`
([HM zed-editor.nix#L87-L94](https://github.com/nix-community/home-manager/blob/ec1a8fdf74ed3f276148ee106299a2ba0e65d51f/modules/programs/zed-editor.nix#L87-L94))
and swaps the store symlink for an activation block that reads the live file
with `json5 --as-json`, merges it with `jq -n`, and writes it back
([HM zed-editor.nix#L19-L30](https://github.com/nix-community/home-manager/blob/ec1a8fdf74ed3f276148ee106299a2ba0e65d51f/modules/programs/zed-editor.nix#L19-L30),
[#L313-L320](https://github.com/nix-community/home-manager/blob/ec1a8fdf74ed3f276148ee106299a2ba0e65d51f/modules/programs/zed-editor.nix#L313-L320)).
That is the same shape as our Python mergers, running at
`entryAfter [ "linkGeneration" ]`.

### macOS defaults

Typed `system.defaults` covers dock, finder, trackpad, NSGlobalDomain,
loginwindow, and the menu clock. Ten untyped domains go through
`CustomUserPreferences`
([modules/darwin/system.nix#L98](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/modules/darwin/system.nix#L98)).
`system.primaryUser` is set from `vars`
([modules/darwin/system.nix#L29](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/modules/darwin/system.nix#L29)),
Touch ID for sudo is on
([modules/darwin/system.nix#L24](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/modules/darwin/system.nix#L24)),
and there is a `system.keyboard.userKeyMapping` block
([modules/darwin/system.nix#L173](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/modules/darwin/system.nix#L173)).
The whole file is 183 lines, against our 143-line `defaults write` script plus
12 plist merge stubs. There is no quit-and-relaunch guard and no delete path.

### Homebrew, casks, MAS, taps

One 200-line module holds every GUI application
([modules/darwin/apps.nix](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/modules/darwin/apps.nix)).
It declares 3 MAS apps, 9 brews, and 26 casks. It declares no taps. Homebrew
itself is not managed: the file says "homebrew need to be installed manually,
see https://brew.sh"
([modules/darwin/apps.nix#L97](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/modules/darwin/apps.nix#L97)),
and `nix-homebrew` does not appear in `flake.nix` at all.

The cleanup policy is the maximal one:

```nix
onActivation = {
  autoUpdate = true;
  upgrade = false;
  # 'zap': uninstalls all formulae(and related files) not listed in the generated Brewfile
  cleanup = "zap";
};
```

([modules/darwin/apps.nix#L102-L107](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/modules/darwin/apps.nix#L102-L107))

Upgrades are deliberately not automatic. `just brew-upgrade` runs
`brew upgrade --cask --greedy` by hand
([Justfile#L145-L148](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/Justfile#L145-L148)).

Note the gap this creates. Roughly 26 casks are installed declaratively and
none of their configuration is managed. There are no per-app modules for the
GUI apps on Darwin.

### launchd

Both surfaces are used, each for logging or for a daemon rather than for a
user cron. `launchd.user.agents.gnupg-agent` adds log paths to the agent
nix-darwin already generates
([modules/darwin/security.nix#L18-L21](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/modules/darwin/security.nix#L18-L21)).
`launchd.daemons."activate-agenix"` is the root daemon that decrypts secrets
([secrets/darwin.nix#L15-L18](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/secrets/darwin.nix#L15-L18)).

### Secrets

agenix, not ragenix. The lock pins `ryantm/agenix` at
`4835b1dc898959d8547a871ef484930675cb47f1`; the `ryan4yin/ragenix` URL sits
commented out one line below
([flake.nix#L93-L97](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/flake.nix#L93-L97)).

Encrypted blobs live in a separate private repository, wired in as a
`flake = false` input over `git+ssh`
([flake.nix#L151](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/flake.nix#L151)).
The threat model is spelled out: files are keyed to every host's SSH host key
plus one offline recovery key, so "all secrets are still encrypted when
transmitted over the network and written to `/nix/store`"
([secrets/README.md#L6-L17](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/secrets/README.md#L6-L17)).

On Darwin the identity is the root-only host key:

```nix
age.identityPaths = [
  # Generate manually via `sudo ssh-keygen -A`
  "/etc/ssh/ssh_host_ed25519_key" # macOS, using the host key for decryption
];
```

([secrets/darwin.nix#L25-L28](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/secrets/darwin.nix#L25-L28))

Secrets are grouped by three mode and owner presets, `noaccess` (0000 root),
`high_security` (0500 root), and `user_readable` (0500 user)
([secrets/darwin.nix#L30-L44](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/secrets/darwin.nix#L30-L44)).
Two rough edges are documented in place. Publishing secrets into `/etc` "will
fail for the first time. cause it's running before activate-agenix"
([secrets/darwin.nix#L87-L89](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/secrets/darwin.nix#L87-L89)),
and a nushell `postActivation` block chowns them because "nix-darwin doesn't
support environment.etc.<name>.mode"
([secrets/darwin.nix#L102-L119](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/secrets/darwin.nix#L102-L119)).

There is no 1Password, no service-account token, and no user-session
dependency anywhere in the secrets path.

### Root per switch

Yes, the whole switch is root. The helper runs
`sudo -E ./result/sw/bin/darwin-rebuild switch --flake .#<name>`
([utils.nu#L59-L68](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/utils.nu#L59-L68)),
invoked by `just local` as a build followed by a switch
([Justfile#L163-L170](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/Justfile#L163-L170)).
The `-E` flag is worth noting: the author preserves the calling user's
environment across the privilege boundary.

Nix itself is Determinate, so nix-darwin's Nix management is turned off:
`nix.enable = false;` with the comment "Determinate uses its own daemon to
manage the Nix installation that conflicts with nix-darwin's native Nix
management"
([modules/darwin/nix-core.nix#L16-L18](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/modules/darwin/nix-core.nix#L16-L18)).
Upgrades are `sudo determinate-nixd upgrade`
([Justfile#L77-L81](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/Justfile#L77-L81)).
Access tokens reach Nix through an agenix path, not the store:
`nix.extraOptions = "!include ${config.age.secrets.nix-access-tokens.path}"`
([modules/darwin/nix-core.nix#L29-L31](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/modules/darwin/nix-core.nix#L29-L31)).

## 4. Testing And CI

The test surface is much smaller than the repo's size suggests.

`checks` is defined but not built. `checks.<system>.eval-tests` is a bare
boolean, `allSystems.${system}.evalTests == { }`, not a derivation, and
`darwinConfigurations` is never exposed under `checks`
([outputs/default.nix#L146-L180](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/outputs/default.nix#L146-L180)).
The other check is a cachix `git-hooks` bundle running nixfmt, typos, and
prettier
([outputs/default.nix#L160-L181](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/outputs/default.nix#L160-L181)).

CI is a single job on `ubuntu-latest` that runs `nix eval .#evalTests`. The
line above it is commented out with a one-word explanation:

```yaml
# stack overflow...
# nix eval .#checks --show-trace --print-build-logs --verbose
nix eval .#evalTests --show-trace --print-build-logs --verbose
```

([.github/workflows/flake_evaltests.yml#L37-L42](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/.github/workflows/flake_evaltests.yml#L37-L42))

There is no macOS runner, no build matrix, and no `nix flake check`. The other
workflow is a Gitee mirror.

Eval tests are `expr.nix` and `expected.nix` pairs loaded by
`haumea.lib.loadEvalTests`
([outputs/aarch64-darwin/default.nix#L28-L34](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/outputs/aarch64-darwin/default.nix#L28-L34)).
For Darwin there are exactly two. One asserts each host's home directory is
`/Users/${username}`
([outputs/aarch64-darwin/tests/home-manager/expr.nix#L13-L15](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/outputs/aarch64-darwin/tests/home-manager/expr.nix#L13-L15)).
The other asserts `networking.hostName` equals the attribute name
([outputs/aarch64-darwin/tests/hostname/expr.nix#L5-L7](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/outputs/aarch64-darwin/tests/hostname/expr.nix#L5-L7)).

The author's own assessment is candid. Eval tests "ensure that some attributes
are correctly set for each NixOS host(not Darwin)" and the section is annotated
"TODO: More Tests!" The NixOS integration tests are "WIP: not working yet", and
one listed blocker is that "Cannot test the whole host, because my host relies
on its unique ssh host key to decrypt its agenix secrets"
([outputs/README.md#L31-L55](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/outputs/README.md#L31-L55)).

Nothing Darwin-specific runs in CI. Darwin validation is a local
`just local`, which builds then switches on the machine itself.

## 5. Compare And Contrast With Our Doc

### App-module-plus-roles versus haumea directory convention

Our doc proposes a composition where per-app modules expose typed options and
roles select them. This repo does the directory half and skips the typed half
almost entirely. Composition is `mylib.scanPaths` plus an explicit
`map mylib.relativeToRoot [...]` per host
([outputs/aarch64-darwin/src/fern.nix#L16-L34](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/outputs/aarch64-darwin/src/fern.nix#L16-L34),
[modules/darwin/default.nix#L1-L6](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/modules/darwin/default.nix#L1-L6)).
Fourteen `mkEnableOption` uses across 302 files is not a typed-option
architecture.

This is evidence that the plain-imports half carries most of the weight at
scale, and that a rich option layer is optional rather than required. Our doc
should keep the app-module-plus-roles target but stop implying the typed layer
is what makes it work. Directory convention plus one explicit import list per
host is the load-bearing part.

The one place typed options do appear is worth copying: role-gated secret
namespaces behind `mkEnableOption`, with `assertions` in the same file
(`secrets/nixos.nix`, the only file in the repo with assertions).

### The "what disappears" table

Two rows come out differently.

`run_onchange_` does not become `onChange`. It becomes nothing. There are zero
`onChange` uses in this repo, and one `home.activation` block in real use. Our
table says `run_onchange_` is eliminated as a primitive because derivations and
`onChange` carry their own inputs. That is true in principle and, in practice
here, the whole class of work simply does not exist because the repo has no
codegen, no plugin reconciler, and no post-install steps. Our repo has a dozen
such scripts. This repo is not evidence that they vanish, only that a config
without them does not need the primitive.

`.chezmoiignore` gating does not become `mkIf`. It becomes "do not put the file
in a directory this host scans". That is cheaper than our proposal and worth
adopting for whole-app gates, though it cannot express our per-cask gates.

### The per-app ownership table

The strongest correction. Our table says of the merger apps that "nothing
merges into a file the app also writes" and lists `force` with its "will
silently delete the target" warning. Both halves are confirmed for the generic
file layer: `force = true` is exactly what this author uses when the app writes
back, and the comment says so
([home/darwin/rime-squirrel.nix#L4-L11](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/home/darwin/rime-squirrel.nix#L4-L11)).

But the claim needs a qualifier. Upstream home-manager already ships the merge
idiom per program. `programs.zed-editor.mutableUserSettings` defaults to `true`
and merges json5 into the live file with jq at
`entryAfter [ "linkGeneration" ]`
([HM zed-editor.nix#L19-L30](https://github.com/nix-community/home-manager/blob/ec1a8fdf74ed3f276148ee106299a2ba0e65d51f/modules/programs/zed-editor.nix#L19-L30),
[#L87-L94](https://github.com/nix-community/home-manager/blob/ec1a8fdf74ed3f276148ee106299a2ba0e65d51f/modules/programs/zed-editor.nix#L87-L94)).
Our doc should say: no generic construct merges, but a sanctioned per-program
pattern exists upstream, `impureConfigMerger` is a working reference
implementation for our six remaining mergers, and it is not wrapped in `run`,
so it acts under `DRY_RUN`. That last point is a real hazard for our dry-run
lane and should be called out where we describe the escape hatch.

Third option this repo adds that our table does not list: point the managed
path at the live checkout with `mkOutOfStoreSymlink` and let the app write into
the repo. Six sites do this. It gives up purity and gains a file the app can
own. For a handful of our app configs that may be the honest answer.

### Problem A, files the app also writes

Answered by surrender, not by merging. Three `force = true` sites, six
`mkOutOfStoreSymlink` sites, and one upstream merger. No custom merge engine
anywhere. Our doc's framing of Problem A as the hardest of the three holds; the
new information is that a 2,000-star, 20-machine config never solved it and
routed around it instead. Our 22 merges have no counterpart here, which means
this repo offers no evidence that our approach scales, and some evidence that
most people avoid needing it.

### Problem B, the MDM-managed work Mac

No evidence either way, and our doc should record that. `frieren` is labelled
"Work Use"
([hosts/README.md#L27](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/hosts/README.md#L27)),
but it imports the same Darwin modules as the personal machine, and nothing in
the repo touches MDM, managed preference domains, or a privilege ritual. There
is no Jamf equivalent, no temp-admin step, and no conditional on the machine
being managed.

What it does confirm is the mechanical shape our doc predicts: the switch is
one root command
([utils.nu#L59-L68](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/utils.nu#L59-L68)),
Touch ID for sudo is available and replaces the password prompt but not the
group requirement
([modules/darwin/system.nix#L24](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/modules/darwin/system.nix#L24)),
and Determinate forces `nix.enable = false`
([modules/darwin/nix-core.nix#L16-L18](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/modules/darwin/nix-core.nix#L16-L18)).
The `sudo -E` detail is a small practical note our doc does not have.

### Problem C, secrets without store leakage

Solved, under a different threat model than ours. Encrypted blobs in a separate
private repo, keyed per host to a root-only SSH host key, decrypted by a root
launchd daemon
([secrets/darwin.nix#L15-L28](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/secrets/darwin.nix#L15-L28),
[secrets/README.md#L6-L17](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/secrets/README.md#L6-L17)).
No password manager and no session dependency, which is why it works during a
root activation. Our doc recommends `op read` in activation; this is the
opposite trade, and it is the one that composes cleanly with a root switch.

Our doc should add two costs it does not currently name. First, host-keyed
secrets make whole-host integration tests impossible, and this author says so
in the test doc
([outputs/README.md#L55](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/outputs/README.md#L55)).
Second, ordering is a real problem: publishing decrypted secrets into `/etc`
fails on first activation because it runs before the decryption daemon
([secrets/darwin.nix#L87-L89](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/secrets/darwin.nix#L87-L89)).

### The test surface

Our doc imagines every host evaluating and building its activation closure. The
largest public config surveyed here does not do that. CI is one Linux job
running `nix eval .#evalTests`, with `nix eval .#checks` commented out and
annotated "stack overflow..."
([.github/workflows/flake_evaltests.yml#L37-L42](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/.github/workflows/flake_evaltests.yml#L37-L42)).
Darwin has two eval tests, both trivial
([outputs/aarch64-darwin/tests/hostname/expr.nix#L5-L7](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/outputs/aarch64-darwin/tests/hostname/expr.nix#L5-L7)).
NixOS integration tests are marked WIP
([outputs/README.md#L45](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/outputs/README.md#L45)).

Two implications for our doc. The `nix build .#darwinConfigurations.<host>.system`
target it proposes is above typical practice, which is a point in its favor and
a cost we should size honestly. And the `expr.nix` / `expected.nix` eval-test
pattern is cheap, real, and directly portable to us for the assertions we care
about, such as "the work host does not select personal package groups".

### Open questions this answers or reframes

| Question topic | What this repo shows |
| --- | --- |
| Homebrew cleanup policy | One datapoint for the maximal setting: `cleanup = "zap"`, with `upgrade = false` and manual `brew upgrade --cask --greedy` ([apps.nix#L102-L107](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/modules/darwin/apps.nix#L102-L107), [Justfile#L145-L148](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/Justfile#L145-L148)) |
| Whether to adopt nix-homebrew | Not adopted. Homebrew is installed by hand ([apps.nix#L97](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/modules/darwin/apps.nix#L97)) |
| Host-local overrides outside the repo | No mechanism exists at 20+ machines. Even the password hash is committed ([vars/default.nix#L12](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/vars/default.nix#L12)) |
| Whether agent CLI config can be managed | Not attempted. CLIs come from the `llm-agents` flake as packages ([dev-tools.nix#L11-L21](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/home/base/gui/dev-tools.nix#L11-L21)), and rules are installed by a hand-run 44-line Python symlinker ([agents/install-rules.py#L30-L38](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/agents/install-rules.py#L30-L38)) |
| Keeping mise for `latest` AI CLIs | Reframed. This author replaces mise with a pinned third-party flake, accepting lock-bump cadence instead of `latest` ([flake.nix#L131](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/flake.nix#L131)) |
| Pre-existing file collisions | Handled with `home-manager.backupFileExtension = "home-manager.backup"` ([lib/macosSystem.nix#L36](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/lib/macosSystem.nix#L36)) plus targeted deletion before `checkLinkTargets` ([git.nix#L13-L15](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/home/base/core/git.nix#L13-L15)) |
| zsh with a custom ZDOTDIR | `programs.zsh.dotDir = "${config.xdg.configHome}/zsh"` works in practice ([home/darwin/shell.nix#L35-L37](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/home/darwin/shell.nix#L35-L37)) |

## 6. What To Take, What To Avoid, Relevance

### Take

- The one-file-per-host output with an explicit import list. `fern.nix` is 41
  lines and shows the entire composition of a machine at a glance
  ([outputs/aarch64-darwin/src/fern.nix](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/outputs/aarch64-darwin/src/fern.nix)).
  This is more legible than our layered `machines.toml` merge and would survive
  the migration well.
- `expr.nix` and `expected.nix` eval tests. Cheap, fast on Linux CI, and
  exactly the right tool for asserting resolved host attributes
  ([outputs/aarch64-darwin/tests/hostname/expr.nix](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/outputs/aarch64-darwin/tests/hostname/expr.nix)).
- `backupFileExtension` as the standing collision policy
  ([lib/macosSystem.nix#L36](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/lib/macosSystem.nix#L36)).
  Cheaper than auditing every managed path before the first switch.
- The `sudo -E` detail on the switch
  ([utils.nu#L59-L68](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/utils.nu#L59-L68)).
  Preserving the caller's environment across the root boundary is directly
  relevant to our private-overlay SSH-agent problem.
- Role-gated secret namespaces with assertions, the pattern in
  `secrets/nixos.nix`, which is the one place typed options earn their cost.
- `mkOutOfStoreSymlink` into the live checkout as a legitimate third option for
  app-owned files, alongside merge and force.

### Avoid

- `cleanup = "zap"` on a work machine. With no per-host Homebrew policy and no
  role split, zap on `frieren` would remove anything IT or a colleague
  installed.
- A single flat `apps.nix`. It buys nothing over a Brewfile and guarantees that
  app configuration lives somewhere else entirely.
- Committing `initialHashedPassword` and per-host identity in the clear
  ([vars/default.nix#L12](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/vars/default.nix#L12)).
- Treating `force = true` as the default answer for app-owned files. Our 22
  merges exist because those files carry state we want to keep.
- Their CI shape. One Linux eval job would not catch the failures we care about.
- Host-key-bound secrets as the only mechanism, given it demonstrably blocks
  integration testing here
  ([outputs/README.md#L55](https://github.com/ryan4yin/nix-config/blob/324e5d8820c60211cff23ccc856c63adcf360cd6/outputs/README.md#L55)).

### Relevance: 3 out of 5

The stack overlaps almost exactly. nix-darwin plus home-manager as a Darwin
module, declarative Homebrew, typed and untyped macOS defaults, agenix,
Determinate Nix, and a personal and a work Mac in one flake. That makes it a
good reference for the shape of the target and for the operational rhythm
(build, switch, bump the lock, run brew upgrade by hand).

It scores 3 rather than 4 or 5 because it does not engage with any of the three
problems our doc calls hardest. There is no merge engine, no MDM constraint, and
no meaningful Darwin test lane. Its per-app surface on macOS is a package list,
not configuration. The work Mac is a hostname, not a role. Where our doc is
uncertain, this repo is mostly silent; where it does speak, it often speaks by
omission.

That omission is still useful. The clearest takeaway is calibration: a
2,300-commit, 2,044-star, 20-machine Nix config runs one CI job and merges
exactly one file, and the merger came from upstream. If our target state
demands more than that, the extra cost is ours to justify, not something the
ecosystem will absorb for us.

## 7. Concept-Map Scorecard

Rows refer to the numbered concept map in Appendix A of
[nix-target-state-research.md](../nix-target-state-research.md). Only rows with
direct evidence in this repo are listed.

| Row | Verdict | Note |
| --- | --- | --- |
| 1 | Supports | Plain home.file used throughout |
| 2 | Alternative | agenix mode and owner instead |
| 4 | Supports | Six mkOutOfStoreSymlink sites including Darwin |
| 5 | Supports | Host facts are evaluation inputs |
| 6 | Supports | One flake attribute per host |
| 7 | Alternative | Everything committed, no local overrides |
| 8 | Contradicts | Explicit import lists, not priorities |
| 9 | Supports | One Homebrew block, no taps |
| 11 | Supports | cleanup zap removes unlisted formulae |
| 13 | Contradicts | Homebrew installed manually, no nix-homebrew |
| 16 | Alternative | Gating by omitting the import |
| 17 | Contradicts | Flat cask list, no gating |
| 19 | Contradicts | Zero onChange uses in repo |
| 21 | Supports | entryBefore checkLinkTargets used exactly once |
| 23 | Supports | CustomUserPreferences carries ten untyped domains |
| 24 | Alternative | Force, symlink, or leave unmanaged |
| 26 | Supports | Typed system.defaults covers most domains |
| 27 | Supports | Root switch confirmed, no MDM |
| 28 | Supports | launchd.user.agents and launchd.daemons both used |
| 34 | Alternative | Pinned flake replaces mise latest |
| 35 | Supports | programs.zsh.dotDir points at XDG |
| 36 | Supports | xdg.configHome used, no data |
| 37 | Supports | Decryption at activation, never eval |
| 38 | Supports | Build then switch, no diff |
| 39 | Supports | No preference diff surface exists |
| 40 | Supports | backupFileExtension plus a preemptive rm |
| 42 | Contradicts | Linux eval only, no build |
