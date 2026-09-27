---
status: proposed
doc_type: plan
owner: Prateek
created: 2026-09-26
updated: 2026-09-27
related:
  - agent-friction-remediation-plan.md
  - agent-session-wiki-plan.md
  - ../adr/0017-agent-session-archive.md
status_detail: "Proposal for completed-session retros and recurring reviews; no schedule enabled."
---

# Periodic session review — plan

## Problem

Agent sessions record every failed command, retry, slow step, and repeated
manual prompt, across every repo and host. Nobody reads them in aggregate, so
recurring friction stays invisible until it is bad enough to notice by hand.
The 2026-09-26 review showed how large that blind spot is: about 3,000 failed
commands from one zsh default, and two long prompts typed by hand more than 100
times. It also showed that a one-off review decays: its scripts lived in a
private directory, one screening step was never saved, and two regex bugs hid
most Claude failures.

## Goals

- Review each completed session for its own friction and outcome, then group
  recurring failure modes and useful optimizations across sessions.
- Turn each recurring pattern into a fix with a falsifiable acceptance check.
- Re-check every open acceptance check on each run, so fixes are confirmed or
  reopened with data rather than memory.
- Keep reports and transcript excerpts private.

## Non-goals

- Cross-harness failure-rate league tables. Harnesses retain different data.
- Unbounded autonomous changes or automatic publication.

## Cadence and inputs

Proposed defaults: a retrospective when each session completes, a weekly
incremental review, and a monthly sweep of older history and open acceptance
checks. None is scheduled by this plan. Backfill all available history in
bounded date/host/harness batches. Checkpoint source revision, cursor, counts,
and classification state after each batch; resume from that checkpoint rather
than starting over.

Each run takes one snapshot and records it:

- A copy-on-write clone of the AgentsView store (`cp -c
  ~/.agentsview/sessions.db`), never the live file, with its max message
  timestamp and session count.
- The session archive at a recorded `origin/main` revision, for hosts and
  transcripts AgentsView does not index.
- Coverage start and end by host, harness, and date. Deduplicate sessions
  appearing in both stores by stable source identity and transcript overlap.
  Silence after a host's last record reads as missing data, not as a fix.

## What a run looks for

- Failures: nonzero exits and tool errors, grouped by shape (for example an
  unknown flag on one CLI, an unmatched glob, an untrusted config), not by
  raw regex category.
- Waste: repeated retries of the same command, truncated output that forces a
  rerun, polling loops, long waits.
- Manual repetition: long prompts a human pastes repeatedly, and bare "try
  again" messages that re-drive a failure.
- Instruction drift: skills or conventions whose documented commands fail
  against installed tools.

Each shape is classified as a current failure, historically fixed issue,
exploratory probe, quoted content, test of code under development, or tool
error. Findings cite primary transcript spans and a reproduction attempt
against the current tool before a fix is proposed. The
classifier is checked against a blind-labeled sample before counts are
trusted.

## Output

A private report under `~/.local/state/session-review/<date>/` with:

- A coverage table by harness, host, and date, including gaps and dedup counts.
- A completed-session retrospective with task outcome, friction, and primary
  transcript references.
- Shapes ranked by count and by root task, with sanitized exemplars.
- For each new recurring shape: a proposed fix, its owner, and an
  acceptance check.
- The status of every open acceptance check from earlier runs.

Route fixes to their owning repos. Prefer tested helpers for repeatable
mechanical defects over longer instructions. Preserve unrelated work. A
scoped automatic fix may edit a task-owned worktree after reproducing a current
failure and passing the relevant check; it may not land, activate runtime
state, schedule work, or publish. Record each finding separately as proposed,
implemented, activated, and live-verified. Measure recurrence over covered
sessions after activation. Reports and transcript excerpts remain private.

## Tooling

Promote the extraction, classification and coverage scripts from the
2026-09-26 review into `scripts/audit/` after a bounded backfill reproduces
that review's counts. Carry its two corrections: Claude Code
reports `Exit code N` without a colon, and zsh errors from Claude arrive with
an `(eval):N:` prefix.

## Data completeness

AgentsView keeps no tool results for Cursor sessions (95,837 calls, zero
results in the 2026-09-26 window), so Cursor failures are invisible to any
review. Ask AgentsView upstream to retain tool results for every harness it
parses; filing that request needs Prateek's approval.

## Acceptance

- A bounded historical backfill produces checkpointed private reports from
  fresh snapshots and reproduces the 2026-09-26 counts within classifier error.
- A completed-session retrospective cites the source transcript and verifies
  its task outcome; the weekly and monthly reports identify coverage gaps.
- Every open acceptance check from the agent friction remediation plan has a
  recorded status in that report.
- No host's coverage in a run is more than 3 days stale, or the report says
  which host is and why.

## Open questions

- Whether a scheduled Orca automation or a manual prompt runs each cadence.
- Where the blind-labeling sample comes from on each run, and how large it
  needs to be to keep failure precision above 85%.
