---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-04
updated: 2026-09-04
related:
  - ../nix-target-state-research.md
  - ../nix-migration-research.md
status_detail: "Agent survey of colemickens/nixcfg at 5718bd9080deaf7a7eabe08da647a59d72a59421, compared with the Nix target-state doc. Unreviewed."
---

# Survey: colemickens/nixcfg

## Method

Snapshot: `colemickens/nixcfg` at commit
`5718bd9080deaf7a7eabe08da647a59d72a59421`, fetched 2026-09-04 as a tarball
through `gh api repos/colemickens/nixcfg/tarball/<sha>` and read from
`/tmp/nix-surveys/colemickens-nixcfg`. Repo metadata came from the GitHub
API on the same day.

Read in full: `README.md`, `flake.nix`, `main.nu`, `.envrc`, `.gitignore`,
all four workflows under `.github/workflows/`, `.github/prep.sh`,
`.github/update.sh`, `darwinConfigs/manzana/configuration.nix`,
`homeManagerConfigs/cole/default.nix`, `secrets/.sops.yaml`,
`secrets/util.sh`, and the profiles `core.nix`, `hm.nix`, `interactive.nix`,
`gui.nix`, `user-cole.nix`, `addon-devtools.nix`. Read in part:
`hosts/raisin/configuration.nix`, `hosts/jupitertwo/{base,cross}.nix`,
`mixins/{common,_preferences,fonts,git,gh,nix,ssh,zsh,zellij,ghostty,helix,rclone-googledrive-mounts}.nix`.
Everything else was covered by directory listings, line counts, and
repo-wide greps.

Two caveats on what is verified.

- Nothing here was evaluated. This machine has no `nix` binary, so every
  claim is a source read, not a build. Anything that depends on evaluation
  semantics is marked unverified below.
- The task brief said the repo used `denix`. It does not. A repo-wide grep
  for `denix` matches only `ucodenix`, an AMD microcode flake input
  ([flake.nix#L18](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/flake.nix#L18)).
  `flake-utils` is used, but indirectly: it arrives through the
  `lib-aggregate` input
  ([flake.nix#L5](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/flake.nix#L5),
  [#L73](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/flake.nix#L73),
  [#L185](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/flake.nix#L185)).

## 1. What It Is

Cole Mickens' personal machine configuration, described in its own words as
"NixOS configurations for my laptop, and old desktop server", Determinate
Nix powered, "reproducible, and immutable full system configuration"
([README.md#L15-L19](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/README.md#L15-L19)).
The repo was created 2016-01-02, carries 488 stars, has no license file, and
was pushed on the survey date.

Author context matters for how much of this transfers. The git mixin
configures a work identity of `cole.mickens@determinate.systems` for
repositories under `~/work/`
([mixins/git.nix#L34-L47](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/git.nix#L34-L47)).
This is a Nix vendor's employee configuring an unmanaged Mac. There is no
MDM anywhere in the repo.

| Fact | Value | Source |
| --- | --- | --- |
| Platforms declared | `x86_64-linux`, `aarch64-linux`, `aarch64-darwin`, plus `riscv64-linux` via cross | [flake.nix#L51-L55](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/flake.nix#L51-L55), [#L125-L136](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/flake.nix#L125-L136) |
| Real machines | 3: `raisin` (NixOS x86_64), `jupitertwo` (NixOS riscv64, cross-built), `manzana` (nix-darwin aarch64) | [flake.nix#L103-L141](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/flake.nix#L103-L141) |
| Installer images | 3 (`x86_64` ISO, `aarch64` ISO, `riscv64` SD card) | [flake.nix#L131-L163](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/flake.nix#L131-L163) |
| Users | 1, `cole`, hardcoded | [profiles/user-cole.nix#L1-L11](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/profiles/user-cole.nix#L1-L11) |
| `.nix` files | 77 | measured on the snapshot |
| `.nix` lines | 3,726 total: mixins 1,947 (47 files), profiles 777 (14), hosts 525 (9), flake 221, darwinConfigs 114 (1), images 110 (4), homeManagerConfigs 32 (1) | measured on the snapshot |

Activity is high and mostly automated. In the 30 days before the snapshot
there were 88 commits, 38 of them titled exactly `flake.lock: Update`.

The lock is bumped by a workflow on an hourly cron. It rebases the author's
own nixpkgs forks with `jj`, runs
`nix flake update --override-input ... --commit-lock-file`, aborts when the
diff is empty, and force-pushes the result to a staging branch
`main-next-wip`
([next.yaml#L3-L6](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/.github/workflows/next.yaml#L3-L6),
[update.sh#L58-L75](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/.github/update.sh#L58-L75)).
The staging branch is then built by the same build and risky workflows the
main branch uses
([next.yaml#L35-L46](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/.github/workflows/next.yaml#L35-L46)).
Nothing in the workflows merges `main-next-wip` into `main`, so promotion
looks manual.

## 2. Composition

### Profile versus mixin

The README states the intent: `mixins/` is "individual application
configuration (mostly via `home-manager`)" and a "mix of `home-manager` and
`nixos` configuration"; `profiles/` is "bits that compose machine
personas"
([README.md#L51-L65](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/README.md#L51-L65)).

The code matches that intent, with one structural detail the README does not
say. Both layers are NixOS or nix-darwin modules. Neither is a
home-manager module. A mixin reaches into home-manager by setting
`home-manager.users.cole` from inside a system module. `mixins/zsh.nix` sets
the system option `programs.zsh.enable` and the HM option
`programs.zsh.dotDir` in the same file
([mixins/zsh.nix#L4-L18](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/zsh.nix#L4-L18)).
`mixins/gh.nix` declares a sops secret at the system level and enables
`programs.gh` at the HM level
([mixins/gh.nix#L4-L18](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/gh.nix#L4-L18)).

So the working definition is:

| Layer | What it is | Cardinality | Example |
| --- | --- | --- | --- |
| mixin | One tool or one capability. Owns both its system fragment and its home-manager fragment. | 47 files | [mixins/gh.nix](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/gh.nix#L1-L20) |
| profile | A persona. Mostly an `imports` list of mixins and other profiles, plus persona-wide config. | 14 files | [profiles/interactive.nix#L10-L34](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/profiles/interactive.nix#L10-L34) |

Profiles nest. `gui.nix` imports `interactive.nix`, which imports
`core.nix`, which imports `user-cole.nix`, `hm.nix`, and
`mixins/common.nix`
([profiles/gui.nix#L4-L14](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/profiles/gui.nix#L4-L14),
[profiles/interactive.nix#L10-L14](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/profiles/interactive.nix#L10-L14),
[profiles/core.nix#L4-L15](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/profiles/core.nix#L4-L15)).
Mixins also nest: `mixins/common.nix` imports `nix.nix`, `ssh.nix`, and
`profiles/user-cole.nix`
([mixins/common.nix#L12-L16](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/common.nix#L12-L16)),
so the two layers are not strictly stratified.

There is no data file and no resolver. Composition is `imports` lists and
the module system's own merge. The only typed option namespace is
`nixcfg.common`, seven boolean or string knobs declared in
`mixins/common.nix`
([#L18-L50](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/common.nix#L18-L50)),
read at
[#L52-L65](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/common.nix#L52-L65)
and set per host at
[hosts/raisin/configuration.nix#L37-L39](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/hosts/raisin/configuration.nix#L37-L39).

### How hosts compose

A host file is an `imports` list plus hardware and host facts. `raisin`
imports one profile, one addon profile, two mixins, two host-local files,
the Determinate NixOS module, and four `nixos-hardware` modules
([hosts/raisin/configuration.nix#L11-L29](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/hosts/raisin/configuration.nix#L11-L29)).
`flake.nix` maps a host name to `./hosts/<n>/configuration.nix` by default
and passes `specialArgs.inputs`
([flake.nix#L87-L100](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/flake.nix#L87-L100)).
Host attrsets are keyed by system first, then flattened
([flake.nix#L121-L141](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/flake.nix#L121-L141)),
which is what lets the per-system `checks` output be derived later.

### How the Mac composes

`darwinConfigurations.manzana` is written out longhand rather than through
`mkSystem`
([flake.nix#L103-L118](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/flake.nix#L103-L118)).
Its configuration is 114 lines. It imports the home-manager darwin module,
the Determinate darwin module, the sops darwin module, nine mixins, and one
profile
([darwinConfigs/manzana/configuration.nix#L9-L27](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/darwinConfigs/manzana/configuration.nix#L9-L27)).

The Mac does not import `core.nix` or `mixins/common.nix`, because those are
NixOS-only. The cost shows up immediately: the darwin config redeclares the
`nixcfg.common.hostColor` option locally, duplicating the declaration in
`common.nix`
([darwinConfigs/manzana/configuration.nix#L28-L36](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/darwinConfigs/manzana/configuration.nix#L28-L36)
versus
[mixins/common.nix#L44-L48](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/common.nix#L44-L48)).
It also sets `users.users.cole.home` by hand
([#L42](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/darwinConfigs/manzana/configuration.nix#L42)),
because `profiles/user-cole.nix` uses the NixOS-only `users.extraUsers`
([profiles/user-cole.nix#L10-L12](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/profiles/user-cole.nix#L10-L12)).

Cross-platform mixins branch inside themselves rather than being split. The
ghostty mixin holds two settings attrsets and picks one on
`pkgs.stdenv.hostPlatform.system`, and sets `package = null` on darwin
because the app is installed outside Nix there
([mixins/ghostty.nix#L4-L34](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/ghostty.nix#L4-L34),
[#L44](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/ghostty.nix#L44),
[#L97](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/ghostty.nix#L97)).

### Where identity lives

Identity is not abstracted. The literal string `cole` appears as an attribute
name in nearly every mixin. SSH public keys and a hashed password are inline
in `profiles/user-cole.nix`
([#L15-L24](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/profiles/user-cole.nix#L15-L24)).
Git signing keys and absolute macOS agent socket paths are inline in
`mixins/git.nix`
([#L11-L18](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/git.nix#L11-L18))
and `mixins/ssh.nix`
([#L3-L7](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/ssh.nix#L3-L7)),
including `/Users/cole/...` paths inside files that also serve Linux hosts.

### The standalone home-manager configs

There are none. A repo-wide grep for `homeConfigurations` returns nothing.
`homeManagerConfigs/cole/default.nix` is a 32-line home-manager module value,
consumed by assignment inside the darwin config:
`home-manager.users.cole = import ../../homeManagerConfigs/cole;`
([darwinConfigs/manzana/configuration.nix#L41-L44](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/darwinConfigs/manzana/configuration.nix#L41-L44),
[homeManagerConfigs/cole/default.nix#L1-L32](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/homeManagerConfigs/cole/default.nix#L1-L32)).
The NixOS side does the same thing inline, in `profiles/hm.nix`
([#L4-L33](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/profiles/hm.nix#L4-L33)).
Home-manager here is always a submodule of a system configuration. It is
never activated on its own.

### Dead code

29 of the 76 non-flake `.nix` files are unreachable from any host or image,
measured by following literal relative paths in `imports = [ ... ]` lists
from the seven entry points in `flake.nix`. That includes six of the
fourteen profiles: `gui.nix`, `gui-wayland.nix`, `gui-cosmic.nix`,
`commands-gui.nix`, `addon-gaming.nix`, `addon-asus.nix`. Nothing outside
`profiles/` imports `gui.nix`. `homeManagerConfigs/cole/default.nix` is a
false positive of that method, since it is reached by `import`, not by
`imports`.

Dead code has real consequences here.
`mixins/_preferences.nix` reads `inputs.nix-rice.colorschemes."MaterialDarker"`
([#L11](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/_preferences.nix#L11)),
but `nix-rice` is not declared as a flake input. Its only consumer is
`mixins/fonts.nix`, which reads only `prefs.font.*`
([#L10-L31](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/fonts.nix#L10-L31)),
and `fonts.nix` is reached only from the unreachable `gui.nix`. Nix's
laziness means the dangling reference never evaluates, so CI never sees it.
Unverified: whether this would error under `nix eval` on that attribute.
Similarly, the unreachable rclone mixin points the reader secret at the
writer file, a copy-paste bug that has never had a chance to fire
([mixins/rclone-googledrive-mounts.nix#L99-L108](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/rclone-googledrive-mounts.nix#L99-L108)).

## 3. Per-App Config Mechanics

### programs.* dominates

23 distinct `programs.<name>` namespaces are configured across the repo:
aria2, bandwhich, bash, bat, bottom, command-not-found, dconf, direnv, gh,
git, gpg, helix, jujutsu, mpv, nix-index, noisetorch, nushell, obs-studio,
ssh, ydotool, zellij, zoxide, zsh. Configuration is expressed as typed
option values, not as files. `mixins/zellij.nix` sets nine `settings` keys
([#L15-L25](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/zellij.nix#L15-L25)).
`mixins/git.nix` sets `settings`, `ignores`, and a conditional `includes`
block
([#L20-L51](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/git.nix#L20-L51)).

### home.file is rare

A repo-wide grep for `home.file`, `xdg.configFile`, `xdg.dataFile`,
`writeText`, and `mkOutOfStoreSymlink` returns 15 hits across 9 files. The
uses are small and specific: two GNU parallel marker files
([profiles/interactive.nix#L57-L60](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/profiles/interactive.nix#L57-L60)),
a gdb init line
([#L67-L69](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/profiles/interactive.nix#L67-L69)),
two helix files
([mixins/helix.nix#L27-L35](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/helix.nix#L27-L35)),
and four generated Firefox desktop entries
([profiles/gui.nix#L78-L85](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/profiles/gui.nix#L78-L85)).
No `mkOutOfStoreSymlink`, no `force = true`, no `backupFileExtension`.

Non-Nix payload files that would be assets in our repo are pulled in with
`builtins.readFile` and handed to an `extraConfig` string option:
`zellij.keybindings.kdl`
([mixins/zellij.nix#L26](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/zellij.nix#L26))
and `nushell-config.nu`
([mixins/nushell.nix#L13](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/nushell.nix#L13)).

### Activation is almost absent

There is exactly one activation script in the repo, a NixOS
`system.activationScripts` block that restarts `systemd-udev-trigger` as a
wifi workaround, gated on an option and on uptime
([mixins/common.nix#L129-L150](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/common.nix#L129-L150)).
There are zero `home.activation` blocks, zero `onChange` hooks, and zero
home-manager DAG entries.

Imperative work that survives is packaged as a store script rather than run
at activation. The git signing helper is a `pkgs.writeShellScript` whose
`outPath` becomes the `signing.signer` value
([mixins/git.nix#L14-L18](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/git.nix#L14-L18)),
and the rclone mount wrappers are `writeScriptBin` derivations referenced
from systemd units
([mixins/rclone-googledrive-mounts.nix#L6-L36](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/rclone-googledrive-mounts.nix#L6-L36)).

### App-rewritten files

Only one managed path in the repo is a file the app also writes: GitHub
CLI's `hosts.yml`, which holds `gh` auth state. The answer is not a merge.
sops-nix owns the whole file, decrypting it to the literal target path with
an owner and group:

```nix
sops.secrets."gh-hosts.yml" = {
  owner = "cole";
  group = "cole";
  path = "/home/cole/.config/gh/hosts.yml";
  sopsFile = ../secrets/encrypted/gh-hosts.yml;
  format = "binary";
};
```

([mixins/gh.nix#L5-L11](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/gh.nix#L5-L11)).
The path is Linux-only and the darwin config does not import this mixin.
Unverified: whether `gh` can still write that path, since sops-nix normally
places a symlink into a runtime secrets directory.

### macOS specifics

All four of these greps return nothing across the repo:

| Surface | Occurrences |
| --- | --- |
| `homebrew`, `casks`, `brews`, `masApps` | 0 |
| `system.defaults`, `CustomUserPreferences`, `targets.darwin` | 0 |
| `launchd` | 0 |
| `system.primaryUser` | 0 |

The Mac gets packages, shell, terminal, editor, and VCS configuration and
nothing else. `environment.systemPackages` and `fonts.packages` are set
directly
([darwinConfigs/manzana/configuration.nix#L78-L109](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/darwinConfigs/manzana/configuration.nix#L78-L109)).
The only macOS system setting touched is Touch ID for sudo,
`security.pam.services.sudo_local.touchIdAuth = true`
([#L111-L112](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/darwinConfigs/manzana/configuration.nix#L111-L112)),
which is the same nix-darwin option our doc cites in Problem B.

### Agent CLIs

`profiles/addon-devtools.nix` installs thirteen agent CLIs, including
`claude-code`, `codex`, `pi`, `opencode`, `goose-cli`, and `copilot-cli`,
from the `llm-agents.nix` flake input
([#L23-L36](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/profiles/addon-devtools.nix#L23-L36),
input at
[flake.nix#L43-L44](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/flake.nix#L43-L44)).
Not one line of their configuration is managed. There is no
`~/.claude`, no `~/.codex`, no skills payload, no plugin marketplace. The
only trace is `.claude` in the global gitignore list
([mixins/git.nix#L27-L32](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/git.nix#L27-L32)).

### Secrets

sops-nix, host-scoped, with ciphertext committed to a public repo.

- 16 encrypted blobs live in `secrets/encrypted/`, including SSH keys,
  API tokens, a `gh` hosts file, and rclone service account JSON.
- `secrets/.sops.yaml` has one creation rule covering every path, with one
  PGP fingerprint and three age recipients.
- Recipients are derived from machine SSH host keys.
  `secrets/util.sh` SSHes to a new host, reads
  `/etc/ssh/ssh_host_ed25519_key.pub`, converts it with `ssh-to-age`, and
  regenerates `.sops.yaml` from everything in `secrets/keys/`
  ([util.sh#L27-L66](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/secrets/util.sh#L27-L66)).
- There is no 1Password, no `op://`, and no interactive unlock anywhere.

The consumption discipline is the part worth copying. Secret values are
never interpolated. Only `config.sops.secrets.<name>.path` is, and the
consuming option takes an include directive:

```nix
access-tokens = "!include ${config.sops.secrets.nix-access-tokens.path}";
```

([darwinConfigs/manzana/configuration.nix#L46-L59](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/darwinConfigs/manzana/configuration.nix#L46-L59);
the NixOS twin is
[mixins/nix.nix#L58-L61](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/nix.nix#L58-L61)).
Restic and the GitHub runner do the same with `environmentFile`,
`passwordFile`, and `tokenFile`
([hosts/raisin/restic.nix#L48-L49](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/hosts/raisin/restic.nix#L48-L49),
[mixins/github-runner.nix#L22](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/github-runner.nix#L22)).

### Root per switch

The Mac switch is `sudo darwin-rebuild switch --option
narinfo-cache-negative-ttl 0 --flake /Users/cole/code/nixcfg`
([main.nu#L19-L21](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/main.nu#L19-L21)).
There is no attempt to avoid it and no privilege dance around it, because
the user is a local admin on an unmanaged machine. Determinate Nix owns Nix
itself through the `determinate.darwinModules.default` import and
`determinateNix.enable = true`
([darwinConfigs/manzana/configuration.nix#L11](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/darwinConfigs/manzana/configuration.nix#L11),
[#L54-L67](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/darwinConfigs/manzana/configuration.nix#L54-L67)),
which is the arrangement our doc's Problem B describes.

## 4. Testing And CI

There is no test suite. No `tests/` directory, no `nmt`, no `assertions`, no
module tests, no golden files. The only formatter declaration is
`formatter = pkgs.${system}.nixfmt`
([flake.nix#L196](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/flake.nix#L196)),
and no workflow invokes it.

CI is one build command:
`nix flake check --keep-going --build-all -L`, on a three-way runner matrix
of `ubuntu-24.04`, `ubuntu-24.04-arm`, and `macos-26`
([build.yaml#L21-L28](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/.github/workflows/build.yaml#L21-L28),
[#L54-L59](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/.github/workflows/build.yaml#L54-L59)).
It runs on push to `main` and is also called by the hourly lock workflow.
A separate `risky` lane builds the riscv64 host and the riscv64 installer by
explicit `nix build` calls, on Linux only
([risky.yaml#L42-L51](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/.github/workflows/risky.yaml#L42-L51)).

The important part is how `checks` is populated. `nix flake check` does not
reach `darwinConfigurations`, so the flake builds the `checks` attrset by
mapping both host tables into it, per system:

```nix
c_toplevels = lib.mapAttrs' (
  n: v: (lib.nameValuePair "toplevel-${n}" v.config.system.build.toplevel)
) (lib.mapAttrs (n: v: (mkSystem n v)) nixosConfigsEx.${system});
c_darwinConfigs = lib.mapAttrs' (
  n: v: (lib.nameValuePair "darwinConfig-${n}" v.system)
) darwinConfigurationsEx.${system};
```

([flake.nix#L198-L217](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/flake.nix#L198-L217)).
This is exactly the workaround our doc prescribes, implemented in a
production repo, and it is why the per-system `nixosConfigsEx` and
`darwinConfigurationsEx` tables exist at all.

What this test surface does not catch, in this repo's own evidence: the
undeclared `nix-rice` input, six dead profiles, and a swapped `sopsFile` in
a dead mixin. Building `checks` covers only what a reachable host forces.

## 5. Compare And Contrast With Our Target-State Doc

### Composition: app module plus roles, versus profiles plus mixins

| Our claim | Their evidence | Verdict |
| --- | --- | --- |
| "The unit is the app module. `modules/apps/<app>.nix` owns everything one app needs on a machine." | A mixin is precisely this, minus macOS surfaces. `mixins/gh.nix` owns the secret and the HM program in one file; `mixins/zsh.nix` owns the system option and the HM option in one file. | Supports. No change needed. |
| "A role module imports app modules. A host imports roles plus host-only exceptions." | `profiles/interactive.nix` imports 17 mixins and two profiles; `hosts/raisin` imports one profile plus host-only files. | Supports. No change needed. |
| "Nothing reads a `machine_type` value at evaluation time." | Confirmed. There is no type value anywhere. The only per-host knobs are seven `nixcfg.common` options. | Supports. |
| "Typed options replace the data layer." | Only partly. They have seven options across 3,726 lines, and everything else is plain imports and literal values. There is no submodule, no `attrsOf`, no `assertions`. | Alternative. Our doc should note that at their scale the typed-option layer was not needed, and that ours is driven by four machine types plus a private overlay, not by Nix. |
| Illustrative tree with `modules/roles/` and `modules/apps/` | Their names are `profiles/` and `mixins/`, and the split is persona versus tool. Same idea, different vocabulary, and the boundary leaks: `mixins/common.nix` imports `profiles/user-cole.nix`. | Supports with a caveat. Worth adding: without a rule, mixins start importing profiles. |
| Not addressed by our doc: multi-user or multi-identity | Their identity is a hardcoded `cole` attribute name in every mixin, with `/Users/cole` paths inside cross-platform files. | New. Our doc's app modules should say how the user name is parameterized before this gets written, or it will end up the same way. |

### The "what disappears" table

Their repo is a natural experiment for most of those rows, because they
never had the chezmoi construct in the first place. The rows it can speak to:

| Row | Their evidence | Verdict |
| --- | --- | --- |
| Resolver and layered `machines*.toml` gone | Confirmed. Imports and seven options do the work for three hosts on two operating systems. | Supports. |
| `run_onchange_` hash lines gone | Confirmed by absence: zero `onChange`, zero `home.activation`. | Supports, but weakly. They have almost nothing that needs a trigger. |
| Brewfile renderer gone | No evidence. They have no Homebrew at all. | No evidence. |
| Drift banner gone, replaced by generations | No evidence. They have no drift-detection surface. | No evidence. |
| Plist modify stubs gone | No evidence. Zero plists managed. | No evidence. |
| First-run prompts gone, host policy committed | Confirmed. Host policy is committed literals, including hashed passwords and SSH keys. | Supports. |

Our doc should not change on the strength of this table, but it should stop
implying the row set is empirically settled. Six of thirteen rows have no
witness in a 488-star, ten-year-old Nix repo, because those rows are all
macOS app-ownership rows.

### The per-app ownership table

The table names nine apps: Claude Code, Codex, obsidian-wiki, pi, Orca,
agentsview, crit, Cursor CLI, Yojam. This repo installs three of them
(Claude Code, Codex, pi) and configures none
([profiles/addon-devtools.nix#L23-L36](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/profiles/addon-devtools.nix#L23-L36)).

The one adjacent data point is `gh`. Its `hosts.yml` is auth state that the
app writes, and their answer is whole-file ownership through the secret
store, not a merge
([mixins/gh.nix#L5-L11](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/gh.nix#L5-L11)).
That is a fourth tier our Problem A design does not list: when the reason a
file cannot be rewritten is that it holds credentials, moving the
credentials into the secrets backend can make whole-file ownership viable
again. Our Cursor merger exists for exactly that reason, per
[nix-target-state-research.md](../nix-target-state-research.md),
Problem A. Worth adding as tier 1b, marked speculative until someone checks
whether the app tolerates a symlinked config path.

### Problem A, files the app also writes

No useful evidence. They manage one such file and only on Linux. Everything
else they own is a file only they write. Our doc's claim that home-manager's
file model does not fit co-owned files is neither confirmed nor challenged
here. If anything, this repo shows the shape of a config that avoided
Problem A entirely by never adopting a GUI app's preferences.

### Problem B, the MDM-managed work Mac

No evidence, and it is worth being explicit about why. The author works at
the company that ships Determinate Nix
([mixins/git.nix#L34-L41](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/mixins/git.nix#L34-L41)),
and his Mac is an unmanaged personal-admin machine. `sudo darwin-rebuild
switch` is a one-liner
([main.nu#L19-L21](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/main.nu#L19-L21)).

Two smaller confirmations do land.

- Our doc's claim that `touchIdAuth` removes the password prompt, not the
  group requirement, is consistent with them enabling it and never
  mentioning group membership
  ([darwinConfigs/manzana/configuration.nix#L111-L112](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/darwinConfigs/manzana/configuration.nix#L111-L112)).
- Our doc's note that Determinate Nix requires nix-darwin to stop managing
  Nix is confirmed by their use of the `determinate` darwin module with
  `determinateNix.enable = true` and `customSettings` instead of
  `nix.settings`
  ([#L11](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/darwinConfigs/manzana/configuration.nix#L11),
  [#L54-L67](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/darwinConfigs/manzana/configuration.nix#L54-L67)).

Our doc's table of two shapes for the work host should note that the
"standalone home-manager only" row has no witness in this survey. This repo
runs zero standalone home-manager configurations.

### Problem C, secrets without store leakage

Strong evidence, on both the rule and the tradeoff.

| Our claim | Their evidence | Verdict |
| --- | --- | --- |
| "Anything read during evaluation is copied into the store", so the value must be resolved at activation and referenced by path | Every consumer references `.path` and never the value. The option syntax they use is an include directive: `"!include ${config.sops.secrets.nix-access-tokens.path}"`. | Supports strongly. Worth citing in our doc as a concrete idiom. |
| sops-nix "would change what the public repo contains" | Confirmed and priced. They commit 16 encrypted blobs to a public repo, and it is normal practice for them. | Supports. Our doc frames the policy shift correctly; it should add that this is the Nix-community default, not an exotic choice. |
| sops-nix needs "an unencrypted age key on every machine" | Their variant avoids a separate key: age recipients are derived from each host's existing SSH host key by `ssh-to-age`, and `.sops.yaml` is regenerated from `secrets/keys/` by a script. | Alternative. Our doc should add this as a mitigation of the key-distribution objection. It only works for host-scoped secrets, not for user-scoped ones. |
| Recommended target is `op read` in activation for interactive Macs | No evidence either way. They have no interactive unlock at all. Their model is fully unattended, which is what our doc recommends only for the headless homelab mini. | No evidence. |

The honest read: their scheme solves a different problem. Their secrets are
machine credentials that a service must read while the human is asleep. Our
three are app license blobs behind a biometric session. The transferable
part is the discipline and the `ssh-to-age` recipient trick, not the model.

### The test surface

This is where the repo is most useful.

| Our claim | Their evidence | Verdict |
| --- | --- | --- |
| "`nix flake check` ... does not touch `darwinConfigurations`. Every host must be exposed explicitly: `checks.aarch64-darwin.<host> = self.darwinConfigurations.<host>.system`" | They do this literally, and it explains why their host tables are keyed by system before being flattened. | Supports strongly. Our doc should cite this as a working implementation. |
| That replacement is "stronger for evaluation and dependency failures and silent about activation" | Confirmed for activation. Also weaker for evaluation than our doc implies: laziness means an undeclared input in an unreachable module never fails the build. | Contradicts in part. Our doc should add: closure builds only cover attributes a reachable host forces. Dead modules and unforced attributes are invisible. A reachability check is a separate, cheap test worth having. |
| "Module tests replace template golden tests" | No evidence. They have no module tests. | No evidence. |
| "What still needs a machine" | Consistent by omission. They have no VM lane and nothing that would need one. | No evidence. |

One more CI idea our doc does not have. Their lock bump is not a manual
review step. It is an hourly job that writes to a staging branch, builds
every host on three runners, and leaves promotion to a human
([next.yaml#L3-L6](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/.github/workflows/next.yaml#L3-L6),
[#L35-L46](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/.github/workflows/next.yaml#L35-L46),
[update.sh#L58-L75](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/.github/update.sh#L58-L75)).
Our doc says freshness "becomes a lock bump you review, or a launchd job".
It should add the third option: a scheduled bump that proves itself in CI
before you look at it.

### Open questions this survey touches

| # | Question | What this repo says |
| --- | --- | --- |
| 1 | Claude Code marketplace over store symlinks | Nothing. They install `claude-code` and manage no config. |
| 2 | Does a running app overwrite a `defaults` write | Nothing. Zero `defaults` usage. |
| 3 | Jamf media restriction and `/nix` | Nothing. No MDM. |
| 5 | Can service accounts read the license vaults | Reframed. Their unattended model uses host-key-derived age recipients instead of a service account, which sidesteps the question for machine secrets. Does not answer it for 1Password. |
| 7 | Is Homebrew fully declarative per host | Nothing. No Homebrew. |
| 9, 10, 13, 16 | Managed layers for Claude, Codex, Cursor | Nothing. They configure none of these tools. |
| 11, 12 | Which plist domains are safe | Nothing. Zero plists. |
| Not in our list | Does exposing every host in `checks` give real evaluation coverage | Partly. It builds what reachable hosts force. Their dead `nix-rice` reference survives CI. Worth adding as question 17. |

## 6. What To Take, What To Avoid, Relevance

### Take

1. **The explicit `checks` construction.** Key host tables by system, then
   derive `checks.<system>` from them, so one `nix flake check --build-all`
   covers every NixOS and darwin host. Adopt the pattern and the shape of
   the host tables that makes it cheap
   ([flake.nix#L103-L141](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/flake.nix#L103-L141),
   [#L198-L217](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/flake.nix#L198-L217)).
2. **The one-file-per-tool boundary that spans layers.** A mixin owns its
   system fragment and its home-manager fragment together. That is our app
   module, already load-bearing in a real repo.
3. **The secret-reference idiom.** Consume
   `config.sops.secrets.<n>.path`, never the value, and prefer options that
   take a file (`environmentFile`, `passwordFile`, `tokenFile`, `!include`).
4. **`ssh-to-age` host-key recipients.** For any host-scoped secret, deriving
   the age recipient from the machine's existing SSH host key removes the
   "another key to distribute" objection
   ([secrets/util.sh#L56-L66](https://github.com/colemickens/nixcfg/blob/5718bd9080deaf7a7eabe08da647a59d72a59421/secrets/util.sh#L56-L66)).
5. **The scheduled lock lane with a staging branch.** Bump hourly, build on
   a matrix, promote by hand.
6. **`builtins.readFile` for payload.** Keep a keybinding file as a real
   `.kdl` and read it into an `extraConfig` option. That is our
   `.chezmoiassets` rule with a different verb.

### Avoid

1. **Hardcoded identity.** `cole` as an attribute name in 40-odd files, and
   `/Users/cole/...` inside files that also serve Linux, is the single worst
   property of this repo. Parameterize the user before writing the second
   module.
2. **Letting dead modules accumulate.** 29 unreachable `.nix` files, and CI
   cannot see the dangling input inside them. If we adopt this shape, add a
   reachability check.
3. **A profile/mixin boundary with no rule.** `mixins/common.nix` importing
   `profiles/user-cole.nix` inverts the intended direction.
4. **Duplicated option declarations across platforms.** The darwin config
   redeclares `nixcfg.common.hostColor` because it cannot import the NixOS
   `common.nix`. A platform-neutral options module fixes that.
5. **Zero tests.** For a repo whose whole value proposition is that the
   build proves the config, they build and never assert.

### Relevance: 2 out of 5

The overlap with our situation is thin in exactly the places that are hard
for us. This repo has no Homebrew, no `system.defaults`, no launchd, no MAS
apps, no plists, no MDM, no standalone home-manager, no test suite, and no
managed agent-CLI configuration. Its macOS host is 114 lines and gets
packages, a shell, a terminal, an editor, and git. Its three hardest
problems are not our three hardest problems: it is a NixOS repo that owns
whole machines, so the co-ownership question our Problem A is built around
never arises.

What keeps it above a 1 is that two narrow sections are genuinely
high-signal. The `checks` construction is the exact workaround our doc
prescribes for `nix flake check` and darwin hosts, running in production.
The secrets discipline gives us a citable idiom and a key-distribution trick
we did not have. The composition model also confirms, at ten years and 488
stars, that "profiles import mixins, hosts import profiles" scales fine
without a data layer or a resolver, which supports our native target's
central bet.

Treat this as the control case: what a Nix config looks like when none of
our hard constraints apply. It tells us the clean parts of our target design
are correct. It tells us nothing about whether the dirty parts are
survivable.

## 7. Concept-Map Scorecard

Rows from Appendix A of
[nix-target-state-research.md](../nix-target-state-research.md) for which
this repo is evidence. Rows with no witness here are omitted, notably 9, 11,
12, 13, 17, 18, 19, 20, 23, 24 (beyond `gh`), 25, 26, 29, 30, 31, 32, 38,
39, and 40.

| Row | Verdict | Note |
| ---: | --- | --- |
| 1 | Supports | Sparse home.file, own-write files only |
| 2 | Alternative | Secret store sets owner, group |
| 4 | Supports | No out-of-store symlinks at all |
| 5 | Supports | Platform branch replaces template conditionals |
| 6 | Supports | One flake attribute per host |
| 8 | Alternative | No layers, plain imports plus mkForce |
| 10 | Supports | Packages listed directly in modules |
| 14 | Alternative | Committed sops blobs, no private input |
| 15 | Alternative | No plugin manager, plugins list empty |
| 16 | Alternative | Import or omit, no gates |
| 21 | Supports | No activation, so no ordering needed |
| 22 | Supports | Store scripts, no bootstrap hook |
| 27 | Supports | Plain sudo darwin-rebuild, touchIdAuth on |
| 28 | Alternative | systemd on Linux, nothing on darwin |
| 33 | Alternative | programs.gh only, no extensions |
| 34 | Alternative | Agent CLIs from flake, no mise |
| 35 | Supports | programs.zsh.dotDir points at XDG |
| 36 | Supports | xdg.dataHome and configHome used throughout |
| 37 | Supports | Secret path referenced, value never interpolated |
| 41 | Alternative | Full NixOS everywhere, never standalone HM |
| 42 | Supports | Explicit checks per host, macOS runner |
