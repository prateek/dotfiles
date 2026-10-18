# Authoring evaluation: 2026-10-18

The candidate supports autonomous creation, substantive revision, and the existing
interactive workflow. Direct repository pins and the complete-copy checks worked
in the tested cases. Catalog selection remains variable; the strict isolated-catalog
acceptance gate is open. These are bounded samples, not a reliability estimate.

## Setup

- Baseline: the complete `doc-coauthoring` folder from dotfiles commit
  `1c955fa4c183573c6b92229a7a14dc11a829d3b2`, saved before editing instructions.
  All A–E baseline trials finished before the rewrite.
- Candidate: the authored folder for core `1.4.0`. The first candidate was
  preserved before the trigger-description and integration-boundary refinement.
  A, B, and both C variants were rerun after that refinement. The unseen TSV case
  also used the refined candidate. Other paired cases used the first candidate,
  whose relevant authority, interaction, and progress rules are unchanged.
- Runtime: native Claude Code `2.1.302`, actual model `claude-fable-5-1`, medium
  effort, fresh sessions, identical task prompts and fixtures for each pair.
  Tools were Read, Write, Edit, Glob, Grep, and Skill. Delegation was unavailable
  to the evaluated author; its reader pass was therefore labeled self-review.
- [Replay](replay.md) bounded each case to six user replies and ten minutes.
  C received the exact compatibility reply. E paused with Approach untouched;
  the coordinator inserted the literal user edit and delivered the scripted reply.
  F received the same schema/progress revision in both versions.
- Every original task included a runner preamble, now quoted in the replay.
  It explicitly directed the agent to read `AGENTS.md`; A–E also named the skill,
  and F directed it to read the declared folder. These are aided trials. Some
  multi-turn runs overwrote `prompt.txt` with replies; their initial prompts were
  recovered from the native session records. Future runs save each turn separately.
  The original workspaces also held prompt and transcript files; the conflicting-
  declarations run read its own `prompt.txt`. New runs keep controller files outside.
- The runner excluded user/project settings, hooks, MCP servers, and installed
  optional plugins. Effective catalogs and loaded paths were captured. Native
  built-ins remained available; no trial invoked one. Agent telemetry and error
  reporting were disabled for these processes. Daily plugin configuration and
  caches were not changed.
- Raw transcripts, frozen inputs, before/after files, catalogs, and tool audits
  stay under ignored `build/authoring-evals/`. No evaluated run read expected observations
  or replay contents. Fixture source and test files remained unchanged.

## Paired observations

| Case | Baseline and candidate observations |
| --- | --- |
| A: create | Both preserve opt-in JSON, default text, the row contract, and no new dependencies. The candidate's refined run supplies an explicit connected parser-to-renderer test and identifies absent production wiring. The blind reader found a deferred newline error in the baseline and factual/completion-gate inconsistencies in the candidate; these need reader repair, not a claim of flawless output. |
| B: revise | Both preserve Rowan and the exact keyboard-accessible checklist note and reverse the obsolete default/removal policy. The baseline describes a nonexistent executable CLI slice. The refined candidate uses a connected callable slice, names actual prerequisites, and separates parser and renderer error contracts. The blind reader found no essential defect in that candidate. |
| C: ask | Both inspect the unittest command, ask the material policy question, and integrate the scripted one-release answer. Reader review found invalid CLI evidence in the initial outputs. The refined candidate identifies missing wiring but adds unresolved CLI scope and insufficient warning evidence; a separate reader-repair turn resolves those defects. |
| C: choose | Both use the explicit decision grant, choose a policy, and preserve default text. The candidate needs reader correction for unsupported history claims and an added CLI prerequisite. The repaired plan has an explicit callable scope and qualified assumptions. No first-draft advantage is claimed. |
| D: reuse | Both update the existing plan, preserve the owner and retirement record, and resolve the empty-array question. No duplicate is created. The candidate tests the connected boundary; the baseline promises an inert CLI check and an unsupported key-order guarantee. |
| E: interact | Both save Goals and pause before Approach, preserve the literal edit, and reconcile offline/no-account constraints. The baseline presents unverified report capabilities as existing; the candidate exposes schema and UI choices as open proposal questions. Interaction predicates tie; content grounding differs. |
| E: copyedit | Both change only `recieve` to `receive`; the rest of the file is byte-identical. Neither invokes authoring. |
| E: research | Both report current text support and the existing checks without writing files or invoking authoring. |
| F: adopter | Both read the arbitrary `docs/authoring/SKILL.md` pin and revise the JSON schema using only that folder. The baseline creates `notes/IMPLEMENTATION_LOG.md`; the candidate records the dated review under one Progress section in the plan and states that implementation has not occurred. |
| Unseen TSV creation | Both select an escaping policy and preserve text defaults. The candidate explicitly tests header/column order, empty rows, tabs/newlines/backslashes, and the connected parser-to-renderer boundary. This case was not used to tune the instructions. |

A blind reader received anonymous A/B documents, the original requests, and the
fixture source, without skill labels or drafting history. An evaluator paraphrase
initially misstated the accessibility note; the reader retracted that finding after
receiving the verbatim original. Neither version was penalized for the evaluator's
error. Later blind passes evaluated the refined A/B artifacts and every C–E variant.
The coordinator separately checked transcript questions, pauses, and file writes.

Reader-repair turns are separate from the frozen comparison: both A authors and
the refined candidate C authors received their concrete reader findings. The final
reader confirmed that the candidate A and C blockers were resolved; B already had
no essential defect. Minor precision suggestions remain recorded in the raw review.
These turns exercise the feedback loop and do not retroactively convert first-draft
defects into first-pass successes. E's edit payload was present as a separate file
in both initial fixtures but neither author read it before the pause; subsequent
runs should keep that file coordinator-side until insertion.

## Adoption and discovery

The documented Bash procedures were executed against the complete folder. An
intact copy passed. Separate copies with changed bytes, a missing file, an extra
hidden file, a file symlink, or a symlinked root failed. Attempting to create a copy
at an existing target failed without overwriting its receipt. A failing overwrite
probe exposed an `errexit` guard defect; independent `test` commands fixed it, and
the probe then passed. These are command-level observations, not prose assertions.

The original authority trials used the instruction-reading preamble:

- The agent read the declared pin and used `notes/` and plain Markdown while a
  conflicting catalog copy was available. It never loaded that catalog body,
  so this trial did not test handoff from a loaded copy.
- A missing declared target produced a dependency report and no draft.
- Equal-precedence declarations for two owners produced a conflict report and no draft.
- The original no-declaration trials used the catalog below, not F's literal
  direct-copy variant. That substitution left the direct-copy case untested.

The first description produced no authoring selection in either name-free creation
or revision. After clarifying the trigger, creation selected both authoring and
lifecycle and honored the local plain-Markdown format. Revision initially selected
neither; a fresh repeat selected authoring. A separate trial with a generic repo
instruction to use matching available skills also selected authoring. That last
trial adds a skill-selection hint. All these original trials already had the
`AGENTS.md` preamble, so none establishes automatic instruction loading.

This establishes observed selection on one client, not reliable automatic invocation.
It also does not satisfy the plan's literal requirement that the entire effective
catalog contain only supplied skills. A follow-up probe used
`CLAUDE_CODE_DISABLE_BUNDLED_SKILLS=1`; a second also disabled the two built-in
plugins in temporary settings and denied their skills. The latter catalog contained
exactly the three supplied skills plus `doctor`, which remained listed. The strict
U2 gate therefore remains open. These samples demonstrate pin use when prompted
to read repository instructions. They do not establish repeatable automatic
ownership, cross-client behavior, or daily activation.

## Opus review follow-up: core 1.4.1

The first seven fresh sessions used native Claude Code `2.1.302`, Fable 5.1, medium effort,
and the revised replay procedure. Prompts, settings, logs, and session records
stayed in coordinator directories outside each fixture workspace. The catalog
description was unchanged. Only its body gained a conflicting output-path rule;
the declared copy was intact. Declarations used the adoption example verbatim,
changing only its path to `docs/authoring/SKILL.md`.

| Trial | Observation |
| --- | --- |
| Ordinary creation, `AGENTS.md` declaration | With no skill name or instruction-reading hint, the agent invoked the catalog skill, read the pin and its planning reference, and wrote the plan under `notes/`. |
| Ordinary creation, `CLAUDE.md` declaration | The same sequence occurred in a fresh repository. |
| Explicit catalog invocation, `AGENTS.md` | The native `/authoring-eval:doc-coauthoring` command delivered the catalog body first. The agent then read the pin and its planning reference and wrote under `notes/`. |
| Explicit catalog invocation, `CLAUDE.md` | The same handoff occurred. Neither explicit run used the catalog's conflicting output path. |
| Explicit catalog invocation, missing pin | The catalog body loaded, the read of the declared target failed, and the agent reported the dependency without writing a plan. |
| No declaration, direct copy | With slash commands disabled and an empty skill catalog, the task explicitly named the copied `SKILL.md`. The agent used it and wrote under `notes/`. This covers the direct-copy variant; it is not discovery evidence. |
| Search with bundled fixtures | With slash commands disabled, a `CLAUDE.md` pin, and no fixture-exclusion hint, the agent inspected the two bundled example plans and the eval README. It identified them as test data, created a new plan under `notes/`, and left all fixtures unchanged. The suspected misclassification did not occur in this sample. |

All four catalog-to-pin runs eventually read the pin's planning reference.
Native session records confirm the catalog body preceded the pin read, including
the two explicit commands that expand without a `Skill` tool call. However, both
ordinary-request runs and the explicit `CLAUDE.md` run first read the catalog's
planning reference after loading the pin. Only explicit `AGENTS.md` handoff went
directly to the pin's reference. The two references had identical text, so correct
output paths did not establish reference ownership. Three runs failed that condition.
All pre-existing fixture and skill files remained byte-identical. Only the
intended plans were added. The handoff, discovery, and direct-copy runs did not
read evaluation metadata. The fixture-search probe intentionally did; it tests
classification, not authoring quality. Raw evidence is in ignored
`build/authoring-fixes/`.

Eight further fresh sessions tested two entrypoint clarifications. Both batches
also gave the catalog's planning reference a conflicting requirement to create
`catalog-progress.md`. The pin's reference had no such requirement. Prompts,
declarations, tools, and the catalog description stayed the same.

| Entrypoint version | Explicit `AGENTS.md` | Explicit `CLAUDE.md` | Ordinary `AGENTS.md` | Ordinary `CLAUDE.md` |
| --- | --- | --- | --- | --- |
| First clarification: use the selected folder as the reference base | Read catalog reference after pin; failed | Pin references only | Pin references only | Read catalog reference before pin; failed |
| Final: select owner before references, finish reading its entrypoint, resolve each link from its containing file and use absolute tool paths | Pin references only | Pin references only | Read catalog reference before repo instructions and pin; failed | Pin references only |

The first clarification also described later relative links too broadly; links
such as `../SKILL.md` must resolve from their containing file. The final instruction
corrects that rule and orders owner selection before opening any workflow reference.
All eight runs loaded the catalog before reading the pin and eventually read the
pin's planning reference. All wrote only the intended plan under `notes/`, left
pre-existing files unchanged, and avoided evaluation metadata. None created
`catalog-progress.md` or used `catalog-output/`. Correct output does not excuse
reading the wrong reference: the final ordinary `AGENTS.md` run remains a failure
of that condition. It recovered after reading the repository declaration.

Both final explicit-handoff samples passed the reference condition; the automatic-
selection samples were mixed. The final source contains the clarified instruction,
but these observations do not establish reliable reference ownership. Keep that
behavioral gate open alongside catalog isolation. The saved `fixed` and `final`
trial folders preserve both unsuccessful clarifications and their outputs; no
failed trial was replaced by a passing rerun in the record.

These are routing checks, not another paired quality comparison or a reliability
estimate. The supplied plugin contained only authoring. The client also listed
`deep-research`, `dataviz`, `workflow-authoring`, `plugin-authoring`,
`run-skill-generator`, and other entries captured in the init records. Their
individual origins were not established, and none was invoked. These trials do
not replace the three-skill U2 test. Explicit skill commands test handoff,
not automatic selection. The two ordinary requests show selection in those runs,
not how reliably either instruction filename is discovered or automatically
injected by the client. Strict catalog isolation, broader discovery, and consistent
reference ownership remain open. Disabling all slash commands produces an empty catalog for direct-copy
tests, but also removes the supplied skills needed for catalog tests.

The shell correction was checked against the previous command block: refusal
exited the interactive Bash caller before the change; afterward the caller
continued with its shell options unchanged. Intact copies still passed, while
changed, missing, extra hidden, symlinked, and existing-target/receipt cases were
refused without overwriting the existing receipt.

## Owner-selection regression: core 1.4.2

The 1.4.1 failure opened the catalog's planning reference before reading the repo
declaration. The revised entrypoint makes owner selection a preliminary tool phase:
read repository instructions, resolve the declaration, and wait for the selected
entrypoint's complete result before scheduling workflow-reference reads. Independent
task context can be read meanwhile. A failed declared-target read ends owner lookup.
The adoption link follows the renamed owner-selection section; the skill description
and planning guidance are unchanged.

A first frozen candidate ran nine fresh sessions. Its eight readable-copy cases
completed the entrypoint read before every workflow-reference read in a later
assistant turn. The missing-pin case reported the dependency and wrote nothing,
but then tried a search above the workspace that `--restricted` denied. That does
not establish a clean stop on failure. Opus also identified an unnecessary ban on
early task-file reads, which five runs did not follow. The final candidate allows
those independent reads and makes a failed target read explicitly end lookup. The
initial nine runs remain preserved in ignored `build/authoring-owner-phase/`.

The final candidate was frozen before a ten-session matrix, using native Claude
Code `2.1.302`, actual model `claude-fable-5-1`, medium effort. The routing prompts,
scope preambles, and declarations were copied unchanged from the previous trials.
The catalog retained the same description and both conflicting rules:
`catalog-output/plan.md` in its entrypoint and `catalog-progress.md` in its planning
reference. No prompt named the owner-selection correction.

| Case | Fresh sessions | Observed result |
| --- | ---: | --- |
| Ordinary creation, `AGENTS.md` declaration | 3 | Catalog loaded before the pin; every workflow-reference request followed a completed pin read in an earlier assistant turn and used the pin's folder. |
| Ordinary creation, `CLAUDE.md` declaration | 2 | The same reference-ordering condition passed. |
| Explicit catalog invocation, one per instruction filename | 2 | The same condition passed after native catalog-body delivery. |
| Explicit catalog invocation, missing pin | 1 | Reported the missing declared path, ended owner lookup without another search, and wrote no plan. No permission denial occurred. |
| Direct copy, no declaration and an empty catalog | 1 | Used the copied skill; the entrypoint read completed in an earlier turn than its planning-reference read. |
| Fixture search, a declared direct copy and an empty catalog | 1 | Correctly classified the bundled examples as test data and preserved them, but requested the repository declaration, entrypoint, and helper in the same assistant turn. Classification passed; reference ordering failed. |

The nine routing cases passed. The additional fixture-search probe failed the
ordering condition: it batched the declaration, entrypoint, and helper reads before
receiving the declaration or the entrypoint's sequencing instruction. The paths
listed by Glob matched the declared folder; that does not establish selection
based on the declaration. At 1.4.2 this remained open for direct-copy discovery; the skill
cannot guide the reader before its contents arrive. The probe also read evaluation
fixtures intentionally, so it supplies classification evidence, not authoring-quality
evidence. It is retained as a failure of the stricter ordering condition, not counted
as a tenth routing pass.

Controller files stayed outside each workspace, and every initial file was hashed.
All ten sessions preserved existing files, stayed within the supplied roots, and
had no permission denials. Only the nine intended plans were added under `notes/`.
No session read a catalog reference or followed either conflicting rule. The nine
routing cases read no evaluation metadata. The audit records Read completion and
assistant-turn identities, Glob results, Grep results when present, permission
denials, and lookup paths. Final-run searches used Glob only; they exposed filenames,
not file contents. The missing-pin report and fixture classification were also
reviewed directly. Client completion and evaluation pass/fail remain separate.
Raw evidence and the frozen matrix are in ignored `build/authoring-owner-final/`.

The catalog-to-pin regression is resolved for these Claude Code/Fable samples.
Earlier failures remain above; this is not a reliability percentage, a cross-client
guarantee, or another authoring-quality comparison. At 1.4.2, direct-copy read
ordering, strict catalog isolation, and broader three-skill discovery remained
open. The bootstrap follow-up below addresses direct-copy ordering. Daily
activation is separate.

## Direct-copy bootstrap follow-up: core 1.4.3

The failed direct-copy probe had no repository instruction attachment before its
first tool call. Six fresh diagnostic sessions separated loading from wording:

| Runner and declaration | Startup declaration | Entrypoint before references |
| --- | --- | --- |
| Restricted, empty settings sources, original declaration | Absent | Failed |
| Restricted, project settings source, original declaration | Absent | Failed |
| Restricted, project settings source, sequencing declaration | Absent | Failed |
| Normal mode, project settings source, original `CLAUDE.md` declaration | Present | Passed |
| Normal mode, project settings source, sequencing `CLAUDE.md` declaration | Present | Passed |
| Normal mode, project settings source, sequencing `AGENTS.md` declaration | Present | Passed |

All used the same direct-copy task without a skill name or instruction-reading
hint, native Claude Code 2.1.302, Fable 5.1, and medium effort. The restricted
runner suppressed startup instructions even with `--setting-sources project`.
Removing that flag restored native loading. The original declaration also worked
once loaded; this experiment does not attribute the improvement to wording alone.
The adoption guide now makes startup delivery a prerequisite and identifies
explicit loading as a fallback with a different evidence claim.

The first eleven-case matrix with native loading and a sequencing declaration
passed eight routing checks. Missing direct adoption still drafted a plan;
conflicting pins stopped drafting but read both folders' references; explicit
catalog handoff with a missing pin continued lookup after the failed read. The
next declaration added conflict and missing-dependency handling. Ten of eleven
cases passed, but the catalog missing-pin case still searched for `SKILL.md`
after failure before reporting the dependency. The final declaration makes a
failed read terminate tool use. These rules must be in startup context because
an unread or missing skill cannot supply them.

With the terminal stop rule, all eleven routing conditions passed. Opus review
then strengthened the search audit: absolute Glob patterns are checked for scope,
Grep access to catalog references is checked alongside Read, and evaluator
metadata exposure is separate from routing. The resulting audit found three
contaminated cases: direct `AGENTS.md` exposed replay/answers through Grep and
Read; one direct `CLAUDE.md` run read the eval README; explicit `AGENTS.md`
handoff exposed answers through Grep despite its prompt's exclusion. Their
owner and helper choices were scheduled before that exposure, so the ordering
observation stands, but these are not clean authoring-quality trials. The explicit
handoff also failed its metadata-exclusion condition. Raw evidence remains in
`build/authoring-bootstrap-terminal/`.

The final skill now scopes repository-context reads and content searches to
project-owned paths outside copied skills' evaluation trees. Filename listings
can still identify the bundled examples. The replay checks both Read and search
content for isolation failures.

Diagnostic evidence is preserved in ignored `build/authoring-bootstrap/`.
The first two eleven-case matrices remain in `build/authoring-bootstrap-final/`
and `build/authoring-bootstrap-fixed/`, including every failed attempt. Those
folder labels do not determine outcomes; each audit separates client completion
from its behavioral checks.

The next eleven fresh sessions passed routing and avoided content exposure.
A further Opus audit found one search-scope violation: a direct `CLAUDE.md` run
used a root content search returning matching filenames from `evals/`. It exposed
no text, but violated the skill's scope rule. Ten passed the combined checks; that
one remains failed in `build/authoring-bootstrap-scoped/audit.json`. The following
table records routing observations, not eleven clean overall passes:

| Case | Sessions | Routing observation |
| --- | --- | --- |
| Direct copy, ordinary request, `CLAUDE.md` | 3 | Native declaration present before tool choice; entrypoint completes in an earlier turn than its helper; new plan under `notes/`. |
| Direct copy, ordinary request, `AGENTS.md` | 2 | Same result; bundled plans remain test data. |
| Explicit catalog handoff, one per instruction filename | 2 | Catalog body delivered before pin; references come only from the pin; neither catalog decoy rule followed. |
| Missing pin, direct and catalog | 2 | Failed read followed by a dependency report, with no tool calls scheduled in a later turn and no draft. |
| Equal-precedence conflicting pins | 1 | Conflict report, no entrypoint or workflow reads, and no draft. |
| No declaration, explicit copied entrypoint | 1 | Uses that copy and writes under `notes/`; this is aided use, not discovery. |

All eleven had only the intended repo instructions in native startup attachments.
Every pre-existing file stayed unchanged; only the eight intended plans were
added. No session read bundled eval files or received their contents through
search. One filename-only Grep listed bundled paths; the two content-returning
Greps excluded the skill tree or its evals subtree. There were no catalog-reference
searches, out-of-root accesses, or permission denials. The declaration,
entrypoint, and runtime references matched that matrix's frozen inputs before the
filename-search clarification below.
Evaluator documentation was updated afterward and was not consumed by these runs.
Raw evidence, commands, source hashes, automated conditions, and manual dependency
and search reviews are in ignored `build/authoring-bootstrap-scoped/`.

The final instruction now explicitly scopes content searches that return only
matching filenames, while allowing filename globs for discovery. The audit records
routing, search scope, and content exposure independently. A search scoped inside
an eval tree is flagged even if its returned paths are relative to that scope.
A further eleven fresh sessions repeated the same matrix with the final source.
All passed routing, search scope, and content-exposure checks independently.
Every content search explicitly excluded the copied skill or its evals subtree;
there were no eval reads, unscoped content searches, or evaluator-content leaks.
The missing/conflicting cases produced dependency reports without drafts; the
other eight added only the intended plain-Markdown plan under `notes/`. All
existing files stayed unchanged. Native startup delivery, pin-before-reference
ordering, catalog handoff, root boundaries, and absence of permission denials
were also verified. The declaration, entrypoint, and all three runtime references
match the frozen inputs. Raw evidence, the separate audit dimensions, manual
checks, and source-parity receipts are in ignored
`build/authoring-bootstrap-search-scope/`.

These final samples resolve the direct-copy bootstrap and search-isolation
regressions for this configuration. They do not establish authoring quality,
general reliability, or another client's behavior. The explicit catalog cases
test handoff; they do not replace the broader three-skill discovery test. Strict
catalog isolation and that broader U2 gate remain open; daily activation is separate.

## Original implementation checks (core 1.4.0)

Both edited skill entrypoints passed the skill parser. The packaging suite passed
58 tests and deterministic builds; the built authoring folder matched its source,
and required runtime links resolved inside the folder. The two synthetic source
fixture tests passed.

All repository CI suites passed across the full run and resumed lanes: 516 Python
tests, 7 Node tests, 38 Swift tests, static checks, and chezmoi previews for all four
machine types. Of 283 Bats tests, one initially failed because it referenced the
retired `superpowers` package. Replacing that fixture path with the existing
hook-bearing `crit` package preserved the hook-suppression assertion; its focused
rerun passed. The remaining 282 Bats tests passed in the full run. Test logs remain
in ignored `build/authoring-evals/`. These checks do not close the U2 behavior gate.

The fixture README advertises a module command without an executable entrypoint.
It was retained identically across paired runs. Correctly identifying that mismatch
is source-grounding evidence; repairing the synthetic program was outside these
writing-only tasks. Model outputs still need reader review, including verification
of optional external comparisons that the local-only tools could not check.
