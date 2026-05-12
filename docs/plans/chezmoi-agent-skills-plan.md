---
status: archived
doc_type: plan
created: 2026-05-10
updated: 2026-05-10
closed: 2026-05-11
current_guidance:
  - ../../home/dot_agents/skills/
related:
  - ../research/agent-skill-management-research.md
status_detail: "Historical draft; do not use as current skill-manifest guidance."
---

# Chezmoi Agent Skills Plan

## Goal

Make dotfiles the source of truth for shared agent skills while keeping Codex's
startup skill list small enough to avoid description truncation.

The plan should support:

- repo-owned skill creation;
- third-party skill import with review;
- skill grouping and enablement;
- Codex and Claude Code projections;
- context-budget audits;
- validation after skill edits.

## Problem

Codex warns when the available skill descriptions exceed the startup context
budget:

```text
Skill descriptions were shortened to fit the 2% skills context budget. Codex can still see every skill, but some descriptions are shorter. Disable unused skills or plugins to leave more room for the rest.
```

This repo already centralizes shared agent guidance under `home/dot_agents/`.
What it does not yet have is an active-set layer. Every discoverable skill
competes for the initial skill list, including duplicate skills, niche skills,
and internal subskills.

## Ownership Model

Keep this split:

- `home/dot_agents/`: canonical shared agent content.
- `home/dot_agents/skills/`: canonical skill source tree.
- `home/dot_codex/`: Codex-specific config and adapters.
- `home/dot_claude/`: Claude-specific config and adapters.
- local chezmoi config: machine preference such as active group selection.

The canonical skill source should stay readable and reviewable in the repo.
Generated tool-specific projections can differ by host, but the skill content
should not be duplicated by default.

## Target Layout

Sketch:

```text
home/dot_agents/
  skills/
    code-gardening/
    write-for-humans/
    managing-agent-skills/
  skill-groups.toml

home/dot_codex/
  config-skill-groups.toml.tmpl

home/dot_claude/
  symlink_CLAUDE.md
  skills/
```

`skill-groups.toml` defines durable groups and membership. Machine-local
chezmoi data selects which groups are active. Codex config renders enablement
overrides. Claude projection can use symlinks or generated directories,
depending on what Claude Code accepts reliably.

## Group Manifest

Use explicit membership. Do not infer groups from directory names alone.

```toml
[groups.core]
description = "Always-on skills for normal coding and prose work."
enabled_by_default = true
skills = [
  "code-gardening",
  "write-for-humans",
  "writing-clearly-and-concisely",
  "using-git-spice",
]

[groups.ios]
description = "Apple platform work."
enabled_by_default = false
skills = [
  "ios-sim-lease",
  "ios-simulator-skill",
  "swift-patterns",
  "tca-ios",
]

[groups.research]
description = "Research, conversion, and source synthesis."
enabled_by_default = false
skills = [
  "deep-research",
  "llms-txt-from-website",
  "markdown-converter",
]
```

Committed group definitions should represent repo policy. Per-machine group
enablement should stay local unless the group is part of the baseline setup.

## Codex Projection

Codex can consume per-skill config entries:

```toml
[[skills.config]]
path = "/Users/prateek/.agents/skills/example"
enabled = false
```

Render this from the group manifest and local active group selection. The first
implementation can disable known inactive skills. If Codex later adds native
skill groups, keep the manifest and change only the renderer.

Avoid a projection that physically deletes or rewrites user-managed skill
directories. Chezmoi should produce desired state, not silently clean local
experiments.

## Candidate Skill

Create one repo-owned skill for this workflow:

```yaml
name: managing-agent-skills
description: Manage repo-owned and machine-local agent skills for Codex, Claude Code, and related agents. Use when installing, auditing, grouping, enabling, disabling, compacting, validating, or creating skills in Prateek's dotfiles/chezmoi setup.
```

Proposed tree:

```text
home/dot_agents/skills/managing-agent-skills/
  SKILL.md
  references/
    codex-skill-loading.md
    group-manifest.md
    third-party-imports.md
    compaction-playbook.md
    graph-tools.md
  scripts/
    inventory-skills
    validate-skills
    render-codex-skill-config
    audit-skill-context
```

`SKILL.md` should stay short. It should identify the canonical tree, choose the
workflow, point to the one needed reference, and require validation after edits.

The `graph-tools.md` reference should explain the distinction between
`/graphify` and Graph of Skills:

- `/graphify` maps a project or document corpus.
- Graph of Skills maps the skill library.

That distinction is important enough to keep out of the main `SKILL.md` but
close enough that agents can load it when choosing a context tool.

## Scripts

Baseline scripts should work from the filesystem and should not require one
marketplace or one third-party manager.

`inventory-skills`:

- walk `home/dot_agents/skills`, `~/.agents/skills`, `~/.codex/skills`, and
  `~/.claude/skills`;
- resolve realpaths;
- report duplicates, broken symlinks, missing `SKILL.md`, and source roots;
- emit JSON.

`validate-skills`:

- parse YAML frontmatter;
- require `name` and `description`;
- detect duplicate names;
- check one-level reference links from `SKILL.md`;
- check executable scripts;
- check `agents/openai.yaml` drift where present.

`audit-skill-context`:

- estimate startup cost from names and descriptions;
- rank long descriptions;
- flag vague or overlapping trigger phrases;
- identify likely compaction candidates.

`render-codex-skill-config`:

- read group definitions and local group selection;
- emit Codex `[[skills.config]]` entries for inactive skills;
- fail if the manifest references missing skills.

## Third-Party Import Path

Use a staging flow:

1. Preview with `gh skill preview` or `npx skills add --list`.
2. Download into a temporary or staging tree.
3. Run `skill-scanner` if available.
4. Run the local validator.
5. Run a janitor-style overlap check.
6. Review the diff.
7. Move into `home/dot_agents/skills/` only after acceptance.

Do not let third-party tools write directly into the canonical tree unless the
result is still reviewed as a repo diff.

## Existing Tools In This Plan

`skills-janitor`:

- Use as an advisory auditor.
- Run against a copied active projection first.
- Pay attention to name collisions, realpath dedupe, context token cost, and
  unused skills.
- Do not use destructive fix modes on chezmoi-managed paths.

`/graphify`:

- Treat as a project-context tool.
- Do not put it in the core skill-management path.
- Pilot per repo, with explicit policy for `graphify-out/`.
- Keep hooks opt-in and reversible.

Graph of Skills:

- Treat as a future large-library retrieval layer.
- Revisit only after grouping and compaction.
- If adopted, expose one small retriever skill or MCP instead of exposing every
  skill in the startup list.

## What To Collapse First

The visible skill set has obvious compaction candidates:

- HIG component skills can become one Apple HIG skill with references by domain.
- `PowerPoint` and `slides` should not both be active unless they differ.
- `Excel` and `spreadsheets` should not both be active unless they differ.
- Duplicate `orchestration` entries should collapse to one source.
- Duplicate Swift and SwiftUI skills should be split by real trigger or
  collapsed.
- Internal subskills, such as trycycle implementation phases, should be hidden
  from normal discovery when the parent skill can route to them.

Handle these in a separate change because they affect live skill behavior.

## Implementation Plan

Phase 1: inventory and measurement

- Add filesystem inventory.
- Add frontmatter validation.
- Add startup description cost report.
- Add focused tests against sample skill trees.

Phase 2: groups

- Add `skill-groups.toml`.
- Add local active-group config.
- Render Codex enablement config.
- Validate that manifest references match real skills.

Phase 3: import workflow

- Add staging directory policy.
- Wire `gh skill` and `npx skills` as optional discovery inputs.
- Add third-party scan and validation steps.

Phase 4: compaction

- Run audits against the live skill set.
- Propose collapses as separate reviewable changes.
- Move long detail into `references/`.

Phase 5: graph retrieval

- Reassess after active descriptions fit comfortably.
- If still needed, spike Graph of Skills on a copy of the skill tree.
- Do not make Graph of Skills part of bootstrap until it proves value locally.

## Validation

For docs and config:

```sh
git diff --check
```

For skill edits:

```sh
scripts/skills/validate-skills home/dot_agents/skills
```

For generated Codex config:

```sh
chezmoi apply --dry-run --verbose --exclude=scripts
```

The validator should exist before broad skill edits begin. Parser drift has
already been a recurring failure mode.

## Open Questions

- Should group definitions be committed while group enablement stays local?
  Recommended answer: yes.
- Should inactive skills live in the canonical tree or outside active scanner
  paths?
  Recommended answer: large inactive groups should live outside active scanner
  paths.
- Should `gh skill` replace `npx skills`?
  Recommended answer: no. Use `gh skill` for GitHub-hosted skills with pinning
  and provenance. Keep `npx skills` for skills.sh discovery and broader
  compatibility.
- Should `/graphify` be installed globally?
  Recommended answer: no. Keep it available as a project-context tool first.
- Should Graph of Skills be adopted now?
  Recommended answer: no. Use it only if profiles and compaction do not solve
  the active-list problem.
