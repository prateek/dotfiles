---
status: current
doc_type: reference
summary: "Isolated APM source/build project, host activation, recovery, and validation lanes."
owner: Prateek
created: 2026-09-07
updated: 2026-10-12
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
`home/.chezmoidata/agent_upstream_plugins.toml`. Native clients install those
plugins directly; the local project builds authored skills and compatibility
adapters. See [ADR 0049](../adr/0049-official-agent-plugin-marketplaces.md) and
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

UI/UX Pro Max, Crit, and Better Writing use maintainer marketplaces in Claude,
OMP, and Pi. `design` retains authored `devtool-ui`; `core` retains the writing
router and its other skills. Separate `ui-ux-pro-max` and `better-writing`
adapters serve Codex. UI/UX and Crit adapters import whole published collections.
Codex retains the UI/UX icon fixes and Better Writing's explicit-only controls;
native installs use upstream behavior. The writing router resolves Better
Writing through the client skill catalog instead of a sibling-directory link.
The follow-up plan is retired (`plans/additional-upstream-agent-plugins-plan.md` in the [ledger](../retired.md)).

The consumer boundary is:

| Surface | Owner |
| --- | --- |
| `agent-marketplace/apm.yml`, `apm.lock.yaml`, `apm_modules/` | One shared acquisition project and committed accepted inputs |
| `agent-marketplace/packages/` | Authored content, selections, reviewed patches, and native plugin metadata |
| `agent-marketplace/build/marketplace` | Validated disposable native artifact |
| `home/.chezmoidata/agent_plugins.toml` | Authored/fallback eligibility and default enablement |
| `home/.chezmoidata/agent_upstream_plugins.toml` | Official native sources and enabled defaults |
| `~/.agents/plugins` | Materialized shared marketplace |
| `~/.agents/plugins.previous` | Previous artifact retained for rollback |
| `~/.agents/skills` | Writable Codex runtime stub, preserving `.system/` |
| `~/.codex/skills` | Managed symlink to `../.agents/skills` |
| `~/.claude/CLAUDE.md` | Managed symlink to `../.agents/AGENTS.md` |
| Claude/Codex native caches | Native client CLIs and app-server APIs |

The enabled authored packages are `core`, `review`, and `utils-agent`.
Official last30days, Matt Pocock, Better Writing, and Crit are enabled. Codex
keeps enabled adapters for Matt Pocock, Better Writing, and Crit. Other official
plugins and adapters remain disabled. The seventeen local packages include Codex-only adapters, whose
Claude equivalents come from official marketplaces. Pstack remains a disabled
compatibility adapter because its upstream catalog targets Cursor. It imports
the whole upstream collection and mirrors human-only controls into Codex sidecars. The
[context-impact report](../research/pstack-context-impact.md) records the default
zero-row projection, the uncontrolled comparison, and the native-client checks.
Local Codex adapters suppress hook discovery with an explicit empty
`hooks` object. Paired human-only controls remain file contracts; these
checks do not prove model invocation behavior after a skill is explicitly loaded.

Only the root APM manifest is maintained. Each plugin's Codex manifest owns its
version and shared metadata; the build derives temporary APM manifests to generate
Claude metadata and both catalogs, then removes them. Materialized plugins contain
selected payloads and native manifests, with no acquisition cache or APM project.

Use [materialization](../../.agents/skills/agent-skill-management/references/generated-outputs.md)
for build-on-apply, repository tool selection, or prebuilt copy, and
[native reconciliation](../../.agents/skills/agent-skill-management/references/plugin-reconcile.md)
for cache updates, disabled project plugins, and rollback. Script 35 preserves
Codex's runtime skill stub; script 36 owns the build/copy/reconcile sequence.
Config merge templates read host policy directly. Pi follows Claude selection;
Cursor keeps its existing marketplace registration and ACP behavior.

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
