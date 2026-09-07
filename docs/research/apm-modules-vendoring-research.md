---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-06
updated: 2026-09-06
related:
  - ../plans/apm-agent-marketplace-plan.md
  - apm-skill-marketplace-spike.md
status_detail: "Pinned APM 0.29.1 source investigation and disposable Git ignore probe. Committed-cache acquisition and rebuild remain unexecuted acceptance gates."
---

# Committing APM Modules as Reviewed Source

Committing each package's `apm_modules/` is a reasonable first replacement for
our separately copied upstream skill store. Keep these dependency snapshots
unchanged after acceptance. Put local skills and review deltas beside them,
then assemble the selected payload into an ignored native marketplace build.
The proposed root `agent-marketplace/` can own this workflow through its own
Makefile. APM owns acquisition and dependency layout; our remaining assembly
owns plugin membership and reviewed edits.

This recommendation follows source inspection of APM 0.29.1 at
[1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc](https://github.com/microsoft/apm/tree/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc).
The source was read through `utils-agent:ask` from the cache returned for
`github:microsoft/apm@v0.29.1`; the release tag was checked against that exact
commit. This follow-up executed only the disposable Git probe below. It did
not run APM acquisition, reinstall, or registry commands. The earlier
[spike](apm-skill-marketplace-spike.md) supplies the executed native publication
evidence, including the bundle export failures.

## What the committed tree contains

APM's physical layout follows dependency sources. A Git repository normally
lives at `apm_modules/<owner>/<repo>/`; a selected subdirectory retains its
suffix under that path. Direct local packages use `_local/<basename>/`, with
an additional parent-derived slot for anchored transitive local packages.
The path preserves repository spelling and does not include a host namespace.
It is therefore unsuitable as the native layout of our ten curated plugins
without a publication selection map.
[Path builder](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/models/dependency/materialization.py#L113-L177),
[identity boundary](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/models/dependency/reference.py#L461-L499).

These are APM materializations. For legacy plugin inputs, APM copies discovered
components into `.apm/`, synthesizes `apm.yml`, and keeps normalization receipts.
The original plugin component directories remain alongside those copies.
Preserve the complete accepted materialization, including APM-generated
metadata, so its lockfile hash still describes the committed bytes.
[Plugin normalization](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/deps/plugin_parser.py#L459-L663),
[skill receipts](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/deps/plugin_parser.py#L299-L386).

The normal hooks-directory importer copies supporting files into `.apm/hooks`.
An inline hook object or a manifest pointing at a hook configuration file
copies only that configuration through this normalization path. Publication
must carry each selected hook's actual helpers from the retained source and
verify its command paths. The earlier spike already demonstrated that the
bundle exporter can drop these helpers even when packing succeeds.
[Hook import branches](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/deps/plugin_parser.py#L1297-L1337),
[executed bundle results](apm-skill-marketplace-spike.md#why-the-bundle-route-failed).

Remote whole-repository acquisition skips or removes the root `.git` directory.
Local acquisition recursively copies entries without a general `.git` filter,
and always replaces its `_local` copy. It dereferences symlinks within the
package and rejects escaping or broken targets. Remote copy helpers also
dereference links by default. A local dependency consequently provides a
copied input, rather than a live link to a skill directory. Check the accepted
cache and exported payload for nested Git metadata and unresolved links;
the remote root cleanup is not a universal guarantee for every source shape.
[Remote download](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/deps/github_downloader.py#L1892-L2008),
[local copy](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/install/phases/local_content.py#L100-L291),
[remote copy default](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/utils/file_ops.py#L234-L296).

## Acquisition and reviewed edits

Prefer native `apm lock` for acquisition and `apm lock --update` for upstream
refreshes, invoked from each dedicated package directory. The command runs
resolution and downloading, records commit/content hashes, and sets
`lockfile_only=True`. That mode skips agent deployment and the install-time
`.gitignore` update. This is a cleaner candidate than a new staging importer;
its public CLI behavior still needs an isolated execution check.
[Lock command](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/commands/lock.py#L1-L35),
[pipeline invocation](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/commands/lock.py#L220-L240),
[Git ignore condition](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/install/pipeline.py#L807-L813).

Require the selected package's cache and lockfile to be clean before fetching
or updating.
Review the resulting Git diff before accepting the new snapshot. Lock-only
resolution skips cleanup. For dependency removal, edit the manifest and run
`apm lock`; require the deleted dependency's lock keys to be absent before
reviewing `apm prune --dry-run`. Prune should then remove only cache leftovers,
with no further lock-key removals. It retains declared dependencies and locked
transitive nodes.
[Lock behavior](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/docs/src/content/docs/reference/cli/lock.md#L18-L74),
[prune contract](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/docs/src/content/docs/reference/cli/prune.md#L8-L105).

Empty deployment records alone do not confine prune to the cache. Whenever
prune removes lock keys, it reconciles surviving hooks against the manifest's
targets; `targets: [claude]` can therefore write Claude configuration even
without earlier deployment records. Reconciliation failures may only warn.
Gate the proposed lock-then-prune sequence on an isolated surviving-hook fixture
that proves only the intended package cache/lock writes. If either the lock-key
invariant or that check fails, defer pruning and exclude unreferenced cache
directories from publication. This remains a source-backed, unexecuted gate.
[Prune hook reconciliation](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/commands/prune.py#L366-L398),
[surviving-hook rebuild](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/integration/hook_integrator.py#L1977-L2028).

Keep patches and overlays outside `apm_modules`. Cached content that differs
from its recorded hash can be deleted and downloaded again; a fresh download
that still disagrees is rejected. Apply reviewed changes to temporary build
copies. A failed patch must stop the build until the upstream change is
reviewed.
[Cached mismatch handling](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/install/phases/integrate.py#L252-L276),
[download verification](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/install/sources.py#L803-L843).

The [revised plan](../plans/apm-agent-marketplace-plan.md#folder-and-ownership)
uses the APM lock for upstream identity and retires our generated `SOURCE.md`
files. This removes provenance generation from assembly. Upstream files and
local patches remain inputs to the build.

Normal `apm install` adds an exact `apm_modules/` ignore rule unless that line
already exists. This explicit package-level sequence accommodates it:

```gitignore
apm_modules/
!apm_modules/
!apm_modules/**
```

A disposable Git repository confirmed that this admits ordinary payload and
`.apm/` files. It also confirmed that an upstream `.gitignore` deeper inside
the module can still hide newly acquired files. Scoped `git add --force` of
the reviewed cache captured those files. Acceptance must compare the tracked
archive against the intended cache, including executable state; checking files
present in the working tree is insufficient. The fixture was removed, and
this probe did not execute APM.
[APM ignore helper](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/commands/_helpers.py#L490-L518).

## Offline rebuild and validation limits

APM's separate machine cache contains bare Git repositories and per-commit
checkouts, plus HTTP responses. It accelerates downloads; committing
`apm_modules` need not include that cache. Plain/frozen installs can reuse
locked content, while update/refresh commands consult upstream for mutable
refs. `install --frozen` validates lockfile structure and does not prohibit
network access. There is no `install --offline` flag in this version;
`pack --offline` is described as marketplace cached-ref behavior.
[Cache contract](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/docs/src/content/docs/reference/cli/cache.md#L20-L39),
[install options](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/docs/src/content/docs/reference/cli/install.md#L28-L145),
[pack flag](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/commands/pack.py#L225-L231).

The planned regular build reads committed files directly, validates the
selected payload, and generates native publication metadata. After tool
provisioning, a clean Git export must rebuild with network denied and an empty
machine cache. A missing committed input should fail locally and direct the
user to restore it from Git or a complete source export. Fetch still requires
clean cache/lock inputs. This gate remains unexecuted for the committed
`apm_modules` design.

Native lock acquisition skips the current importer's content scans: empty
targets bypass the integration scanner, and lock-only mode skips the audit
phase. The accepted plan retains source-surface checks and scans the selected
payload after local patches/overlays. These checks must run offline without
agent deployment before build output is ready for consumers. Hash validation
does not replace a scan for hidden control characters.
[Integration early return](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/install/template.py#L309-L313),
[audit skip](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/install/pipeline.py#L909-L917),
[existing rejection test](../../tests/python/agents/test_packages.py).

Lockfile content hashes cover sorted regular-file paths and raw bytes. They
exclude symlinks, `.git`, `__pycache__`, and root `.apm-pin`, and ignore
permissions. The `.apm-pin` marker records the resolved commit; drift replay
checks it against the lock before reusing a remote directory. Preserve both
hashes and markers, but retain our independent payload/mode validation and
paired human-only invocation checks. A cache marker match alone cannot prove
payload integrity.
[Hash implementation](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/utils/content_hash.py#L1-L103),
[replay verification](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/install/drift.py#L239-L262),
[marker contract](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/src/apm_cli/install/cache_pin.py#L1-L31).

Minimal publication assembly still selects complete skill trees into curated
plugins, copies required helpers and other accepted payloads, and applies local
deltas. APM then generates the package manifests and catalogs using the native
source route established by the spike. No additional
dependency resolver or second committed curated copy is required by this
design. Inventory parity and a relocated native-consumer check remain required
before replacing the current vendoring workflow.

## Deferred registry and mirror work

APM already has two distinct extension points worth revisiting later:

- A dedicated REST registry, enabled through the experimental `registries`
  feature, supports version resolution and immutable archive publication with
  `apm publish`. Its flat APM archive differs from a native plugin marketplace.
  [Registry guide](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/docs/src/content/docs/guides/registries.md#L8-L33),
  [publication format](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/docs/src/content/docs/guides/registries.md#L294-L353).
- `PROXY_REGISTRY_URL` routes Git-hosted package acquisition through an
  Artifactory-compatible archive mirror; `PROXY_REGISTRY_ONLY=1` blocks direct
  fallback. An internally hosted marketplace provides discovery separately.
  [Mirror controls](https://github.com/microsoft/apm/blob/1b3d80ad2bfcb7ab3ce24bdac0538855aaddf3bc/docs/src/content/docs/enterprise/registry-proxy.md#L8-L112).

Keep operating a registry and designing a shared offline acquisition cache as
TODOs. Neither is necessary for building the accepted committed snapshot.
Their archive preservation and restore behavior have not been tested here.
