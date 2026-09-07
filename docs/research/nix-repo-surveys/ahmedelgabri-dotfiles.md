---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-04
updated: 2026-09-04
related:
  - ../nix-target-state-research.md
  - ../nix-migration-research.md
status_detail: "Agent survey of ahmedelgabri/dotfiles at df5a0d3531d6e3c73d5cbc3e79f1e1521377805c, compared with the Nix target-state doc. Unreviewed."
---

# Survey: ahmedelgabri/dotfiles

## Method

Surveyed at commit `df5a0d3531d6e3c73d5cbc3e79f1e1521377805c`, fetched 2026-09-04 as a
GitHub tarball and extracted to a scratch directory. Every citation below points at that
sha. Permalinks use the form
`https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/<path>#L<n>-L<m>`.

Files opened in full: `flake.nix`, `AGENTS.md`, `CLAUDE.md`, all of `nix/parts/flake/`,
`nix/parts/hosts/`, `nix/parts/modules/base/`, `nix/parts/modules/darwin/`,
`nix/parts/outputs/`, `nix/secrets/secrets.nix`, both GitHub workflows, and
`scripts/aarch64-darwin_bootstrap`. Files opened in full from `nix/parts/modules/shared/`:
`agenix.nix`, `ai.nix`, `ghostty.nix`, `git.nix`, `gui.nix`, `jujutsu.nix`, `kitty.nix`,
`misc.nix`, `node.nix`, `python.nix`, `user-shell.nix`. Read in part: `mail.nix` (activation,
launchd, secret lookup, and file-generation sections) and `README.md` (layout, install,
Homebrew, machine-local config, secrets, and contributor sections). Read for the include
wiring only: `config/git/config`, `config/ghostty/config`, `config/kitty/kitty.conf`,
`config/claude/settings.json`.

Counts came from `find` over the extracted tree. Stars, creation date, license, and weekly
commit activity came from the GitHub API at the same time.

Compared against `../nix-target-state-research.md` in full, the Options and Sizing sections
of `../nix-migration-research.md`, and `../../references/chezmoi-architecture.md`.

## 1. What It Is

Ahmed El Gabri's personal dotfiles. The repo was created 2013-02-02 and has 291 stars under
the Unlicense. It predates its Nix content by years, so this is a plain dotfiles repo that
adopted Nix, not a greenfield Nix configuration. That is the same starting position we are in.

The author works at Miro. The work host sets `my.email = "ahmed@miro.com"` and
`my.company = "Miro"`
([rocket/default.nix#L13-L22](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/hosts/rocket/default.nix#L13-L22)).

| Fact | Value |
| --- | --- |
| Platforms | `aarch64-darwin` and `x86_64-linux` ([flake/default.nix#L50-L58](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/flake/default.nix#L50-L58)) |
| Hosts | 3: `rocket` (work Mac), `alcantara` (personal Mac), `nixos` (VM, no hardware) ([flake/default.nix#L39-L48](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/flake/default.nix#L39-L48)) |
| `.nix` files | 61 total: 51 under `nix/`, 9 under `templates/`, 1 at the root |
| Files under `config/` | 274, all checked in |
| Flake inputs | 20 ([flake.nix#L1-L136](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/flake.nix#L1-L136)) |
| VCS | Jujutsu, not git ([AGENTS.md#L28-L31](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/AGENTS.md#L28-L31)) |

Activity is real. Commit counts for the last twelve weeks are 16, 18, 0, 39, 49, 0, 0, 37,
151, 3, 11, 6. Last push was 2026-09-02, two days before this survey.

Lock bumping is manual and human-triggered. There is no dependabot or flake-update bot. The
author runs a shell helper, `nixup`, which does `nix flake update` in the dotfiles directory
followed by a project-specific regeneration step
([user-shell.nix#L175-L183](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/user-shell.nix#L175-L183)).
The resulting commits are titled `chore(nix): update flake inputs` and land roughly every one
to three weeks. One input, `treefmt-nix`, exists purely as a dedup anchor so that the inputs
below it follow it instead of each locking their own copy
([flake.nix#L20-L28](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/flake.nix#L20-L28)).

## 2. Composition

### The nix/ and config/ split

`nix/` holds the logic. `config/` holds the actual dotfiles, checked in verbatim as plain
files. The README states the split directly, and `AGENTS.md` states the linking rule:
"Application configs in `config/` are checked into the repo and symlinked into place by Home
Manager"
([AGENTS.md#L12-L17](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/AGENTS.md#L12-L17)).

The flake is flake-parts. `flake.nix` delegates all output construction to one module
([flake.nix#L137-L138](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/flake.nix#L137-L138)).
That module imports every other module and host file by explicit path, with no directory
auto-import
([flake/default.nix#L1-L48](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/flake/default.nix#L1-L48)).

### The feature registry

Composition runs through one file. `lib.nix` declares a typed flake option
`flake.modules.<runtime>.<name>`, where runtime is `generic`, `darwin`, `nixos`, or
`homeManager`
([lib.nix#L15-L18](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/flake/lib.nix#L15-L18)).
Every feature module registers itself into that namespace. A resolver then picks the
runtime-specific module, falling back to the generic one, falling back to a home-manager-only
wrapper, and finally `throw "unknown feature: ${name}"`
([lib.nix#L45-L57](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/flake/lib.nix#L45-L57)).

`commonFeatures` is a flat list of 28 names that every host enables, with the comment "Single
source of truth for the features every host enables, so a new feature only needs to be added
once"
([lib.nix#L75-L103](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/flake/lib.nix#L75-L103)).
`mkFeatureModule` turns that list into system imports plus a nested
`home-manager.users.<user>.imports`
([lib.nix#L130-L141](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/flake/lib.nix#L130-L141)).

There is no role layer. A host file supplies only its own deltas. `mk-host.nix` does all the
wiring and adds `defaults` as an extra feature on Darwin
([mk-host.nix#L1-L51](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/hosts/mk-host.nix#L1-L51)).

### Which files are links and which are generated

This is the most important finding. The default is an out-of-store symlink into the working
checkout, and it is applied at scale by a custom helper,
`config.lib.file.mkOutOfStoreTree`
([base/home-manager.nix#L26-L51](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/base/home-manager.nix#L26-L51)).
It takes a `source` directory, walks it with `lib.filesystem.listFilesRecursive` at evaluation
time, and emits one `mkOutOfStoreSymlink` per file pointing at the absolute checkout path. Its
comment states the intent: "Keep destination directories writable while making each managed
file live-editable from the dotfiles checkout"
([base/home-manager.nix#L30-L31](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/base/home-manager.nix#L30-L31)).

The per-file rather than per-directory choice matters. The destination directory stays a real
writable directory, so an app can create files next to the managed ones without fighting a
directory symlink.

There are 23 `mkOutOfStoreTree` call sites and 19 additional direct `mkOutOfStoreSymlink`
sites across `nix/`. Against that, only 19 `.text =` generated files. So yes: edits to
`~/.dotfiles/config/**` are live with no rebuild. Store-backed content is the exception,
reserved for values Nix must compute, such as store paths, identity strings, and package
versions.

Home Manager itself is used as a system module with `useGlobalPkgs`, `useUserPackages`, and
`backupFileExtension = "bk"`
([base/home-manager.nix#L22-L25](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/base/home-manager.nix#L22-L25)).
Home Manager's `programs.*` config generators are essentially unused. There is no
`programs.git`, no `programs.tmux`, no HM `programs.zsh`. Only `programs.home-manager`,
`programs.man`, the nix-darwin `programs.zsh`, and `programs.gnupg` appear anywhere in `nix/`.

### Where identity lives

In one typed options block, `options.my`, holding name, timezone, username, website, GitHub
username, email, company, dev folder, a `nix_managed` banner string, host name, host config
home, dotfiles dir, and a module registry
([base/identity.nix#L1-L36](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/base/identity.nix#L1-L36)).
There are no TOML or JSON data files anywhere in the repo. `my.user` is an alias onto
`users.users.<username>` so the same attribute works on Darwin and NixOS
([base/user.nix#L9-L14](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/base/user.nix#L9-L14)).

Identity crosses into Home Manager through `extraSpecialArgs.myConfig`
([base/home-manager.nix#L52-L67](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/base/home-manager.nix#L52-L67)).

### Work versus personal

Expressed only as per-host overrides, not as a type or role. `rocket` sets the Miro identity,
a work mail account, host-only packages, and its own taps, casks, and brews
([rocket/default.nix#L13-L73](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/hosts/rocket/default.nix#L13-L73)).
`alcantara` sets personal identity, `networking.hostName`, and personal casks
([alcantara/default.nix#L1-L52](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/hosts/alcantara/default.nix#L1-L52)).
Both import the identical 28-feature list.

`rocket` is Kandji-managed and the repo says so, with a comment explaining that it declares no
`networking.hostName` at all because "Kandji owns this machine's names (its Device Name
enforcement resets ComputerName to the serial number at every check-in)"
([rocket/default.nix#L6-L9](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/hosts/rocket/default.nix#L6-L9)).
The logical host name comes from `my.hostName`, set by `mk-host`, and the option's own comment
says it is "Deliberately decoupled from networking.hostName: an MDM may own the machine's real
names, so no configuration should key off them"
([base/identity.nix#L22-L25](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/base/identity.nix#L22-L25)).
The logical name is then published as a plain file for GUI apps that inherit neither shell env
nor a reliable machine name
([base/home-manager.nix#L79-L82](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/base/home-manager.nix#L79-L82)).

## 3. Per-App Config Mechanics

### The dominant idiom: verbatim tree plus generated fragment plus app include

Four apps use the same three-part shape. A verbatim tree is linked out of store, a small Nix
fragment is generated into the store, and the app's own include mechanism joins them. A third
slot is left for a machine-local file the repo never sees.

| App | Verbatim tree | Generated fragment | Joined by | Machine-local slot |
| --- | --- | --- | --- | --- |
| git | `config/git/**` ([git.nix#L36-L46](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/git.nix#L36-L46)) | `git/config-nix` ([git.nix#L48-L73](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/git.nix#L48-L73)) | `[include] path = config-nix` ([config/git/config#L298-L300](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/config/git/config#L298-L300)) | `[include] path = $HOST_CONFIGS/gitconfig` ([git.nix#L71-L73](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/git.nix#L71-L73)) |
| jujutsu | `config/jj/**` ([jujutsu.nix#L27-L32](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/jujutsu.nix#L27-L32)) | `jj/conf.d/nix.toml` ([jujutsu.nix#L33-L52](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/jujutsu.nix#L33-L52)) | jj's native `conf.d` drop-in directory | none |
| ghostty | `config/ghostty/**` ([ghostty.nix#L25-L30](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/ghostty.nix#L25-L30)) | `ghostty/config.nix.local` ([ghostty.nix#L31-L34](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/ghostty.nix#L31-L34)) | `config-file = ?config.nix.local` ([config/ghostty/config#L31-L32](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/config/ghostty/config#L31-L32)) | `config-file = ?config.local` (same lines) |
| kitty | `config/kitty/**` ([kitty.nix#L43-L47](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/kitty.nix#L43-L47)) | `kitty/nix.conf` ([kitty.nix#L52-L54](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/kitty.nix#L52-L54)) | `include nix.conf` ([config/kitty/kitty.conf#L61](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/config/kitty/kitty.conf#L61)) | `include kitty-local.conf` ([config/kitty/kitty.conf#L128-L129](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/config/kitty/kitty.conf#L128-L129)) |

The generated fragment is always tiny and always carries something only Nix knows: a store
path for a shader, a computed socket path, identity strings, or a `plutil` binary path. Note
that git's fragment keeps a Darwin-only plist textconv,
`textconv = plutil -convert xml1 -o -`
([git.nix#L67-L69](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/git.nix#L67-L69)).

`python.nix` uses three merged trees for python, pip, and uv
([python.nix#L38-L52](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/python.nix#L38-L52)).
`misc.nix` live-links four bare dotfiles
([misc.nix#L10-L17](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/misc.nix#L10-L17)).

### Files the app rewrites

Four cases, three handled by handing the file to the app.

Karabiner gets a whole-directory out-of-store symlink with an explicit rationale: "Karabiner
mutates its config from the GUI, so keep this as a live symlink instead of deploying it as an
immutable Home Manager file"
([karabiner.nix#L13-L19](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/karabiner.nix#L13-L19)).
Hammerspoon uses the identical shape
([hammerspoon.nix#L13-L19](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/hammerspoon.nix#L13-L19)).

Claude Code's `~/.claude/settings.json` is a live symlink to `config/claude/settings.json`
([ai.nix#L200-L205](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/ai.nix#L200-L205)).
The committed file carries `permissions`, 24 hook entries, a `statusLine`, and also
`enabledPlugins` and `extraKnownMarketplaces`
([config/claude/settings.json#L325-L340](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/config/claude/settings.json#L325-L340)),
which is state Claude Code itself writes on plugin install. So plugin installs land as working
tree diffs. `CLAUDE.md` is the same shape, a live symlink to a template
([ai.nix#L200-L202](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/ai.nix#L200-L202)).
The Claude subtrees for skills, agents, docs, commands, hooks, and scripts go through
`mkClaudeTree`, which maps them into both `.agents/` and `.claude/`
([ai.nix#L127-L133](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/ai.nix#L127-L133)).

The fourth case is the only one where Nix insists on owning the file, and it does so by
overwriting. The pi agent's settings are computed as `fromJSON` of a committed base overlaid
with a package version and a set of computed paths
([ai.nix#L111-L116](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/ai.nix#L111-L116)),
written to a store-backed sidecar `pi/agent/settings.json.bk`
([ai.nix#L143](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/ai.nix#L143)),
and then copied over the real file by an activation block ordered after the write boundary
([ai.nix#L117-L126](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/ai.nix#L117-L126),
wired at
[ai.nix#L164](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/ai.nix#L164)).
That is a whole-file replace. Anything pi wrote to its settings since the last switch is
discarded. There are zero merge programs anywhere in the repo.

One activation script goes the other direction and symlinks a store path into the checkout, to
give a pi extension its pinned `node_modules`. It refuses to act if the target is not already
a symlink
([ai.nix#L149-L162](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/ai.nix#L149-L162)).

### macOS defaults

nix-darwin only, in two tiers, all in one file. Typed `system.defaults` domains cover
NSGlobalDomain, dock, finder, trackpad, screencapture, clock, universal access, LaunchServices,
SoftwareUpdate, and loginwindow
([darwin/default.nix#L68-L165](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/default.nix#L68-L165)).
Everything typed options do not cover goes into one large `CustomUserPreferences` block,
including third-party domains for Safari, Raycast, and Ghostty
([darwin/default.nix#L167-L267](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/default.nix#L167-L267)).

There is no plist merge tooling, no quit guard, and no delete directive. The file opens with a
validation warning worth quoting: "Invalid domains/keys will build but silently fail to apply"
and "Not all `defaults` commands have targets.darwin.defaults equivalents"
([darwin/default.nix#L5-L12](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/default.nix#L5-L12)).

One activation block runs as the user rather than root, creating the screenshots directory,
with a comment noting that a root-run activation would leave a directory `screencapture` cannot
write to
([darwin/default.nix#L276-L287](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/default.nix#L276-L287)).

### Homebrew, casks, MAS, taps

Fully declarative through nix-homebrew on both Macs, including the Kandji-managed one.
nix-homebrew installs and owns the Homebrew prefix with Rosetta support
([darwin/default.nix#L35-L39](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/default.nix#L35-L39)).
`homebrew.onActivation` sets `autoUpdate`, `upgrade`, `cleanup = "zap"`, and
`extraFlags = [ "--force-cleanup" ]`
([darwin/default.nix#L52-L57](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/default.nix#L52-L57)).
`extraEnv` pins `HOMEBREW_GIT_PATH` to the Xcode CLT git and points `SSL_CERT_FILE` and
`GIT_SSL_CAINFO` at the nixpkgs cacert
([darwin/default.nix#L41-L64](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/default.nix#L41-L64)).

Casks are contributed by the feature module that owns the app, not from a central list.
`gui.nix` contributes 13
([gui.nix#L5-L19](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/gui.nix#L5-L19)),
`karabiner.nix` contributes its own
([karabiner.nix#L9-L11](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/karabiner.nix#L9-L11)),
`ghostty.nix` contributes `ghostty@tip`
([ghostty.nix#L5](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/ghostty.nix#L5)),
and `ai.nix` contributes a cask plus a brew
([ai.nix#L216-L221](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/ai.nix#L216-L221)).
Hosts add their own on top. The README explains the retained-Homebrew reasoning: GUI apps,
"especially around symlinking into Applications/"
([README.md#L184-L195](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/README.md#L184-L195)).

Taps are declared as plain `homebrew.taps` strings on the work host
([rocket/default.nix#L51-L56](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/hosts/rocket/default.nix#L51-L56)).
nix-homebrew's immutable flake-input taps are not used.

Mac App Store is not used. `masApps` exists only as a commented-out block with the note
"Requires to be logged in to the AppStore" and "Cleanup doesn't work automatically if you
add/remove to list"
([alcantara/default.nix#L32-L43](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/hosts/alcantara/default.nix#L32-L43)).

### launchd

Two agents. `maxfiles` raises file limits
([user-shell.nix#L494-L505](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/user-shell.nix#L494-L505))
and `mailsync` runs on a 120 second interval, guarded so it only appears when local mail
accounts exist
([mail.nix#L468-L490](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/mail.nix#L468-L490)).

There is a third launchd interaction worth recording as a Nix gotcha. A Home Manager activation
block re-runs `git maintenance start --scheduler=launchctl` on every rebuild, because the
launchd plists that command writes hardcode the git binary's Nix store path, and after a git
bump plus a store GC they fail with `EX_CONFIG`
([git.nix#L76-L94](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/git.nix#L76-L94)).

### agenix on Darwin

Enabled, and deliberately near-empty. There is exactly one secret: an `.npmrc` decrypted to the
home directory at mode 600
([node.nix#L32-L39](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/node.nix#L32-L39)).
The agenix feature module contributes only a shell alias
([agenix.nix#L1-L10](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/agenix.nix#L1-L10)).

`secrets.nix` states the policy in a header comment: the author does not plan to use agenix to
store secrets or private keys because "it's not 100% safe", citing agenix's own threat model
and an upstream age issue; agenix is instead for "info that's not really secret, but I'd rather
keep it private"; and the author prefers "to regenerate keys, env vars, tokens, etc... on every
new machine"
([secrets.nix#L1-L12](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/secrets/secrets.nix#L1-L12)).
Host and user SSH public keys are committed as recipients
([secrets.nix#L23-L42](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/secrets/secrets.nix#L23-L42)).

Real credentials live in `pass` and are read at application runtime, not at activation. Mail
passwords resolve through `pass show service/email/<account>/<key>` embedded in the generated
mail configs
([mail.nix#L226](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/mail.nix#L226)).
`AGENTS.md` states the split as a rule
([AGENTS.md#L57-L61](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/AGENTS.md#L57-L61)).
A third tier exists for shell secrets: a `postActivation` script seeds `$HOST_CONFIGS/zshrc` at
mode 600 with inline guidance to fetch values from the macOS keychain rather than write
literals
([user-shell.nix#L212-L229](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/user-shell.nix#L212-L229)).

### What runs as root per switch

The whole switch. The helper is `nixsw`, which is
`sudo ... darwin-rebuild switch --flake ".#${hostName}"`
([user-shell.nix#L534-L544](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/user-shell.nix#L534-L544)).
`security.pam.services.sudo_local.touchIdAuth = true` makes that a Touch ID prompt rather than
a password
([darwin/default.nix#L30-L33](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/default.nix#L30-L33)).
A `postActivation` block additionally runs `sudo dscl . -create ... UserShell` when the login
shell drifts
([user-shell.nix#L487-L493](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/user-shell.nix#L487-L493)).
Bootstrap also needs root for Rosetta and the first switch
([scripts/aarch64-darwin_bootstrap#L30-L50](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/scripts/aarch64-darwin_bootstrap#L30-L50)).

There is no elevation dance anywhere in the repo, on either host. The author evidently holds
standing admin on the Kandji-managed work Mac.

## 4. Testing And CI

Thin. Two workflows, and only one of them tests anything.

`nix-eval.yml` is 23 lines. It triggers on push and pull request touching `flake.nix`,
`flake.lock`, or `nix/**`, plus a weekly Monday cron. It runs on `ubuntu-latest` with
`permissions: {}` and executes three commands, all `nix eval --raw` of a `drvPath`: the NixOS
toplevel, and the `system.drvPath` of each of the two Darwin configurations
([nix-eval.yml#L1-L23](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/.github/workflows/nix-eval.yml#L1-L23)).
Its header comment gives the reason: "The nixos host has no hardware exercising it, so evaluate
every system configuration in CI to catch regressions that local darwin rebuilds would never
surface"
([nix-eval.yml#L2-L4](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/.github/workflows/nix-eval.yml#L2-L4)).

Three things follow. This is evaluation, not build, so it costs a Linux runner and no macOS
minutes. Darwin configurations evaluate fine on Linux. And `nix flake check` is never invoked,
which is consistent with it not covering `darwinConfigurations`; each host is named explicitly
instead.

`claude.yml` is a `@claude` responder, not a test. Its one notable detail is that the action is
pinned to a commit sha with a comment explaining why a moving tag is not trusted
([claude.yml#L16-L18](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/.github/workflows/claude.yml#L16-L18)).

There are no unit tests, no `nmt`-style file assertions, no golden files, no formatter gate, no
shellcheck job, no Linux build, and no VM test. Formatting and spelling tools exist, but only
as devshell packages developers run by hand
([devshells.nix#L6-L31](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/outputs/devshells.nix#L6-L31),
[README.md#L399-L410](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/README.md#L399-L410)).

## 5. Compare And Contrast With Our Target-State Doc

### Composition model

Our doc's native target says an app module owns its package, its config, its cask, its defaults,
and its launchd agent together, and that the 20 cask gates collapse into imports. This repo
demonstrates exactly that at 28 features. `karabiner.nix` is a 26-line file holding a cask, a
config link, and its Darwin gating, and nothing else references Karabiner
([karabiner.nix#L1-L26](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/karabiner.nix#L1-L26)).
There is no central package list, no cask-enable data file, and no `.chezmoiignore` analogue
anywhere.

It also supports our claim that typed options replace the data layer. `options.my` is typed
`uniq str` throughout, there are no data files, and the `throw "unknown feature"` fallthrough
([lib.nix#L45-L57](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/flake/lib.nix#L45-L57))
is the unknown-group validation our doc says becomes `assertions`.

It contradicts one structural assumption. Our doc's scaffold proposes nine roles: base,
desktop, development, apple-development, personal, work, homelab, ci, devpod. This repo has no
role layer at all. Work versus personal is an identity delta and a package delta in the host
file, over one flat feature list. That is a real data point that a role layer earns its place
only when hosts genuinely diverge. Our headless DevPod and CI profiles do diverge, so we
probably need a split, but nine roles for what may be a two-way or three-way distinction is
worth re-examining before it is built.

Two composition ideas our doc does not have and should. First, `flake.modules.<runtime>.<name>`
as a typed flake option with a runtime-preference resolver
([lib.nix#L15-L18](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/flake/lib.nix#L15-L18)),
which lets one feature name mean "the Darwin module, or the generic one, or the Home Manager
one" without three parallel import lists. Second, a recorded flake-parts hazard: `mk-host.nix`
is called as a plain function rather than through `inputs.self.lib` specifically to avoid a
fixpoint recursion, and the file says so
([mk-host.nix#L1-L8](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/hosts/mk-host.nix#L1-L8)).

### The "what disappears" table

Most rows hold. This repo has no resolver, no cask-enable template, no ignore gates, no
Brewfile renderer, no drift banner, no first-run prompts, and no group union.

The plist row holds strongly. Our doc says plist modify stubs go away for domains written
through `defaults`. This repo writes roughly 40 domains, Apple and third-party alike, through
`system.defaults` and `CustomUserPreferences` with zero merge tooling
([darwin/default.nix#L68-L267](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/default.nix#L68-L267)).

One row needs reframing. Our doc says first-run prompts and machine-local state disappear
because host policy is committed. Host policy is committed here, but machine-local config did
not disappear. It moved to a documented runtime directory, `$HOST_CONFIGS`, which resolves to
`~/.local/share/<host>`
([base/home-manager.nix#L19](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/base/home-manager.nix#L19),
[user-shell.nix#L137](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/user-shell.nix#L137)).
The README documents it as a table of six known slots
([README.md#L196-L228](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/README.md#L196-L228)).
Nothing in the flake reads it. Each app reads it itself, through its own include or source
mechanism: `[include] path = $HOST_CONFIGS/gitconfig`
([git.nix#L71-L73](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/git.nix#L71-L73))
and a guarded `source $HOST_CONFIGS/zshrc`
([user-shell.nix#L418-L420](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/user-shell.nix#L418-L420)).
That is the answer to our row 7 and our open question 6, and it is a better one than trying to
make a pure flake read an out-of-repo file. Our doc rates that scaffold row "partial" for
exactly the impurity reason. The move is to stop trying.

### The per-app ownership table

Our table asks, per app, whether the app offers a layer Nix can own outright. This repo asks a
different question first: does the app write the file. Where the answer is yes, it hands the
file to the app and keeps Nix out of it.

| App | Our doc's plan | This repo | Verdict |
| --- | --- | --- | --- |
| Claude Code | Root-owned managed drop-in for hooks and permissions; `enabledPlugins` stays user-level | One live symlink; hooks, permissions, and `enabledPlugins` all in one committed file ([ai.nix#L203-L205](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/ai.nix#L203-L205)) | Alternative; no managed layer tried, so our open questions 9 and 16 stay open |
| pi | No separate machine-default file, so the global merge stays | Generates the whole file and copies it over the app's on every switch ([ai.nix#L117-L126](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/ai.nix#L117-L126)) | Alternative; a third option we do not name |
| Karabiner | EDN as a managed file, goku compile stays an onChange block | No goku; whole directory live-symlinked into the checkout ([karabiner.nix#L13-L19](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/karabiner.nix#L13-L19)) | Different problem, same conclusion about GUI-written files |
| git | Managed config plus includes | Verbatim tree plus generated `config-nix` joined by git's own include ([git.nix#L48-L73](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/git.nix#L48-L73)) | Supports, with a cleaner mechanism |

Two mechanisms our per-app table does not name and should:

1. **App-native include of a generated fragment.** Documented in the table in section 3. This
   is a merge the application performs, at read time, with no merge program and no clobber
   risk. Our table currently considers only system or managed layers, which are a special case
   of the same idea. Several of our six surviving mergers may have an include mechanism nobody
   has checked.
2. **Sidecar and copy.** A store-backed `.bk` file plus a `cp` in an activation block ordered
   after the write boundary. Full replacement, not a merge, and its cost is losing whatever the
   app wrote since the last switch.

### Problem A: files the app also writes

Supported, with one mechanism to steal and one loss to record.

The support: this repo confirms Home Manager's file model does not merge, and it confirms that
`mkOutOfStoreSymlink` into the checkout is the practical escape. It does that deliberately in
at least four places and writes down the reasoning in the code
([karabiner.nix#L13-L14](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/karabiner.nix#L13-L14),
[hammerspoon.nix#L13-L14](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/hammerspoon.nix#L13-L14)).

The mechanism to steal: `mkOutOfStoreTree` and its per-file rather than per-directory linking
([base/home-manager.nix#L26-L51](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/base/home-manager.nix#L26-L51)).
This is strictly better than either of the two options our doc considers. A recursive
`home.file` gives store symlinks and clobber errors. A directory-level `mkOutOfStoreSymlink`
puts the whole directory in the repo. Per-file out-of-store links keep the destination
directory real and writable, so the app can create new files beside the managed ones. Costs to
state if we adopt it: `listFilesRecursive` runs at evaluation time, so a newly added file needs
a rebuild before it appears; and the link target is the checkout, so the repo must sit at a
fixed path, hardcoded here as `~/.dotfiles`
([base/home-manager.nix#L20](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/base/home-manager.nix#L20)).

The loss to record: our doc's Problem A does not mention store-path rot in artifacts written by
third-party tools. The `git maintenance` launchd fix is a clean example of a class of breakage
we will hit
([git.nix#L76-L94](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/git.nix#L76-L94)).

This repo does not solve the things our doc says are lost. There is no delete directive, no
quit guard before writing a plist, and no merged-result preview. It simply does not need them.

### Problem B: the MDM work Mac

Partial evidence, and the negative result matters as much as the positive one.

Positive: nix-darwin runs on a Kandji-managed corporate Mac, and it has been made MDM-aware in
two specific ways worth copying. Nothing keys off the machine's real hostname, because the MDM
resets it
([rocket/default.nix#L6-L9](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/hosts/rocket/default.nix#L6-L9),
[base/identity.nix#L22-L25](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/base/identity.nix#L22-L25)).
And the logical name is published as a file so GUI apps can read it
([base/home-manager.nix#L79-L82](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/base/home-manager.nix#L79-L82)).
Our doc's scaffold names our work host by its Jamf-assigned hostname. If Jamf renames it, that
breaks. Cheap thing to design around now.

Negative, and this is the important part: this repo does not stress the constraint that
actually blocks us. Every switch is a plain `sudo darwin-rebuild switch`
([user-shell.nix#L534-L544](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/user-shell.nix#L534-L544)),
with no elevation step anywhere in the repo. The author has standing admin. Our work user is not
in `admin` by default and needs a Jamf temp-admin round trip per switch. This repo gives zero
evidence on that, and zero evidence on the installer's MDM pre-flight check that our open
question 3 asks about.

One partial answer to our open question 7: Homebrew is fully declarative on the corporate Mac,
`cleanup = "zap"` included
([darwin/default.nix#L52-L57](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/default.nix#L52-L57)).
Whether that machine has MDM-pushed casks that zap would remove is unverified.

### Problem C: secrets

Strong support, reached independently. Our doc concludes that sops-nix and agenix would change
what the public repo contains and are aimed at machines with no 1Password session. This author
reached the same conclusion and wrote it into the repo, citing agenix's own threat model
([secrets.nix#L1-L12](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/secrets/secrets.nix#L1-L12)).
One encrypted file, and it is a low-sensitivity one.

It adds a tier our doc should rank above "op read in activation": push the secret lookup all
the way to application runtime, where the application supports a password command. mbsync and
msmtp call `pass` themselves
([mail.nix#L226](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/mail.nix#L226)),
so no secret ever touches activation, let alone the store. Where the app does not support a
command, which is almost certainly true for our three license files, activation stays the right
place.

It also supports our "no eval-time reads" rule and our row 2 rating. The one agenix entry uses
`path` plus `mode = "600"`
([node.nix#L32-L39](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/node.nix#L32-L39)),
and the seeded local zshrc gets an explicit `chmod 600` in activation
([user-shell.nix#L212-L229](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/user-shell.nix#L212-L229)).
Both are the workarounds our doc predicts.

### The test surface

Contradicts our doc's implied scale. Our doc sketches `checks/` with subtrees for hosts, roles,
apps, reconcilers, and shell, plus nmt file assertions, plus a Tart lane. This repo is 13 years
old with 291 stars and three hosts, and ships 23 lines of CI that evaluate three derivation
paths.

It supports one specific technical claim: `nix flake check` does not cover
`darwinConfigurations`, and the working answer is to name each host output explicitly.

It offers a cheaper first rung than our doc proposes. Our doc jumps to building
`darwinConfigurations.<host>.system` as a check, which needs a macOS runner. Evaluating
`.system.drvPath` on `ubuntu-latest` catches every evaluation error, which is most of what
breaks, at Linux-runner cost
([nix-eval.yml#L19-L23](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/.github/workflows/nix-eval.yml#L19-L23)).
The weekly cron on the same workflow
([nix-eval.yml#L10-L11](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/.github/workflows/nix-eval.yml#L10-L11))
is also one answer to our note that our weekly update cadence has no declarative analogue: keep
the cadence in CI, not in the configuration.

Our doc should not copy the scale, though. We have 22 mergers, real plist behavior, and a Tart
lane, and eval-only CI would drop all of it.

### Concept map rows 1, 4, and 24

Row 1, plain files under `home/` becoming `home.file.source`, rated full for files only we
write. This repo is an **alternative** and inverts our ratio. It routes essentially the whole
274-file `config/` tree through out-of-store symlinks and reserves store-backed content for 19
small generated fragments. Our doc treats store symlinks as the default and out-of-store as an
eight-file exception. Worth stating explicitly as a repo-wide policy choice rather than a
per-file one, with the costs named: config content no longer rolls back with the generation, it
is not immutable, directory enumeration happens at evaluation time, and the checkout path
becomes load-bearing.

Row 4, `mkOutOfStoreSymlink`, rated full. **Supported and extended.** Every call site
interpolates an absolute path derived from `my.dotfilesDir`, confirming the absolute-path
requirement. The extension our row does not make is the per-file versus per-directory
distinction, which is exactly what decides whether an app can create new files in its own
config directory.

Row 24, app-owned configs. **Alternative.** Our row treats this as a choice between a managed
layer and a merger. This repo shows two more options: an app-native include of a small
generated fragment, and sidecar-and-copy overwrite. It also weights the third option, hand the
file to the app via a live symlink, much more heavily than we do.

### Open questions touched

| Q | Status after this survey |
| --- | --- |
| 3 (installer MDM pre-flight) | Untouched. Nothing in the repo mentions it. |
| 6 (machine-local override) | Reframed. Answer is a runtime `$HOST_CONFIGS` directory apps read themselves, not anything the flake evaluates ([README.md#L196-L228](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/README.md#L196-L228)). |
| 7 (Homebrew fully declarative per host) | Partial yes, including on a corporate Mac, with `zap` ([darwin/default.nix#L52-L57](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/default.nix#L52-L57)). |
| 9 and 16 (Claude managed drop-in) | Unanswered. No managed layer is used ([ai.nix#L203-L205](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/ai.nix#L203-L205)). |
| 11 (safe whole-domain plist import) | Indirect. Every third-party domain is written per key through `CustomUserPreferences`, never imported wholesale ([darwin/default.nix#L167-L267](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/default.nix#L167-L267)). |
| 14 (apps that let Nix own the whole file) | Reframed. This repo does not disable app persistence; it overwrites and accepts the loss ([ai.nix#L117-L126](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/ai.nix#L117-L126)). |

New question this raises for us: do any of our six surviving mergers support an app-native
include of a second file? Codex does. crit, agentsview, Cursor, and Yojam are unchecked. That
is cheaper than every option currently in our per-app table.

## 6. What To Take, What To Avoid, Relevance

### Take

1. **`mkOutOfStoreTree`**, per-file out-of-store linking of a verbatim directory
   ([base/home-manager.nix#L26-L51](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/base/home-manager.nix#L26-L51)).
   The single most directly applicable thing here. It is roughly 20 lines and it answers "what
   happens to our `home/` tree" better than either option our doc considers.
2. **Verbatim file plus generated fragment plus app include.** Four working instances. Where an
   app has an include mechanism, this beats both a merger and a managed layer.
3. **A documented `$HOST_CONFIGS` runtime directory** for machine-local config, with a README
   table of known slots
   ([README.md#L196-L228](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/README.md#L196-L228)).
4. **Never key configuration off an MDM-controlled hostname**, and publish the logical name as a
   file for GUI apps
   ([base/identity.nix#L22-L25](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/base/identity.nix#L22-L25),
   [base/home-manager.nix#L79-L82](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/base/home-manager.nix#L79-L82)).
5. **`nix eval --raw` of each host's `drvPath` on a Linux runner, plus a weekly cron** as the
   first CI rung
   ([nix-eval.yml#L1-L23](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/.github/workflows/nix-eval.yml#L1-L23)).
6. **A typed `flake.modules.<runtime>.<feature>` namespace with a resolver that throws on
   unknown names**
   ([lib.nix#L15-L18](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/flake/lib.nix#L15-L18),
   [lib.nix#L45-L57](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/flake/lib.nix#L45-L57)).
7. **Homebrew activation environment pinning**, `HOMEBREW_GIT_PATH` plus cacert
   ([darwin/default.nix#L41-L64](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/default.nix#L41-L64)).
   A gotcha we would otherwise hit blind.
8. **Store-path rot in tool-generated launchd plists** as a documented hazard
   ([git.nix#L76-L94](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/git.nix#L76-L94)).

### Avoid

1. **Overwriting an app-written settings file from a sidecar on every switch**
   ([ai.nix#L117-L126](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/ai.nix#L117-L126)).
   Acceptable where app-written state is disposable. Wrong for Cursor's `cli-config.json`, where
   it would log us out, and wrong for Claude's `enabledPlugins` under our default-loaded-plugin
   policy.
2. **Symlinking `~/.claude/settings.json` into the checkout**
   ([ai.nix#L203-L205](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/shared/ai.nix#L203-L205)).
   Turns every plugin install into a repo diff. We deliberately leave install records with the
   CLI.
3. **`homebrew.onActivation.cleanup = "zap"` with `--force-cleanup`, unreviewed**
   ([darwin/default.nix#L52-L57](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/darwin/default.nix#L52-L57)).
   We keep a named retired-package ledger for a reason, and on a Jamf-managed Mac zap could
   remove MDM-pushed apps.
4. **Eval-only CI.** Too thin for our merge and plist surface.
5. **No role or profile layer at all.** Fine for three near-identical Macs. Our headless
   profiles genuinely diverge.
6. **A hardcoded `~/.dotfiles` checkout path**
   ([base/home-manager.nix#L20](https://github.com/ahmedelgabri/dotfiles/blob/df5a0d3531d6e3c73d5cbc3e79f1e1521377805c/nix/parts/modules/base/home-manager.nix#L20)).
   We work out of git worktrees constantly; whatever we adopt from `mkOutOfStoreTree` needs the
   root to be an option, not a constant.

### Relevance: 4 / 5

The platform mix is ours almost exactly: nix-darwin plus Home Manager plus nix-homebrew plus
flake-parts plus agenix, on Apple Silicon. The starting position is ours: a long-lived plain
dotfiles repo with a large verbatim config tree that adopted Nix rather than starting from it.
The fleet includes an MDM-managed corporate Mac. And the app overlap is unusually high, since
this repo manages Claude Code, Codex, and pi configs and hits the same file-ownership problems
we do. Most usefully, it answers the structural question our doc leaves most open, what happens
to the verbatim tree, with a working and documented mechanism.

It is not a 5 for three reasons. It never tests the two constraints that actually block us: a
per-switch Jamf temp-admin round trip, and merging into files an app rewrites, which it
sidesteps rather than solves. It has no secrets story we can copy for the 1Password-backed
license files. And its test surface is far too thin to inform ours.

## 7. Scorecard Against Our Concept Map

Rows are from Appendix A of `../nix-target-state-research.md`. Only rows this repo actually
provides evidence for are listed.

| Row | Verdict | Note |
| --- | --- | --- |
| 1 | Alternative | Out-of-store tree replaces store links |
| 2 | Supports | Uses age mode, activation chmod |
| 3 | Alternative | Source mode survives out-of-store links |
| 4 | Supports | Absolute paths, per-file linking preferred |
| 5 | Supports | Interpolation and typed options only |
| 6 | Supports | Host argument replaces every prompt |
| 7 | Alternative | Runtime directory, read by apps |
| 8 | Alternative | No layer merge, host overrides |
| 9 | Supports | Feature modules contribute casks directly |
| 10 | Supports | Packages pinned by flake lock |
| 11 | Supports | Zap cleanup replaces retired ledger |
| 13 | Supports | nix-homebrew installs and owns Homebrew |
| 16 | Supports | No gates, imports decide everything |
| 17 | Supports | Cask lives beside its config |
| 19 | Alternative | Activation blocks rerun every switch |
| 20 | Supports | Stamp-style guard seeds file once |
| 21 | Supports | entryAfter writeBoundary orders every block |
| 23 | Supports | CustomUserPreferences only, no merge tooling |
| 24 | Alternative | App include fragment or overwrite |
| 25 | Supports | No quit guard, accepts overwrite |
| 26 | Supports | Typed defaults plus CustomUserPreferences escape |
| 27 | Supports | Sudo switch, TouchID, standing admin |
| 28 | Supports | Two launchd user agents work |
| 29 | Alternative | Symlinked settings, app records plugins |
| 30 | Alternative | Live symlink, app owns file |
| 34 | Supports | mise kept alongside nixpkgs packages |
| 35 | Alternative | nix-darwin zsh, ZDOTDIR via variable |
| 36 | Supports | xdg options set every path |
| 37 | Supports | No eval-time secret reads anywhere |
| 38 | Supports | No per-file drift report exists |
| 39 | Supports | plist textconv kept in gitconfig |
| 40 | Supports | backupFileExtension set to avoid clobber |
| 42 | Alternative | Eval-only CI, no macOS runner |
