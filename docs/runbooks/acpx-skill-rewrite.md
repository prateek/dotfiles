---
status: active
doc_type: runbook
created: 2026-09-26
updated: 2026-09-27
related:
  - ../plans/acpx-skill-rewrite-plan.md
  - ../plans/acpx-native-skill-rewrite-plan.md
  - ../references/acpx-routing.md
  - ../../scripts/acpx/rewrite-skills.flow.mjs
status_detail: "Five-skill live pilot completed with peak concurrency two, one afablex review, and a validated unapplied patch; runtime overrides were required."
---

# Rewrite authored skills with acpx

The [flow](../../scripts/acpx/rewrite-skills.flow.mjs) rewrites every immediate
skill directory under `agent-marketplace/packages/*/skills/`. Imported selections
in `publish.toml` and overlays are outside this sweep. It snapshots the current
tracked and nonignored untracked source, including pending edits, and produces
patches relative to that snapshot. It leaves the source worktree and index alone.

For each skill, a native [child flow](../../scripts/acpx/rewrite-skill.flow.mjs)
runs three isolated ACP nodes:

1. **GPT-6 Sol, high:** rewrite the whole folder using writing-for-agents;
   save a draft patch and file coverage report.
2. **Opus 5.5, high:** independently review the draft and original files;
   report identified defects. A checkout change by this reviewer fails the job.
3. **GPT-6 Sol, high:** resolve every finding and save the final skill patch.

After every worker succeeds, one native **afablex** node reads all patches
and reports in an aggregate checkout, fixes remaining issues, and runs the
marketplace check. The controller increments each changed plugin version once,
repeats the marketplace check, checks patch application against the snapshot,
and writes `final.patch` with a `receipt.json`.

## Run when execution is wanted

From the repository root:

```sh
acpx --approve-all flow run scripts/acpx/rewrite-skills.flow.mjs \
  --input-json '{"concurrency":3,"agentTimeoutSeconds":1800}'
```

This command launches models and authorizes writes in their disposable checkouts.
The five-skill pilot required the runtime overrides described below. Check the
host's adapter runtime before launching the full inventory.

The default output is a private temporary directory named
`acpx-skill-rewrite-*`, reported by the prepare stage. To retain it at a known
location, supply an absolute `outputDir` outside the source checkout; it must not
already exist. `repo` can specify an absolute repository root when invoking the
flow elsewhere. Unknown input fields fail validation.

To run a subset, provide `skills` as a nonempty array of exact repository-relative
authored skill roots, such as
`["agent-marketplace/packages/core/skills/code-simplifier"]`. Duplicates and paths
outside the discovered authored inventory fail before model calls. Omitting
`skills` selects the whole inventory. The selected paths are recorded in the
manifest and bound both worker and aggregate-review scope.

`concurrency` defaults to 3, accepts 1–16, and bounds active agent invocations
across the per-skill pipelines. Each worker finishes rewrite → review → fix
serially. Other skills may occupy the remaining slots. Final review starts after
the pool has drained and uses exactly one invocation. Delegates are instructed
to perform their work themselves without spawning more agents.

`agentTimeoutSeconds` defaults to 1800 and accepts 1–21600 for the child ACP
nodes. The parent afablex node has a 30-minute timeout. Each child process has a
deadline of three agent timeouts plus 30 minutes for its deterministic actions.
There are no automatic model retries. Parent actions have finite ceilings:
prepare 10 minutes, workers 7 days, assemble 30 minutes, export 2 hours. Commands
run through acpx's managed `context.runShell`, which owns their deadlines and
cancellation. A failed skill does not discard other completed jobs; aggregation
requires all jobs to succeed.

## Models and permissions

The balanced cost configuration uses Sol for the two writing passes per skill,
with Opus and afablex for review. As checked on 2026-09-26, Sol's standard API
input/output rates are $2/$10 per million tokens, compared with Astra's $10/$50.
That is 80% lower per-token pricing for the writing stages at equal token use;
total cost depends on token usage and the review calls. These API rates do not
predict Codex subscription usage. Sources: [Sol](https://developers.openai.com/api/docs/models/gpt-6-sol)
and [Astra](https://developers.openai.com/api/docs/models/gpt-6-astra).

At prepare time an action reads `~/.agents/bin/acpx-routing show` for `agpt`,
`aopus`, and `afablex`. It preserves native route environment and credentials,
pins the Codex route to `gpt-6-sol` / `high`, and pins the Claude or Claude Vertex
route to `claude-opus-5-5` / `high`. The child profiles are saved as argv arrays
under `skill-writer` and `skill-opus` in each job's `.acpxrc.json`, outside its
editable checkout. The parent's native
`afablex` node uses the profile acpx resolved when the parent command started;
the action also checks that the host routing report recognizes that shortcut.

This is deliberate: the inspected aliases resolved to older GPT and Opus
generations when the flow was authored. Exact pins express the requested models;
they do not prove the host account can run them. A provider rejection fails the
job without substituting another model.

For another harness, provide `writerCommand` or `opusCommand` as an explicit
adapter **argv array**, including the exact model and effort flags that harness
supports. The action rejects unsupported default routes instead of guessing their
model IDs. Overrides are operator-owned: argv structure is checked, and executable
or model rejection fails the native ACP node. Their model semantics are not inferred.
Avoid project overrides of `afablex` if the host's routing report should select it.
Resolved child commands and their launch argv are saved with the run.

The 2026-09-27 pilot found two adapter/runtime mismatches on this host:

- `codex-acp`'s bundled Codex rejected `gpt-6-sol`. Adding
  `CODEX_PATH=/Users/prateek/.local/bin/codex` to the writer adapter's `env` argv,
  after any corresponding `-u` option, selected installed Codex 0.157.1. Its ACP
  model catalog advertised `gpt-6-sol` / `high`, and the writing passes ran it.
- `claude-agent-acp`'s bundled Claude Code 2.1.257 rejected Opus 5.5 and requested
  2.1.280 or newer. Adding
  `CLAUDE_CODE_EXECUTABLE=/Users/prateek/.local/bin/claude` selected installed
  Claude Code 2.1.283. The pilot supplied that environment entry in `opusCommand`
  and in a run-local `.acpxrc.json` for `afablex`, preserving its resolved
  `claude-fable-5-1` / `xhigh` selection.

These were explicit argv overrides for this pilot, not global tool updates or
changes to the flow defaults. Supply paths that exist on the invoking host;
installed CLI versions and bundled adapter versions can differ.

The parent and child flows require explicit `--approve-all`, including the reviewer, which needs
to write its separate report. The reviewer is prompted to leave the checkout
unchanged, and its resulting diff is compared byte-for-byte with the draft.
Other stages may edit only their assigned skill roots; scope checks reject
changes outside them, removed entrypoints, symlinks, history changes, and
generated Python bytecode. These are prompt and post-run checks, not an OS
sandbox. The agents still run as the invoking user.

## Artifacts and failure recovery

The [flow definitions](../../scripts/acpx/skill-rewrite-flows.mjs) own the steps.
Their [JavaScript actions](../../scripts/acpx/skill-rewrite.mjs) handle Git,
reports, patches, and a small bounded pool of native child-flow commands. The
[prompts](../../scripts/acpx/skill-rewrite-prompts/common.md) own
the rewrite and review instructions. The guidance comes from the snapshotted
writing-for-agents dependency, including `SKILL-MECHANICS.md`.

| Artifact | Contents |
| --- | --- |
| `manifest.json` | Source tree, private baseline commit, parent run ID, skill inventory, child model commands, and concurrency. |
| `runtime/` | Frozen child-flow modules for this sweep. |
| `jobs/<id>/` | Child profile configuration, input, launch argv, native-flow result and bundle path, completion reports, draft/final patches, and result. |
| `results.json` | Every successful job and every failure; successful entries include patch hashes and native child run IDs/paths. |
| `combined-before-review.patch` | All successful skill patches before the final review. |
| `aggregate/` | The single afablex review report; its prompt and conversation are in the parent acpx bundle. |
| `combined/` | Final working tree for inspection, including aggregate fixes and version increments. |
| `validation.log` | Controller-run marketplace validation. |
| `final.patch`, `receipt.json` | Validated combined diff and its hash, source identity, and artifact pointers. |

The flow exports no `final.patch` when any worker fails, a review is incomplete,
an issue remains unresolved, a scope check fails, or final validation fails.
Completed patches and logs remain available; failed worker checkouts are retained.
Successful worker checkouts are removed to bound disk use. The baseline and final
checkout remain for review; delete the run directory after retaining needed
artifacts. Private clones depend on that baseline, not the source repository.

Inspect the patch with `git apply --stat /absolute/run/final.patch` or a diff
viewer. Before a later, separately requested application, run `git apply --check`
against the destination: changes since the snapshot can make the patch stale.
No source-repository commit, application to the source, publication, or installation
is performed. The controller creates a private baseline commit for patch generation.

There is no built-in resume command. Every normal parent invocation creates a new
snapshot and run directory; an explicitly named existing output directory is
rejected. Preserve failed or interrupted runs for diagnosis. The pilot used
separate native recovery flows to reuse validated artifacts from the same
baseline: four saved drafts resumed at review, a capacity-rejected fifth writer
was retried, and completed patches were collected for final review. This manual
recovery is not a supported resume interface. Read saved native projections when
collecting results; a terminal log can mix stderr notices with JSON stdout.

## Native viewer

The parent graph shows `prepare → rewriteSkills → assemble → aggregateReview →
export`. `aggregateReview` is a native ACP node with its own conversation.

Each skill is a separate native run titled with its source path, showing
`setup → rewrite → saveDraft → review → checkReview → fix → saveFinal`.
The three agent nodes have native prompts, outputs, and ACP conversation traces.
The run title and `parentRunId` connect each child to its sweep; `results.json`
records its native bundle path. Bundles use acpx's normal `~/.acpx/flows/runs/`
location and appear in the viewer's Recent runs list. The list shows up to 24
recent runs; older children remain accessible by their run IDs at `/run/<id>`.

Bounded concurrency is the only custom scheduling code. acpx still lacks a native
parallel map or nested subflow UI: the viewer shows a parent plus individual
child runs, not an expanded parallel tree on one canvas. No Python runtime or
external `acpx exec` agent loop is used.

## Local verification without models

```sh
just test-python -p test_skill_rewrite.py
node --check scripts/acpx/rewrite-skills.flow.mjs
just check-docs-lifecycle
git diff --check
```

The Python test entrypoint runs the Node contract suite using temporary Git
repositories and substitutes the acpx runtime/model boundary and marketplace
validation. It covers native node placement, worker bounds and cancellation,
phase order, model pins, explicit skill selection, scope and reviewer-write rejection, source/index
preservation, patch replay, version increments, failed validation, and deadline
forwarding to acpx. A separate local smoke check exercised acpx 0.19.3 with two
fixture skills and a mock ACP adapter: six child ACP traces and one parent ACP
trace were captured, with no real provider calls. These fixture checks establish workflow
and transport behavior, not model output quality or provider access. A native
`runShell` deadline check also confirmed that acpx terminates and reaps a timed-out
fixture process.

## Five-skill live pilot

On 2026-09-27, the first five authored skill roots alphabetically completed the
balanced model pipeline: `ask-questions-if-underspecified`, `code-gardening`,
`code-simplifier`, `conventions-maintainer`, and `decomment`, all in `core`.
The runtime overrides and manual recovery described above were required; this
was not an uninterrupted run of the default command.

All 32 per-skill review findings received evidenced fixes. One `afablex`
invocation reviewed the combined result and made nine aggregate fixes, leaving
no reported unresolved issues. Native ACP step intervals across the attempts
and recoveries showed a peak of two concurrent invocations.

The final export passed all 50 marketplace tests, built both marketplace
catalogues, and passed patch application checks against both its baseline and
the source checkout. It contains 16 changed files, including one `core` version
increment from `1.2.1` to `1.2.2`. The source skill files, their inventory and
modes, the source plugin manifest, and the source Git index remained unchanged.
The patch has not been applied or published.

The final native run is
`2026-09-27T051102112Z-finalize-reviewed-skills-f51851aa`. Its local artifacts are
under
`~/.local/state/acpx-skill-rewrite/pilot-2026-09-27T034826941Z-standalone-review-recovery-final/`:
`final.patch`, `receipt.json`, `pilot-audit.json`, `pilot-history.json`, the
per-skill reports, and `aggregate/aggregate.report.json`. Keep predecessor
baselines while inspecting the combined checkout: recovery clones share their
object stores. The exported patch is standalone.

This verifies the five selected skills and the live provider path with those
overrides. The full inventory and model-based behavioral evals were not run.
