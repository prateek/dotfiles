---
status: active
doc_type: research
owner: Prateek
created: 2026-05-11
updated: 2026-05-18
related:
  - ../plans/docs-reorg-plan.md
  - ../../home/dot_agents/packages/core/skills/local/code-gardening/SKILL.md
status_detail: "Pattern reference. Surveys external patterns for self-improving agents across two surfaces: the repo-state surface (files in this repo that change agent behavior) and the runtime surface (agent memory and skills that evolve in-process). Part 5 tracks this repo's open questions about skill coverage, subagent context, and dark skills."
---

# Self-Improving Agents

External patterns for letting agents get better over time without
manual prompt engineering. All rest on the same premise: when an agent
makes a mistake, the productive response is to change something
durable so the next agent does not repeat it — not to write a longer
prompt.

The patterns split across two surfaces:

- **Repo-state surface.** Files in this repo that change agent behavior
  session over session. The agent reads them; a human or a curator
  writes them. Examples: `AGENTS.md`, a Known Pitfalls table, MLD
  observability files. Cheap, durable, auditable in `git log`.
- **Runtime surface.** State inside the agent process itself that
  evolves as the agent runs — memory stores, auto-generated skill
  libraries, learned routing rules. Examples: Anthropic's Dreaming
  pass over Claude Managed Agents memory; Hermes Agent's auto-curated
  skill library; claude-bootstrap's 3-tier memory mesh. More
  capability per session; harder to inspect, harder to share across
  agents.

This doc is reference material, not a proposal. The completed docs reorg
kept skill coverage and subagent-context questions here as follow-up
material; see [docs-reorg-plan.md](../plans/docs-reorg-plan.md) for the
archived implementation record.

## Part 1: Repo-state surface

Patterns where the agent reads durable files in this repo and a human
(or a curator agent) writes them. The unit of learning is a tracked
file in `git`.

### Pattern 1: Known Pitfalls table (Quickwit)

#### Source

- Repo: [quickwit-oss/quickwit](https://github.com/quickwit-oss/quickwit)
- Root file: [`/CLAUDE.md`](https://github.com/quickwit-oss/quickwit/blob/main/CLAUDE.md)
- Author: George Talbot (quickwit core engineer). Introduced in early
  2026 alongside the wider ADR/gaps/deviations framework.

#### Shape

A table near the bottom of the repo-root `CLAUDE.md`, three columns:

| Mistake | Correct behavior | Bug reference |
| --- | --- | --- |
| Using `tokio::sync::Mutex` in async code | Use the std `Mutex`; the async one is almost always a smell | `clippy.toml` lint |
| Calling `JoinHandle::abort()` | Use cancellation tokens; abort leaves Drops un-run | GAP-007 |
| Using `Path::exists()` | Returns false on permission errors; use `try_exists()` | _(uncited)_ |

Each row is one specific agent failure that recurred enough to be worth
encoding. The column choices are deliberate:

- **Mistake** names the wrong behavior in agent-recognizable shape
  (the literal API call, not abstract advice).
- **Correct behavior** is the substitute, paired with the *why*.
  Pairing matters: "don't use X" without "use Y" was measured by
  Augment Code to make PRs ~20 % less complete on average.
- **Bug reference** is either a clippy/lint rule that mechanically
  catches the failure, a gap-doc ID, or a PR link. The reference is
  evidence that the rule exists; if there is no reference, the row is
  drift-prone.

#### Why it works

- It is appended to, not rewritten. Every entry is born from a
  concrete bad experience, so the file is calibrated rather than
  guessed.
- The Bug Reference column applies social pressure to ground each
  rule in either an automated check or a documented past failure.
  Rows that lack a reference invite the question "is this still
  true?"
- It is one table, not a section per topic. Skimming is the use case;
  the agent reads top-to-bottom looking for matches against its
  planned actions.
- The companion ADR/gaps system at
  [`docs/internals/adr/`](https://github.com/quickwit-oss/quickwit/tree/main/docs/internals/adr)
  provides the long-form record for entries that grew beyond one
  row. Known Pitfalls is the short-form intake.

#### What to consider before adopting

- Best paired with mechanical enforcement. A pitfall without a lint,
  test, or hook decays fastest because nothing fails when the rule
  is silently ignored.
- Belongs in the always-loaded file (CLAUDE.md / AGENTS.md). Hiding
  it in a sibling doc loses the "scanned every session" property.
- Cap on length matters. Quickwit's table is short by design; if a
  pitfall list grows past ~15 rows, the file starts to lose the
  scannability that makes the pattern work in the first place.
- Best for narrow, repeating mistakes (specific API misuse, specific
  file mis-edited). Broad mistakes ("plans are not specs") belong in
  the doc-type guidance, not in this table.

#### Files in scope if adopted here

- `AGENTS.md` (root) — add a "Known Pitfalls" table section.
- `scripts/audit/` — one lint or check per row when feasible.
- Optionally `docs/adr/` — for any pitfall whose rationale is long
  enough to warrant its own ADR.

### Pattern 2: MLD framework — MISTAKES.md / DESIRES.md / LEARNINGS.md (Ryan Lopopolo)

#### Source

- Author: Ryan Lopopolo (OpenAI Frontier; coined "harness engineering").
- Original post: [@_lopopolo on X, 2026-03-26](https://x.com/_lopopolo)
  (the framework is named in a thread; the OpenAI post
  [_Harness engineering: leveraging Codex in an agent-first world_](https://openai.com/index/harness-engineering/)
  gives the surrounding context).
- Adopted at: Basis (paystubsdotai), reportedly several other harness-
  serious teams. Cited frequently in Latent Space discussion:
  [Extreme Harness Engineering for Token Billionaires](https://www.latent.space/p/harness-eng).

#### Shape

Three sibling files at the repo root (or `.agents/`), each maintained
by the agent during its working session:

```text
MISTAKES.md     — "I made a mistake. Here is what I did, why it was wrong,
                  and what would have prevented it."
DESIRES.md      — "I wished I had X here. Here is what I needed, when I
                  needed it, and what I had to do instead."
LEARNINGS.md    — "I learned something about this environment. Here is the
                  fact, where I needed it, and how I discovered it."
```

The system prompt or AGENTS.md tells the agent to *write* to these
files during its run. They are observability surfaces, not
instructions. The human (or a downstream agent) reads them after the
session and decides what to do:

- A repeated MISTAKES.md entry becomes a Known Pitfall row, a lint, a
  test, or a new skill.
- A repeated DESIRES.md entry becomes a tool, a script, an MCP server,
  or a skill.
- A repeated LEARNINGS.md entry becomes a documented convention or a
  Repo Map clarification.

The framework is closer to telemetry than to documentation. Each file
is allowed to be messy in-flight; the gardening pass that promotes
entries into durable repo state is where the value materializes.

#### Lopopolo's stated quotes

From the cited X thread and his AI Engineer Europe talk
[_Harness Engineering: How to Build Software When Humans Steer,
Agents Execute_](https://www.youtube.com/watch?v=am_oeAoUhew):

- > Please make note of mistakes you make in MISTAKES.md. If you find
  > you wish you had more context or tools, write that down in
  > DESIRES.md. If you learn anything about your env write that down
  > in LEARNINGS.md.
- > Anytime you find an agent makes a mistake, you take the time to
  > engineer a solution such that the agent never makes that mistake
  > again. (paraphrasing Mitchell Hashimoto's terser version of the
  > same rule.)
- > Where is the agent making mistakes? Where am I spending my time?
  > How can I not spend that time going forward?

#### Why it works

- Decouples observation from action. The agent does not have to be
  "right" about its mistakes in real time; it just needs to record
  them. Curation happens out-of-loop.
- Generates evidence for harness changes rather than relying on the
  human's memory of "that one annoying thing last week."
- Surfaces the missing-tool / missing-doc case (DESIRES.md) that is
  otherwise invisible. Most observability captures what went wrong;
  this is one of the few patterns that captures what should have
  existed.
- Pairs naturally with the Known Pitfalls table: MLD is the intake,
  Known Pitfalls is the curated output.

#### What to consider before adopting

- Requires a gardening cadence. Without periodic curation, MLD files
  become append-only logs that nobody reads. Lopopolo's team treats
  curation as a non-negotiable part of the harness loop.
- The files need to live somewhere the agent can write to easily.
  Repo-root works; per-session files under
  `${XDG_STATE_HOME:-~/.local/state}/dotfiles/sessions/` also work
  and avoid polluting `git status`.
- The system-prompt / AGENTS.md addition that asks the agent to write
  to these files is short — three or four sentences — but it must be
  unconditional or the agent will skip when it gets busy.
- Works best when one human (or one skill) is named as the curator.
  Otherwise entries pile up and nobody promotes them.

#### Files in scope if adopted here

- `AGENTS.md` — three sentences telling the agent to maintain MLD
  files during its session.
- New writable surface — either tracked files at repo root (visible
  in `git status`) or untracked files under `$XDG_STATE_HOME` (silent
  but harder to share).
- A skill or hook to roll up sessions: read the MLD files, summarize,
  optionally feed back into Known Pitfalls.
- A curator. The `code-gardening` skill is the natural fit, with a
  new sub-step "promote MLD entries to durable repo state."

### How the two repo-state patterns relate

| | Known Pitfalls | MLD |
| --- | --- | --- |
| Lifecycle stage | Curated output | Raw intake |
| File count | 1 (a table inside AGENTS.md) | 3 sibling files |
| Author | Human or curator after the session | Agent during the session |
| Update cadence | When evidence justifies a row | Continuous during session |
| Failure mode | Stale rows; bloat past ~15 entries | Append-only logs nobody reads |
| Strength | Always-loaded, scannable | Surfaces missing tools/docs that would otherwise stay invisible |
| Best paired with | A lint, test, or hook per row | A curator that promotes entries to durable state |

The patterns are complementary. Quickwit demonstrates the curated-
output half without an explicit intake mechanism; their intake is
informal (engineer notices, engineer writes a row). Lopopolo
demonstrates the intake half without prescribing what the curated
output looks like; the output could be a Known Pitfalls table, an ADR,
a new skill, a new lint, or anything else.

A full adoption would run both: MLD as session-time telemetry, Known
Pitfalls as the curated digest, a gardening pass that translates the
former into the latter.

## Part 2: Runtime surface

Patterns where the agent's own memory or skill library evolves
in-process. The unit of learning is a memory entry, a skill file in
the agent's state directory, or a routing rule the agent rewrote
itself.

These patterns are *not directly adoptable in this repo*. They
require switching to a different agent runtime, or building one. They
are included because they are the architectural alternative to
Part 1 — when Part 1 is too coarse (the gardening loop is too slow,
the curator does not have time, or the mistakes are too
domain-specific to encode as repo files), Part 2 is the answer the
ecosystem has converged on.

### Pattern 3: Dreaming — offline memory curation (Anthropic)

#### Source

- Anthropic blog: [_New in Claude Managed Agents: dreaming, outcomes,
  and multiagent orchestration_](https://claude.com/blog/new-in-claude-managed-agents) (2026-05-06).
- Press coverage: [VentureBeat](https://venturebeat.com/technology/anthropic-introduces-dreaming-a-system-that-lets-ai-agents-learn-from-their-own-mistakes),
  [The New Stack](https://thenewstack.io/anthropic-managed-agents-dreaming-outcomes/),
  [SiliconANGLE](https://siliconangle.com/2026/05/06/anthropic-letting-claude-agents-dream-dont-sleep-job/).

#### Shape

A scheduled, offline pass over an agent's past sessions and memory
stores. Reads sessions; rewrites memory.

Anthropic's own description:

- > Dreaming is a scheduled process that reviews your agent sessions
  > and memory stores, extracts patterns, and curates memories so
  > your agents improve over time.
- > Dreaming surfaces patterns that a single agent can't see on its
  > own, including recurring mistakes, workflows that agents converge
  > on, and preferences shared across a team.
- > It also restructures memory so it stays high-signal as it evolves.

What it *does* surface:

- Recurring mistakes across sessions.
- Workflows that multiple agents independently converge on.
- Preferences shared across a team of agents.

What it *does not* do (read this twice): Dreaming **curates existing
memory**. It does not synthesize new skills. The blog post does not
claim skill creation; that distinction belongs to Hermes Agent
(Pattern 4 below).

#### Numbers, with caveats

- Harvey (legal AI): "Completion rates went up ~6x in their tests."
  Anthropic frames this as test results, not deployed-fleet metrics.
- Wisedocs (medical document review): "Reviews now run 50% faster,
  while staying aligned with their team's standards."

Both wins are in domains with judgeable outputs (legal drafting,
document review). See Part 4 on the verifiability constraint.

#### Companion features shipped same day

- **Outcomes.** A rubric-graded evaluator over agent output; reported
  "up to 10 points" task-success improvement, "+8.4% task success on
  docx and +10.1% on pptx."
- **Multi-agent orchestration.** Lead agent delegates to specialist
  subagents "in parallel on a shared filesystem," with persistent
  event logs for mid-workflow check-ins.

#### Architectural primitive

- **Unit of learning:** memory entries inside a memory store.
- **When:** scheduled, "between sessions," offline. Exact cadence
  (hourly/daily, per-agent vs. per-store) is not specified in the
  blog post.
- **Where state lives:** memory stores attached to agents or teams.
  Dreaming reads sessions plus memory stores and writes back curated
  memory.

#### What to consider

- Closed-source. To use it you commit to Claude Managed Agents as the
  runtime. The pattern is generalizable; the implementation is not
  portable.
- The community-facing framing landed on
  [r/AIToolsForSMB](https://www.reddit.com/r/AIToolsForSMB/comments/1t6ich4/anthropic_just_dropped_dreaming_agents_that/)
  as "REM sleep for agents." Same post notes plainly: "For most SMBs
  it changes nothing yet." The capability exists at the enterprise-
  agent tier; the SMB tooling has not caught up.

### Pattern 4: Skillbank — auto-generated skill library (Hermes Agent)

#### Source

- Project: [Hermes Agent](https://hermes-agent.nousresearch.com/) by
  Nous Research; repo at
  [github.com/nousresearch/hermes-agent](https://github.com/nousresearch/hermes-agent).
- Current release (as of fetch on 2026-05-11): **v0.13.0 "The
  Tenacity Release"** (2026-05-07). License: MIT.
- Walkthrough video (highest-signal community content in the
  research window): [Better Stack — _Hermes: The Self-Improving
  Agent That Gets Smarter Every Day_](https://www.youtube.com/watch?v=HdxtLpL9CC8)
  (18,902 views, 442 likes).

#### Shape

A single agent that runs against an evolving skill library it writes
itself. Distinct from Dreaming: Hermes *creates* skills, not just
curated memory.

From the Hermes README and docs:

- > Persistent memory and auto-generated skills — it learns your
  > projects and never forgets how it solved a problem.
- > Agent-curated memory with periodic nudges. Autonomous skill
  > creation after complex tasks. Skills self-improve during use.
  > FTS5 session search with LLM summarization for cross-session
  > recall.
- > This is not a CLAUDE.md file you maintain yourself. The agent
  > curates its own memory with periodic nudges.
- v0.12.0 release note: "Autonomous Curator grades, prunes, and
  consolidates skill library on scheduled cycles."

The architecture in the [Tech Edge AI-ML
walkthrough](https://www.youtube.com/watch?v=_fEOmnyaRRM):

- > Hermes Agent takes a different approach from agents like Open Claw.
- > Unlike agents that simply store logs, Hermes actively extracts
  > useful procedures and writes them as skills, ready to be reused
  > when similar problems arise.
- > These skill files are structured according to the agentskills.io
  > open standard, making them portable and shareable across
  > compatible agents.

The canonical learning loop, from [AgentsLab-Ritik on
YouTube](https://www.youtube.com/watch?v=XklD9jw8LpQ):

- > Embed the task, run top-K search over the Skillbank, inject the
  > results into the system prompt. After solving, a skill extractor
  > parses the output and writes new entries back to the store.
- > By session 10, it's pulling from patterns it extracted itself.

#### Architectural primitive

- **Unit of learning:** skills (auto-generated, self-improving) plus
  a session-recall layer. The skill is the persistent artifact, not
  the memory entry.
- **Where skills live on disk:** `~/.hermes/skills/`, with an
  `imports/` subdirectory for external skills. Schema is not
  published on the marketing surfaces; lives in the repo source.
- **Curation cadence:** "scheduled cycles" via the Autonomous Curator
  (v0.12.0). The "every 15 tool calls" cadence cited in some
  community videos does not appear in the primary docs as of this
  fetch — treat it as a video claim, not a documented contract.
- **Cross-session memory:** FTS5 full-text index over sessions, plus
  LLM summarization. Not described as a layered tier system in the
  docs even though the marketing copy says "multi-level memory."

#### Numbers

- 8,102 commits, ~145K GitHub stars, ~22.7K forks at fetch time
  (these come from a model-summarized GitHub fetcher; if precise
  numbers matter, hit `gh api repos/nousresearch/hermes-agent`
  directly).
- Skill share velocity: claimed "40% task-time reduction on
  domain-similar tasks after 20+ skills are accumulated"
  (third-party blog, not confirmed by Nous Research).

#### What to consider

- Open source, MIT licensed. Portable in the sense that the *agent
  runtime* is portable, but the skill library it builds is local to
  your install unless you publish to the Skills Hub.
- Skills are exposed as files. That makes them inspectable, diffable,
  and shareable in a way that opaque memory stores are not. The
  trade-off is that the agent is writing files in your home
  directory autonomously; you need to be okay with that.
- The agent is single-process and runs alongside one of seven
  terminal backends (local, Docker, SSH, Singularity, Modal,
  Daytona, Vercel Sandbox). It is not a managed-cloud product.

### Pattern 5: Closed-loop evaluation-to-improvement (Future AGI, OJ)

#### Source

- Reddit post: [_Finally an open-source stack for agents that
  actually "self-improves" (Future AGI)_](https://www.reddit.com/r/AgentsOfAI/comments/1sx18mq/finally_an_opensource_stack_for_agents_that/)
  on r/AgentsOfAI (2026-04-27).
- Walkthrough: [Orkhan Javadli — _How to Build Self-Improving AI
  Agents in 2026: Evaluation-to-Improvement Loop_](https://www.youtube.com/watch?v=4fowNz3ASfk)
  (2026-04-29).

#### Shape

The improvement signal is not "the agent wrote something useful"; it
is "the agent's output passed an evaluator we trust." A separate
evaluator scores agent outputs; an optimizer rewrites prompts or
routing rules until the score goes up.

From the Reddit thread:

- > Instead of just deploying a static prompt and praying it doesn't
  > hallucinate into a void, this thing is built to simulate failures
  > and optimize itself based on production data.

The OJ walkthrough cites the Stanford 329T evaluation framework, a
December 2025 survey paper, and the MIPRO v2 optimizer as the
concrete tooling. Recommended bench: "at least 30 iterations to
start setting some benchmark," with a 5% failure tolerance ("okay
with one out of 20 failing").

#### Architectural primitive

- **Unit of learning:** prompts, routing rules, or skill parameters
  — whatever the optimizer is allowed to rewrite.
- **When:** offline, against a held-out evaluation set.
- **Where state lives:** the evaluator's run history plus the
  optimizer's checkpointed parameter set.

#### What to consider

- This pattern requires an evaluator. If you do not have a way to
  score agent outputs, this is not a runtime; it is just a wishlist.
  See Part 4.
- Pairs naturally with MLD as a feedback source: MISTAKES.md becomes
  an automatic negative-example feed into the evaluator's training
  set.

### Pattern 6: DIY harness on top of a platform (claude-bootstrap / Maggy)

#### Source

- Reddit post: [r/ClaudeAI — _I built an autonomous engineering
  agent on top of Claude Code_](https://www.reddit.com/r/ClaudeAI/comments/1ta3rsi/i_built_an_autonomous_engineering_agent_on_top_of/)
  (u/naxmax2019, 2026-05-11).
- Project: claude-bootstrap v5 ("Maggy"). Repo:
  [github.com/alinaqi/claude-bootstrap](https://github.com/alinaqi/claude-bootstrap).
- Built on Claude Code skills, hooks, and MCP servers. The author
  frames it as "additive" — does not replace Claude Code, layers on
  top.

#### Shape

A wrapper that wires four mechanisms into Claude Code:

- *Self-improving routing.* "Auto-discovers which CLIs you have
  (Claude, Codex, Kimi, Ollama) by probing `--help` at startup.
  Routes by complexity score. The routing rules are YAML and
  self-update from task outcomes." Five-level cadence: L0 real-time
  (seconds) → L4 monthly recalibration of the improvement process
  itself.
- *Cross-session memory (Engram).* "Three-tier memory system — local
  (project-specific), portfolio (cross-project patterns), and mesh
  (team-shared)." The author enumerates "7 distinct amnesia
  pathologies (anterograde, retrograde, temporal, source,
  interference, context-binding, confabulation)" the design is meant
  to address.
- *Process intelligence.* "Collects signals from the full SDLC — CI
  results, PR review comments, CodeRabbit findings, merge patterns,
  deploy results."
- *P2P team learning (Maggy Mesh).* "Typed memory classes (scores,
  patterns, policies, gaps) with provenance and quarantine."

The amnesia critique, verbatim:

- > Every AI coding tool today is an amnesiac. When a session ends,
  > everything the agent learned — project conventions, reviewer
  > preferences, codebase idioms — evaporates.

#### Implicit critique of the platform

The author positions Claude Code as "Level 3: Task Agent" and Maggy
at Level 4. Claimed benchmark: same 6/6 success as Claude Code, but
"Claude usage 1/6 tasks (17%)" vs "6/6 (100%)" and "Security issues
found: 7 vs 0." Read this as a one-author benchmark; it is a
direction-of-travel signal, not validated comparison.

#### Community reaction

The post sits at 0 upvotes with mostly skeptical comments:

- u/Formally-Fresh (+6): "Wow truly revolutionary ( /s )"
- u/CricktyDickty (+2): "You solved continual learning and just
  released it on Reddit?"
- u/devulders (+3) plugs a competing project, ltm-cli.dev, on the
  same amnesia thesis.

Skepticism is the dominant reaction. Worth including as a useful
reality check: "self-improving agent" is a crowded marketing space
and the bar for proof is high.

#### Architectural primitive

- **Unit of learning:** routing rules + memory entries + skill files.
  No single primitive; the project is a kitchen-sink layer.
- **Where state lives:** in a parallel state tree alongside the
  Claude Code session, written by hooks the user configures.

#### What to consider

- The pattern (additive harness layered on a platform agent) is more
  important than this specific project. The same shape would work on
  Codex, Gemini CLI, or any agent that exposes skills/hooks/MCP.
- DIY harnesses are visibly out-running platform-shipped features
  right now. Treat this as evidence that the platforms are leaving
  surface area on the table, not as a recommendation to adopt this
  specific repo.

## Part 3: The interop layer

### `agentskills.io` as portable skill format

Both Hermes Agent (Pattern 4) and the broader ecosystem are
converging on `agentskills.io` as the open standard for portable
skill files. Tech Edge AI-ML on YouTube:

- > These skill files are structured according to the agentskills.io
  > open standard, making them portable and shareable across
  > compatible agents.

The New Stack on the OpenClaw → Hermes migration:

- > Skills follow the open agentskills.io standard, making them
  > portable across compatible platforms.
- Hermes can install ClawHub skills directly; an official OpenClaw →
  Hermes migration tool exists.

The standard URL is referenced in Hermes docs but the spec itself was
not fetched during this pass. Worth following up if interop matters
for adoption.

The interop story for *memory snapshots* is much weaker. None of the
runtimes described in Part 2 commit to a portable memory-store
format. If you move agents, you keep the skills and start the memory
over.

## Part 4: The verifiability constraint

Self-improvement only works when the agent can tell whether the
change it just made was an improvement. The strongest published
account of this constraint is the
[o-mega 2026 guide](https://o-mega.ai/articles/self-improving-ai-agents-the-2026-guide):

- > AI self-improvement only works reliably in domains where outcomes
  > are objectively verifiable. Code either compiles or it does not.
  > A math proof is either valid or invalid. An optimized algorithm
  > either runs faster or it does not.
- > But in domains like marketing copy, strategic planning, or
  > relationship management, there is no clean signal for 'better.'

The empirical proof point cited is **HyperAgents** (researchers from
Meta, UBC, Oxford, NYU; published 2026-03-19). Agents trained on
paper review and robotics were transferred to grade Olympiad math
solutions with no additional customization:

- > They achieved imp@50 = 0.630. Hand-designed systems built by
  > human experts for that same task scored 0.0.
- > The meta-level improvements acquired in other domains (better
  > memory management, performance tracking, prompt templates)
  > transferred to a novel domain where hand-designed approaches
  > failed entirely.

This is why Anthropic's wins are in legal drafting (Harvey) and
medical document review (Wisedocs) — both have judgeable outputs.
And it is why the Reddit framing of Dreaming as "for most SMBs it
changes nothing yet" is honest: SMB-shaped tasks are mostly in the
"no clean signal" bucket o-mega describes.

For the repo-state patterns in Part 1, the verifiability story is
different: the verifier is the human curator or the lint/test
attached to the Known Pitfalls row. The pattern dodges the
machine-learning verifiability problem by routing the decision
through a human or a deterministic check.

## How the patterns relate (across both surfaces)

| | Known Pitfalls | MLD | Dreaming | Hermes Skillbank | Eval-to-Improvement | DIY harness |
| --- | --- | --- | --- | --- | --- | --- |
| Surface | Repo state | Repo state | Runtime | Runtime | Runtime | Runtime |
| Unit of learning | Table row | Free-text entry | Memory entry | Skill file | Prompt / routing rule | Mixed |
| Author | Human curator | Agent (intake) | Offline agent pass | Agent (online + offline) | Optimizer | Hook-installed wrapper |
| Cadence | Per-session edit when justified | Continuous during session | Scheduled offline | Periodic during use + Autonomous Curator | Offline against eval set | Five-level (real-time → monthly) |
| Verifier | Human or attached lint | Human curator | Pattern detection | Skill-extractor heuristics | External evaluator | Heterogeneous |
| Portable? | Yes (git) | Yes (git) | No (Anthropic-managed) | Skills yes via agentskills.io; memory no | Eval set yes; rest no | Project-specific |
| Failure mode | Stale rows | Append-only logs | Closed-source dependency | Schema drift; uncurated skill bloat | No evaluator = no loop | One-author bench-marketing |
| Best paired with | A lint, test, or hook per row | A curator that promotes entries | Outcomes (rubric eval) | agentskills.io interop | MLD as negative-example feed | An existing platform agent |

Two observations from the table:

- The repo-state patterns are the only ones where the artifact is
  legible in `git`. That is a feature, not a limitation — it is the
  only column where a human reviewer can audit what the agent
  "learned" without running the agent.
- The runtime patterns dominate on per-session capability gain but
  almost all fail the portability test. The exception is
  agentskills.io, which is portable in principle but adopted only by
  Hermes-class agents in practice.

## Adoption sequence (if you decide to)

This section is unchanged from the original failure-capture framing:
the patterns in Part 1 are the only ones cheap enough to adopt today
in this repo. Runtime patterns require switching the agent runtime
and are out of scope for any incremental change to this dotfiles
checkout.

1. **Known Pitfalls table in AGENTS.md** — cheapest. Add the section
   with two or three rows distilled from recent sessions (the
   `.config/mise/config.toml` rule, the plan-vs-spec rule, the
   plist-not-TOML rule). Treat empty rows as a feature, not a bug.
2. **MLD files at repo root** — moderate cost. Add the three-sentence
   instruction to AGENTS.md and create empty `MISTAKES.md`,
   `DESIRES.md`, `LEARNINGS.md` files so the agent does not have to
   decide whether to create them.
3. **`code-gardening` skill gains a curator step** — moderate cost.
   Document that promoting MLD entries to Known Pitfalls / ADR /
   skill / lint is part of the gardening pass.
4. **`scripts/audit/promote-mld`** — optional and out of scope here.
   Walks the MLD files, surfaces entries seen more than once, and
   suggests Known Pitfalls rows.

If you only adopt one, pick Known Pitfalls. It is cheaper, more
durable, and pays off without changing how sessions run. MLD adds
upside but requires the curator commitment to be real value rather
than noise.

The runtime patterns (Parts 2-3) are tracked here so that *when* a
follow-up project considers switching agent runtimes — say to Hermes
Agent, or to Claude Managed Agents for a specific workflow — the
architectural trade-offs are already mapped out and the verifiability
question has been asked.

## Part 5: Open questions for this repo's harness

The dotfiles repo is itself a self-improving-agent harness: it ships
`AGENTS.md`, repo-local skills under `.agents/skills/`, machine-wide skill
package source under `home/dot_agents/packages/*/skills/{local,vendor}/`, and
the conventions that shape how Claude Code and Codex sessions run.
Three open questions about that harness sit one level above the
patterns in Parts 1-4 — they are about *whether the harness itself is
covering the right surface area*, not about which external pattern to
adopt. They are tracked here rather than in a separate plan because
they are the local instance of the same question Parts 1-4 ask.

### Missing skill coverage

`.agents/skills/chezmoi-management/` arrived after about 85
chezmoi sessions had already paid the friction cost. There is no
automated way to notice "this area churns and has no skill yet."

Build or prototype a small read-only auditor under
`scripts/audit/skill-coverage` or as a skill if the workflow becomes
repeatable. It should walk recent Claude Code and Codex transcripts,
tally repo areas touched, and flag areas with many sessions and no
firing skill.

Output:

```text
repo path glob | session count | matching skill or none
```

Defer implementation if the cost outweighs the value. The first pass
can be a manual report.

**Reuse-or-learn-from: [khendzel/skills-janitor](https://github.com/khendzel/skills-janitor).**
A separate project already implements much of the auditor sketched
above. Seven slash commands, zero dependencies (Bash, Python 3, curl),
dry-run by default. The relevant ones:

- `/janitor-audit` — full skill inventory.
- `/janitor-usage` — parses conversation history to compute which
  skills actually fired vs which are dead weight; the creator's own
  run found 4 of 35 installed skills in use, with the other 31 eating
  context for no benefit. That is exactly the "Skills That Never
  Fired" question below, automated.
- `/janitor-tokens` — context-window cost per skill.
- `/janitor-search` — compares local skills against GitHub.
- `/janitor-fix` — auto-fix proposed (dry-run by default; never
  deletes without explicit confirmation).

Decide before building: run skills-janitor against this repo's package skill
source under `home/dot_agents/packages/*/skills/{local,vendor}/`, repo-local
skills under `.agents/skills/`, and the rendered `~/.claude/` / `~/.agents/`
skill installs first. If its `/janitor-usage` output answers the dark-skill
question and its `/janitor-audit` output answers the coverage question, reuse it
directly. If we need repo-specific output shape (repo-path-glob granularity,
mapping back to package ownership, integration with `code-gardening`), fork or
vendor the relevant bits rather than starting from scratch. The auditor
sketched above remains the fallback if neither path works.

### Subagent context overhead

Codex injects the full `AGENTS.md` as the synthetic first message of
every subagent task. For focused review-style subtasks this is
overhead and tends to be ignored.

Evaluate a short variant, about 30-50 lines, capturing only the rules
every subtask must obey:

- path discipline;
- address Prateek by name;
- no breadcrumbs;
- validators must pass;
- plan docs are not live specs;
- subagents return findings only.

Two implementation paths:

- **A**: `.agents/AGENTS-subagent.md` referenced from dispatcher
  configuration.
- **B**: a skill such as `subagent-conventions` that loads on demand.

Pick A if Codex / Claude Code dispatch can inject a specific file.
Otherwise pick B and add a dispatcher preamble that explicitly invokes
the skill.

### Skills that never fired

In the sampled dotfiles sessions, these skills did not fire:

- `repo-guideline-site`
- `markdown-converter`
- `image-gen-nano-banana`
- `ask-questions-if-underspecified`
- `using-git-spice`
- `ask`
- `ci-autofix-loop`
- `mcporter-skillifier`
- `swift-patterns`
- `ios-simulator-skill`
- the `hig-*` suite

iOS/HIG/Swift skills are expected dark because they are out of scope
for dotfiles. The others deserve one look at their `description`
frontmatter to check whether the "Use when..." pattern would fire for
plausible dotfiles tasks. `ask-questions-if-underspecified` and
`ci-autofix-loop` are especially worth checking.

No removals are proposed. Weakly-firing skills are cheap because only
descriptions load at startup. Suppress only if a skill is actively
misfiring.

### Open questions

- Should this be a script, a skill, or a one-off audit report?
- Can the dispatcher inject a subagent-specific instruction file?
- Are there skills with weak descriptions that should have fired but
  did not?
- Should hierarchical `AGENTS.md` files be introduced anywhere, or is
  root-only still the right shape?
- Which routing-shaped content belongs in `AGENTS.md`, and which
  procedural content belongs in skills?

### Validation criteria

- Run the auditor (or skills-janitor) against recent Claude Code and
  Codex logs.
- Verify it reports known areas such as chezmoi, docs lifecycle, and
  skill maintenance.
- Confirm it does not recommend removing dark skills that are simply
  out of scope for dotfiles.
- If a subagent instruction variant is added, run one focused review
  subagent and verify it receives only the intended reduced context.

## References

### Repo-state patterns

- [Quickwit CLAUDE.md (root)](https://github.com/quickwit-oss/quickwit/blob/main/CLAUDE.md)
- [Quickwit ADR / gaps / deviations framework](https://github.com/quickwit-oss/quickwit/tree/main/docs/internals/adr)
- [OpenAI — Harness engineering: leveraging Codex in an agent-first world](https://openai.com/index/harness-engineering/)
- [OpenAI — Unlocking the Codex harness: how we built the App Server](https://openai.com/index/unlocking-the-codex-harness/)
- [Latent Space — Extreme Harness Engineering for Token Billionaires](https://www.latent.space/p/harness-eng)
- [Ryan Lopopolo (@_lopopolo) on X](https://x.com/_lopopolo)
- [AI Engineer Europe — Harness Engineering talk (YouTube)](https://www.youtube.com/watch?v=am_oeAoUhew)
- [Mitchell Hashimoto — My AI Adoption Journey (harness engineering origin)](https://mitchellh.com/writing/my-ai-adoption-journey)
- [Augment Code — How to write good AGENTS.md files (pair-every-prohibition study)](https://www.augmentcode.com/blog/how-to-write-good-agents-dot-md-files)
- [Zed `.rules` (Rules Hygiene meta-section)](https://github.com/zed-industries/zed/blob/main/.rules)

### Runtime patterns

- [Anthropic — New in Claude Managed Agents: dreaming, outcomes, and multiagent orchestration](https://claude.com/blog/new-in-claude-managed-agents)
- [VentureBeat — Anthropic introduces "dreaming," a system that lets AI agents learn from their own mistakes](https://venturebeat.com/technology/anthropic-introduces-dreaming-a-system-that-lets-ai-agents-learn-from-their-own-mistakes)
- [The New Stack — Anthropic will let its managed agents dream](https://thenewstack.io/anthropic-managed-agents-dreaming-outcomes/)
- [Hermes Agent — Nous Research](https://hermes-agent.nousresearch.com/)
- [nousresearch/hermes-agent on GitHub](https://github.com/nousresearch/hermes-agent)
- [The New Stack — OpenClaw vs. Hermes Agent: The race to build AI assistants that never forget](https://thenewstack.io/persistent-ai-agents-compared/)
- [Better Stack — Hermes: The Self-Improving Agent That Gets Smarter Every Day (YouTube)](https://www.youtube.com/watch?v=HdxtLpL9CC8)
- [Tech Edge AI-ML — Inside Hermes Agent (YouTube)](https://www.youtube.com/watch?v=_fEOmnyaRRM)
- [AgentsLab-Ritik — How to Build a Self-Improving Code Agent With RAG (YouTube)](https://www.youtube.com/watch?v=XklD9jw8LpQ)
- [Orkhan Javadli — How to Build Self-Improving AI Agents in 2026 (YouTube)](https://www.youtube.com/watch?v=4fowNz3ASfk)
- [r/AgentsOfAI — Finally an open-source stack for agents that actually "self-improves" (Future AGI)](https://www.reddit.com/r/AgentsOfAI/comments/1sx18mq/finally_an_opensource_stack_for_agents_that/)
- [r/ClaudeAI — I built an autonomous engineering agent on top of Claude Code](https://www.reddit.com/r/ClaudeAI/comments/1ta3rsi/i_built_an_autonomous_engineering_agent_on_top_of/)
- [alinaqi/claude-bootstrap on GitHub](https://github.com/alinaqi/claude-bootstrap)

### Verifiability and theory

- [o-mega — Self-Improving AI Agents: The 2026 Guide](https://o-mega.ai/articles/self-improving-ai-agents-the-2026-guide)
- [HyperAgents — cross-domain self-improvement transfer (Meta, UBC, Oxford, NYU, 2026-03-19)](https://o-mega.ai/articles/self-improving-ai-agents-the-2026-guide)
- [agentskills.io open standard for portable agent skills](https://agentskills.io)

### Raw research dump

The full engine + WebSearch dump that fed the Part 2-4 sections is not
committed to this repo. It lived at
`~/Documents/Last30Days/self-improving-agents-raw-v3.md` during the research
pass.
