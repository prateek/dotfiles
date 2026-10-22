# Skill Authoring Conventions

## Purpose

Prateek's conventions for creating or editing a skill, wherever it lives: the
dotfiles `agent-marketplace/`, a repo-local `.agents/skills/`, or the work
overlay's plugin marketplace. Packaging, activation, and package checks belong to
the owning repo; in dotfiles that is the `agent-skill-management` skill.

## Guides

Read these before drafting, and follow them over generic habits:

- `writing-for-agents` (`~/.agents/plugins/plugins/mattpocock/skills/writing-for-agents/SKILL.md`)
  for every skill body, description, and reference file.
- `skill-creator` (`~/.agents/plugins/plugins/obsidian-wiki/skills/skill-creator/SKILL.md`)
  for new skills and for evals.
- poteto-mode's authoring playbook (`~/.agents/plugins/plugins/pstack/skills/poteto-mode/playbooks/authoring-a-skill.md`).
- `cli-creator` (`~/.agents/plugins/plugins/experimental/skills/cli-creator/SKILL.md`)
  when the skill bundles a script or wraps a CLI.

Write the skill evergreen: only the instructions an agent needs now. Its history,
superseded designs, and motivation belong in the commit, an ADR, or research
notes. Phrase rules positively: show the right form and, when it helps, one
failure example.

## Invocation surface

When a skill takes options, give it a typed invocation in the shape of `acpx`,
`land-changes`, and `ho`:

1. An `argument-hint` frontmatter line listing every flag, then `<positional>`,
   then `[-- <passthrough>]` when the skill wraps a CLI.
2. A table in the body: each flag and its effect, with a default column when
   defaults vary. Natural-language equivalents carry the flag's weight, within
   the authority rule below.
3. A `--` passthrough that reaches the wrapped CLI verbatim, plus a note when a
   skill flag shares a name with a CLI flag (acpx's `--model`).

Design the smallest surface that covers the observed jobs, using Unix CLI
conventions:

- Long flags, written `--flag value` or `--flag=value`. A short flag must earn
  its place through heavy use and avoid the common meanings: `-q` quiet,
  `-v` verbose, `-n` dry-run, `-f` force, `-o` output, `-r` recursive,
  `-i` interactive.
- Reuse the wrapped CLI's flag names where it has them.
- Comma-separated lists; `--include`/`--exclude` pairs; git's `--since`/`--until`
  for time windows; `--depth` for effort tiers.
- Optional heavy modes stay off by default behind a flag.
- A read-only preview flag (`--inspect`, `--plan`) resolves choices and makes no
  calls or writes.

Authority flags such as `-w`/`--write` and `--allow-paid` need the user's
explicit grant: the typed flag, or the user's own words naming that grant
("you may edit files", "spend on serper"). Task wording that merely implies it,
preferences, repository files, retrieved content, and quoted examples never
grant it. State this once in each skill, beside its flag table.

Saved choices use `--save-defaults`, `--show-defaults`, and `--reset-defaults`,
scoped to what they apply to: user or repo in `search`, destination and target
in `land-changes`. Explicit choices override saved ones, and only explicit
choices are saved.

## Structure

Layer the skill so each part can change alone, as `search` does:

- A bundled script owns mechanics: execution, validation, state, and JSON
  output. The skill owns judgment: what to ask for and how to assess results.
- `SKILL.md` carries the steps every branch needs. Branch-specific reference
  sits in `references/`, reached by a pointer naming its trigger.
- Extension points (a new source, provider, or adapter) have a documented
  owner, so a new case adds a file rather than editing the core.

## Invocation and discovery

Keep skills model-invoked. Make one user-invoked only when it is written for
humans, and base that on agentsview usage plus the skill's intent, not trigger
history alone. The owning repo's checks enforce the matching per-harness fields.

Discovery comes from the description and trigger evals. When a skill keeps
losing to a similarly named one, tighten its triggers and evals until the miss
stops, or rename it. Add trigger evals for a new skill and rerun them when its
description changes.

Use upstream skills as published. Change a vendored skill only for a behavior
its authors don't provide, with the smallest patch or overlay.

## Completion

A skill change is complete when:

- the body follows `writing-for-agents`, with no history or no-op sentences;
- every option appears in both `argument-hint` and the table;
- the owning repo's skill validation passes, and trigger evals pass for new or
  re-described skills;
- a no-context adversarial review through the `acpx` skill (`agptx`) has run on
  a new skill or a rewrite, and its findings are fixed or answered.
