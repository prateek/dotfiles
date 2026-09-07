---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-06
updated: 2026-09-06
related:
  - public-dotfiles-skills-packaging-research.md
  - nix-agent-skills-packaging-research.md
  - apm-skill-marketplace-spike.md
status_detail: "Source survey of packaging alternatives; subsequent APM execution is recorded in the linked spike."
---

# Agent Marketplace Packaging Tools

The requirement is to package committed local and reviewed vendored skill
directories into one published source containing separate plugins, with native
Claude and Codex consumption. Deliberate vendor edits must survive packaging;
upstream retrieval belongs to a separate review/update step. Consumers should
only need their agent's native marketplace support.

This bounded survey adds a Python scaffolder, a repository-owned compiler,
Rulesync, and skillshare to the APM and Nix options already discussed. They
cover different parts of the build: plugin contents, manifests, marketplace
indexes, or installation. The comparison below identifies the work each would
leave with this repository; it does not select a migration.

## Evidence and scope

Inspected primary documentation and executable source through read-only GitHub
APIs on 2026-09-06. GitHub source links pin the inspected revisions; snapshot
dates below are commit dates. No downloaded code was executed, no dependency
was installed, and no marketplace was loaded into an agent. The installed APM
CLI was queried for its version. Artifact generation is source-level evidence;
successful native installation was untested at this survey stage. The subsequent
[APM spike](apm-skill-marketplace-spike.md) records native execution and supersedes
the source-only compatibility inferences below for that candidate.

| Candidate and snapshot | Verified output | Fit for this requirement |
| --- | --- | --- |
| [APM](https://github.com/microsoft/apm/tree/045f78cd71e56b9029e1b4193f7e4d4a46b00086), 2026-09-06 | Plugin bundles and both marketplace catalog formats | Existing general CLI candidate; curated inputs and native manifest layout need adaptation |
| [agent-plugins-nix](https://github.com/Kyure-A/agent-plugins-nix/tree/324168d2afbb7a50a5c87bed2b59d97291b23512), 2026-08-14 | Individual Claude and Codex plugin artifacts, with portable output mode | Can build from committed files independently of installation; marketplace indexes remain ours |
| [Skill Packager](https://github.com/yaniv-golan/skill-packager-skill/tree/ca4750e2ba9d91a8d07e136c9d44cc5ae547dcc0), 2026-08-29 | Claude and Codex plugin manifests and marketplace catalogs | Local inputs work; each run has one plugin and one catalog entry |
| [wondelai/skills](https://github.com/wondelai/skills/tree/eade5d170b3a593c5b6ebcaca898102134aee108), 2026-08-29 | Codex catalog and collection plugins derived from a Claude catalog | Closest complete public pattern; compiler is specific to its repository |
| [Rulesync](https://github.com/dyoshikawa/rulesync/tree/ec15febdc845cd226fd14d80e6d72719c90ebaf6), 2026-09-05 | Components inside existing Claude plugin directories | Requires separate manifests/catalog generation and Codex packaging |
| [skillshare](https://github.com/runkids/skillshare/tree/60e19f96d540e2b3fb1c28a68ef61d9fb8eb1897), 2026-09-05 | Skill-directory symlinks/copies and ownership manifests | Synchronization layer; native marketplace packaging remains separate |

## Skill Packager: executable scaffolder, one plugin per repository

The project includes a Python CLI with `metadata`, `scaffold`, `validate`,
`build-zip`, and `bump-version` commands. Packaging can run from a supplied
manifest without agent reasoning. Its source supports absolute and
manifest-relative `source_path` directories and copies their local contents;
the scaffold implementation does not retrieve upstream repositories.
[CLI](https://github.com/yaniv-golan/skill-packager-skill/blob/ca4750e2ba9d91a8d07e136c9d44cc5ae547dcc0/skill-packager/skills/skill-packager/scripts/skill_packager/__main__.py),
[source resolution and copying](https://github.com/yaniv-golan/skill-packager-skill/blob/ca4750e2ba9d91a8d07e136c9d44cc5ae547dcc0/skill-packager/skills/skill-packager/scripts/skill_packager/scaffold.py#L42).

The model is one `plugin_name` plus `skills[]`. Both native manifests reference
the same generated `<plugin>/skills/` tree. Both marketplace templates contain
exactly one plugin entry, and scaffolding rejects a nonempty destination.
Producing separate `core`, `review`, and vendor plugins in one catalog would
therefore require an aggregation layer or changes to the tool. This is a
scaffolding workflow, with no repeated source-to-output reconciliation contract.
[Scaffold](https://github.com/yaniv-golan/skill-packager-skill/blob/ca4750e2ba9d91a8d07e136c9d44cc5ae547dcc0/skill-packager/skills/skill-packager/scripts/skill_packager/scaffold.py#L211),
[marketplace templates](https://github.com/yaniv-golan/skill-packager-skill/blob/ca4750e2ba9d91a8d07e136c9d44cc5ae547dcc0/skill-packager/skills/skill-packager/scripts/skill_packager/templates.py#L56).

The copy rule preserves files inside selected skills, including `SOURCE.md`,
`LICENSE`, `agents/openai.yaml`, and helper scripts, apart from a small cache
ignore list. However, scaffolding injects `metadata.version` into `SKILL.md`
when a version is not detected. Universal/Agent Skills output additionally
rewrites selected `${CLAUDE_SKILL_DIR}` path uses in portable copies. The shipped
manifest redirects source paths to generated copies, and the root `LICENSE`
comes from a fixed MIT template. These behaviors need explicit adaptation for
reviewed vendor bytes and mixed licenses.
[Copy and version logic](https://github.com/yaniv-golan/skill-packager-skill/blob/ca4750e2ba9d91a8d07e136c9d44cc5ae547dcc0/skill-packager/skills/skill-packager/scripts/skill_packager/scaffold.py),
[path and ignore rules](https://github.com/yaniv-golan/skill-packager-skill/blob/ca4750e2ba9d91a8d07e136c9d44cc5ae547dcc0/skill-packager/skills/skill-packager/scripts/skill_packager/path_hygiene.py).

Version management also follows one package: `bump-version` updates manifests
and skill versions together. Templates use the current date/year, so identical
inputs across dates do not guarantee identical repository output. The Codex
catalog points to the published repository's `main` through `git-subdir`; this
is a native consumer fetch, separate from the offline packaging operation.
[Version updater](https://github.com/yaniv-golan/skill-packager-skill/blob/ca4750e2ba9d91a8d07e136c9d44cc5ae547dcc0/skill-packager/skills/skill-packager/scripts/skill_packager/bump_version.py),
[template variables](https://github.com/yaniv-golan/skill-packager-skill/blob/ca4750e2ba9d91a8d07e136c9d44cc5ae547dcc0/skill-packager/skills/skill-packager/scripts/skill_packager/scaffold.py#L130).

## Wondelai: one Claude catalog drives separate Codex plugins

Its committed Claude marketplace contains named collections with explicit skill
membership, versions, and `source: "./"`. A Bash/jq compiler reads that catalog,
creates one Codex marketplace entry per collection, and writes
`plugins/<collection>/.codex-plugin/plugin.json` beside copied skill directories.
Claude continues to use the original catalog and source directories. Once the
generated output is published, consumers can use their native formats without
the generator.
[Claude catalog](https://github.com/wondelai/skills/blob/eade5d170b3a593c5b6ebcaca898102134aee108/.claude-plugin/marketplace.json#L13),
[compiler](https://github.com/wondelai/skills/blob/eade5d170b3a593c5b6ebcaca898102134aee108/scripts/generate-plugins.sh#L57).

Generation uses local `cp -R`, with no source fetching or skill-content rewrite.
Files inside each selected directory travel together; `.DS_Store` files are
removed and generated symlinks are rejected. This naturally includes reviewed
vendor content when staged in the expected layout. The compiler assumes
repo-root skill directories, contains project-specific branding, and fully
replaces its generated output directories. Missing `SKILL.md` entries produce
a warning and are skipped, so its existing checks do not guarantee that every
declared skill was packaged.
[Copy and validation implementation](https://github.com/wondelai/skills/blob/eade5d170b3a593c5b6ebcaca898102134aee108/scripts/generate-plugins.sh#L91).

Each collection has a version field, but the release helper deliberately sets
all collections to one release version before regenerating. This is a useful
small-compiler reference for our renderer: explicit membership, local payloads,
and native outputs. Adopting it requires maintaining our own adapted script.
Its additional root `plugin.json` files implement another format and are not
the Claude manifests.
[Version workflow](https://github.com/wondelai/skills/blob/eade5d170b3a593c5b6ebcaca898102134aee108/scripts/sync-marketplace-versions.sh),
[output manifests](https://github.com/wondelai/skills/blob/eade5d170b3a593c5b6ebcaca898102134aee108/scripts/generate-plugins.sh#L69).

## Rulesync: component conversion inside an existing plugin

Rulesync now has a real `claudecode-plugin` output target. It generates selected
skills, commands, subagents, MCP, and hooks from `.rulesync/` into an existing
plugin root. Its documented boundary leaves plugin metadata, marketplace
catalogs, and other package assets with the repository owner. Source declares
only Claude and Antigravity packaging targets; ordinary Codex skill support
does not add native Codex plugin or catalog generation.
[Packaging contract](https://github.com/dyoshikawa/rulesync/blob/ec15febdc845cd226fd14d80e6d72719c90ebaf6/docs/guide/plugin-packaging.md#L10),
[packaging target enumeration](https://github.com/dyoshikawa/rulesync/blob/ec15febdc845cd226fd14d80e6d72719c90ebaf6/src/types/tool-targets.ts#L23).

Skill conversion carries the body and auxiliary files while constructing
target-specific frontmatter. Adopting its canonical representation would
therefore introduce a conversion boundary for reviewed vendor skills. It is
worth considering if cross-agent component translation becomes a separate
requirement; it still leaves plugin grouping, versions, and both catalogs to
another layer.
[Claude skill conversion](https://github.com/dyoshikawa/rulesync/blob/ec15febdc845cd226fd14d80e6d72719c90ebaf6/src/features/skills/claudecode-skill.ts#L622).

## Skillshare: local content synchronization

Skillshare recursively discovers `SKILL.md` directories and projects them into
agent skill roots through symlink, merge, or copy modes. Its target registry
names Claude and Codex skill directories. Copying operates on local files with
ignore rules and symlink dereferencing; upstream installation/update is a
separate command surface. It could synchronize a reviewed local source tree.
[Discovery and copy implementation](https://github.com/runkids/skillshare/blob/60e19f96d540e2b3fb1c28a68ef61d9fb8eb1897/internal/sync/sync.go),
[target registry](https://github.com/runkids/skillshare/blob/60e19f96d540e2b3fb1c28a68ef61d9fb8eb1897/internal/config/targets.yaml#L45).

The inspected CLI and sync implementation produce skill projections and a
`.skillshare-manifest.json` tracking owned names/checksums. That ownership
manifest supplies no native marketplace or plugin grouping. Using skillshare
for authoring or acquisition would leave this task's publishing layer intact.
[CLI surface](https://github.com/runkids/skillshare/blob/60e19f96d540e2b3fb1c28a68ef61d9fb8eb1897/cmd/skillshare/main.go#L211),
[ownership manifest](https://github.com/runkids/skillshare/blob/60e19f96d540e2b3fb1c28a68ef61d9fb8eb1897/internal/sync/manifest.go#L10).

## APM: bundle production and marketplace compilation

APM's marketplace builder emits Claude and Codex catalogs from one declaration,
including local relative-path entries. Plugin bundling is a separate operation:
per-package `apm pack` builds the contents, while a root marketplace declaration
builds the index. The inspected exporter writes a root `plugin.json`; that is
different from our paired `.claude-plugin/plugin.json` and
`.codex-plugin/plugin.json` output.
[Output mappers](https://github.com/microsoft/apm/blob/045f78cd71e56b9029e1b4193f7e4d4a46b00086/src/apm_cli/marketplace/output_mappers.py),
[plugin exporter](https://github.com/microsoft/apm/blob/045f78cd71e56b9029e1b4193f7e4d4a46b00086/src/apm_cli/bundle/plugin_exporter.py#L800),
[publisher workflow](https://microsoft.github.io/apm/producer/pack-a-bundle/#multi-plugin-marketplace-publisher).

Project-owned local primitives are valid packaging inputs. Local-path
dependencies are rejected by the exporter, while remote dependency contents
come from lockfile-attested `deployed_files` and their recorded hashes. A local
edit to an attested dependency file therefore fails verification. Our reviewed
vendor copies would need to enter the packaging project as local owned content,
with provenance retained separately, rather than as local dependency references.
The subsequent [APM spike](apm-skill-marketplace-spike.md) demonstrated a simpler
source-publication route that generates native manifests and catalogs without
using the bundle exporter. Codex accepted APM's Claude manifest as a fallback;
two static Codex manifests preserved the existing hook suppression policy.
[Dependency guard and collection](https://github.com/microsoft/apm/blob/045f78cd71e56b9029e1b4193f7e4d4a46b00086/src/apm_cli/bundle/plugin_exporter.py#L837),
[local component collection](https://github.com/microsoft/apm/blob/045f78cd71e56b9029e1b4193f7e4d4a46b00086/src/apm_cli/bundle/plugin_exporter.py#L930).

The installed APM CLI reported `0.13.0` during this discussion. These findings
describe the inspected upstream revision and current documentation, not a
successful run of those newer features on the installed CLI.

## agent-plugins-nix: independent plugin artifact builds

The library's skill-only example discovers committed relative skill paths,
selects skills, bundles them, and projects Claude and Codex artifacts. Our local
and curated directories can supply those paths; skill content need not be
fetched from upstream. Nix's own library and build dependencies still need to
be available. Its public API exposes artifact generation independently of its
installer and Home Manager module, but has no marketplace-index generator.
[Local skill example](https://github.com/Kyure-A/agent-plugins-nix/blob/324168d2afbb7a50a5c87bed2b59d97291b23512/examples/skill-only.nix),
[public API](https://github.com/Kyure-A/agent-plugins-nix/blob/324168d2afbb7a50a5c87bed2b59d97291b23512/lib/default.nix).

Portable output requires marking the skill component portable and requesting
a portable target projection. Both adapters materialize files and reject
remaining symlinks or `/nix/store` references. The finished files can therefore
be distributed separately from Nix, subject to the skills' actual runtime
dependencies. This checks file portability; it does not discover commands
mentioned in skill prose.
[Skill provider](https://github.com/Kyure-A/agent-plugins-nix/blob/324168d2afbb7a50a5c87bed2b59d97291b23512/lib/providers/agent-skills-nix.nix),
[Claude adapter](https://github.com/Kyure-A/agent-plugins-nix/blob/324168d2afbb7a50a5c87bed2b59d97291b23512/lib/adapters/claude.nix),
[Codex adapter](https://github.com/Kyure-A/agent-plugins-nix/blob/324168d2afbb7a50a5c87bed2b59d97291b23512/lib/adapters/codex.nix).

This is distinct from `agent-skills-nix.mkAgentPlugin`. That separate exporter
only produces a Codex skill plugin and rejects `packages`, transforms, and
`disable-model-invocation: true`. Those restrictions do not automatically apply
to `agent-plugins-nix`, whose skill provider uses `mkBundle`. See the
[Nix report](nix-agent-skills-packaging-research.md#portable-export-has-a-narrower-contract)
for the exporter evidence and the rest of the Nix installation comparison.

## Comparison for this checkout

APM is the general CLI option to evaluate for marketplace authoring.
`agent-plugins-nix` is worth considering if Nix will own artifact builds;
we would still assemble the marketplace around its plugin outputs. Skill
Packager provides reusable templates and helpers, but its single-plugin
scaffolding model needs more adaptation for a maintained collection. Wondelai
demonstrates a small compiler with the required separate-plugin structure.
Rulesync becomes relevant when component translation is itself a requirement;
skillshare covers synchronization.

Vercel's `skills` CLI also remains an acquisition/installation option. The
inspected command dispatcher has no native plugin or marketplace build command.
See its [CLI source](https://github.com/vercel-labs/skills/blob/435076e78988e1e6ec40d00b0b1d76bdbbc5419a/src/cli.ts#L332)
and the [earlier installation findings](public-dotfiles-skills-packaging-research.md#what-the-skills-cli-actually-packages).

Our existing [renderer](https://github.com/prateek/dotfiles/blob/9a24d70664e52f119f00907929c2587305d54bc7/.agents/skills/agent-skill-management/scripts/render-agent-plugin-marketplace)
already combines local/vendor sources and emits the two native formats. A
replacement should be compared against extracting that implementation into a
standalone build, including the existing source filename handling and invocation
policies. This survey establishes candidates and adaptation costs; it is not
an exhaustive registry survey, a runtime compatibility test, or evidence of
market share.
