---
status: active
doc_type: research
summary: "Per-class retention verdicts from the corpus inventory, agentsview read and cost forensics, policy compliance audit, and a practitioner and GitHub-corpus survey."
owner: Prateek
created: 2026-10-17
updated: 2026-10-17
related:
  - ../document-lifecycle.md
  - ../index.md
  - ../plans/docs-reorg-plan.md
  - ../plans/periodic-session-review-plan.md
  - ../../home/dot_agents/docs/agentsview.md
  - ./skill-pack-doc-lifecycles.md
  - ../adr/0052-retire-closed-docs-through-a-ledger.md
status_detail: "Evidence behind ADR 0052, which adopted its recommendations; the sweep that applies them lands separately. Merges a Codex corpus-and-policy pass with a Claude pass that measured reads, maintenance cost, policy compliance, practitioner sources, and the GitHub corpus. Repeat the agentsview queries before acting on a number older than a quarter."
---

# Documentation maintenance and retention review

The repo keeps too many process documents in its working tree, and the
lifecycle machinery costs more than it returns. The evidence below supports a
different verdict for each class of document, so the recommendation is
per-class rather than a single retention rule:

| Class | Verdict | Load-bearing evidence |
| --- | --- | --- |
| ADRs (51) | Keep in tree, immutable, superseded with links. Add a number-uniqueness check. | Every precedent and every ADR skill with adoption says keep and supersede. ADR 0049 exists twice. ADR 0024 landed a 175-line body rewrite after acceptance despite the lock. |
| Plans (67, 47% of words) | Close on completion and let the file leave the tree once its durable content has a home. Stop treating the index row as the changelog. | 19 of 24 open plans say they are implemented. Post-reorg, archived plans were read for guidance in more sessions than active plans (101 vs 64). 56% of reads of a closed doc never reach its pointer target. |
| Research (24, 28% of words) | Move snapshots out of the product tree, or delete after reconciling findings into maintained docs. | 9 of 24 never read for guidance; 2.0 guidance sessions per doc, the lowest of any type. Practitioners who retain research at scale do it in a separate repo. |
| Runbooks and references (20) | Keep; they return the most per word. Dedupe the two reference-to-skill text copies. | 11.3 and 7.4 guidance sessions per doc. `acpx-routing` and `chezmoi-architecture` each share about 30 eight-word sequences with a skill. |
| `docs/index.md` | Shrink to a short router over current guidance and open work. Generate everything else from frontmatter. | 3.9k words; read first in 7.6% of doc-reading sessions; present in 57% of docs commits; the top validator failure; about 2M tokens of read traffic. Hand-written routers in the surveyed corpus top out near 750 words. |
| Lifecycle policy and validator | Keep the shape, link, and body-lock checks. Lift the deletion lock on closed non-ADR docs and consider reducing the eight-state transition graph. | The transition graph has rejected nothing in about 120 eligible runs. `document-lifecycle.md` is the most-read doc in the tree (115 sessions): every doc-writing session pays to learn rules that never bite. |

These are recommendations, not adopted policy. This review changes only this
report and its index entry. It is itself the 165th document under `docs/`.

## Scope and confidence

The inventory covers every tracked Markdown file at baseline commit
`24852fd3`, including files outside `docs/`. Session evidence comes from the
local AgentsView store (16,773 sessions, April 2025 to 17 October 2026) opened
read-only with `immutable=1`; the queries, scratch databases, classifier
scripts, and per-doc tables sit in gitignored `build/doc-policy-review/` beside
the earlier Codex evidence in `build/doc-policy-audit/`,
`build/doc-policy-research/`, and `build/session-impact-review/`. Nothing here
quotes a transcript; session identifiers are omitted.

Two independent passes produced this document. A Codex pass did the corpus
inventory, read the policy and validator, examined six qualitative session
cases, and surveyed external policy. A Claude pass with five background agents
then measured doc reads, maintenance cost, policy compliance, practitioner
primary sources, and the GitHub corpus. Where their numbers differ, both are
given with the reason. Word counts are whitespace tokens including code and
metadata, not model tokens. Token estimates use 1.3 tokens per word against
current file sizes and are ceilings, since 49% of guidance reads are partial.

The dotfiles session filter matters. Matching only `project LIKE '%dotfiles%'`
finds 1,881 sessions and 38% of doc reads; worktree sessions carry the branch
name as their project. Both agentsview passes matched on project, working
directory, or input path instead (3,378 to 3,717 sessions, 1,360 to 1,364
top-level roots). Subagent sessions roll up to their root. External claims
come from authors' own pages, repos, or posts, each fetched during the review;
unfetchable sources are named as such. There is no defensible global ranking of
the "most influential" documentation practitioners; the sources were chosen for
direct relevance and identifiable reach.

## What is present

| Surface | Markdown files | Words |
| --- | ---: | ---: |
| Vendored APM inputs | 1,767 | 1,658,932 |
| Marketplace authored or adapted content | 231 | 120,572 |
| `docs/` | 164 | 260,313 |
| Repo agent surface, `.agents/` | 31 | 19,332 |
| Machine agent surface, `home/dot_agents/` | 19 | 9,850 |
| Test, root, and home guides | 17 | 11,870 |
| Total | 2,229 | 2,080,869 |

About 80% of Markdown words are vendored dependencies whose committed bytes
support offline builds and portable publication. Pruning their README or
reference files as documentation cleanup would violate that contract; review
unused dependencies through package selection. See the
[marketplace build contract](../../agent-marketplace/README.md) and the
[management skill](../../.agents/skills/agent-skill-management/SKILL.md).

The owned `docs/` tree:

| Type | Files | Body words | Share of words |
| --- | ---: | ---: | ---: |
| Plans | 67 | 120,371 | 47% |
| Research | 24 | 72,351 | 28% |
| ADRs | 51 | 32,451 | 13% |
| Runbooks | 12 | 14,023 | 6% |
| References | 8 | 9,864 | 4% |
| Index | 1 | 3,920 | 2% |
| Lifecycle policy | 1 | 1,329 | 1% |

Status totals: 44 `active`, 43 `accepted` (40 ADRs and three plans), 32
`archived`, 17 `superseded`, 14 `current`, eight `draft`, six `proposed`. The
49 closed documents hold 73,605 words, 28% of the tree.

Growth is recent and steep: four documents on 1 April, 36 on 1 July, 132 on 1
October, 164 now. Net growth per quarter was +32, +96, +32. Across history 167
paths were added and three were genuinely deleted (`devtools.md`,
`iterm2-tmux.md`, `worktrees.md`, all moved to `home/dot_agents/docs/` in
April and May); the other apparent deletions are the May reorganization's
renames and its one-day revert. Nothing has left `docs/` since May. Closure is
the only exit, and 30% of documents have taken it.

The tree clusters by subject. The agent marketplace and APM cluster alone is
29 documents and 54.8k words (nine ADRs, eight plans, eleven research docs, one
reference) plus four skills. Chezmoi architecture is 13 documents and 22.1k
words plus a 12k-word skill; shell and tests 7 and 17.4k; keyboard hardware 9
and 16.9k; TCC and permissions 9 and 16.3k; acpx 16 and 14.2k. Text is copied
between layers: ADR 0012 and the config-gating plan share 29 eight-word
sequences, ADR 0001 and the fork setup plan 28, ADR 0006 and the chezmoi
migration plan 25; `references/acpx-routing.md` shares 30 with the acpx skill
and `references/chezmoi-architecture.md` 29 with the chezmoi-management skill.
Fourteen of 20 references and runbooks have no skill covering the same job;
`runbooks/tcc-onboarding.md` is the largest of those.

## What the policies encourage

### Creation has clear triggers; deletion has no exit

[Root guidance](../../AGENTS.md) requires plans for nontrivial initiatives,
ADRs for architectural decisions, reciprocal links, retained research
findings, and index maintenance. The `mattpocock:research` skill additionally
requires a saved Markdown findings file. Those are delivery contracts; none
supplies a retention criterion.

[Document Lifecycle](../document-lifecycle.md) says to archive documents that
are no longer useful as guidance. The executable policy then protects every
closed document, of any type, and every accepted ADR from deletion:
`body_locked` in the [validator](../validate-doc-lifecycle.py) covers
`archived`, `superseded`, `rejected`, and accepted ADRs, and
`validate_commit_against_parent` raises `locked historical doc cannot be
deleted` for any of them.
`test_accepted_and_archived_documents_cannot_be_deleted_or_edited` in
[the tests](../../tests/python/docs/test_locked_docs.py) pins that contract.
The validator also requires a direct index entry for every document, closed
ones included, so archival preserves both the file and a permanent routing
obligation. This has been intentional, tested behavior since the first
validator commit on 18 May; the [reorganization plan](../plans/docs-reorg-plan.md)
preserved existing enforcement and recorded an archaeology motive, but no case
for retaining every closed plan and research report forever.

Two other instruction surfaces already say the opposite.
[Engineering conventions](../../home/dot_agents/docs/engineering.md) say to
remove obsolete guidance and leave no migration breadcrumbs; the
[durable-docs workflow](../../agent-marketplace/packages/core/skills/code-gardening/references/durable-docs.md)
asks for completed migration notes to be removed and for each rule to have one
authoritative home. The three surfaces need one shared retirement boundary.

### Structural correctness is not authority

The baseline passes `just test-docs-lifecycle` for all 164 documents. The
validator checks shape, transitions, links, and locks. It does not check
whether work remains, whether dates are true, or whether a number is unique.
The compliance audit found the gaps it leaves:

- Plans are being used as changelogs. 19 of the 24 `active` or `accepted`
  plans describe themselves as implemented, landed, or applied in their index
  row. Three name nothing left to do
  ([acpx packaging](../plans/acpx-skill-packaging-plan.md),
  [justfile migration](../plans/justfile-migration-plan.md),
  [wiki ingest revisit](../plans/wiki-ingest-revisit-plan.md)); sixteen stay
  open on an attended or pending check. The policy's "move durable guidance out
  before closure" step never triggers because nobody closes them.
- Closed-document discipline is good. Of 49 closed documents, none has had its
  body refreshed for current behavior since the validator landed. The only
  post-closure body commits are two inline link-path repairs on the test-suite
  rebuild plan, forced before the closed-doc link exemption existed, and two
  reorganization re-adds. Eleven `closed:` dates disagree with the closing
  commit, ten of them by one to four days.
- Accepted ADRs are less clean. ADR 0024 was rewritten (175 body lines) two
  commits after acceptance on 7 September. Both that day's validator and
  today's report the locked-body error on that range, and CI ran the lane for
  pushes and pull requests, so the branch landed with the check skipped or red.
  Four earlier ADRs were edited after acceptance before the validator existed.
- ADR 0049 exists twice. Two same-day branches each took the next number and
  were rebased into linear history; 0050 is taken; the validator reads the
  numeric prefix only for rename identity. One bare "ADR 0049" citation in the
  skills-repo-split plan is ambiguous.
- Recommended frontmatter is thin: `owner` is missing on 47 documents (29%),
  `updated` on 24 (18 of them ADRs), `created` on six. Two documents took body
  edits without bumping `updated`.
- The index has drifted from its own rules: 20 of 162 status cells exceed 25
  words (maximum 60), a one-topic `## Package Helper` heading and loose
  bullets above the Research table bypass the tables, and two documents have
  no row of their own.
- Seventeen research documents are `active` or `current` (56.9k words); three
  are cited by nothing open, and only two say when to re-run them. The
  [agent skill management research](agent-skill-management-research.md),
  marked `current`, still describes the retired vendor-source layout and
  generated `~/.agents/skills` output.

Eight lifecycle states and historical-body enforcement are more machinery than
most document changes need. Section "What sessions show" measures what that
machinery has caught.

## What sessions show

### Reads: who opens `docs/`, and which documents

Across the store, 5,483 tool calls read a `docs/` file in 340 top-level
sessions. Reads split into authoring (the session also edited that document)
and guidance (it did not). Guidance is the number that measures value: 1,947
calls in 308 sessions. The share of top-level dotfiles sessions that read any
document for guidance fell from 32% before the May reorganization to 22%
after it.

| Measure | Value |
| --- | ---: |
| Documents with at least one guidance read ever | 138 of 164 |
| Documents never read for guidance | 34 (45k words, 17% of the tree) |
| Documents with no read of any kind in the last 90 days | 34, of which 16 carry a live status |
| Guidance sessions per document, by type | reference 11.3, runbook 7.4, ADR 4.5, plan 3.9, research 2.0 |
| Guidance sessions per document, by status at HEAD | current 24.9, archived 4.9, accepted 4.8, superseded 3.7, active 2.6, proposed 1.2, draft 0.6 |
| Post-reorg guidance sessions, archived plans vs active plans | 101 (28 docs) vs 64 (21 docs) |
| Post-reorg guidance doc-session pairs landing on closed documents | 176 of 810 (22%) |
| Post-reorg guidance sessions that touched an archived document | 33% |
| Stale document read without its pointer target in the same session | 91% before, 56% after |
| Machine conventions `~/.agents/docs/*.md` reads, for comparison | 573 sessions (`git.md` alone 359) |
| Readers | Claude 138 sessions, Codex 130 (53% of its calls from subagents), Cursor 40 |

The never-read set is not what the policy would predict. Ten of the 34 are
ADRs from ADR 0021 onward (eight accepted, one archived, one superseded),
thirteen are plans (nine live, four closed), nine are research documents, and
`runbooks/tcc-onboarding.md` and `runbooks/g95nc-display.md` are both current
operating guidance nobody has opened. Of the 34 documents unread in 90 days,
the TCC and permissions cluster contributes six.

Closed documents are read as if they were live. ADR 0011 was read in eleven
sessions; its successor ADR 0039 was read in none of them. ADR 0016: six
sessions, successor ADR 0028 never. The archived chezmoi migration plan, at
9,000 words the second-largest document in the tree, was read for guidance in
33 sessions, eight of which also reached `chezmoi-architecture.md`; it is the
sixth most-read document overall and still the costliest, at a ceiling of 1.35M
context tokens and a floor of 386k. The archived test-suite rebuild plan was
read in eleven sessions with its `current_guidance` target reached in none. The
reorganization's pointers did help: the target-read rate rose from 9% to 44%.
In the other 56% of cases the agent read only the stale document.

Reproducing the reorganization plan's own forensics: the chezmoi migration
plan before 12 May was read in 31 top-level sessions (121 counting subagents
separately), against the 44 the plan reported from a 423-session sample. The
gap is consistent with the earlier pass counting subagent sessions and
`git diff` output as reads. The ranking matches.

### The index is not a router

`docs/index.md` did not exist before 12 May. Since then, 276 sessions read a
document under `docs/`; 21 of them (7.6%) opened the index first, and 44%
opened it at all. The most common first read is `document-lifecycle.md` (42
sessions), followed by the index (21), ADR 0012 (15), and
`chezmoi-architecture.md` (13). Agents go straight to a specific document
92% of the time, and the policy document is the de facto entry point, which
says that most doc-reading sessions are about to write a document rather than
follow one. The lifecycle convention is the single most-read file in the tree
at 115 guidance sessions and 279 calls.

Reading the index costs more than writing it. Writing: 200 edits in 40 root
sessions, about 300k output tokens over the whole history. Reading: 798 reads
in 315 sessions returning about 8 MB, roughly 2M context tokens. (The reads
pass counts only guidance reads and reports 146 calls in 69 sessions; the
cost pass counts every read including authoring and shell `sed -n` slices.)

### Maintenance cost

| Measure | Value |
| --- | ---: |
| Root sessions that edited `docs/` | 109 of 1,364 (15% of interactive roots; 44% of roots that edited anything) |
| Docs edit tool calls | 1,936 |
| Index-only sessions, and index-only commits of 90 | 0 and 0 |
| Frontmatter-only edits outside the May reorganization | about 10% of edit calls; no session was purely bookkeeping |
| Doc-heavy sessions (over half of edits under `docs/`) | 38; median 172 tool calls and about $16 |
| Estimated spend attributable to docs edits | about $3.0k of about $14.5k priced dotfiles spend (21%) |
| Commits since January touching `docs/` | 159 of 493 (32%); 90 of those touch the index |
| Markdown lines under `docs/` since January | 37.7k added, 5.3k removed |

The reads pass counts 146 editing sessions where the cost pass counts 109;
the reads pass accepts more path spellings and does not drop edits made from a
non-dotfiles working directory. Treat 110 to 150 as the range.

### The validator: what it catches and who runs it

Since it landed on 11 May the validator has run 241 times outside sandboxes,
in 44 root sessions; three sessions account for 135 runs. After 12 May, 47% of
docs-editing root sessions ran it (Claude 52%, Codex 25%). A looser count that
accepts any mention of the validator in a tool call gives 77%; that figure
includes reading or grepping the script and is a ceiling. The reorganization
plan's "100% skipped" has become roughly half skipped, with Codex sessions
skipping three times in four.

Of 41 failures, 16 were a missing index entry, nine the closed-body lock, six
a missing link target, one a missing field, one a status rule, and the rest
timeouts, environment, or unclassified. `invalid status transition`: zero,
across about 120 runs that compared against a base and could have raised one.
The eight-state transition graph has never rejected anything. The index-sync
rule, the closure lock, and link checks are the rules that bite, and the lock
produced the one real policy contradiction found in conversation text: closed
documents could not be edited yet their links had to resolve, fixed on 8
September by exempting closed-doc links.

Conversation-level friction is low. Of 306 root sessions that mention
lifecycle-specific terms, a hand-categorized random sample of 30 held one
validator complaint (the contradiction above), zero agents asking which status
to use, zero user corrections of document placement, three index-update
chores, and 15 routine mentions. Targeted searches for status questions and
placement corrections returned only audit-template noise. The friction is not
in the conversation; it is in the reads of stale documents and in the index.

### Six qualitative cases from the Codex pass

| When | Observed behavior | Defensible implication |
| --- | --- | --- |
| July | Retiring a Tart host led to repeated validator inspection; accepted ADR bodies stayed frozen and corrections went into metadata. | Volatile operating facts inside immutable decisions create maintenance friction. |
| August | The user questioned the acpx doc-and-skill split; a later decision documented that neither route reached the other's guidance. | Distinct content needs a working discovery path to justify a separate surface. |
| October | New NocFree findings landed in a separate document while the earlier report was left out of scope. | Research needs an owner for reconciling findings into existing guidance. |
| September | A browser plan preserved unfinished cleanup and follow-ups for a requested handoff. | Keep genuine outstanding work even when the implementation has landed. |
| September | A suspected obsolete crit reference turned out to document a surviving experiment selector. | Age and old tool names alone do not justify deletion. |
| September | A fresh reviewer used a testing plan's failure-recovery guarantee to report missing diagnostics. | Plans can supply independent acceptance contracts. |

Current files corroborate these: ADR 0004 carries a metadata correction for
historical host facts; ADR 0028 records the acpx discovery problem; the NocFree
firmware and community reports show cumulative evidence with split integration.

## How others handle the same tradeoffs

### Vendor guidance

Every vendor cost figure is about auto-loaded files, not archives. Anthropic
targets under 200 lines per `CLAUDE.md`, says imported files cost the same as
inline, warns that bloated files make the model ignore instructions, and
defaults plan-mode plans to `~/.claude/plans/` outside the repo. OpenAI caps
combined `AGENTS.md` content at 32 KiB and documents ExecPlans as living
documents that end with a retrospective, with no retention rule. Cursor keeps
rules under 500 lines and saves plans to the home directory by default. A plan
sitting in `docs/plans/` costs nothing until an agent reads it, so the vendor
material argues for a small router and skills, not directly for deleting
archives. Sources: Anthropic best practices, memory, and context-window pages;
OpenAI AGENTS.md guide, best practices, and ExecPlans cookbook; Cursor rules
and planning docs.

### Practitioner camps

| Camp | Who | Stated or observed practice |
| --- | --- | --- |
| Keep forever with status | Nygard ADRs, MADR, PEP 1, Rust RFCs, Kubernetes KEPs, Addy Osmani's ADR skill (57k installs), Vercel AI, react-router, Dapr, NATS, Sentry RFCs | Multi-contributor governance records. PEP 1: a resolved PEP is "a historical document rather than a living specification". Nygard's rationale is newcomers blindly reversing decisions. SWE at Google archives design docs in team documents, outside the code tree. |
| Delete when done; git is the archive | Geoffrey Huntley's Ralph loop, Chromium docs guidance ("default to delete"), Shape Up ("let it go"), sst/opencode, mwmbl, openmeld (linter-enforced), Every's compound-engineering (no `_archived/`) | Huntley removes finished items and has "deleted the TODO list multiple times". A GitLab work item on exactly this question chose "delete the spec and its plans, keep git history as the archive" after agents read finished specs as current and opened MRs to fix them. Write the Docs is the counterweight: git works "though it can take some archaeological work to follow the trail when files get moved". |
| Keep outside the repo | HumanLayer (`thoughts/` in a separate synced repo; a pre-commit hook blocks it from the code repo), Simon Willison (notes in GitHub issues; AI research quarantined in `simonw/research`), Matt Pocock (specs and tickets in the tracker, prototypes and wayfinder research on unmerged branches; his `research` skill still writes into the repo), Steve Yegge's Beads (closed tasks summarized away), Sentry (`.claude/plans` gitignored), rundeck | The largest camp among agent-first practitioners. Matches this repo's existing out-of-tree surfaces: the session archive and `~/.agents`. |
| Tiny instruction file, current-state docs only | Mitchell Hashimoto (Ghostty `AGENTS.md` is 1.4 KB, "each line based on a bad agent behavior", no docs dir), Armin Ronacher, Thorsten Ball, Pocock's AGENTS.md guide, Osmani's 150-line cap | Every vendor page converges here for the router and references. Ronacher: an obsolete decision keeps an agent on an obsolete pattern. Osmani: "Stale instructions are worse than no instructions". |

Stated versus observed: Kent Beck's BPlusTree3 leaves two plan files, two
analysis files, and one ADR in tree; Jesse Vincent's superpowers repo holds
17 plans and 22 specs under `docs/superpowers/` at v7.0.0 plus four legacy
plans in `docs/plans/`. Neither has status metadata or a policy. The
[skill-pack lifecycle survey](skill-pack-doc-lifecycles.md) reads the Pocock,
superpowers, and pstack skill text at pinned commits: all three say when to
create a document and none gives a committed one a status, an index, or a
closing rule, and each has open issues where users hit that gap.
That unstated practice is the nearest match to this repo's current state,
minus the machinery. No fetched source advocates retaining finished plans in
tree. Harper Reed, Osmani, and OpenAI keep spec or plan files in tree as living
documents for in-progress work, not as a finished-work archive. Boris Cherny's
X posts were reachable only as search snippets; Huntley's specs posts and Kent
Beck's newsletter are paywalled; Yegge's Medium returned 403.

Controlled evidence is mixed. The September revision of "Evaluating AGENTS.md"
found no statistically significant task-success improvement from context files
and a 20 to 23% cost increase from generated ones, with file length alone
showing no strong effect. A JAWS study of 124 PRs found lower median runtime
and output tokens with `AGENTS.md` under a sanity-check correctness assessment.
Both concern auto-loaded instruction files; neither measured on-disk archives.
No source quantifies agent error rates against archive size. The evidence that
stale on-disk documents mislead agents is direct but thin: the GitLab work
item, Ronacher, Osmani, and HumanLayer ranking "incorrect information" as the
worst context failure.

### GitHub corpus

From 1,622 enriched repositories (116 above 500 stars) plus a notable set
surveyed directly:

| Policy for finished plans, proposals, and ADRs | Repos | Examples |
| --- | ---: | --- |
| Keep in place, flip a status field | 21 | PEPs, KEPs, NATS, Sentry RFCs, react-router, Vercel AI, Dapr, spec-kitty ADRs |
| Keep in place, no status field (merged means accepted) | 9 | Rust RFCs, Go proposals, Flux, Prometheus, OTEPs |
| Archive directory | 5 | spec-kitty (196 archived plans vs 69 active, CI-gated inventory), leanspec, PRPs-agentic-eng, OpenProject (policy only) |
| Delete on completion; git is the archive | 3 | openmeld (linter), mwmbl (closing PR deletes the plan), opencode |
| Out-of-tree plans | 5 | Sentry, HumanLayer and 24 `thoughts/shared/plans` adopters, rundeck, steipete/agent-scripts |
| Plans committed but never closed out | 6 | superpowers, motor-os, claude-task-master research |
| No plan or ADR docs in the main repo | 25+ | workers-sdk, Quickwit, Tailscale, Ghostty, Deno, Bun, Supabase, Grafana, next.js, claude-code, codex, uv |

Keeping finished documents in place with a status flip is the majority
policy, so this repo's statuses are mainstream. The repositories that cap
growth do it by deleting transient plans when work ships or keeping them out
of the code repo. The big agent-heavy product repositories commit agent skills
but not agent plans; PostHog's `AGENTS.md` forbids new `docs/**` files without
a human request.

Index sizes: hand-written routers run 250 to 750 words (opencode about 250,
Dapr 348, spec-kitty 687 over 892 documents). Process documents that double as
indexes run 440 to 2,400 words. Everything larger that stays accurate is
generated from frontmatter (NATS, PEP 0, the KEP cross-index, spec-kitty's era
tables) and diffed in CI. A hand-maintained 3.9k-word index is outside the
observed range.

Validators found: `check-peps.py`, KEP `verify-kep-metadata.sh`, NATS
regenerate-and-diff, openmeld `verify-docs-lifecycle.mjs` (status plus an
explicit removal condition; delete in the completing PR), chromedp's
`go test ./docs/` index-row completeness, spec-kitty's
`freshen_adr_inventory --check`, and the leanspec CLI. adr-tools, log4brains,
and the MADR template exist in hundreds of repositories but none of the
notable set uses them.

Skills: no published skill with meaningful adoption handles plan lifecycle
end to end. The exact matches are dzhng `close-spec` (266 installs: move to
`specs/done/`, rewrite the plan into a rationale record, fix inbound links,
audit claims against the code) and openmeld `docs-lifecycle-scan` (a thin
router to its linter). ADR skills with adoption (ecc 9.9k installs, Osmani 57k,
Anthropic 6.6k) all say immutable, supersede, never delete. Peter Steinberger's
`docs-list.ts` excludes `archive` and `research` from default discovery and
emits `read_when` hints, and his agent guidance makes plan creation
explicit-request-only. Dotfiles peers (ten surveyed, all under 100 stars) keep
ADRs in place; one has `docs/plans/`; none validates; this repo is an order of
magnitude larger than any of them.

## Recommended policy

Use the existing folders. Change admission, retirement, and discovery before
adding taxonomy or metadata.

| Document class | Admission and maintenance | Retirement |
| --- | --- | --- |
| Current guide, runbook, or skill | Named reader and task; one authoritative home; update with the behavior it describes. | Merge or delete obsolete guidance and repair live callers. Temporary redirects only for a real compatibility need. |
| ADR | A consequential decision whose constraints or alternatives would be costly to rediscover; keep it short. | Keep; mark supersession with a link; never renumber. Volatile commands and hosts belong in maintained guides, with conspicuous corrections in metadata. |
| Working plan | Cross-session coordination, reviewable acceptance criteria, or unresolved delivery gates require persistence beyond the task. | Close when the work ships. Move remaining work to its live owner, extract reusable contracts into a reference, runbook, or ADR, then let the file leave the tree unless it has a named continuing use. |
| Research | A requested deliverable or evidence needed for a real decision, with a stated consumer. | Reconcile corrections into maintained docs, preserve necessary citations, then delete or move the snapshot out of the product tree. |
| Logs, experiments, session narration | Ignored scratch or the session archive. | Remove when the question is resolved; promote only independently useful findings. |
| Vendor and reference payloads | Package acquisition and publication contract, including licensing. | Remove through package selection and its validation, not prose cleanup. |

Git history recovers deleted tracked prose while reachable history remains.
Do not rewrite history as part of routine retirement. If a document's unique
evidence lives only in an expiring external service or an untracked session,
preserve a public-safe record before deleting.

### Concrete policy edits

Replace the blanket nontrivial-initiative plan requirement in `AGENTS.md`
with:

> Write a persistent plan when work needs cross-session coordination,
> reviewable acceptance criteria, or unresolved delivery gates. Otherwise keep
> the plan in the task or PR. Record consequential architectural decisions
> separately when their rationale would be costly to recover.

Add a retirement rule to `docs/document-lifecycle.md`:

> Completed plans and superseded research leave the working tree once their
> reusable guidance and evidence have a durable home, remaining work has an
> owner, and live links are repaired. Retain a historical document only for a
> named continuing use. Git preserves prior tracked wording.

Change the validator with the policy. Allow deliberate deletion of closed
non-ADR documents, keeping live-link checks and the ADR history safeguards.
That revises the no-delete tests because the contract changes; do not weaken
the tests under the existing contract. Decide any ADR-retirement exception
separately. Add ADR number uniqueness. Consider dropping the eight-state
transition graph to the states that carry meaning (`draft`, `active`,
`current`, `accepted`, `superseded`, `archived`) since the graph has rejected
nothing; keep the accepted-ADR body lock, which has caught real edits, and
make CI's failure on it visible enough that ADR 0024's landing cannot repeat.

Make `docs/index.md` a short router to current guidance and open work, in
the 500 to 800 word range the corpus shows hand-written routers can sustain.
Keep decisions and history discoverable through a generated inventory built
from frontmatter by the validator script and diffed in CI, so no hand-written
row is needed for a closed file. Default discovery should expose status and
prefer current guidance; explicit archaeology should still reach history.
Moving files alone does not reduce loaded context unless the reader and
search mechanism change too, so pair any move with the index change.

For research, add a consolidation step: when new evidence qualifies an
existing claim, update the maintained answer or create a visible
reconciliation item. Do not leave two `active` documents competing through an
accidental scope gap. Mark every retained research document with a `read_when`
or re-run condition in `status_detail`; 15 of 17 live ones lack it.

Use completion, replacement, and discovered inaccuracy as review triggers. A
periodic review can surface abandoned work, but an age threshold should
prompt a decision, not an automatic deletion. No evidence here establishes a
retention schedule or a word budget for `docs/`.

## Initial candidates and protected value

Review candidates, not an approved deletion list. "Guidance reads" are
distinct top-level sessions that read the document without editing it.

| Candidate | Evidence | Action and gate |
| --- | --- | --- |
| [acpx packaging plan](../plans/acpx-skill-packaging-plan.md), [justfile migration plan](../plans/justfile-migration-plan.md), [wiki ingest revisit plan](../plans/wiki-ingest-revisit-plan.md) | Index rows name nothing left to do; status still open. | Close now; ADR 0028, ADR 0026, and the tests guide already hold the rationale. First test of the retirement rule. |
| [Chezmoi migration plan](../plans/chezmoi-migration-plan.md), 9,000 words, archived | 33 guidance reads, 8 reaching the architecture reference; 1.35M-token ceiling, the costliest document in the tree. | Check that `chezmoi-architecture.md` and the chezmoi skill cover its recovery content and incoming links; preserve distinctive migration evidence before removal. |
| [Test-suite rebuild plan](../plans/test-suite-rebuild-plan.md), 9,331 words, archived | 11 guidance reads, zero reaching its `current_guidance` target. | Compare its guarantees with the tests guide and ADR 0022; candidate for deletion after extraction and the validator change. |
| ADR 0011 and ADR 0016, superseded | Read in 11 and 6 sessions; their successors (ADR 0039, ADR 0028) read in none of them. | Keep the files; put a one-line "superseded, read X instead" at the top of the body or ensure the generated inventory surfaces the successor first. |
| [Agent skill management research](agent-skill-management-research.md), `current` | Describes the retired layout; 20 guidance reads. | Correct its authority signal promptly; preserve useful evidence, then supersede or retire. |
| Never-read research (nine documents, including [macOS permission utility design](macos-permission-utility-design.md) at 6,459 words) and the three cited by nothing open | Zero guidance reads ever. | Reconcile any standing claims into their maintained docs; move or delete the snapshots. |
| [Ralph workflow research](ralph-loop-workflow.md), 9,006 words, active | Largest live research doc. | Separate recurring operating contracts from experiment chronology; assess callers before retention. |
| `references/acpx-routing.md` and `references/chezmoi-architecture.md` | About 30 copied eight-word sequences each with their skill. | Pick one home per sentence. |
| [Orcactl plan](../plans/orcactl-plan.md), draft for a separate tool | 4,508 words; 4 guidance reads. | Review whether the tool's own repo should own it; lack of implementation is not permission to discard it. |
| [Console plan](../plans/skill-management-console-plan.md) and [session archive plan](../plans/agent-session-wiki-plan.md) | 7,500 and 5,969 words; live phases and gates. | Preserve open phases; condense completed narrative only if it helps ongoing work. |
| `docs/index.md` | Section "The index is not a router". | Shrink to a router; generate the rest. The 16 index-entry validator failures go away with it. |
| ADR 0049 collision | Two files share the number. | Renumber the later one to 0051 with a redirect note in its predecessor's row, or record the collision in both and add the uniqueness check so it cannot recur. Never renumber is the standing rule, so this is Prateek's call. |

Keep current recovery runbooks, useful testing contracts, and meaningful
decision rationale. Do not delete research solely because an operational
summary exists: original sources, uncertainty, and negative results prevent
repeated investigation. Preserve that value deliberately in the smallest
suitable home.

## How to evaluate a follow-up

Start with the retirement contract and the three plans with nothing left.
Before deleting each file, review its inbound live links, unique evidence,
open gates, and git recovery path, and repair its callers in the same change.

Then run comparable fresh-agent tasks that require finding current package
architecture, recovering a historical decision, following a runbook, and
locating unfinished work. Hold model, task, and environment constant and
repeat enough to expose variance. Score correctness and policy compliance
first; record wrong-source selection, unnecessary reads, retries, elapsed
time, and tokens. The agentsview queries in `build/doc-policy-review/` give
the baseline: guidance reads by status, stale reads without their target,
index-first rate, and validator failure mix. Re-run them a quarter after any
change and compare before claiming a benefit.

Routine maintenance should ask whether a document answered a real question,
whether its reader found the right authority, and whether its durable content
already lives elsewhere. Track net growth as a diagnostic, without a quota that
discourages necessary guidance.

## Reproduction and this report's own lifetime

Inventory and compliance: `git ls-files`, frontmatter parsing, `git log` per
path (with and without `--follow`; the former truncates history for 19 renamed
documents), inbound-link grep across the repo, and eight-word shingle overlap
between documents and skills. Session evidence: the AgentsView store opened
with `immutable=1` while no daemon ran, one scan of `tool_calls` for doc paths
materialized into a scratch SQLite file, per-call classification into read,
edit, search, or mention with heredoc bodies excluded, subagent rollup to the
root session, and a frontmatter join against the checkout at HEAD. Costs come
from `messages.token_usage` times `model_pricing`; Cursor sessions carry no
token data and `usage_events` records no cost. Git churn uses
`git log --numstat -- docs/`. The Codex pass's inventory script, CSV, external
source notes, and private case notes remain in `build/doc-policy-audit/`,
`build/doc-policy-research/`, and `build/session-impact-review/`; the Claude
pass's five reports with every query inline, the per-document TSV, and the
practitioner and corpus source lists are in `build/doc-policy-review/`. All
are gitignored working evidence, not maintained tools.

This file is the requested research deliverable. After a policy decision,
promote adopted rules into `document-lifecycle.md`, `AGENTS.md`, and the
validator, and retire this report unless its comparative evidence has a named
continuing use. Do not create a plan and ADR merely to preserve this review;
create them only if the chosen implementation needs those artifacts.

## Sources

Vendor guidance:

- Anthropic, Claude Code [best practices](https://code.claude.com/docs/en/best-practices), [memory](https://code.claude.com/docs/en/memory), [context window](https://code.claude.com/docs/en/context-window), and [effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- OpenAI, [AGENTS.md guide](https://learn.chatgpt.com/docs/agent-configuration/agents-md.md) and [ExecPlans cookbook](https://developers.openai.com/cookbook/articles/codex_exec_plans)
- Cursor, [planning](https://cursor.com/docs/agent/planning)

Practitioners:

- HumanLayer, [`THOUGHTS.md`](https://github.com/humanlayer/humanlayer/blob/main/hlyr/THOUGHTS.md) and [`create_plan.md`](https://github.com/humanlayer/humanlayer/blob/main/.claude/commands/create_plan.md)
- Geoffrey Huntley, [Ralph](https://ghuntley.com/ralph/)
- Simon Willison, [GitHub Issues for notes](https://simonwillison.net/2025/May/26/notes/) and [`simonw/research`](https://github.com/simonw/research/blob/main/README.md)
- Mitchell Hashimoto, [My AI adoption journey](https://mitchellh.com/writing/my-ai-adoption-journey)
- Addy Osmani, [AGENTS.md lesson](https://addyosmani.com/agents/15-agents-md/) and [documentation-and-adrs skill](https://github.com/addyosmani/agent-skills/blob/main/skills/documentation-and-adrs/SKILL.md)
- Peter Steinberger, [`docs-list.ts`](https://github.com/steipete/agent-scripts/blob/main/scripts/docs-list.ts) and [agent guidance](https://github.com/steipete/agent-scripts/blob/main/AGENTS.MD)
- Boris Cherny, X thread via [ThreadReader](https://threadreaderapp.com/thread/2017742741636321619.html) (direct X access returned 403)
- David Zhang, [`close-spec` skill](https://github.com/dzhng/skills)

Repository conventions:

- [openmeld `developing/README.md`](https://github.com/amplifthq/openmeld/blob/main/developing/README.md)
- [spec-kitty docs index](https://github.com/spec-kitty/spec-kitty/blob/main/docs/adr/index.md)
- [opencode `specs/v2/README.md`](https://github.com/sst/opencode/blob/dev/specs/v2/README.md)
- [GitLab artifact-registry work item 1338](https://gitlab.com/gitlab-org/ops/artifact-registry/-/work_items/1338); GitLab docs [workflow](https://docs.gitlab.com/development/documentation/workflow/) and [removals](https://docs.gitlab.com/development/documentation/styleguide/deprecations_and_removals/)

Non-agent precedents:

- Michael Nygard, [Documenting architecture decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [PEP 1](https://peps.python.org/pep-0001/), [Rust RFCs README](https://github.com/rust-lang/rfcs/blob/master/README.md), [Kubernetes KEP process](https://github.com/kubernetes/enhancements/blob/master/keps/sig-architecture/0000-kep-process/README.md)
- [Software Engineering at Google, chapter 10](https://abseil.io/resources/swe-book/html/ch10.html); Malte Ubl, [Design docs at Google](https://www.industrialempathy.com/posts/design-docs-at-google/)
- [Chromium documentation best practices](https://chromium.googlesource.com/chromium/src/+/main/docs/documentation_best_practices.md)
- Basecamp, [Shape Up: bets, not backlogs](https://basecamp.com/shapeup/2.1-chapter-07)
- Write the Docs, [July 2021 newsletter](https://www.writethedocs.org/blog/newsletter-july-2021/)

Studies and discussion:

- [Evaluating AGENTS.md](https://arxiv.org/html/2602.11988v3) (arXiv, September revision)
- [JAWS 2026 study of AGENTS.md efficiency](https://assets.empirical-software.engineering/pdf/jaws26-agents.md-efficiency.pdf)
- Reddit, [r/ExperiencedDevs on stale documentation](https://www.reddit.com/r/ExperiencedDevs/comments/1qejexx/documentation_is_three_years_out_of_date_and/) and [r/ChatGPTCoding on AI documentation dumps](https://www.reddit.com/r/ChatGPTCoding/comments/1l625ca/please_stop_doing_this/)

The full fetched-URL lists, with the passages relied on, are in
`build/doc-policy-review/practitioner-doc-lifecycle-research.md` and
`build/doc-policy-review/github-corpus-doc-lifecycle.md`.
