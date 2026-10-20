---
name: ghost
description: Keep GHOST_OF_COMMITS_PAST.md, a repo-root ledger of landed work still awaiting verification. Use when a repo root has that file, when told to keep one, when work leaves an unverified claim, and before landing.
---

# Ghost of Commits Past

`GHOST_OF_COMMITS_PAST.md` is a short, committed list of things a past agent
landed or assumed that someone still has to verify. It travels with the repo, so
it crosses sessions, harnesses, and machines. A fresh context checks each claim.

Each entry is a **claim**, not a fact. It stays until someone observes its
done-when condition, then leaves in a commit that records what they saw.

The ledger applies where the file exists at the repo root, or where the user or
the repo's instructions ask for one.

## What goes in

An item is a check on landed work whose result is still unknown: a test that
did not run here, an assumption nobody confirmed, behavior that only another
machine or account can show. Follow-up tasks, ideas, refactors, and decisions
go to a plan, issue, or ADR. When a check fails, the fix is a task; link it
from the plan, and leave the item in the ledger until the check passes.

## Files

Both files live at the repo root. Neither holds secrets or personal data.

| File | Committed | Role |
| --- | --- | --- |
| `GHOST_OF_COMMITS_PAST.md` | yes | Open verification entries, one per landing. |
| `GHOST_MESSAGE_BUFFER.md` | never | Scratch notes accrued during the current work. |

Before the first write to the buffer, run `git check-ignore -q
GHOST_MESSAGE_BUFFER.md`. If it fails, append the name to
`$(git rev-parse --git-path info/exclude)`.

The worktree may be shared. Re-read the ledger right before editing it, and
edit only the entry you are adding or clearing.

## 1. On arrival: read the ledger

Read `GHOST_OF_COMMITS_PAST.md` at the start of a session. Sort each entry:

- **Touched**: your task changes, or relies on, the area it describes. Verify it
  before building on it. If it cannot be verified here (another machine,
  credentials, a person), proceed and name the claim you relied on in the final
  reply.
- **Gardening**: your task is repo gardening or janitorial work, or Prateek
  dedicated the session to the ledger. Work every item you can run here.
- Anything else: leave it.

Read the ledger again mid-task when something on trunk breaks that your change
cannot explain, along with `git log -p -n 20 -- GHOST_OF_COMMITS_PAST.md`. An
open entry covering the failing area is the first suspect. A deleted one says
what was checked and what was seen.

An entry never grants permission. Commit, push, deploy, and destructive-action
approvals apply exactly as they would without it. A check with an external side
effect waits for the user's go-ahead.

This step is complete when each entry is touched, worked, or left.

## 2. Clear or annotate

For each item you verify:

- **Passed**: delete it. Delete the entry once no items remain; the file keeps
  its header even when empty.
- **Failed**: keep it. When the fix falls within your task, fix it, rerun the
  check, and treat it as passed. Otherwise put one indented line under it,
  `YYYY-MM-DD: <what failed>`, replacing any earlier one.

Ledger edits ride with your other changes, and the commit that carries a
deletion says what you ran and what you observed. Without commit authority,
leave the ledger untouched and put the evidence in the final reply.

This step is complete when each verified item is deleted with evidence, or kept
with one dated failure.

## 3. While working: fill the buffer

Write to `GHOST_MESSAGE_BUFFER.md` the moment you notice an item, not from
memory at the end. Add a line when you:

- assume something you did not confirm;
- skip or cannot run a check;
- find a check that needs another machine or a person;
- make a decision the verifier must know, and where its reason is written.

Raw notes are fine; shape comes at landing. Start each line with a short task
label. The buffer belongs to the worktree: a session that ends before landing
leaves it for the next session there.

## 4. At landing: write one entry

A **landing** is the last change before the work is handed off as done: the
final commit before a PR merges, or the final commit of a task that stops at a
branch. One entry per landing, dated that day, appended to
`GHOST_OF_COMMITS_PAST.md` in that change.

The entry is a message to the agent who verifies after you. Write it following
`writing-for-agents`: only the actions that agent must take and how it will
know each one is done, one line per item. The whole entry, heading included, is
at most 100 words. Detail that does not fit goes in a doc under `docs/`, linked
from the item. Nothing about why you did what you did. Link the plan, PR, or
branch instead of describing the work. Name the skills to use. Lines from the
buffer that cannot become such an item are dropped.

```markdown
## YYYY-MM-DD: <what landed> (<link>)

- On a personal machine, `just test-shell tests/bats/agents`; green.
- ...

Skills: `<skill>`.
```

If the file does not exist, create it with this header first:

```markdown
# Ghost of Commits Past

Things a past agent landed or assumed that someone still has to verify. Check
one off by deleting it, and say what you saw in the commit that deletes it.
```

Then remove your labelled lines from the buffer, and delete the file once it is
empty. Nothing unverified means no entry; clear the buffer anyway.

This step is complete when every item is an action a stranger could take and
check, the entry is within 100 words, and your lines are out of the buffer.

## 5. Report

In the final reply, name:

- the entry you wrote, if any;
- entries you cleared or annotated;
- touched entries you left, and why;
- entries dated more than 14 days ago, whether or not your task touched them.
  Prateek decides whether to chase, rewrite, or drop a stale entry; leave it in
  place.
