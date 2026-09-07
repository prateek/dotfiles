# Applies to: TCA 1.25+, iOS 16+

# Effects and Dependencies Review

## Use When

Use this for networking, persistence, clocks, files, analytics, permissions, notifications, async streams, polling, and SDK usage.

## Inspect

- Reducers returning effects instead of doing I/O directly.
- Dependency access through `@Dependency` or the codebase's current TCA mechanism.
- Controlled dates, UUIDs, clocks, randomness, networking, and persistence.
- Live/test/preview dependency values.
- Error handling and response actions.
- Fire-and-forget effects.
- Domain-specific clients.
- Terminal write paths (save / insert / commit) reachable from more than one action branch (timer-complete and user-confirm, dismissal and explicit-cancel). Are the writes idempotent, or can two branches fire the same write in the same dispatch tick?
- Subscription effects that emit a sequence of values across the feature's lifetime (speech transcripts, location, sensor data, server-sent events). Is the stream drained before terminal state writes, or does the parent simply tear it down and trust whatever has already been delivered?
- Boundary checks that use exact equality (`==`) on a monotonically advancing value (seconds elapsed, page index, byte offset). Does a scheduler skip or out-of-order delivery let the value step over the boundary undetected?

## Findings To Look For

- Direct singleton use in reducers.
- Effects that swallow errors.
- Effects that never report important completion/failure.
- Flaky tests caused by live time, network, random, or database.
- Broad clients that leak SDK concepts into feature reducers.
- Stateful dependencies without actor/lock/serial isolation.
- Two reducer branches performing the same logical write (insert / save / commit) without an idempotency guard. The symptom is an at-the-moment race: a timer reaches a boundary and saves *and* the user taps confirm at the same instant, so the row is inserted twice. Funnel both paths through one action (`meetingEnded`, `recordingFinished`) or guard with an `isFinished` flag.
- Stream subscriptions torn down by group cancellation rather than explicit completion. Anything yielded between the last `await send(...)` and the terminal write is lost. Either await the stream's final value before writing, or model the write as a response to the stream's `nil`/`.finished` signal.
- Equality boundary checks (`==`) where `>=` is the safe contract. A slow scheduler or a coalesced clock tick can step from below to above the boundary in one delivery and silently bypass the branch.

## Runtime Correctness Lens

Read the effect as a sequence of events, not as a type signature. For each long-lived effect ask: when this feature dismisses, what is in flight, and what is dropped? For each terminal write ask: which other action paths can reach this write, and what happens if two reach it on the same tick? Type shape is necessary; ordering and drainage are sufficient.

## Output

Include a side-effect map, findings, dependency-client improvements, and tests requiring overrides. Call out any terminal write reachable from more than one branch and any subscription whose drainage story is implicit.
