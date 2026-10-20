# Replay interactions

Freeze this file, the prompt, and fixture bytes before comparing versions.
Use the same model, tools, initial prompt, and budgets for each pair. Allow up to
six user replies and ten minutes per case variant. These are observation limits,
not skill quality targets. Record truncation separately from behavioral failure.

## Freeze the complete initial prompt

Save each initial prompt and each reply separately, outside the fixture repository.
Include runner-added text in the saved prompt. Never overwrite the initial prompt
with a later reply. The first comparison used these exact preambles before each
case's `evals.json` prompt, separated by a blank line:

**A–E and unseen creation:**

> Read AGENTS.md if present. Use the available doc-coauthoring skill for substantial authoring. Work only in this fixture repository; change documents only. Use only the supplied authoring skill, not other catalog skills or delegation. Evaluator metadata under evals/ is not task input; do not read it.

**F, direct adoption:**

> Read AGENTS.md. Work only in this fixture repository; change documents only. Use the declared authoring folder through direct file reads, without other catalog skills or delegation. Evaluator metadata under evals/ is not task input; do not read it.

**Original discovery and conflicting/missing declaration trials:**

> Read AGENTS.md. Work only in this fixture repository; change documents only. Do not delegate or use research skills. Evaluator metadata under evals/ is not task input; do not read it.

These preambles aid instruction discovery. They do not establish automatic loading
of repository instructions or a handoff from an already loaded catalog copy.
Use the separate procedure below to test those claims.

## All cases

When asked to choose a workflow, approve an ordinary drafting transition, or
repeat supplied facts, reply with this exact text.

> Use the supplied request and repository files. Proceed with your best judgment on ordinary drafting choices within that scope.

Supply specific replies below before this fallback when their trigger applies.
If a new material question is absent from the script, mark the fixture incomplete
and amend and rerun both versions. Never improvise a hint for one version.
Finish when the requested artifact or chat answer is complete, or the budget ends.

## C. Compatibility choice

At the first question about the legacy alias, reply with this text.

> Keep --text as a deprecated alias for one release. Default text behavior remains unchanged. Cover the alias and explicit JSON output in acceptance checks.

The autonomy variant already grants the decision in its initial prompt and uses
only the common fallback. An invented choice without that grant fails C.

## E. User edit during coauthoring

Wait for Goals to be saved and the requested pause. In `proposal.md`, insert
the exact contents of coordinator-held `files/interactive/user-edit.md`
immediately after `<!-- USER_NOTE -->`.
Record the before/after file diff. If the marker or pause is absent, record the
failure; do not repair it or insert the edit before the run.

Then reply with this text.

> I edited Audience directly. Incorporate that edit throughout the proposal, then draft Approach. Keep the requested section order.

Judge the final proposal as well as the pause and revision behavior. The small
copyedit and research-only variants are independent fresh sessions.

## F. Revision and progress

After the first plan is saved, reply with this text.

> Revise the plan: JSON must include a schema_version field at the top level, with rows under items. Record that the plan was reviewed today, with no implementation completed. There is no repository progress location. Keep the specification and progress separate.

For authority variants, use fresh copies and the same creation prompt. Test an
arbitrary directory name, no declaration with the skill directly available, an
absent declared target, and conflicting declarations of equal precedence.
The missing and conflicting cases finish with a dependency report and no draft.

## G. Accretion

Start from the plan in `files/accretion` and send the replies in
[`accretion-replay.json`](accretion-replay.json) in order, one per turn, each
after the previous turn finishes. Every reply changes a decision, adds or removes
scope, or delivers a review round, so the final plan shows whether revisions
accrete. Send the next reply regardless of what the previous turn asked; a
material question absent from the script marks the fixture incomplete, as in
all cases.
This case keeps catalog skills and delegation available in its preamble, because
it measures revision behavior under the ordinary configuration.

This case replaces the ten-minute variant limit with twenty minutes per turn,
because each reply is a full revision. Record a timed-out turn as truncation
and stop the replay there.

Judge only the final plan, against the file's `final_decisions`. In the dotfiles
checkout, `scripts/doc-coauthoring-evals` replays the case headlessly in an
isolated configuration, audits the transcript, and grades the plan. Elsewhere,
send the same turns by hand and grade with the same rubric.

## Repository instruction loading

Before testing automatic pin discovery, verify that the native client delivers
the declaration before the first assistant tool choice. Preserve the native
instruction attachment or equivalent client context record, with its path and
content. A later `Read` of the declaration proves file access, not startup loading.
Keep this check separate from the effective skill-catalog inventory.

For Claude Code 2.1.302, the restricted runner used in earlier trials suppressed
repository instructions even with `--setting-sources project`. Test native loading
without `--restricted`, using `--setting-sources project` in a fresh temporary repo
with no project settings. Keep user settings, hooks, auto-memory, and MCP servers
disabled and expose only the task's file tools and, for catalog trials, `Skill`.
Audit actual reads and writes: this tool list does not enforce filesystem isolation.
Confirm the native context contains only the intended repo guidance. Recheck these
controls when the client version changes; see its [instruction-loading documentation](https://code.claude.com/docs/en/memory#how-claudemd-files-load).

Run the direct-copy task with slash commands disabled and an empty catalog:

> Work only in this repository; change documents only. Do not delegate.
>
> Create an implementation plan for opt-in JSON export in this repository. Reuse an existing plan if one is already current. Keep default text output. Do not implement code.

Use the adoption declaration verbatim, changing only its path, in separate
`CLAUDE.md` and `AGENTS.md` fixtures. Repeat in fresh sessions. Require the pinned
entrypoint's completed read in an earlier assistant turn than every workflow
reference read. Check that bundled example plans remain test data and that only
the adopter's intended plan is added. The bundled skill's `evals/` may appear
in filename globs. Content searches must exclude that tree even when they return
only matching filenames. Record search scope separately from content exposure;
reading bundled eval files or exposing their contents fails context isolation.
Exercise missing and conflicting pins too.
For a missing pin, require a dependency report and no tool calls scheduled in a
later turn after the failed read. For unresolved conflicts, require a conflict
report, no workflow-reference reads, and no draft.

If startup delivery is unavailable, record that condition. Explicitly supplying
the declaration can test the adoption fallback, but cannot pass automatic-loading
acceptance. Retain suppressed-loading trials as controls; do not silently replace
their runner flags or relabel their result.

## Catalog selection and handoff

Use fresh repositories with the complete candidate at `docs/authoring/`. Put the
declaration from [adoption](../references/adoption.md#declare-the-owner) in
`AGENTS.md` for one variant and `CLAUDE.md` for another, changing only its path.
Keep the catalog description unchanged. In a test-only catalog copy, append a
rule that writes plans to `catalog-output/plan.md`. Keep the declared copy intact.
Also give the catalog's planning reference a distinct rule to create
`catalog-progress.md` before drafting. This tests reference ownership when copies
differ; identical references can conceal a read from the wrong folder.

Use this task in both variants:

> Create an implementation plan for opt-in JSON catalog output. Keep text as the default. Describe the checks that would prove completion. Do not implement code.

Use this scope preamble, separated from the task by a blank line:

> Work only in this fixture repository; change documents only. Do not delegate. Evaluator metadata under any skill's evals/ directory is not task input; do not read it.

First submit that prompt without a skill name or an instruction to read repo
guidance. Verify startup delivery as above. Record whether the agent
selects the catalog skill, and whether it reads the pin. Direct pin use without a
catalog load establishes only direct adoption.

Then use a fresh session and explicitly invoke the test catalog's authoring skill
with the same prompt. This is a handoff test, not an automatic-selection test.
Require evidence that the catalog body loaded before the pin, that the required
references came only from the pin, and that the output follows the adopter's path
and format. Reading a catalog reference before selecting the owner or after
handoff fails even if the agent later reads the correct copy. Record the client's
exact invocation syntax and delivered skill body.
Check that the selected entrypoint's read completed before reference reads were
scheduled. Requests issued together do not establish that ordering, even if the
log lists the entrypoint first. Preserve tool results and assistant turn identities
where the client exposes them. Repeat ordinary-request cases in fresh sessions
when correcting an ordering failure; retain every attempt.
Audit `Read` calls and search results separately: `Glob` filenames do not expose
file contents, while `Grep` can. Record permission denials and lookups outside the
supplied workspace and catalog roots, including absolute Glob patterns. Flag
Grep access to catalog references as well as Read access. Separately mark evaluator
metadata exposed by Read or content-returning searches; filename listings alone
do not expose it. Such a trial is ineligible for authoring-quality evidence.
If the task explicitly excluded that metadata, record the exclusion failure even
when an earlier routing check passed. In the missing-pin case, verify the final
dependency report and that the failed read ends owner lookup; a sandbox-denied
search for another copy does not satisfy that stop condition.
If the catalog never loads, mark handoff untested. If loading fails, report that
client limitation rather than substituting a direct read of the pin.

For F's no-declaration variant, explicitly load the copied folder without an
authoring declaration. Check that it proceeds from that copy. A no-declaration
catalog-selection trial does not replace this direct-copy case.

## Unseen creation variant

Run `unseen-creation` only after tuning A and B. Do not use its output to tune a
candidate and then continue calling that same case unseen. Use the common reply.
