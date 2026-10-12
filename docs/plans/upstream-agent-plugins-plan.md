---
status: archived
doc_type: plan
created: 2026-10-11
updated: 2026-10-12
related:
  - ../adr/0049-official-agent-plugin-marketplaces.md
  - ../references/agent-marketplace.md
closed: 2026-10-12
current_guidance: ../references/agent-marketplace.md
status_detail: "Implemented and verified on the host; restart existing sessions and reload Pi to discover the updated catalogs."
---

# Use upstream agent plugins

Use official marketplaces wherever the selected client supports the upstream
catalog. Keep authored skills and necessary compatibility adapters in the
reviewed local artifact. The user selected direct official installation over
repackaging complete upstream plugins.

## First functional slice

Install last30days from its official marketplace in isolated Claude, Codex, and
OMP profiles. Verify the native versions and enabled states before removing its
local wrapper. Extend that same workflow to the other compatible plugins.

## Executed sequence

1. Validate official catalogs and native CLI registration/install behavior.
2. Split mixed local packages so native plugins do not duplicate their skills.
3. Refresh fallback inputs and preserve the remaining patches and invocation
   controls. Use whole upstream collections for the large adapters.
4. Run packaging, consumer/config, and isolated native checks.
5. Install official replacements before local reconciliation removes wrappers.
6. Verify canonical Claude/OMP and both canonical and Orca Codex profiles.

Documentation polish cannot outrank a failed build, native install, or missing
replacement. Runtime model calls and authenticated research evaluations are
outside the install verification.

## Implementation boundaries

`home/.chezmoidata/agent_upstream_plugins.toml` declares official sources,
selected plugin identities, client eligibility, and enabled defaults. Native
clients acquire and cache those plugins. The upstream reconciler has an explicit
`--update` lane; ordinary apply installs missing plugins and restores defaults.

`agent-marketplace/` remains the source/build project for authored skills and
compatibility adapters. Its builds remain offline. Native upstream installations
require the hosting service and are not part of the local artifact receipt.

The remaining adapters use collection payload selections for Matt Pocock,
Pstack, Obsidian Wiki, Kepano's Obsidian skills, and Apple HIG. Pstack's adapter
mirrors human-only invocation controls into Codex sidecars without changing its
accepted cache. Imported edits remain patches or overlays.

The large `aiskillstore/marketplace` dependency is replaced with the original
`Cygnusfear/claude-stuff` writing skill. APM's branch resolver uses a shallow
whole-tree clone before content acquisition; selecting a subdirectory did not
avoid that resolution cost.

## Acceptance criteria

- Official plugins install through native marketplaces wherever a compatible
  catalog exists; a plugin manifest alone does not count as a marketplace.
- Mixed packages retain their authored skills and do not expose duplicate
  imported skills in the same client.
- Whole fallback collections gain new upstream skills and remove retired ones
  without maintaining individual skill lists.
- Disabled plugins remain disabled after updates and failed refreshes.
- Foreign marketplaces, plugins, and account-specific state survive.
- Invalid policy or a conflicting marketplace source fails before mutations in
  that client. OMP rejects two plugins with the same runtime name; remove the
  matching local install only after registering its replacement, and restore
  the old install and enabled state if replacement fails. Keep the old local
  artifact throughout this step. Other clients install replacements before
  retiring wrappers.
- Local cache hashes, patches, frontmatter, notices, and native version bumps
  pass the build checks. Config merge and consumer checks pass.
- Host native inventories match the declared plugin identities and defaults.
  Existing sessions must restart to discover the changed catalogs.

## Compatibility exceptions

Pstack publishes a Cursor plugin but no Claude/Codex marketplace entry for it;
the selected host clients use the local adapter. Matt Pocock, the Obsidian
plugins, Crit, Apple HIG, Shortcut, and the iOS plugins have Claude catalogs but
no compatible Codex marketplace catalog, so Codex retains adapters.

The UI/UX package retains local icon fixes. Better Writing and the Strunk skill
retain explicit invocation controls and serve the authored writing router.
Obsidian's live-layout patch and the Crit patches remain in Codex adapters;
official Claude plugins use upstream content. These are deliberate client
differences, not claims of complete payload parity.

Superpowers uses the maintainer's release marketplace for Claude/OMP and
its native Codex catalog in `obra/superpowers` for Codex. Both provide 7.0.0.
The catalog name `superpowers-dev` comes from upstream; the plugin is not
repackaged locally. A trial of Codex's built-in official catalog installed
6.4.2, but that remote catalog ignored the local disabled setting and the
installed CLI exposed no remote enablement method. The trial was removed so
the declared disabled default remains enforceable. The public Git mirror's
reserved name also prevents registering it as a user-owned Git marketplace.

## Recovery

Keep `~/.agents/plugins.previous` and the prior policy until native inventories
are verified. To restore the previous local release, restore its matching
source and both local/upstream policy files and use the existing
[artifact rollback procedure](../../.agents/skills/agent-skill-management/references/plugin-reconcile.md).
Disable or remove the corresponding official plugins through each native client
before enabling the restored wrappers. Regenerate Pi's prior desired-state file
and reload its extension. Restoring the local artifact alone does
not undo official marketplace registrations or installations.

## Verification and rollout

The host rollout completed on 2026-10-12. Native inventories confirmed 19
declared plugins each in Claude and OMP, and 17 each in canonical and Orca
Codex profiles, with the declared versions and enabled defaults. Foreign
user-plugin state was preserved in the profiles with before/after snapshots.
The temporary built-in Codex Superpowers installation was removed.

Packaging checks passed 57 tests and deterministic rebuilds. Consumer checks
passed 28 tests; the console suite passed 57, with an additional collection-edit
regression check. The final native-policy and configuration checks passed 25
tests. Live, previous, and pre-migration artifact receipts validated. Pi's
marketplace configuration was applied and verified; its extension was not
reloaded and no model calls or service-backed skill evaluations were run.

The scoped script-36 apply succeeded. A validated pre-migration artifact is
retained at `~/.agents/plugins.before-upstream-marketplaces-20261012`, in addition
to the materializer's rolling `plugins.previous` backup. Use the matching prior
source and policies with the rollback procedure; copying the artifact alone
does not restore native official installations or their enabled states.
