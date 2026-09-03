# acpx Harness Lanes

The native watch **lane** for Codex, cursor-agent, and pi, plus spectating a
session someone else started. Claude Code's relay lives in `acpx.md`; so does
everything about launching and finishing a run, which is the same in every
lane.

These three lanes rest on version-pinned capability research rather than on a
driven run. Trust them at that weight. The redirected shape from `acpx.md`
works in all three, so fall back to it whenever a lane misbehaves — outside
Claude Code it needs `nohup … &`, because a bare `&` is reaped by
cursor-agent's tool shell.

## Codex: auto-backgrounded terminal

Run acpx as a plain foreground command. Unified exec yields after at most ~30s
and converts the run into a background terminal rather than killing it.

Hold liveness with long empty `write_stdin` polls: they block up to
`background_terminal_max_timeout` (default 300s) and early-return on output or
exit. Nothing wakes the model between calls, so keep one poll outstanding
until the marker lands.

The human follows through the footer terminal counter and `/ps`, which shows
the command plus its last 3 output lines. Mirror the run's phases into
`update_plan` to give them a visible task row.

## cursor-agent: background job and Await

Run acpx as a background shell command, or let the timeout auto-background it.
The agent is woken with a new turn when the job completes, and the `Await`
tool's `regex` argument blocks on stream milestones such as `\[done\]` or
`\[error\]`, so output-notification patterns give mid-run wakeups without
polling.

The human gets the Tasks pager at the `/jobs` slash entry: a live log view per
job, and `k` to abort.

## pi: native live tail

pi's bash tool streams live already — a rolling tail with an elapsed counter,
expandable in the TUI, no default timeout, full output saved to a temp file on
truncation — so a plain foreground run is watchable as-is. A custom extension
tool with `onUpdate` streaming is the richer lane if pi becomes a daily acpx
driver.

## Spectating a session you did not start

A persistent session (not `exec`) appends the raw ACP wire log to
`~/.acpx/sessions/<recordId>.stream.ndjson` whatever `--format` says, so any
process can follow it. Find the record id with `acpx <agent> sessions show`,
or `sessions list --local`, then:

```bash
tail -f ~/.acpx/sessions/<recordId>.stream.ndjson | jq -j '
  select(.method=="session/update") | .params.update |
  if .sessionUpdate=="agent_thought_chunk" then "\u001b[2m"+(.content.text//empty)+"\u001b[0m"
  elif .sessionUpdate=="agent_message_chunk" then (.content.text//empty)
  elif .sessionUpdate=="tool_call" then "\n[tool] "+(.title//"")+"\n"
  else empty end'
```

Treat wire logs as sensitive: they keep full prompts, reasoning, and tool
output. `sessions close` then `sessions prune --include-history` removes them.
An `exec` one-shot writes no wire log, so its redirected log file is the only
trail it leaves.
