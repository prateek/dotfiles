---
status: active
doc_type: research
summary: "How the Matt Pocock, superpowers, and pstack skill packs create, locate, update, and retire documents at pinned versions, compared with this repo's lifecycle."
owner: Prateek
created: 2026-10-17
updated: 2026-10-17
related:
  - ../document-lifecycle.md
  - ./documentation-maintenance-review.md
  - ./pstack-context-impact.md
  - ../adr/0052-retire-closed-docs-through-a-ledger.md
status_detail: "Snapshot of mattpocock/skills main 49dd158 (cache labelled 1.3.1; tag v1.3.1 is 24fe0ef), obra/superpowers v7.0.0 bb92a77, cursor/plugins pstack 0.15.25 at 99743e9 (upstream main 182f2ce changes packaging only). Repeat when any pin moves."
---

# Document Lifecycles in Three Agent Skill Packs

All three skill packs tell the agent when to create a document and where to
put it. None of them gives a committed document a status field, an index, or
a rule for closing it after the work lands. Matt Pocock's skills push most
artifacts out of the main branch: specs and decisions go to the issue tracker,
and prototypes and wayfinder research go to throwaway branches that never
merge. ADRs and `GLOSSARY.md` are the only durable in-tree docs, and ADR
status is an optional field. Superpowers commits dated specs and plans under
`docs/superpowers/` and never touches them again. Its only end-of-life rule
deletes the gitignored per-plan execution scratch. pstack writes plans and
decision logs to the agent's own store or a local work directory by default.
Its guide says to delete a committed plan when the work lands. Its one
structural lint checks plan shape, not lifecycle. Each pack has open upstream
issues where users hit the missing stage: planned ADRs read as in force,
plans whose checkboxes never get ticked, and requests for a `done/` folder.
This repo's [document lifecycle](../document-lifecycle.md) covers the stages
the packs skip. The packs keep work artifacts out of the tree, which this
repo does not.

## Versions examined

| Collection | Pin examined | Notes |
| --- | --- | --- |
| mattpocock/skills | `49dd158d1076134a641b33efb035946536778336` (main, 2026-10-09) | The local plugin cache is labelled 1.3.1, but its `wayfinder` and `handoff` files hash to main, not to tag `v1.3.1` (`24fe0ef7737efae15c87225755e9f6f5965e4888`). The repo's `agent-marketplace` lock also pins `49dd158`. `research/SKILL.md` and `ADR-FORMAT.md` are identical at both. |
| obra/superpowers | `v7.0.0` = `bb92a77741419a4ab5f06e711a283343f1ada0c3` (2026-10-10) | The local cache matches the tag for `brainstorming`, `writing-plans`, and `executing-plans`. The default branch is `main`; PRs target `dev`. |
| cursor/plugins `pstack/` | `99743e9c151c8537cbbf1f98bb38f34ef3368453`, version 0.15.25 | Vendored under `agent-marketplace/apm_modules/cursor/plugins/pstack`. Upstream main `182f2ce` adds a Claude Code install tree and changes no skill file. The local patch touches only `setup-pstack`. |

Citations below use `M:`, `S:`, and `P:` for paths in each repo at these
pins. The [link list](#source-links) resolves them.

## Comparison

| Stage | Matt Pocock skills | superpowers | pstack |
| --- | --- | --- | --- |
| Create | Per artifact. ADR only when hard to reverse, surprising, and a real trade-off. Glossary term when resolved. Spec on request (`to-spec`). Research file per run. | Spec when brainstorming sizes the work as "a project with a written design". Plan after spec approval. | Plan only for multi-phase work, and the playbook skips it for one or two files. Decision trail for long or unattended runs. |
| Location and naming | `docs/adr/NNNN-slug.md` (scan for the highest number). Root `GLOSSARY.md`, or a `GLOSSARY-MAP.md` that points at per-context files. Spec and tickets in the issue tracker, or `.scratch/<feature>/spec.md` and `issues/NN-slug.md`. Research "where the repo already keeps such notes". Prototype and wayfinder research on `prototype/<name>` and `research/<name>` branches. Rejections in `.out-of-scope/<concept>.md`. | `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` and `docs/superpowers/plans/YYYY-MM-DD-<feature>.md`. User preference overrides both. Scratch in `.superpowers/sdd/<plan-basename>/`. | Plan "under the agent store's `docs/`" unless the operator names a path. Trail at `decisions.tsv` or `.audit/<slug>.tsv`, uncommitted by default. Orchestration under `orchestrate/<slug>/` in the agent store. |
| Status metadata | ADR `Status` frontmatter (`proposed`, `accepted`, `deprecated`, `superseded by ADR-NNNN`) is optional. Local-tracker tickets carry a `Status:` line for triage and claim state. Other artifacts have none. | None in the templates. Plans carry checkboxes that executors do not tick. | None. `check-plan.mjs` skips frontmatter if present and never requires it. Trail rows carry a `result` cell. |
| Update | Glossary inline as terms resolve. The wayfinder map gains one context pointer per closed ticket. Silent on editing a spec or ADR after the fact. | Plan self-review fixes inline before handoff. During execution the spec is the authority and deviations go to the ledger, not the plan. Silent on editing a spec after approval. | Trail is append-only: a wrong row is superseded by a new row. Silent on plan edits after handoff. |
| Completion and archive | Tickets close. Prototype and research branches stay unmerged as primary sources. Removed skills' docs pages get an `> **Archived.**` banner (repo practice, not a skill instruction). | Delete the plan's scratch workspace when the final review is clean. Committed specs and plans are untouched. | Orchestrate store is left intact "as the postmortem". The guide says a committed multi-day plan should be deleted when the work lands. |
| Delete | `to-spec` docs page: delete unfinished tickets on a change of direction, keep the spec. Wayfinder deletes tickets the decision invalidates. Silent on ADR or research deletion. | `finishing-a-development-branch` asks before deleting uncommitted plans in a worktree. Silent otherwise. | Trail rows are never deleted. Plans as above. |
| Supersede | Only the optional ADR status value. | Silent. | Trail rows only. |
| Index and discovery | Wayfinder map as an index over closed tickets. `GLOSSARY-MAP.md` over contexts. Consumer skills read `GLOSSARY.md` and ADRs "in the area you're touching". Nothing loads old research. | None. A user request for `docs/superpowers/README.md` is open. | `session-pickup` treats the prior trail as authoritative. No doc index. |

Across all three, tooling enforces one thing about lifecycle: superpowers'
`sdd-workspace` script makes execution scratch per-plan and gitignored, and
the executor deletes it. pstack's `check-plan.mjs` lints plan structure and
prose, and its `log.sh` writes append-only rows. Every rule about committed
documents is prose instruction to the agent.

## Matt Pocock's skills

The pack treats each artifact type differently, so the detail is per type.

| Artifact | Created by | Lives in | Lifecycle rule |
| --- | --- | --- | --- |
| ADR | `domain-modeling`, `grill-with-docs` | `docs/adr/NNNN-slug.md`, created lazily | Offer only when all three gates hold. Status optional. |
| Glossary | same | Root `GLOSSARY.md`, or a `GLOSSARY-MAP.md` that points at per-context files | Updated inline, never batched. No implementation detail. |
| Spec (was PRD) | `to-spec` | Issue tracker; local tracker uses `.scratch/<feature>/spec.md` | Published with `ready-for-agent`. No post-implementation rule in the skill. |
| Tickets | `to-tickets`, `wayfinder` | Tracker or `.scratch/<feature>/issues/NN-slug.md` | Closed when resolved. `to-tickets` must not close the parent. |
| Research | `research` | "where the repo already keeps such notes" | None in the skill. |
| Prototype | `prototype` | Throwaway branch off main | Kept, never merged, linked from the issue. |
| Wayfinder research | `wayfinder` | `research/<name>` branch | Pushed, no PR, "never merged". |
| Rejected requests | `triage` | `.out-of-scope/<concept>.md` | One file per concept, kept as institutional memory. |
| Handoff, architecture report | `handoff`, `improve-codebase-architecture` | OS temp dir | Never in the repo. |

**ADRs.** `M:skills/engineering/domain-modeling/ADR-FORMAT.md` fixes the
location and numbering: "ADRs live in `docs/adr/` and use sequential
numbering", "Scan `docs/adr/` for the highest existing number and increment by
one." The template is a title and one to three sentences. Status is listed
under optional sections: "**Status** frontmatter (`proposed | accepted |
deprecated | superseded by ADR-NNNN`): useful when decisions are revisited."
That one optional field is the pack's whole supersession mechanism. The
creation bar is strict and lives in both `ADR-FORMAT.md` and
`domain-modeling/SKILL.md` ("Only offer to create an ADR when all three are
true"). The skill says nothing about editing an accepted ADR or when to retire
one.

Issue [#299][m299], open since 2026-06-02, describes the gap: `grill-with-docs`
writes ADRs during planning, downstream skills treat `docs/adr/` as in force,
and "there's currently no signal separating 'decided, not yet built' from 'in
force,' and no lifecycle that promotes or retires an ADR". Matt replied "This
makes sense to me" to a proposed `proposed`-to-`accepted` fix and later "Keeping
this open". It is unmerged at `49dd158`. Matt's own repo appends dated
`## Update, 2026-08-05` and `## Update, 2026-10-07` sections to
`M:.agents/adr/0002-ship-as-a-claude-code-plugin.md` rather than writing a
superseding ADR. That ADR has no status frontmatter.

**Glossary.** `domain-modeling/SKILL.md`: "When a term is resolved, update
`GLOSSARY.md` right there. Don't batch these up." `GLOSSARY-FORMAT.md`
creates the file "lazily when the first term is resolved". Terms are replaced
in place; the `_Avoid_` list records rejected synonyms. The skill has no
removal or deprecation rule. The human docs page
(`M:docs/engineering/domain-modeling.md`) concedes the glossary "can go stale"
and that "an unreviewed, agent-authored glossary is worse than none".

**Specs.** `to-spec` publishes a spec to the issue tracker with no file path.
Its template bans file paths and code snippets because "They may end up being
outdated very quickly", which is how the skill handles staleness: keep
volatile detail out. With the local-markdown tracker, the spec is
`.scratch/<feature-slug>/spec.md` and triage state is a `Status:` line
(`M:skills/engineering/setup-matt-pocock-skills/issue-tracker-local.md`). The
`to-spec` docs page records the PRD rename: "renamed in v1.1 ... the old
`to-prd` slug no longer works". It also gives the retention intent: "the
tickets are disposable and the spec is not. Each ticket ... gets deleted or
closed, while the spec stays as the one place that records the reasoning."
That sentence is on the docs page, not in `SKILL.md`. `code-review` looks for
the originating spec in the tracker or "a spec file under `docs/`, `specs/`,
or `.scratch/`".

**Research.** `M:skills/engineering/research/SKILL.md` has three steps; the
third is "Save it where the repo already keeps such notes; match the existing
convention, and if there is none, put it somewhere sensible and say where."
Nothing else covers naming, status, update, or removal. The docs page
(`M:docs/engineering/research.md`) goes further than the skill. It relays a
community answer, "ADRs yes. Everything else archive or delete after done",
and concludes "On balance, these files don't belong in git". It also states
"Nothing loads a past research file automatically." This file exists because
the installed `research` skill followed this repo's convention and wrote to
`docs/research/`.

**Prototypes and wayfinder research.** Rule 6 of
`M:skills/engineering/prototype/SKILL.md`: "commit it to a throwaway branch,
out of main, and leave a context pointer to that branch on the implementation
issue ... The main branch keeps only the validated decision." The history shows
a deliberate change from deleting to keeping: commit `d6274600` (2026-07-09)
"Retain the prototype as a primary source on a throwaway branch ... rather than
deleting it", and `371b9c9c` "capture the prototype, don't dispose of it".
Wayfinder applies the same pattern to research tickets: "capturing its
findings on a throwaway `research/<name>` branch with a context pointer from
the ticket. Push the branch but open no PR: it is never merged." The "open no
PR" clause landed after tag v1.3.1 via issue [#576][m576]. The research docs
page notes the cost: "deleting the branch later breaks the context pointers in
the tickets."

**Wayfinder map.** The map is an issue labelled `wayfinder:map`, described as
"an **index**, not a store". Resolving a ticket posts a resolution comment,
closes the issue, and appends a one-line pointer to Decisions-so-far.
Out-of-scope tickets are closed with one line in an Out of scope section. "If
the decision invalidates other parts of the map, update or delete those
tickets." This is the closest the pack comes to a full lifecycle, and it lives
in the tracker, not in files.

**Out-of-scope records.** `M:skills/engineering/triage/OUT-OF-SCOPE.md` keeps
one kebab-case file per rejected concept, with a "Prior requests" list that
grows as duplicates arrive. The reason "should be durable. Avoid referencing
temporary circumstances". It is silent on reversing a rejection.

**Repo practice for docs pages.** `M:.agents/writing-docs.md` governs the
maintainers' own human-facing pages. A removed skill keeps its page "as an
**archived** page: leave the body as it was and open it with a blockquote
notice (`> **Archived.** ...`) naming the version it was removed in and any
replacement, so the published URL keeps resolving." This is the only explicit
archive-and-supersede rule in the repo, and it applies to the maintainers'
pages, not to anything the skills produce in a user's repo.

## superpowers

**Create and locate.** Brainstorming sizes the work first: a quick task, a
small change described in chat, or "a project with a written design". Only
the third produces a file. `S:skills/brainstorming/SKILL.md` (lines 156-158):
"in a software repo, `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`,
committed. Otherwise, ask. Your human partner's preferences override both."
`S:skills/writing-plans/SKILL.md` (line 16): "Save plans to:
`docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md` (User preferences for
plan location override this default)". `writing-plans` does not tell the agent
to commit the plan file itself; its commit instructions are per task. The
plan header must name its spec ("**Spec:** [path to the spec/design doc this
plan implements]").

The paths have moved twice. v3.2.0 (2025-10-18) put designs in
`docs/plans/YYYY-MM-DD-<topic>-design.md` with a `-design.md` suffix "to
prevent filename collisions". v5.0.0 (2026-03-09) listed as a breaking change
"Specs and plans directory restructured" to `docs/superpowers/specs/` and
`docs/superpowers/plans/`, with migration left to the user: "move existing
files from `docs/plans/` to new locations if desired" (`S:RELEASE-NOTES.md`).

**Status.** Neither template has a status field. Plans use `- [ ]` steps "for
tracking". Issue [#1075][s1075] (open) reports that after execution "all
checkboxes remain `- [ ]`, with no indication that the work was completed".
A commenter counted 15 plans with 544 unchecked boxes and 5 checked on `dev`.
The maintainer response is draft PR [#2395][s2395], "Executors tick a completed
task's plan checkboxes (needs evals)", open against `dev` and not in v7.0.0.
The superpowers repo's own specs carry hand-written status lines in different
shapes, for example `Status: approved by Jesse (in-session); spec pending
review` and `**Status:** Design Complete, Awaiting Implementation`. At
v7.0.0 the repo holds 17 files in `docs/superpowers/plans/`, 22 in
`docs/superpowers/specs/`, and 4 legacy files in `docs/plans/`.

**Update.** `writing-plans` self-review: "If you find issues, fix them inline."
During execution the plan is read, not edited:
`S:skills/executing-plans/SKILL.md` says "the spec is the authority the plan
argues from, and conflicts inside the plan resolve against it", and every
deviation is a `Ruling:` line in the ledger. Neither skill says whether an
approved spec may change. Issue [#2522][s2522] (open) reports a plan that
edited its approved spec; issue [#2475][s2475] asks to document "if the specs
documents are settled or if the agents is allowed to modify them later".
Issue [#921][s921] (open) asks for a post-execution iteration workflow, and
the maintainer replied "I don't feel like I yet have a *good* handle on what
the superpowers version of this is."

**Completion.** The end-of-life rule covers scratch only. `executing-plans`
creates `.superpowers/sdd/<plan-basename>/progress.md` as a ledger and, at the
finish, says: "When the final review is clean and its fixes are committed,
delete this plan's workspace directory — the git history is the record now."
`S:skills/subagent-driven-development/scripts/sdd-workspace` enforces the
location: one gitignored directory per plan, keyed by a plan-path marker,
because "A stale ledger misread as current progress makes controllers skip
whole task sequences". The v6.2.0 release note says the old workspace "had
no plan identity and no end-of-life". The committed spec and plan get no completion step.
`finishing-a-development-branch` asks the user whether to commit, move, or
delete "uncommitted plans, notes, or scratch work" that block worktree removal.

**Archive and supersede.** The skills say nothing. Issue [#1547][s1547] asked
to ship `specs/done/` and `plans/done/` directories; Jesse Vincent closed it
with "/done is not part of superpowers. It doesn't make sense to create
directories for something that's a local convention."

**Discovery.** No index. Issue [#1690][s1690] (open) reports that the default
`docs/superpowers/` path published internal plans through Sphinx on Read the
Docs. Issue [#939][s939] reports brainstorming ignoring a CLAUDE.md output-path
table; Jesse's suggested fix is a README example of overriding the default.

## pstack

pstack has "no planning skill, on purpose" (`P:docs/guide/04-design.md`). Its
documents come from playbooks inside `poteto-mode` and from
`show-me-your-work`.

**Plans.** `P:skills/poteto-mode/playbooks/multi-phase-plan.md`: "When the
change is one or two files with an obvious approach, skip the plan." Step 4:
"Unless the operator names a path, write the file under the agent store's
`docs/`." The agent store is Cursor's per-agent directory whose "path [is] in
the system prompt" (`orchestrate.md`), so the default plan sits outside the
repo. The playbook fixes a long skeleton (program checklist, one section per
PR, appendices for prototype evidence, rejected alternatives, risks, links)
and requires `node pstack/skills/poteto-mode/scripts/check-plan.mjs
<plan.md>`. The script checks required headings, sub-blocks, verification
sentences, long dashes, curly quotes, and mid-sentence colons. It skips leading
frontmatter but never asks for any. Plan progress is boxes checked "only when
its evidence exists". The plan closes with "Every box above is checked with
its evidence" and a reply to the operator. Nothing says what happens to the
file afterward. The guide adds the only retention rule: "For a project that
spans many days, you can commit the plan to the repo for a while so other
agents see the work in progress. Delete it when the work lands."

**Decision trail.** `P:skills/show-me-your-work/SKILL.md` keeps one TSV with
columns `ts`, `phase`, `decision`, `why`, `evidence`, `result`. "By default the
log is a working artifact, not committed. Keep it at `decisions.tsv` in the
work dir, or `.audit/<task-slug>.tsv` when several efforts run at once, and
leave it out of git. Commit it only when the work is ambitious enough that a
reviewer needs the trail to trust the result." Its rules hold the pack's only
supersession mechanism: "Append-only. A wrong call gets a new row that
supersedes it. Never edit or delete history." The end-of-run audit follows the
same rule: "Correct the log, not the story." `session-pickup.md` makes the
prior trail "authoritative input".

**Orchestration store.** `orchestrate.md` creates `orchestrate/<project-slug>/`
in the agent store, with one writer per file, and at close says "Leave the
store intact. It is the postmortem."

**Other outputs.** `prototype.md` builds in "an isolated scratch dir" and the
reply must "Say plainly that the prototype is throwaway". It does not say
where the scratch dir lives or when to remove it. `investigation.md` is
read-only and its output is the reply. `pause-safely.md` writes a resume note
to `/tmp/<slug>-resume.md`. `architect` says the rationale "ships alongside"
the type sketch per `references/rationale-template.md`, with no path.
`maintain-verification-skill` keeps run notes "in a scratch location; don't
commit them". pstack reads ADRs as evidence in `why`
(`references/sources/code-archaeology.md`) but has no skill that writes one.
`technical-writing` sets prose standards for docs and RFCs and is silent on
lifecycle.

## Against this repo's lifecycle

This repo's [document lifecycle](../document-lifecycle.md) covers the stages
the three packs leave blank:

- A required `status` with eight canonical states, a transition graph, and
  per-type allowed states. Matt has an optional four-value ADR field; the
  other two have none.
- `superseded_by` and `current_guidance` routing, a `closed` date, and a body
  lock on closed docs. None of the packs has an equivalent for committed docs.
  pstack's append-only trail is the nearest analog, at row level.
- A maintained `docs/index.md` and a validator that checks frontmatter,
  links, and transitions. None of the packs ships a doc index or a doc
  validator. pstack's `check-plan.mjs` validates shape only.
- Explicit rules for closing plans and moving durable content into references
  or runbooks before closure. Only pstack's guide says anything about finished
  plans, and it says delete.

The packs do things this repo does not:

- Keep work artifacts out of the main tree. Matt uses the issue tracker for
  specs and tickets and unmerged branches for prototypes and research.
  pstack's default is the agent store and gitignored local files.
  Superpowers does this only for execution scratch. The
  [maintenance review](documentation-maintenance-review.md) lists Matt among
  the "keep outside the repo" camp; this survey supports that for specs and
  prototypes, but Matt's `research` skill itself still writes into the repo.
- Delete scratch automatically at completion (superpowers `sdd-workspace`
  plus the executor's finish step), and say to delete a landed plan (pstack
  guide).
- Gate creation harder. Matt's three-test ADR bar and the "skip the plan"
  thresholds in superpowers and pstack decide whether a document is written
  at all. This repo's trigger is "non-trivial initiative" for plans and
  "architectural decision" for ADRs.
- Keep volatile detail out of durable docs. `to-spec` forbids file paths and
  code snippets for that reason.

Shared conventions and shared weak spots:

- ADR naming matches Matt's (`NNNN-slug.md`, next number by scanning). The
  scan-and-increment rule has no collision check in either place. The
  maintenance review found ADR 0049 used twice here.
- Dated filenames are a superpowers convention only. This repo's plans use
  `<slug>-plan.md`, and Matt's local tracker uses a feature slug.
- The open issues listed above (#299, #1075 with draft #2395, #1547, #2522,
  #921, #1690) show users of each pack hitting the stages this repo's policy
  defines: planned decisions read as in force, finished plans that look
  unfinished, and no closed-work convention. The maintenance review's
  counter-evidence still applies: this repo's transition graph has rejected
  nothing in about 120 runs, and closed docs are read for guidance anyway.
  The packs show the gap is real. They do not show that this repo's machinery
  is the right fix for it.

One factual correction for the maintenance review: it says superpowers
"leaves four dated plans in `docs/plans/`". That counts only the legacy
directory. At v7.0.0 the repo also holds 17 plans and 22 specs under
`docs/superpowers/`, none with lifecycle metadata.

## Gaps

- pstack's "agent store" is defined only as a path given in the system
  prompt. This survey did not inspect a Cursor session to confirm where that
  is or whether it persists across sessions.
- The pstack `architect` rationale and `prototype` scratch dir have no stated
  location. Their lifecycle could not be determined from the skill text.
- Superpowers issue [#2473][s2473] (commit spec and plan by path) was seen
  only by title.
- The Matt research docs page cites Discord threads and an issue (#530) that
  were not read. Its retention view is relayed as the docs page states it,
  not verified against those threads.

## Source links

Pinned roots:
`M:` = <https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/>,
`S:` = <https://github.com/obra/superpowers/blob/bb92a77741419a4ab5f06e711a283343f1ada0c3/>,
`P:` = <https://github.com/cursor/plugins/blob/99743e9c151c8537cbbf1f98bb38f34ef3368453/pstack/>.

Matt Pocock commits: [d6274600][mc1], [371b9c9c][mc2], [0d74d01c][mc3]
(research skill added).

[m299]: https://github.com/mattpocock/skills/issues/299
[m576]: https://github.com/mattpocock/skills/issues/576
[mc1]: https://github.com/mattpocock/skills/commit/d6274600ab43
[mc2]: https://github.com/mattpocock/skills/commit/371b9c9c9431
[mc3]: https://github.com/mattpocock/skills/commit/0d74d01cbc64
[s921]: https://github.com/obra/superpowers/issues/921
[s939]: https://github.com/obra/superpowers/issues/939
[s1075]: https://github.com/obra/superpowers/issues/1075
[s1547]: https://github.com/obra/superpowers/issues/1547
[s1690]: https://github.com/obra/superpowers/issues/1690
[s2395]: https://github.com/obra/superpowers/pull/2395
[s2473]: https://github.com/obra/superpowers/issues/2473
[s2475]: https://github.com/obra/superpowers/issues/2475
[s2522]: https://github.com/obra/superpowers/issues/2522
