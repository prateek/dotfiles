# acpx Harness Lanes

Read this reference after choosing a launch shape in [SKILL.md](../SKILL.md) when a
run must be watched, relayed, cancelled, or recovered.

## Completion markers

In text output, the final line determines the result:

- `[done] end_turn`: natural completion.
- `[done] cancelled`: cancellation reached the ACP session.
- `[error]` as the last line: terminal failure.
- `[error]` before later output: recoverable adapter noise; report it and keep
  watching.
- No final marker: the outcome is unknown. A crash or lost observer can leave
  the persistent turn running; follow the recovery procedure below.

The final answer is the assistant text immediately before the terminal marker.

Under `acpx-pane`, the Orca viewer is the human-visible trail and the log carries
acpx's text output. Harnesses that normally watch a direct run wait for the helper
to return, then read the log.

## Recover an interrupted task

Use this procedure before continuing a failed, cancelled, or partially completed
task, or after a timeout, crash, lost terminal, or missing final result.
Preserve the existing logs and session receipt while classifying the interruption.

1. **Recover the scope.** Read the task's saved receipt and launch options.
   Restore the exact `session`, absolute `session_cwd`, and guarded `acpx_agent`.
   If the receipt is missing, recover the command from the original launch and
   use `acpx --format json --agent "$acpx_agent" sessions list --local` to locate
   candidates. Local listing filters by agent command; the default Codex list
   will not discover guarded routes. If the command is also lost, inspect local
   record metadata under `~/.acpx/sessions/` scoped to the known cwd/task. Match
   cwd, command, name, history, and model to the task. A similar name alone is
   insufficient. Complete this step with one verified active session and its saved
   `acpxRecordId` and `acpSessionId`, or report that continuity cannot be established.
   Inspect it without running `sessions ensure`:

   ```bash
   scope=(--cwd "$session_cwd" --agent "$acpx_agent")
   acpx --format json "${scope[@]}" sessions show "$session"
   acpx --format json "${scope[@]}" status -s "$session"
   acpx --format json "${scope[@]}" sessions history "$session" --limit 20
   ```

   Require `closed == false`, the exact cwd, command, name, and saved record ID;
   `show` can return closed records, while `prompt` skips them and searches ancestor
   directories. Verify backend ID, model, and thinking against the saved task receipt.
   A missing/closed record, changed established backend, or unsupported resume
   ends continuation without creating a replacement conversation.

   The saved command's route guard can expire or become invalid after a selection
   change, even when the model is unchanged. `show`, `history`, `status`, `watch`,
   and `cancel` do not launch the adapter and remain available with that command.
   A continuation may fail when it reconnects. If the saved guard no longer
   validates, mark continuation unavailable and complete steps 2–3 with the saved
   command before reporting the audit and stopping. Do not refresh the global selection, append
   `--allow-stale`, or substitute a new command to resume: each can invalidate the
   guard or change the session scope. Repairing that limitation requires a separate
   routing-helper change.

2. **Classify the interrupted turn.** Correlate the saved request ID with its
   events. If the post-prompt receipt is missing, inspect the current record's
   `lastRequestId` and match it to the submitted prompt and watch events. A crash
   can leave a raw JSON-RPC ID in that field. If it matches no `turn_started`, use
   the latest `turn_started` after the last settled cursor, matched to the submitted
   prompt, only when a single submitter and a unique candidate establish identity.
   If no cursor was saved, establish that boundary from retained lifecycle events
   and the previous receipt; otherwise report the outcome as unknown. Text prompt
   logs contain no request ID. If another submitter could have changed
   the record, or more than one request could match, report the ambiguity and stop.
   `status` describes queue-owner health; an alive owner may be idle, and a dead
   owner does not prove that no work happened.

   Watch without submitting another prompt. Run this whole block as a managed
   background task, retain its task/terminal handle, and read bounded chunks of
   its log through that harness's monitor or relay:

   ```bash
   umask 077
   watch_log=$(mktemp /tmp/acpx-watch.XXXXXX)
   echo "watch log: $watch_log"
   acpx --format json --cwd "$session_cwd" --agent "$acpx_agent" \
     sessions watch -s "$session" > "$watch_log" 2>&1
   ```

   Restore the saved variables in that same shell before launching. Add
   `--cursor "$cursor"` when a saved watch cursor exists; otherwise replay
   retained history. The watcher remains open even when the session is idle.
   On the target request's `turn_result`, retain its cursor and result, then stop
   **the watcher task by its handle** and drain the log. Also stop it on a terminal
   watcher error. Stopping the watcher does not cancel the delegated work.

   Keep observing an active or queued request; another turn's completion does
   not settle it. `WATCH_OUTCOME_UNKNOWN`, `WATCH_CURSOR_EXPIRED`, and
   `WATCH_OWNER_UNSUPPORTED`, a missing result, or an uncertain queue state leave
   the outcome unknown. Inspect retained logs and scoped processes, or use the
   cancellation procedure below, then reclassify. Finish with a settled result
   and no unfinished work for this task, or report uncertainty without resubmitting.

3. **Reconcile completed work.** Recover any retained answer and inspect tool
   calls and actual effects for every outcome:
   the checkout's current diff, created files, test output, and any external
   operation receipts. History previews alone are not a complete audit. Account
   for each attempted mutation and determine the remaining work. If an external
   effect cannot be verified, report it and leave the dependent retry pending.
   After a user cancellation, report the result and audit from steps 1–3, then
   stop until the user gives renewed direction. If the guard blocks continuation,
   report that limit with the audit and stop before step 4. Otherwise compare the retained
   result and effects with the original goal. If complete, skip continuation and
   proceed to step 5 with the answer and audit.

4. **Continue the verified session.** Resume only remaining authorized work.
   When the previous turn has settled and its effects are accounted for, correct
   the identified failure
   within that scope. Write a new continuation prompt stating the original goal,
   verified completed work, remaining work, and current permission constraints.
   Keep the previous logs. Use a fresh log and prompt file and the recorded
   launch options, with `--prompt-retries 0` for this recovery turn and no model
   or configuration overrides. Do not run `ensure` or `new`. Send
   `prompt -s "$session" -f "$prompt_file"` through the normal direct or Orca
   pane lane. Capture a new post-prompt receipt, including `lastRequestId`.
   Complete this step only after the new turn settles; a repeated failure
   returns to classification instead of replaying the original prompt.

5. **Verify continuity and finish.** Compare the saved and current `acpSessionId`,
   model, and thinking. Report a backend replacement as lost continuity even if
   the new turn produced an answer. Save a fresh receipt without overwriting the
   earlier one, audit the new tool calls, and report the outcome, session name,
   and any remaining work.

## Cancel a persistent turn

Use the recorded session scope to cancel work, including a queued turn:

```sh
acpx --format text --cwd "$session_cwd" --agent "$acpx_agent" cancel -s "$session"
```

The command returns `cancel requested` or `nothing to cancel`; neither is a
settled turn result. Confirm through the original prompt's `[done] cancelled`, or
through the target request's `turn_result` using the managed watcher in step 2.
Drain that output and stop the watcher. For `nothing to cancel`, classify the
request through step 2; it does not prove completion. Stopping a waiting shell process can leave the retained queue owner running; it
does not prove the turn stopped. After cancellation, stop the waiting
helper if needed. Keep the ACP session available for follow-ups. If cancellation
cannot be confirmed, report the outcome as unknown before attempting recovery.

## Orca: viewer

`acpx-pane` runs acpx in the caller's process: the log, the exit status, and
`Ctrl+C` behave as they do inline. Before the run starts, it makes sure the
current Orca worktree has a viewer: one split beside the caller, running
`pi-viewer acpx` (the pi viewer that chezmoi links from the dotfiles repo's
`src/pi-viewers/`). Later runs in the same worktree reuse it; another worktree
gets its own. A viewer whose pane was closed reopens on the next run.

The viewer lists every open acpx session under the worktree and shows the
selected run's transcript: one row per tool call, expandable with a click or
Enter, with the live thinking and running tool expanded. Press `?` there for its
keys; they are the same keys as the workflow viewer's, and the list's placement
and size persist between launches. It only watches, so closing it never affects
a run. Cancelling from the viewer (`x`, then `y`) runs `acpx cancel` for the
selected session.

The helper checks the caller's current worktree before splitting beside its
terminal. If an inherited handle belongs to another worktree, it selects the
current worktree's sole agent terminal; if no parent is available, it runs
without the viewer. To open the viewer, or switch Orca back to it, run
`~/.agents/plugins/plugins/utils-agent/skills/acpx/scripts/acpx-pane --view`.
Missing `pi-viewer`, pi, or Python 3, or a failed split, falls back to the inline run.
Outside Orca, or with `--inline`, the helper runs acpx in place with the
redirect.

## Claude Code: redirected relay

Claude Code watches the redirected log created by the canonical launch in
[SKILL.md](../SKILL.md). Use one blocking `~/.agents/bin/poll-stream` call per wait;
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

Cancel through the named session as above, then stop the background task if it
is still waiting. Under `acpx-pane`, stopping the helper stops only its acpx
process; the viewer and other runs stay open.

When a native first-party monitor is available, use it instead of the relay
because it wakes on stream output.

## Codex: managed background terminal

Run acpx as a foreground command. Codex can convert a long command into a
managed background terminal. Keep one long blocking wait outstanding until
output or completion rather than polling rapidly.

The terminal view and process list provide the human-visible trail. The named
ACP session retains its event stream; keep a per-prompt log when the audit needs it.

## cursor-agent: background job

Run acpx as a background shell job or let the command timeout background it.
When starting it manually with `&`, use `nohup` and redirect stdout and stderr
to a slug-specific log; cursor-agent's tool shell can reap a bare background
process. Use the redirected launch in [SKILL.md](../SKILL.md) as the fallback shape.
Use escaped regular-expression notification patterns for stable milestones,
such as `\[done\]` and `\[error\]`, and await only when the next step depends
on the result.

The task viewer owns the live log. Cancel through the named session before
stopping the waiting task in the viewer.

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
longer needed and cleanup is requested. Keep the named session available for
follow-ups after a prompt completes.

## Completion

- The selected lane exposes progress without rapid polling.
- The terminal marker and process result agree.
- All final assistant output has been drained before handoff.
- Cancellation targets only the delegated run.
- Sensitive logs are retained only as long as the task requires.
