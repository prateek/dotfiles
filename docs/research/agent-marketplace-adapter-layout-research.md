---
status: active
doc_type: research
summary: "Whether adapter plugin definitions can live under vendor/ or upstream catalog entries, and whether one root manifest can replace per-plugin publish.toml and plugin.json files."
owner: Prateek
created: 2026-10-20
updated: 2026-10-20
related:
  - ../plans/agent-marketplace-layout-plan.md
  - ../adr/0023-apm-agent-marketplace-packaging.md
  - ../adr/0025-shared-apm-acquisition.md
  - ../adr/0049-official-agent-plugin-marketplaces.md
---

# Agent marketplace adapter layout

Prateek asked two questions about the layout planned in
[the plan](../plans/agent-marketplace-layout-plan.md), which puts
hand-written inputs in `src/<plugin>/` and vendored code in `vendor/`:

1. Do adapter plugins need directories under `src/` at all, or can they live
   in `vendor/`?
2. Can one `publish.toml` replace the per-plugin files?

The evidence comes from the build (`agent-marketplace/scripts/marketplace.py`),
the installed APM 0.29.1 source
(`agent-marketplace/.venv/lib/python3.14/site-packages/apm_cli/`), the console,
and the activation data. Each claim is marked **verified**, meaning read in
code or data, or **inferred**.

## What an adapter is today

Ten plugins have no authored skills: apple-hig, better-writing, crit,
ios-tools, mattpocock, obsidian, obsidian-wiki, pstack, shortcut, and
ui-ux-pro-max. Each one has:

- `.codex-plugin/plugin.json`
- `publish.toml`, except utils-human, which is not an adapter
- one `001-*.patch` in seven of the ten (none in apple-hig, obsidian, or
  shortcut)
- `overlays/` in pstack only

**Verified.**

Why the adapters exist is also verified. Nine of the ten are **Codex-only**.
`home/.chezmoidata/agent_plugins.toml` sets `claude = false, codex = true`
for apple-hig, crit, ios-tools, mattpocock, obsidian, obsidian-wiki, shortcut,
better-writing, and ui-ux-pro-max (lines 3–86). Their official upstream
marketplaces are registered for Claude only (`codex = false`) in
`agent_upstream_plugins.toml`. ADR 0049 explains why: "A client without a
compatible upstream catalog receives a documented local adapter"
(`docs/adr/0049-official-agent-plugin-marketplaces.md:47-50`). Codex's remote
catalog does not honor local enabled settings (lines 24–26). Pstack is the
exception. It is enabled for both clients because its upstream catalog
targets Cursor (`docs/references/agent-marketplace.md:80-84`), and it mirrors
human-only invocation controls (`packages/pstack/publish.toml:1`).

So an adapter is a small Codex compatibility recipe: a selection, a
manifest, and usually one patch.

## A. Could adapters live under `vendor/`?

### Inside `apm_modules/<owner>/<repo>/`: no

- **Verified:** the build recomputes each module's content hash and fails on
  any difference: `compute_package_hash(module) != dependency.content_hash`
  (`marketplace.py:104`). Adding a single adapter file inside a module dir
  breaks every build.
- **Verified:** `fetch`/`update` refuse untracked or ignored changes under
  `apm_modules/` (`marketplace.py:375-387`). Committed files pass that check,
  but the hash check above still fails.
- **Inferred, not tested:** `apm lock --update` replaces a module dir when
  upstream changes. A hand-written file inside it would be lost or would block
  the update.

### Beside the modules, e.g. `vendor/apm_modules/_adapters/` or `vendor/adapters/`: it works but is misleading

- **Verified:** APM's package scan only counts directories containing
  `apm.yml` or `.apm` (`commands/deps/_utils.py:11-35`). `apm prune` would
  ignore a plain `_adapters/` dir and would not delete it.
- **Inferred:** nothing in the build would stop a `vendor/adapters/` tree.
  The build reads selections from wherever it is told.
- **Cost:** it breaks the rule the layout exists to make true: "`vendor/` is
  fetched; never edit it." Adapter patches are reviewed local edits, the same
  kind of file as an authored skill. It also leaves two hand-edited homes
  again, only renamed.

### Point catalog entries straight at upstream: possible in APM, wrong for this job

- **Verified:** APM's marketplace schema accepts remote package sources:
  `owner/repo`, host-qualified, or HTTPS, with `subdir`, `ref`, and `sha`
  (`marketplace/yml_schema.py:28-29, 343-347`). For both Claude and Codex it
  emits `git-subdir`, `url`, or `github` sources
  (`marketplace/output_mappers.py:241-263, 355-372`). So a catalog entry needs
  no local directory.
- **Inferred:**
  - The client would then fetch from GitHub at install time, which loses the
    committed bytes, offline apply, patches, notice selections, and
    `mirror_invocation_controls`. That breaks ADR 0023's guarantees and is
    risky on work-mbp, where the corp filter blocks some GitHub fetches.
  - Upstream `.apm/skills` collections are not plugin roots, so the entry
    would also need a plugin manifest in the upstream repo.
  - Where upstream does ship a Codex-compatible plugin, ADR 0049's
    official-marketplace path already covers it without a local catalog entry.
- **Not checked:** whether `apm pack --offline` resolves remote entries without
  network access when a `sha` is pinned.

**Conclusion (A):** adapters need a hand-written home outside `apm_modules/`.
Putting that home in `vendor/` changes only the name, not what kind of file it
is. Removing adapters entirely needs Codex-compatible upstream catalogs, which
nine of the ten upstreams lack today.

## B. One manifest instead of per-plugin `publish.toml`

### Readers today (verified)

| Reader | Location |
| --- | --- |
| Build: selections, mirror flag | `marketplace.py:131-149, 166-172` |
| Build: patches, overlays, plugin.json | `marketplace.py:194, 291, 303-309`, packages loop `:324` |
| Skill library inventory | `.agents/skills/agent-skill-management/scripts/agent_skill_lib.py:184-197` |
| Console: owning selection, cross-plugin use count, deletion plan, version bump | `skill_console/decisions.py:420-447, 946-950, 991-997` |
| Console UI path label | `templates/skill-console.html:1562` |
| dotpkgs dependency removal guard | `home/dot_local/lib/dotpkgs/actions.py:489` |
| Tests | `agent-marketplace/tests/test_marketplace.py` (~10 writers), `tests/python/agents/console_support.py:93`, `test_console_writes.py`, `test_console_validation.py` |

### Churn (verified, `git log` since 2026-09-07)

- `packages/*/publish.toml`: 5 commits.
- `packages/*/.codex-plugin/plugin.json`: 42 commits, almost all version
  bumps on authored plugins.

Selections rarely change. Versions change all the time.

### plugin.json can mostly be generated (verified)

- Nine of the seventeen manifests follow one template from `displayName`:
  - `description = "<X> skills from Prateek's dotfiles."`
  - `shortDescription = "<X> skills"`
  - `longDescription = "Generated local plugin for <X>."`
  - `defaultPrompt = ["Use the <X> plugin."]`
  - `category = Coding`
  - `capabilities = [Interactive, Write]`

  They are core, design, experimental, ios, mattpocock, obsidian-wiki, review,
  utils-agent, and utils-human. review also carries `hooks: {}`.
- The other eight deviate:
  - Seven adapters (apple-hig, better-writing, crit, ios-tools, obsidian,
    shortcut, ui-ux-pro-max) have short "compatibility skills" descriptions
    and no `interface`. crit also carries `hooks: {}`.
  - pstack adds `homepage`, `repository`, `keywords`, `agents`, and the `Read`
    capability.

A generator with per-plugin overrides can reproduce every one exactly.

### Sketch

```toml
# agent-marketplace/marketplace.toml  (replaces the planned marketplace.yml,
# 17 publish.toml files, and 17 plugin.json files)
[catalog]
name = "prateek-local"
version = "1.2.0"
owner = "Prateek"
category = "Productivity"

[plugins.mattpocock]
version = "1.2.3"
display_name = "Matt Pocock Skills"
payloads = [
  { dependency = "mattpocock/skills", path = ".apm/skills", target = "skills" },
  { dependency = "mattpocock/skills", path = "LICENSE", target = "licenses/mattpocock/skills/LICENSE" },
]

[plugins.pstack]
version = "0.15.7"
mirror_invocation_controls = true
payloads = [ ... ]
[plugins.pstack.manifest]          # verbatim overrides merged over the template
homepage = "..."
keywords = ["..."]

[plugins.core]
version = "1.4.4"
display_name = "Core Agent Skills"
skills = [ { name = "deep-research", dependency = "199-biotechnologies/claude-deep-research-skill", path = "." } ]
```

`src/<plugin>/` would then exist only where there are files to hold:

- authored `skills/` or `evals/`: core, design, experimental, ios, review,
  utils-agent, utils-human
- `patches/` or `overlays/`: seven adapters

apple-hig, obsidian, and shortcut would have no directory at all.

### Trade-offs

- **Version-bump locality.**
  - Every payload change bumps one line in the shared file, instead of
    editing that plugin's own `plugin.json`.
  - *Inferred:* each plugin is its own TOML table several lines apart, so
    concurrent bumps on different plugins usually merge cleanly. Bumps to
    neighbouring tables can conflict.
  - The console's bump (`decisions.py:946-950`) would change to edit TOML.
- **Console guarded writes.**
  - The console already fingerprints the whole marketplace source before
    planning and again before writing (`agent-skill-management` SKILL.md), so
    a single file doesn't widen what the guard checks.
  - It does mean two console sessions editing different plugins write the
    same file. The second write fails the recheck and has to re-plan, which is
    safe.
- **Patches still need per-plugin directories.** One manifest removes the
  `publish.toml` and `plugin.json` files but not `patches/` or `overlays/`.
- **The artifact must be unchanged.** The generated `plugin.json` must match
  today's bytes, so acceptance is the plan's artifact-identity check.
- **Cost:**
  - Rewrite the build's selection, mirror, and manifest code, plus a new
    generator.
  - Update the console's selection lookup, deletion guard, version bump, and
    UI label; `agent_skill_lib.iter_package_skills`; and the dotpkgs removal
    guard.
  - Update about 15 test fixtures that write `publish.toml`.
  - Update the README, the reference doc, and the skill references.
  - *Inferred:* about the same size as the layout move itself.

### Not checked

- Whether Codex and Claude accept a derived version (e.g. build metadata from
  the source digest). If they did, manual bumps would disappear, but that
  changes how clients detect updates and needs a native-client test.

## C. Recommendation

1. **Keep adapters out of `vendor/`.** Inside a module dir it fails the hash
   check (verified). Beside the modules it works but puts hand-written patches
   back under a "never edit" name.
2. **Adopt one root manifest, `marketplace.toml`, as a separate follow-up
   to the move.** It absorbs catalog identity, selections, the mirror flag,
   versions, and plugin metadata, and generates every `plugin.json`. After
   that, `src/` holds only directories with real files: authored skills and
   evals, plus patches and overlays. Most adapters shrink to one table and a
   patch. Three disappear from the tree.
3. **Order:** do the `packages/` → `src/` and `vendor/` move first, as
   planned. Then make the manifest change against the artifact-identity check.
   Doing both at once mixes a rename with a format change and weakens rename
   detection for locked docs.
4. **Retire adapters upstream when possible.** Each Codex-only adapter can go
   once its upstream ships a Codex-compatible native catalog. That decision
   belongs to ADR 0049, not to this layout work.

## D. Can Codex consume the upstream catalogs directly?

Yes, for the upstreams we use. The premise behind the Codex-only adapters
(the archived upstream-plugins plan said these upstreams have "no compatible
Codex marketplace catalog") does not hold for current Codex. Our own reconciler
is what enforces it.

### What Codex reads (verified, `openai/codex` at `rust-v0.163.0`, released 2026-10-15)

- **Claude marketplace files.** `codex-rs/core-plugins/src/marketplace.rs:20-25`
  lists the marketplace locations Codex accepts: `.agents/plugins/marketplace.json`,
  `.agents/plugins/api_marketplace.json`, `.claude-plugin/marketplace.json`, and
  `.cursor-plugin/marketplace.json`. `marketplace add` and discovery both use this
  list (`find_marketplace_manifest_path`, `marketplace.rs:328-338`).
  `marketplace_tests.rs:7` tests the Claude path.
- **Claude plugin manifests.** `exec-server-protocol/src/protocol.rs:51-55`
  (`DISCOVERABLE_PLUGIN_MANIFEST_PATHS`) lists `.codex-plugin/plugin.json`, then
  `.claude-plugin/plugin.json`, then `.cursor-plugin/plugin.json`.
- **Claude `skills` forms.** The manifest `skills` field can be a string or an
  array of strings, each starting with `./` (`manifest.rs:136-140,581-621`).
  The default `skills/` directory is also scanned (`loader.rs:71,1116-1122`).
- **Manifests inside catalog entries.** When an entry's plugin root has no
  manifest, Codex builds one from the entry's own fields, including `skills`
  arrays (`marketplace.rs:546-557,1089-1111`). That is Claude's `strict: false`
  pattern, which hefgi and raintree use.
- **Source types.** Codex accepts plain `./path`, `local`, `url`, `git-subdir`, and
  `npm` (`marketplace.rs:1037-1070`). Claude's `{"source": "github"}` object is not
  among them: Codex skips such entries with a warning (`marketplace.rs:597-603`).
  Plain relative paths must start with `./` (`marketplace.rs:707-716`).
- **Git catalogs.** `codex plugin marketplace add owner/repo --ref main` and
  `https://…` URLs both work (`cli/src/marketplace_cmd.rs:63`,
  `marketplace_add/source.rs:47-56`).
- **Since when.** Claude catalog support arrived between `rust-v0.120.0`
  (absent) and `rust-v0.130.0` (present). It is in every release since; I
  checked 0.140, 0.149, 0.155, 0.160, and 0.163. The `skills` array form was
  already present at 0.140.

### Upstream catalogs (verified via `gh api` trees on default branches, 2026-10-20)

Every upstream catalog uses `./` local sources, so Codex accepts them all.

| Adapter | Upstream catalog | Codex-relevant files upstream | Local patch |
| --- | --- | --- | --- |
| mattpocock | `mattpocock/skills`, source `./`, manifest `skills` array (27 paths) | Claude only | yes: edits to `diagnosing-bugs` and `retro` |
| obsidian | `kepano/obsidian-skills`, source `./`, default `skills/` | Claude only | none |
| obsidian-wiki | `ar9av/obsidian-wiki`, source `./`, `skills: "./.skills/"` | Claude only | yes: a live-layout section added to one skill |
| apple-hig | `raintree-technology/apple-hig-skills`, entry-level `skills` array, no plugin manifest | `plugin/.codex-plugin/plugin.json` (not in the catalog) | none |
| shortcut | `hefgi/skills`, three entries sharing `./` with entry-level `skills` | Claude only | none |
| better-writing | `forjd/better-writing`, source `./`, default `skills/` | Claude only | yes: makes the skill explicit-only (invocation controls) |
| crit | `tomasz-tomczyk/crit`, source `./integrations/claude-code` | separate `integrations/codex/plugin/crit/.codex-plugin/plugin.json` | yes: added guidance in `crit` and `crit-cli` |
| ui-ux-pro-max | `nextlevelbuilder/ui-ux-pro-max-skill`, `skills: "./.claude/skills/"` | Claude only | yes: icon data fixes |
| ios-tools | bundles `AvdLee/SwiftUI-Agent-Skill`, `efremidze/swift-patterns-skill`, and `conorluddy/ios-simulator-skill` | AvdLee: root `.codex-plugin`. conorluddy: a full `.agents/plugins/marketplace.json`. efremidze: Claude only. | yes: license files only |

For comparison, `mvanhorn/last30days-skill`, our one upstream installed natively
in Codex, ships both `.agents/plugins/marketplace.json` and
`.claude-plugin/marketplace.json`, plus `.codex-plugin` and `.claude-plugin`
manifests. Public repos show the same dual pattern: `Mastercard/developers-agent-toolkit`,
`echoVic/boss-skill`, and `string-os/string` ship `.codex-plugin/marketplace.json`
(found via `gh search code --filename marketplace.json codex`). Many others ship
only the Claude catalog, which current Codex reads anyway. So the dual pattern
is convention, not a Codex requirement.

### What blocks us is local (verified)

- **The reconciler hard-codes the Codex-native path.** `bootstrap_codex_snapshots`
  in `.agents/skills/agent-skill-management/scripts/reconcile-upstream-agent-plugins:115`
  checks only `.agents/plugins/marketplace.json` in the marketplace snapshot. If
  that file is missing, it re-adds the marketplace on every run. It would need to
  accept Codex's four locations.
- **Policy says `codex = false`.** `home/.chezmoidata/agent_upstream_plugins.toml`
  sets `codex = false` for these marketplaces.
- **ADR 0049's consequence assumed Claude manifests weren't enough.** It reads:
  "A client without a compatible upstream catalog receives a documented local
  adapter; the presence of a native manifest alone is insufficient." The upstream
  catalogs are compatible. Only the eligibility flag and the reconciler check
  need to change.

### Patches and enabled defaults

- **Patches don't reach native installs.** Six of the nine adapters carry local
  patches: better-writing, crit, mattpocock, obsidian-wiki, ui-ux-pro-max, and
  ios-tools (licenses only). Claude already runs these upstreams unpatched,
  because ADR 0049 says local patches are not applied to official installs.
  Moving Codex to native makes the two clients match, and drops our edits on
  both. Per patch, the choice is to upstream it, accept losing it, or keep an
  adapter for both clients. A Codex-only adapter is the one inconsistent option.
- **Enabled defaults work.** Git catalogs honor local enabled state. Only Codex's
  built-in remote catalog ignored it (ADR 0049). The reconciler already sets
  enabled state for Git-catalog plugins (`enabled_edit`, reconciler around line 96),
  so `default_loaded = false` marketplaces would keep working. *Inferred* from
  the existing last30days and superpowers flow. Not re-tested for Claude-format
  catalogs.

### Recommendation

1. **Flip `codex = true` and drop the Codex-only adapters where there's no patch.**
   That's obsidian, apple-hig, and shortcut, plus ios-tools if license-only
   patches can go: the upstream plugins ship their own licenses. Change the
   reconciler to accept any of Codex's four catalog locations. Verify in an
   isolated `CODEX_HOME`: add, install, skill discovery, and the enabled default.
2. **For the patched adapters, decide per patch.** Upstream the mattpocock,
   crit, obsidian-wiki, and ui-ux-pro-max edits, or drop them. better-writing's
   explicit-only control is a local policy choice. Upstream can't carry it, so
   if it matters, keep that one adapter and use it for **both** clients.
3. **Watch apple-hig.** It has no plugin manifest and three entries share one
   root (hefgi does the same), so it depends on Codex's entry-level fallback.
   Verify it in the probe.
4. **Effect on this plan.** If adapters go, `src/` shrinks to the authored plugins
   plus at most one or two patched adapters. That takes most of the weight off
   deliverable 7's adapter handling.

### Not verified

- **No live Codex probe.** An isolated `CODEX_HOME` probe with npm
  `@openai/codex@0.163.0` was killed with signal 9 (exit 137) during
  `marketplace add`, before any network or config write. That pattern looks like
  this laptop's endpoint protection, so I didn't retry. The scratch home is
  deleted. Run the probe on a personal machine.
- **Codex version on Prateek's machines.** Codex isn't on this machine's PATH.
  `~/.codex/version.json` last saw 0.149.1, which is past the 0.130 threshold.
- **Claude Code docs.** I didn't fetch them (the `anthropics/claude-code` repo
  doesn't hold them). The source-type comparison above comes from Codex's parser.
