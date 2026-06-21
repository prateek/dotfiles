# Testing Philosophy: Reference

Depth behind `SKILL.md`. Load a section when you're actually applying that technique or making a
non-obvious trade-off. You don't need this file for routine "write a sensible test" work. Code is
portable pseudocode — translate to the project's language and framework.

## Contents

1. [Technique deep-dives](#1-technique-deep-dives)
   - [1.1 Data-driven / table / externalized](#11-data-driven--table--externalized)
   - [1.2 Expect tests / snapshots](#12-expect-tests--snapshots)
   - [1.3 Property-based testing](#13-property-based-testing)
   - [1.4 Exhaustive testing](#14-exhaustive-testing)
   - [1.5 Fuzzing](#15-fuzzing)
   - [1.6 Golden / approval tests](#16-golden--approval-tests)
   - [1.7 Differential / oracle / cross-branch](#17-differential--oracle--cross-branch)
   - [1.8 Coverage marks & observability](#18-coverage-marks--observability)
   - [1.9 Contract tests at service seams](#19-contract-tests-at-service-seams)
2. [Test double taxonomy](#2-test-double-taxonomy)
3. [Determinism patterns](#3-determinism-patterns)
4. [Coverage, MC/DC, and mutation testing](#4-coverage-mcdc-and-mutation-testing)
5. [Robustness / anomaly testing & fault injection](#5-robustness--anomaly-testing--fault-injection)
6. [Diagnosing a slow / flaky / brittle / toothless suite](#6-diagnosing-a-slow--flaky--brittle--toothless-suite)
7. [Seams and layered testing](#7-seams-and-layered-testing)
8. [Case studies](#8-case-studies)
9. [Per-language seam cheat sheet](#9-per-language-seam-cheat-sheet)
10. [Provenance and further reading](#10-provenance-and-further-reading)

---

## 1. Technique deep-dives

Pick by the shape of input and output, and by how the test should fail. Default to 1.1; escalate
only when it pays.

### 1.1 Data-driven / table / externalized

The workhorse. Encapsulate the API under test in one `check` function (value(s) in, expected out),
then express every case as data. Benefits: a signature change touches one place; adding a case is
trivial, so cases actually get added; the data format becomes reusable infrastructure.

Progression, in increasing order of decoupling:

- **Inline table**: a list/array of cases iterated through `check`. Start here.
- **Embedded DSL / fixture format**: a compact text format that encodes a whole scenario (e.g. a
  mini-project, a cursor-position marker, expected markers). Invest in one shared format and every
  test benefits — editor support, highlighting, helpers — amortized across the suite.
- **Externalized cases**: case definitions live in data files; one test loops over them. Forces true
  data-in/data-out and lets a reimplementation in another language reuse the suite. Cost: you lose
  per-case IDE integration ("run this one test", "47 of 50 passed"). Mitigation: keep a trivial
  inline smoke test (`check("", "")`) you can paste a failing input into for debugging.

Keep `check` thin. A `check` that does elaborate massaging hides what's actually under test and
becomes its own untested logic. Put one good failure message / rich diff in `check`; this beats
fluent-assertion ceremony spread across every test.

### 1.2 Expect tests / snapshots

You write the scenario; the framework captures actual output and writes the expected value back into
the test (or a sidecar file) on an explicit update flag (`UPDATE_EXPECT=1`, `--snapshot-update`). A
mismatch shows a diff, and the diff *is* the review artifact.

Pays off when output is large, structured, or changes in bulk (ASTs, diagnostics, serialized state,
rendered tables, hardware waveforms). Eliminates hand-transcribing expected output and makes a
sweeping intended change a one-command update.

Failure modes and how to avoid them:

- **Rubber-stamping.** Accepting updates without reading the diff turns the suite into "assert the
  code does what it does." Review every snapshot change as carefully as source; never run the update
  command and commit without inspecting each hunk.
- **Over-broad / noisy snapshots.** Snapshotting a whole object when you care about one field
  captures noise (timestamps, ordering, addresses) and churns. Snapshot the smallest meaningful
  projection; normalize volatile fields before comparing.
- **Giant unreadable blobs.** If a human can't eyeball the snapshot and know it's right, it isn't
  buying much confidence.

A vivid example of doing it well: testing a state machine by rendering its behavior as ASCII
waveforms in the expectation — the gold value is something a human reads directly, so a bad diff is
immediately legible. Most languages have a library (`insta`/`expect-test`, `syrupy`, `jest`/`vitest`
snapshots, `ppx_expect`).

### 1.3 Property-based testing

Assert a property that must hold for all inputs; the framework generates many inputs and shrinks any
counterexample to a minimal failing case. Use when a property is clearer or stronger than hand-picked
examples. Always pin a discovered counterexample as a permanent example regression test.

The motivating story: a malicious implementer ("the enterprise developer from hell") can pass any
finite set of example tests by special-casing them — `if x==1 and y==2: return 3`. Example tests pin
only the points you thought of; properties pin the whole space.

Property-discovery patterns (when you "can't think of a property"):

- **There and back**: `decode(encode(x)) == x`; serialize/parse, compress/decompress, set/get.
- **Different paths, same destination**: `sort(map(f, xs))` vs `map(f, sort(xs))` when valid;
  commutative/associative operations; order-independence.
- **Invariants preserved**: length after `map`, multiset after `sort`, balance after tree insert,
  conservation of a total after a transfer.
- **Idempotence**: `f(f(x)) == f(x)` for normalize, dedupe, saturating clamp, `PUT`.
- **Algebraic laws**: but pick strong ones — `x+1+1 == x+2` passes a `*` impl; associativity catches
  it. Weak properties miss bugs.
- **Hard to produce, easy to verify**: generating a maze solution is hard; checking a path is
  trivial. Generate the answer, verify cheaply.
- **Test oracle / model-based**: compare against a simpler, slower reference (see 1.7).
- **Metamorphic**: when you don't know the exact output, you may know a *relation* between outputs
  (adding an irrelevant filter shouldn't change a count).

Watch the generator: a property is only as good as the inputs it explores. Bias generators toward
edge cases (empty, max, negative, duplicates, unicode). Log and let users pin the seed for
reproducibility. Coming up with properties is the hard part — that difficulty is just thinking about
the spec, and it deepens your understanding of it.

### 1.4 Exhaustive testing

When the input domain is small, enumerate it instead of sampling. Generate *every* input up to some
bound and check each against a naive oracle (e.g. verify binary search against linear search for all
sorted lists of length ≤ 7 with elements in `0..=6`). Stronger than examples and properties combined
when the bounded domain is representative. Watch for combinatorial blowup; keep bounds small enough
to stay on the pure/fast rung.

### 1.5 Fuzzing

Throw large volumes of generated input at code and assert it never violates a safety property:
doesn't crash, corrupt state, hang, or hit undefined behavior; always returns a clean error. The
contract under test is usually negative. Variants:

- **Dumb/random**: random bytes. Cheap; finds shallow crashes.
- **Coverage-guided**: the fuzzer observes which branches execute and mutates toward new coverage
  (libFuzzer, AFL, Go's native fuzzing, `cargo-fuzz`). Far more effective at reaching deep states,
  and polymorphic — the same harness works on any implementation of the format.
- **Structure-aware / generative**: use random bytes as a seed to build *valid-ish* structured
  inputs (a well-formed program, a valid wire message) so you get past surface validation into deeper
  logic. Mutating multiple inputs at once (e.g. a data file *and* a query) reaches states single-axis
  fuzzers miss.

Best targets: parsers, decoders, deserializers, anything consuming untrusted input, and any place a
crash is a security issue. Add every crash the fuzzer finds as a fixed regression seed in a fast
corpus run on every build. Note the tension with branch-coverage goals: defensive "can't happen"
code is by design hard to fuzz into.

### 1.6 Golden / approval tests

A snapshot stored as a committed file (the "golden" output). Same idea as 1.2, file-based; common for
compilers, codegen, formatters, report generators. Same discipline: review golden diffs, keep them
small and deterministic, normalize volatile content.

### 1.7 Differential / oracle / cross-branch

When output isn't inferable from input by inspection and has no clean mathematical property ("rho
problems": vision code, simulations, gnarly business logic, data pipelines), test against a reference
you trust:

- **Brute-force oracle**: a slow, obviously-correct implementation; assert the fast one agrees.
- **Alternate implementation**: another tool/engine for the same spec (how SQL engines cross-check
  query results against each other on millions of generated queries).
- **Cross-branch / cross-version**: run the current code against the previous known-good version on
  generated inputs and assert agreement. This catches subtle refactor regressions that affect a tiny
  fraction of inputs (a 1%-of-inputs bug has ~1% chance per example test but is caught fast by
  generated differential testing). `git worktree add ref <known-good>` checks out the reference
  alongside the working copy.

```
# In a worktree of the known-good branch:  git worktree add ref deploy
import ref.module as reference
import module as candidate

@given(integers(), integers(), integers())
def test_refactor_preserves_behavior(a, b, c):
    assert candidate.f(a, b, c) == reference.f(a, b, c)
```

Caveat: differential testing finds *divergence*, not *correctness*. If both sides share a bug, it
stays invisible. Pair with a few absolute-correctness examples.

### 1.8 Coverage marks & observability

To assert something the caller can't directly see ("the cache was hit," "the fast path ran," "we
retried exactly twice," "this branch was the reason"), don't reach into private state. Add a real
side channel and assert on it:

- a counter or metric the test can read,
- a structured event/log record consumed *as data* (not by scraping human log strings),
- a "coverage mark" the code emits at a specific point and the test asserts was reached.

Coverage marks are the antidote to tests that pass for the wrong reason (the bad thing didn't happen,
but only because an unrelated path short-circuited). They make intent observable and keep the test
behavioral. Distinguish this from asserting-on-logs as a behavioral proxy (an anti-pattern): a
coverage mark is a *deliberate, stable* part of the contract you chose to expose; incidental log text
exists for humans and breaks on rewording.

### 1.9 Contract tests at service seams

When two services talk, neither full end-to-end nor isolated mocks suffice alone. A contract test
pins the request/response shape both sides agree on: the consumer asserts it sends what the provider
expects; the provider asserts it honors that shape. This catches integration drift without a full
multi-service deployment. Keep the contract the source of truth and generate fakes from it, so a
consumer's fake can't drift from the real provider.

---

## 2. Test double taxonomy

"Mock" is used loosely for five different things. Precision matters because they have different costs
and different legitimate uses.

- **Dummy**: a placeholder passed to satisfy a signature, never used. Harmless.
- **Stub**: returns canned answers to calls. Fine for feeding fixed inputs. Keep it dumb.
- **Fake**: a real, working, lightweight implementation (in-memory database, in-memory clock, temp
  filesystem). **Usually the best double.** High fidelity, no brittle call-count assertions, behaves
  like the real thing, survives refactors.
- **Spy**: records how it was called for later assertions. Use sparingly.
- **Mock**: a double pre-programmed with expectations that fails if calls don't match. This is
  *interaction* testing ("was `save` called once with this argument?").

Guidance:

- **Substitute only at true I/O seams**: network, disk, clock, randomness, external processes,
  third-party services. Prefer a **fake** there; fall back to a stub.
- **Don't mock your own internal modules.** It welds tests to your call structure, re-breaks on every
  refactor, and tests the wiring you wrote instead of the behavior you ship.
- **Avoid interaction assertions** ("called with X") unless the interaction *is* the externally
  observable behavior ("we must send exactly one charge to the payment API, never two"). There,
  asserting the call is correct.
- **The mock-heavy smell:** a test file with more `when(...).thenReturn(...)` setup than scenario,
  that breaks whenever you rename a method without changing behavior. Replace the mocks with a fake
  at the boundary. If you're reaching for a mock to make a test "a unit," the boundary is probably in
  the wrong place — fix the design (functional core / sans-I/O) instead.

---

## 3. Determinism patterns

Flakiness is a bug. Each non-deterministic input is a seam to control.

- **Time.** Never read the wall clock or `sleep` to synchronize. Inject a clock (a `Clock` interface,
  a `now()` parameter, a virtual time source) so tests advance time deterministically. Replace
  timeouts/retries with a fake clock you tick manually.
- **Concurrency.** Don't spawn background work the caller can't await; it outlives the test and
  contaminates others (a leaked task is causality you can't re-forge from a layer above). Use
  structured concurrency: every task has an owner that joins it. Await real completion signals, not
  durations. For logic-level concurrency bugs, prefer deterministic schedulers or model checkers
  (`loom`-style exhaustive interleaving, or TLA+ for the design) over hopeful sleeps.
- **Randomness.** Seed all RNGs from the test; log the seed so a failure reproduces. Generate IDs,
  UUIDs, and shuffles through an injected source.
- **Ordering.** Don't assume map/set iteration order, filesystem listing order, or concurrent
  completion order. Sort before comparing, or assert on sets/multisets.
- **Environment.** Pin timezone, locale, and encoding. Don't read ambient env vars or global config
  inside the code under test; pass them in.
- **Network.** Prefer an in-process fake server or sans-I/O state machine. If you must hit a real
  endpoint, that test is slow and goes behind a runtime gate.

---

## 4. Coverage, MC/DC, and mutation testing

- **Line/statement coverage** tells you what definitely *wasn't* run — genuinely useful: scan for
  surprising red, watch for per-commit drops, read the gutter to learn how your code reacts to
  inputs. It does *not* tell you tests are good: 100% line coverage with no real assertions is
  trivial and worthless.
- **Branch coverage** is stronger (each decision taken both ways). **MC/DC** (modified
  condition/decision coverage) is stronger still: every boolean sub-condition independently affects
  the outcome. Safety-critical code (avionics, databases) aims here. Prefer branch over line when you
  have the choice.
- **Mutation testing** is the real measure of suite quality: it injects small faults (flip a `<`,
  delete a line) and checks your tests catch them. Surviving mutants are assertions you're missing.
  Slow, but the most honest signal that tests would actually detect regressions.
- **Don't make a coverage percentage a hard target.** It incentivizes assertion-free tests that
  touch lines. A useful ratchet for legacy code: never let coverage drop on a commit, and add tests
  when you touch an untested function, so the active hot zone grows coverage while dead corners are
  left alone. (100% branch/MC/DC is defensible for tiny, ubiquitous, safety-critical infrastructure —
  overkill almost everywhere else.)
- **Runtime assertions** are testing's quiet partner. Liberal pre/postcondition and invariant
  `assert`s turn every test and fuzz run into a consistency check and document assumptions. Compile
  them out of hot release paths if needed, but run the suite with them on, plus sanitizers and leak
  detectors where the toolchain offers them.

---

## 5. Robustness / anomaly testing & fault injection

How extremely-tested systems (e.g. SQLite) get reliable: they don't just test the happy path on a
healthy machine; they simulate the world going wrong, deterministically.

- **Fault injection**: make `malloc`/allocation fail, make a syscall return an error, at each call
  site in turn, and assert the system degrades cleanly (no leak, no corruption, correct error).
- **I/O error and crash simulation**: a fake filesystem layer that can fail or simulate power loss
  between any two writes; assert the on-disk state is always recoverable. This needs a controllable
  I/O seam, which you get from functional-core / sans-I/O design.
- **Malformed input**: feed corrupted files/messages and assert graceful rejection (where fuzzing
  meets robustness).
- **Boundary values**: explicitly test min, max, zero, empty, off-by-one, overflow edges — random
  generation rarely hits exact boundaries.
- **Leak detection**: run under sanitizers / leak detectors in CI so resource leaks fail the build.

You won't do all of this for ordinary code. Pull these out for parsers, storage engines, anything
handling untrusted input, and anything where corrupted state is catastrophic.

---

## 6. Diagnosing a slow / flaky / brittle / toothless suite

When asked to fix a bad suite, work in this order:

1. **Slow?** Profile per-test time. Almost always it's I/O, a few outliers, or huge inputs — not code
   volume. Move logic to a pure core; replace real I/O with fakes or push it behind a runtime-gated
   slow lane; shrink inputs.
2. **Flaky?** Find the nondeterminism: real clock, unseeded randomness, shared mutable global state,
   order dependence between tests, sleep-based synchronization, unawaited background work. Fix the
   source; don't add retries.
3. **Brittle (breaks on every refactor)?** The tests are pinned to implementation shape. Move them to
   the boundary; apply the swap test; introduce a `check` seam; replace mocks of your own code with
   real calls or fakes.
4. **Passes but misses bugs?** Assertions don't bite (confirm with a mutation or by breaking the code
   on purpose), or coverage gates produced assertion-free tests. Add behavioral assertions; add
   properties/differential tests for rho-shaped logic.

Then make new tests cheap (the `check` idiom, a shared fixture format) so the suite improves by
default, and add a merge queue so it stays green.

---

## 7. Seams and layered testing

A *seam* is a place you can change behavior without editing the code around it — the natural spot to
observe or substitute. Good architecture has seams at I/O edges and public boundaries, not in the
middle of business logic.

**Test each layer through its own boundary.** Given `L1 ← L2 ← L3 ← L4`, don't test `L1` only by
driving `L4`:

```
L1 ← tests
L1 ← L2 ← tests
L1 ← L2 ← L3 ← tests
```

Higher-layer tests legitimately exercise lower layers (high extent, and it's fine; it's pure and
fast). The reason to *also* test low layers directly is feedback latency: in compiled languages,
editing `L1` with only `L4` tests means rebuilding the whole stack to learn anything. Direct `L1`
tests give a tight loop. This is about compile/iteration time, not run time — run time is dominated
by I/O, not code volume. Avoid the inversion where a beautifully layered system has tests that all
enter from the top, coupling your fast inner loop to the slowest outer layer.

---

## 8. Case studies

- **SQLite**: ~600× more test code than library code; four independent harnesses; 100% MC/DC branch
  coverage; billions of fuzz mutations per day; OOM/I/O-error/crash anomaly testing; every historical
  bug pinned by a regression test. Lesson: reliability is bought with *multiple independent* testing
  strategies and aggressive fault injection, not one big E2E suite.
- **Compiler / IDE front-ends**: data-driven tests with a shared fixture DSL; a single high-extent
  test drives lexer → parser → name-resolution → types and still runs in milliseconds because it's
  pure. The process-orchestrating parts accept slow integrated tests and isolate them. Lesson: extent
  is cheap when purity is high; isolate the unavoidably-impure part so the core suite stays fast.
- **Sans-I/O protocol libraries (h11, wsproto, hyper-h2)**: the protocol is a pure state machine over
  bytes; the caller drives the socket. The hard logic is fully testable without a network and
  reusable across sync/async runtimes. Lesson: removing I/O from the logic makes it both portable and
  trivially testable.

---

## 9. Per-language seam cheat sheet

Real seams to inject (I/O edges) and idiomatic tools. The principle is identical everywhere; only the
syntax changes.

- **Python**: `pytest` (assert rewriting, fixtures, `parametrize`), `hypothesis` (property), `syrupy`
  (snapshot), `freezegun` or an injected clock, `responses`/`respx` for HTTP, `tmp_path` for temp
  dirs. Inject dependencies as function/constructor args.
- **Go**: table tests with subtests (`t.Run`), accept interfaces for seams, `httptest` for HTTP,
  native fuzzing (`func FuzzX`), gate slow tests with `t.Skip` reading an env var (not build tags),
  `-race` in CI.
- **JavaScript / TypeScript**: `vitest`/`jest` with built-in snapshots, `fast-check` (property), fake
  timers for the clock, MSW for the network boundary. Prefer dependency injection over module
  mocking; reserve `vi.mock` for true externals.
- **Rust**: `#[test]` + table loops, `expect-test`/`insta` (snapshot), `proptest`/`quickcheck`
  (property), `cargo-fuzz` + `arbitrary` (fuzz), `loom` (concurrency interleavings). Inject via
  traits/generics.
- **JVM (Java/Kotlin)**: JUnit5 parameterized tests, `jqwik` (property), AssertJ for diffs, fakes
  over Mockito where possible; reserve mocks for genuine external collaborators.

If the repo already has a convention (a `check` helper, a fixture format, a chosen library), match it
instead of introducing another.

---

## 10. Provenance and further reading

The spine of this skill is Alex Kladov's (matklad) testing writing, generalized away from Rust and
folded together with broadly accepted practice.

- matklad, *How to Test* and *Unit and Integration Tests*: the `check` idiom, test features not code,
  the swap/neural-network test, purity×extent, make-tests-fast, expect tests, coverage marks.
- *Software Engineering at Google*: the size×scope framing that purity×extent adapts.
- Ted Kaminski (tedinski), *Testing at the Boundaries*: tests against internals as technical debt;
  TDD's limits for design-in-the-large.
- Gary Bernhardt, *Boundaries*: functional core / imperative shell; values at boundaries.
- *Sans-I/O* (Cory Benfield): I/O-free protocol implementations.
- Jane Street, *Testing with Expectations*: the expect-test workflow and why diffs matter.
- Scott Wlaschin, *Choosing properties for property-based testing*: the property-discovery catalog.
- Hillel Wayne, *Cross-Branch Testing*: differential testing for "rho problems."
- *How SQLite Is Tested*: independent harnesses, MC/DC, anomaly testing, fuzzing at scale.
- Peter Bourgon, *Don't use build tags for integration tests*: runtime gating over compile gating.
- Tim Bray, *Testing in the Twenties*: the pragmatic counterweight — unit tests pay off, coverage
  data is useful, flaky integration tests are either real bugs or deletion candidates, no dogma.
