---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-06
updated: 2026-09-06
related:
  - public-dotfiles-skills-packaging-research.md
  - nix-migration-research.md
  - ../../.agents/skills/agent-skill-management/SKILL.md
status_detail: "Public Nix skill-packaging source survey; no third-party configuration was built or activated."
---

# Nix Agent Skill Packaging

Public Nix configurations package skills at different levels. Some declare
individual Home Manager files. Others select skills from pinned source inputs,
or turn skills into packages with a custom deployment module. Nix can also
manage links to editable checkouts, so using Nix does not necessarily make the
installed skill content immutable.

## Method

Inspected public repository commits, trees, configuration files, and selected
`SKILL.md` payloads through GitHub's read-only APIs on 2026-09-06. Links pin
the inspected commits. The scope is skill packaging, including selection and
updates; it does not evaluate a general migration to Nix.

No third-party flake was evaluated, built, or activated. The descriptions below
establish declared behavior, not successful agent loading. Store-backed versus
editable content follows the source path and deployment operation in each
configuration; actual filesystem permissions were not measured.

## Public configurations

| Repository and snapshot | Packaging | Installed content | Update unit |
| --- | --- | --- | --- |
| [kattakath/nix-config](https://github.com/kattakath/nix-config/tree/a248ac8989856a0a0925ad5c557406d075b297a4), 2026-09-06 | Non-flake inputs and local forks through `programs.claude-code.skills` | Store-backed skill payloads | Source changes or input lock updates, then switch |
| [Koutaro-Hanabusa/dotfiles](https://github.com/Koutaro-Hanabusa/dotfiles/tree/42fd2ed8171c2ed80e3559c438925f6423323f3c), 2026-09-05 | Explicit `home.file` links plus a package-provided skill | Editable personal skills; store-backed Hunk skill | Existing personal edits are live; package changes need switch |
| [sudosubin/nixos-config](https://github.com/sudosubin/nixos-config/tree/c665784c6c3935149b6d8f3144a70c15b33d09a6), 2026-09-05 | `pkgs.skills` package selection and a custom Pi module | Per-skill links to package outputs | Locked skill-catalog input, then switch |
| [i9wa4/dotfiles](https://github.com/i9wa4/dotfiles/tree/55e352dd707b48f740f0fefd51ea805eb8b6fc93), 2026-09-06 | Validated and patched sources, separate bundles per consumer | Writable destination roots containing store-backed links | Input locks or local sources, then build and synchronize |
| [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles/tree/60863073301757c8c6232889e19b60f1b6b9b231), 2026-09-06 | Separate skill registry, dependency packages, text transforms | Copied `.agents` tree and Claude links | Skill-source lock update PRs, then switch |

### Plain Home Manager options with pinned upstream directories

Kattakath declares skill repositories as `flake = false` inputs, including
`vercel-labs/skills` and `anthropics/claude-code`. Their revisions and NAR hashes
are recorded in `flake.lock`. Its Darwin-gated Claude module maps named skills
to selected source subdirectories rather than installing every upstream skill.
Examples include `find-skills` and the individual plugin-authoring skills.
See the [inputs](https://github.com/kattakath/nix-config/blob/a248ac8989856a0a0925ad5c557406d075b297a4/flake.nix#L239-L253),
[lock](https://github.com/kattakath/nix-config/blob/a248ac8989856a0a0925ad5c557406d075b297a4/flake.lock),
and [selection](https://github.com/kattakath/nix-config/blob/a248ac8989856a0a0925ad5c557406d075b297a4/modules/shared/home.nix#L947-L990).

The same option also consumes local skills. Its vendored `brag` fork redirects
generated user data away from the managed skill directory into `BRAG_DATA_DIR`.
That is a concrete adaptation required when an upstream skill expects to write
beside its instructions. The module also documents unresolved ambient runtime
dependencies for some document skills: pinning the Markdown does not package
every executable or Python dependency it invokes.
See the [fork rationale](https://github.com/kattakath/nix-config/blob/a248ac8989856a0a0925ad5c557406d075b297a4/skills/brag/FORK-NOTES.md)
and [dependency note](https://github.com/kattakath/nix-config/blob/a248ac8989856a0a0925ad5c557406d075b297a4/modules/shared/home.nix#L983-L995).
A [weekly workflow](https://github.com/kattakath/nix-config/blob/a248ac8989856a0a0925ad5c557406d075b297a4/.github/workflows/update-flake-lock.yml)
is configured to open input-update PRs; its successful execution was not checked.

### Editable dotfiles with a skill tied to its executable package

Koutaro uses `mkOutOfStoreSymlink` with the explicit live path
`$HOME/dotfiles/home-manager`. Individual `home.file` entries expose selected
personal skills under `~/.agents/skills`; its Claude directory is linked as a
whole. Existing personal skill edits therefore follow the checkout immediately.
New shared-skill names need another declaration and switch.
See the [link helper and declarations](https://github.com/Koutaro-Hanabusa/dotfiles/blob/42fd2ed8171c2ed80e3559c438925f6423323f3c/home-manager/home.nix#L16-L19)
and [skill list](https://github.com/Koutaro-Hanabusa/dotfiles/blob/42fd2ed8171c2ed80e3559c438925f6423323f3c/home-manager/home.nix#L131-L146).

Hunk follows another path. The flake passes `hunk.packages.<system>.default`
into Home Manager and installs that package. An activation step writes
gitignored links inside both checkout skill trees to
`${hunkPkg}/skills/hunk-review`. The binary and its instruction payload thus
come from the same locked input. Updating the Hunk lock and switching refreshes
those links. This retains editable local skills while avoiding a separate
vendored copy of Hunk's skill, but assumes the checkout exists at the declared
path. See the [package wiring](https://github.com/Koutaro-Hanabusa/dotfiles/blob/42fd2ed8171c2ed80e3559c438925f6423323f3c/flake.nix#L74-L92)
and [activation](https://github.com/Koutaro-Hanabusa/dotfiles/blob/42fd2ed8171c2ed80e3559c438925f6423323f3c/home-manager/home.nix#L175-L186).

### Skill packages selected through a custom agent module

Sudosubin's configuration imports the `nix-skills` overlay and selects eleven
packages under `programs.pi.skills`, with local name overrides for several
entries. Its custom Home Manager module accepts a list of packages, rejects
duplicate `pname` values, and maps each package into
`~/.config/pi/agent/skills/<pname>` using `home.file.source`.
See the [consumer selection](https://github.com/sudosubin/nixos-config/blob/c665784c6c3935149b6d8f3144a70c15b33d09a6/modules/shared/programs/ai/default.nix#L105-L117)
and [deployment module](https://github.com/sudosubin/nixos-config/blob/c665784c6c3935149b6d8f3144a70c15b33d09a6/libraries/home-manager/programs/pi/default.nix#L159-L185).

The lock pins `nix-skills` at `e45b450931bd8b60f77eba54850f7f4456ed8606`.
A daily workflow updates dependencies and the root flake lock, then opens a PR.
This makes skill selection look like package selection; the catalog supplies
the upstream packaging layer. The complete configuration also references private
inputs, so inspecting its public modules does not demonstrate that an unrelated
user can build the full system. See its
[flake inputs](https://github.com/sudosubin/nixos-config/blob/c665784c6c3935149b6d8f3144a70c15b33d09a6/flake.nix),
[lock](https://github.com/sudosubin/nixos-config/blob/c665784c6c3935149b6d8f3144a70c15b33d09a6/flake.lock),
and [update workflow](https://github.com/sudosubin/nixos-config/blob/c665784c6c3935149b6d8f3144a70c15b33d09a6/.github/workflows/update.yaml).

### Build-time repairs and different inventories per agent

I9wa4 wraps `agent-skills-nix` with its own module. It validates local skill
frontmatter in a derivation and creates a patched Anthropic source that
normalizes `claude-api/SKILL.md` before validation. The original sources remain
pinned flake inputs. It then constructs separate active, minimal Codex, and
reference-only bundles. Broad provider collections stay outside active loader
paths at `~/.local/share/skills`.
See the [source transformations](https://github.com/i9wa4/dotfiles/blob/55e352dd707b48f740f0fefd51ea805eb8b6fc93/nix/home-manager/agents/shared/agent-skills.nix#L61-L152)
and [bundle selections](https://github.com/i9wa4/dotfiles/blob/55e352dd707b48f740f0fefd51ea805eb8b6fc93/nix/home-manager/agents/shared/agent-skills.nix#L233-L310).

Its [install manifest](https://github.com/i9wa4/dotfiles/blob/55e352dd707b48f740f0fefd51ea805eb8b6fc93/nix/home-manager/agents/shared/install-manifest.nix)
declares symlink trees for Claude and Codex. Custom activation preserves
`.system` while refreshing Codex with `rsync --delete`; Claude synchronization
can skip unmanaged content or continue after an error. Consequently, successful
completion of the surrounding switch alone would not prove Claude received
the new bundle. Local or input changes require regeneration; these links do
not expose edits from a live source checkout.
See the [activation logic](https://github.com/i9wa4/dotfiles/blob/55e352dd707b48f740f0fefd51ea805eb8b6fc93/nix/home-manager/agents/shared/agent-skills.nix#L382-L450)
and [input lock](https://github.com/i9wa4/dotfiles/blob/55e352dd707b48f740f0fefd51ea805eb8b6fc93/flake.lock).

## Upstream Home Manager already has skill options

Home Manager at `2c0350c759688177331b8f5242311fae8877bdb3`
provides `programs.claude-code.skills` and `programs.codex.skills`.
They accept named skills as inline Markdown or file/directory paths, and
can consume directories from fetched sources or package outputs. The
modules translate these declarations into Home Manager file entries.
Codex's directory form leaves the enclosing skills directory available
for unmanaged siblings. These are upstream options; the Pi option in
Sudosubin's example is defined in that repo's custom module.
Sources: [Claude options](https://github.com/nix-community/home-manager/blob/2c0350c759688177331b8f5242311fae8877bdb3/modules/programs/claude-code/options.nix#L394-L445),
[Claude file generation](https://github.com/nix-community/home-manager/blob/2c0350c759688177331b8f5242311fae8877bdb3/modules/programs/claude-code/lib.nix#L95-L124),
[Codex options](https://github.com/nix-community/home-manager/blob/2c0350c759688177331b8f5242311fae8877bdb3/modules/programs/codex/options.nix#L223-L276).

The same snapshot also has native plugin options. Claude's implementation
chooses personal-plugin links or a `--plugin-dir` wrapper according to the
selected Claude version. Codex's implementation generates marketplace
metadata, plugin cache entries and settings, with activation cleanup for
managed cache directories that the CLI has materialized. These are
separate integration paths with version-specific behavior. The inspected
upstream snapshot does not establish which behavior an older consumer
pin receives.
Sources: [Claude plugin option](https://github.com/nix-community/home-manager/blob/2c0350c759688177331b8f5242311fae8877bdb3/modules/programs/claude-code/options.nix#L150-L173),
[Codex plugin deployment](https://github.com/nix-community/home-manager/blob/2c0350c759688177331b8f5242311fae8877bdb3/modules/programs/codex/default.nix#L299-L390).

## A full skill catalog with agent-skills-nix

`Kyure-A/agent-skills-nix` adds source discovery and selection around a Nix
store bundle. Sources can be local paths, flake inputs, or a separate
registry. The registry loader verifies that declarations match the lock
and fetches its recorded revisions and hashes. Explicit skills can carry
Nix packages and a `transform` function; the builder adds executable links
and generates the skill text. This allows a skill and its required CLI
to be deployed together.
Sources at `260294fa7b7b8083006a959f1b36be77b24912dc`:
[source registry](https://github.com/Kyure-A/agent-skills-nix/blob/260294fa7b7b8083006a959f1b36be77b24912dc/lib/source-registry.nix#L274-L338),
[bundle builder](https://github.com/Kyure-A/agent-skills-nix/blob/260294fa7b7b8083006a959f1b36be77b24912dc/lib/bundle.nix#L145-L218).

Its Home Manager module offers three deployment forms:

| Form | Implementation | Ownership implication |
| --- | --- | --- |
| `link` | Recursive `home.file` entries pointing into the bundle | Skill content follows the Nix generation. |
| `symlink-tree` | Activation synchronizes with `rsync -a --delete` | Preserves bundle links and treats the marked destination as generated. |
| `copy-tree` | Activation uses `rsync -aL --delete` | Materializes files; subsequent synchronization can replace edits. |

Tree synchronization refuses non-empty unmarked destinations unless forced,
records an ownership marker, and excludes `.system` by default. Copying
outside the store does not by itself establish a durable editing workflow
or guarantee writable file modes. These synchronization rules come from
the framework; they differ from ordinary Home Manager file declarations.
Sources: [Home Manager module](https://github.com/Kyure-A/agent-skills-nix/blob/260294fa7b7b8083006a959f1b36be77b24912dc/modules/home-manager/agent-skills.nix),
[synchronizer](https://github.com/Kyure-A/agent-skills-nix/blob/260294fa7b7b8083006a959f1b36be77b24912dc/scripts/sync.sh#L264-L329),
[exclusions](https://github.com/Kyure-A/agent-skills-nix/blob/260294fa7b7b8083006a959f1b36be77b24912dc/modules/common.nix#L196-L205).

### Ryoppippi's concrete configuration

`ryoppippi/dotfiles` at `60863073301757c8c6232889e19b60f1b6b9b231`
pins that exact framework revision. Its local skills stay in
`agents/skills/`; external skills use `registry/sources/*.nix` plus
`sources.lock.json`, separately from `flake.lock`. The module attaches
`ast-grep` and `agent-browser` packages to the matching skills and
rewrites selected instructions to call the chosen executables. It
deploys a `copy-tree` to `~/.agents/skills` and Home Manager links to
`~/.config/claude/skills`.
Sources: [consumer module](https://github.com/ryoppippi/dotfiles/blob/60863073301757c8c6232889e19b60f1b6b9b231/nix/modules/home/agent-skills.nix),
[framework pin](https://github.com/ryoppippi/dotfiles/blob/60863073301757c8c6232889e19b60f1b6b9b231/flake.lock),
[source lock](https://github.com/ryoppippi/dotfiles/blob/60863073301757c8c6232889e19b60f1b6b9b231/registry/sources.lock.json).

Its daily workflow runs the registry updater and opens a PR with old and
new revisions. The workflow deliberately leaves merging for review.
Source: [skill update workflow](https://github.com/ryoppippi/dotfiles/blob/60863073301757c8c6232889e19b60f1b6b9b231/.github/workflows/update-skill-sources.yaml).

### Portable export has a narrower contract

The framework's experimental `mkAgentPlugin` exporter creates a
self-contained `.codex-plugin/plugin.json` plus `skills/` artifact.
That exporter rejects skills with `packages` or `transform`, and rejects
`disable-model-invocation: true`. It also excludes plugin hooks and MCP
configuration. Those restrictions matter for this repo's dependency-backed
and human-invoked skills; the exporter and the ordinary Nix bundle are
different outputs.
Source: [export contract](https://github.com/Kyure-A/agent-skills-nix/blob/260294fa7b7b8083006a959f1b36be77b24912dc/README.md#agent-plugin-export-experimental).

## Individual derivations from nix-skills

Inspected at `5f0e1a5b594441f577f02b3e5e939d2d6e422279` (2026-09-06).
The flake and builder have identical source blobs at Sudosubin's consumer
pin `e45b450931bd8b60f77eba54850f7f4456ed8606`.
Sources: [consumer-pinned flake](https://github.com/sudosubin/nix-skills/blob/e45b450931bd8b60f77eba54850f7f4456ed8606/flake.nix),
[consumer-pinned builder](https://github.com/sudosubin/nix-skills/blob/e45b450931bd8b60f77eba54850f7f4456ed8606/nix/build-skill/default.nix).

This flake exposes both `skills.<system>.<owner>.<repo>.<skill>` and a `pkgs.skills` overlay. Committed JSON records upstream repository revisions, hashes, and skill paths; the updater resolves repository HEAD, prefetches the archive, and discovers `SKILL.md` directories. Consumers pin a catalog snapshot through their flake input rather than declaring every upstream repository separately. [Flake implementation](https://github.com/sudosubin/nix-skills/blob/5f0e1a5b594441f577f02b3e5e939d2d6e422279/flake.nix), [updater](https://github.com/sudosubin/nix-skills/blob/5f0e1a5b594441f577f02b3e5e939d2d6e422279/scripts/update-skills.ts).

Each derivation fetches the recorded revision/hash, copies the selected directory to its output, and rewrites the frontmatter name; `.override { name = "..."; }` supports renaming. The builder disables build/configure phases and adds only `yq-go` as a native build input. It therefore packages skill content, without resolving skill runtime dependencies or preserving an enclosing repository’s native plugin/marketplace structure. [Skill builder](https://github.com/sudosubin/nix-skills/blob/5f0e1a5b594441f577f02b3e5e939d2d6e422279/nix/build-skill/default.nix).

Deployment is delegated to consumers: its README shows Home Manager’s `programs.claude-code.skills` and a direct `home.file` declaration for pi. There is no library-owned activation reconciler in its flake outputs. Relative to our local/vendor packages and generated marketplaces, this is chiefly an upstream acquisition/catalog option, not a complete replacement for packaging policy and agent activation. [Deployment examples](https://github.com/sudosubin/nix-skills/blob/5f0e1a5b594441f577f02b3e5e939d2d6e422279/README.md), [flake outputs](https://github.com/sudosubin/nix-skills/blob/5f0e1a5b594441f577f02b3e5e939d2d6e422279/flake.nix).

## Native artifacts from agent-plugins-nix

Inspected `Kyure-A/agent-plugins-nix` at
`324168d2afbb7a50a5c87bed2b59d97291b23512` (2026-08-14).

This library covers a similar part of our plugin renderer's job. Its flake pins Nixpkgs, agent-skills-nix, and mcp-servers-nix; consumers supply a logical plugin with metadata, a skill bundle derivation, MCP definitions, assets, and agent-specific extensions. The skill provider wraps agent-skills-nix’s bundle builder rather than maintaining another skill catalog. [Flake inputs](https://github.com/Kyure-A/agent-plugins-nix/blob/324168d2afbb7a50a5c87bed2b59d97291b23512/flake.nix), [skill provider](https://github.com/Kyure-A/agent-plugins-nix/blob/324168d2afbb7a50a5c87bed2b59d97291b23512/lib/providers/agent-skills-nix.nix).

Separate derivations materialize `.claude-plugin/plugin.json` or `.codex-plugin/plugin.json` and `skills/`. Claude output can include `.mcp.json` and native hooks; Codex receives a separate MCP TOML fragment. The Codex adapter rejects nested skill IDs unless explicitly flattened, while Claude preserves them. These are the library’s implemented policies, not independently verified statements about current agent capabilities. [Claude adapter](https://github.com/Kyure-A/agent-plugins-nix/blob/324168d2afbb7a50a5c87bed2b59d97291b23512/lib/adapters/claude.nix), [Codex adapter](https://github.com/Kyure-A/agent-plugins-nix/blob/324168d2afbb7a50a5c87bed2b59d97291b23512/lib/adapters/codex.nix).

For dependencies, MCP commands may reference Nix executables directly; the example embeds `${pkgs.jq}/bin/jq`. It also accepts evaluated mcp-servers-nix definitions. This does not discover dependencies mentioned inside skill prose or automatically package every helper script. [Full example](https://github.com/Kyure-A/agent-plugins-nix/blob/324168d2afbb7a50a5c87bed2b59d97291b23512/examples/full.nix), [MCP provider](https://github.com/Kyure-A/agent-plugins-nix/blob/324168d2afbb7a50a5c87bed2b59d97291b23512/lib/providers/mcp-servers-nix.nix).

Activation is materially narrower than our marketplace plus CLI reconciliation. Its custom installer copies artifacts into `.claude/plugins/<name>` or `.codex/plugins/<name>`, uses an ownership marker before replacing/removing plugin directories, and exposes `install`, `remove`, and `check`. It does not register marketplaces, call agent plugin CLIs, or change agent configuration; Codex MCP fragment inclusion is explicitly left to the user. Home Manager generates install hooks only for declared plugins. Inference from that module: deleting a declaration does not automatically invoke removal of its old copied directory. [Installer](https://github.com/Kyure-A/agent-plugins-nix/blob/324168d2afbb7a50a5c87bed2b59d97291b23512/scripts/install-plugin.sh), [Home Manager module](https://github.com/Kyure-A/agent-plugins-nix/blob/324168d2afbb7a50a5c87bed2b59d97291b23512/modules/home-manager.nix).

## Comparison with this checkout

Assessment: `agent-skills-nix` covers source selection and bundle assembly,
while the upstream Home Manager modules cover agent-specific delivery.
Sudosubin's overlay offers a ready-made catalog if maintaining source
fetchers is the main burden. The separate plugin composer resembles our
renderer, but its copied output and installation hooks do not replace
our marketplace and CLI reconciliation workflow.

Two public practices are particularly relevant here: coupling a skill to
its CLI package, as Ryoppippi and Koutaro do, and keeping reference
collections outside active skill discovery, as I9wa4 does. Ryoppippi also
separates skill-source review from updates to the rest of the Nix inputs.

Our current package sources and reviewed APM snapshots live under
`home/dot_agents/packages/`; generated marketplaces and CLI caches have
separate owners. A Nix comparison should preserve those ownership and
invocation contracts. In particular, generated Home Manager settings use
store-backed file entries, while this repo merges desired values into
agent-owned settings. That boundary needs explicit treatment if these
modules are ever adopted.
Sources: [current package contract](../../.agents/skills/agent-skill-management/SKILL.md),
[current renderer and installation comparison](public-dotfiles-skills-packaging-research.md#comparison-with-this-checkout),
[Home Manager settings generation](https://github.com/nix-community/home-manager/blob/2c0350c759688177331b8f5242311fae8877bdb3/modules/programs/claude-code/default.nix#L302-L325).

## Limits of this sample

These five configurations were selected for different packaging decisions.
Indexed operational notes can lag source code:
Killua7362's public notes describe automatic local-skill discovery, while the
[inspected module](https://github.com/Killua7362/killuanix/blob/1f5cbfe138910e1b9e87143d64beb75298dc7530/modules/common/programs/dev/ai/claude.nix#L694-L725)
uses an explicit list that is currently empty. It was therefore excluded as
an enabled global-skill example.

The configurations show packaging mechanisms and ownership choices. They do
not establish cross-agent instruction compatibility, successful dependency
execution, or working runtime discovery on the authors' machines.
