---
name: testing-philosophy
description: >-
  Use when writing, reviewing, designing, or repairing tests, or deciding what to test. Triggers on
  add/write tests, what should I test, how do I test this, is this tested, review my tests, TDD,
  coverage, flaky or brittle tests, refactor-broken tests, too many mocks, should I mock, unit vs
  integration, snapshot or golden tests, property-based tests, fuzzing, regression tests,
  concurrency, time, database or network tests, slow suites, or tests that pass while code is
  broken. Also use proactively before adding a test mid-task, choosing assertions or test doubles,
  or deleting, skipping, weakening, or blindly updating a failing test. Provides the purity x extent
  model, behavior-through-stable-seams guidance, a toolbox, determinism rules, anti-patterns, a
  review checklist, and agent conduct rules. Skip only for pure runtime/app debugging with no test
  involved.
---

# Testing Philosophy

## Why this exists

A good test fails when behavior breaks and stays quiet during honest refactors. A bad test does the
reverse: it passes while the product is broken, and it breaks every time you rename a variable or
reshape a function. Most weak testing comes from one habit — testing the *shape* of the code (this
class, this private method) instead of the *behavior* it delivers for a caller.

A test suite has one job: let people change the code with confidence. This skill keeps you on the
behavior side of that line and gives you precise vocabulary for the trade-offs. Treat the guidance
as defaults with reasons, not laws; when you break one, say why. The default question is almost
never *whether* to test, but *what* behavior, *at which seam*, and *with how much impurity*.

## The model: purity and extent, not "unit vs integration"

"Unit vs integration" is a confused axis — people use those words for scope, for speed, for
compilation layout, and for "does it touch a database," often in one sentence. Drop the argument and
classify on two independent axes.

- **Purity** — how much generalized I/O and nondeterminism the test involves. Impurity is a ladder,
  each rung roughly half an order of magnitude slower and flakier than the last: pure computation →
  threads → time and disk → multiple processes → distributed across machines. Purity drives speed,
  determinism, and resilience to unrelated environment changes.
- **Extent** — how much of *your* code the test exercises. A test can drive your entire compiler or
  pricing engine in memory and still be 100% pure and finish in milliseconds.

These are orthogonal, and that is the whole point: more code under test does **not** mean a slower
test (merge sort runs more code than bubble sort and is faster). I/O is what costs, not lines
executed. So:

- **Optimize purity ruthlessly.** Moving a test one rung down the ladder is the single highest-
  leverage thing you can do for a suite. Push I/O to the edges so most tests are pure functions of
  data.
- **Let extent be whatever it naturally is.** A wide, pure test that drives the real subsystems and
  fakes only the I/O at the boundary is usually the *best* test: high fidelity, fast, refactor-proof.
  Do not shrink extent by mocking your own modules — that buys nothing on speed and costs you
  fidelity and refactor-resilience.
- Optimize for speed, determinism, resilience to refactoring, and a sharp failure. Do not optimize
  for extent, test count, coverage percentage, or how "unit" a test looks.

When someone asks "should this be a unit or an integration test?", reframe: "How pure can we make
it, and what is the smallest stable seam that exercises the real behavior?" But when the caller
*names* the layer, that layer is part of the requirement, not an open question — honor it and
optimize purity *within* it (see "Choosing the test layer").

## Default move

When asked to add or repair a test:

1. **Identify the behavior and a stable boundary.** For a library, the public API; for an app, what
   a user or calling service observes (CLI output, HTTP response, persisted state, emitted event).
2. **Pick the smallest meaningful test** that protects that behavior — small setup and fast feedback,
   not "mock every collaborator." *Unless the caller named a layer* (integration, scenario, E2E,
   service-start): then that layer is the deliverable — see "Choosing the test layer."
3. **Push impurity outward** with fakes, a fake clock, seeded randomness, in-memory stores, or
   sans-I/O drivers before reaching for disk, sleeps, real services, or subprocesses.
4. **Route shared cases through one `check` helper** when several cases have the same shape.
5. **Run the focused test and read the failure** before changing anything.
6. **For a bug, write the regression test first** when practical: make it fail for the bug, then
   pass for the fix.

## Choosing the test layer

The steps above optimize for purity and behavior fidelity. *Which* layer to test is a separate
decision, and the answer depends on who makes it.

- **Named layer → honor it.** When the caller names a layer (integration, scenario, E2E,
  service-start), that layer is the deliverable. A single mocked interaction, a recording fake around
  one component, or a fake-only seam test does **not** count as integration/scenario coverage — at
  most it is supporting coverage. If you add one, label it as supporting and say plainly the named
  layer is still owed; never pass a narrower test off as the named coverage.
- **Apply this philosophy inside the layer.** Keep it behavior-focused, fake only the external I/O
  the harness normally fakes, avoid brittle internal assertions, and synchronize on real observable
  signals. Purity work happens *within* the requested extent, not by shrinking it. If you also work
  test-first, write the failing test at the named layer; an inner-loop test is supporting only.
- **Open layer → choose by purity and risk, not by size.** When no layer is named (or the ask is
  "whatever's best"), don't reflexively reach for the smallest unit test or the largest E2E. Take the
  highest-purity test that still exercises the real behavior, with extent as wide as the behavior
  needs. Climb to impure rungs — real services, network, E2E — only when the risk lives in the wiring
  (cross-service, persistence, money, migrations) or the behavior is observable nowhere else.
- **Infeasible, mismatched, or genuinely ambiguous → surface it, don't guess.** Name the missing
  harness or blocker, or why a named layer doesn't fit the behavior; when the layer is open and the
  choice materially changes cost or coverage, state the assumption you're making (or ask). Don't
  silently pick, and don't ship a narrower test as if it satisfied a request for a bigger one.

- *"Add an E2E scenario for tracing and consumption."* **Good:** a real scenario that ingests traces
  and asserts the externally visible consumption telemetry. **Bad:** a package-level recording fake
  around the client, claimed as scenario coverage.
- *"Add a local integration test like the existing consumption one."* **Good:** a harness that drives
  several real components together, faking only the outer infrastructure boundary. **Bad:** call a
  private method, assert one mocked interaction, and call it integration coverage.

## What to test: behavior through stable seams

Test what the code *does* for its caller, observed through an interface that survives refactors.

- **The swap (neural-network) test.** If you replaced the implementation with a completely different
  one — a rewrite, or an opaque model that just returns correct answers — would the suite still be
  valid? If yes, you are testing behavior. If the tests would all break, they are welded to the
  current implementation and will fight every refactor.
- **Tests against concrete internals are technical debt.** They help while you bring code to life,
  then tax every change: a redesign leaves a pile of red whose "expected" values you mechanically
  paste over, learning nothing. (A suite written against a type checker's internals got deleted for
  exactly this; the same logic tested as "this bad input produces this error" survived for years.)
- **Boundary cases worth covering:** empty / one / many, malformed, permission denied, timeout /
  retry, duplicate / ordering, precision / time rollover.
- **Cross-layer contracts where wiring breaks:** serialization, migrations, routing / auth,
  idempotency, backward compatibility.
- **Exception (pragmatism over purity):** a direct test of a private or extracted unit is fine as a
  *temporary or justified* move for genuinely tricky pure logic. Prefer widening visibility a little
  or extracting a real boundary, and move the test back out once the boundary is clear.

```python
# Brittle: welded to internals. Breaks when you rename _bucket_for or switch to a tree.
def test_cache_uses_lru_bucket():
    c = Cache(); c._buckets[c._bucket_for("k")] = Node("k", 1)
    assert c._evict_candidate()._key == "k"

# Behavioral: states a guarantee a caller relies on. Survives any rewrite that keeps it.
def test_lru_evicts_least_recently_used():
    c = Cache(capacity=2)
    c.put("a", 1); c.put("b", 2); c.get("a"); c.put("c", 3)  # "b" is now coldest
    assert c.get("b") is None
    assert c.get("a") == 1 and c.get("c") == 3
```

## Design for testability

Testability is a property of the design, not of the test framework. If something is painful to test,
the design is usually telling you something.

- **Functional core, imperative shell.** Put decisions and computation in pure functions that take
  data and return data. Confine I/O — network, disk, clock, randomness, env — to a thin outer shell
  that calls the core. Test the core exhaustively and cheaply; cover the thin shell with a few
  high-extent tests.
- **Sans-I/O for protocols and stateful logic.** Model the logic as a state machine that consumes
  events and emits intents ("send these bytes", "set this timer"); let the caller perform the actual
  I/O. The hard part becomes pure, deterministic, and reusable across sync and async runtimes.
- **Inject dependencies at *real* seams.** A database, clock, HTTP client, or message bus is a
  legitimate thing to substitute. Your own pure business module is not. The smell to avoid is
  "mock everything one layer down"; the goal is "one fake at the boundary, real code behind it."
- **Make background work awaitable and behavior observable.** Fire-and-forget work you can't join is
  untestable by construction (and leaks across tests). Return a handle or completion signal. When you
  must assert something the caller can't see (a cache hit, a retry), expose a deliberate
  observability point and assert on that — don't reach into private state.

## Lower the cost of a test

People — and agents — skip tests when a test costs more than the fix. Drive that cost toward zero.

- **Funnel each kind of test through one `check` helper** that owns the call shape: input(s) in,
  expected out. When the signature changes you fix the helper once instead of fifty call sites. Put
  one good failure message or rich diff in `check` and every case inherits it.
- **Specify cases as data, not code.** Once a test is "a value in, a value out," adding a case is a
  line of data — and you unlock table-driven, parameterized, property-based, and golden tests for
  free.

```go
// One check function. Adding a case is one line; changing the API touches only check().
func check(t *testing.T, input string, want []Token) {
    t.Helper()
    got := Lex(input)
    if !reflect.DeepEqual(got, want) { t.Fatalf("Lex(%q)\n got: %v\nwant: %v", input, got, want) }
}

func TestLexer(t *testing.T) {
    check(t, "", nil)
    check(t, "1+2", []Token{Num("1"), Plus, Num("2")})
    check(t, "  x ", []Token{Ident("x")})
}
```

## Choose the technique that fits

Default to example-based table tests; reach for the rest when they earn their keep. Deep dives and
failure modes are in `REFERENCE.md` — load it when you actually apply one.

- **Table / data-driven** — the workhorse: many cases of one rule through a thin `check`.
- **Snapshot / expect / golden** — large or structured output where a diff is the review surface
  (ASTs, diagnostics, rendered text). The framework records the expected value and updates it on an
  explicit flag. Failure mode: rubber-stamping updates without reading the diff. Review every change.
- **Property-based** — assert an invariant over generated inputs (round-trips, idempotence, "agrees
  with a slow reference"); the framework shrinks failures to a minimal case. Pin every counterexample.
- **Exhaustive** — for small input domains, check *all* inputs against a naive oracle.
- **Fuzzing** — feed random or coverage-guided input to parsers and anything taking untrusted bytes;
  assert it never crashes or corrupts. Add each crash as a permanent regression seed.
- **Differential / cross-branch** — for "rho problems" (output not inferable, no clean property):
  run the new code against a trusted reference and assert they agree. A `git worktree` of the
  known-good branch makes a perfect oracle for refactors.
- **Fault injection** — make allocation fail, a write tear, a partition happen; assert clean
  recovery. For storage, parsers, and anything where corrupt state is catastrophic.
- **Contract tests** — at service seams, pin the request/response shape both sides agree on so a
  fake can't drift from the real provider.

## Speed and determinism

Fast tests dominate every other property, because the time from edit to result drives how often you
run them, which drives everything else. A suite slower than your attention span stops getting run.

- **I/O is the tax, not lines of code.** Slowness comes from disk, network, processes, oversized
  inputs, and a few outliers. Print per-test timing so outliers can't hide; cut I/O first.
- **Flakiness is a bug, filed and fixed, not retried.** A test that fails intermittently either
  catches a real race (fix the code) or tests nothing stable (fix or delete the test). One tolerated
  flake trains everyone to ignore red.
- **Never synchronize with sleeps.** Await a real signal, inject a controllable clock, or return a
  joinable handle. Don't spawn background work you can't wait for.
- **Control the nondeterministic edges:** clock, randomness (seed it and log the seed), iteration
  order, UUIDs, timezone, locale. Pass them in; don't read them ambiently.
- **Gate slow tests at runtime, not compile time.** Skip them unless an env var is set, and print how
  to enable them. Build tags / conditional compilation hide both the tests and their compile errors.
- Keep the main branch green with a merge queue that tests the post-merge result before it lands.

## Mocks and fakes

Mock the outside world, not your own architecture.

- **Prefer a fake at the real I/O seam** — an in-memory store, a fake clock, a local transport, a
  deterministic ID generator. Fakes preserve real semantics and survive refactors.
- **Use interaction assertions only when the interaction *is* the behavior** — "charge the payment
  API exactly once," "emit one audit event." Asserting on internal call sequences is not.
- **The mock-heavy smell:** more setup (`when(...).thenReturn(...)`) than scenario, and a test that
  breaks when you rename a method without changing behavior. Replace the mocks with a fake at the
  boundary and let real code run behind it.

## Anti-patterns

- Testing private internals or asserting on internal call order.
- Over-mocking — mocking your own code, or asserting "method X was called with Y."
- Asserting on logs or incidental output to infer behavior.
- Blindly checked-in snapshots nobody reads.
- Tests that restate the code (`assert add(2,3) == 2+3`) or assert nothing ("doesn't throw").
- Ice-cream-cone suites: mostly slow end-to-end tests, few fast ones.
- Coverage as a target: it shows untested lines, not whether tested lines are tested well.
- Sleeps and unawaited background work; ignored flaky tests; build-tag-hidden slow tests.
- Deleting, skipping, weakening, or loosening a test to make a suite go green.

## Reviewing tests

Review the tests before the implementation — they state the intended behavior and where the author
thinks the risk is. Ask:

1. Would this fail for the bug or regression we care about?
2. Would it keep passing after a harmless refactor?
3. Is the slow or impure part necessary?
4. Does the failure message point at the broken behavior?
5. Are snapshots or goldens small and reviewable?
6. Were existing tests removed, skipped, weakened, or replaced — and is that justified?

Missing tests matter most when the change touches persisted data, money, permissions, migrations,
compatibility, concurrency, parsing, or public APIs.

## Process: how much, when, and when not

- **TDD where it pays.** Test-first shines when you know the desired behavior: fixing a bug,
  implementing a clear spec, hardening an interface. It is a poor fit while you are still discovering
  the design — sketch first, then lock behavior in. TDD gives design feedback in the small; it won't
  tell you the right architecture.
- **Honeycomb over a rigid pyramid.** Many fast, mostly-pure tests at their natural extent and a thin
  shell of slow integration tests, rather than dogmatic ratios. Avoid the ice-cream cone.
- **Calibrate effort to risk and blast radius.** Core logic, money, auth, data integrity, and parsers
  deserve heavy testing (consider exhaustive / property / fuzz). A one-line accessor does not.
- **Coverage is a diagnostic, not a target.** Use it to find blind spots. Branch coverage tells you
  more than line coverage; mutation testing tells you whether your assertions actually bite.
- **When not to test:** throwaway spikes, trivial pass-throughs, generated code, and corners where the
  test is far more brittle and costly than the code and a cheaper check covers the risk. Skipping is a
  deliberate, stated trade-off — not silent omission. "Hard to test" usually means "poorly factored,"
  so try the design fix first.
- **No religion.** A fast, high-fidelity in-memory or local fake is fine even if a purist won't call
  the result a "unit test." Pick what's fast, deterministic, and high-fidelity.

## Agent conduct

You will be tempted to make the bar turn green. Optimize for *true*, not for green.

- **Never silence a failure to pass.** Don't delete or skip a failing test, loosen an assertion,
  widen a tolerance, wrap the body in a blanket catch, or comment out the check. A red test is
  information. If the test is genuinely wrong, fix it deliberately and say why.
- **Read the actual failure output before reacting.** Don't blanket-update snapshots or accept
  generated expectations without reading the diff.
- **Assert on expected errors; don't swallow them.** When code should reject input, assert it raises
  the specific error. Test the failure paths, not just the happy path.
- **Verify your test can fail.** A test you've only seen pass might assert nothing. Break the code
  once to confirm it goes red, then revert.
- **Prefer the smallest meaningful test** at the highest purity that still exercises real behavior.
- **Match the repo's conventions** — its `check` helpers, fixtures, naming, and layout — and run the
  relevant suite the way the project runs it before adding a new framework.
- **Never claim tests pass without running them**, and **state residual risk** plainly when you
  skipped slow or integration tests or couldn't run the full suite.

## Deeper material

`REFERENCE.md` covers each technique in depth (with examples and failure modes), the test-double
taxonomy (dummy / stub / fake / spy / mock), property-discovery patterns, determinism patterns for
time / concurrency / network, coverage / MC/DC / mutation testing, robustness and fault injection, a
seam-by-system chooser, a per-language cheat sheet, a workflow for diagnosing a bad suite, and case
studies (SQLite, compiler/IDE suites, sans-I/O). Load it when you're applying a specific technique or
making a non-obvious trade-off — not for routine "write a sensible test" work.
