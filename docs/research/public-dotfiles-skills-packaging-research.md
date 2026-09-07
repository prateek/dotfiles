---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-06
updated: 2026-09-06
related:
  - agent-skill-management-research.md
  - nix-agent-skills-packaging-research.md
  - ../../.agents/skills/agent-skill-management/SKILL.md
status_detail: "Public source survey; packaging patterns verified in repository files, without running installers or selecting a migration."
---

# Public Dotfiles Skill Packaging

Public dotfiles repositories use several concrete packaging models: direct
skill-directory links, curated links to separate owning repositories, downloaded
copies, declarative source registries, and native plugin marketplaces. The
examples below show that source ownership and installation are separate choices.
A shared `.agents/skills` destination alone does not identify the packaging model.

## Method and evidence boundary

Surveyed on 2026-09-06 using web search for discovery, then GitHub's read-only
commit, tree, and file APIs. Each example includes skill sources and
the installer or manifest that consumes them. All GitHub links below pin the
inspected revision. Commit dates identify the repository snapshot, not the age
of every skill.

These are source-level findings. No third-party installer, Nix activation, or
agent discovery session was run. Checked-in settings demonstrate intended
activation; they do not establish successful loading on the author's machine.

## Concrete examples

| Repository and snapshot | Source layout | Installation model |
| --- | --- | --- |
| [kurko/dotfiles](https://github.com/kurko/dotfiles/tree/2114c85eeeba02fc8a25211ad904846a388425b2), 2026-09-06 | `ai/skills/<name>/` | Per-skill links into Claude, Codex, and `.agents` roots. |
| [jinyeow/dotfiles](https://github.com/jinyeow/dotfiles/tree/005fc5716a374b938e20e85f1ed0731df4649c0b), 2026-09-04 | Portable `ai-agents/skills/`; native `<runtime>/skills/` | Windows junctions or Linux symlinks, with native-name precedence. |
| [joelhooks/dotfiles](https://github.com/joelhooks/dotfiles/tree/c3f55039c22e9b36b93c5ba193a5ff406467e001), 2026-07-14 | TSV manifests referencing owning checkouts | Curated per-skill links; source repositories remain separate. |
| [enitrat/skill-issue](https://github.com/enitrat/skill-issue/tree/fa36a49605d4ed7481736a00e3216167e02a0ec2), 2026-09-01 | Personal `skills/`; downloaded `skills/external/` | Manifest-driven vendoring followed by `npx skills add .`. |
| [DROOdotFOO/dotfiles](https://github.com/DROOdotFOO/dotfiles/tree/f788c0b6c71b7c877592e4d423de2065d8066120), 2026-09-01 | Remote archive plus checked-in `skills-extra/` | Chezmoi extracts upstream files, then builds a merged link inventory. |
| [daviddwlee84/dotfiles](https://github.com/daviddwlee84/dotfiles/tree/fe0eed72b7d811d9756a97f76db34157b1f0acf0), 2026-09-06 | Managed global declarations plus a templated local skill | Chezmoi merges CLI metadata and invokes `npx skills` for missing skills. |
| [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles/tree/60863073301757c8c6232889e19b60f1b6b9b231), 2026-09-06 | `agents/skills/` plus a locked external-source registry | Nix packages selected skills and declares separate deployment targets. |
| [vinta/hal-9000](https://github.com/vinta/hal-9000/tree/3098da841921c7ba7dbeae2ae5d39d2a7e28e9d3), 2026-09-06 | `skills/` alongside dotfiles and plugin manifests | Native Claude marketplace, with enabled plugins declared in managed settings. |

### Direct links from the dotfiles checkout

Kurko's `update_symlinks` enumerates directories under `ai/skills/` and creates
links into `~/.claude/skills`, `~/.codex/skills`, and `~/.agents/skills`. Its
stale-link cleanup matches targets under `$HOME/.dotfiles/*`, preserving files
outside that cleanup rule. Directory links expose edits within an existing skill
immediately; adding a new skill directory needs another installer pass.
The [installer](https://github.com/kurko/dotfiles/blob/2114c85eeeba02fc8a25211ad904846a388425b2/bashrc_source#L72-L126)
is more complete evidence than its
[agent notes](https://github.com/kurko/dotfiles/blob/2114c85eeeba02fc8a25211ad904846a388425b2/AGENTS.md),
which mention only Claude and `.agents` destinations. Whether the extra Codex
projection causes duplicate discovery was not tested.

### Portable sources with explicit runtime overrides

Jinyeow separates portable skills under `ai-agents/skills/` from Claude-native
skills under `claude/skills/`; Codex and Pi have their own native source roots.
The installer builds one desired name set per runtime, with native directories
winning collisions. It preserves unmanaged destinations and removes obsolete
links only when their source falls under that runtime's managed roots. Linux
uses symlinks; Windows uses directory junctions. Codex's projection explicitly
omits `codex-review` and leaves its `.system` content alone.
See the [Linux projections](https://github.com/jinyeow/dotfiles/blob/005fc5716a374b938e20e85f1ed0731df4649c0b/setup.sh#L633-L687)
and [Windows projection](https://github.com/jinyeow/dotfiles/blob/005fc5716a374b938e20e85f1ed0731df4649c0b/setup.ps1#L963-L1010),
plus the [Codex selection](https://github.com/jinyeow/dotfiles/blob/005fc5716a374b938e20e85f1ed0731df4649c0b/setup.sh#L782-L825).

### Dotfiles as a catalog of separately owned skills

Joel Hooks records source paths and consumer targets in
[`agent-skill-install.tsv`](https://github.com/joelhooks/dotfiles/blob/c3f55039c22e9b36b93c5ba193a5ff406467e001/manifests/agent-skill-install.tsv).
The [bootstrap script](https://github.com/joelhooks/dotfiles/blob/c3f55039c22e9b36b93c5ba193a5ff406467e001/scripts/bootstrap-agent-skills.sh)
requires an existing source directory containing `SKILL.md`; it does not fetch
the owning repository. It defaults to a dry run, rejects symlinked consumer
roots, preserves real destination files, and requires `--replace-links` to
replace another source's link. A separate
[catalog script](https://github.com/joelhooks/dotfiles/blob/c3f55039c22e9b36b93c5ba193a5ff406467e001/scripts/catalog-agent-skills.sh)
supports inventory and broken-link inspection. This makes dotfiles a portable
installation policy, though some manifest entries require private checkouts and
cannot be reconstructed from the public repository alone.

### Vendoring upstream skills before normal CLI installation

Enitrat's [`skills-external.json`](https://github.com/enitrat/skill-issue/blob/fa36a49605d4ed7481736a00e3216167e02a0ec2/skills-external.json)
lists skill names and upstream URLs. The
[installer](https://github.com/enitrat/skill-issue/blob/fa36a49605d4ed7481736a00e3216167e02a0ec2/scripts/install-skills)
fetches each skill through `npx skills` in a temporary directory using `--copy`,
replaces its `skills/external/<name>` copy, then calls `npx skills add .`.
The external files are actually
[checked in](https://github.com/enitrat/skill-issue/tree/fa36a49605d4ed7481736a00e3216167e02a0ec2/skills/external),
alongside personal skills. Install and update use the same
[Make recipe](https://github.com/enitrat/skill-issue/blob/fa36a49605d4ed7481736a00e3216167e02a0ec2/Makefile).
Git preserves the vendored bytes, while upstream selection remains floating:
the manifest has no commit pins and
[`.gitignore`](https://github.com/enitrat/skill-issue/blob/fa36a49605d4ed7481736a00e3216167e02a0ec2/.gitignore)
excludes `skills-lock.json`.

### Chezmoi externals with local precedence

DROOdotFOO declares an `exact` archive external at `.agents/skills-upstream`,
extracting only `*/skills/**` from a separate `agent-skills` repository's `main`
archive with a 168-hour refresh period. Locally vendored skills live under
`home/dot_agents/skills-extra/`. A post-apply script builds
`~/.agents/skills/<name>` links, giving extras precedence over upstream names,
then links the merged inventory into Claude. This separates the upstream tree
that chezmoi may prune from the active inventory.
See the [external declaration](https://github.com/DROOdotFOO/dotfiles/blob/f788c0b6c71b7c877592e4d423de2065d8066120/home/.chezmoiexternal.toml)
and [merge script](https://github.com/DROOdotFOO/dotfiles/blob/f788c0b6c71b7c877592e4d423de2065d8066120/home/run_after_sync-skills.sh.tmpl).
The merger rebuilds non-hidden links in its `.agents/skills` destination and
assumes ownership of those links. The archive URL is unpinned.

### Chezmoi declarations restored by a skills CLI

`daviddwlee84/dotfiles` commits a small managed dependency set in a
`modify_` template. It merges those source declarations into
`~/.agents/.skill-lock.json`, preserving ad-hoc installed skills and
machine-local metadata. An apply hook reads that merged file and installs
missing skills with `npx -y skills@latest add <source> -s <name> -g -y`.
This is presence-based restoration: existing `SKILL.md` files are skipped,
and the declared sources have no immutable revision pins. The repo declares an
`onchange` hook whose trigger includes the merger's hash. Sources:
[lock merger](https://github.com/daviddwlee84/dotfiles/blob/fe0eed72b7d811d9756a97f76db34157b1f0acf0/dot_agents/modify_dot_skill-lock.json.tmpl),
[restore hook](https://github.com/daviddwlee84/dotfiles/blob/fe0eed72b7d811d9756a97f76db34157b1f0acf0/.chezmoiscripts/global/run_onchange_after_40_install_global_skills.sh.tmpl).

The same repo treats its own `chezmoi-dotfiles` skill as a normal templated
chezmoi target under `~/.agents/skills`, with a Claude symlink. Project
dependencies have a separate `skills-lock.json` and bootstrap hook. The
global dependency set, the host-rendered skill, and repository-only
dependencies have different owners.
Sources: [scope description](https://github.com/daviddwlee84/dotfiles/blob/fe0eed72b7d811d9756a97f76db34157b1f0acf0/docs/tools/agent-skills.md),
[Claude link](https://github.com/daviddwlee84/dotfiles/blob/fe0eed72b7d811d9756a97f76db34157b1f0acf0/dot_claude/skills/symlink_chezmoi-dotfiles).

### Nix source pins, dependencies, and deployment forms

Ryoppippi combines checked-in `agents/skills/` with external sources declared in
`registry/sources/*.nix`. The committed
[`sources.lock.json`](https://github.com/ryoppippi/dotfiles/blob/60863073301757c8c6232889e19b60f1b6b9b231/registry/sources.lock.json)
records resolved revisions and archive hashes. The
[Home Manager module](https://github.com/ryoppippi/dotfiles/blob/60863073301757c8c6232889e19b60f1b6b9b231/nix/modules/home/agent-skills.nix)
uses `agent-skills-nix` and selects external skills explicitly. It can attach
executable packages or transform instruction text to use their paths. It declares a
`copy-tree` target at `$HOME/.agents/skills` and a `link` target at
`.config/claude/skills`. Its
[daily workflow](https://github.com/ryoppippi/dotfiles/blob/60863073301757c8c6232889e19b60f1b6b9b231/.github/workflows/update-skill-sources.yaml)
refreshes the skill lock separately from `flake.lock` and opens a PR showing
changed revisions; it contains no auto-merge step. Nix evaluation and activation
were not performed in this survey.

The [Nix follow-up](nix-agent-skills-packaging-research.md) examines five
configurations, upstream Home Manager options, skill libraries, and native
plugin packaging in more detail.

### Native plugins published from the dotfiles repository

Vinta's development-environment repository is also a Claude marketplace.
[`marketplace.json`](https://github.com/vinta/hal-9000/blob/3098da841921c7ba7dbeae2ae5d39d2a7e28e9d3/.claude-plugin/marketplace.json)
exposes `hal-skills` from `./skills`; its
[plugin manifest](https://github.com/vinta/hal-9000/blob/3098da841921c7ba7dbeae2ae5d39d2a7e28e9d3/skills/.claude-plugin/plugin.json)
lists twelve skills and a version. Managed
[Claude settings](https://github.com/vinta/hal-9000/blob/3098da841921c7ba7dbeae2ae5d39d2a7e28e9d3/dotfiles/.claude/settings.json#L169-L197)
declare the GitHub marketplace with automatic updates and enable
`hal-skills@hal-9000`. A
[publishing skill](https://github.com/vinta/hal-9000/blob/3098da841921c7ba7dbeae2ae5d39d2a7e28e9d3/.claude/skills/publish-plugins/SKILL.md)
documents version bumps and synchronization checks for the duplicated plugin
and marketplace metadata. This is a concrete public example of keeping native
plugin distribution within the same repository as machine configuration.

## What the skills CLI actually packages

Vercel's CLI offers both copy and symlink installation. In its default
symlink mode, it copies a skill into the canonical `.agents/skills`
directory and links agent-specific destinations to that installed copy.
A local checkout is therefore not automatically the live edit location
when passed to `skills add`. In copy mode, each selected agent receives
its own copy. This is distinct from the direct source-directory links
used by the simpler dotfiles installers.
Source: [installer at 435076e](https://github.com/vercel-labs/skills/blob/435076e78988e1e6ec40d00b0b1d76bdbbc5419a/src/installer.ts#L265-L399).

The project lock stores source information, an optional ref, and a
content hash. Its restore routine rebuilds a source request and calls
the installer; it does not retrieve an artifact by that content hash.
A lockfile name alone therefore does not establish an immutable restore.
The global restore hook above is repo-specific; the upstream
`runInstallFromLock` routine inspected here reads the project lock and
targets its canonical project directory.
Sources: [local lock schema](https://github.com/vercel-labs/skills/blob/435076e78988e1e6ec40d00b0b1d76bdbbc5419a/src/local-lock.ts#L15-L36),
[project restore](https://github.com/vercel-labs/skills/blob/435076e78988e1e6ec40d00b0b1d76bdbbc5419a/src/install.ts).

## Comparison with this checkout

This repo already combines patterns present in the public examples:
local and vendored skill source, declared upstream dependencies, and
plugin distribution. Its extra layer is a shared renderer that builds
both Claude and Codex plugin manifests and their activation fragments.

The checked-in source is `home/dot_agents/packages/<package>/`, with
`skills/local`, `skills/vendor`, and APM lockfiles containing resolved
commits. Apply renders `~/.agents/plugins` and reconciles plugin installs.
The root-skill directory is a runtime stub here, so the public examples'
use of `~/.agents/skills` should not be mistaken for this repo's current
design. Sources: [package contract](../../.agents/skills/agent-skill-management/SKILL.md),
[example lockfile](https://github.com/prateek/dotfiles/blob/9a24d70664e52f119f00907929c2587305d54bc7/home/dot_agents/packages/core/apm.lock.yaml),
[renderer](https://github.com/prateek/dotfiles/blob/9a24d70664e52f119f00907929c2587305d54bc7/.agents/skills/agent-skill-management/scripts/render-agent-plugin-marketplace),
[apply hook](../../home/.chezmoiscripts/run_onchange_after_36-agent-plugins.sh.tmpl),
[root maintenance hook](../../home/.chezmoiscripts/run_onchange_after_35-agent-skill-roots.sh.tmpl).

My assessment: this repo's package grouping and plugin distribution both
have public precedents. The APM review workflow and shared renderer are
additional machinery for its chosen guarantees. The survey alone does not
establish whether that machinery should be simplified.

## Uncertainties and selection bias

The examples were selected for variety. Search favors indexed repositories
with visible skill-management documentation;
it misses private dotfiles, unindexed directories, and undocumented manual
copying. Several sampled repositories contain agent-authored operational notes,
so prose claims were checked against scripts where possible.

The survey does not establish installation reliability, cross-agent semantic
compatibility, or the authors' current live inventories. Directory linking
alone cannot establish that a skill's tool names and execution assumptions work
in each consuming agent. Existing machine receipts in public docs may be older
than the pinned repository snapshot.
