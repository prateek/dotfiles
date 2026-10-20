---
status: draft
doc_type: research
summary: "Prior art for an in-repo ledger of landed-but-unverified agent work, and what the GHOST_OF_COMMITS_PAST convention should borrow from it."
created: 2026-10-20
updated: 2026-10-20
status_detail: "Consumed by the ghost skill in agent-marketplace/src/core; no plan or ADR."
---

# Ghost of Commits Past: Prior Art

## Scope

The proposed convention has two parts. While working, an agent accrues notes in
a gitignored `GHOST_MESSAGE_BUFFER.md`. When it lands, it folds them into one
handoff-shaped entry in a committed, repo-root `GHOST_OF_COMMITS_PAST.md` that
lists what still needs verifying, then deletes the buffer. A later agent, which
can be any harness on any machine, verifies an entry and deletes it. The first
real entry is on branch `prateek/agent-marketplace`.

This survey asks what existing practice already covers, and which parts of it
should shape three decisions: the entry format, the receiving agent's behavior,
and later lint rules.

## Method and coverage

The survey ran the `search` skill on 2026-10-20 across six facets: harness
progress files, handoff conventions, vendor memory features, GitHub code
(`HANDOFF.md`), GitHub repos, and Hacker News. The trace is
`~/.local/state/agent-search/runs/2026-10-20/606542d7c3964596ac90d5786079899d/state.json`.

A second pass covered the families the first one missed: Cline Memory Bank, Amp
handoff, Codex memories, Beads, and expiring-TODO linters. It used direct web
search and `gh api` outside that run.

Coverage gaps:

- Page fetch was unavailable. The MCP fetch gateway disconnected, and work-machine
  policy denies WebFetch. GitHub READMEs were read in full through `gh api`.
- Claims from non-GitHub pages rest on search-result excerpts. That covers the
  Anthropic engineering post, Amp, Cline, Codex, and the Claude Code docs.
  Treat those claims as unverified until someone reads the original page.
- The searches were English only.

## Findings

### 1. Progress files plus git history are the standard handoff

Anthropic's harness for long-running agents has each coding session append to
`claude-progress.txt` and commit. The next session starts the same way every
time: it reads the git log and the progress file, picks the next item, and runs
one end-to-end check before new work. That check caught breakage left by the
previous session
([Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents),
excerpt). The post names two failure modes. In one, an agent ran out of context
mid-feature and left it undocumented. In the other, a later agent saw partial
progress and declared the job done.

The companion repo [anthropics/cwc-long-running-agents](https://github.com/anthropics/cwc-long-running-agents)
(README read) keeps this pattern as an agent-maintained `PROGRESS.md`, plus a
`commit-on-stop.sh` hook that catches uncommitted work. It adds two primitives:

- **Default-FAIL contract.** Every criterion starts false. A hook refuses to
  mark one passing until the agent has opened an evidence file.
- **Fresh-context evaluator.** A separate agent with no write tools grades the
  work from a context that never saw it being built.

### 2. Handoffs should carry claims, not facts

[aggressive0/verifiable-session-handoff](https://github.com/aggressive0/verifiable-session-handoff)
(README read) is the closest match to this convention. Its core rule is that "a
handoff contains claims to verify, not facts to trust blindly." It has four
protocols:

- **LOG**: record requirements, rejected approaches, and pitfalls when they
  happen, then re-read the entry to confirm it was saved.
- **WRITE**: rebuild the handoff from files and commands, and label each claim
  `verified`, `reported`, `unverified`, or `blocked`.
- **READ**: compare the handoff with the current repo state and verify material
  claims before resuming. Low-risk, reversible next steps may proceed. Ambiguity,
  drift, destructive actions, and external side effects pause for the user. "A
  handoff is never authorization to deploy, publish, delete data, or change
  permissions."
- **PROMOTE**: propose durable cross-task knowledge for the project
  instructions, after deduplication and user confirmation.

The skill also scans for secrets before writing. It uses a stale-write guard, a
fingerprint compare-and-swap, so concurrent writers can't clobber each other.

### 3. Handoff notes for work in flight are rewritten, not accumulated

Community `HANDOFF.md` practice keeps one active file, rewritten at each handoff,
with roughly these sections: done, changed, verified, not done, next step, do
not touch ([docs-md.com template](https://docs-md.com/agent-handoff-document),
[DEV: end sessions with a handoff note](https://dev.to/alapha888/your-agent-forgets-nothing-thats-the-problem-end-sessions-with-a-handoff-note-5f79),
excerpts). One guide adds frontmatter for status, branch, and next action, and
allows one active handoff per branch and topic
([Mervin Praison](https://mer.vin/2026/04/managing-handoffs-in-multi-agent-coding-sessions-fresh-context-without-losing-continuity/),
excerpt). Recurring advice:

- record the commit the note describes;
- write down dead ends and the reasons behind decisions, so the next session
  doesn't reopen them;
- don't let a guess read as a fact.

The common boundary test is "is it true next month?" Standing context belongs in
`AGENTS.md`. A handoff covers work in flight and is useless once that work lands.

Matt Pocock's [`/handoff`](https://www.aihero.dev/skills-handoff), which this
convention's entry shape adapts, writes to `$TMPDIR`. It references artifacts
instead of copying them, names suggested skills, and redacts secrets.

### 4. Multi-file memory systems grow until they need governance

- [WeirdSky924/agent-handoff-skill](https://github.com/WeirdSky924/agent-handoff-skill)
  (README read) bootstraps an `AGENT_HANDOFF.md` index plus nine files under
  `.agent-handoff/`, including `validation.md`, `backlog.md`, and `risks.md`. It
  ships capacity-governance scripts because snapshots and logs kept growing.
- [RRFRRF/project-memory-skill](https://github.com/RRFRRF/project-memory-skill)
  (README read) spreads memory across `LOOP.md`, `BUGS.md`, and a `.mem/` folder
  of state, decisions, and handoff files.
- Cline's [Memory Bank](https://docs.cline.bot/best-practices/memory-bank)
  (excerpt) is six chained files, with `activeContext.md` and `progress.md`
  changing most often. "update memory bank" makes the agent review every file.

All three are project memory: state, decisions, and context. None isolates the
narrow question of what landed but hasn't been checked.

### 5. Dated lines make staleness visible; owners push the dates

[awrshift/agent-memory-kit](https://github.com/awrshift/agent-memory-kit)
(README read) dates every memory line "so a stale fact looks stale," and writes
only after the user approves.

Expiring-TODO linters fail builds once a dated TODO passes its date:
[`unicorn/expiring-todo-comments`](https://github.com/sindresorhus/eslint-plugin-unicorn/blob/main/docs/rules/expiring-todo-comments.md),
[SwiftLint `expiring_todo`](https://realm.github.io/SwiftLint/expiring_todo.html),
and [todo_or_die](https://github.com/searls/todo_or_die). The unicorn rule
skips expired dates on pull requests by default, so the maintainer fixes them
rather than an unrelated contributor.

[chenhz01/todo-expiry-ledger](https://github.com/chenhz01/todo-expiry-ledger)
(excerpt) lists the failure modes: owners keep pushing the date forward, and
teams stop writing dates to keep the report clean.

### 6. Vendor memory is machine-local and per tool

- **Claude Code** auto memory lives in `~/.claude/projects/<project>/memory/`,
  and the first 200 lines of `MEMORY.md` load into each session
  ([docs](https://code.claude.com/docs/en/memory), excerpt).
- **Codex** memories are opt-in. Codex writes them to `~/.codex/memories/` after
  a session goes idle, and prunes entries nobody recalls for 30 days
  ([summary](https://codex.danielvaughan.com/2026/05/01/codex-cli-memories-persistent-context-session-memory-ecosystem/),
  excerpt).
- **Cursor** memories need user approval and are per project and per user,
  never shared ([aq.dev guide](https://aq.dev/guides/coding-agent-memory-explained/),
  excerpt).

None of the three syncs across machines or across tools. The shared channel is
the repo (`AGENTS.md`), and that holds rules, not open checks.

### 7. Within-session handoff is being absorbed by compaction

Amp replaced compaction with `/handoff` in October 2025. By May 2026 it had
dropped handoff again for automatic compaction plus thread references
([Amp, Rebuilt](https://ampcode.com/news/neo), excerpt). The cwc repo also says
the handoff layer is the most sensitive to model capability, and should be
re-checked after each model release.

That trend covers continuing one task. It doesn't cover a different agent, on a
different machine and harness, learning that a check never ran.

### 8. Structured trackers are the heavyweight alternative

[Beads](https://github.com/steveyegge/beads) (README read) replaces markdown
plans with a dependency-aware issue graph. It has `bd ready` for claimable work
and `bd remember` for durable facts. It needs a CLI and a database, which is out
of proportion for a short list of open checks.

## What to borrow

| Idea | Source | Use in the convention |
| --- | --- | --- |
| Claims, not facts; label what was verified | verifiable-session-handoff | Each entry states what is unverified and why. The receiver treats it as a claim. |
| Read on start, verify before relying | Anthropic harness, READ protocol | When the file exists and the task touches an entry's area, verify that entry before building on it. |
| Evidence before check-off | cwc default-FAIL contract | Delete an entry only after observing its done-when condition, and record what you saw in the deleting commit. |
| A different context does the check | cwc fresh-context evaluator | The file hands verification to whichever agent comes next. That's a feature, so say so. |
| LOG as it happens | verifiable-session-handoff LOG | This is `GHOST_MESSAGE_BUFFER.md`. Write to it at the moment, not from memory at the end. |
| PROMOTE durable facts elsewhere | verifiable-session-handoff PROMOTE, "true next month?" test | Entries hold open checks only. Standing facts go to `AGENTS.md` or docs; past work stays in git history. |
| Never an authorization | verifiable-session-handoff | An entry doesn't authorize pushing, deploying, or destructive steps. Ordinary approval rules still apply. |
| Date every entry | agent-memory-kit, expiring TODOs | Entry headings already carry the date, which enables later staleness checks. |
| One file, short by construction | lesson from the multi-file systems | One root file. Entries are appended per landing and deleted on verification. No archive, because git is the archive. |
| Redact at write time | `/handoff`, verifiable-session-handoff scanner | Required: this repo is public, and the work overlay rules apply to entries. |
| Don't make contributors fix maintainers' debt | unicorn PR default | If staleness linting arrives later, warn on unrelated changes rather than block them. |

## What not to borrow

- **Rewriting a single session-state handoff.** This file is a ledger of open
  checks, not a snapshot of one task, so per-landing entries fit better. Session
  handoffs already have `ho`.
- **Multi-file memory directories and capacity scripts.** Deleting verified
  entries is the size control.
- **Per-claim status enums** (`verified` / `reported` / ...). Only unverified
  items belong in the file, so every claim in it is unverified by definition.
- **A tracker or database.** Beads-scale tooling costs more than this problem
  justifies.
- **Snooze or extend dates.** The ledger lesson is that dates get pushed. An
  entry should either be verified or escalated to Prateek.

## Decisions taken from this research

On 2026-10-20 Prateek chose these options from the proposal:

- **Scope**: the ledger applies where the file exists, or where an agent is told
  to keep one.
- **Home**: a skill only, `ghost` in the core package. One
  pointer line in the machine `AGENTS.md` routes to it.
- **Receiver**: touch-or-stale. Verify entries the task touches, work the
  ledger only during gardening or a dedicated session, and report entries
  older than 14 days.
- **Entry size**: at most 100 words, with detail linked from `docs/`. Items are
  checks on landed work; tasks go to plans or issues.
- **Names**: keep `GHOST_OF_COMMITS_PAST.md` and `GHOST_MESSAGE_BUFFER.md`. The
  buffer is ignored in the global git ignore file.

Lint rules wait until the convention has been used in practice.
