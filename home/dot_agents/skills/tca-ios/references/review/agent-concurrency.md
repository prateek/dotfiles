# Applies to: TCA 1.25+, iOS 16+

# Concurrency and Cancellation Review

## Use When

Use this for async effects, cancellation IDs, long-lived streams, timers, MainActor, and Swift 6 warnings.

## Inspect

- `Effect.run` closures and explicit captures.
- Async sequences and `for await` loops.
- Timers, clocks, polling, and subscriptions.
- `Task` and `Task.detached`.
- Cancellation IDs and `cancelInFlight`.
- Effects tied to view or feature lifecycle.
- MainActor and Sendable safety.
- Shared mutable dependency state.
- Terminal events reachable from more than one trigger (timer-complete, user-confirm, dismissal). What is the reducer's order-of-arrival contract when two of those land in the same tick, and what guarantees the work happens once?
- `withDiscardingTaskGroup` (and similar) running multiple producers (timer + speech + network). When the group ends, which producers' pending yields are dropped, and is that dropping intentional?
- Pending effect actions on the dismissal boundary. When the parent nils the optional child or pops the stack, what is in flight, and where does its `.send(...)` deliver?

## Findings To Look For

- Repeated user effects without cancellation.
- Long-lived work still running after dismissal.
- Unstructured tasks bypassing reducer lifecycle.
- Loading state not cleared on failure or cancellation where visible.
- Mutable captures across concurrency boundaries.
- Heavy work forced onto MainActor.
- Terminal-event double-fire: the same logical end-of-feature event reachable from two branches with no idempotency. Each branch must either funnel through one action (`meetingEnded`, `recordingFinished`) or guard with an `isFinished` flag the other branch checks. Symptom: the meeting is saved twice when the timer reaches the boundary at the instant the user taps confirm.
- Stream drainage at termination: a subscription that emits sequentially (speech transcripts, location updates) is torn down by group cancellation instead of explicit drain. Trailing values are lost. Symptom: the saved transcript is missing the last few seconds of speech because the stream had not yet yielded them when the timer-tick branch dismissed.
- Race between a pending effect action and dismissal: a stream emits value V, dismissal nils the parent, V's `.send(...)` arrives at a torn-down feature. Symptom: dropped data; or, in tests, an "unexpected action received" failure on a feature whose state is already gone.
- Equality boundary checks on monotonic values: `if elapsed == limit` skips when the scheduler steps past the limit in one delivery. Use `>=` and pair with an idempotency guard.

## Runtime Correctness Lens

Type-shape findings catch what should not compile. Concurrency findings catch what compiles and runs but drops data, double-writes, or delivers actions to a torn-down feature. Ask, for every long-lived effect: when its parent ends, is the data drained, dropped, or delivered to nothing? Ask, for every terminal write: which actions can reach this code, and what happens when two reach it on the same tick? The answers are usually structural — an `isFinished` flag, a single funnel action, an explicit drain — but they only surface if the reviewer reads the effect as a sequence in time.

## Output

Include a concurrency summary, list of long-lived effects and cancellation story, findings, and concrete race/cancellation tests. Each long-lived stream and each multi-trigger terminal write should appear in the summary with an explicit drain/idempotency note, even when no finding fires.
