# Export formats

`scripts/perf-view` writes each of these from the same span JSON, following
the sources linked under each heading.

## Trace Event JSON: Perfetto UI and chrome://tracing

Open at <https://ui.perfetto.dev> (drag the file in) or `chrome://tracing`.

- Top level: `{"traceEvents": [...], "displayTimeUnit": "ms"}`.
  `displayTimeUnit` changes display only.
- `ts` and `dur` are microseconds and may be fractional: Perfetto imports
  `"ts": 5.1` as 5100 ns.
- `ph: "X"` is a complete slice with `dur`; `ph: "I"` is an instant with scope
  `s` of `g` (global), `p` (process), or `t` (thread).
- `ph: "M"` metadata named `process_name` or `thread_name` labels tracks through
  `args.name`.
- Slices on one thread must nest. Perfetto moves overlapping, non-nested slices
  to an overflow track, so perf-view refuses partial overlap on one track.
- Perfetto calls JSON a legacy, best-effort format; its native format is
  protobuf TrackEvent. Prefer that for production instrumentation, and JSON for
  generated views like these.

Sources: Perfetto [other formats](https://github.com/google/perfetto/blob/main/docs/getting-started/other-formats.md),
[FAQ](https://github.com/google/perfetto/blob/main/docs/faq.md), and
[JSON parser tests](https://github.com/google/perfetto/blob/main/test/trace_processor/diff_tests/parser/json/tests.py).
The canonical spec is the Trace Event Format Google Doc they link.

## speedscope

Open at <https://www.speedscope.app>, or install with `npm install -g speedscope` and run `speedscope profile.json`.

- `{"$schema": "https://www.speedscope.app/file-format-schema.json",
  "shared": {"frames": [{"name": ...}]}, "profiles": [...]}`.
- An `evented` profile has `name`, `unit` (`nanoseconds` to `seconds`, `bytes`,
  `none`), `startValue`, `endValue`, and `events` of
  `{"type": "O"|"C", "frame": <index>, "at": <value>}` in non-decreasing `at`.
  Opens and closes must balance like a stack.
- perf-view writes one evented profile per track. speedscope also imports Trace
  Event JSON directly.

Source: [file-format-spec.ts](https://github.com/jlfwong/speedscope/blob/main/src/lib/file-format-spec.ts).

## Folded stacks: flamegraphs

One line per stack: frames separated by `;`, a space, then an integer weight.
perf-view writes `track;outer;inner <self time in ns>`. Self time under half a
nanosecond rounds away. The format has no escape, so `;` in a name becomes `,`
and newlines become spaces; names that differ only there merge.

```sh
inferno-flamegraph --countname ns --title "fork" stacks.folded > flame.svg
flamegraph.pl --countname ns stacks.folded > flame.svg
```

A flamegraph merges identical stacks and sorts frames alphabetically, so it
answers "where does time go in aggregate", not "in what order". Concatenate
folded files from many runs to aggregate them. perf-view's folded output also
merges same-name siblings and writes each stack's self time on one line, so
`--flamechart` does not recover a timeline from it; use a Trace Event view.

Sources: [inferno README](https://github.com/jonhoo/inferno) and
[`flamegraph` options](https://github.com/jonhoo/inferno/blob/main/src/bin/flamegraph.rs),
[FlameGraph README](https://github.com/brendangregg/FlameGraph).
