---
status: active
doc_type: plan
summary: "Make document authoring portable, evidence-based, and usable for autonomous drafting, interactive coauthoring, and substantive revision."
owner: Prateek
created: 2026-10-17
updated: 2026-10-18
related:
  - ../references/agent-marketplace.md
  - ../document-lifecycle.md
  - ../../agent-marketplace/packages/core/skills/doc-coauthoring/SKILL.md
status_detail: "Catalog handoff and direct-copy bootstrap pass the final Claude Code/Fable routing and search-isolation matrix. U2 remains open for catalog isolation and broader three-skill discovery. Daily activation remains separate."
---

# Improve document authoring skills

Improve `core:doc-coauthoring` so a reader can create or revise a useful document
without the author's conversation history. Keep its existing name and fresh-reader
review. Add explicit evidence and decision criteria, disclose implementation-plan
guidance only when needed, and make interactive drafting optional. Ship one
self-contained skill folder that another repository can pin and use directly.

## How to use this plan

The audience is the engineer or agent implementing the skill changes. The two
delivery units below name the files, prerequisites, observable results, and
acceptance evidence. Complete each unit's checks before depending on it.
The user authorized implementation on 2026-10-18. Daily plugin activation remains
a separate action.

The implementation sequence is U1, then U2. U1 improves the portable skill.
U2 connects existing callers and proves adoption in an isolated repository.
The lifecycle extraction has landed as separate work. Use the repository's
normal skill-management and landing workflows when implementation is requested.
No new execution framework is required.

## Preserve the request and scope

The required result is a reusable authoring workflow that agents can reach during
ordinary document work. Its required guidance and any supporting tools must fit
inside the skill folder. Adopters consume one pinned source rather than edit
copies of its policy. This plan evaluates the review suggestions against those
requirements and the current skills.

The work covers substantial document creation, implementation planning, and
revision after changed requirements or evidence. It preserves interactive
coauthoring for users who want it. It also preserves user-specified formats,
ordering, acceptance criteria, and the meaning of completion.

Lifecycle schema, retirement, publication, orchestration, and deployment remain
with their existing owners. This work changes no private repositories or daily
client installations. Temporary client profiles load fixture skills for testing.
Small wording edits do not need the full authoring workflow. A plan can be useful
without adopting this repository's
frontmatter or retention policy.

The lifecycle extraction landed at
`1c955fa4c183573c6b92229a7a14dc11a829d3b2`, with core version `1.3.0`.
Implementation starts from that commit. Planning used
`22e43e7e40b46d736f342b5fb85d023198c6265c` and inspected landed source through Git
and a preserved snapshot. This branch was fast-forwarded to the landed commit
before implementation. The original source worktree is no longer needed.

## What the current skills already do

These are source observations at the planning base, updated against the landed
lifecycle commit. They are not behavioral eval results.

| Component | Current behavior and authoritative input |
| --- | --- |
| `doc-coauthoring` | Authored in [its skill folder](../../agent-marketplace/packages/core/skills/doc-coauthoring/SKILL.md). Its Gather context, Refine and draft, and Test with a fresh reader sections cover audience, iterative drafting, and fresh-reader review. The implementation-spec branch already prioritizes an end-to-end slice. |
| Interaction defaults | The same file asks users to select the workflow, answer repeated question batches, select brainstormed points, and approve transitions. It names Claude and specific editing tools. Its completion test includes a fixed question to the user. These requirements impede autonomous drafting and portability. |
| Research reports | `core:deep-research` is an imported skill selected by [core's publication metadata](../../agent-marketplace/packages/core/publish.toml). Its [entrypoint](../../agent-marketplace/apm_modules/199-biotechnologies/claude-deep-research-skill/SKILL.md) already requires cited claims, explicit assumptions, evidence persistence, and claim verification. Its report sizes, source quotas, artifact formats, and output directory are unsuitable defaults for a repository plan. |
| Targeted research | [Matt Pocock's research skill](../../agent-marketplace/apm_modules/mattpocock/skills/skills/engineering/research/SKILL.md) delegates primary-source investigation and saves cited findings using the repository's conventions. It does not define document-authoring acceptance or a code-archaeology procedure. |
| Coupled updates | [Code gardening](../../agent-marketplace/packages/core/skills/code-gardening/SKILL.md) already reconciles nearby docs with changed behavior. Its [durable-doc guidance](../../agent-marketplace/packages/core/skills/code-gardening/references/durable-docs.md) requires a whole-document reread and one authoritative home per rule. It lacks a specific route for substantial plan revision. |
| Prose and agent instructions | [Writing for humans](../../agent-marketplace/packages/core/skills/writing-for-humans/SKILL.md) owns prose editing. [Writing for agents](../../agent-marketplace/apm_modules/mattpocock/skills/skills/productivity/writing-for-agents/SKILL.md) owns agent-instruction structure. Neither is a reason to repeat a style catalog in the authoring skill. |
| Lifecycle | The landed commit moves shared policy and tooling into `agent-marketplace/packages/core/skills/document-lifecycle/`. The [local lifecycle page](../document-lifecycle.md) is a configuration page and its validator is a thin adapter. `AGENTS.md` and code gardening route to the skill. |

The main additions are requirements preservation, consequential evidence,
decision completeness, plan decomposition, and revision after changed premises.
Audience selection, iteration, and fresh-reader review need refinement and reuse.
They do not need parallel implementations.

## Give each behavior one owner

| Behavior | Owner | How callers reach it |
| --- | --- | --- |
| Recover intent, find existing work, choose a document home | `doc-coauthoring/SKILL.md` | Skill description for creation and substantial revision. A repo pointer reaches its pinned copy. |
| Decide which factual gaps matter and whether to ask the user | `doc-coauthoring/SKILL.md` | The evidence step runs before a factual premise becomes a design premise. |
| Conduct a separate primary-source investigation | Existing research skills | Optional delegation when the task warrants a separate investigation. The authoring skill consumes the findings. |
| Develop implementation choices, outcomes, and dependencies | `doc-coauthoring/references/implementation-plans.md` | Load when the output directs implementation, including PRDs with implementation commitments. |
| Facilitate section-by-section collaboration | `doc-coauthoring/references/interactive-drafting.md` | Load when the user requests guided coauthoring or iterative selection among alternatives. |
| Reconcile changed requirements and stale premises | `doc-coauthoring/SKILL.md` | The revision branch. Code gardening routes substantial changes here. |
| Check the document without conversation context | `doc-coauthoring/SKILL.md` | The completion step, with plan-specific reader questions in the planning reference. |
| Record useful progress and unresolved acceptance | The implementation-plan reference | Use the repo's progress location or the fallback defined in the planning branch below. Lifecycle interprets that evidence when setting state. |
| Status, locks, indexes, retirement | Existing repo lifecycle policy or adopted lifecycle skill | Consult the repository's declared owner. Authoring does not supply a competing schema. |
| Pin and adopt this authoring folder | `doc-coauthoring/references/adoption.md` | Load only for adoption or packaging work. |

An evidence requirement is a document acceptance rule. A research method is how
an investigator obtains that evidence. Keep that distinction explicit. The
authoring skill must explain enough local inspection to finish alone. It must
not require a second skill to establish a premise or finish its reader review.

### Keep the common workflow in the entrypoint

Replace the existing ceremonial interaction sequence with the following steps.
Each completion criterion belongs next to its step, once.

1. Recover the request and the document's owner. Read supplied context, existing
   documents, and relevant repo instructions. Resolve the authoring authority
   using the declaration rule below before following this copy's remaining
   steps. Search the local index and topic paths before creating a sibling
   document. Inspect referenced branches or PRs when supplied evidence suggests
   parallel work. Finish when the audience,
   intended result, explicit requirements, exclusions, and authoritative editing
   location are identified, or a specific inaccessible input is recorded.
2. Establish the consequential facts. Inspect the definitions, consumers, and
   configuration that support the proposal. Use history when current evidence
   conflicts or the reason for a choice matters. Distinguish observed facts,
   assumptions, selected approaches, and unresolved decisions. Finish when each
   premise that could change the design has a source or a named uncertainty with
   its effect. Ask about judgment or unavailable intent. Research discoverable
   facts using available authorized tools.
3. Outline and decide. Draft a provisional structure suited to the audience.
   For a design, start with the problem and desired result, then the mechanism
   and material alternatives. Finish when every requested outcome has a place
   and every implementation-blocking choice is resolved or explicitly open.
   A provisional outline may be saved earlier during long investigations.
4. Draft or revise. Write the artifact in its existing format and location.
   Integrate changed answers into the affected sections. For revisions, reread
   the whole document and trace effects through requirements, decisions,
   dependencies, acceptance, and examples. Finish when those parts agree and
   remaining work is explicit. Preserve unrelated edits and generated sections.
5. Test the reader and finish. Give an isolated reader the document and realistic
   questions without the authoring chat. Correct concrete gaps and repeat the
   affected questions. Check links and the repo's applicable document rules.
   Finish when requirements are represented, consequential claims are supported
   or qualified, and the reader can identify the result and next action. Report
   unresolved decisions and missing verification in the handoff.

Use a fresh agent when available and permitted. If none is available, perform a
separate reread and label it a self-review. Do not claim independent validation.
A user-run fresh-reader test remains an option, not a mandatory stop. A single
reader can answer the small set of questions. Correctness and missing context
matter more than a fixed count of agents or repetitions.

### Disclose the planning branch

The planning reference owns these additions to the common workflow.

- Preserve each explicit requirement across revisions. Quote wording only when
  its precision changes scope or acceptance. Keep requirements separate from
  the author's chosen implementation approach and assumptions.
- Add a design beyond the request. Explain the mechanism, affected interfaces,
  ownership, and meaningful alternatives. Leave local implementation details
  flexible where the reader can choose without changing the agreed outcome.
- Define each deliverable by result, scope, prerequisite, and acceptance evidence.
  State whether a dependency needs an interface, code on the working branch,
  merged code, or deployed behavior. Use the earliest useful end-to-end result
  when the work has one. Respect user-required sequencing and necessary gates.
- Reconcile the remaining plan when new evidence invalidates a premise. A plan
  change is one that changes what a later implementer would do. Integrate
  plan-affecting review feedback into the relevant sections in the same change.
  Repair an ordinary sequencing defect within authorized scope. Ask only when
  the repair changes intent, authority, or a material constraint.
- Record decisions and their useful rationale in the document. Resolve the
  open-question list after integrating an answer. Keep material provenance,
  without requiring a verbatim question-and-answer transcript.
- Keep the specification stable and progress identifiable. Reuse the repo's
  existing progress location. If none is declared, append dated entries under
  one Progress heading at the end of the plan, separate from the specification.
  Create that section when there is progress to record. A separate log is useful
  for long execution, but `IMPLEMENTATION_LOG.md` is not a required filename or
  an automatic new file. Entries record changed state and supporting evidence.
  Completion means the agreed acceptance criterion, which may be a reviewed plan,
  passing tests, a merge, a deployment, or a physical check.
- Ask the fresh reader which decisions would stop implementation, what the first
  useful deliverable is, which prerequisites it needs, and what would prove it
  complete. For an integration project, check that later polish does not displace
  the necessary first slice. Do not demand five tasks when the plan has two.

Use Background, Goals, Non-goals, and Proposal as a starting example, not a fixed
schema. Add alternatives, rollout, risks, and open decisions when substantive.
Remove empty sections. A short plan need not inherit a long document's ceremony.

### Preserve interactive coauthoring as a branch

Keep section-by-section drafting and selective brainstorming in the interactive
reference. Ask only questions that remain after reading supplied context. Scale
the question batch to the decision, and proceed with independent drafting while
waiting when possible. Honor the user's choice of section order and feedback
style. Accept edits made directly by the user and carry their preferences forward.

Remove fixed rounds of 5 to 10 questions, 5 to 20 suggestions, the 80-percent
review threshold, compulsory approval after each section, and the fixed final
yes-or-no question. Remove the requirement to discourage direct user edits.
Use the tools actually available. Describe inaccessible images or missing source
access as limitations of the current environment, not universal Claude limits.

## Make the folder portable and discoverable

Keep `doc-coauthoring` model-invoked. Its description must distinguish creation,
implementation planning, and substantive revision. Suggested wording is a draft
to evaluate, not a string to freeze in a test.

> Create or substantially revise documents, including implementation plans,
> proposals, and technical specifications. Use for autonomous drafting or guided
> coauthoring.

Evaluate this description alongside gardening and lifecycle in the same catalog.
Authoring owns the content workflow, gardening reconciles affected surfaces, and
lifecycle applies the repo's document policy. Selecting both authoring and
lifecycle is valid. A substantive plan task that reaches only lifecycle has not
demonstrated authoring discovery. Preserve lifecycle's creation trigger and
gardening's existing deferral to a primary owner. Tune the authoring description
and gardening pointer if the discovery trial reveals ambiguity. Case E checks
that small copyedits and research-only tasks retain their own scope.

All required Markdown links in the skill resolve inside its folder. All examples
use adopter-relative paths. Repository files, user documents, and supplied links
are task input. They are not hidden dependencies on the publisher checkout.
No required runtime scripts are needed for prose judgment. The skill can finish
with the host agent's normal reading, editing, and research tools.

Research and prose skills remain optional capabilities discoverable from the
active catalog. The skill must still finish when only its own folder is installed.
It must not use sibling filesystem links, hard-coded cache paths, or an assumed
`core` or `mattpocock` installation for required behavior. This avoids copying
their report machinery or style catalogs into the authoring folder.

For reproducible adoption, use the repository's existing dependency mechanism
to pin the whole folder to an immutable revision or verified artifact. With no
such mechanism, vendor the folder under `vendor/doc-coauthoring/`. Keep the source
identity and complete file checksums in `vendor/doc-coauthoring.receipt/`, outside
the copied folder. Its `provenance.md` names the source repository and full commit,
or the verified artifact and digest, plus the skill's path within that source.
Its `SHA256SUMS` records every regular file, including dotfiles, with paths relative
to the skill root. Generate it from the accepted source before copying. Verify
from the copied skill root with `shasum -a 256 -c ../doc-coauthoring.receipt/SHA256SUMS`.

The adoption reference also supplies a shell recipe using `find`, `LC_ALL=C sort`,
and `cmp` to compare the actual file set with the manifest's paths. Added or missing
files fail verification, as do changed bytes and symlinks. This matches the
publisher's symlink-free payload contract. Keep the receipt outside the enumerated
tree. These are adoption commands, not a runtime authoring dependency.

Update the whole dependency, verify against the new source receipt, and review
the diff. Keep local templates, paths, and exceptions in adopter-owned instructions.
Changes to shared behavior belong upstream rather than in an editable local copy.

### Resolve the declared authoring authority

An authoring declaration is an instruction in the client's applicable repo
guidance, such as `AGENTS.md` or `CLAUDE.md`, to use a named `SKILL.md` for document
authoring. This includes policy files that guidance explicitly references. The
declaration names a repo-relative path and assigns authority to that copy. A bare
mention in a document or an incidental search result is not a declaration.
Resolve the path from the repo root; the folder can have any name.

The adopting repo's instruction pointer can be this short.

> For substantial document creation, implementation planning, or revision that
> changes what a reader should do, read `vendor/doc-coauthoring/SKILL.md` and use
> that pinned version. Repository formats and document ownership remain local.

Put lookup and handoff in the entrypoint's first step. Follow the client's normal
repo-instruction precedence to select a declaration. Read its target and use that
folder's workflow. If already running that file, continue without invoking it
again. Report an absent or unreadable target as a dependency problem and leave
authoring pending. If applicable declarations conflict without a precedence rule,
report the conflict instead of selecting one. With no declaration, continue from
the installed copy. These checks require no guessed directory names or new parser.
The adoption reference owns the declaration example and setup procedure; it
points to the entrypoint for runtime precedence rather than copying that rule.

Direct file reading supports clients without plugin discovery. Descriptions help
discovery; they do not enforce execution. Demonstrate both routes separately.

There is no new universal CI authoring gate. Existing document validators enforce
mechanical policy. Behavioral evals assess authoring quality. If lifecycle tooling
is also adopted, its resolved validator remains the command owner. The
authoring skill does not wrap or duplicate it.

## Deliver U1 as a complete authoring workflow

U1 changes no lifecycle behavior. Its result is a usable standalone folder,
with baseline and candidate authoring samples for review.

| File | Change |
| --- | --- |
| `agent-marketplace/packages/core/skills/doc-coauthoring/SKILL.md` | Replace the default interrogation loop with the common workflow above. Preserve the skill name. Add creation, planning, and substantial-revision triggers and local branch pointers. Keep completion criteria beside their steps. |
| `.../doc-coauthoring/references/implementation-plans.md` | Add the planning contract, deliverable example, revision effects, progress rules, and plan-specific reader questions. Move useful first-slice guidance here and remove its repeated copies from the entrypoint. |
| `.../doc-coauthoring/references/interactive-drafting.md` | Move the useful interactive branch here. Remove fixed counts, provider-specific instructions, and redundant permission questions. |
| `.../doc-coauthoring/references/adoption.md` | Add complete-folder pinning, the receipt format and verification commands, local customization boundaries, and the declaration example. Point to the entrypoint's authority rule. Include the clean-adopter procedure below. |
| `.../doc-coauthoring/evals/evals.json` | Use the existing convention for static prompts, input files, and observable expectations. Link the shared replay protocol from the eval README and keep it outside agent fixture inputs; do not assume the schema executes multiple turns. |
| `.../doc-coauthoring/evals/README.md` | Document the manual replay protocol below, the reader rubric, fixture mutations, isolation, result locations, and evidence limits. Keep model receipts and outputs in ignored scratch during development. |
| `.../doc-coauthoring/evals/files/` | Add small self-contained fixtures for the synthetic repository, existing plan, changed requirements, and adopter instructions. Keep the shared response script, including C's preference answer, in `evals/replay.md`; keep E's literal direct-edit payload here for coordinator insertion. Use Markdown fixtures for snippets where possible. |
| `agent-marketplace/packages/core/.codex-plugin/plugin.json` | Bump the core version for changed published content from the accepted release, currently `1.3.0`. Refresh that value at implementation time. Preserve unrelated metadata. |

The `...` prefix in this table is
`agent-marketplace/packages/core/skills`. These are proposed paths. The three
reference files and evals do not exist at the planning base.

- [x] Prepare the eval fixtures and scripted interactions while preserving the
  original behavioral instructions. Archive the complete baseline folder for
  later case F runs. Capture A through E baseline outputs through the manual
  protocol before rewriting the instructions. Record the source revision,
  model, prompt, fixture, interaction script, and output paths. Each output is
  evidence of that run, not a universal claim about the model.
- [x] First remove the mandatory interaction ceremony and repeated planning
  paragraphs. Add the common workflow and references in the same change so
  every branch remains reachable and usable.
- [x] Inspect the complete folder after rewriting. Every required pointer has
  a target and an activation condition. Each accepted rule has one owner.
  No pointer requires a sibling skill or the producer repository.
- [x] Validate skill frontmatter with the available skill validator. Run
  `just -f agent-marketplace/justfile -d agent-marketplace check` for packaging
  tests and two deterministic builds. Inspect the built core folder and native
  catalog entry, rather than assuming source edits were exported.
- [x] Run cases A through E against the candidate with the same inputs as the
  baseline. Give the outputs to a fresh reader without the drafting chat or
  variant label. Resolve candidate failures before U2.

U1 is complete when the packaged folder is self-contained, the candidate meets
the required predicates for A through E, and useful existing coauthoring behavior
is retained. Report baseline behaviors that already pass. If both variants perform
the same, claim no measured improvement for that case. Revise or remove new prose
that produces no distinct benefit and carries no necessary contract.

Keep the main workflow short enough that its steps remain visible. Do not replace
the old length with a longer flat checklist. The exact word count is not a gate.

## Deliver U2 by routing callers and proving adoption

U2 depends on U1's actual folder contents being available on the working branch.
Using a parent branch is sufficient for development. A published adoption receipt
requires an immutable accepted revision or a verified artifact.

| File | Change |
| --- | --- |
| `AGENTS.md` | Add one creation/substantive-revision pointer to the authored `doc-coauthoring/SKILL.md` folder in Docs And Decisions. Preserve the landed lifecycle pointer and its separate ownership. |
| `agent-marketplace/packages/core/skills/code-gardening/SKILL.md` | In step 4, beside the lifecycle pointer, route substantive plan revision to the declared authoring owner or, when none is declared, the available `doc-coauthoring` skill. Add no copy of the authoring steps. Preserve routine synchronization and lifecycle handling. |
| `agent-marketplace/packages/core/.codex-plugin/plugin.json` | Bump the version again if U2 lands separately because the published gardening entrypoint changes. |
| `tests/README.md` | Add a short pointer to the authoring evals and distinguish behavioral evidence from package and native-install tests. |
| `docs/index.md` and `docs/inventory.md` | Maintain the plan link and generated inventory while work remains open. At final completion, retire this plan using the existing lifecycle process. |

Gardening's `durable-docs.md` remains unchanged. Its activation condition covers
steady-state guides, so it cannot be the sole route for plan revisions. Gardening
still reconciles routine drift when no authoring owner is declared or available.
A declared but missing pin is a dependency problem under the authority rule.

- [x] Add the repo and gardening pointers after U1's targets exist. Inspect
  the landed lifecycle routing and preserve its ownership.
- [ ] Run case F against the archived baseline and candidate in separate temporary
  repositories and isolated client profiles. Expose only each copied folder,
  fixture instructions, and ordinary tools. Verify the candidate's receipt and
  the negative cases below. Record the client version and effective skill roots.
- [ ] Run the discovery procedure below with a fresh catalog in the isolated
  profile. Save loaded skill paths and artifacts. Keep this acceptance item open
  if the available client cannot provide the required isolation or discovery.
- [x] Run the package check for the changed gardening payload. Regenerate docs
  inventory, run the repo's docs lifecycle check, and inspect `git diff --check`.
  Use the full native-install regression suite only if installation or activation
  plumbing changes. The focused live discovery procedure remains required even
  when that broader suite is unnecessary.
- [ ] Review only the authoring changes for landing. Close the plan in the
  final implementation change when its acceptance is established. Keep durable
  instructions in the skill, record retirement, and remove this plan.

U2 is complete when local callers reach the correct owner, the clean adopter
creates and revises a usable plan from its verified pin, the isolated discovery
procedure passes, and the published folder has no mandatory cross-folder
dependency. Activation on the daily machine remains a separate authorized action.

### Verify discovery in an isolated client profile

Use a temporary repository and a client-supported isolated configuration and
catalog. Reuse the consumer suite's temporary-home layout where useful, but launch
an actual fresh agent session for this check. A passing consumer test establishes
materialization, not model selection. Inspect the effective catalog before each
run; it must contain only that scenario's supplied skills. Keep the daily profile
and its caches unchanged. If the client cannot isolate its catalog, record that
limit and leave U2 open rather than testing against the daily installation.

Run these scenarios on one named client and version. Broader client support
remains unverified until tested separately.

1. With only the copied authoring folder and repo pointer, create and revise the
   case F plan through direct file reads. No publisher checkout or sibling plugin
   is available to the session.
2. With no declaration, expose the built authoring, gardening, and lifecycle
   skills through the isolated catalog. Request plan creation and substantive
   revision without naming a skill. Pass when authoring handles content and
   lifecycle handles applicable metadata and state. Selecting both is valid.
3. Keep those catalog entries and declare the unchanged candidate folder as the
   repo's pin. Preserve the description in a test-only catalog copy and add a
   body rule directing output away from the adopter's required plan path. Add a
   distinct planning-reference rule requiring `catalog-progress.md` in that copy.
   First
   request ordinary creation without an instruction-reading hint. Separately,
   explicitly invoke the catalog skill in a fresh session to test handoff.
   Require evidence that the catalog body loads before the declared target is
   read, workflow references come only from the pin, and the adopter's path is
   honored. Reading a catalog reference before selecting the owner also fails.
   Direct pin use alone is not handoff.
   The altered catalog copy is a test fixture, never a release input. Repeat with
   the declared target missing; the agent must report the dependency and leave
   authoring pending. Exercise declarations in `AGENTS.md` and `CLAUDE.md` separately.

Save the catalog listing, loaded paths, transcript, and output for each scenario.
Record provider and tool differences. The direct-pointer run cannot substitute
for the catalog run or establish discovery on another client.

## Evaluate the behavior through concrete tasks

The evals use real document outputs and reader answers. They do not assert a
heading roster, exact prose, a prescribed number of questions, or a score based
only on keyword presence. Use small fixtures with independent expected facts.

| Case | Input and required observation |
| --- | --- |
| A. Create a plan | A synthetic repo has a config producer, a consumer, an existing test command, and a request to change behavior. The output preserves the request, identifies those facts from the fixture, chooses a mechanism, and defines a useful first result with evidence. It adds design beyond restating the request. |
| B. Revise a plan | An existing plan has dependent deliverables. A changed requirement makes one premise false while unrelated user edits remain valid. The revision updates the mechanism, affected dependencies, acceptance, and open decisions together. It preserves the unrelated edits and leaves no conflicting old instruction. |
| C. Research or ask | The fixture answers which checks exist. The user has not chosen a material compatibility policy. The agent reads the checks, asks a focused preference question, and continues independent drafting. The replay script supplies the same answer when that question is asked. A separate autonomy variant grants the choice in the initial prompt and expects a stated reasonable default. Neither variant asks the user to recite discoverable facts. |
| D. Reuse existing work | The repo contains an unfinished plan on the same topic, a retired related item, and a supplied follow-up. The agent continues the live plan, integrates the clarification, and preserves retirement semantics. It creates no duplicate topic document or transcript appendix. |
| E. Preserve interaction and scope | A user requests section-by-section collaboration on a proposal and a pause after saving the first named section. Apply the same direct-edit payload during that pause, then replay feedback. The agent incorporates the edit and respects the requested section order. A paired small-copyedit task stays small. A research-only request stays with research rather than creating an implementation plan. |
| F. Adopt a clean folder | A temporary repo has no publisher checkout or research/lifecycle plugins. Its pin and pointer reach the copied skill. The agent creates then revises a plan, resolves all required references within the folder, and follows the adopter's format. Exercise an arbitrary pin-directory name, no declaration, a missing declared target, and an unresolved declaration conflict. The last two leave authoring pending. Verify the intact receipt passes and changed, removed, extra hidden, or symlinked files fail in separate fixture copies. Record one progress update with no repo progress location; it belongs in the plan's separate Progress section. |

### Run the baseline and candidate with manual transcript replay

Use the existing agent client interactively, with a human or coordinating agent
acting as the scripted user. The eval owner records each message and fixture edit.
The static `evals.json` convention supplies prompts and expectations; it is not
assumed to implement multi-turn sessions. This protocol requires no new runner.

1. Before the baseline, freeze each initial prompt, fixture, answer map, edit
   payload, and stop condition in the case's replay file. Set the same turn and
   time budgets for each pair and record them. Start fresh sessions with separate
   fixture copies, the same model and tools, and only the intended skill version
   available. Preserve the original folder for F, which runs in U2.
2. At each user-input boundary, supply the matching prewritten answer. For every
   case, use this fallback for workflow-choice questions and facts already covered
   by the request or fixture. "Use the supplied request and repository files.
   Proceed with your best judgment on ordinary drafting choices within that scope." Apply it to
   either variant whenever needed. Do not answer discoverable facts on its behalf
   or grant an unresolved material preference through the fallback.
3. In C's preference variant, reserve the compatibility answer for the first
   question about that choice. Save that event and reply verbatim. An agent that
   silently invents the choice fails the case even if it produces a draft.
   The separate autonomy variant supplies its grant up front to both versions.
4. In E, the common prompt names the first section and requires a pause after
   saving it. The fixture defines a stable edit target and literal user text.
   During that pause, apply the text to the saved document before sending the
   next scripted message. Record the actual diff in each run. If the required
   pause or edit target is missing, record the behavioral failure; do not repair
   it for the agent or pre-apply the edit before drafting.
5. If an unanticipated material question has no answer in the script, mark the
   fixture incomplete. Amend it and rerun both variants. Do not improvise a hint
   for one version. Distinguish tool or client failures from behavior failures.
   An unanswered harness question is not evidence that the skill cannot finish.
6. Stop at the case's declared completion or the shared budget. Save all artifacts
   and transcripts, including incomplete runs. Score content against the reader
   rubric and record unnecessary questions separately. A stalled or truncated run
   needs that qualification; it does not establish a general quality advantage.

Reviewers receive the artifacts without variant labels or the drafting chat.
The eval owner separately checks transcripts for interaction and authority
predicates that cannot be judged from the finished document alone.

For A and B, the fresh reader must identify the requested outcome, selected
mechanism, major rationale, constraints, first action, dependencies, and proof
of completion. It must also list decisions that would stop work. An author may
not mark a missing decision as settled merely because the reader guessed it.

Run one baseline and one candidate per case variant initially. Repeat a case when a
failure, ambiguity, or suspected run variance could change the decision.
Add an unseen variant of creation or revision after tuning. Keep model, tool,
fixture, and prompt differences visible. A few samples support a bounded
acceptance decision, not a reliability percentage or cross-client guarantee.

The smallest mechanical evidence is frontmatter parsing, package publication,
internal-reference resolution, receipt verification, and document validation.
Reuse existing tools. Do not build an authoring linter that tries to decide
whether prose expresses enough rationale. No performance benchmark, ten-lane
swarm, UI recording, or production deployment is justified by this change.

## Alternatives and decisions

| Choice | Decision and reason |
| --- | --- |
| Add a new planning or editor skill | Keep the existing name and one entrypoint. Planning and revision share intent recovery, evidence, and reader testing. Their distinct instructions fit disclosed references. A new invocation is not yet justified. |
| Put revision in lifecycle | Put substantive revision in authoring. A repo can author or revise a plan without adopting lifecycle states or tooling. Lifecycle continues to interpret completion evidence. |
| Require research and prose plugins | Keep them optional. A required sibling plugin breaks the requested independent-folder contract. A comprehensive research report already has an owner and need not be recreated inside every plan. |
| Patch upstream research | Make no research-source change in this plan. Existing primary-source and citation rules cover the useful overlap. The missing behavior is using evidence to finish a document, which authoring owns. |
| Add one shared external policy file | Keep required policy inside the authoring folder. Callers point to its workflow instead of maintaining copies. An external file would create the dependency the user asked to remove. |
| Force a single template or separate log | Let the requested format and repo conventions decide. Use a separate Progress section when no progress home exists. Create it only when needed, without requiring an extra file. |
| Make every question a blocker | Preserve material unknowns and actual evidence gates. Resolve ordinary choices from evidence and authority already granted. Expose genuinely blocking product choices rather than fabricate answers. |
| Enforce authoring through a save hook | Use discovery, repo pointers, and focused evals. Hook-driven rewriting adds a new execution mechanism and risks surprising edits. This task has no evidence that such machinery is necessary. |

There are no unresolved product decisions required to make this proposal
reviewable. The choices above are recommendations for user review. Final release
numbers and the accepted implementation base are facts to refresh when execution
begins. Behavioral effectiveness and client discovery remain experiments to run,
not preferences to ask the user to decide.

## Disposition of the review suggestions

All eight merged suggestions are accounted for below. The reviews are evidence
of potentially useful instructions. They do not prove those instructions improve
our agents' outputs.

| Suggestion | Disposition |
| --- | --- |
| 1. Recover full intent and existing work | Accept in the common workflow. Existing context gathering covers part of it. Add reuse, requirement preservation, and an explicit editing owner. Keep duplicate searches proportional to the task. |
| 2. Research facts, ask about judgment | Accept in the common workflow. Reuse established research skills when useful. Require consequential evidence, not exhaustive searches or mandatory history archaeology for every symbol. |
| 3. Turn the brief into a design | Accept in the planning reference. Separate requirements, approach, assumptions, and open choices. Preserve meaningful alternatives and necessary evidence gates. |
| 4. Outline in passes | Refine existing behavior. Keep a provisional outline, format flexibility, and meaningful iteration. Remove fixed question counts and section ceremonies. |
| 5. Outcomes and real dependencies | Accept in the planning reference. Keep existing first-slice thinking where it applies. Define done by the request's acceptance criteria. |
| 6. Reconcile after substantive edits | Accept in authoring with a gardening pointer. Update stale premises and their consequences together. Do not move the authoring procedure into lifecycle. |
| 7. Durable decisions and useful progress | Adapt in the planning reference. Integrate answers and rationale. Keep exact wording only when material. Reuse the existing progress home, with a separate plan section as the default when none exists. |
| 8. Fresh-reader review | Retain and sharpen. Add implementation-blocking questions and concrete completion criteria. Remove the mandatory Claude-specific flow and repeated user approval. |

Additional raw-review ideas have these dispositions.

- First-save draft status and promotion rules stay with the adopter's lifecycle
  policy. Follow its actual states. A finished draft does not authorize execution.
- A sequencing defect belongs in the plan when it changes future work. Fix a
  routine defect in scope. A universal stop-and-ask rule adds needless blocking.
- Record meaningful changes of state, but reject universal "done means merged."
  Reject bans on necessary evidence gates and requirements to preserve every
  answer verbatim forever.
- Classify repository-owned, generated, and externally managed documents before
  editing. This is a useful authoring boundary. Use the owning system's workflow
  for a managed document. Published URL redirects and retention are separate
  lifecycle or site-maintenance work.
- Test reachability of the pinned folder. Existing locks, immutable ADR numbers,
  generated inventories, and retirement ledgers already have owners. Duplicate
  schemas, prompt catalogs, controller APIs, notifications, and scheduling rules
  add no authoring capability here.
- The two reported lifecycle portability findings were fixed in the landed
  extraction. Its regression tests cover retirement of `guides/docs/task.md`
  under a custom root and rejection of the dotfiles adapter exception by the
  standalone validator. No authoring follow-up is needed for those findings.
  Python-version portability and broader ledger immutability remain separate
  observations, not proven new regressions.

## Packaging ownership and unchanged inputs

The [marketplace workflow](../../agent-marketplace/README.md) and
[repo skill-management instructions](../../.agents/skills/agent-skill-management/SKILL.md)
are the implementation authority. Authored files live under package `skills/`.
Selected upstream files come from the root's accepted lock and pristine cache.
Patches modify temporary plugin copies. Overlays add published files.

| Input or output | Treatment |
| --- | --- |
| Core authored doc, gardening, and prose folders | Edit only the files listed in U1 and U2. The landed lifecycle folder remains separate. |
| `packages/core/publish.toml` | Selects deep-research, code-principles, and Strunk. No change needed for the already-authored coauthoring skill. |
| `packages/core/patches/001-local.patch` | Changes Strunk's invocation controls. It does not own doc-coauthoring or deep-research. Leave unchanged. |
| `packages/mattpocock/publish.toml` | Selects the entire normalized `apm_modules/mattpocock/skills/.apm/skills/` collection plus its root license. There is no per-skill research selection or current package patch to edit. Leave unchanged. |
| `apm.yml`, `apm.lock.yaml`, `apm_modules/` | Keep accepted dependency bytes and pins unchanged. Deep-research resolves to `f2f2c0fa4e7617ca84c86b63f4bb40f77a746933`. Matt Pocock resolves to `49dd158d1076134a641b33efb035946536778336`. The lock is authoritative. |
| `build/marketplace/plugins/core/skills/doc-coauthoring/` | Generated output to inspect after the build. Do not hand-edit it. The release receipt records artifact hashes. |
| `home/.chezmoidata/agent_plugins.toml` and apply-time scripts | No activation-policy or materialization change. Existing consumers materialize the artifact under `~/.agents/plugins`; native clients manage their caches. |

Keep the skill model-invoked. No human-only restriction or new Codex sidecar is
needed just to change its description. If interface metadata is later added,
preserve invocation parity and validate it with the package check. Source changes
do not prove an existing agent session has reloaded the skill.

## Apply the requested writing disciplines

The exact requested installed copies of `writing-for-agents` and `poteto-mode`
were read for this plan. The Poteto entrypoint, planning playbook, routed writing
skills, and principle leaves linked below were compared with the repo cache and
have identical bytes. The repo lock's package version differs from the installed
package label. These links identify the inspected text, not a runtime upgrade.

| Principle or rule | Choice it changes |
| --- | --- |
| [Writing for agents](../../agent-marketplace/apm_modules/mattpocock/skills/skills/productivity/writing-for-agents/SKILL.md) and [skill mechanics](../../agent-marketplace/apm_modules/mattpocock/skills/skills/productivity/writing-for-agents/SKILL-MECHANICS.md) | One model-invoked description names distinct branches. Common steps remain visible. Planning, interactive, and adoption details move behind conditional pointers. Completion criteria are local and checkable. |
| [Laziness Protocol](../../agent-marketplace/apm_modules/cursor/plugins/pstack/skills/principle-laziness-protocol/SKILL.md) | Improve one existing skill. Keep research imports unchanged and avoid a new authoring subsystem. |
| [Subtract Before You Add](../../agent-marketplace/apm_modules/cursor/plugins/pstack/skills/principle-subtract-before-you-add/SKILL.md) | Remove the mandatory question rounds and repeated plan rules before adding the missing evidence and revision instructions. |
| [Sequence work into verifiable units](../../agent-marketplace/apm_modules/cursor/plugins/pstack/skills/principle-sequence-verifiable-units/SKILL.md) | U1 delivers a usable folder and checked behavior. U2 adds callers and clean-adopter evidence after the folder exists. |
| [Prove It Works](../../agent-marketplace/apm_modules/cursor/plugins/pstack/skills/principle-prove-it-works/SKILL.md) | Inspect the built folder and actual reader outputs. Separate syntax, package, behavioral, and activation evidence. |
| [Explain the Number](../../agent-marketplace/apm_modules/cursor/plugins/pstack/skills/principle-explain-the-number/SKILL.md) | Replay equivalent inputs in both variants. Separate unanswered harness questions, tool failures, and interaction cost from document quality. |
| [Encode Lessons in Structure](../../agent-marketplace/apm_modules/cursor/plugins/pstack/skills/principle-encode-lessons-in-structure/SKILL.md) | Use one canonical folder and a pin receipt for drift. Use examples and evals for judgments a parser cannot establish. |
| [Guard the Context Window](../../agent-marketplace/apm_modules/cursor/plugins/pstack/skills/principle-guard-the-context-window/SKILL.md) | Bound the read-only packaging explanation and conduct a separate fresh-reader review. Keep private raw reports outside the public plan. |

The final writing pass uses the read [technical-writing](../../agent-marketplace/apm_modules/cursor/plugins/pstack/skills/technical-writing/SKILL.md)
and [unslop](../../agent-marketplace/apm_modules/cursor/plugins/pstack/skills/unslop/SKILL.md)
guidance. The document combines implementation instructions with the rationale
needed to review them, as the task requests. It avoids an additional family of
documents solely to enforce one prose category per file.

The [multi-phase planning playbook](../../agent-marketplace/apm_modules/cursor/plugins/pstack/skills/poteto-mode/playbooks/multi-phase-plan.md)
was applied during the original planning phase with these scope adjustments.
These describe completed planning work, not limits on the later implementation
authorization recorded above.

1. The shared skill, callers, and portable adoption warranted a plan instead of
   the playbook's one-file shortcut.
2. Source inspection resolved packaging facts. Behavioral effectiveness was
   reserved for the implementation trials; no prototype benefit was claimed.
3. A read-only packaging explainer supported ownership discovery, and a fresh
   reader reviewed the plan. Codex collaboration replaced Cursor-specific agent
   types and unavailable model slugs.
4. Repo-local placement and two coherent delivery units replaced the playbook's
   agent-store placement and orchestration skeleton.
5. Technical-writing and unslop guided the prose, with decision rationale kept
   beside the implementation instructions.
6. `check-plan.mjs` was used as a diagnostic. Its PR lifecycle, ten live lanes,
   performance budgets, and hourly automation did not apply to this task.
7. The original deliverable ended with the plan. The user's subsequent
   `mattpocock:implement` invocation authorized implementation, review, and a
   commit on this branch. Push, merge, and daily activation remain outside that grant.

The historical checks below establish the planning artifact. Current implementation
and behavior evidence belongs in Progress and the linked evaluation results.

## Evidence and handoff

The source inspection includes the current authored skills, imported research
guidance, publication selections, patch ownership, and build entrypoints. The
input reviews include a collaboration analysis, an independently identified
Fable review, and their merged suggestions. The collaboration report's model
identity is not established. No separate Astra-authored source report was
verified. Their private source citations remain in the private handoff bundle.

Public conclusions here are generic. Implementers need the repository files
linked above and this plan, not the private reports or the authoring conversation.
Read the current files again before execution because imported pins and
lifecycle policy can change independently. The landing handoff reports 54
lifecycle tests, 58 packaging tests, and deterministic builds passed. The planner
inspected the landed portability regression tests but did not rerun that landing
suite or activate its plugins.

A fresh reader received only this plan and its review questions. It recovered
the intended outcome, owners, delivery order, and completion evidence without
the private reports. Its two requested corrections are incorporated above.
Prepare fixtures before taking the baseline, and replay identical interactions
for the preference and coauthoring cases.

A subsequent adversarial review ran as verified Fable 5.1 through Claude Code.
Its accepted corrections define pin declarations, make the eval replay executable,
and place the gardening route in the reachable entrypoint. Receipt checks,
isolated discovery, complementary skill triggers, and the progress fallback are
also specified above. The reported stale-base contradiction was rejected after
checking this worktree's HEAD and local lifecycle file. Source observations now
use section names instead of fragile line ranges. This revision was checked for
internal consistency; the behavioral trials remain implementation work.

Planning verification produced these results.

| Check | Result |
| --- | --- |
| `just docs-inventory` | Regenerated the inventory with this proposed plan. |
| Initial `just test-docs-lifecycle` | All 49 tests in the planning base passed. Validation passed for 155 documents against `HEAD`. This is separate from the landed extraction's 54-test result. |
| Post-review `just check-docs-lifecycle` | Validation passed for 155 documents against `HEAD`, including the existing inventory. The prose revision changes no validator code or schema. |
| Post-review whitespace checks | The tracked diff and the plan's revision diff contain no whitespace errors. |
| Poteto `check-plan.mjs` | Exited 1 with `0 PR sections, 4 problems`. It requires `How to read this`, `Program checklist`, `Close the program`, and PR sections. Those template requirements were deliberately replaced by the task-specific plan above. No punctuation findings were reported. |
| Source snapshot | All 12 files changed by the landed lifecycle commit match the preserved snapshot byte for byte. |
| Fresh-reader review | Two reproducibility corrections were requested and incorporated. No unresolved product choice blocked the reader. |

The planner made no changes to the original source worktree or its preserved
snapshot. These checks establish a reviewable plan. They do not establish that
the proposed skill improvements work in production.

## Progress

- 2026-10-18. Implementation authorized on the landed lifecycle base. The complete
  original authoring folder and frozen fixtures were preserved in ignored scratch;
  A–E baseline trials finished before the runtime instructions changed.
- 2026-10-18. Implemented the common authoring workflow, planning/interaction/adoption
  references, fixtures, and callers; core payload version is 1.4.0. Paired baseline
  and candidate trials cover A–F and an unseen creation variant. Focused A/B/C reruns
  follow the trigger and integration-boundary refinement. Blind reader review covers
  A–E, and separate repair turns resolved the candidate A/C blockers. See the
  [reviewed observations](../../agent-marketplace/packages/core/skills/doc-coauthoring/evals/results.md)
  for baseline strengths, initial output defects, and evidence limits. U1 is complete.
- 2026-10-18. Parser checks, 58 packaging tests, deterministic builds, runtime
  links, receipt mutation checks, static checks, and four machine-type previews
  passed. The remaining CI lanes passed: 516 Python, 7 Node, and 38 Swift tests.
  The Bats run passed 282 of 283 tests; the sole failure was a pre-existing reference
  to the retired `superpowers` package. A narrow substitution with hook-bearing
  `crit` preserved the assertion and passed its focused rerun. Interrupted package
  runs and the final successful checks remain recorded in ignored scratch.
- 2026-10-18. Independent standards and spec reviews found stale planning-only
  instructions and incomplete A–E reader-review guidance. Both were corrected,
  the missing reader reviews were performed, and the evidence was reconciled.
- 2026-10-18. U2's caller and direct-adoption work is implemented. Live creation
  selected authoring and lifecycle; revision selected authoring on a repeat.
  Temporary-profile probes disabled bundled skills and both built-in plugins, but
  the final catalog still listed `doctor` beside the three supplied skills. No
  built-in skill was invoked. F's functional checks passed, but its strict profile
  condition and the discovery gate remain open. Keep this plan active until a
  client satisfies that isolation requirement or the acceptance rule is explicitly
  revised. Daily activation was not attempted.
- 2026-10-18. Applied the Opus review corrections in core 1.4.1: absent-path
  wording, subshell-scoped copy commands, explicit fixture boundaries, complete
  prompt preambles, and corrected historical evidence. Seven fresh Claude/Fable
  sessions cover catalog-to-pin handoff for both instruction filenames, ordinary
  selection, missing-pin refusal, no-declaration direct use, and fixture search.
  Native records prove the catalog body loaded before the pin. The fixture-search
  probe recognized bundled examples as test data. These are bounded routing checks;
  the supplied three-skill catalog and strict isolation requirement remain open.
- 2026-10-18. The follow-up review found wrong-folder reference reads in three
  of the four catalog-to-pin trials. Corrected the result claims and clarified
  the entrypoint: select the owner before workflow references, finish reading
  its entrypoint, resolve links from their containing files, and use absolute
  tool paths. Eight fresh trials tested two clarifications with a conflicting
  catalog-reference rule. The final explicit handoffs passed for both instruction
  filenames. The final ordinary `CLAUDE.md` trial passed, but ordinary `AGENTS.md`
  read a catalog reference before checking the repo declaration, then recovered.
  All eight preserved existing files and used the local plan path. The failed
  reference-read condition remains visible in the eval results. Consistent
  reference ownership joins the open U2 gates; this plan remains active.
- 2026-10-18. Native Claude Code / Opus 5.5 re-reviewed the corrections and
  confirmed the remaining reference-read failure is accurately reported. Its
  additional audit-label finding was corrected: client completion and evaluation
  pass/fail are separate fields. Core 1.4.1 passed the skill parser, 58 packaging
  tests with deterministic builds, 54 lifecycle tests and branch validation,
  and complete-copy verification for all 21 authoring files. These corrections
  have not been pushed or activated in the daily profile.
- 2026-10-18. Addressed the catalog-to-pin reference-ordering failure in core
  1.4.2 with a separate owner-selection phase. Workflow references wait for the
  selected entrypoint's completed result; independent task context may be read
  meanwhile. A failed declared-target read ends lookup. After review, nine fresh
  Claude Code 2.1.302 / Fable 5.1 routing cases passed: three ordinary `AGENTS.md`
  requests, two ordinary `CLAUDE.md` requests, explicit handoff for each filename,
  missing-pin refusal, and no-declaration direct use. Every readable-copy routing
  case completed its entrypoint read in an earlier turn than its helper read.
  The missing-pin case stopped without an alternative search or sandbox denial.
  An additional fixture-search probe classified examples correctly but batched
  the repository declaration, entrypoint, and helper reads in one turn; that ordering failure
  remains recorded. All ten preserved existing files and ignored the conflicting
  catalog rules. Evidence is bounded to this client/model. Direct-copy ordering,
  strict catalog isolation, and broader three-skill discovery remain open.

- 2026-10-18. Fixed the direct-copy bootstrap in core 1.4.3. The old restricted
  runner suppressed native repository instructions; the replay now verifies
  declaration delivery before the first tool choice. The startup pointer carries
  ordering, unresolved-conflict, and failed-read stop rules. The skill scopes
  context reads and all content searches, including filename-returning searches,
  outside copied evaluation trees. All eleven fresh final Claude Code 2.1.302 /
  Fable 5.1 cases passed routing, search scope, and content-exposure checks:
  repeated direct requests, explicit catalog handoff, missing pins, conflicting
  pins, and aided no-declaration use. Existing files stayed unchanged; runtime
  instructions matched the frozen source. Failed and contaminated candidates
  remain in the linked evaluation history. Direct-copy ordering and search
  isolation are resolved for this tested setup. Strict catalog isolation and
  broader three-skill discovery remain open.
