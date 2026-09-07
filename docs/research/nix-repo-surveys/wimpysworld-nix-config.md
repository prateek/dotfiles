---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-04
updated: 2026-09-04
related:
  - ../nix-target-state-research.md
  - ../nix-migration-research.md
status_detail: "Agent survey of wimpysworld/nix-config at e2ca3b06, compared with the Nix target-state doc. Unreviewed."
---

# Survey: wimpysworld/nix-config

## Method

Read on 2026-09-04 against a pinned tarball of
[wimpysworld/nix-config](https://github.com/wimpysworld/nix-config) at commit
`e2ca3b06484541d0349df60990a3ec2d470b44c3`, fetched with
`gh api repos/wimpysworld/nix-config/tarball/<sha>`. That sha was still
`HEAD` when the survey finished. Permalinks below all resolve at that sha.

Files read in full: `README.md`, `flake.nix`, `lib/default.nix`,
`lib/flake-builders.nix`, `lib/registry-systems.toml`,
`lib/registry-users.toml`, `lib/noughty/default.nix`, `lib/noughty-helpers.nix`,
`lib/tests/wayland-compositors.nix`, `lib/tests/wayland-session-lifecycle.nix`,
`darwin/default.nix`, `darwin/momin/default.nix`, all four files under
`darwin/_mixins/`, `common/default.nix`, `home-manager/default.nix`,
`home-manager/_mixins/agentic/default.nix`, the `claude-code`, `codex`,
`assistants`, `agentsview`, `pi`, `mcp`, and `acp` agentic modules,
`modules/nixos/falcon-sensor.nix`, `modules/nixos/default.nix`,
`modules/home-manager/default.nix`, `.sops.yaml`, `.github/dependabot.yml`,
`.github/workflows/builder.yml`, `.github/workflows/checker.yml`,
`.github/workflows/freshener.yml`,
`home-manager/_mixins/scripts/flake-inventory/flake-inventory.sh`, and the
relevant recipes in `justfile`. `lib/noughty/README.md` was read in outline
plus its rationale sections. The `secrets/` tree was listed but not decrypted.
Counts ("15 activation blocks", "zero `onChange` uses", "50 distinct
`programs.*` namespaces") come from `grep` across all 382 `.nix` files.
Repository metadata, commit counts, and per-path history came from the GitHub
API on the same day.

Compared against [the Nix target-state doc](../nix-target-state-research.md),
[the prior migration doc](../nix-migration-research.md), and
[the chezmoi architecture reference](../../references/chezmoi-architecture.md).

One fact in the task brief needed correcting against the source. The brief
described the repo as "flake-parts plus flake-utils". Both are declared as
inputs, but the root flake builds its outputs from a hand-written builder in
`lib/`, not from flake-parts
([flake.nix#L92-L107](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/flake.nix#L92-L107)).
The brief also implied an active macOS host. There is none at this sha; see
section 1.

## 1. What It Is

Martin Wimpress's personal NixOS, nix-darwin, and Home Manager configuration.
He is the author of Noughty Linux and a long-time Ubuntu MATE maintainer, and
parts of this repo are explicitly written to be reusable outside it
(`lib/noughty/README.md`, "Why TOML for the registries").

| Fact | Value |
| --- | --- |
| Stars | 716 |
| Created | 2023-03-13 |
| Last push | 2026-09-04 |
| License | BlueOak-1.0.0 |
| `.nix` files | 382 |
| Registered hosts | 21, all `x86_64-linux` |
| Darwin hosts | 1, commented out |
| Commits, last 52 weeks | 1962 |
| Commits, last 12 weeks | 639 |

This is a very active repo by any measure, and the activity is real work, not
just bot noise. The lock is bumped continuously: at least 100 commits touched
`flake.lock` in the 90 days before the survey, which is the GitHub API page
cap rather than the true count. Bumps arrive from three sources. Dependabot
runs weekly against the `nix` package ecosystem
([dependabot.yml#L9-L12](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/.github/dependabot.yml#L9-L12)).
A "Package Freshener" workflow runs twice a week on cron and opens a pull
request per package from 13 per-package updater scripts
([freshener.yml#L12-L16](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/.github/workflows/freshener.yml#L12-L16), [#L31-L68](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/.github/workflows/freshener.yml#L31-L68)).
The rest are manual `chore(flake): update lock` commits.

The important caveat for our purposes: **the only macOS host in the repo is
disabled.** The registry entry for `momin` is commented out with a note that
"there is no local Mac to validate against; CI cannot build a config that only
exists in the registry"
([registry-systems.toml#L410-L426](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/lib/registry-systems.toml#L410-L426)).
That disable landed on 2026-06-10. The Darwin CI job is gated on
`needs.inventory.outputs.has_darwin == 'true'`
([builder.yml#L285-L296](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/.github/workflows/builder.yml#L285-L296)),
and the inventory script discovers Darwin targets by enumerating
`darwinConfigurations`
([flake-inventory.sh#L149-L157](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/scripts/flake-inventory/flake-inventory.sh#L149-L157)),
which is now empty. So no Darwin closure has been built by CI or a machine
since June. Files under `darwin/` kept changing until 2026-07-30. Every macOS
claim in this survey describes code that has not been evaluated in roughly
three months. Treat it as design evidence, not operational evidence.

## 2. Composition

### The broadcast-and-gate pattern

The composition model is stated plainly in the README and it is the opposite
of what our doc proposes:

> Most NixOS configurations use **selective imports** - each host cherry-picks
> which modules to include. This flake does the opposite. **Every module is
> imported by every host.** Modules decide *internally* whether to activate,
> based on typed host metadata. I call this the "broadcast-and-gate" pattern
> ([README.md#L64-L66](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/README.md#L64-L66)).

A module gates itself with `lib.mkIf` on typed metadata, and a module whose
condition is false "evaluates to nothing - zero cost, zero side effects"
([README.md#L68-L82](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/README.md#L68-L82)).
Import lists disappear entirely. Each `_mixins` parent auto-imports every
subdirectory by reading the filesystem:

```nix
directories = lib.filterAttrs isDirectoryAndNotTemplate (builtins.readDir currentDir);
imports = lib.mapAttrsToList (name: _: importDirectory name) directories;
```

([darwin/_mixins/features/default.nix#L1-L10](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/darwin/_mixins/features/default.nix#L1-L10)).
The stated payoff is that "adding a new feature = drop a directory containing
a self-gating module. No import lists to edit. No other files to touch"
([README.md#L88-L94](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/README.md#L88-L94)).

### Where machine identity lives

Machine identity lives in a committed TOML registry, not in Nix. `flake.nix`
reads it with `builtins.fromTOML` and hands it to the builder
([flake.nix#L87-L107](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/flake.nix#L87-L107)).
The registry header documents the field vocabulary and defaults in comments
([registry-systems.toml#L1-L25](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/lib/registry-systems.toml#L1-L25)).
A host row is short; `[palpatine]` is four lines
([registry-systems.toml#L405-L408](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/lib/registry-systems.toml#L405-L408)).

`resolveEntry` merges four layers in plain Nix with `//` before the module
system ever sees the data: a baseline `username`, defaults derived from
`kind` plus OS, ISO overrides, then the explicit entry
([flake-builders.nix#L18-L52](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/lib/flake-builders.nix#L18-L52)).
Because `//` is right-biased attrset update, list-valued fields are replaced
wholesale rather than concatenated. That is the same semantics our
`machines.toml` has today, obtained without fighting the module system's
list-merge behavior.

The resolved entry is then injected into typed options. `mkDarwin` builds a
host from exactly three modules: the shared `../darwin`, the host directory,
and an inline block that sets `noughty.host.*` and `noughty.user.*`
([flake-builders.nix#L306-L376](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/lib/flake-builders.nix#L306-L376)).
`noughty` is a real NixOS-style options module with declared types,
descriptions, and derived read-only values. `host.is.workstation`,
`host.is.server`, `host.is.laptop`, `host.is.darwin`, and `host.is.linux` are
all computed defaults, not registry fields
([noughty/default.nix#L165-L208](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/lib/noughty/default.nix#L165-L208)).
`lib/noughty/README.md` argues explicitly that the module system beats helper
functions because it brings type checking, defaults, `mkDefault`/`mkForce`
overridability, and generated documentation.

### How desktop, server, and macOS are expressed

Not by name and not by role module. `desktop` is either set in the registry or
derived: `"aqua"` for a `computer` on a Darwin platform, the default Wayland
compositor for a `computer` on Linux, and `null` for servers, VMs, and
containers
([flake-builders.nix#L23-L37](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/lib/flake-builders.nix#L23-L37)).
`host.is.workstation` is then simply `desktop != null`
([noughty/default.nix#L166-L170](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/lib/noughty/default.nix#L166-L170)).
Platform selects which top-level tree gets used, through predicates over the
registry
([flake-builders.nix#L54-L63](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/lib/flake-builders.nix#L54-L63)).

### How a host opts into a mixin

It does not. A host opts *out* by having metadata the module rejects. There
are four gating vocabularies in use:

| Gate | Example | Source |
| --- | --- | --- |
| Derived boolean | `lib.mkIf host.is.workstation` | [claude-code#L677-L685](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/agentic/claude-code/default.nix#L677-L685) |
| User tag | `lib.mkIf (noughtyLib.userHasTag "developer")` | [agentsview#L25](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/agentic/agentsview/default.nix#L25) |
| User identity | `lib.optionals (noughtyLib.isUser [ "martin" ])` | [darwin/_mixins/desktop#L28-L36](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/darwin/_mixins/desktop/default.nix#L28-L36) |
| Compound | `lib.mkIf (isDeveloper && !host.is.server)` | [codex#L687](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/agentic/codex/default.nix#L687) |

Host directories carry only hardware. The README says so
([README.md#L94](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/README.md#L94)),
and the Mac takes it to the limit: `darwin/momin/default.nix` is one line,
`_: { }`
([darwin/momin/default.nix#L1](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/darwin/momin/default.nix#L1)).

### Per-app modules

The app-module idea our doc proposes is present and is the dominant unit at
the leaf level. `home-manager/_mixins/agentic/` holds one directory per agent
CLI: `claude-code`, `codex`, `opencode`, `pi`, `paseo`, `agentsview`, `mcp`,
`acp`, `fence`, `hooks`, `assistants`, `claude-desktop`. Each owns its
package, its config, its secrets, and its activation edges. `claude-code` is
977 lines and even declares its own option so that language modules can
contribute LSP fragments upward:

```nix
options.claude-code.lspServers = lib.mkOption {
  type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
  default = { };
};
```

Cross-cutting composition happens through options like that, not through a
role layer. There is no `roles/` directory anywhere in the tree.

## 3. Per-App Config Mechanics

### `programs.*` first, `home.file` last

The strongest structural signal is what he does *not* do. Across 382 `.nix`
files there are 50 distinct `programs.<name>` namespaces in use and only 12
`file = { ... }` blocks. `home.file` is reserved for things with no upstream
module: a face image, a media-production asset, a Claude LSP plugin manifest.
Raw file placement is the exception.

`mkOutOfStoreSymlink` appears exactly once in the repo, and not for the reason
our doc contemplates. It points `~/.gitconfig` at `~/.config/git/config` to
keep one file from diverging into two
([git/default.nix#L65-L69](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/development/git/default.nix#L65-L69)).
Nothing links into the repo checkout.

`onChange` is used **zero** times. Every side effect in the repo is an
unconditional `home.activation` block. There are 15 of them across 11 files:

| File | Block | Ordering |
| --- | --- | --- |
| `home-manager/default.nix` | `refreshSopsNix` | `entryAfter [ "reloadSystemd" ]` |
| `agentic/claude-code` | `claudeCodeDisableLspPrompt` | `entryAfter [ "writeBoundary" ]` |
| `agentic/codex` | `codexConfig` | `entryAfter [ "writeBoundary" ]` |
| `agentic/assistants` | `codexFiles`, `codexSecretFiles` | `entryAfter [ "writeBoundary" ]`, then `entryAfter [ "codexFiles" "sops-nix" ]` |
| `agentic/mcp`, `agentic/acp` | Zed settings purges | `entryBetween [ "zedSettingsActivation" ] [ "linkGeneration" ]` |
| `agentic/pi` | `piStateDirectories` | `entryAfter [ "writeBoundary" ]` |
| `development/zed-editor` | `zedDisabledExtensionsPurge` | `entryAfter [ "linkGeneration" ]` |
| `terminal/herdr.nix` | chained plugin installs | `entryAfter [ "writeBoundary" ]` |
| `users/martin/gpg.nix` | key import | `entryAfter [ "writeBoundary" ]` |

Only one of those, `refreshSopsNix`, wraps its commands in home-manager's
`run` helper
([home-manager/default.nix#L59-L63](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/default.nix#L59-L63)).
The other fourteen call `jq`, `install`, `mv`, `mkdir`, and `python` directly,
so `home-manager switch -n` would still mutate the target files. That is worth
noting for our own Problem A design, which assumes the `run` discipline.

### App-rewritten files: three distinct strategies

He manages the same class of files we do, and he hit the same wall. Three
different answers are visible in the tree.

**1. Merge into the app's mutable runtime file (Claude Code).** He uses the
`programs.claude-code` module for `settings.json`, composed with `lib.mkMerge`
from a base attrset, conditional communication rules, hook definitions, and a
Linux-only override. But one setting could not go there, and the comment is
worth reading in full:

> The kill switch is the undocumented `lspRecommendationDisabled` key
> (verified from the decompiled source); it must live in the mutable runtime
> file `~/.claude.json`, not in settings.json (which would reject it on schema
> validation). Claude Code rewrites `~/.claude.json` at runtime (OAuth,
> caches, per-project state), so the key is merged in idempotently rather
> than declared as a read-only symlink
> ([claude-code#L677-L706](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/agentic/claude-code/default.nix#L677-L706)).

The implementation is a `jq` read-modify-write in activation that creates the
file at mode 600 if absent, exits silently if the JSON is unparseable, and
writes through a `mktemp` sibling. This is our Problem A tier 3, applied to a
file our per-app table does not list at all.

**2. Generate in the store, deploy as a real mutable file (Codex).** He did
*not* use `/etc/codex/config.toml`. The reason is a file-shape constraint, not
a content one:

> Why a real file, not a store-backed symlink: codex follows symlink chains
> when persisting config.toml. A Home Manager link into the read-only Nix
> store leaves codex with a target it cannot rewrite
> ([codex#L572-L582](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/agentic/codex/default.nix#L572-L582)).

The desired TOML is built with `(pkgs.formats.toml { }).generate`, then an
activation function removes any symlink at the target, runs a generated Python
merger built on `tomllib` and `tomli_w`, and `chmod 644`s the result
([codex#L662-L673](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/agentic/codex/default.nix#L662-L673)).
The merger has a `runtime_state_allowlist` hook that currently returns `{}`,
so activation deliberately scrubs runtime drift
([codex#L605-L621](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/agentic/codex/default.nix#L605-L621)).
This is the same program shape as our `modify_` stubs, moved into activation
and generated from Nix rather than checked in.

**3. Wrap the binary and never touch the file (agentsview).** The most
interesting answer, because it is not in our doc's tier list at all. He
manages no `config.toml` for agentsview. Instead a sops template renders an
env file at mode 0400, and `makeWrapper` wraps the binary so it sources that
file at exec time
([agentsview#L14-L43](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/agentic/agentsview/default.nix#L14-L43)).
The app keeps sole ownership of its config file, and Nix owns the
environment the app runs in.

A fourth, narrower pattern appears for Zed: reconcile one subtree of a file
the app also writes. The MCP module purges stale `context_servers` entries
from Zed's `settings.json` while leaving other top-level keys alone, because
"users may legitimately set those via Zed's UI"
([mcp#L112-L126](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/agentic/mcp/default.nix#L112-L126)).
That is the shape our doc assigns to Orca.

### Symlinks are not always readable by the app

Two independent findings in this repo say a store symlink can be invisible,
not just unwritable:

> codex-rs scans for SKILL.md using entry.file_type() which does NOT follow
> symlinks on Linux - it returns the type of the symlink itself. The scanner
> only follows symlinked directories, not symlinked files; it skips symlinked
> SKILL.md files entirely. home.file creates symlinks, so skills written via
> home.file are invisible to codex
> ([assistants#L654-L665](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/agentic/assistants/default.nix#L654-L665)).

His fix is a hybrid: `SKILL.md` files are written as real files by an
activation script, and supporting directories beside them stay symlinks,
because "the scanner only inspects SKILL.md itself for the `is_file()` check,
and it does follow symlinked directories". The agents case is the same
([assistants#L890-L897](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/agentic/assistants/default.nix#L890-L897)).

### macOS defaults

Everything goes through nix-darwin's typed `system.defaults` plus
`CustomUserPreferences`. There are no plist fragments, no merge scripts, and
no `targets.darwin.defaults` (the home-manager route) anywhere in the tree.
`system.primaryUser` is set from the registry username, and the domains
managed under `CustomUserPreferences` include `com.apple.AdLib`,
`com.apple.controlcenter`, `com.apple.desktopservices`, `com.apple.finder`,
`com.apple.ImageCapture`, `com.apple.screencapture`, `com.apple.SoftwareUpdate`,
and `com.apple.TimeMachine`, alongside typed `NSGlobalDomain`, `dock`,
`finder`, `menuExtraClock`, `screensaver`, `smb`, and `trackpad` blocks
([darwin/default.nix#L111-L150](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/darwin/default.nix#L111-L150)).
Unverified in practice: none of this has been applied since June.

### Homebrew, casks, MAS, taps

nix-homebrew is enabled with `autoMigrate = true` and `mutableTaps = true`
([darwin/default.nix#L55-L61](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/darwin/default.nix#L55-L61)).
The `homebrew` module is set to the most aggressive posture available:

```nix
homebrew = {
  enable = true;
  onActivation = { autoUpdate = true; upgrade = true; cleanup = "zap"; };
};
```

([darwin/default.nix#L46-L53](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/darwin/default.nix#L46-L53)).
Casks are a literal list of 11 in one desktop mixin, with 7 of them gated on
user identity
([darwin/_mixins/desktop/default.nix#L21-L37](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/darwin/_mixins/desktop/default.nix#L21-L37)).
No renderer, no groups, no package data file. There are **no** `masApps`
anywhere in the repo, though the `mas` CLI is installed
([darwin/default.nix#L31-L39](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/darwin/default.nix#L31-L39)).
No explicit taps are declared.

### launchd

Two `launchd.agents` declarations, both in home-manager, both gated on
`host.is.darwin`: a PATH fix for the sops-nix agent
([home-manager/default.nix#L234-L240](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/default.nix#L234-L240))
and one in the git module. Everything else that would be a LaunchAgent on
macOS is a `systemd.user.services` unit gated on `host.is.linux`, and the
Darwin branch is simply absent.

### Secrets

sops-nix, wired through the home-manager module
([home-manager/default.nix#L223-L232](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/default.nix#L223-L232)),
with the age key read from `$XDG_CONFIG_HOME/sops/age/keys.txt` and
`generateKey = false`. There are four age recipients in `.sops.yaml`, two user
keys and two host keys, and one creation rule matching
`secrets/[^/]+\.(yaml|json|env|ini)$`
([.sops.yaml#L20-L32](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/.sops.yaml#L20-L32)).

**52 encrypted files are committed to this public repository**, including
per-host files, `ai.yaml`, `slack.yaml`, `linear.yaml`, `mcp.yaml`, and
`agentsview.yaml`. Nothing was decrypted for this survey.

Two sops-nix constructs matter for us. `sops.secrets.<NAME>` with a `mode`
gives a decrypted file at a runtime path, consumed by reading
`config.sops.secrets.<NAME>.path` inside a shell fragment
([pi#L742-L755](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/agentic/pi/default.nix#L742-L755)).
`sops.templates` goes further: it renders a whole file from a Nix string with
`config.sops.placeholder.<NAME>` substitutions, at an arbitrary absolute path,
with a mode
([pi#L757-L761](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/agentic/pi/default.nix#L757-L761),
[agentsview#L31-L39](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/agentic/agentsview/default.nix#L31-L39)).
That is exactly the shape of our three license files.

There is no 1Password anywhere in the Nix configuration. Authenticating 1Password
is a manual line item in the README's post-install checklist
([README.md#L343-L349](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/README.md#L343-L349)).

The operational cost of the sops path is visible. On Linux he needs an
activation block that force-restarts `sops-nix.service` after every switch,
because the unit is a store symlink and a stale daemon left "sops templates
rendering old content until a manual" intervention
([home-manager/default.nix#L51-L63](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/default.nix#L51-L63)).
On Darwin he needs a `PATH` override with `lib.mkForce` on the launchd agent.

### Root per switch

Yes. `just apply-host` runs
`sudo fh apply "${CONFIG_TYPE}" "${FLAKEREF}#${CONFIG_PATH}.{{ hostname }}"`
and then diffs the generations with `nvd diff`
([justfile#L430-L436](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/justfile#L430-L436)).
He softens the prompt the same way our doc predicts, with
`security.pam.services.sudo_local.touchIdAuth = true`
([darwin/default.nix#L109](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/darwin/default.nix#L109)).
Home Manager is applied separately and needs no root, which is why the
justfile splits `just host` from `just home`
([README.md#L255-L274](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/README.md#L255-L274)).

Nix itself is managed by Determinate, with `determinateNix.enable = true` and
a native Linux builder enabled through the Virtualization framework
([darwin/default.nix#L63-L70](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/darwin/default.nix#L63-L70)).

## 4. Testing And CI

### `checks` is nearly empty

`flake.nix` exposes exactly two checks, both about Wayland, and both scoped so
that host integration only runs on `x86_64-linux`
([flake.nix#L126-L144](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/flake.nix#L126-L144)).
Nothing under `checks` covers Darwin, and no configuration is exposed as a
check attribute.

The two tests that exist are good models. `wayland-compositors.nix` is 427
lines that assert against a contract attrset and then `grep -F` the generated
script bodies inside a derivation.
`wayland-session-lifecycle.nix` stubs commands with exported bash functions
and `diff -u`s an expected event log
([lib/tests/wayland-session-lifecycle.nix#L1-L42](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/lib/tests/wayland-session-lifecycle.nix#L1-L42)).
That is the nix-darwin `release.nix` style our doc already points at, applied
to a personal repo.

### `nix flake check` is deliberately not used

The `just check` recipe replaces it, and the comment explains why:

> `nix flake check` deep-evaluates the flat *Configurations attrsets for
> every platform regardless of --systems (flat attrsets are not per-system),
> which triggers cross-platform catppuccin IFD on this host. Scope the check
> to the native platform's configurations plus this system's per-system
> outputs instead. Foreign-platform configurations are covered by CI runners
> ([justfile#L140-L172](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/justfile#L140-L172)).

The recipe enumerates configurations itself and evaluates a drvPath per
config, gated on the native platform:
`nix eval .#darwinConfigurations.${config}.system.drvPath --raw` only when
`uname -s` is `Darwin`.

### The build matrix

CI does the real coverage, and it is dynamic. An `inventory` job runs
`flake-inventory.sh`, which enumerates devshells, packages,
`nixosConfigurations`, `darwinConfigurations`, and `homeConfigurations` from
the flake, resolves each one's `stdenv.hostPlatform.system`, and maps it to a
runner through a hardcoded table
([flake-inventory.sh#L15-L18](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/scripts/flake-inventory/flake-inventory.sh#L15-L18)).
Downstream jobs consume that as a matrix.

| Job | Build command |
| --- | --- |
| `nixos` | `nix build ".#nixosConfigurations.<name>.config.system.build.toplevel"` |
| `darwin` | `nix build ".#darwinConfigurations.<name>.config.system.build.toplevel"` on `macos-latest` |
| `homes` | `nix build ".#homeConfigurations.\"<name>\".activationPackage"` |
| `packages`, `devshells` | `nix build ".#<attr>"` per target |
| `release` | ISO image for one host |

Sources:
[builder.yml#L280](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/.github/workflows/builder.yml#L280),
[#L306-L308](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/.github/workflows/builder.yml#L306-L308),
[#L347](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/.github/workflows/builder.yml#L347).
Every job uses `DeterminateSystems/determinate-nix-action@v3` and
`flakehub-cache-action@v3`, and a `publish` job pushes the results to FlakeHub
Cache so that `just apply` can fetch a prebuilt closure instead of evaluating
locally
([README.md#L288-L297](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/README.md#L288-L297)).

### The cheap non-Nix gate

A separate `checker.yml` workflow lints the TOML registries against committed
JSON Schemas with `taplo lint --schema file://...`, triggered on schedule and
on pushes to `lib/**.toml` or `lib/**-schema.json`
([checker.yml#L1-L28](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/.github/workflows/checker.yml#L1-L28)).
A malformed or mistyped host row fails in seconds without a Nix evaluation.

### Anything Darwin-specific

Only the `darwin` job, and it is currently skipped for want of a host. There
is no macOS VM lane, no equivalent of our Tart runbook, and no activation
testing anywhere. The README's "Post-install Checklist" is the honest
acknowledgement of what the automation does not cover: 30-odd manual items
across secrets, accounts, system, and themes
([README.md#L339-L360](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/README.md#L339-L360)).

## 5. Compare And Contrast With Our Target-State Doc

### Composition model: app modules yes, roles no

Our doc says: "The unit is the app module ... A role module imports app
modules. A host imports roles plus host-only exceptions." The first half is
strongly supported here. `agentic/claude-code` owns Claude's package,
settings, hooks, LSP contributions, statusline config, and its activation
edge, in one directory. Twelve sibling directories do the same for other
agent CLIs. That is our design, running at scale.

The second half is contradicted by a working 21-host repo. There is no role
layer. Instead every module is imported unconditionally and self-gates on
typed metadata
([README.md#L64-L66](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/README.md#L64-L66)).
The tradeoff is real in both directions and we should name it rather than
pick silently:

| | Roles (our doc) | Broadcast-and-gate (this repo) |
| --- | --- | --- |
| Adding an app | Edit the app module and one role | Drop a directory, edit nothing |
| Reading "what does host X get" | Read the host's import list | Read every module's gate |
| Evaluation cost | Only imported modules | Every module, every host |
| Failure mode | Forgot to add to a role, app missing | Wrong gate, app silently absent or present |

**Should our doc change?** Yes, narrowly. Our doc presents the role layer as
the obvious consequence of app modules, citing SrvOS and nixos-hardware. It
should acknowledge broadcast-and-gate as a live alternative and say why we are
not taking it. My read is that we should keep roles: our four hosts differ
along axes (root availability, MDM, headlessness) where "silently absent" is a
much worse failure than an edited import list, and we have four hosts, not
twenty-one.

### Typed options do not replace the data layer

Our doc claims: "Typed options replace the data layer ... A host that imports
`roles.work` and `apps.claude-code` has no five-layer list to merge."

This repo is evidence against the strong form of that claim. It has both. The
registry is still TOML, still read with `builtins.fromTOML`, and still
layer-merged before the module system sees it
([flake.nix#L87-L90](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/flake.nix#L87-L90),
[flake-builders.nix#L18-L52](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/lib/flake-builders.nix#L18-L52)).
The typed layer sits *downstream* of the merge, not in place of it, and its
job is validation, derivation, and overridability. `lib/noughty/README.md`
gives three reasons for keeping TOML: the registry is reusable by non-Nix
consumers, it is consumable by non-Nix tooling, and `builtins.fromTOML` has
been stable since Nix 2.3.

The order matters more than the format. Because the layer merge happens in
plain Nix with `//`, list-valued fields are replaced wholesale. Our concept
map's row 8 flags exactly this as the named gap in the module-priority
approach: "Lists merge by concatenation in the module system, so `groups`
needs a scalar-like type or per-layer `mkOverride` to keep replace semantics."
Merging before the module system makes that gap disappear.

**Should our doc change?** Yes. Row 8 should gain the "merge in Nix, then feed
typed options" option as a third path alongside module priorities, and the
"What disappears" row for `machines*.toml` should soften from "Gone" to
"optionally retained as validated input data".

### The "what disappears" table

| Our row | This repo | Verdict |
| --- | --- | --- |
| `features.tmpl` resolver and layered `machines*.toml` gone | Kept, as `resolveEntry` plus TOML registries plus a JSON Schema | Contradicts the strong form |
| Cask gates and `package-cask-enabled.tmpl` gone | Gone. Literal cask list gated with `lib.optionals` | Supports |
| Group union and unknown-group validation become `assertions` | Became `taplo lint` against a JSON Schema in CI | Alternative, and cheaper |
| `run_onchange_` hash lines gone, replaced by `onChange` | `onChange` used zero times; unconditional activation blocks instead | Alternative |
| `run_once_` bootstrap becomes a one-time migration script | Became a README checklist for a human | Alternative |
| Brewfile renderer and golden tests gone | Gone | Supports |
| Drift banner gone, replaced by closure diffs | `nvd diff` after every apply | Supports |
| Plist modify stubs gone for domains written through `defaults` | Gone; `CustomUserPreferences` only | Supports (unexercised) |
| Plist quit guard narrows | Absent entirely | No evidence |

The `onChange` row deserves attention. Our row 19 rates `onChange` as "full"
fidelity for `run_onchange_`. A 382-file production repo with 15 side-effect
blocks reaches for it zero times. The likely reason is structural: side
effects here depend on several inputs at once, or on a package version, not on
one file's content, so there is no single `home.file` to hang the hook off.
Our own `run_onchange_` scripts have the same shape. We should downgrade row
19's practical usefulness even if the mechanism works as documented.

### The per-app ownership table

This is where the repo is most valuable, because it manages the same apps.

| App | Our doc's native decision | What he actually did | Implication |
| --- | --- | --- | --- |
| Claude Code | Hooks, permissions, marketplace move to a managed drop-in; merger splits | No managed drop-in. `programs.claude-code.settings` for settings.json, plus a `jq` activation merge into `~/.claude.json` | Add a row: the runtime file is a separate problem from settings.json |
| Codex | `/etc/codex/config.toml` as the system layer; merger disappears | No system layer. Generate TOML in the store, deploy as a real file via a Python merger | The system layer solves content, not file shape |
| agentsview | Reconciler stays for the dynamic source list; env vars where they suffice | No config file managed at all. `makeWrapper` sources a sops-rendered env file | A fourth strategy our tiers omit |
| pi | Global merge stays | No merge. `sops.templates` writes `~/.pi/agent/mcp.json` outright; `home.file` for models.json | Whole-file ownership worked for the parts he manages |
| Orca, crit, Cursor, Yojam | Mergers stay | Not managed | No evidence |

Two corrections our doc should absorb.

First, the Codex row is too optimistic. Our doc says the merger disappears
because `/etc/codex/config.toml` sits below the user file. That is true about
*precedence*, but it does not address the fact that `~/.codex/config.toml`
must still exist as a writable regular file, and that a home-manager symlink
there is actively harmful because Codex follows the chain into the read-only
store
([codex#L572-L577](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/agentic/codex/default.nix#L572-L577)).
The system layer removes the *need to merge our defaults into* the user file.
It does not remove the need to keep that path un-symlinked. Our table should
say so.

Second, the Claude row is incomplete. Even with a first-class home-manager
module and a managed drop-in available, at least one setting has to be merged
into `~/.claude.json` because `settings.json` schema-validates and rejects it.
Our per-app table treats Claude as one file. It is two.

The agentsview finding argues for adding a **tier 0** to Problem A: *do not
own the file; own the process environment*. Wrap the binary, inject
configuration through env vars or an env file, and let the app keep sole
ownership of its config. It costs a wrapper derivation and works only for
settings the app reads from the environment, but where it applies it removes
the merge entirely. Our per-app table already notes "environment variables
where they suffice" for agentsview; this repo shows that being taken all the
way, including for the credential.

### Problem A: files the app also writes

Verdict: our analysis is right, and the escape hatch we plan on is the one
this repo actually lives in. Fourteen of fifteen activation blocks exist to
work around the store-symlink model. None of the app-native managed layers our
doc hopes for are in use.

Two things our doc does not cover, both worth adding.

1. **A store symlink can be unreadable, not just unwritable.** `codex-rs`
   discovers skills with `file_type().is_file()`, which is false for a symlink
   on Linux, so `home.file`-placed `SKILL.md` files are simply not found
   ([assistants#L654-L659](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/agentic/assistants/default.nix#L654-L659)).
   Our Problem A frames the risk as "the app replaces the symlink and the next
   switch refuses". This is a different and quieter failure: the app never
   sees the file at all, and nothing errors.
2. **The `run` discipline is easy to lose.** Our tier 3 design specifies
   wrapping the mergers in `run` so `DRY_RUN` prints instead of writing. In
   this repo only 1 of 15 blocks does. If we build a
   `dotfiles.merges.<target>` option as planned, the wrapper should be part of
   the option's implementation, not something each call site remembers.

### Problem B: the MDM-managed work Mac

Almost no direct evidence. There is no MDM, no Jamf, and no corporate policy
anywhere in this repo, and the Mac is disabled.

Three adjacent data points.

- Root per switch is confirmed, and so is the mitigation our doc names.
  `sudo fh apply` for the host config
  ([justfile#L430-L436](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/justfile#L430-L436)),
  `touchIdAuth` for the prompt
  ([darwin/default.nix#L109](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/darwin/default.nix#L109)),
  and a separate no-root Home Manager lane
  ([README.md#L266-L271](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/README.md#L266-L271)).
  The two-lane split is exactly our doc's "Two target shapes" table made
  operational: he runs the standalone-HM shape most days and the root shape
  when the system layer changes.
- `modules/nixos/falcon-sensor.nix` packages CrowdStrike Falcon on NixOS. The
  header states that Falcon "is a proprietary binary that cannot be packaged
  declaratively" and bootstraps it to `/opt/CrowdStrike` outside the store,
  with a staged-update script that runs at boot before tamper protection arms
  ([falcon-sensor.nix#L1-L47](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/modules/nixos/falcon-sensor.nix#L1-L47)).
  This is weak evidence that a corporate endpoint agent and a Nix machine can
  coexist, but it is Linux, self-installed, and says nothing about whether
  Falcon on macOS tolerates a `/nix` APFS volume. Our open question 3 stands
  unchanged.
- FlakeHub Cache is a shape our doc does not consider for the work Mac. CI
  builds every configuration on a matching runner and publishes it; `just
  apply` then fetches the prebuilt closure and activates it, "completely
  skipping local Nix evaluation and compilation"
  ([README.md#L288-L297](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/README.md#L288-L297)).
  On a locked-down machine where you would rather not run a local builder,
  that reduces the on-box operation to a fetch and an activation. Worth adding
  to the Problem B options.

### Problem C: secrets without store leakage

This repo is the clearest available example of the option our doc ranked
third and declined. It commits 52 encrypted files to a public repo, uses four
age recipients split between user and host keys, and keeps an unencrypted age
key at `~/.config/sops/age/keys.txt` on every machine
([home-manager/default.nix#L223-L232](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/default.nix#L223-L232),
[.sops.yaml#L20-L32](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/.sops.yaml#L20-L32)).
Every mechanical claim in our sops-nix row checks out.

Three things our doc should add.

1. **`sops.templates` is a better fit for our license files than our doc
   implies.** Our row 37 and Problem C frame the choice as "where does the
   secret get decrypted". The sharper question for our three license files is
   "what writes a whole file whose content is a secret, at a chosen path, with
   mode 0600". `sops.templates` does exactly that in one declaration
   ([agentsview#L31-L39](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/agentic/agentsview/default.nix#L31-L39)).
   Under our recommended `op read` route we would hand-roll the same thing in
   an activation block. That is a fair trade, but the doc should name it.
2. **sops-nix has a real per-switch maintenance cost.** He needs an activation
   block that force-restarts the service on Linux because "the unit is a store
   symlink" and a stale daemon left templates rendering old content
   ([home-manager/default.nix#L51-L63](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/default.nix#L51-L63)),
   and a `lib.mkForce` PATH override on the Darwin agent
   ([home-manager/default.nix#L234-L240](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/default.nix#L234-L240)).
   Our sops-nix row lists the policy cost but not the operational one.
3. **No evidence for or against our first choice.** He does not use
   1Password from Nix at all. Our recommendation of `op read` in activation
   for interactive Macs remains unvalidated by any repo surveyed so far.

Our doc's conclusion stands: this is a policy decision, not a technical one,
and this repo does not present a reason to change ours.

### The test surface

Three findings, one of which challenges our doc.

**Supported.** Our doc's model of what module tests look like matches his: a
contract attrset, `grep -F` over generated script text, stubbed commands, and
a diffed event log
([lib/tests/wayland-session-lifecycle.nix#L1-L42](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/lib/tests/wayland-session-lifecycle.nix#L1-L42)).

**Supported, differently implemented.** Our doc says every host must be
enumerated explicitly because `nix flake check` will not reach
`darwinConfigurations` or `homeConfigurations`, and recommends exposing them
as `checks.<system>.<host>`. He reaches the same conclusion about enumeration
but implements it in CI rather than in `checks`, with one job per
configuration and a runner selected from the configuration's own
`hostPlatform.system`
([flake-inventory.sh#L199-L222](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/scripts/flake-inventory/flake-inventory.sh#L199-L222)).
That is better than our proposal for two reasons: per-host job granularity in
the CI UI, and correct cross-platform runner assignment without a second
mapping to maintain.

**Challenged.** His `just check` comment says the opposite of our doc about
`nix flake check` behavior: that it "deep-evaluates the flat *Configurations
attrsets for every platform regardless of --systems"
([justfile#L144-L148](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/justfile#L144-L148)).
Our doc, citing the pinned `flake-check.md`, says it "does not touch
`darwinConfigurations` or `homeConfigurations`". Both could be true of
different Nix versions; this repo runs Determinate Nix, which our doc's source
does not describe. This is not resolved here and should not be asserted either
way in our doc without a direct test. It matters: if `flake check` already
deep-evaluates flat attrsets, our recommendation to add
`checks.aarch64-darwin.<host>` is redundant, and the real hazard is the
opposite one he hit, cross-platform evaluation triggering IFD on the wrong
machine.

**One gap our doc should note.** Neither `checks` nor CI proves activation.
His answer is a 30-item manual post-install checklist
([README.md#L339-L360](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/README.md#L339-L360)).
Our Tart lane is a genuine advantage over the best-maintained repo in this
class, and the doc should say so rather than treating Tart as a cost.

### Open questions this answers or reframes

| # | Question | What this repo says |
| ---: | --- | --- |
| 1 | Does Claude Code accept a `directory` marketplace of store symlinks, and do plugin hooks keep their bits? | Reframed and half-answered. For Codex, symlinked `SKILL.md` files are invisible because `codex-rs` uses `file_type().is_file()`; symlinked *directories* beside them are fine. Split the question by CLI, and ask about discovery, not just permissions |
| 2 | Does a running app overwrite a `defaults` write? | No evidence. The Mac is disabled |
| 3 | Does the endpoint agent tolerate `/nix`? | Weak adjacent evidence only, from a Linux CrowdStrike module |
| 7 | Is Homebrew fully declarative per host? | He chose `cleanup = "zap"` plus `autoUpdate` and `upgrade` on a personal Mac. Viable there. Note the combination makes the *set* declarative but the *versions* unpinned |
| 8 | Does `ray build` work in a derivation? | No evidence |
| 9 | Which Claude keys belong in a managed drop-in? | Unanswered, but a new constraint appears: some keys cannot go in `settings.json` at all because it schema-validates, and must go to `~/.claude.json` |
| 10 | Which Codex defaults belong in `/etc/codex/config.toml`? | Unanswered. He uses neither system nor managed layer |
| 11 | Which plist domains are safe for whole-domain import? | He avoided the question by using key-level `CustomUserPreferences` for everything |
| 14 | Which apps allow disabling persistence so Nix owns the file? | His Codex merger scrubs all runtime state by default and keeps an allowlist hook returning `{}`. Owning the whole file works if you accept losing runtime keys, and the allowlist is the seam for changing your mind later |

New question this repo raises: does `nix flake check` deep-evaluate flat
`*Configurations` attrsets under Determinate Nix? Our test-surface plan is
written against the answer being no.

## 6. What To Take, What To Avoid, Relevance

### Take

1. **A JSON Schema over the machine registry, linted in CI.** `taplo lint
   --schema file://...` on push to the registry path
   ([checker.yml#L1-L28](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/.github/workflows/checker.yml#L1-L28)).
   This is worth doing to `home/.chezmoidata/machines.toml` **today**,
   independent of any Nix decision. It costs one workflow and one schema file
   and it catches typed-field errors that currently only surface at render
   time.
2. **Merge machine layers in code, then feed typed options.** `resolveEntry`
   is 35 lines and dissolves row 8's list-merge problem
   ([flake-builders.nix#L18-L52](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/lib/flake-builders.nix#L18-L52)).
   It also means the registry stays readable by non-Nix tooling, which we care
   about because scripts under `scripts/` read `machines.toml` today.
3. **Discover the CI matrix from the flake.** One job per configuration, with
   the runner chosen from each configuration's own platform
   ([flake-inventory.sh#L199-L222](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/scripts/flake-inventory/flake-inventory.sh#L199-L222)).
   Better than a hand-maintained matrix and better than one big `flake check`.
4. **Tier 0 for Problem A: wrap the binary, own the environment.** The
   agentsview module manages no config file
   ([agentsview#L14-L43](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/home-manager/_mixins/agentic/agentsview/default.nix#L14-L43)).
   Check each of our six surviving mergers against this before writing a
   merger for it.
5. **`nvd diff` after apply.** Cheap partial answer to row 38's lost drift
   banner
   ([justfile#L430-L436](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/justfile#L430-L436)).
6. **Scheduled freshener PRs.** Thirteen per-package updater scripts on a
   twice-weekly cron, each opening a pull request
   ([freshener.yml#L12-L16](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/.github/workflows/freshener.yml#L12-L16), [#L31-L68](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/.github/workflows/freshener.yml#L31-L68)).
   This is the concrete form of "freshness becomes a lock bump you review",
   which our "What Stays Outside Nix" section leaves abstract.
7. **His two hazard comments, verbatim, in our design notes.** The Codex
   symlink-chain note and the `is_file()` discovery note are the kind of thing
   you only learn by shipping.
8. **Split the apply lanes.** `just host` (root) and `just home` (no root) as
   separate commands, with `just apply` for the cache path
   ([README.md#L264-L274](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/README.md#L264-L274)).
   On the work Mac this is the difference between needing Jamf and not.

### Avoid

1. **Broadcast-and-gate, for us.** It is a good fit for 21 similar Linux
   workstations owned by one person. Our hosts differ on the axes where a
   silent gating mistake is expensive, and "every module evaluated by every
   host" is a worse deal at four hosts than at twenty-one. Keep explicit
   imports.
2. **Committing encrypted secrets to a public repo.** He does it at scale and
   it works. Our "op:// refs only" policy is a deliberate choice, and nothing
   here argues against it.
3. **`cleanup = "zap"` with `autoUpdate` and `upgrade` on the work Mac.**
   Zap is stronger than `uninstall`, and it will remove IT-installed casks
   that are not in the generated Brewfile
   ([darwin/default.nix#L46-L53](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/darwin/default.nix#L46-L53)).
   Per-host policy, as our row 11 already says.
4. **Letting a host exist only in the registry.** The Mac here has been
   uncompiled since June and its files kept changing until July
   ([registry-systems.toml#L410-L426](https://github.com/wimpysworld/nix-config/blob/e2ca3b06484541d0349df60990a3ec2d470b44c3/lib/registry-systems.toml#L410-L426)).
   He handled it honestly by commenting the entry out so CI would not lie. The
   lesson for us: a host declared but never built accumulates rot fast, and
   the honest move is to delete or disable it, not to leave a green CI badge
   over an unbuilt config.
5. **Activation blocks that skip `run`.** Fourteen of fifteen here would write
   during a dry run. Build the wrapper into our merge option so it cannot be
   forgotten.

### Relevance: 4 out of 5

Highest-value repo surveyed so far for our specific problem, with one large
caveat.

Reasons it scores high. It manages the same applications we do, including
Claude Code, Codex, and agentsview, in more depth than we do, and it has hit
Problem A three separate times with three different answers, each documented
in a comment that explains *why*. It runs nix-darwin plus home-manager plus
nix-homebrew plus Determinate plus sops-nix, which is the exact stack our doc
evaluates. Its CI actually builds configuration closures on matching runners.
Its author writes down his composition model and defends it, so we can compare
designs rather than reverse-engineer one. And its `just check` recipe
independently arrived at our conclusion that `nix flake check` is the wrong
instrument, which is a useful corroboration even though the stated reason
differs from ours.

Reasons it does not score 5. The macOS half is design evidence only: the sole
Darwin host has been commented out for roughly three months, so no `defaults`
write, no cask install, no launchd bootstrap, and no activation on macOS has
been exercised at this sha. There is no MDM, no managed enterprise Mac, and no
1Password, which are three of our hardest constraints. And the host shape is
the opposite of ours, 21 similar Linux boxes rather than four dissimilar
machines, so the composition lesson needs discounting before we apply it.

## 7. Scorecard Against Our Concept Map

Rows from Appendix A of [the target-state doc](../nix-target-state-research.md).
Only rows where this repo provides actual evidence are listed. Notes are five
words.

| Row | Verdict | Note |
| ---: | --- | --- |
| 1 | Alternative | Program modules replace raw files |
| 2 | Supports | sops templates carry file mode |
| 5 | Supports | Typed metadata replaces Go templates |
| 6 | Supports | One flake attribute per host |
| 8 | Alternative | Merge in Nix before modules |
| 9 | Supports | Literal cask list, no renderer |
| 10 | Supports | home.packages plus environment.systemPackages |
| 11 | Supports | Chose zap, strongest cleanup setting |
| 13 | Supports | nix-homebrew autoMigrate, mutable taps kept |
| 16 | Supports | mkIf gating is the architecture |
| 17 | Supports | Casks gated by module condition |
| 19 | Alternative | onChange unused; unconditional activation instead |
| 20 | Alternative | README checklist replaces once scripts |
| 21 | Supports | entryAfter, entryBetween, named sops dependency |
| 23 | Supports | CustomUserPreferences only, no plist stubs |
| 24 | Alternative | Activation mergers, no managed layers |
| 26 | Supports | Typed defaults plus CustomUserPreferences |
| 27 | Supports | TouchID sudo, root per switch |
| 28 | Supports | launchd.agents used, Darwin gated |
| 29 | Contradicts | Symlinked SKILL.md invisible to codex |
| 33 | Supports | programs.gh extensions declared per language |
| 35 | Alternative | Fish login shell, zsh secondary |
| 36 | Supports | xdg.configHome used throughout modules |
| 37 | Alternative | sops-nix templates, no 1Password |
| 38 | Supports | nvd diff after every apply |
| 40 | Alternative | Activation writes sidestep clobber check |
| 42 | Alternative | CI builds closures per host |
