# acpx delegation evaluations

Two files, two lanes.

`trigger-evals.json` is the trigger lane: does the description make the model
reach for this skill, and stay out of it when the request belongs elsewhere? It
is skill-creator's flat `{query, should_trigger}` format and runs unattended.

`evals.json` is the behavior lane: given that the skill loaded, does the
invocation it builds match what the skill says — shortcut choice, flag
placement, the passthrough, and an honest account of what the permission flags
do not do? Run those by asking for the intended action and the exact
invocation, keep `expectations` hidden until grading, and grade behavior, not
wording. No case authorizes spawning a real delegate. Case 6 is the one to
re-run after any acpx or adapter upgrade: if an adapter starts sending
`session/request_permission`, re-probe, update the skill, then expect its
grading to change.

## Running the trigger lane

```bash
evals/run_trigger_evals.sh            # 18 queries × 3 runs, about 13 minutes
evals/run_trigger_evals.sh --runs 1   # quick pass
```

The wrapper materializes a fresh fixture with `setup_fixture.sh`, runs
skill-creator's `scripts/run_eval.py` from inside it, and prints the runner's
JSON to stdout with the per-query table on stderr. Each run is one `claude -p`
turn: the runner kills the process at the first tool decision, so nothing a
delegate would do ever executes, and cost is one short turn per run.

Three properties of the runner shape the numbers:

- **It scores the first tool call only.** A run counts as a trigger when the
  first tool call is the skill; a `Read` of the file to scope the task before
  delegating counts as a miss, however sensible. Queries therefore name paths
  the fixture provides, so there is nothing to hunt for first.
- **It must run serially.** Every run drops a temporary command into the
  fixture's `.claude/commands/`, and concurrent workers share that directory,
  so parallel runs see several identical acpx entries and score each other's
  picks as misses. Four workers gave 0/27 on the positives; one worker gives
  the numbers below. The wrapper pins `--num-workers 1`.
- **It runs against the installed listing.** The temporary command competes
  with whatever is actually installed. Today that includes the vendored acpx
  skill carrying upstream's description verbatim, which is exactly the
  arbitration this skill depends on, and the machine conventions' old pointer
  to `~/.agents/docs/acpx.md`. The fixture's `CLAUDE.md` retires that pointer,
  because a model that obeys it reads the doc before loading any skill and
  every delegation query scores as a miss (34 of 44 first-tool misses in the
  unneutralized run). Drop that line from `setup_fixture.sh` once every machine
  has applied the change that deletes the pointer.

## Results

2026-09-08, `claude-fable-5-1`, installed listing with `utils-agent` 1.2.1
(vendored `acpx` skill, upstream description), serial, 3 runs per query:
**15/18**.

| Outcome | Runs | Reading |
| --- | --- | --- |
| Shortcut named, second opinion, run-it-elsewhere (7 positives) | 21/21 router | The description fires without the user naming acpx. |
| Command-surface near misses: prune, named session, `NO_SESSION`, `defineFlow` (4 negatives) | 12/12 vendored skill | The two descriptions split the subject as intended; no narrowing needed. |
| Subagent, background test run, check-it-yourself (4 negatives) | 12/12 stayed local | Adjacent intents do not pull the router in. |
| "the intro in README.md reads like a press release… rather than doing it yourself" | 1/3 | Both misses read the intro first to scope the brief, then delegated. First-tool rule, not a trigger failure. |
| "farm the migration audit out to another agent, i don't want the files… eating my context" | 0/3, all Agent tool | "Another agent" plus a context-budget motive reads as a built-in subagent. The description's run-it-elsewhere clause does not beat that, and arguably should not. |
| "ask the opus model whether the index… will actually get used, and then update the migration if it won't" | 3/3 router | Labeled should-not-trigger on the premise that naming a model family is not a delegation request. The model disagrees, coherently: delegate the question, act on the answer locally. Likely a mislabel; decision pending. |

Trigger behavior moves with the model, the rest of the installed listing, and
the listing budget. A regression here is as likely to be a budget or listing
problem as a description problem, so check those before rewording.
