---
status: active
doc_type: research
owner: Prateek
created: 2026-09-23
updated: 2026-09-23
related:
  - skill-invocation-frontmatter-research.md
  - self-improving-agents.md
status_detail: "Build log and handoff for the ralph-architecture workflow, an unattended plan/implement/review loop that commits and fast-forwards a real branch. Self-contained: the adversarial review that shaped it is reproduced in Appendix A and the whole script in Appendix B. One round has run. Covers what the design has to get right, the fourteen defects the review caught before first run, and the one guardrail that is currently too strict."
---

# Running a Ralph Loop as a Claude Code Workflow

## Question

Can an unattended loop pick its own architecture work, implement it, review
it, and land it on `main` without a human in the loop — and what does it take
to make that safe enough to actually run?

Built and run once against `serial-sync` on 2026-09-22. It landed. The
interesting material is not the loop, which is obvious; it is the set of
things that have to be true before you dare start it.

This document is self-contained. The script is reproduced in Appendix B and
the adversarial review that shaped it in Appendix A; neither original is
durable, since the script lives unmanaged at
`~/.claude/workflows/ralph-architecture.js` and the review log was written to
`$TMPDIR`. Restoring the workflow means copying Appendix B back to that path.

It is kept out of chezmoi deliberately. The loop commits from inside a
worktree, and a managed file in the tree it is about to commit from is a
foot-gun; that also means edits to the live file are not backed up anywhere
but here.

## What was built

630 lines, reproduced in Appendix B. Per round, five agents, sequential:

1. **Provision** (Sonnet, low) — `orca worktree create --no-parent
   --base-branch main` cuts a fresh Orca worktree, verifies `HEAD` equals the
   base tip and the tree is clean.
2. **Plan** (Opus, xhigh, zero prior context) — picks exactly one deepening
   candidate, writes a standalone plan to `$TMPDIR`.
3. **Implement** (Sonnet, xhigh) — builds the plan, stages, commits nothing.
4. **Review** (Opus, xhigh, fresh context) — reviews the staged diff, fixes,
   writes the single commit, verifies the commit, fast-forwards `main`.
5. Retirement is folded into the reviewer rather than being a sixth agent.

Parameterised by `args`: `iterations`, `base`, `namePrefix`, `repo`, `orca`,
`keepWorktrees`, `skillPath`, `coauthor`. Invoke by path, since the tool only
promises to resolve names from a project-level `.claude/workflows/`:

```
Workflow({scriptPath: "~/.claude/workflows/ralph-architecture.js",
          args: {iterations: 1}})
```

### The one round that has run

5 agents, 66 minutes wall clock, 802k subagent tokens, 585 tool calls. Landed
`serial-sync` `de5832c → 0a374fc` as a true fast-forward, +449/−185 across 11
files: the EPUB package edit session refactor that had been open since that
repo's deepening plan.

Worth recording because it shows what the gates are for. The reviewer declined
to take the implementer's byte-identity claim on trust — it extracted the base
commit with `git archive` into scratch, rebuilt the output baseline itself, and
diffed it against both a host run and a Docker end-to-end run of a freshly
built image. It got the full suite green in a container with Calibre and
EPUBCheck, including three tests that cannot run bare-host, because
`AGENTS.md` made that check conditional on the kind of change and the
conditional was threaded into its prompt.

It also found a real semantic change the implementer had not flagged — a
package-document directory that had been `"."` became `""`, which changes how
an absolute manifest href resolves — judged it a hardening rather than a
regression, and wrote it into the commit body instead of reverting it. Given a
gate it could fail, it used it.

## What we learned

### An interactive skill cannot be automated without cutting it in half

`/mattpocock:improve-codebase-architecture` carries `disable-model-invocation:
true`. In Claude Code that flag means the model cannot invoke the skill via
the Skill tool at all — it is excluded from the model's skill listing, and
only a human typing the slash command can reach it. That behaviour, and which
harnesses honour it, is established in
[skill-invocation-frontmatter-research.md](skill-invocation-frontmatter-research.md);
the same capture found all 14 flagged mattpocock skills absent from the
listing.

What is new here is the workaround and its real cost.

The workaround is cheap: point the subagent at the `SKILL.md` path and tell it
to follow the process. The cost is that skills carrying this flag are usually
flagged *because* they are interactive, and their process assumes a human. The
architecture skill writes an HTML report, asks "which of these would you like
to explore?", and then runs a grilling loop. Two of its three phases are
conversation. Automating it meant instructing the planner to skip the report
(nobody can open it mid-run), skip the question, and self-select its own top
recommendation.

Generalises: before automating a slash-command skill, read it for the places
it stops and waits. Those are not incidental. `mattpocock:handoff` has the
same shape — it wants to write to the OS temp directory, which is wrong for
any caller that wants the output filed somewhere durable.

### Git will not let a worktree check out a branch another worktree holds

`main` is checked out in the canonical clone, so `git checkout main` from any
Orca worktree fails outright:

```
fatal: 'main' is already used by worktree at '/Users/prateek/code/github.com/prateek/serial-sync'
```

Anything merging into `main` from elsewhere has to use `git -C <that checkout>
merge --ff-only <sha>`.

That in turn has a trap. `git -C <path> merge` merges into whatever `HEAD`
that checkout is on, which is not necessarily the branch you looked up
earlier. A human switching branches in the main clone mid-round is enough: the
`main` ref can still be at the expected sha and `git status` can still be
clean, so a naive gate passes and the merge advances the *human's* branch. The
fix is to re-derive the checkout from `git worktree list` immediately before
merging, assert `symbolic-ref --short HEAD` equals the base branch before and
after, and merge the commit SHA rather than the branch name.

### A worktree per round is a correctness fix, not just tidiness

The first draft ran every round in one shared checkout. That is silently
wrong: after round 1 merges to `main`, round 2's planner is scanning whatever
branch the shared checkout is still on. Cutting a fresh worktree from `main`
per round makes the staleness structurally impossible rather than something a
prompt has to remember.

Orca-managed rather than raw `git worktree` because the rounds show up as
cards, carry a status and comment, and survive for inspection when something
goes wrong. Two mechanics that bit:

- `orca worktree create --json` returns `result.worktree.id` as the full
  `<repoId>::<path>`. Both halves are needed for every later command; a bare
  repo id is not a worktree id.
- Orca prefixes the branch with the git username (`prateek/ralph-1`), so
  provisioning has to report the branch it actually got rather than the name
  it asked for.

### Adversarially review the script before the first run

`gpt-6-astra` at high effort, read-only, against the finished script, via
`acpx`. Fourteen findings, five of them blockers. Full text in Appendix A. The
one that mattered most:

> `PROVISION_SCHEMA` declared a field `worktreeId`. The script read `wt.id`.

Every round would have created a worktree, failed the guard, logged "could not
provision", and stopped. The `orca worktree rm` command would have
interpolated `id:undefined`. The workflow could not have run at all, and no
syntax check catches it — the schema and the reader are 280 lines apart and
both are valid JavaScript.

That class of defect is the argument for the review. A workflow script is
plumbing between an LLM's declared output shape and a script's assumptions
about it, and nothing type-checks that boundary.

Three more of the five are worth stating as rules rather than incidents:

- **Verify after committing, never before.** An unstaged fix can make a suite
  pass while the index still holds broken code, and hooks can rewrite files
  after you looked. Order must be stage → commit → assert clean tree → verify
  the committed snapshot → merge. What you verify and what you merge have to
  be the same tree.
- **Never keep a fallback you have also forbidden.** The draft had a `git
  branch -f` path for the "no worktree holds the base" case, two paragraphs
  above a line reading "never force anything". Delete the fallback; that case
  returns `left-on-branch`.
- **Let the script pick the mode, not the prompt.** The implementer's
  `blocked` flag never reached the reviewer, whose salvage branch was keyed on
  "if the implementer was blocked". Salvage is now selected in JavaScript,
  with the merge and retirement instructions absent from the prompt entirely
  rather than present-but-forbidden.

### Constrain every string the script compares literally

`outcome` was a free-form string tested against `"merged"`. A reviewer
returning `"Merged"` would have merged the code and then been recorded as a
failure. JSON Schema `enum` on every such field, plus a rule that a success
claim missing its evidence — commit SHA, verification result, confirmation
that the base ref was checked — is downgraded rather than believed:

```js
if (outcome === 'merged') {
  const missing = []
  if (review.verifyPassed !== true) missing.push('verifyPassed')
  if (!review.commitSha) missing.push('commitSha')
  if (review.baseRefConfirmed !== true) missing.push('baseRefConfirmed')
  if (missing.length) outcome = 'merged-unverified'   // and stop the loop
}
```

### Guardrails have to be able to fail

The review's phrasing that stuck: *a command you did not run is not a command
that passed.* Several prompts told an agent to verify something without giving
it any way to report that it could not. The pattern now is that every gate
names its stop condition, and the reviewer is told explicitly that leaving
work on a branch is a good outcome and a forced merge is not.

### Workflow script constraints worth knowing

- Plain JavaScript, not TypeScript. `Date.now()`, `Math.random()`, and argless
  `new Date()` throw — they would break workflow resume. Pass timestamps via
  `args`, and vary anything that needs uniqueness by index. This is why round
  worktree names carry the round number and collisions are resolved by the
  provisioning agent rather than by a random suffix.
- `agent()` returns `null` when the agent is skipped or dies. A null from a
  stage that mutates state is an *unknown* outcome, not a failed one: the
  reviewer can commit, merge, and retire the worktree and then die before
  returning. The script must claim nothing in that case, which is why that
  path records `reviewer-unknown` and stops rather than reporting the worktree
  as preserved.
- `node --check` reports "Illegal return statement" on a valid script. The
  runtime wraps the body in an async function, so top-level `return` is legal.
  To syntax-check, wrap the body yourself:

  ```sh
  { echo 'const args=null, budget=null;'
    echo 'const agent=async()=>({}), log=()=>{}, phase=()=>{};'
    echo 'async function __body(){'
    sed 's/^export const meta = {/const meta = {/' ralph-architecture.js
    echo '}'
  } > /tmp/wrap.mjs && node --check /tmp/wrap.mjs
  ```

## Open problems

**The retirement gate is too strict to ever fire.** Merged rounds are supposed
to have their worktree deleted. The gate requires `git status --porcelain
--ignored` to be empty, on the reasoning that an ignored file might be work
the merge did not preserve. But `serial-sync`'s `AGENTS.md` requires a
fixture-backed `run` for output changes, which always leaves `publish/` and
`state/` behind. So every round keeps its worktree and auto-retirement is dead
code. Confirmed on the one round that has run.

The fix is to let the gate skip paths the repo's own `.gitignore` marks as run
output while still blocking on anything else ignored. That weakens a safety
gate, so it is a deliberate decision rather than a cleanup. Unresolved as of
2026-09-23.

**No ledger of rejected ideas.** Each planner starts cold. Landed work is
visible in the code, so it will not be re-proposed — but a candidate a human
would reject can be re-derived every round. The ADR check inside the
architecture skill is the only backstop. Acceptable at three rounds; probably
not at ten.

**Nothing bounds a round's size.** The planner is told to pick something that
fits in one commit, and nothing enforces it. One round took 66 minutes.

**Findings 2, 7, 8, 10 and 11 in Appendix A are mitigated, not closed.** Each
now depends on an agent following an instruction rather than on the script
making the bad state unreachable. That is the weaker kind of guardrail.

## Suggested skills

For a session picking this up:

- `mattpocock:codebase-design` — the deepening vocabulary the whole loop is
  written in (module, interface, depth, seam, adapter, leverage, locality).
  The prompts use these terms precisely and a rewrite should keep doing so.
- `utils-agent:orca-cli` — before touching any provisioning or retirement
  step. Load the version-matched guide from the binary; the flags move.
- `utils-agent:acpx` — for the adversarial review lane. `agpt` resolved to
  `gpt-6-astra` at high effort via codex. Launch read-only, then audit the
  log's tool calls for writes; the permission flags are not a boundary.
- `workflow-authoring` — the script API reference. Required before editing the
  workflow.
- `core:testing-philosophy` — if changing what the reviewer is told to accept
  as proof.

## Appendix A: the adversarial review, in full

`gpt-6-astra`, high effort, read-only, 2026-09-22, against the pre-run draft.
Reproduced because the original log was written to `$TMPDIR`. Its verdict was
"I would block unattended use of this". All fourteen are applied in the script
in Appendix B; the parenthetical notes are mine.

**1. Blocker — provisioning returns `worktreeId`, the script requires `id`.**
A schema-conforming provisioner returns `{created: true, worktreeId, path}`;
the guard rejects it because `wt.id` is absent. Two such rounds create two
worktrees, report provisioning failures, and stop. *Fix: use `worktreeId`
consistently, including the retirement commands; require identity fields when
`created=true`.*

**2. Blocker — the forced removal gate does not prove deletion is safe.**
Ancestry of the commit says nothing about an unstaged correction, an untracked
file, ignored authored data, or another agent's later work in the same
worktree. All of those are destroyed by `worktree rm --force`. *Fix: require
worktree HEAD to equal the merged commit, `git status --porcelain --ignored`
to be empty, ancestry confirmed, and the Orca id to still resolve to the same
path — and forbid `reset --hard` or `clean` as a way to satisfy the check.*

**3. Blocker — passing verification is not bound to the committed snapshot.**
The reviewer tested the working tree, then staged and committed. An unstaged
fix can make tests pass while the index holds broken code; a failing hook can
trigger edits after verification. The gate only asked whether commands passed
at some point. *Fix: commit first, then verify that exact snapshot with a
clean tree; merge the recorded SHA and read back the result.*

**4. Blocker — the cached base-checkout path can become another branch's
checkout.** Preflight records where `main` lives. A human switches that
checkout to another clean branch mid-round. `main` can still be at the
expected SHA and `status --porcelain` empty, so the gates pass, and `git -C
<cached path> merge --ff-only` advances the human's branch. *Fix: re-resolve
the checkout immediately before landing and verify its symbolic HEAD, repo
identity, expected SHA and cleanliness; confirm afterwards which ref actually
moved.*

**5. Blocker — the fallback `git branch -f` can overwrite concurrent base
commits.** The agent checks A→C is a fast-forward; another process advances
the unchecked-out base A→B; `git branch -f main <branch>` replaces B with C.
The earlier ancestry check does not make this safe, and the command
contradicts the "never force anything" line in the same prompt. *Fix: remove
the fallback; return `left-on-branch` when no base checkout exists.*

**6. Major — the reviewer never receives the implementer's `blocked` flag.**
The script logs it but passes only `summary`. An implementer can return a
coherent partial change with `blocked=true`; the reviewer sees the change
without the blocking fact and follows the normal merge path, violating the
explicit salvage prohibition. *Fix: make salvage a script-selected mode on
`!impl || impl.blocked`, pass the reason, and omit the merge and removal
instructions entirely in that mode.*

**7. Major — successful states require almost none of their supporting
evidence.** Accepted by the draft schemas: `ready=true` with no resolved repo;
successful provisioning with no `headSha`; `{"outcome":"merged"}` with no
commit SHA or verification result; `outcome="Merged"` or `"merged "`, which
silently count as misses against a literal comparison; and the contradiction
`outcome="merged", verifyPassed=false`. *Fix: enums for outcome and severity,
conditionally required fields for success states, cross-field invariant
checks, and `cutFromBase === true` rather than "not explicitly false". Note
that validating the final response cannot protect mutations the reviewer has
already performed — landing needs its own pre-mutation gate.*

**8. Major — a pinned repo is not tied to the repo preflight inspects.** With
`args.repo` supplied, preflight checks it resolves but still runs its git
commands in the session repo, and `preflight.repoSelector` then overrides the
caller's pin. A caller can get a successful preflight for one repo, provision
another, and pass the first repo's base-checkout path into review. *Fix:
require the pin to equal the session repo's canonical Orca id and fail on
disagreement; an explicit pin must win over discovery.*

**9. Major — the discovered verification baseline is discarded.** Preflight
collects the mandatory commands from `AGENTS.md` and nothing consumes them; a
planner returning a short list causes both later prompts to emphasise that
list. `go test ./...` can pass while a conversion change never gets its
required Docker end-to-end run. *Fix: carry the baseline forward into both
prompts and require the reviewer to reconcile it against `AGENTS.md` and the
actual change; a required check that cannot run blocks the merge.*

**10. Major — plan filenames collide across runs.** Two runs picking the same
slug in round 1 write the same `$TMPDIR/ralph-plan-1-<slug>.md`, and one can
overwrite the other between planning and review. *Fix: bind the filename to
the round worktree name, refuse to overwrite, and verify the plan's identity
before consuming it. Also: the reviewer prompt called the base checkout the
only permitted path outside the worktree, which contradicted its need to read
the plan.*

**11. Major — a null reviewer result is an unknown outcome, but the report
implies preservation.** The reviewer can commit, merge and delete the worktree
and then die. The draft recorded `reviewer-failed`, said the worktree was
"left as-is", and excluded the round from the merged count. *Fix: record it as
unknown, stop, and claim nothing about either the base branch or the worktree
without reading them back. Never retry a destructive step on a missing
response.*

**12. Minor — retained-worktree accounting omits failure paths.** Failure
exits recorded `path`; the final collector read `worktree`. The summary could
omit every worktree deliberately retained for inspection. *Fix: one record
shape across all exits.*

**13. Minor — argument coercion changes the requested policy.** `iterations:
0` ran three rounds via `||`; the string `"false"` enabled `keepWorktrees`.
*Fix: validate a bounded integer and an actual boolean; default only when the
value is absent.*

**14. Minor — executable examples interpolate unquoted arguments.** An
overridden path containing spaces breaks the command; a name containing shell
metacharacters changes its meaning if the agent copies it literally. *Fix:
validate selectors, refs and names against a character allowlist and quote
every interpolation rather than leaving it to the agent.*

What the review judged sound: the `meta` literal and phase-title matching,
top-level control flow, guarding against direct dereference of null results,
the two-consecutive-misses counter, and using the existing base checkout with
`merge --ff-only` to sidestep the already-held-branch problem.

## Appendix B: the workflow script

`ralph-architecture.js` as run on 2026-09-22, with all fourteen Appendix A
findings applied. Restore it by writing this to
`~/.claude/workflows/ralph-architecture.js`. Invoke it by `scriptPath` rather
than by name — the Workflow tool only promises to resolve names from a
project-level `.claude/workflows/`.

```js
export const meta = {
  name: 'ralph-architecture',
  description: 'Ralph loop: each round gets a fresh Orca worktree cut from the base branch, an Opus planner picks one deepening candidate, Sonnet implements it, a fresh Opus reviewer commits, verifies the committed snapshot, and fast-forwards the base',
  whenToUse: 'Run N unattended rounds of architecture deepening on a repo, each round landing at most one candidate on the base branch in its own Orca worktree.',
  phases: [
    { title: 'Preflight', detail: 'confirm Orca is up, the repo is registered, and the base checkout is clean' },
    { title: 'Provision', detail: 'create this round Orca worktree, cut fresh from the base branch' },
    { title: 'Plan', detail: 'fresh agent, no context: scan the codebase and commit to one deepening candidate', model: 'opus' },
    { title: 'Implement', detail: 'build the plan in the round worktree, stage everything, commit nothing', model: 'sonnet' },
    { title: 'Review', detail: 'fresh agent: review, fix, commit, verify the commit, fast-forward the base, retire the worktree', model: 'opus' },
  ],
}

// ---------------------------------------------------------------------------
// Arguments. An absent value takes the default; a present but invalid value
// aborts rather than being silently coerced into one.
// ---------------------------------------------------------------------------

const bad = []

function intArg(name, dflt, min, max) {
  const v = args && args[name]
  if (v === undefined || v === null) return dflt
  if (!Number.isInteger(v) || v < min || v > max) {
    bad.push(name + ' must be an integer in [' + min + ', ' + max + '], got ' + JSON.stringify(v))
    return dflt
  }
  return v
}

function boolArg(name, dflt) {
  const v = args && args[name]
  if (v === undefined || v === null) return dflt
  if (typeof v !== 'boolean') {
    bad.push(name + ' must be a boolean, got ' + JSON.stringify(v))
    return dflt
  }
  return v
}

function strArg(name, dflt, pattern) {
  const v = args && args[name]
  if (v === undefined || v === null) return dflt
  if (typeof v !== 'string' || !pattern.test(v)) {
    bad.push(name + ' is not a safe value: ' + JSON.stringify(v))
    return dflt
  }
  return v
}

// No shell metacharacters, spaces, or quotes: these are interpolated into
// command examples the agents run.
const SAFE_REF = /^[A-Za-z0-9._\/-]{1,120}$/
const SAFE_NAME = /^[A-Za-z0-9._-]{1,60}$/
const SAFE_PATH = /^[A-Za-z0-9._\/-]{1,300}$/
const SAFE_SELECTOR = /^[A-Za-z0-9._:\/-]{1,200}$/

const ITERATIONS = intArg('iterations', 3, 1, 25)
const BASE = strArg('base', 'main', SAFE_REF)
const NAME_PREFIX = strArg('namePrefix', 'ralph', SAFE_NAME)
const REPO = strArg('repo', null, SAFE_SELECTOR)
const ORCA = strArg('orca', 'orca', SAFE_PATH)
const KEEP_WORKTREES = boolArg('keepWorktrees', false)
const SKILL_PATH = strArg('skillPath',
  '/Users/prateek/.agents/plugins/plugins/mattpocock/skills/improve-codebase-architecture/SKILL.md', SAFE_PATH)
const COAUTHOR = (args && typeof args.coauthor === 'string' && args.coauthor) ||
  'Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>'

if (bad.length) {
  log('Refusing to start. Invalid arguments: ' + bad.join('; '))
  return { aborted: true, reason: 'invalid arguments: ' + bad.join('; '), rounds: [] }
}

const NO_HUMAN = [
  'You are running unattended inside a workflow. No human will read your questions or approve anything mid-run.',
  'Never stop to ask. When a decision is genuinely ambiguous, pick the option you can defend, state the assumption in your return value, and continue.',
  'Your final text is a return value consumed by a script, not a message to a person.',
].join(' ')

function inWorktree(wt, extraPaths) {
  const allowed = ['Work inside ' + wt.path + '. Your first shell command is `cd ' + wt.path + '`; stay there. Every repo file you read or write is absolute and under ' + wt.path + '.']
  allowed.push('Other checkouts of this repo exist and a human may be working in them right now. Never read, edit, or run git against any path outside ' + wt.path + ', with these exceptions: ' + extraPaths + '.')
  return allowed.join(' ')
}

// ---------------------------------------------------------------------------
// Schemas. Successful states must carry the evidence the script relies on, and
// every string the script compares literally is an enum.
// ---------------------------------------------------------------------------

const PREFLIGHT_SCHEMA = {
  type: 'object',
  properties: {
    ready: { type: 'boolean', description: 'true only if the loop can safely provision worktrees and merge' },
    reason: { type: 'string' },
    repoSelector: { type: 'string', description: 'the id:<repoId> selector for the repo this checkout belongs to' },
    repoMatchesPin: { type: 'boolean', description: 'when the caller pinned a repo, true only if it is the same repo as this checkout' },
    baseWorktree: { type: 'string', description: 'absolute path of the checkout holding the base branch, or "none"' },
    baseSha: { type: 'string' },
    baseCheckoutClean: { type: 'boolean' },
    verifyCommands: { type: 'array', items: { type: 'string' }, description: 'the mandatory verification baseline named by AGENTS.md or CI config, including any conditional checks and the conditions that trigger them' },
  },
  required: ['ready', 'reason', 'verifyCommands'],
}

const PROVISION_SCHEMA = {
  type: 'object',
  properties: {
    created: { type: 'boolean' },
    failureReason: { type: 'string' },
    worktreeId: { type: 'string', description: 'the full <repoId>::<path> id, copied whole from result.worktree.id' },
    path: { type: 'string', description: 'absolute path of the new checkout' },
    branch: { type: 'string', description: 'branch the new worktree is on, from git rev-parse --abbrev-ref HEAD' },
    headSha: { type: 'string', description: 'full sha of the new worktree HEAD' },
    cutFromBase: { type: 'boolean', description: 'true only if HEAD is exactly the base branch tip and the tree is clean' },
  },
  required: ['created'],
}

const PLAN_SCHEMA = {
  type: 'object',
  properties: {
    abort: { type: 'boolean', description: 'true if no candidate is worth implementing this round' },
    abortReason: { type: 'string' },
    slug: { type: 'string', description: 'kebab-case name for the deepened module, 40 chars max' },
    title: { type: 'string', description: 'one line, imperative, in the style of this repo git log subjects' },
    rationale: { type: 'string', description: 'the friction this removes, in codebase-design vocabulary' },
    planPath: { type: 'string', description: 'absolute path of the plan markdown, written outside the repo' },
    filesInvolved: { type: 'array', items: { type: 'string' } },
    testStrategy: { type: 'string' },
    verifyCommands: { type: 'array', items: { type: 'string' }, description: 'commands that prove this specific change, in addition to the mandatory baseline you were given' },
    runnersUp: { type: 'array', items: { type: 'string' } },
  },
  required: ['abort'],
}

const IMPL_SCHEMA = {
  type: 'object',
  properties: {
    blocked: { type: 'boolean' },
    blockedReason: { type: 'string' },
    summary: { type: 'string', description: 'what you changed and any deviation from the plan, with the reason' },
    filesChanged: { type: 'array', items: { type: 'string' } },
    filesCreated: { type: 'array', items: { type: 'string' } },
    verifyPassed: { type: 'boolean' },
    verifyRan: { type: 'array', items: { type: 'string' }, description: 'the commands you actually ran' },
    verifyOutput: { type: 'string', description: 'tail of the verification output, failures verbatim' },
  },
  required: ['blocked', 'summary'],
}

const FINDING_SCHEMA = {
  type: 'object',
  properties: {
    severity: { type: 'string', enum: ['blocker', 'major', 'minor'] },
    file: { type: 'string' },
    summary: { type: 'string' },
    fixed: { type: 'boolean' },
  },
  required: ['severity', 'summary', 'fixed'],
}

const REVIEW_SCHEMA = {
  type: 'object',
  properties: {
    outcome: { type: 'string', enum: ['merged', 'left-on-branch', 'abandoned'] },
    branch: { type: 'string' },
    commitSha: { type: 'string', description: 'required when outcome is merged or left-on-branch' },
    baseSha: { type: 'string', description: 'base branch sha read back AFTER the merge; required when outcome is merged' },
    baseRefConfirmed: { type: 'boolean', description: 'true only if you confirmed the base checkout symbolic HEAD was the base branch immediately before AND after merging' },
    verifyPassed: { type: 'boolean', description: 'true only if every command passed against the committed snapshot with a clean tree' },
    verifyRan: { type: 'array', items: { type: 'string' }, description: 'the commands you actually ran against the commit' },
    findings: { type: 'array', items: FINDING_SCHEMA },
    worktreeRetired: { type: 'boolean' },
    notes: { type: 'string', description: 'anything the next round or the human needs to know' },
  },
  required: ['outcome', 'findings', 'notes'],
}

// ---------------------------------------------------------------------------
// Prompts
// ---------------------------------------------------------------------------

function baselineBlock(preflight, plan) {
  const lines = ['## Verification', '']
  lines.push('MANDATORY baseline from AGENTS.md, discovered before this run started. Treat it as the floor, not the ceiling:')
  lines.push('')
  const baseline = (preflight.verifyCommands || [])
  lines.push(baseline.length ? baseline.map(c => '  - ' + c).join('\n') : '  - (preflight found none; read AGENTS.md yourself and derive them)')
  lines.push('')
  if (plan && plan.verifyCommands && plan.verifyCommands.length) {
    lines.push('Plus the checks this plan calls for:')
    lines.push('')
    lines.push(plan.verifyCommands.map(c => '  - ' + c).join('\n'))
    lines.push('')
  }
  lines.push('Reconcile both lists against AGENTS.md and against what this change actually touches. AGENTS.md makes some checks conditional on the kind of change; if this change trips one of those conditions, that check is mandatory too even though no list above names it.')
  lines.push('Read the full output of everything you run. A command you did not run is not a command that passed. If a required check cannot run in this environment, that blocks the merge — say so rather than substituting a weaker one.')
  return lines.join('\n')
}

function planPrompt(i, wt, preflight) {
  return [
    NO_HUMAN,
    '',
    inWorktree(wt, 'you may read ' + SKILL_PATH + ', and you write your plan file to $TMPDIR'),
    '',
    'You are the planner for round ' + i + ' of an architecture deepening loop. You have no memory of earlier rounds; that is deliberate. This checkout was cut from ' + BASE + ' moments ago, so it already contains whatever earlier rounds landed. Read the code and the history, not a ledger.',
    '',
    '## Method',
    '',
    'Read ' + SKILL_PATH + ' and follow its "Explore" step in full. Two deliberate deviations, because there is no human in this loop:',
    '',
    '1. Skip the HTML report. Nobody can open it mid-run. Write a plan markdown instead (below).',
    '2. Skip the grilling loop and the "which would you like to explore?" question. Select the top recommendation yourself and commit to it.',
    '',
    'Call the Skill tool with "mattpocock:codebase-design" for the architecture vocabulary and use those terms exactly: module, interface, depth, seam, adapter, leverage, locality. Apply the deletion test to anything you suspect is shallow.',
    '',
    'Read CONTEXT.md for the domain vocabulary and every ADR under docs/adr/ before you propose anything. An ADR that forbids your candidate is a reason to drop it, unless the friction is real enough to justify reopening it, which you must then say explicitly in the plan.',
    '',
    'Weight recent history: `git log --oneline -40` shows where the codebase is hot. Deepening pays off where change keeps landing.',
    '',
    '## Choosing',
    '',
    'Pick exactly ONE candidate: the best ratio of friction removed to blast radius. Prefer a candidate that one agent can land in a single coherent commit with the tests to prove it. Reject anything that needs a decision only the repo owner can make.',
    '',
    'Set abort=true if the honest answer is that nothing is worth deepening right now, or if every real candidate is too large for one commit. An aborted round is a legitimate outcome; a made-up candidate is not.',
    '',
    '## The plan file',
    '',
    'Write the plan to $TMPDIR (fall back to /tmp) as `ralph-plan-' + wt.name + '-<slug>.md` and return its absolute path. The `' + wt.name + '` part is this worktree name and makes the filename unique; do not drop it, and do not overwrite an existing file — if that exact path already exists, stop and set abort=true, because something else is using your scratch space.',
    '',
    'It must live outside the repo: this worktree may be deleted when the round ends, and the plan has to outlive it. The implementer gets this file and nothing else, so it must stand alone:',
    '',
    '- The module being deepened, named in CONTEXT.md vocabulary, and the seam being drawn',
    '- The target interface: exact signatures, what sits behind the seam, what callers see',
    '- Every file to touch and what changes in each',
    '- Which existing tests must keep passing unchanged, which move, which die, and what new tests prove the deepening',
    '- The durable surfaces AGENTS.md says must stay in sync with this kind of change',
    '- Explicit non-goals, so the implementer does not widen the diff',
    '',
    baselineBlock(preflight, null),
    '',
    'You do not run these. Record in the plan which of them this change makes mandatory, and return any additional checks in verifyCommands.',
    '',
    'Do not write code. Do not touch git beyond reading history. Do not create or switch branches; you are already on the round branch.',
  ].join('\n')
}

function implPrompt(plan, i, wt, preflight) {
  return [
    NO_HUMAN,
    '',
    inWorktree(wt, 'you may read the plan file at ' + plan.planPath),
    '',
    'You are the implementer for round ' + i + '. Build exactly what the plan says.',
    '',
    'Plan: ' + plan.planPath,
    'Candidate: ' + plan.title,
    'Branch: ' + wt.branch + ' (already checked out; do not create or switch branches)',
    '',
    'Read the plan first. If that file is missing or does not describe the candidate above, stop and set blocked=true; do not improvise a change from the title alone.',
    '',
    '## Build it',
    '',
    'Read every file the plan names before you change any of them. Follow AGENTS.md; it outranks the plan wherever they disagree, and say so in your summary when that happens.',
    '',
    'Stay inside the plan. Fix a cheap, directly-related papercut if you hit one; report anything broader instead of widening the diff.',
    '',
    'Keep the durable surfaces in sync as you go: AGENTS.md names which docs and skills must move with a behavior change. A deepening that leaves docs stale is not done.',
    '',
    baselineBlock(preflight, plan),
    '',
    'Report verifyPassed=false with the failure text verbatim rather than claiming a clean run; the reviewer will decide what to do. Never delete, skip, or weaken a test to make a suite pass.',
    '',
    '## Hand off',
    '',
    'Stage your work with explicit paths (`git add <path> ...`). Never `git add -A` or `git add .`. When you are done, `git status --porcelain` must show your work staged and nothing else modified — the reviewer verifies the commit, not your working tree, so anything you leave unstaged is work you are throwing away.',
    '',
    'Do NOT commit, merge, push, tag, or switch branches. The reviewer owns the commit.',
    '',
    'If you cannot carry the plan out, set blocked=true, explain precisely where it broke, and leave whatever you have staged. Do not improvise a different change.',
  ].join('\n')
}

function reviewPrompt(plan, impl, i, wt, preflight, salvage) {
  const head = [
    NO_HUMAN,
    '',
    inWorktree(wt, 'you may read the plan file at ' + (plan.planPath || '(none)') + ', and the merge step below names the one other checkout you may run git against'),
    '',
    'You are the reviewer for round ' + i + '. You did not write this code and have no memory of planning it. Review it as the diff of a colleague you respect but do not trust.',
    '',
    'Plan: ' + (plan.planPath || 'not written'),
    'Candidate: ' + plan.title,
    'Branch: ' + wt.branch,
    'Cut from ' + BASE + ' at: ' + (wt.headSha || 'unknown'),
    'Implementer summary: ' + (impl ? impl.summary : 'the implementer produced no result at all'),
    'Implementer verification: ' + (impl && impl.verifyPassed ? 'reported passing — verify it yourself anyway' : 'reported FAILING or unknown'),
  ]

  if (salvage) {
    return head.concat([
      '',
      '## This is a SALVAGE round. Do not merge.',
      '',
      'The implementer ' + (impl ? 'reported itself blocked: ' + (impl.blockedReason || 'no reason given') : 'died without returning anything') + '.',
      '',
      'Whatever is in this worktree is unfinished by definition. Your only job is to leave it in a state a human can pick up:',
      '',
      '1. Read the plan, then `git status` and `git diff --staged` to see how far it got.',
      '2. If what is staged is coherent on its own — it compiles, it does not break existing tests, and it is a sensible partial step — commit it on this branch with a subject that says it is partial, and return outcome=left-on-branch.',
      '3. If it is not coherent, commit nothing and return outcome=abandoned. Leave the files exactly where they are; do not `git reset`, `git checkout --`, or `git clean` anything.',
      '',
      'Put the reason the round stopped, and what a human would need to do next, in notes.',
      '',
      'You may NOT merge, fast-forward, push, or touch any checkout outside this worktree. You may NOT delete this worktree — a human needs to look at it.',
      '',
      'Record the state of this worktree for the Orca card:',
      '',
      '  ' + ORCA + ' worktree set --worktree \'id:' + wt.worktreeId + '\' --workspace-status todo --comment \'<one line: what stopped and what is left>\' --json',
      '',
      'Set worktreeRetired=false. Findings may be empty; notes may not.',
    ]).join('\n')
  }

  const baseWt = preflight.baseWorktree && preflight.baseWorktree !== 'none' ? preflight.baseWorktree : null

  return head.concat([
    '',
    '## Review',
    '',
    'Read the plan, then `git diff --staged` AND `git status --porcelain`. Unstaged changes are a red flag: the implementer was told to stage everything it meant to ship. Decide deliberately whether each one belongs in the commit or should be discarded, and say which in notes. Judge the change on:',
    '',
    '- Does it do what the plan said, and is the result actually a deeper module? Would deleting the new seam concentrate complexity or just move it?',
    '- Correctness: the bugs a careful reader finds, not style. Trace the changed paths for real inputs.',
    '- Tests: do they exercise behavior through the new interface, or assert the implementation back at itself? Was any test weakened, skipped, or deleted to make the suite pass?',
    '- AGENTS.md compliance, including the durable surfaces it says must stay in sync.',
    '- Comments: prune narration and restatement the change introduced; keep rationale and directives.',
    '',
    'Fix what you find. Prefer the smallest correct fix. If a finding needs a decision the repo owner should make, do not guess: record it, leave the work on the branch, and do not merge.',
    '',
    '## Commit BEFORE you verify',
    '',
    'The order matters. Verifying a working tree and then committing proves nothing about what you committed: an unstaged fix can make a suite pass while the index still holds the broken version, and hooks can rewrite files after you looked. So:',
    '',
    '1. Stage everything you intend to ship, with explicit paths. Never `git add -A` or `git add .`.',
    '2. Commit. Match the subject style in `git log --oneline -15` exactly — read it before writing; do not impose conventional-commit prefixes if the repo does not use them. Subject imperative and concrete; body carries rationale and any deviation from the plan. End the message with this line, verbatim, on its own line after a blank line:',
    '',
    COAUTHOR,
    '',
    '3. Let hooks run. If a hook fails, read the output, fix the cause, amend, and retry. Never bypass a hook.',
    '4. `git status --porcelain` must now be empty. If a hook left changes behind, fold them in and amend until it is.',
    '5. Record the commit sha. You may amend this commit — it is yours, made this round. Never rewrite any commit you did not create this round.',
    '',
    baselineBlock(preflight, plan),
    '',
    'Run these NOW, against the committed snapshot, with `git status --porcelain` empty throughout. If anything fails: fix it, amend the commit, confirm the tree is clean again, and re-run from the top. What you verify and what you merge must be the same tree.',
    '',
    'Set verifyPassed=true only if every required command passed on output you read, against the final commit. Return the commands you ran in verifyRan.',
    '',
    '## Merge gate',
    '',
    'Fast-forward ' + BASE + ' onto your commit ONLY if all of these hold. Check each one; do not assume any of them.',
    '',
    '1. verifyPassed is true, against the final commit, with a clean tree.',
    '2. No unfixed blocker or major finding remains.',
    '3. ' + BASE + ' is still exactly at ' + (wt.headSha || 'the sha this worktree was cut from') + '.',
    '',
    'Then resolve the target checkout FRESH. Do not trust a path you were handed; a human may have switched branches in it while you were working.' +
      (baseWt ? ' Preflight last saw ' + BASE + ' in ' + baseWt + ', but re-derive it rather than assuming.' : ''),
    '',
    '  a. `git worktree list --porcelain` — find the checkout whose branch is refs/heads/' + BASE + '. If none holds ' + BASE + ', STOP: return outcome=left-on-branch. There is no safe fallback and you must not invent one.',
    '  b. `git -C <path> rev-parse --git-common-dir` must match this worktree\'s, proving it is the same repository.',
    '  c. `git -C <path> symbolic-ref --short HEAD` must equal exactly ' + BASE + '. If it does not, that checkout is on some other branch and merging into it would advance the wrong branch. STOP.',
    '  d. `git -C <path> status --porcelain` must be empty.',
    '  e. `git -C <path> rev-parse HEAD` must equal ' + (wt.headSha || 'the sha above') + '.',
    '  f. `git -C <path> merge --ff-only <your commit sha>` — merge the SHA, never the branch name.',
    '  g. Read back: `git -C <path> rev-parse HEAD` must now equal your commit sha, and `git -C <path> symbolic-ref --short HEAD` must still be ' + BASE + '.',
    '',
    'Set baseRefConfirmed=true only if you ran c and g and both passed. Report the post-merge sha in baseSha.',
    '',
    'If any check fails, or the fast-forward is refused: leave the commit on the branch, return outcome=left-on-branch, and say exactly what blocked it. A branch left behind is a good outcome; a forced merge is not.',
    '',
    'Never push to a remote. Never use --force, --force-with-lease, `git branch -f`, `git reset --hard`, or `git clean` anywhere in this task.',
    '',
    '## Retire the worktree',
    '',
    KEEP_WORKTREES
      ? 'Leave this worktree in place. Record its state on the Orca card:\n\n  ' + ORCA + ' worktree set --worktree \'id:' + wt.worktreeId + '\' --workspace-status <in-review if merged, todo otherwise> --comment \'<one line: outcome and why>\' --json\n\nSet worktreeRetired=false.'
      : [
          'Deleting a worktree destroys everything in it that is not reachable from ' + BASE + ', including untracked and ignored files. Retire it ONLY on outcome=merged, and only after ALL of these pass:',
          '',
          '  1. `git rev-parse HEAD` in this worktree equals the commit you merged. (Nothing new landed here after you merged.)',
          '  2. `git status --porcelain --ignored` is empty. Any tracked change, untracked file, or ignored file means there is content here that merging did not preserve. STOP and keep the worktree.',
          '  3. `git -C <base checkout> merge-base --is-ancestor <your commit sha> ' + BASE + '` exits 0.',
          '  4. `' + ORCA + ' worktree show --worktree \'id:' + wt.worktreeId + '\' --json` still reports path ' + wt.path + '. If the id now points somewhere else, STOP.',
          '',
          'Do not make those checks pass. If check 2 finds content, that is a signal to keep the worktree, never a cleanup task.',
          '',
          'Then `cd /tmp` so you are not standing inside the directory you are deleting, and run:',
          '',
          '  ' + ORCA + ' worktree rm --worktree \'id:' + wt.worktreeId + '\' --force --json',
          '',
          'Set worktreeRetired=true only if that succeeded. On any other outcome, or if any check above failed, leave the worktree in place, set worktreeRetired=false, say why in notes, and record it on the card:',
          '',
          '  ' + ORCA + ' worktree set --worktree \'id:' + wt.worktreeId + '\' --workspace-status todo --comment \'<one line: outcome and why>\' --json',
        ].join('\n'),
  ]).join('\n')
}

// ---------------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------------

phase('Preflight')
const preflight = await agent([
  NO_HUMAN,
  '',
  'Preflight for an unattended loop that will create Orca worktrees, commit in them, and fast-forward ' + BASE + '. Report, do not fix. Change nothing.',
  '',
  '1. `' + ORCA + ' status --json` — the app must be running and the runtime reachable.',
  '2. `' + ORCA + ' worktree current --json` — record this checkout repo id. The selector for later commands is `id:<repoId>`.',
  REPO
    ? '   The caller pinned the repo to ' + REPO + '. Resolve it with `' + ORCA + ' repo show --repo ' + REPO + ' --json` and set repoMatchesPin=true ONLY if it is the same repository as this checkout. If they differ, set ready=false: provisioning one repo while inspecting another is never what the caller meant.'
    : '   If the current directory is not an Orca worktree, find the repo with `' + ORCA + ' repo list --json` and match it to this checkout git remote. Set repoMatchesPin=true (no pin was given).',
  '3. `git worktree list --porcelain` — record which checkout holds refs/heads/' + BASE + '. Confirm with `git -C <that path> symbolic-ref --short HEAD` that it really is on ' + BASE + ', and `git -C <that path> status --porcelain` that it is clean. A dirty base checkout blocks every merge this loop would make.',
  '4. `git rev-parse ' + BASE + '` — record the base sha.',
  '5. Read AGENTS.md (and CLAUDE.md if present) and record the MANDATORY verification baseline it names, in verifyCommands. Include conditional checks along with the condition that triggers them, phrased so a later agent can tell whether its change trips them — for example "a Docker-based end-to-end run when changing browser/bootstrap, container runtime, or Calibre-backed conversion behavior". Do not invent commands, and do not reduce a conditional check to an unconditional one.',
  '',
  'Set ready=false if Orca is unreachable, if the repo does not resolve or does not match the pin, if ' + BASE + ' does not resolve, if no checkout holds ' + BASE + ' while its holder is dirty, or if you cannot find any verification commands.',
].join('\n'), { label: 'preflight', phase: 'Preflight', model: 'sonnet', effort: 'low', schema: PREFLIGHT_SCHEMA })

if (!preflight || !preflight.ready) {
  const why = preflight ? preflight.reason : 'the preflight agent returned nothing'
  log('Preflight blocked the run: ' + why)
  return { aborted: true, reason: why, rounds: [] }
}
if (REPO && preflight.repoMatchesPin === false) {
  log('Preflight says the pinned repo ' + REPO + ' is not the repo this checkout belongs to. Refusing to run.')
  return { aborted: true, reason: 'pinned repo does not match the session checkout', rounds: [] }
}

// An explicit pin wins over discovery; discovery only fills a blank.
const repoSelector = REPO || preflight.repoSelector || null
const repoFlag = repoSelector ? ' --repo ' + repoSelector : ''
log('Preflight clear. ' + BASE + ' at ' + (preflight.baseSha || 'unknown') + ' in ' + (preflight.baseWorktree || 'no worktree') +
    '; repo ' + (repoSelector || 'inferred') + '; ' + (preflight.verifyCommands || []).length + ' baseline checks')

const rounds = []
let consecutiveMisses = 0

// One record shape for every exit, so nothing retained falls out of the summary.
function record(i, outcome, extra) {
  const r = Object.assign({
    round: i,
    outcome: outcome,
    title: null,
    worktree: null,
    worktreeId: null,
    branch: null,
    worktreeRetired: false,
  }, extra || {})
  rounds.push(r)
  return r
}

for (let i = 1; i <= ITERATIONS; i++) {
  if (consecutiveMisses >= 2) {
    log('Stopping early: two consecutive rounds landed nothing. Rounds ' + i + ' through ' + ITERATIONS + ' skipped.')
    break
  }

  const wtName = NAME_PREFIX + '-' + i

  phase('Provision')
  const prov = await agent([
    NO_HUMAN,
    '',
    'Create the Orca worktree for round ' + i + ' of an architecture deepening loop. This is a mechanical provisioning step: create it, verify it, report it. Do not read or change any repo content.',
    '',
    'Run:',
    '',
    '  ' + ORCA + ' worktree create' + repoFlag + ' --name ' + wtName + ' --no-parent --base-branch ' + BASE + ' --comment \'ralph round ' + i + ': planning\' --json',
    '',
    '`--no-parent` keeps this independent of whatever worktree the loop is running in. `--base-branch ' + BASE + '` is deliberate: every round must start from the current ' + BASE + ' tip, not from a sibling branch.',
    '',
    'If the name is already taken, retry with ' + wtName + 'b, then ' + wtName + 'c, until one is free. Do not reuse, reset, or delete an existing worktree.',
    '',
    'From the create result take `result.worktree.id` WHOLE — it is `<repoId>::<path>` and both halves are needed later. Return it as worktreeId. Do not shorten it to the repo id.',
    '',
    'Then verify the checkout, substituting its path:',
    '',
    '  git -C <path> rev-parse --abbrev-ref HEAD    → return as branch',
    '  git -C <path> rev-parse HEAD                 → return as headSha (full sha)',
    '  git -C <path> rev-parse ' + BASE + '                → must equal headSha',
    '  git -C <path> status --porcelain             → must be empty',
    '',
    'Set cutFromBase=true only if BOTH the sha comparison and the clean-tree check passed. Set created=false with a failureReason if the create itself failed. If the create succeeded but verification did not, still return created=true with the worktreeId and path so the caller knows a worktree exists — and cutFromBase=false. Never try to repair it.',
  ].join('\n'), { label: 'provision:' + i, phase: 'Provision', model: 'sonnet', effort: 'low', schema: PROVISION_SCHEMA })

  if (!prov || !prov.created || !prov.worktreeId || !prov.path || !prov.branch) {
    const why = prov && prov.failureReason ? prov.failureReason : 'the provision agent returned nothing usable'
    log('Round ' + i + ': could not provision a worktree — ' + why)
    record(i, 'provision-failed', {
      reason: why,
      worktree: (prov && prov.path) || null,
      worktreeId: (prov && prov.worktreeId) || null,
    })
    consecutiveMisses++
    continue
  }

  const wt = {
    name: wtName,
    worktreeId: prov.worktreeId,
    path: prov.path,
    branch: prov.branch,
    headSha: prov.headSha || null,
  }

  if (prov.cutFromBase !== true) {
    log('Round ' + i + ': worktree ' + wt.path + ' is not provably cut from a clean ' + BASE + ' tip. Refusing to build on it; left in place.')
    record(i, 'provision-off-base', { worktree: wt.path, worktreeId: wt.worktreeId, branch: wt.branch })
    consecutiveMisses++
    continue
  }
  log('Round ' + i + ': worktree ' + wt.path + ' on ' + wt.branch + ' at ' + (wt.headSha || 'unknown').slice(0, 8))

  phase('Plan')
  const plan = await agent(planPrompt(i, wt, preflight), {
    label: 'plan:' + i, phase: 'Plan', model: 'opus', effort: 'xhigh', schema: PLAN_SCHEMA,
  })

  if (!plan || plan.abort || !plan.slug || !plan.planPath || !plan.title) {
    const why = !plan ? 'the planner returned nothing'
      : plan.abort ? (plan.abortReason || 'planner declined, no reason given')
      : 'planner returned an unusable plan (missing slug, title, or plan path)'
    log('Round ' + i + ': ' + why + '. Worktree ' + wt.path + ' left in place for inspection.')
    record(i, 'no-plan', { reason: why, worktree: wt.path, worktreeId: wt.worktreeId, branch: wt.branch })
    consecutiveMisses++
    continue
  }
  log('Round ' + i + ': ' + plan.title + (plan.runnersUp && plan.runnersUp.length ? ' (over ' + plan.runnersUp.length + ' runners-up)' : ''))

  phase('Implement')
  const impl = await agent(implPrompt(plan, i, wt, preflight), {
    label: 'implement:' + plan.slug, phase: 'Implement', model: 'sonnet', effort: 'xhigh', schema: IMPL_SCHEMA,
  })

  // Salvage is chosen by the script, not left to the reviewer to infer.
  const salvage = !impl || impl.blocked === true
  if (!impl) {
    log('Round ' + i + ': implementer returned nothing. Reviewer runs in salvage mode; no merge possible.')
  } else if (impl.blocked) {
    log('Round ' + i + ': implementer blocked — ' + (impl.blockedReason || 'no reason given') + '. Reviewer runs in salvage mode; no merge possible.')
  } else if (impl.verifyPassed === false) {
    log('Round ' + i + ': implementer reported failing verification. Reviewer will fix or leave it on the branch.')
  }

  phase('Review')
  const review = await agent(reviewPrompt(plan, impl, i, wt, preflight, salvage), {
    label: (salvage ? 'salvage:' : 'review:') + plan.slug, phase: 'Review', model: 'opus', effort: 'xhigh', schema: REVIEW_SCHEMA,
  })

  if (!review) {
    // The reviewer may have committed, merged, and retired the worktree before
    // dying. A missing answer proves nothing either way, so claim nothing.
    log('Round ' + i + ': reviewer returned nothing. Its effect on ' + BASE + ' and on ' + wt.path + ' is UNKNOWN — check both by hand before rerunning. Stopping the loop.')
    record(i, 'reviewer-unknown', {
      title: plan.title, worktree: wt.path, worktreeId: wt.worktreeId, branch: wt.branch,
      notes: 'reviewer died without returning; base branch and worktree state unverified',
    })
    break
  }

  const findings = review.findings || []
  const unfixed = findings.filter(f => !f.fixed)
  let outcome = review.outcome

  // A "merged" claim missing its evidence is not a merge we will count.
  if (outcome === 'merged') {
    const missing = []
    if (review.verifyPassed !== true) missing.push('verifyPassed')
    if (!review.commitSha) missing.push('commitSha')
    if (review.baseRefConfirmed !== true) missing.push('baseRefConfirmed')
    if (unfixed.some(f => f.severity === 'blocker' || f.severity === 'major')) missing.push('unfixed blocker/major findings')
    if (missing.length) {
      outcome = 'merged-unverified'
      log('Round ' + i + ': the reviewer says it merged but did not supply ' + missing.join(', ') +
          '. ' + BASE + ' may have advanced on unproven work — inspect it before continuing. Not counting this as a clean merge.')
    }
  }

  record(i, outcome, {
    title: plan.title,
    slug: plan.slug,
    planPath: plan.planPath,
    worktree: wt.path,
    worktreeId: wt.worktreeId,
    worktreeRetired: review.worktreeRetired === true,
    branch: review.branch || wt.branch,
    commitSha: review.commitSha || null,
    baseSha: review.baseSha || null,
    verifyPassed: review.verifyPassed === true,
    verifyRan: review.verifyRan || [],
    findings: findings,
    notes: review.notes,
  })

  log('Round ' + i + ': ' + outcome + (review.commitSha ? ' (' + review.commitSha.slice(0, 8) + ')' : '') +
      ', ' + findings.length + ' findings, ' + unfixed.length + ' left unfixed' +
      (review.worktreeRetired === true ? ', worktree retired' : ', worktree kept at ' + wt.path))

  if (outcome === 'merged') {
    consecutiveMisses = 0
  } else {
    consecutiveMisses++
    if (outcome === 'merged-unverified') {
      log('Stopping the loop: ' + BASE + ' moved without proof. Later rounds would build on it.')
      break
    }
  }
}

const merged = rounds.filter(r => r.outcome === 'merged')
const kept = rounds.filter(r => r.worktree && !r.worktreeRetired).map(r => r.worktree)
log('Done. ' + merged.length + ' of ' + rounds.length + ' rounds merged into ' + BASE + '.' +
    (kept.length ? ' Worktrees left for inspection: ' + kept.join(', ') : ' No worktrees left behind.'))
return { base: BASE, requested: ITERATIONS, rounds: rounds, merged: merged.map(r => r.title), keptWorktrees: kept }
```
