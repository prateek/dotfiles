# acpx delegation evaluations

Two files, two lanes.

`trigger-evals.json` is the trigger lane: does the description make the model
reach for this skill, and stay out of it when the request belongs elsewhere? It
is a flat `{query, should_trigger}` list and runs unattended.

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
evals/run_trigger_evals.sh                                   # 18 queries × 3 runs, ~3 minutes
evals/run_trigger_evals.sh --runs 5 --transcripts /tmp/te    # for a decision, with evidence
```

The wrapper builds a fresh fixture with `setup_fixture.sh`, runs
`trigger_eval.py` from inside it, and prints the runner's JSON to stdout with
the per-query table on stderr. Each run is one `claude -p` turn: the runner
kills the process at the first tool decision, so nothing the model chose ever
executes.

`trigger_eval.py` measures the **installed** skill against the real listing. It
does not inject a temporary command the way skill-creator's `run_eval.py` does;
that trick is only meaningful before the skill is installed, because a copy
next to the real `utils-agent:acpx` double-lists it and the installed one wins
— which scored as misses in that runner. So:

- `utils-agent` 1.3.0 or later must be materialized under `~/.agents/plugins`
  (both `acpx` and `acpx-cli`); the wrapper refuses to run otherwise.
- The eval scores the installed description, not this checkout's. The wrapper
  warns when they differ; apply before measuring an edit.
- Nothing is written into the listing per run, so `--workers` (default 3) is
  safe.
- **It scores the first tool call only.** A `Read` of the file to scope the
  brief before delegating counts as a miss, however sensible. The pre-tool text
  is kept per run and printed for misses under `--verbose`; `--transcripts DIR`
  saves every run's event stream.
- The fixture writes a project `CLAUDE.md` retiring the old
  `~/.agents/docs/acpx.md` pointer only while the installed `~/.agents/AGENTS.md`
  still carries it (`pointer_shim=yes|no` on stderr). A model that obeys that
  pointer reads the doc before loading any skill, and every delegation query
  scores as a miss (34 of 44 first-tool misses in the one unneutralized run).

Trigger behavior moves with the model, the rest of the installed listing, and
the listing budget. Compare like with like: same model, same installed version.
A regression is as likely to be a budget or listing problem as a description
problem, so check those before rewording.

## Results

All on 2026-09-08. The per-query table for each run is in that run's stderr;
these are the shape of the outcome.

| Run | Runner, listing, model | Score |
| --- | --- | --- |
| Pre-install | skill-creator `run_eval.py` (temp command), `utils-agent` 1.2.1, pointer shim, serial, `claude-fable-5-1` | 15/18 as labeled; 16/18 after case 8 was relabeled |
| Installed, run A | `trigger_eval.py`, `utils-agent` 1.3.0, no shim, 3 workers, `claude-opus-5` | 13/18 |
| Installed, run B | same as A, twenty minutes later | 15/18 |

Stable across every run:

- The four command-surface negatives (prune, named session, `NO_SESSION`,
  `defineFlow`) go to `acpx-cli`, 3/3 each. The split between the two
  descriptions holds with upstream's wording verbatim; no narrowing needed.
- The subagent negative goes to the `Agent` tool 3/3; the background-test,
  check-the-regex, and read-it-yourself negatives stay local. Nothing leaks
  into the router.
- Positives that name a shortcut (`agptx`, `afablex`) or ask for a branch
  review (`afable` session, `agpt` read-only review) route first, 3/3.

What moves between runs is the file-scoped positives with no shortcut named —
"have opus look over `docs/design/sharding.md`", "ask the opus model whether
the index in `0007_add_orders_idx.sql` will get used", the README rewrite. Under
`claude-opus-5` these flip between 0/3 and 3/3 from one run to the next, and
the pre-tool text says why: "I'll look at the README first, then hand the
rewrite off." The decision to delegate is right; the order is what the runner
scores. With three runs and a 0.5 threshold those queries sit on the boundary,
so use `--runs 5` before acting on a change in them.

Two boundaries are documented, not defects:

- "farm the migration audit out to another agent, i don't want the files…
  eating my context" goes to `Bash` then a subagent every time. "Another agent"
  plus a context-budget motive reads as the built-in Agent tool; the
  description's run-it-elsewhere clause does not beat that, and arguably should
  not.
- Case 8 ("ask the opus model … then update the migration if it won't") was
  first labeled should-not-trigger on the premise that naming a model family is
  not a delegation request. The model read it as one, coherently — delegate the
  question, act on the answer locally — and the label was flipped to
  `should_trigger: true` in both eval files.
