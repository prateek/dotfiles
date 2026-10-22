---
status: accepted
doc_type: adr
summary: "A pi extension watches Claude Code Workflow runs by tailing the files Claude Code already writes: a phase-grouped agent list beside the selected agent's transcript, plus a --once JSON snapshot."
owner: Prateek
created: 2026-10-21
updated: 2026-10-22
related:
  - 0061-acpx-pi-viewer.md
  - 0064-pi-viewers-share-one-kit.md
current_guidance: ../../agent-marketplace/src/utils-agent/skills/workflow-viewer/SKILL.md
---

# ADR 0062: Watch Claude Code workflows in a pi viewer

The `workflow-viewer` skill in utils-agent opens a pi extension that shows one
Claude Code Workflow run: a list of its agents grouped by phase on the left,
the selected agent's transcript on the right, and zoom. The list has three
modes (a tree, a sortable table, a timeline of bars); pinned agents stack in
the detail pane; a stream of every agent's events opens as a tail. Every action
works by mouse alone or by keys alone. `--once` prints the same run as JSON for
agents and scripts.

The viewer only tails files. Claude Code appends each run's journal
(`subagents/workflows/wf_<id>/journal.jsonl`: started, result, failed) and each
agent's transcript as the run goes, saves the script (phase names) at launch,
and writes `workflows/wf_<id>.json` (queue times, retries, errors) only at
completion. So the live roster comes from the journal, and the completion
record refines it afterwards. No hooks or OpenTelemetry are needed, which keeps
it working on the work laptop, where managed policy disables hooks.

Claude Code's bundled `/workflows` view is a summary. A survey on 2026-10-21
found no terminal tool with a live, phase-aware roster beside a dense
transcript: claude-code-log and claudecodeui model workflows but are web apps,
tail-claude is a good terminal base without a roster, and claude-devtools never
sees workflow agents. pi hosts the view for the reasons in
[ADR 0061](0061-acpx-pi-viewer.md): its own transcript cannot be made dense,
and an overlay drawn with pi-tui gets terminal, mouse, theme, and packaging
for free.

States are judged rather than copied. An open tool call counts as activity
until its timeout, so a long build is not a stall. An agent the finished run
never recorded is `abandoned`, not stalled forever. Durations stop at an
agent's last event. The model sits in `workflow-model.ts` with no pi imports,
so Node tests cover these rules and the snapshot reuses them.

Four separate views (roster, table, timeline, stream) were prototyped first. An
adversarial review found the table and timeline duplicated the roster's job
and the stream was noise past about ten agents, so they became list modes and
a tail pane around one roster-plus-transcript layout.
