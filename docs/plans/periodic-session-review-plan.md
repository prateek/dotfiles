---
status: proposed
doc_type: plan
owner: Prateek
created: 2026-09-26
updated: 2026-09-26
related:
  - agent-friction-remediation-plan.md
  - agent-session-wiki-plan.md
  - ../adr/0017-agent-session-archive.md
status_detail: "Proposal for a recurring review of agent sessions; not scheduled yet."
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

- Review agent sessions on a fixed cadence for repeated failure modes and for
  optimizations the sessions expose.
- Turn each recurring pattern into a fix with a falsifiable acceptance check.
- Re-check every open acceptance check on each run, so fixes are confirmed or
  reopened with data rather than memory.
- Keep reports and transcript excerpts private.

## Non-goals

- Reviewing individual sessions for quality. The unit is a pattern that
  recurs across sessions.
- Cross-harness failure-rate league tables. Harnesses retain different data.
- Automating fixes. A run produces findings; applying them is ordinary work.

## Cadence and inputs

Monthly to start, covering the previous 30 days plus the open acceptance
checks from earlier runs. Adjust once two runs show whether the volume
justifies more or less.

Each run takes one snapshot and records it:

- A copy-on-write clone of the AgentsView store (`cp -c
  ~/.agentsview/sessions.db`), never the live file, with its max message
  timestamp and session count.
- The session archive at a recorded `origin/main` revision, for hosts and
  transcripts AgentsView does not index.
- Per-host coverage ends, so silence after a host's last record reads as
  missing data, not as a fix.

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

Each shape is classified as a real failure, an exploratory probe, quoted
content, a test of code under development, or a tool error, and the
classifier is checked against a blind-labeled sample before counts are
trusted.

## Output

A private report under `~/.local/state/session-review/<date>/` with:

- A coverage table by harness and host.
- Shapes ranked by count and by root task, with sanitized exemplars.
- For each new recurring shape: a proposed fix, its owner, and an
  acceptance check.
- The status of every open acceptance check from earlier runs.

Findings that need repo changes become plan items or issues through the usual
workflow. Nothing from a run is published automatically.

## Tooling

Promote the extraction, classification and coverage scripts from the
2026-09-26 review into `scripts/audit/` once the first scheduled run confirms
they reproduce that review's counts. Carry its two corrections: Claude Code
reports `Exit code N` without a colon, and zsh errors from Claude arrive with
an `(eval):N:` prefix.

## Data completeness

AgentsView keeps no tool results for Cursor sessions (95,837 calls, zero
results in the 2026-09-26 window), so Cursor failures are invisible to any
review. Ask AgentsView upstream to retain tool results for every harness it
parses; filing that request needs Prateek's approval.

## Acceptance

- The first scheduled run produces a report from a fresh snapshot and
  reproduces the 2026-09-26 counts within its classifier's error.
- Every open acceptance check from the agent friction remediation plan has a
  recorded status in that report.
- No host's coverage in a run is more than 3 days stale, or the report says
  which host is and why.

## Open questions

- Whether a scheduled Orca automation or a manual monthly prompt runs it.
- Where the blind-labeling sample comes from on each run, and how large it
  needs to be to keep failure precision above 85%.
