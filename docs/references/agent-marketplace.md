---
status: current
doc_type: reference
summary: "Isolated APM source/build project, host activation, recovery, and validation lanes."
owner: Prateek
created: 2026-09-07
updated: 2026-10-24
related:
  - ../../agent-marketplace/README.md
  - ../../.agents/skills/agent-skill-management/SKILL.md
  - ../adr/0023-apm-agent-marketplace-packaging.md
  - ../adr/0025-shared-apm-acquisition.md
  - ../adr/0039-work-overlay-in-work-repo.md
  - ../retired.md

---

# Agent Marketplace

[The isolated project](../../agent-marketplace/README.md) owns authored skills,
reviewed APM inputs, patches, native plugin metadata, build checks, and export.
It can build outside dotfiles after tool provisioning. The
retired [verification record](../retired.md) (`research/apm-marketplace-migration-verification.md`)
records the earlier local-artifact migration. It does not establish completion
of the official-plugin rollout. A changed checkout does not by itself change the
live marketplace.

Official sources, plugin identities, and enabled defaults are declared in
`home/.chezmoidata/agent_upstream_plugins.toml`. Every harness installs every
plugin, local or official ([ADR 0059](../adr/0059-one-plugin-set-for-every-harness.md)).
Native clients install official plugins directly, Codex included, from their
upstream Claude-format catalogs. The local project builds authored skills plus
the adapters we keep for their patches. See
[ADR 0049](../adr/0049-official-agent-plugin-marketplaces.md) and
the retired migration plan (`plans/upstream-agent-plugins-plan.md` in the [ledger](../retired.md)).

Refresh official installs from the repository root:

```sh
.agents/skills/agent-skill-management/scripts/reconcile-upstream-agent-plugins \
  --apply --update --agent claude --agent codex --agent omp
env -u CODEX_HOME .agents/skills/agent-skill-management/scripts/reconcile-upstream-agent-plugins \
  --apply --update --agent codex
```

Scoped script 36 apply installs missing official plugins before materializing
the local artifact and removing obsolete wrappers. OMP requires removing a
matching local install first because runtime names must be unique; the
reconciler restores that install and its enabled state if replacement fails.
Existing official installs refresh only when maintenance passes `--update`. Pi reads the same official
Claude catalogs from its desired-state file on extension reload. Native upstream
caches are outside the local release receipt.

Five adapters carry patches we keep, and serve every harness in place of the
official install: Better Writing (explicit-only controls), pstack (human-only
setup), and, pending a decision on their patches, Matt Pocock, Crit, and
Obsidian Wiki. Their official installs are listed in
`retired_agent_upstream_plugins`, which the reconciler uninstalls and the config
templates pin disabled. The writing router resolves Better Writing through the
client skill catalog instead of a sibling-directory link.
The follow-up plan is retired (`plans/additional-upstream-agent-plugins-plan.md` in the [ledger](../retired.md)).

The consumer boundary is:

| Surface | Owner |
| --- | --- |
| `agent-marketplace/marketplace.toml` | The catalog's identity and plugin order, plus each plugin's version, manifest, and selections |
| `agent-marketplace/vendor/apm.yml`, `apm.lock.yaml`, `apm_modules/` | One shared acquisition project and committed accepted inputs |
| `agent-marketplace/src/` | Authored content and reviewed patches and overlays, per plugin |
| `agent-marketplace/build/marketplace` | Validated disposable native artifact |
| `home/.chezmoidata/agent_plugins.toml` | Default enablement for every local plugin |
| `home/.chezmoidata/agent_upstream_plugins.toml` | Official native sources, enabled defaults, and retired official installs |
| `~/.agents/plugins` | Materialized shared marketplace |
| `~/.agents/plugins.previous` | Previous artifact retained for rollback |
| `~/.agents/skills` | Writable Codex runtime stub, preserving `.system/` |
| `~/.codex/skills` | Managed symlink to `../.agents/skills` |
| `~/AGENTS.md` | Managed symlink to `.agents/AGENTS.md`, read by Claude Code as a parent directory |
| Claude/Codex native caches | Native client CLIs and app-server APIs |

The enabled local packages are `core`, `review`, `utils-agent`, and the Matt
Pocock, Better Writing, and Crit adapters. Official last30days is enabled; other
official plugins and local packages remain disabled. Pstack is a disabled
adapter that imports the whole upstream collection and mirrors human-only
controls into Codex sidecars. The
[context-impact report](../research/pstack-context-impact.md) records the default
zero-row projection, the uncontrolled comparison, and the native-client checks.
Local Codex manifests suppress hook discovery with an explicit empty
`hooks` object, so Crit's hooks run on Claude only. Paired human-only controls remain file contracts; these
checks do not prove model invocation behavior after a skill is explicitly loaded.

`marketplace.toml` owns the catalog, its plugin order, and each plugin's
version, manifest, and selections; `vendor/apm.yml` holds only dependencies.
The build generates every `plugin.json`, derives temporary APM manifests to
generate Claude metadata and both catalogs, then removes them. Materialized plugins contain
selected payloads and native manifests, with no acquisition cache or APM project.

Use [materialization](../../.agents/skills/agent-skill-management/references/generated-outputs.md)
for build-on-apply, repository tool selection, or prebuilt copy, and
[native reconciliation](../../.agents/skills/agent-skill-management/references/plugin-reconcile.md)
for cache updates, disabled project plugins, and rollback. Script 35 preserves
Codex's runtime skill stub; script 36 owns the build/copy/reconcile sequence.
Config merge templates read host policy directly. Pi follows Claude selection.
Cursor gets default-loaded skills as links in `~/.cursor/skills`, because its
CLI loads plugins only from Cursor's server-side marketplaces.

Work machines with the work overlay configured get a second marketplace,
`work-overlay`, from the overlay clone's `agent-plugins/` directory
([ADR 0039](../adr/0039-work-overlay-in-work-repo.md)). It is hand-maintained in
the work repo, not built here. Script 39 installs it with the reconciler's
`--overlay` mode. The four client config templates register it once the clone
holds a catalog, and take the marketplace and plugin names from the reconciler's
`--json` listing. A plugin reaches the clients whose catalog lists it. Bump its
version in every manifest it ships to refresh installs; the reconciler refuses a
mismatch.

The [management skill](../../.agents/skills/agent-skill-management/SKILL.md) routes
maintenance work. The [test index](../../tests/README.md#agent-package-checks)
separates portable packaging checks, consumer checks, native client checks,
console producer parity, and authenticated evals.

## On-demand skill library

`utils-agent:skill-library` discovers skills in every plugin whose policy has
`default_loaded = false`. There is no separate discovery allowlist. Script 36
runs `generate-skill-library` after reconciliation and writes
`${XDG_STATE_HOME:-~/.local/state}/agent-skills/catalog.json`. Regenerate it without
changing activation from the dotfiles checkout:

```sh
.agents/skills/agent-skill-management/scripts/generate-skill-library
```

Local entries come from the receipt-validated materialized artifact. Upstream
entries resolve declared identities through Claude's user installation registry
under `${CLAUDE_CONFIG_DIR:-~/.claude}`, including custom skill paths in native
manifests. They can be read by either client, but this does not establish native
availability in Codex. Missing or ambiguous installations appear in coverage
diagnostics. Codex-only upstream installations are not resolved by this adapter.
Retired plugins and unselected vendor content are not searched.

The catalog includes human-only entries, marked `explicit`, and skills requiring
native invocation, marked `native`. Discovery preserves those constraints and
any narrower prose conditions; it does not enable plugins or authorize actions.
The reader checks input fingerprints and the selected instruction file before
loading. Changes to policy, the artifact receipt, registry or manifest require
regeneration. Relative references retain the selected skill's directory.

Only the discovery skill's description enters the default catalog. The generated
index and chosen instructions load on demand. Automatic triggering, native plugin
invocation and retention across compaction require separate client validation;
CLI catalog checks do not establish those behaviors.
