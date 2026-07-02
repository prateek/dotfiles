---
status: active
doc_type: plan
owner: Prateek
created: 2026-07-01
updated: 2026-07-02
related:
  - ../adr/0007-default-loaded-plugin-policy.md
  - ../../home/dot_agents/packages/core/skills/local/decomment/SKILL.md
  - ../../home/dot_agents/packages/core/skills/local/code-gardening/SKILL.md
  - ../../.agents/skills/agent-skill-management/SKILL.md
status_detail: "Approved in crit review 2026-07-02; implementation in progress."
---

# Decomment Skill Plan

Add a machine-wide `decomment` skill that deletes AI-written comment slop from
code the agent wrote. It runs automatically at the end of code tasks, and the
user can invoke it directly (`/decomment` in Claude Code, `$decomment` in
Codex). The plan also fixes the standing-instruction problems that would
otherwise neuter the skill, and ships an eval suite so a regression shows up
in a benchmark instead of a code review.

## Current Situation

Claude litters code with comments that narrate or restate it, and the cleanup
lands on the operator. Evidence from the local agentsview store (May–July
2026):

- Recurring feedback like "remove comments like `// The config snapshot
  fetcher requires...`", "remove any/all comments we've added in the
  stack", and "remove the comments above `a.closer = func() error {`". Ten
  such messages on 2026-07-01 alone.
- A work Slack thread confirms the pattern is team-wide and had grown
  noticeably worse in the week before the thread. One report there: a
  dedicated comment-removal skill regressed to deleting no comments at all,
  until its author rewrote it to be more severe.

That thread produced the two artifacts this plan builds on: Cody's `decomment`
skill, shared for cribbing, and John's write-time prevention prompt.

Skill auto-triggering is also broken for Claude on this machine, which decides
how "runs automatically" has to work:

- Since April, `code-gardening` fired in 2 of 2,128 Claude sessions, against
  20 of 280 Cursor sessions. The AGENTS.md directive to use it has been in
  place the whole time.
- Claude's most-fired skill is `write-for-humans` (49 sessions). It is the
  only skill backed by a plain-English "apply by default" directive at the top
  of the instruction file.
- Claude Code caps the skill listing at 1% of the context window (1,536 chars
  per skill) and, over budget, drops the descriptions of least-used skills
  entirely, keeping names only (<https://code.claude.com/docs/en/skills.md>).
  Roughly 60 installed skills blow that budget, so most trigger descriptions
  never reach the model. Dropping least-used skills first makes the failure
  self-reinforcing: an unseen skill stays unused, and an unused skill stays
  unseen.

## Cody's Skill (source material)

A complete SKILL.md. The plan adapts it; the adaptation notes are in the path
forward below. Snapshot (internal identifiers renamed for publication; rules
and structure unchanged):

````markdown
---
name: decomment
description: >-
  Prune and refine comments in code: delete restating, redundant, or stale
  comments and trim bloated doc comments down to their contract. Subtractive
  only — never adds comments or refactors code. Use before pushing a PR, or
  when asked to decomment, clean up comments, or trim comments on a branch,
  diff, PR, or file.
user_invocable: true
---

# Decomment

Prune and refine comments. Goal: **fewer and smaller comments**. Most
AI-written comments fail a test below — delete or shorten them.

This is subtractive: delete or shorten comments only. Never add comments
(except a minimal linter-floor godoc) and never refactor the code under
cover of a comment pass.

## The core question

Before keeping a comment, ask: **"If I deleted this, what would a reader
fail to figure out from the code alone?"** If nothing, delete it.

A comment isn't free: it's read, distrusted for staleness, and kept in
sync on every edit. Comments that restate code bury the ones that matter.

Bias hard toward deletion. A pass that deletes nothing and keeps most
comments is the signature of under-pruning, not of unusually good
comments — re-scan. The escape hatches below ("real WHY," length isn't
the smell) justify keeping a *minority*; invoking them on most comments
is rationalizing.

## Failure modes

Scan for these in order.

### 1. Same fact explained on N sites

BAD: A non-obvious fact re-explained everywhere it's touched.

GOOD: Explain it once, on the symbol that establishes it. Others stay
quiet or say `see Foo`.

WHY: N copies rot in N–1 places on the next edit.

**Bad** — "-1 means unlimited" explained twice:
```go
// Limit returns the max, or -1 for unlimited.
func (c Config) Limit() int

// Allow reports whether n fits. Note: a limit of -1 means
// unlimited, so this always returns true in that case.
func (c Config) Allow(n int) bool
```
**Fix** — state it once on the owner; the other describes itself:
```go
// Limit returns the max, or -1 for unlimited.
func (c Config) Limit() int

// Allow reports whether n fits under the limit.
func (c Config) Allow(n int) bool
```

### 2. Implementation details on an exported API

BAD: Exported-symbol doc describes internals ("batched internally",
"polls every minute"), wiring ("always non-nil because..."), or
integration narrative.

GOOD: Doc gives a one-line summary of what it does, then only the
contract — what callers pass, get back, and can rely on.

WHY: Docs are for callers; how it works lives in the code and rots when
the code changes.

**Bad** — doc leaks construction and wiring:
```go
// Snapshot exposes a per-process view of per-key entry counts,
// populated by polling the Redis-backed cache that the stats writer
// cron publishes to. Reads happen on the query hot path.
//
// Always non-nil at every wiring site — when the cache is disabled
// NewSnapshot returns a no-op implementation whose Get returns an
// empty map and whose Start/Close do nothing, so callers never need
// to nil-check either the snapshot or its map.
type Snapshot interface { ... }
```
**Fix** — keep only the contract:
```go
// Snapshot maintains a Redis-backed cache of per-key entry counts.
type Snapshot interface { ... }
```

### 3. Doc comments on unexported functions

BAD: An unexported func, method, or helper carries a godoc — *any*
godoc. Restating the signature, spelling out a contract, documenting a
precondition, or explaining architecture rationale all count.

GOOD: No doc comment — delete it entirely. The name and body are the
documentation.

WHY: The only reader is already in the file reading the implementation.
There's no external caller to hand a contract to, so nothing — not a
precondition, not rationale — earns a godoc here.

No exceptions. There is no "subtle helper" carve-out, and you never trim
the lead to a tighter doc — delete the whole comment. A genuinely
load-bearing precondition belongs inline at the code that depends on it,
which decomment does not add.

**Bad** — restates a self-evident helper:
```go
// buildKey constructs the Redis key for the given tenant and slug.
func buildKey(tenant, slug string) string {
    return tenant + ":" + slug
}
```
**Fix** — delete:
```go
func buildKey(tenant, slug string) string {
    return tenant + ":" + slug
}
```

**Bad** — godoc carrying a real precondition; still deleted (unexported):
```go
// sendAll applies the volume thresholds, returning false if the
// request should be dropped. Callers must fill req's buckets first.
func (c *client) sendAll(req *request) bool { ... }
```
**Fix** — delete the whole godoc, not just the restating lead:
```go
func (c *client) sendAll(req *request) bool { ... }
```

### 4. Inline comments narrating the code

BAD: An inline comment restates what the next line(s) plainly do.

GOOD: Delete it. Inline comments are for a non-obvious WHY, never the
WHAT.

WHY: Any competent reader gets the WHAT from the code; narration is noise
that still has to be kept in sync on every edit.

**Bad** — comment restates a loop:
```go
// Sum the sizes of all items.
total := 0
for _, it := range items {
    total += it.Size
}
```
**Fix** — delete:
```go
total := 0
for _, it := range items {
    total += it.Size
}
```

**Bad** — comment restates a guard:
```go
// Return early if the context was cancelled.
if ctx.Err() != nil {
    return ctx.Err()
}
```
**Fix** — delete:
```go
if ctx.Err() != nil {
    return ctx.Err()
}
```

**Bad** — a "why" that actually narrates how the implementation works.
This describes what the next call does and the mechanics of a
collaborator — restatement wearing a reason's clothes:
```go
// X is multi-region, so the sync client needs the rate limit to weight
// per-region traffic into credits during refresh.
c.volume.UpdateRateLimit(rl)
```
**Fix** — delete. Litmus: does the comment state a fact you can't get
from the code in front of you, or narrate what that code does? If the
latter — even phrased as a reason — delete.

### 5. Trivial restatement

BAD: Doc paraphrases the identifier and adds nothing. `Foo is the foo`,
`NewFoo returns a Foo`, fields restating their name.

GOOD: Delete inline and field comments outright.

WHY: It carries no new information and must be kept in sync on every
rename.

**Exception:** golint requires a comment on exported types/funcs (not
fields). Keep a one-line floor like `// Name implements cron.Job.`;
the floor is fine when there's nothing to add.

**Bad** — linter-required godoc padded with filler:
```go
// WriterConfig defines the stats cache writer cron job configuration.
type WriterConfig struct { ... }

// WriterParams holds the dependencies for creating a WriterJob.
type WriterParams struct { ... }
```
**Fix** — trim to the floor (can't delete; the linter needs it):
```go
// WriterConfig configures the writer cron job.
type WriterConfig struct { ... }

// WriterParams are the params for NewWriterJob.
type WriterParams struct { ... }
```

**Bad** — field restates its name:
```go
type Params struct {
    // Redis is a redis client.
    Redis *redis.Client
}
```
**Fix** — delete (fields aren't linter-flagged):
```go
type Params struct {
    Redis *redis.Client
}
```

**Bad** — default value restated:
```go
type Config struct {
    // ChunkConcurrency caps how many chunks run in parallel.
    // Defaults to 8.
    ChunkConcurrency int `yaml:"chunkConcurrency"`
}

func (c *Config) setDefaults() {
    if c.ChunkConcurrency == 0 {
        c.ChunkConcurrency = 8
    }
}
```
**Fix** — drop "Defaults to N"; it lives in `setDefaults` and rots
independently. Keep what the field does:
```go
type Config struct {
    // ChunkConcurrency caps how many chunks run in parallel.
    ChunkConcurrency int `yaml:"chunkConcurrency"`
}
```

**Bad** — arithmetic the reader can do from the literals on adjacent
lines (rife in tests):
```go
// 1 credit/byte makes credit consumption equal to byte volume, so a
// 1-credit budget is exceeded after a single 10-byte write.
cfg.CreditsPerStoredByte = 1.0
```
**Fix** — delete the derivation. Keep only an *intent* clause if one is
present: "consume enough to blow past the budget" earns its place; the
re-derived numbers do not.

Same goes for any code-restating doc — enum values, struct-tag values,
default args. If the source is a few lines away, the comment will drift.

## Test comments

Tests get the same rules, with one sharpener. Keep a test comment only
when it states the test's **intent** or the non-obvious **property a
case proves** — "why this case exists," "what would be surprising here,"
"this assertion holds because the system does NOT convert / shares the
budget / attributes the drop here." Delete everything that narrates
setup mechanics or restates an assertion.

Litmus: **does this tell me WHY this test does what it does, or narrate
WHAT it sets up / asserts?** Narration → delete.

**Keep** — the non-obvious thing the assertion proves:
```go
// Credit thresholds pass through as-is (no unit conversion).
require.Equal(t, want, got)
```

**Delete** — narrates what the setup code plainly does:
```go
// Send logs so the volume client refreshes and emits consumed tenant
// metrics.
for i := 0; i < n; i++ { send(t, log) }
```

## Scope

Resolve scope yourself before reading files:

- **Bare run / current branch** — review only the branch's own changes.
  In a git-spice stack, diff against the branch's base (falling back to
  `master`): `git diff --name-only "$(git merge-base <base> HEAD)" -- "*.go"`.
  Only added/modified comments are in scope — leave pre-existing ones alone.
- **Working tree** — `git diff --name-only HEAD` (bare `git diff` misses
  staged-only edits) + `git ls-files --others --exclude-standard`.
  Added/modified comments only.
- **Commit range `A..B`** — `git diff --name-only A..B`. Added/modified
  comments only.
- **Explicit file(s)** — every comment in the file is in scope.

Not Go-specific: apply the same rules to any language in scope.

## Procedure

1. **Read each file fully.** A diff-added comment may duplicate an
   existing one you can only spot with full context (still edit only the
   in-scope comment).
2. **Classify every in-scope comment** against the modes above. Watch
   for: repeated phrasing across symbols; multi-paragraph godoc; docs on
   unexported funcs; inline comments narrating the next lines; one-liners
   restating the identifier.
3. **Use `Edit`**, never whole-file rewrites.
4. **Respect the linter floor:** exported types/funcs keep one minimal
   line if you've nothing substantive; never delete entirely.
5. **Don't touch:** generated files (`// Code generated by ...`, `.gen.`,
   `.pb.go`), license headers, `//go:`/`//nolint`/`//revive:` directives,
   anything the user flags keep.
6. **Leave everything unstaged** — don't stage or commit; the caller
   diffs the working tree to review.
7. **Report** briefly what was removed/trimmed, grouped by file.

## Anti-patterns

- **Don't swap a bad comment for another bad one.** If it can't pass the
  core question, delete.
- **Don't keep a comment for sunk cost.**
- **Don't add comments** — decommenting is subtractive (except a minimal
  linter-floor godoc).
- **Don't refactor the code** under cover of a comment pass; flag bad
  code instead.
- **Don't delete a real WHY for being long.** Length isn't the smell —
  restatement is.
- **A long comment that's mostly mechanics or restatement IS the smell.**
  Don't let "it's a real WHY" shield a comment that narrates how the code
  works.
````

## John's Prompt (source material)

A write-time "Code Generation Style" block, reported as "somewhat effective but
not completely". Verbatim:

```markdown
# Code Generation Style

- New files must not include copyright or license banner comments at the top. Do not add legacy file headers to new files. Existing files that already have such headers should keep them unless removal is explicitly requested.

- Never use fancy Unicode characters (arrows, bullets, dashes, etc.) or parenthetical dash in code or comments. Use plain ASCII equivalents: `->` not `→`, `*` not `•`.

- Never leave "slop" comments that narrate what was added, removed, or moved. Examples of slop:
  - `// NB: validation was moved to the map layer`
  - `// Removed: old validation logic`
  - `// Added: new metric for X`
- Comments should explain WHY, not describe the diff.

- NEVER remove or rewrite existing comments in code you are editing unless the comment is factually wrong due to your change. Pre-existing comments were written by humans for good reasons -- they explain intent, constraints, or non-obvious behavior. The "no slop" rule above applies only to comments YOU are adding, not to comments already in the codebase.
```

The last bullet is the scoping idea this plan borrows: protect pre-existing
human comments and leave the agent's own additions fair game.

## Current Issues

1. **A standing rule forbids the cleanup.**
   [`home/dot_agents/AGENTS.md`](../../home/dot_agents/AGENTS.md) line 39
   materializes into every Claude and Codex session and fights any decomment
   pass. It plausibly contributed to the refusal behavior reported in the
   thread:

   ```markdown
   - NEVER remove code comments unless you can prove that they are actively false. Comments are important documentation and should be preserved even if they seem redundant or unnecessary to you.
   ```

2. **Description-based triggering doesn't reach Claude.** The skill-listing
   budget drops descriptions (see above), so a new skill's trigger conditions
   would never be seen. In an over-budget session the model sees only names:

   ```text
   The following skills are available for use with the Skill tool:
   - code-gardening
   - code-simplifier
   - write-for-humans
   ...
   ```

   The only trigger channel proven to work on this machine is a plain-English
   directive in the instruction file.

   *Fix (details in the path forward):* raise Claude's skill-listing budget
   (`skillListingBudgetFraction`) so descriptions load again, and back every
   must-run skill with a plain-English directive in AGENTS.md. The directive
   always loads; the description is best-effort.
3. **Skill references use a sigil Claude doesn't act on.** In
   [`home/dot_agents/AGENTS.md`](../../home/dot_agents/AGENTS.md) line 54,
   `$code-gardening` reads like a shell variable; nothing tells Claude it
   means "invoke the skill". 2-of-2,128 firing is the measurable result:

   ```markdown
   - Use `$code-gardening` when you are touching durable state, hit a parser or config error, suspect a failure may be pre-existing, or do not trust your read of the code yet.
   ```

   *Fix (details in the path forward):* write skill references in plain
   English: "use the code-gardening skill". No `$` or `/` prefixes in
   instruction files; those are typing affordances, not prose. Migrate the
   existing sigil references in the machine-wide AGENTS.md and in this repo's
   root AGENTS.md and CLAUDE.md.

4. **Under-pruning regression risk.** The one documented failure mode of a
   decomment skill is drifting back to deleting nothing; without an eval
   tripwire this would go unnoticed.
5. **Ironic-process risk.** Loading examples of bad comments into every session
   can increase their frequency (the pink-elephant concern raised in the
   thread). Prevention guidance must stay short and example-free in the
   always-loaded file; examples belong inside the skill, which loads only when
   it runs.

## Proposed Path Forward

One SKILL.md source serves both agents: `core` package skills render to
`~/.claude/skills` (Claude) and `~/.agents/skills` (Codex) at `chezmoi apply`,
and the AGENTS.md edits reach both through the `~/.claude/CLAUDE.md` symlink.
The skill is user-invocable out of the box: `/decomment` in Claude Code
(`user-invocable` defaults to true) and `$decomment` in Codex via the
openai.yaml interface.

### New skill: `home/dot_agents/packages/core/skills/local/decomment/SKILL.md`

Frontmatter is `name` + `description` only (repo validator's required set;
~830 chars, under the 1,536 cap):

```yaml
---
name: decomment
description: >-
  Prune comments in code you wrote or modified: delete restating, narrating,
  redundant, and slop comments; trim bloated doc comments down to their
  contract. Subtractive only — never adds comments or refactors code.
  Triggers aggressively: run as a final pass at the end of ANY nontrivial
  code-writing task before reporting done, and before any commit, PR, or
  handoff. Apply by default unless told to skip. Also use on explicit asks
  like "decomment", "remove comments", "too many comments", "comment slop",
  or "clean up comments" on a file, diff, branch, or PR. On automatic runs,
  scope is only comments added or modified by the current work — never
  pre-existing comments. Do not use for prose or docs (write-for-humans),
  for syncing comments that drifted from behavior (code-gardening), or as
  cover for refactoring (code-simplifier).
---
```

The closing "Do not use for" clauses are routing boundaries, not scope creep.
Three neighboring skills already touch comments, and the Claude Code docs name
overlapping descriptions as the main cause of wrong-skill loads. So the
description says who owns what: `write-for-humans` owns prose, `code-gardening`
owns comments that no longer match behavior (decomment deletes and shortens
but never corrects facts), and `code-simplifier` owns refactoring. Without
them, a "clean up comments" request could load the wrong skill, or a decomment
pass could drift into rewriting drifted comments or restructuring code. The
repo's other core skills draw the same boundaries: code-gardening has a
Trigger Boundaries section and write-for-humans a Scope paragraph.

Body: keep Cody's core question, deletion bias, five failure modes,
test-comment sharpener, procedure, and anti-patterns near-verbatim.
Adaptations:

- Two modes, mirroring `write-for-humans`: a final-pass mode (automatic; scope
  is the comments added or modified by the current work; "nontrivial" means
  anything beyond a typo-class fix) and an explicit mode (the user asked;
  scope per the Scope section).
- Scope gains a first bullet for automatic runs (only comments the agent
  authored this session or branch), then keeps Cody's four scopes unchanged.
- Hard protections: pre-existing comments not authored this session (unless
  the scope is explicit files and the user asked), generated files, license
  headers, directives (`//go:`, `//nolint`, shebangs), and anything the user
  flags. Repo-local AGENTS.md or CLAUDE.md comment rules win over this skill,
  which keeps it safe in work repos with their own comment policies.
- One added anti-pattern: don't skip the final pass because the diff looks
  clean. Scan, and report "nothing to prune" if that is true.
- A cross-reference section with pass order: `code-simplifier` refactors, then
  `decomment` prunes comments, then `write-for-humans` handles PR and commit
  prose. A comment that is wrong about behavior is drift and belongs to
  `code-gardening`; decomment only deletes or shortens.
- Language framing: examples stay Go (matching where the mined pain lives),
  fronted by a language-mapping section: doc-comment equivalents, the
  linter-floor rule collapsing to plain deletion where no linter demands a
  comment, the Python private-docstring nuance, per-language directives, and
  generated-file markers, plus one shell example of inline narration.

Plus `agents/openai.yaml`, matching code-gardening's Codex interface metadata.
Its default prompt restates the skill description, so both agents get the same
instructions.

### Fix the trigger channels

- In [`home/dot_agents/AGENTS.md`](../../home/dot_agents/AGENTS.md), replace
  line 39 with three bullets: never remove or rewrite pre-existing comments
  (not written this session or branch) unless provably false; comments must
  explain WHY, never narrate the diff or restate adjacent code; and use the
  decomment skill as a final pass on any nontrivial code change before
  reporting done, committing, or handing off. No slop examples in this file
  (issue 5); they live in the skill.
- Write skill references in plain English, dropping the sigils. Line 54
  becomes "Use the code-gardening skill when you are touching durable
  state, ...". Claude reads `$code-gardening` as a shell variable, and the
  2-of-2,128 firing rate is the result. Migrate the remaining sigil
  references in the machine-wide AGENTS.md and in this repo's root AGENTS.md
  and CLAUDE.md in the same change.
- Set `"skillListingBudgetFraction": 0.04` in the hand-maintained managed
  fragment (`home/.chezmoitemplates/claude-settings-managed.json.tmpl`, merged
  last into `~/.claude/settings.json` by
  `home/dot_claude/modify_private_settings.json.tmpl`) so skill descriptions
  survive into context (issue 2). Two implementation findings changed the
  original design: Claude Code never reads a user-level `settings.local.json`,
  so the managed merge is the only chezmoi-durable home for the key (that
  file is retired outright, since its remaining keys were equally dead); and
  on
  this machine ~73 skills need roughly 7.2k tokens, so the first pick of 0.02
  still dropped never-fired skills while 0.04 keeps every description.
  `SLASH_COMMAND_TOOL_CHAR_BUDGET` is the env-var fallback. This trades
  context for reliability, in the spirit of
  [ADR 0007](../adr/0007-default-loaded-plugin-policy.md); measure with a
  headless `claude -p "/context"` after apply.
- In `code-simplifier`, append one line to its comment bullet: "For a
  dedicated comment-pruning pass, use the decomment skill after simplifying."

### Evals: `decomment/evals/`

skill-creator format (`evals.json` + `setup_fixture.sh` + `files/`), modeled on
[code-gardening's evals](../../home/dot_agents/packages/core/skills/local/code-gardening/evals/evals.json)
(fixtures, git-init special case) and write-for-humans' greppable
counting-rule assertions:

1. `explicit-decomment-dense-file`: Go fixture planting all five failure
   modes as roughly 11 uniquely-greppable marker comments, plus four keepers
   (a real WHY, `//go:generate`, `//nolint`, a license header), a padded
   linter-floor godoc that must be trimmed rather than deleted, and a
   `// Code generated` file that must stay byte-identical. Expectations: all
   markers gone, keepers verbatim, no new comments, no non-comment lines
   changed, nothing staged.
2. `git-scope-discipline`: the fixture script commits a base with human
   comments, including one mildly redundant pre-existing comment as the trap,
   then overlays uncommitted slop-heavy changes. On a bare "decomment" run the
   overlay slop dies, both pre-existing comments survive verbatim, the agent
   demonstrates diff-based scoping, and the tree is left unstaged.
3. `generation-no-slop` (`mode: generate`, zsh): the prompt adds a `--dry-run`
   flag to a script and never mentions comments. Expectations: no narration
   comments, no diff-narration, at most two new comments each stating a
   non-obvious WHY, pre-existing comments untouched. This tests the automatic
   channel. Fall back to a Python fixture if zsh judging proves flaky.
4. `borderline-under-pruning-guard`: 12 individually-defensible planted slop
   comments plus 3 genuine keepers; the prompt is "this package has too many
   comments, trim it". Expectations: at least 9 of 12 markers deleted, all
   keepers survive, linter floors trimmed rather than deleted. This is the
   regression tripwire for issue 4.
5. `python-report-slop`: a Python report generator carrying slop mined
   verbatim from public-repo sessions (section labels like '# Stats' and
   '# Save results', trailing comments restating dict literals, a
   private-helper docstring restating its name) plus real keepers, including
   the escape-WHY comment lifted from this repo's own eval viewer.
6. `zsh-envfile-slop`: a zsh script with numbered section banners and
   step-narration comments mined verbatim from public-repo sessions; the
   prompt is the operator's real historical feedback line ("remove all the
   self-evident/obvious/redundant/verbose comments ..."). Keepers: a
   shellcheck directive and a secrets-WHY comment.

#### Comparative benchmark: new skill vs Cody's vs John's prompt

Run the same evals (all six) across four arms: no skill as the baseline,
John's prompt packaged as a minimal skill, Cody's skill (the benchmark ran
against his original text; the committed baseline renames its internal
identifiers, rules unchanged), and the new skill.
The two borrowed arms live as plain markdown under `evals/baselines/`,
deliberately not named `SKILL.md` so the package renderer and validator never
treat them as installable skills. The eval runner materializes each arm into a
temp skill directory, one iteration per arm, and per-arm pass rates are
compared via the harness benchmark output and
`scripts/eval-review.py --previous`.

Acceptance: the new skill matches or beats Cody's on every eval. John's
arm should compete only on eval 3 (generation): prevention and cleanup are
different jobs, and this plan ships both.

Results (2026-07-02, mechanical grading; expectation pass rates):

| eval | none | john | cody | new |
| --- | --- | --- | --- | --- |
| 1 dense-file | 80% | 53% | 100% | 100% |
| 2 git-scope | 88% | 88% | 100% | 100% |
| 3 generation | 100% | 100% | 100% | 100% |
| 4 borderline | 60% | 80% | 100% | 100% |
| 5 python-report | 100% | 100% | 100% | 100% |
| 6 zsh-envfile | 100% | 100% | 100% | 100% |

Three observations worth keeping. Explicit cleanup prompts carry most of the
signal on small files, so evals 5 and 6 sit at ceiling for every arm and act
as regression guards (keepers survive, nothing added) rather than arm
discriminators. The skill arms separate from the baselines on scope
discipline (eval 2: none and john touch pre-existing comments) and on
borderline severity, where the new skill deletes 11-12 of 12 planted markers
per rep against Cody's consistent 10 (three reps each; the strengthening
edits for exported-const floors, constant derivations, and wiring narration
came from the first benchmark round's misses). Eval 2's original
"strictly beats" criterion was unreachable: both skills hit 100% because
Cody's bare-run scoping also protects pre-existing comments there.

#### Grounding fixtures in real sessions

Done for this plan (a 2026-07-01 pass over the agentsview store): FTS-search
user messages for removal feedback, then pull the comments Claude wrote in
those sessions from their Edit calls. Fixtures recreate these patterns with
fresh names and code, and the quotes below carry the same renaming; no
work-repo code or identifiers land in this public repo. The mined catalog,
mapped to the fixture that plants it:

1. Constant and field comments restating the identifier (failure mode 5;
   evals 1 and 4): `// DropReasonRateLimit is used when items were dropped
   because the batch exceeded a rate limit`.
2. Inline narration ahead of a call (mode 4; eval 1): `// Apply batch
   limit drops before usage attribution.` directly above
   `s.enforceLimits(ctx, decisions)`.
3. Godocs on unexported functions and test helpers (mode 3; evals 1 and 4):
   `// queryDiscarded reads cumulative discarded (dropped) volume for a key
   on the global bucket.`
4. Test setup narration (test rules; eval 1's `_test.go`): `// The config
   snapshot fetcher requires exactly one object in the snapshot, so seed
   the fake with an empty config.` This is the comment quoted in the
   feedback that started this plan.
5. The same fact explained at N sites (mode 1; eval 1): "the threshold
   lives only on the global bucket, so the request targets the global
   bucket path directly" appeared twice near-verbatim in one session's
   edits, and `// Experimental until usage tracking is enabled in CI
   environments.` was duplicated on adjacent wiring lines.
6. Diff and temporal narration (John's rule; the prevention bullets and
   eval 3): `// It is safe to call more than once (Close was previously a
   no-op, so callers may double-close).`
7. Individually-defensible mechanics that the operator still deleted (eval 4's
   borderline set): `// reportCheckTimeout must cover two collector
   polls (each up to ~2m) plus validation within a single activity
   invocation.` It reads like a WHY; it narrates arithmetic.
8. A borderline keeper for contrast (eval 4's keeper set): `// Internal batches
   are never enforced.` above an assertion states the property the case
   proves, which is exactly what the test-comment rule keeps.

The operator's own severity bar from the feedback ("remove all the comments
you've created unless you're 150% sure they capture some insight that is
non-trivial") sets eval 4's acceptance threshold.

A second mining pass covers sessions from repos verified public on GitHub
(`gh api repos/<owner>/<repo>` visibility check: prateek/dotfiles,
wesm/agentsview, tomasz-tomczyk/crit, and others). Public-repo material can be
used verbatim, so evals 5 and 6 carry the mined slop unaltered: Python
section-label narration ('# Stats', '# Render workflows', '# Save results'),
trailing comments restating dict literals ('"✓",  # ✓'), zsh step narration
('# sanity checks', '# build env content', '# write the file'), and numbered
section banners. Eval 6's prompt is the operator's real feedback line from a
dotfiles session, verbatim. Anonymization drops personal paths and session
context; the code patterns themselves are public.

### Validation and rollout

Standard agent-skill pipeline (see
[Agent Skill Management](../../.agents/skills/agent-skill-management/SKILL.md)):
`validate-agent-packages`; render core skills and plugin marketplace to temp
roots plus `--check`; `make test-agent-skill-packages test-claude-settings
test-codex-config`; `audit-skill-context --agent codex .`;
`render-agent-core-skills --check-live`; `chezmoi apply`. Then run the eval
suite via the skill-creator harness into transient iteration directories, one
per comparative-benchmark arm, and review with `scripts/eval-review.py`. Only
`evals/` sources are committed; iteration directories are not.

Post-apply checks: `decomment/` present in both live skill roots; `/decomment`
in the slash menu; `/doctor` and `/context` confirm decomment's and
code-gardening's descriptions survive the listing budget; a bare "decomment"
smoke test in a scratch git repo; a smoke test in the work monorepo, where
repo-local comment rules must win.

Single commit, because the AGENTS.md directive must not land without the
skill: `feat(skills): add decomment core skill and rescope comment rules`.

### Risks

- The skill-listing budget is measured, not guaranteed: 0.04 covers today's
  ~73 skills, and adding skills eventually outgrows it again. The AGENTS.md
  directive always loads; the description stays best-effort.
- Line 39 currently protects all comments, so the rescope widens what the
  agent may delete. Both new surfaces state the same boundary (pre-existing
  comments are untouchable), and eval 2 regression-tests it.
- A machine-wide skill can collide with repo-local comment policies. The
  "repo rule wins" protection is the escape hatch, and the monorepo smoke test
  checks it.
