# Agent marketplace

This folder builds Prateek's Claude and Codex plugins from authored skills and
reviewed APM dependencies. Copy the whole folder to another directory to use it
without dotfiles or chezmoi.

APM owns acquisition, locks, Claude manifests, and both marketplace catalogs.
Git retains the accepted dependency bytes. The build assembles native plugin
directories; consumer adapters decide where to put them and which to enable.

## Build and export

Provision the pinned Python, uv, and APM environment once with network access:

```sh
make tools
```

Then run:

```sh
make build
make check
make export
```

`build/marketplace` contains both catalogs and `plugins/<package>`. `check`
executes the packaging tests and compares two fresh builds. `export` writes
`build/marketplace.tar.gz`; it refuses an unchecked, damaged, or stale artifact.
`make clean` removes only `build/`.

Builds use committed input files and `apm pack --offline`. A missing cache file
is an error, with its path and a recovery instruction. Restore that file from
Git (`git restore -- path/to/file`) or recopy a complete source export. Builds
never invoke acquisition. Tool provisioning and upstream acquisition may need
network access; a provisioned source export has been built under network denial.

`release.json` records the input digest, Git revision/dirty state when available, APM version,
and every artifact file's hash and mode. It is a release receipt, not an upstream
provenance store. It lets a consumer validate the artifact with Python's standard
library, without APM or the source cache. Keep complete exports for recovery.

Inside Git, cache executable bits must match the index; review and stage an
intentional mode change before building it. A standalone source export trusts
the modes preserved by its archive. Copy tools that drop executable bits do not
provide an equivalent source export.

## Source layout

The project root owns one dependency graph shared by all plugins:

| Input | Ownership |
| --- | --- |
| `apm.yml` | Marketplace membership and all `devDependencies.apm` declarations |
| `apm.lock.yaml` | APM's accepted resolution; acquire it through APM |
| `apm_modules/` | Pristine fetched content and normalization receipts |

## Edit a package

Each directory under `packages/` defines a separate native plugin. It has no APM
manifest, lock, or cache:

| Input | Ownership |
| --- | --- |
| `skills/<name>/` | Authored skills, edited directly |
| `publish.toml` | Selected cached paths, curated directory aliases, extra payloads |
| `patches/*.patch` | Reviewed edits applied in filename order to temporary plugin trees |
| `overlays/` | Local additions at their published relative paths |
| `.codex-plugin/plugin.json` | Plugin identity, version, shared metadata, and Codex interface fields |
| `hooks/`, `evals/`, other native payloads | Authored supporting files |

Use native filenames throughout this project. Chezmoi does not traverse this
source directory, so no `literal_` conversion is needed.

Selections refer to dependency identities in the root lock and paths within their
shared cache roots. Several plugins can select the same input; each plugin's
patches and overlays apply to its own build copy:

```toml
[[skills]]
name = "curated-name"
dependency = "owner/repo"
path = ".apm/skills/upstream-name"

[[payloads]]
dependency = "owner/repo"
path = ".apm/hooks"
target = "hooks"

[[payloads]]
dependency = "owner/repo"
path = "LICENSE"
target = "licenses/owner/repo/LICENSE"
```

`exclude = ["skills"]` can omit a top-level child of a selected directory.
Aliases describe published directories; frontmatter skill names remain intact.
Unused cache directories never become publication inputs automatically.
Each selected path must be a skill directory containing its own `SKILL.md`.
Authored and overlay skill directories follow the same rule. Every selected or
authored root must still have its entrypoint after patches and overlays; retire
an imported skill by removing its selection.

Patches use native plugin paths, such as `a/skills/curated-name/SKILL.md`. They
apply to unmodified selected upstream content; aliases mean the patch's paths
may need remapping before submitting it upstream. Keep replacements in patches
and additions in overlays. Collisions, escaping paths, symlinks, stale patches,
unsupported dependency components, and critical APM content-scan findings fail
before replacing the previous build. The scanner runs after local changes.
Python `__pycache__` entries are excluded from both source fingerprints and
publication without following cache symlinks. Running an unchanged authored
Python helper therefore does not change the artifact through its bytecode cache.

For a human-only skill, pair `disable-model-invocation: true` in `SKILL.md` with
`policy.allow_implicit_invocation: false` in `agents/openai.yaml`. The build
checks both directions. Hook-bearing packages keep `hooks: {}` in their Codex
manifest under the current Codex skills-only policy.

Bump the version in `.codex-plugin/plugin.json` when published content or metadata
changes. The build derives a temporary APM publication manifest from that file,
with `targets: [claude]` and no `dependencies` key, then calls native APM to generate
the Claude manifest and both catalogs. The temporary manifests are removed after
packing; consumers receive native plugin files and the release receipt.

The root `apm.yml` lists each plugin's relative output path. Catalogs describe
availability independently of a machine's activation policy. Do not add
per-plugin APM projects or duplicate dependency declarations in `publish.toml`.

## Acquire or update upstream inputs

Start with an accepted, clean cache and lock. Both commands refuse tracked,
staged, untracked, and ignored pending cache/lock changes before calling APM:

```sh
make fetch                   # native apm lock at the project root
make update                  # native apm lock --update for all root dependencies
```

Edit root declarations before `fetch` when adding or removing dependencies.
`PACKAGE=...` is rejected. An update leaves the complete shared cache and lock
diff for review. Adjust patches if necessary, bump each affected plugin's version,
rebuild, and inspect the published diff. Local patches and authored skills are
outside APM's cache and survive acquisition.

APM locks do not deploy skills or configure agents. Keep lockfiles free of old
agent deployment claims. APM Git inputs have content hashes and `.apm-pin`
receipts; both are checked using the pinned producer. Local-directory APM cache
entries lack those receipts/hashes in 0.29.1, so this publication workflow uses
`skills/` for authored local content instead.

Upstream `.gitignore` files can hide new fetched files. Include the **complete**
cache in review and acceptance:

```sh
git add --intent-to-add --force -- apm_modules
git diff -- .
# After review, stage the lock, complete cache, metadata, and local changes together.
git add --force -- apm_modules
git add -- apm.lock.yaml apm.yml packages/core
```

The project attributes preserve raw cache line endings. Native Git commits retain
executable bits; APM's hashes alone do not. Inspect mode changes alongside bytes.
Our initial native lock files were normalized from APM's mode 0600 to Git's
regular-file mode 0644; published payload modes were unchanged.

Before removing a declaration, check every plugin's skill and supporting-payload
selections for remaining uses. The console checks ownership across plugins both
when planning a deletion and immediately before writing it. After removing a
declaration, run `fetch` and confirm the resulting lock no longer contains that
dependency. Only then, from the project root,
consider `apm prune --dry-run` followed by `apm prune` using APM 0.29.1. This order
has been exercised with a surviving hooks dependency. A prune that removes keys
from the lock itself may deploy surviving hooks. Leaving unused cache directories
is safe: selections and the accepted dependency graph determine publication.

We retain upstream license/notice files, including upstream-owned `SOURCE.md`
files. We generate no per-skill `SOURCE.md`; repository identity and resolved
revisions come from native locks, and Git records acceptance.
When selecting a subdirectory, review its upstream root for license and notice
files and add explicit payload selections under `licenses/<owner>/<repo>/` for
any texts that the selected tree does not already include. Inspect the exported
plugin too; retaining notices only in `apm_modules/` does not ship them to clients.

## Consumers and future work

The dotfiles adapter is documented in
[Agent Marketplace](../docs/references/agent-marketplace.md). Its host policy,
chezmoi scripts, and native install reconciliation live outside this project.
A Nix consumer can build this folder or consume the same artifact.

An artifact-root Git repository can distribute releases without exposing the
source layout. Remote publication is a separate action. A future APM registry or
mirror can cache acquisition by immutable revision; it is not needed to build
from the committed modules or install a retained artifact during an outage.
