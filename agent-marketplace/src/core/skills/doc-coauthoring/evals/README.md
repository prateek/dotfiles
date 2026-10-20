# Evaluate document authoring

These tasks exercise document outputs and interactions, not preferred prose.
`evals.json` follows the repository's static prompt/files/expectations convention.
[replay.md](replay.md) supplies a manual multi-turn protocol. Use a human or
coordinating agent as the scripted user in an existing client; no runner is
assumed to interpret the replay file automatically. The accretion case also has
a machine-readable script, [accretion-replay.json](accretion-replay.json), which
the dotfiles checkout replays with `scripts/doc-coauthoring-evals`.

## Prepare a comparison

1. Preserve the complete original skill before editing its instructions. Record
   its revision or artifact digest. Make separate temporary repositories for
   baseline and candidate. Copy each fixture directory's contents into the root
   in listed order; later files replace earlier ones. Copy individual input files
   to the root by basename. Keep the coordinator's prompt files, transcripts,
   session files, settings, and working copy of E's `user-edit.md` in a directory
   outside the fixture workspace. Inject E's edit only at its scripted pause.
   Preserve every initial prompt and reply.
2. Use the same model, effort, tools, prompt, and budgets for each pair. Expose
   only that version of the skill. Save client version and effective skill roots.
   Start a fresh session for every case variant and follow the replay at user
   input boundaries. Keep transcripts and file diffs in ignored scratch.
3. In F, copy the complete skill to `docs/authoring/`. Verify the receipt using
   [adoption](../references/adoption.md) for the candidate. Test changed bytes,
   a removed file, an extra hidden file, and a symlink in separate copies. Each
   must fail verification. Also retry creation at an existing target and confirm
   it fails without overwriting the existing receipt. Give the agent no publisher
   checkout or sibling skills.

The complete skill also contains `evals/`. Its expected observations, replay, and
edit payload remain physically readable in that copy. Do not attach them as task context or
pretend the files are absent. Use the recorded exclusion instruction in the
replay protocol and audit every read/search result for exposure. A filename in a
listing differs from reading its contents. If answers or replay text reach the
agent, mark that trial contaminated; it cannot establish authoring quality.

## Judge results

Give anonymized A–E outputs to a fresh reader without the drafting chat.
For implementation plans, ask for the outcome, chosen mechanism, rationale, constraints, first action,
dependencies, and evidence that would establish completion. Ask which unresolved
decision would stop implementation. A guessed answer is not a settled decision.
For interactive drafts, check preservation of direct edits and their consequences.
For copyedits and research answers, check exact scope and factual support. Grade
each case's observable expectations using the fixture's independent facts.
For the accretion case, grade the final plan both ways: what is missing, and what
is stale, repeated, narrating history, or an acceptance check the reader cannot
run. Count history phrases and stale terms deterministically; use the judge for
contradictions and repeats.
The eval owner separately checks transcripts for authority, questions, pauses,
and direct-edit handling. Record unnecessary questions apart from content quality.

Run one pair per variant initially. Repeat when failure, ambiguity, or variance
could change the decision. If the script lacks a material answer, correct it and
rerun both versions. Keep incomplete, tool-failed, and budget-limited results
visible. They cannot establish a general quality advantage. Run the unseen
creation case after tuning. Report existing baseline strengths and ties.

## Check discovery separately

Use an actual fresh client with an isolated configuration and effective catalog.
Inspect the catalog before running. A consumer-package test alone does not prove
model discovery. Keep the daily profile and its caches unchanged.
Verify repository-instruction loading independently of catalog isolation, using
the replay's startup-context check. An isolated catalog can coexist with disabled
repo instructions; a successful file read does not prove startup delivery.

- Run F through the explicit repo pointer with only the copied authoring folder.
- With no declaration, expose authoring, gardening, and lifecycle in the isolated
  catalog. Request creation and substantive revision without naming a skill.
  Authoring must own content; lifecycle still handles applicable local policy.
- Declare the unchanged candidate as the repo pin. Follow the replay's separate
  catalog-selection and explicit-handoff trials. Preserve the description; add
  the replay's conflicting output path and planning-reference rule to the test
  catalog copy. Verify the catalog actually loads and only the pin's references
  are read before claiming a successful handoff. Repeat with the pin missing;
  authoring must remain pending.

Save selected paths, catalog listing, transcript, and artifacts. Name the client
and version proved. If isolation or discovery is unavailable, leave that gate
open. A direct-pointer result cannot substitute for catalog discovery.

## Evidence limits

Keep model receipts and raw outputs in ignored scratch. Retain a compact reviewed
result summary beside the evals when accepting the change. Syntax, deterministic
packaging, authoring behavior, live discovery, and daily activation are separate
claims. These samples support bounded acceptance, not a reliability percentage
or a cross-client guarantee.

The [2026-10-18 results](results.md) record the initial comparison, reader findings,
authority checks, and the remaining catalog-isolation gate.
