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

# Decomment

Prune and refine comments. Goal: **fewer and smaller comments**. Most
AI-written comments fail a test below — delete or shorten them.

This is subtractive: delete or shorten comments only. Never add comments
(except a minimal linter-floor doc comment) and never refactor the code
under cover of a comment pass.

Examples below are Go; the rules and failure modes apply to any language in
scope. Translate the Go terms:

- Doc comments: godoc maps to Python docstrings, JSDoc/TSDoc, rustdoc,
  javadoc.
- Linter floor: golint/revive's exported-comment rule maps to whatever your
  project's linter enforces (pydocstyle, eslint jsdoc rules). Where no
  linter demands a comment, there is no floor — delete outright.
- Python nuance: a private helper keeps a one-line docstring only where the
  project's linter or convention requires docstrings. A docstring that
  restates the function name is slop like any other.
- Directives are hard-protected in every language: `//go:`, `//nolint`,
  `# noqa`, `# type: ignore`, `# shellcheck`, `// eslint-disable`,
  `# pylint:`, shebangs, and editor or linter control comments.
- Generated-file markers: `Code generated ... DO NOT EDIT`, `@generated`,
  `.pb.go` and friends.

## Two modes

- **Final-pass mode** (automatic). At the end of any nontrivial code-writing
  task — before reporting done, committing, opening a PR, or handing off —
  run this skill over the work you just did. Scope is only the comments you
  added or modified in the current session or branch. "Nontrivial" means
  anything beyond a typo-class or single-line fix.
- **Explicit mode**. The user asked: "decomment", "remove comments", "clean
  up comments", "too many comments", or similar, optionally naming a file,
  diff, branch, PR, or commit range. Resolve scope per the Scope section.

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

**Bad** — same failure in any language; shell:
```zsh
# build the request body
body="$(jq -n --arg k "$key" '{key: $k}')"
```
**Fix** — delete; the comment restates the assignment.

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

Wiring narration gets no unexported pass: a struct-field or setup comment
narrating who calls what, which collaborator stays warm or passive, or how
components are flushed together is this same failure whether the symbols
are exported or not. Delete it.

### 5. Trivial restatement

BAD: Doc paraphrases the identifier and adds nothing. `Foo is the foo`,
`NewFoo returns a Foo`, fields restating their name, constants restating
their name or trigger condition (`DropReasonX is used when X happened`).

GOOD: Delete inline and field comments outright.

WHY: It carries no new information and must be kept in sync on every
rename.

**Exception:** golint requires a comment on exported types, funcs, consts,
and vars (not fields). Keep a one-line floor like
`// Name implements cron.Job.`; the floor is fine when there's
nothing to add. A padded exported-const comment gets trimmed to its floor,
never kept whole.

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

**Bad** — a constant's value re-derived from collaborators' mechanics:
```go
// retryBudget must cover two upstream timeouts (each up to ~3s) plus one
// backoff cycle.
const retryBudget = 7 * time.Second
```
**Fix** — delete; it narrates arithmetic over other components' timing and
rots the moment any of them changes. Sounding like a WHY doesn't save it —
it's a derivation, and derivations drift.

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

- **Final-pass run** (automatic, end of a task) — only the comments you
  added or modified in this session's work: your uncommitted working-tree
  changes, plus your own commits on the current branch if you made any.
  Pre-existing comments are out of scope.
- **Bare run / current branch** — review only the branch's own changes.
  In a git-spice stack, diff against the branch's base (falling back to
  `master`): `git diff --name-only "$(git merge-base <base> HEAD)"`.
  Only added/modified comments are in scope — leave pre-existing ones alone.
- **Working tree** — `git diff --name-only HEAD` (bare `git diff` misses
  staged-only edits) + `git ls-files --others --exclude-standard`.
  Added/modified comments only.
- **Commit range `A..B`** — `git diff --name-only A..B`. Added/modified
  comments only.
- **Explicit file(s)** — every comment in the file is in scope.

### Hard protections

Never touch, in any mode:

- Pre-existing comments you did not author, unless the user named the file
  explicitly and asked for a full pass.
- Generated files (`// Code generated by ...`, `.gen.`, `.pb.go`).
- License and copyright headers.
- Directives: `//go:`, `//nolint`, `//revive:`, shebangs, and editor or
  linter control comments in any language.
- Anything the user flags keep.

If a repo-local AGENTS.md or CLAUDE.md sets its own comment policy, the
repo rule wins over this skill.

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
5. **Respect the hard protections** above.
6. **Leave everything unstaged** — don't stage or commit; the caller
   diffs the working tree to review.
7. **Report** briefly what was removed/trimmed, grouped by file.

## Anti-patterns

- **Don't swap a bad comment for another bad one.** If it can't pass the
  core question, delete.
- **Don't keep a comment for sunk cost.**
- **Don't add comments** — decommenting is subtractive (except a minimal
  linter-floor doc comment).
- **Don't refactor the code** under cover of a comment pass; flag bad
  code instead.
- **Don't delete a real WHY for being long.** Length isn't the smell —
  restatement is.
- **A long comment that's mostly mechanics or restatement IS the smell.**
  Don't let "it's a real WHY" shield a comment that narrates how the code
  works.
- **Don't skip the final pass because the diff looks clean.** Scan, and
  report "nothing to prune" if that is true. Deleting zero after scanning
  is a finding; skipping the scan is not.

## Cross-reference

Pass order when several skills apply to the same change: the
code-simplifier skill first (behavior-preserving refactors), then this
skill (comment pruning on the result), then the write-for-humans skill
(PR descriptions, commit messages, and other prose).

A comment that is *wrong about behavior* is drift, not slop — the
code-gardening skill decides what is true and rewrites it. Decomment only
deletes or shortens; it never corrects facts.
