---
status: accepted
doc_type: adr
owner: Prateek
created: 2026-09-08
updated: 2026-09-08
related:
  - 0016-vendor-into-skill-references.md
  - 0023-apm-agent-marketplace-packaging.md
  - ../plans/acpx-skill-packaging-plan.md
  - ../plans/acpx-claude-streaming-poc-plan.md
---

# ADR 0028: Own a subject with a sibling router skill, not a vendored remap

When local conventions and a vendored upstream skill cover the same subject,
publish both as sibling skills in one package and split the trigger between
their descriptions. Do not relocate vendored content inside a local skill.

## Context

acpx had two always-loaded context pointers for one subject, and neither
reached the other. The vendored upstream skill owned the trigger and knew
nothing about local conventions — model shortcuts, safety posture, how to watch
a run. The conventions lived in `~/.agents/docs/acpx.md` behind a line in the
machine `AGENTS.md`, which only fires for agents that read the pointer list.
Loading the skill got the command surface and none of the conventions.

[ADR 0016](0016-vendor-into-skill-references.md) proposed fixing this by
teaching the vendor pipeline a per-skill destination, so upstream content could
land under a local skill's `references/` and the second listing would
disappear. Its own scope note, added later, undercut it: a router skill whose
reference bodies are skills in their own right does not need that mapping. It
can point at a sibling path, because the sibling is already published.

That is exactly the acpx shape. The upstream body is a skill, not reference
material. The `dest =` mapping, its validator rules, its `SOURCE.md` migration,
and the license invariants it dragged along all existed to move content that
did not need moving.

## Decision

`utils-agent` publishes two sibling skills:

- `skills/acpx/` — authored here. Delegation: which shortcut fits which job,
  what the permission flags actually do, how to watch a run from inside the
  calling harness. It carries an `argument-hint` and the `-m/--model`,
  `-w/--write`, `-- <acpx flags>` interface, and it links to the sibling with a
  plain relative path, `../acpx-cli/SKILL.md`.
- `skills/acpx-cli/` — the vendored `openclaw/acpx` skill, renamed in
  `publish.toml`. The command surface: sessions, queues, permission policies,
  config, flows.

Both stay model-invocable. Arbitration is by description: the router's claims
delegation intent and the shortcut names, and upstream's already reads as the
command surface. The local patch changes one line, `name: acpx` to
`name: acpx-cli` — forced, because the builder rejects duplicate frontmatter
names within a package (`scripts/marketplace.py:219`). Upstream's description
is left verbatim.

Narrowing that description was drafted and cut. The overlap is one clause
("agent-to-agent communication"), the rewrite cost 108 characters against a
listing budget whose failure mode is silent, and nothing had measured whether
the two listings actually compete. Upstream's wording is the baseline the evals
measure; narrowing is the response to a failed near-miss case, not a
precaution. Measured 2026-09-08: the router took all 21 delegation runs and
the vendored skill all 12 command-surface runs, so no narrowing is warranted. The rename is safe to make alone: the vendored skill is a single
`SKILL.md` with no intra-skill paths, its one self-reference is the
name-independent "this skill", and every other `acpx` in the body is the CLI's
name rather than the skill's.

The `AGENTS.md` pointer line is deleted, which is where the always-loaded cost
was, and `home/dot_agents/docs/acpx.md` goes with it. The archived
crit-agent-bridge plan still links to that path; closed docs are not
maintained, and the docs validator no longer checks their inline links (it
did, which made anything a closed doc ever linked undeletable — fixed in this
change). `acpx-harness-lanes.md` moves to
`skills/acpx/references/harness-lanes.md`, where it is disclosed on demand
instead of pointed at from always-loaded text.

No build script changes. `publish.toml` and `patches/001-local.patch` already
express everything this needs.

## Alternatives considered

- **ADR 0016's `dest =` mapping (superseded).** Tens of lines across three
  scripts, new validator rules, a `SOURCE.md` migration, and an unresolved
  question about whether a nested `SKILL.md` under `references/` is inert for
  Codex — which it is not. All of it to avoid a relative link between two
  directories that sit next to each other.
- **`disable-model-invocation: true` on `acpx-cli`.** Guarantees one trigger
  surface, at the cost of never firing for a genuine command-surface question
  unless the router happens to be loaded first. Rejected: the command surface
  is worth triggering on its own, and the descriptions can carry the split.
- **Keep the conventions as a doc, repoint the pointer.** Leaves the trigger
  with the vendored skill, which is the actual defect.
- **Rename the local skill instead, patch nothing.** Genuinely zero patch
  surface. Rejected because the bare name is what a human types: `/acpx` should
  reach the delegation conventions, not the command reference.

## Consequences

- Net context-load reduction. One `AGENTS.md` line and a 140-line doc leave
  always-loaded state; the skill listing gains a description and the body loads
  only when the subject comes up.
- Two descriptions now compete where one did. Skill-trigger arbitration is
  undocumented in Claude Code, so this is measured, not assumed: the skill's
  `evals/run_trigger_evals.sh` drives skill-creator's trigger runner against
  the installed listing, and the first run found the split clean — 15/18, with
  every miss a label question rather than one listing taking the other's
  queries.
- The vendored `name` is a local patch, so an upstream frontmatter rewrite
  breaks `git apply` at build time — loudly, which is the point. `name:` and
  `description:` are adjacent, and `apply_patches` runs plain `git apply` with
  default context and no fuzz, so this one-line hunk is exactly as brittle as
  the wider rewrite would have been; the reason to keep it small is the listing
  budget and the drift from upstream, not fragility.
- The plugin version must move for installed Claude and Codex caches to pick
  the change up on their normal update path. Bumped to 1.3.0 with this change.
- The pattern generalizes to any package where a vendored skill and local
  conventions share a subject; `crit` and `orca-cli` are the plausible next
  customers, and both already have the sibling shape available.
- Writing the conventions as a skill forced them to be true. The old doc said
  the canonical launch runs "with non-interactive permissions that fail
  closed." Probing acpx 0.15.0 for the skill body showed cursor-agent and
  claude-agent-acp send no permission requests at all, so the flags gate
  nothing and the claim was false. The skill says so, and says that nothing in
  acpx contains these adapters either — a disposable worktree narrows the blast
  radius, it does not bound an adapter that writes by absolute path.

## Validation

- `just check` in `agent-marketplace/` — 37 tests, including the duplicate
  frontmatter name check the rename depends on.
- The built tree carries both `skills/acpx/` and `skills/acpx-cli/` with
  distinct names and descriptions, and the sibling link resolves inside it.
- `just test-docs-lifecycle` for the docs closure.
- The trigger evals, run against the installed listing rather than the source
  tree, because triggering depends on the rest of the listing and the budget.
  The runner has to be serial — concurrent workers share one
  `.claude/commands/` and score each other's temporary entries as misses — and
  the fixture retires the old conventions pointer until every machine has
  applied its deletion. Both are recorded in `evals/README.md`.
