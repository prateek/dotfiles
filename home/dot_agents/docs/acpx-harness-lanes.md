# acpx Harness Lanes

Read this reference after choosing a launch shape in [acpx.md](acpx.md) when a
run must be watched, relayed, cancelled, or recovered.

## Completion markers

In text output, the final line determines the result:

- `[done] end_turn`: natural completion.
- `[done] cancelled`: cancellation reached the ACP session.
- `[error]` as the last line: terminal failure.
- `[error]` before later output: recoverable adapter noise; report it and keep
  watching.
- No final marker: a crash, SIGKILL, or other hard failure. The harness process
  completion is the backstop.

The final answer is the assistant text immediately before the terminal marker.

## Claude Code: redirected relay

Claude Code watches the redirected log created by the canonical launch in
[acpx.md](acpx.md). Use one blocking `~/.agents/bin/poll-stream` call per wait;
read the helper's header for its current arguments and exit codes.

```sh
~/.agents/bin/poll-stream "$log" "$log.offset" 240 8192 > /tmp/chunk
```

1. Read the launch task's `log:` line before polling.
2. Set the shell timeout above the helper's maximum wait. The default
   240-second wait needs at least 270 seconds.
3. Capture each chunk in a file before reading it. A pipe to an early-exiting
   reader can lose bytes while still advancing the offset.
4. Relay each chunk, then inspect the log tail in a separate command.
5. For `[done]`, stop only after a five-second `poll-stream` drain returns no
   bytes. For a final `[error]`, wait for process exit, drain remaining output,
   then stop and report the failure.

The terminal marker, process state, and drain are all required because byte
limits can split a marker or leave earlier output unread. Treat the harness
completion notification as the backstop for a markerless run.

Cancel by stopping the background task or killing only the slug-specific
process. A broad kill can terminate cursor-agent's shared authentication
worker.

When a native first-party monitor is available, use it instead of the relay
because it wakes on stream output.

## Codex: managed background terminal

Run acpx as a foreground command. Codex can convert a long command into a
managed background terminal. Keep one long blocking wait outstanding until
output or completion rather than polling rapidly.

The terminal view and process list provide the human-visible trail. A direct
acpx run itself leaves no separate log.

## cursor-agent: background job

Run acpx as a background shell job or let the command timeout background it.
When starting it manually with `&`, use `nohup` and redirect stdout and stderr
to a slug-specific log; cursor-agent's tool shell can reap a bare background
process. Use the redirected launch in [acpx.md](acpx.md) as the fallback shape.
Use escaped regular-expression notification patterns for stable milestones,
such as `\[done\]` and `\[error\]`, and await only when the next step depends
on the result.

The task viewer owns the live log and cancellation path.

## pi: native live output

Run acpx in the foreground. pi's shell surface streams a rolling tail, retains
the complete output in a temporary file when truncated, and has no default
timeout.

## Spectating an existing session

A persistent session writes its ACP event stream under
`~/.acpx/sessions/<recordId>.stream.ndjson`. Find the record with acpx's session
commands, then follow the file with a scoped reader.

```sh
tail -f ~/.acpx/sessions/<recordId>.stream.ndjson | jq -j '
  select(.method=="session/update") | .params.update |
  if .sessionUpdate=="agent_thought_chunk" then
    "\u001b[2m"+(.content.text//empty)+"\u001b[0m"
  elif .sessionUpdate=="agent_message_chunk" then
    (.content.text//empty)
  elif .sessionUpdate=="tool_call" then
    "\n[tool] "+(.title//"")+"\n"
  else empty end'
```

Treat event streams as sensitive: they contain full prompts, reasoning, and
tool output. Close the session and prune its history when retention is no
longer needed. An `exec` one-shot has no event stream; only an explicitly
redirected log provides a trail.

## Completion

- The selected lane exposes progress without rapid polling.
- The terminal marker and process result agree.
- All final assistant output has been drained before handoff.
- Cancellation targets only the delegated run.
- Sensitive logs are retained only as long as the task requires.
