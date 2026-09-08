---
status: active
doc_type: plan
owner: Prateek
created: 2026-09-08
updated: 2026-09-08
related:
  - ../adr/0028-router-skill-over-vendor-remap.md
  - ../adr/0016-vendor-into-skill-references.md
  - ./acpx-claude-streaming-poc-plan.md
  - ../research/acpx-rewrite-model-bakeoff.md
status_detail: "Skill, vendored rename, and docs closure landed together; trigger arbitration measured 2026-09-08 (15/18, no cross-listing steals). Open: two eval labels to settle."
---

# acpx Skill Packaging Plan

Move the acpx conventions out of the machine `AGENTS.md` pointer list and into
a skill that owns its own trigger, sitting next to the vendored upstream skill
rather than swallowing it. The shape and its rejected alternatives are in
[ADR 0028](../adr/0028-router-skill-over-vendor-remap.md).

## Problem

One subject, two always-loaded pointers, no path between them. The vendored
`openclaw/acpx` skill owned the trigger and knew no local conventions. The
conventions sat in `~/.agents/docs/acpx.md` behind `AGENTS.md` line 42, which
only helps an agent that reads the pointer list first. Invoking the skill got
the command surface; the shortcut table, the safety posture, and the
watch-a-run lanes stayed unread.

Separately, the conventions doc had gone stale in a way a doc cannot catch:
it told agents the canonical launch fails closed on permissions.

## Work

1. **Author `packages/utils-agent/skills/acpx/`.** `SKILL.md` is the
   conventions, rewritten for a skill: no "this doc" self-reference, an
   `argument-hint`, and a description that claims the delegation branch
   explicitly (shortcut names, second-opinion intent, run-it-elsewhere).
   `references/harness-lanes.md` is the moved sibling doc with its links
   rewritten. `agents/openai.yaml` carries the Codex interface block.

2. **Fix the permission claim before writing it down.** Probe the live
   adapters rather than restating the doc.

3. **Rename the vendored skill to `acpx-cli`.** `publish.toml` supplies the
   directory name; a one-line hunk in `patches/001-local.patch` changes
   `name: acpx` to `name: acpx-cli`. Mandatory — `scripts/marketplace.py:219`
   rejects duplicate frontmatter names in a package. Upstream's description
   stays verbatim; see [Description narrowing, deferred](#description-narrowing-deferred).

4. **Retire the old surface.** Delete the `AGENTS.md` pointer line and
   `home/dot_agents/docs/acpx.md`; repoint the two mise config comments and the
   bakeoff research doc's `related` entry. chezmoi does not delete a deployed
   target when its source goes, so both retired docs are listed in
   `home/.chezmoiremove` and leave every machine on its next apply.

   Deleting the doc exposed a validator contradiction. The archived
   crit-agent-bridge plan links to it, archived bodies are locked, and the
   validator checked inline links in every doc regardless of status — so the
   file could not be deleted and the link could not be repaired. The lifecycle
   policy already said archived bodies "may be stale"; the validator now agrees
   (`validate-doc-lifecycle.py` skips inline-link checks for closed docs —
   archived, superseded, rejected — the way it already skipped the stale-path
   check for locked bodies), with a test for both sides. Accepted ADRs stay
   checked: their bodies are locked, but they are live direction, and the
   escape when a linked file must go is to close the ADR first.

5. **Close the docs.** ADR 0028 for the pattern, ADR 0016 superseded by it, the
   streaming PoC plan archived onto the skill reference that now carries its
   output, and `docs/index.md` updated. The PoC plan closes metadata-only,
   because the validator blocks body edits in the change that closes a doc.

6. **Bump the plugin version** so installed Claude and Codex caches take the
   change on their normal update path.

## Interface

Two flags and a passthrough. Everything acpx already names keeps acpx's name:

| Argument | Meaning |
| --- | --- |
| `-m`, `--model <shortcut>` | Shortcut that runs the task |
| `-w`, `--write` | The delegate may change files; absent means read-only |
| `-- <acpx flags>` | Verbatim to acpx |

The earlier draft had seven flags. Five of them — `--mode`, `--watch`,
`--format`, `--timeout`, `--session` — were renames of acpx's own flags, a
second vocabulary to learn and a cache of upstream's interface that would rot
the first time acpx changed. The passthrough replaced all five.

## Description narrowing, deferred

A wider patch was drafted: it rewrote upstream's description to the command
surface and added "use `acpx` instead to delegate" as an explicit cross-link.
Cut before landing.

Upstream's description is already mostly command surface. The overlap with the
router's branch is one clause, "agent-to-agent communication". Against that:
the rewrite ran 365 characters to upstream's 257, and an over-budget skill
listing drops descriptions silently, so the cost lands on the exact mechanism
the change is trying to protect. Nothing had measured whether the two listings
compete.

So upstream's wording is the baseline the trigger evals run against, and the
run settled it: the vendored skill took all 12 command-surface runs and the
router all 21 delegation runs. Narrowing stays the response to a measured
failure, and there is none. The rename is
safe alone: the vendored skill is a single `SKILL.md` — no `references/`, no
scripts — its one self-reference is the name-independent "this skill", and
every other `acpx` in the body is the CLI's name, not the skill's.

## Permission finding

Probed on acpx 0.15.0 with cursor-agent 2026.07.01 and claude-agent-acp 0.75.1:
neither adapter sends `session/request_permission`. Both wrote a file and ran a
shell command under `--non-interactive-permissions deny`, and again under
`--deny-all`. `--no-terminal` is inert; neither calls ACP `terminal/create`.
cursor-agent's shell gating is a regression from the 2026-09-03 probe at acpx
0.13.2, where a shell request was rejected with `reject-once`.

So `-w` cannot be an enforcement gate. Without it the skill writes the
read-only constraint into the prompt and audits the log's tool calls
afterwards. A disposable git worktree under `--cwd` narrows the blast radius
and adds a second audit surface, but it is not containment: `--cwd` only sets
the working directory, and an ungated adapter writes anywhere by absolute path.
Nothing in acpx bounds these adapters. The launch keeps
`--non-interactive-permissions deny` as cheap insurance for adapters that do
ask.

## Validation

- `just check` in `agent-marketplace/` (37 tests, passing).
- The built tree carries `skills/acpx/` and `skills/acpx-cli/` with distinct
  names, and `acpx-cli`'s body is upstream's byte for byte below the frontmatter
  (the reconstructed pre-image hashes to the blob the patch names).
- `just test-docs-lifecycle`, and `git diff --check`.
- `evals/run_trigger_evals.sh` — 18 trigger queries through skill-creator's
  runner, serial, against the installed listing. 15/18 on 2026-09-08 with
  `claude-fable-5-1`; the router took all 21 delegation runs and the vendored
  skill all 12 command-surface runs. `evals/evals.json` is the separate
  behavior lane, graded by hand. Both are documented in `evals/README.md`.

## Open

- Arbitration is measured: neither listing took the other's queries in 33
  runs, so the description narrowing stays deferred. Two eval labels remain to
  settle. "Ask the opus model … then update the migration" triggered 3/3 and
  the model's reading is coherent, so it is probably a should-trigger case
  mislabeled as a near miss. "Farm the migration audit out to another agent"
  went to the built-in Agent tool 3/3; the router's run-it-elsewhere clause
  does not beat a subagent when the motive is context budget, and widening it
  to compete would be the wrong fix. Disabling model invocation on the sibling
  stays off the table.
- The fixture's `CLAUDE.md` retires the old `~/.agents/docs/acpx.md` pointer
  for the duration of a run. Remove that line from `setup_fixture.sh` once
  every machine has applied the change that deletes the pointer.
- The description budget moves with the rest of the installed listing. A
  regression here looks like a triggering failure, so check the budget before
  blaming the wording.
