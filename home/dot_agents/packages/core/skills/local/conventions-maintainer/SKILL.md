---
name: conventions-maintainer
description: Maintain machine-wide agent conventions in ~/.agents/AGENTS.md and ~/.agents/docs. Use when adding, pruning, restructuring, or validating convention guidance; keep AGENTS as a small kernel and router, and keep topic docs focused on local policy rather than tool manuals.
---

# Conventions Maintainer

Use `writing-for-agents` as the design reference. The maintenance target is a
predictable information hierarchy, not a uniform document template.

## Boundaries

- `~/.agents/AGENTS.md` is the always-loaded kernel and router. Keep only
  preferences and guardrails needed across most tasks, plus short pointers.
- `~/.agents/docs/*.md` holds reference needed by a distinct task branch.
- A model-invoked skill owns an executable workflow that must be discovered
  autonomously. Convention docs may add machine-specific policy, but should not
  copy the skill's command reference.
- The environment, repository configuration, tool `--help`, and upstream docs
  are sources of truth. Cache their contents only when lookup is expensive and
  the local copy has a clear refresh owner.
- Repo-specific guidance belongs in that repository, not in these machine-wide
  files.

## Workflow

### 1. Locate the human-edited source

- Edit chezmoi source under `home/dot_agents/`, not rendered files under
  `~/.agents/`.
- Update an existing focused topic file instead of creating a synonym.
- Keep filenames stable and obvious.
- `slack.md` is generated at apply time from
  `home/.chezmoitemplates/agent-slack-base.md` plus a private overlay. Edit the
  base or overlay source, never the rendered file.

### 2. Place each instruction on the right tier

For every instruction, decide:

1. Does nearly every task need it before acting? Keep it in `AGENTS.md`.
2. Does one identifiable branch need it? Put it in a focused doc and add a
   pointer.
3. Is it an executable workflow with an independent trigger? Put the workflow
   in a skill and leave only local policy in the doc.
4. Can the agent obtain it cheaply from the environment or upstream source?
   Leave it there.

When a must-follow rule moves behind a pointer, make the pointer strong enough
to recover the lost reliability.

### 3. Write the pointer

- Front-load the task condition: `Git or GitHub work: ...`.
- Name each distinct trigger branch once. Avoid lists of synonyms.
- Point to the exact rendered path under `~/.agents/docs/`.
- Keep identity and explanation in the target doc.
- Place related pointers together so the router is scannable.

### 4. Write the topic doc

- Open with the condition under which the doc applies.
- Let the content determine the sections. Use `Defaults`, `Workflow`,
  `Safety`, and `Completion` only when they carry real material.
- Co-locate a concept's rule, rationale, caveats, and exact formats.
- End ordered work on a checkable, exhaustive completion criterion.
- Include commands only when the exact local shape matters. Otherwise point to
  version-matched `--help`, upstream docs, or the owning skill.
- Record the local delta: preferences, authorization boundaries, private
  topology, generated-file ownership, and gotchas the environment does not
  reveal.

### 5. Prune

- Delete no-ops that do not change model behavior.
- Keep each meaning in one authoritative place.
- Replace repeated prohibitions with a positive target; retain a prohibition
  only for a hard guardrail.
- Remove stale field manuals, generic motivation, discoverable command lists,
  and duplicated skill content.
- Split only when a real branch or sequence boundary earns another pointer.

### 6. Validate the boundary

- Reread every changed instruction file end-to-end.
- Confirm each pointer target exists in source or has an explicit generation
  path, as `slack.md` does.
- Search touched topics for duplicated or contradictory guidance.
- Confirm steps have observable completion criteria.
- Run `make test-agents-doc-pointers` after changing `AGENTS.md` or a convention
  doc.
- Run the relevant chezmoi preview and package validator after changing
  generated paths or a packaged skill.

The work is complete when every changed convention has one authoritative home,
every disclosed branch has a reliable pointer, and validation passes.

## Handoff

Report the files and boundaries changed, the validation run, and any unresolved
pointer, generation, or source-of-truth question.
