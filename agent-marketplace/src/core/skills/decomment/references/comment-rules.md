# Comment rules

Scan these failure modes in order for every in-scope comment. Each example is
Go, but the same tests apply to other languages: Go doc comments map to Python
docstrings, JSDoc/TSDoc, rustdoc, and Javadoc.

## One owner for each fact

Explain a non-obvious fact once, on the symbol that establishes it. Delete
repetitions at callers. When an in-scope comment duplicates a pre-existing
one, edit only the in-scope copy. A short `see Foo` pointer is enough when a
reader needs navigation.

```go
// Limit returns the max, or -1 for unlimited.
func (c Config) Limit() int

// Allow reports whether n fits under the limit.
func (c Config) Allow(n int) bool
```

The second doc need not explain `-1` again. Repeated explanations drift
independently.

## Caller contracts on exported APIs

Keep what callers pass, receive, and may rely on. Trim polling schedules,
construction wiring, and collaborator narratives visible in the implementation.
For example, a long `Snapshot` doc about cache polling and why every wiring site
has a non-nil instance can become:

```go
// Snapshot maintains a Redis-backed cache of per-key entry counts.
type Snapshot interface { ... }
```

Wiring and nil-safety explanations are implementation details; keep a one-line
summary, then only what callers pass, receive, and can rely on.

## No doc comment on unexported functions or methods

Delete the whole doc comment on an unexported or private function, method, or
helper in any language, even when it includes a precondition or architecture
rationale. No exceptions or subtle-helper carve-outs: delete the whole comment
rather than trimming its lead. The local reader has the name and body. A
load-bearing precondition belongs inline where the code depends on it; this
subtractive pass does not add that comment. Follow the linter rule below for
private Python docstrings.

```go
func buildKey(tenant, slug string) string {
    return tenant + ":" + slug
}
```

## Intent rather than narration

Delete comments that announce a loop, guard, assignment, setup step, or the
next call. A sentence phrased as a reason still fails when it describes the
mechanics of the called function. This applies to struct-field wiring and to
setup comments about which collaborator stays warm or gets flushed. Retain a
non-obvious external constraint beside the code it governs.

```go
// The partner API accepts at most 100 IDs per request.
const requestBatchSize = 100
```

Delete `// Sum the sizes of all items.` beside a summing loop, and
`// Return early if the context was cancelled.` beside a context guard. Delete
a comment saying a client "needs the rate limit to weight per-region traffic
during refresh" when the next line calls `UpdateRateLimit(rl)`: it narrates
that collaborator's work.

## Restatement and linter floor

Delete field comments that rename the field, `Foo is the foo`, enum comments
that repeat their values or trigger conditions, and comments that rederive
nearby defaults, tags, or arithmetic. Go exported types, functions, constants,
and variables keep one minimal doc line, even without a configured linter;
never delete their doc comments outright. Fields have no floor. For other
languages, follow the project's linter or convention: a private Python helper
keeps a docstring only when required, and a restating doc comment with no floor
is deleted. Trim padded exported Go docs to one line:

```go
// WriterConfig configures the writer cron job.
type WriterConfig struct { ... }
```

A default in `setDefaults` does not need a second textual copy beside its
field. A timeout comment that adds adjacent durations is a derivation, not a
reason to keep. Keep the field's purpose or a test's intent when that meaning
is not otherwise visible.

## Tests

Keep a comment only if it explains why the case exists or the surprising
property it proves. Delete comments narrating setup, assertions, or arithmetic
from test literals. `// Credit thresholds pass through as-is (no unit
conversion).` names a useful property; `// Send logs so the client refreshes`
beside the send loop narrates its mechanics.

## Final scan

For each surviving comment, ask whether it states a fact absent from nearby
code and whether that fact is owned here. For each removed comment, ensure it
is within scope and is neither a directive nor a notice. The pass is
subtractive: replacing weak prose with another weak comment fails the same
test.
