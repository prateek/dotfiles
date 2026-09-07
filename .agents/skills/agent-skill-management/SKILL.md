---
name: agent-skill-management
description: Manage agent-marketplace packages, reviewed APM caches and patches, plugin materialization, and Claude, Codex, Cursor, or pi activation in this dotfiles repo. Use for skill imports or edits, package policy, the console's guarded edits, apply hooks, and related architecture docs.
---

# Agent Skill Management

Use `agent-marketplace/` for the portable source/build project. Host activation
policy lives in `home/.chezmoidata/agent_plugins.toml`. Native clients own their
install records and caches; `~/.agents/plugins` is the shared materialized
artifact.

1. Choose the working surface. Read the
   [project workflow](../../../agent-marketplace/README.md) for authored skills,
   APM acquisition, selections, patches, versions, and export. Read
   [materialization](references/generated-outputs.md) for chezmoi or artifact
   copy changes, and [reconciliation](references/plugin-reconcile.md) for native
   installation, enablement, or rollback.
2. Change durable inputs. Edit authored `skills/` directly and imported content
   through patches or overlays. Keep `apm_modules/` pristine. The console plans
   imported edits as patches, stages paired invocation controls and native
   version bumps, then builds the staged result before guarded writes. Imported
   description/frontmatter edits fingerprint the whole marketplace source before
   planning and recheck it before writing any file. If those inputs change,
   re-plan and revalidate; `--allow-dirty-targets` does not bypass that check.
3. Validate the changed boundary. Run `make -C agent-marketplace check` for
   package changes; run `make test-agent-skill-packages test-skill-console` for
   consumer or console changes. Activation changes also need the Claude, Codex,
   Cursor, and pi config merge checks. Native client changes need
   `make test-agent-skill-packages-native` on a host with both clients installed.
   The consumer suite applies scripts 35/36, config entries, and managed symlinks
   together in an isolated home, then repeats apply and verifies managed targets.
   Completion means the relevant checks pass and every payload change has a
   matching native version bump.
4. Materialize and reconcile within the user's requested apply scope. Read
   [the current reference](../../../docs/references/agent-marketplace.md) for
   paths and commands. Keep the previous artifact until native inventories and
   enabled states are verified. Source changes alone do not reload an existing
   agent session.

For input recovery, restore missing committed files from Git or a complete source
export. Acquisition refuses unaccepted cache/lock changes; it is not the repair
command for a deleted committed helper. Keep disposable probes in ignored scratch
and record useful evidence in research docs.

A human-only skill needs both `disable-model-invocation: true` and the Codex
sidecar's `policy.allow_implicit_invocation: false`. The build validates the pair.
Every published skill directory must retain its root `SKILL.md`, including after
patches and overlays. Python `__pycache__` entries are ignored without traversal
and never enter the artifact; other payload symlinks are rejected.
Keep all Codex interface metadata; hook-bearing packages retain `hooks: {}` under
the current skills-only Codex policy.

Runtime inventory comes from native catalogs and selected built payloads. Treat
`apm.lock.yaml` as the upstream identity/revision source. Preserve upstream license
and notice files in the published plugin as well as the cache. Subdirectory
imports need explicit root-notice payload selections when those texts are absent
from the selected tree; see the project workflow. Generate no `SOURCE.md` or
replacement per-skill provenance store.

For acquisition edge cases, read [third-party imports](references/third-party-imports.md).
For package shapes, read [package layout](references/package-layout.md).
The [test index](../../../tests/README.md#agent-package-checks) distinguishes the
ordinary checks from native host checks, console producer parity, and authenticated
evals. Those lanes establish different guarantees.
