---
status: active
doc_type: research
owner: Prateek
created: 2026-09-26
updated: 2026-09-26
related:
  - acpx-visual-workflow-authoring.md
  - ralph-loop-workflow.md
  - ../references/acpx-routing.md
status_detail: "Source and deterministic-probe findings for acpx 0.19.3, compared with historical workflow discussions."
---

# acpx Flow Capabilities

acpx 0.19.3 executes a graph with one active node at a time. The graph can
branch and loop. Its TypeScript callbacks can run arbitrary code, but native
graph execution does not provide parallel branches, durable continuation, or
child workflows.
[Traversal](https://github.com/openclaw/acpx/blob/6b4714c7aaac8c38b1fe38354848d2546f65d87d/src/flows/runtime.ts#L343-L373),
[edge validation](https://github.com/openclaw/acpx/blob/6b4714c7aaac8c38b1fe38354848d2546f65d87d/src/flows/graph.ts#L24-L38).

## Historical Discussions Recovered Through AgentsView

The most relevant conversation is the August 31, 2026 evening `/code-review`
session on `work-mbp` (September 1 in the stored UTC timestamps). It directly
compared a Claude dynamic workflow with an acpx flow implementation.

| Session | Relevant messages and findings |
| --- | --- |
| [Code-review conversion](http://127.0.0.1:8080/sessions/50c18e3f-be76-4422-861e-54a829fcf389) | User messages 343–344 requested the entire conversion in both engines. Message 389 described the acpx port: deterministic diff gathering, level routing, sequential isolated angle reviewers, semantic deduplication, and an action spawning bounded parallel verifier children. |
| Same conversation | User message 390 explicitly asked whether later releases fixed the sequential runtime and dynamic cardinality limits. Messages 405–408 produced a local feature-request draft for a bounded `map` node over runtime-computed items. This retrieval does not establish whether the draft was later submitted. |
| [September 3 concurrency investigation](http://127.0.0.1:8080/sessions/3d9a7681-814c-4502-9868-3654fb9a1e32) | User message 0 asked about execution/concurrency limits and asymmetric timeouts. Message 278 distinguished independent `exec` processes, persistent-session queueing, and sequential flow execution. |
| [September 4 control-plane review](http://127.0.0.1:8080/sessions/97560bb3-1c2a-445a-93e8-8b9d2fafaf08) | Message 202 corrected the draft's scope: parallel workers launched by a parent were not a workload owned by the flow scheduler. A parent semaphore was the workaround discussed. |

The old code-review port therefore illustrates the present boundary: its
pipeline stages fit the native graph, while its variable-sized parallel
verification stage needed a custom process pool inside an action. The 0.19.3
source and probes confirm that the missing native parallel-map primitive
remains a gap. Historical reports of successful model runs were recovered as
transcript evidence; those runs and their old `/tmp` artifacts were not
re-executed or recovered here.

Three earlier claims need more precise wording:

- Dynamic cardinality is possible through a serial loop over an input or
  upstream result. The missing primitive is runtime-owned parallel map/gather,
  with per-item lifecycle and evidence.
- Output handling can validate strictly after generation through `parse`;
  calling it “parse-and-hope” understated that option. A schema-constrained
  generation setting is not part of the native flow API.
- The earlier claim that PR #485 shipped per-node model configuration was
  wrong: [#485](https://github.com/openclaw/acpx/pull/485) closed unmerged.
  Current nodes choose a `profile`; direct model/reasoning options are absent.

The first correction follows from the traversal and callback contracts above.
The other two follow from the
[parser execution](https://github.com/openclaw/acpx/blob/6b4714c7aaac8c38b1fe38354848d2546f65d87d/src/flows/runtime.ts#L1027-L1035)
and [ACP node type](https://github.com/openclaw/acpx/blob/6b4714c7aaac8c38b1fe38354848d2546f65d87d/src/flows/types.ts#L57-L67).

## What Fits Natively

| Workflow requirement | Representation |
| --- | --- |
| Research, implement, test, then review | Sequential ACP and action nodes |
| Choose a path using model judgment | `decision` plus exhaustive `decisionEdge` choices |
| Route on deterministic conditions | `compute` returns a route; a switch selects one successor |
| Review, repair, and repeat | Back-edge to an earlier node; author a counter and stopping condition |
| Recover from failure or timeout | Switch on `$result.outcome` and explicitly route to recovery or retry |
| Process a discovered list sequentially | Loop with index and accumulated output |
| Use different agents at different steps | Static `profile` per ACP node, including configured local shortcuts |
| Preserve context across steps | Shared session handle with matching command, arguments, and cwd |
| Give a reviewer fresh context on every visit | `session: { isolated: true }` |
| Work in a newly prepared checkout | Action creates a worktree; subsequent `cwd` callback reads its path |
| Reject malformed or invalid model output | `parse` callback performs application-supplied schema validation and throws on mismatch |

These are properties of the public
[node types](https://github.com/openclaw/acpx/blob/6b4714c7aaac8c38b1fe38354848d2546f65d87d/src/flows/types.ts#L26-L144),
[decision helper](https://github.com/openclaw/acpx/blob/6b4714c7aaac8c38b1fe38354848d2546f65d87d/src/flows/decision.ts#L20-L72),
[routing implementation](https://github.com/openclaw/acpx/blob/6b4714c7aaac8c38b1fe38354848d2546f65d87d/src/flows/graph.ts#L41-L102), and
[session binding](https://github.com/openclaw/acpx/blob/6b4714c7aaac8c38b1fe38354848d2546f65d87d/src/flows/runtime.ts#L1081-L1145).
Session isolation supplies fresh conversation context; filesystem isolation
still requires a worktree or another authored mechanism.

## What Needs Additional Orchestration

| Requirement | Boundary in 0.19.3 |
| --- | --- |
| Run three reviewers concurrently, then combine their answers | No native fan-out or barrier join. Each node has at most one outgoing edge; a switch chooses one path. |
| Pause for human approval, then continue the same run | Checkpoint records `waiting` and returns. No public flow-resume API or command exists. |
| Continue after process or machine failure | Run bundles support inspection. A new invocation starts a new run with empty state. |
| Spawn a variable number of child flows | No native map/subflow node or parent-child lifecycle. A graph can be assembled before execution, or a list processed in a serial loop. |
| Start from or fork an existing conversation | Flow session options provide handles and isolation, not an existing session ID or conversation-fork operation. |
| Run on a schedule, webhook, or external event | Requires an external launcher or authored polling; no native trigger API. |
| Enforce a total cost, runtime, or iteration budget | Per-node timeouts exist; whole-workflow limits must be authored. |

The checkpoint limitation is stronger than the word “pause” suggests:
its successor is never executed by that invocation, and calling `run` again
creates a new run. In-process ACP reconnection preserves the provider session
where possible; it does not restore the flow's execution position after a
restart.
[Fresh-state run API](https://github.com/openclaw/acpx/blob/6b4714c7aaac8c38b1fe38354848d2546f65d87d/src/flows/runtime.ts#L206-L252),
[checkpoint return](https://github.com/openclaw/acpx/blob/6b4714c7aaac8c38b1fe38354848d2546f65d87d/src/flows/runtime.ts#L511-L540),
[checkpoint test](https://github.com/openclaw/acpx/blob/6b4714c7aaac8c38b1fe38354848d2546f65d87d/test/flows.test.ts#L1113-L1150),
[public API](https://github.com/openclaw/acpx/blob/6b4714c7aaac8c38b1fe38354848d2546f65d87d/src/flows.ts).

Parallel calls can be put inside an `action.run` callback, or independent flow
runs can execute concurrently. The parent viewer then sees one action rather
than one native node per reviewer. Child scheduling, aggregation, and recovery
belong to the callback or external controller.
[Function-action execution](https://github.com/openclaw/acpx/blob/6b4714c7aaac8c38b1fe38354848d2546f65d87d/src/flows/runtime.ts#L616-L636).

## Authoring Caveats

Retries are explicit edges, without a generic retry/backoff policy. They may
repeat effects already performed, so commands need appropriate idempotency
and completion checks. Loop limits are also explicit. `--timeout` supplies a
per-node deadline, not a whole-run deadline.
[Flow types](https://github.com/openclaw/acpx/blob/6b4714c7aaac8c38b1fe38354848d2546f65d87d/src/flows/types.ts),
[attempt lifecycle](https://github.com/openclaw/acpx/blob/6b4714c7aaac8c38b1fe38354848d2546f65d87d/src/flows/attempt.ts#L86-L134).

Loop attempts remain in step history. `outputs[node]` retains the latest
successful output, even if a later visit fails; recovery logic must consult
the latest result rather than treating that old output as fresh success.
Node profile selection is a static `profile` string. Prompt and cwd callbacks
can use earlier outputs. New flow runs create their own sessions with the run
ID in their names.
[Result updates](https://github.com/openclaw/acpx/blob/6b4714c7aaac8c38b1fe38354848d2546f65d87d/src/flows/runtime.ts),
[session names](https://github.com/openclaw/acpx/blob/6b4714c7aaac8c38b1fe38354848d2546f65d87d/src/flows/runtime-support.ts#L228-L244).

## Verification

Used AgentsView CLI 0.44.0 `session search`, `session messages`, and
`session get` after its automatic archive rebuild completed. Searches covered
acpx with flow/workflow, map, and checkpoint terms; message windows established
the context of the relevant matches. The current conversation was excluded
from follow-up searches. This was a targeted retrieval, not an exhaustive
audit of every historical conversation.

The main thread can be reopened with:

```sh
agentsview session messages 50c18e3f-be76-4422-861e-54a829fcf389 --from 340 --limit 45
```

Inspected release source at `6b4714c7aaac8c38b1fe38354848d2546f65d87d`
and exercised the installed 0.19.3 package with temporary compute/action flows:

- A three-visit loop completed with distinct attempts.
- Two outgoing edges from one node failed validation.
- Failure routed through recovery to a successful retry.
- Checkpoint stopped before its successor; rerunning created a different run ID.
- Two concurrent managed shell calls inside a callback appeared as one action.

These probes made no model/provider calls. Session behavior above was checked
in source and existing upstream tests; those upstream tests were inspected,
not executed. No production workflow was run.
