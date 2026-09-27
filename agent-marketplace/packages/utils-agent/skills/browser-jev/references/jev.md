# Jev trials

Jev is an opt-in decision loop for bounded browser tasks. The regular browser
skill selects the browser, page, and identity. This experimental skill sets
the origin and operation policy; Jev selects from the resulting choices. The
runner is a Node.js CLI with the same
stdin/stdout contract from Claude, Codex, Pi, or another parent with shell
access.

Use this lane for reversible search, filtering, and synthetic fixture work
when the parent explicitly selects a Jev trial. Keep consequential writes,
credential entry, login, CAPTCHA, unsupported widgets, and visual judgment in
the parent workflow. Evaluation has not established a speed or reliability
advantage over the existing browser loop; the frozen explicit-manifest
comparison below failed the adoption gate. The newer dynamic setup has no
paired result yet. Retain the existing loop as the default.

## Dynamic preparation

Use `scope.discover: true` to move repeated control setup into skill code.
The parent still chooses an owned page, exact origins, ordinary values, and a
goal. It may supply independent final checks when the requested outcome has a
known machine-readable predicate. Provider, action/decision/time budgets,
empty controls, and empty inputs/checks default in this mode. For example:

```json
{
  "version": 1,
  "goal": "Show only published entries matching orchard",
  "browser": {
    "driver": "agent-browser",
    "session": "jev-trial",
    "pageId": "targetId_from_tab_inventory",
    "config": "/absolute/task/agent-browser-empty.json"
  },
  "scope": {
    "origins": ["http://127.0.0.1:43210"],
    "foregroundInput": false,
    "discover": true
  },
  "inputs": { "query": "orchard", "published": true },
  "checks": [
    { "selector": "#query", "property": "value", "equals": "orchard" },
    { "selector": "#published", "property": "checked", "equals": true },
    { "selector": "#result-ids", "property": "text", "equals": "orchard-alpha,orchard-beta" }
  ]
}
```

The observer discovers currently visible, enabled same-origin links, ordinary
text fields, checkboxes/radios, native selects, Filters disclosures, and
Next/Previous page buttons. It repeats discovery after each action, so opening
Filters can reveal the next checkbox. It excludes unknown and form-submit
buttons, sensitive fields, downloads, and new-tab links. These are mechanical
filters, not proof that a site's link or script is harmless: use dynamic mode
only for authorized low-impact work. For other effects, use the explicit
control contract below. If the page has more than 240 candidate controls,
discovery returns `discovery_limit` before inspecting them; continue through
the regular browser skill or a narrower explicit-control job.

Supplied strings bind to text/select fields, and `true` binds to a checkbox or
radio option. Binding uses exact normalized `id` or `name`, then exact label or
placeholder. Ambiguous fields hand back; absent values are never invented.
Bound fields execute deterministically after fresh target revalidation. If a
requested `true` checkbox is not visible and exactly one Filters disclosure is
available, the runner opens it deterministically and discovers again. Jev is
called only when these rules cannot select the next action. `false` does not
mean uncheck in this version; it is rejected.
Immediate value, checked, and URL effects are verified. For Filters and page
buttons the runner records only `observed_change`, which does not prove the
task outcome. If final checks are omitted, model `DONE` produces a handoff
with `verification_required`; the parent verifies the real result on the same
page. Result decisions mark `source: "deterministic"` or `source: "jev"`;
`counters.decisions` counts Jev calls only. The default 0.85 confidence floor
remains. In a two-run synthetic
Cloudflare trial, the query-only job used one deterministic fill, then Jev
selected Filters and the revealed checkbox at confidence 1; both runs verified
by the fixture oracle with zero forbidden effects. A job with both `query` and
`published: true` completed that fixture with zero Jev calls. These small
trials do not establish reliability or a full-task speed advantage.

## Prepare an explicit-control job

1. Follow the selected driver and
   [shared policy](../../browser/references/policy.md). Inspect an owned page
   and confirm its exact origin. For Orca, resolve the worktree from the
   task's actual path and confirm that the page belongs to it; an inherited
   `ORCA_WORKTREE_ID` may name a different worktree.
2. Identify unique selectors for the task's low-impact controls. Supply the
   permitted operations and ordinary input values. All selectors must be
   standard CSS accepted by `document.querySelectorAll`; browser-tool syntax
   such as `text=`, `role=`, and `@ref` is unsupported. Each click needs an
   observable postcondition. Provide independent final checks that distinguish the
   requested outcome from plausible wrong results.
3. Choose the applicable [Orca runtime](#orca-runtime-and-focus), or an isolated
   headless agent-browser session. A qualified headless runtime can use
   `scope.foregroundInput: false`. Desktop Orca requires an existing
   [focus agreement](../../browser/references/policy.md#focus), `scope.foregroundInput: true`, and a
   fresh focused-page check before every mutation. Browser or API authorization
   alone does not grant focus permission.
4. Supply `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` through the launcher
   environment. Read the credential into process memory through the approved
   secret reader; keep it out of job files, shell arguments, logs, and output.
   The portable runner consumes those variables and removes them from browser
   child environments. Credential provisioning belongs to the caller.

This example describes synthetic controls; substitute inspected page identity,
origin, selectors, and expected values before running it:

```json
{
  "version": 1,
  "goal": "Show published entries matching orchard",
  "browser": {
    "driver": "orca",
    "worktree": "path:/absolute/task/worktree",
    "pageId": "page_from_orca"
  },
  "provider": { "kind": "cloudflare", "model": "typesafe/jev" },
  "limits": { "actions": 8, "decisions": 12, "elapsedMs": 60000 },
  "scope": {
    "origins": ["http://127.0.0.1:43210"],
    "foregroundInput": true,
    "controls": [
      {
        "selector": "#filters",
        "operations": ["CLICK"],
        "expect": { "selector": "#filter-panel", "property": "visible", "equals": true }
      },
      { "selector": "#published", "operations": ["CHECK"] },
      { "selector": "#query", "operations": ["FILL"], "inputId": "query" }
    ]
  },
  "inputs": { "query": "orchard" },
  "checks": [
    { "selector": "#published", "property": "checked", "equals": true },
    { "selector": "#query", "property": "value", "equals": "orchard" },
    { "selector": "#result-ids", "property": "text", "equals": "orchard-alpha,orchard-beta" }
  ]
}
```

Required limits are 1–60 actions, 1–120 decisions, and 50–300,000 milliseconds.
`confidenceFloor` defaults to 0.85 and accepts values from 0 through 1 at the
job's top level. Lower it only for recorded development calibration. Both the
operation and its selected target must meet the floor; changing the floor
does not expand the authorized controls or bypass independent verification.
The job supports up to eight exact HTTP(S) origins, 40 explicit scoped controls,
and 40 final checks. Explicit-control jobs must have at least one final check.

## Orca runtime and focus

Use the same Orca browser fields for a desktop or isolated container runtime.
The caller can select its existing Orca CLI executable with `ORCA_CLI_COMMAND`
(a command name or executable path, not a shell expression).
The adapter reads public `orca status --json` through the executable that
will issue the page commands. It requires a reachable runtime in `ready` state
with a nonempty `runtimeId`. Background operation is available only when
that status also reports all three:

- `app.desktopWindowStatus: "openable"`;
- `graph.state: "ready"`;
- `runtime.capabilities` includes `browser.headless.v1`.

The adapter computes `requiresForeground: false` from that evidence. A job
field, page content, or model response cannot grant this mode. For such an
isolated headless Orca runtime, set `scope.foregroundInput: false`. The adapter
pins the runtime ID and headless/desktop mode alongside worktree and profile
identity; a change returns a handoff instead of switching runtimes.

Desktop Orca input may activate its window. Set `scope.foregroundInput: true`
only after the user grants the named foreground handoff, then keep that
window and page focused throughout the job. A fresh `document.hasFocus()`
check must pass before each desktop mutation; otherwise the runner returns
`window_not_focused`. The runner never activates a window or switches a tab
to satisfy the check. A desktop focus failure does not block qualification of
an independently selected, isolated headless Orca runtime.

## Operations and predicates

| Scoped operation | Required task data and settling |
| --- | --- |
| `CLICK` | An `expect` predicate, or an observed link with an allowed destination; verify that condition after clicking. Each scoped control can be clicked once per job. |
| `CHECK` | A checkbox or radio button; verify its checked state becomes true. |
| `FILL` | An ordinary input or textarea and `inputId`; verify the supplied value. |
| `SELECT` | A native select and `inputId` naming an enabled option value; verify its selected value. |
| `SCROLL` | Viewport only: `selector: "html"` or `"body"`, `direction: "up"` or `"down"`, and `amount` from 1–1200. Verify a position change or hand back at the boundary. |

Predicates use `property: "url"`, `"visible"`, `"text"`, `"value"`, or
`"checked"` and an exact `equals` value. `visible` and `checked` take booleans;
the rest take strings. All except `url` require a `selector`. An absent element
satisfies a `visible` check with `equals: false`; other element checks require
one match. Text comparison normalizes whitespace. Optional `scope.pending` supplies a predicate
for the model's `WAIT` choice. `DONE` requests final verification; `HANDOFF`
returns control to the parent. Those three choices are not scoped operations.

## Agent-browser session

For an isolated agent-browser session, replace `browser` with:

```json
{
  "driver": "agent-browser",
  "session": "jev-trial",
  "pageId": "targetId_from_tab_inventory",
  "config": "/absolute/task/agent-browser-empty.json"
}
```

Create the configuration file with exactly `{}` and use that explicit config
for the dedicated session. Choose its page from the session's tab inventory;
`pageId` is the stable target ID, not the current tab index. It must already be
the session's active pinned target; the runner does not switch tabs. Use
`scope.foregroundInput: false` for a qualified headless session. The runner
borrows this page and leaves session creation and cleanup to the parent.

## Run and inspect

Set `BROWSER_JEV_SKILL_DIR` to the directory containing this skill's `SKILL.md`.
With credentials already present in the launcher's environment:

```sh
"$BROWSER_JEV_SKILL_DIR/scripts/run-jev" < job.json
```

The runner reads one JSON job and prints one JSON result. Its Cloudflare host
and `typesafe/jev` model are fixed; redirects and provider URL overrides are
unsupported. Page state is sent to Cloudflare only inside the job's permitted
origin. Start with synthetic or public content; transmitting private page
content requires that scope from the user.

Jev answers an `operation` choice and a separate `<OPERATION>_target` choice
for each available operation, such as `CLICK_target`. Each target choice is
an ID bound to a current operation/control pair, such as `c0_CLICK`. The runner
uses the chosen operation's target, revalidates that control, and binds any
value through the scope's `inputId`; the model cannot substitute a different
field value. Model output cannot supply selectors, shell commands, page
JavaScript, or new text. Selector
revalidation precedes driver commands, but validation and dispatch are
separate: a page can replace a matching element between them. Restrict these
trials to the low-impact controls described above.

| Result | Exit | Parent action |
| --- | --- | --- |
| `verified` | 0 | Read the independent check evidence and report the confirmed state. |
| `handoff` | 2 | Inspect the reason and action receipts, then continue on the same page through the normal browser skill. |
| `failed` | 1 | Resolve the invalid job or launcher failure before attempting another job. |

A model `DONE` only requests independent checks. Failed or missing checks do
not establish success. Dynamic jobs without checks return
`verification_required`. A timed-out or lost mutation response has an unknown
effect; inspect the page and reconcile it before another attempt. The runner
does not automatically resume across processes. If it exits without a final
JSON result, treat any possible dispatched effect as unknown. Preserve the
borrowed page on every outcome and apply the parent skill's resource cleanup.

`reclaim_gate_busy` means another process may be clearing a dead browser lock,
or a process died while doing so. Keep the browser handoff fail-closed. If the
reason persists after all `run-jev` processes on that host have exited, locate
the empty gate at `os.tmpdir()/browser-jev-<uid>/<hash>.reclaim`, where `<hash>`
is SHA-256 of `JSON.stringify([driver, resource])` and `resource` is the Orca
page ID or agent-browser session. Remove only that gate with `rmdir`, then retry;
the runner will recheck the main lock owner. Do not remove the main lock folder.

## Qualification and iteration

The implementation remains experimental. The qualification snapshot from
September 27, 2026 records 130 passing offline cases and these independently
verified real Cloudflare trials using the split question format:

| Runtime | Confidence floor | Recorded result |
| --- | --- | --- |
| Standalone agent-browser | 0.85 default | Navigation and pagination verified. In the recorded form attempt, confidence 0.82 caused handoff before the final click. |
| Standalone agent-browser | 0.6 development | 20/20 verified: five each for navigation, search/filter, pagination, and the synthetic form; zero forbidden effects. |
| Isolated container Orca 1.4.214 | 0.85 default | 3/4 verified: navigation, pagination, and form; search returned a low-confidence handoff. Zero forbidden effects. |
| Isolated container Orca 1.4.214 | 0.6 development | 4/4 verified, one per family; zero forbidden effects. |

Both Orca batches used `scope.foregroundInput: false` and the runtime-qualified
headless path. These are finite development results; confidence varies between
attempts. The calibrated batches do not qualify the default floor or establish
a matched speed or reliability advantage.

A frozen 20-pair comparison used standalone agent-browser 0.38.1, fresh Codex
sessions with `gpt-6-astra` at high reasoning effort, and a Jev floor of 0.6.
The parent loop completed 20/20 tasks autonomously; the Jev path completed
13/20. Scored end-to-end medians, including fallback, were 33.96 seconds for the
parent and 50.26 seconds for Jev. Both arms recorded zero false successes and
forbidden effects. This candidate failed both the completion and speed gates;
retain it only for explicit experiments. A holdout was not warranted by this
development result.

Another 16 scenarios exercised the real container Orca driver with scripted
decisions. They covered the four task families, delayed results, duplicate
targets, DOM replacement, redirects, unauthorized choices, login, CAPTCHA,
unsupported widgets, duplicate submission, lost mutation replies, and viewport
scrolling. Invalid or stale targets handed back; the lost-reply case preserved
an uncertain effect and dispatched its synthetic submission once, without
replay. Ledger-backed cases recorded zero forbidden effects. These scenarios
qualify driver behavior, not Jev's decision quality.

The task's container, image tag, downloaded app image, tabs, and profiles were
removed after qualification; desktop Orca was untouched by that cleanup.

The dynamic follow-up has separate qualification and adoption gates. Its
real-browser proof and two synthetic Cloudflare trials do not replace this
frozen paired comparison.

Fresh Codex and Claude sessions passed portable CLI invocation checks. Those
checks exercised invalid-job handling without browser or provider calls.
Pi's invocation check stopped at its installed provider's OAuth refresh HTTP
401; authentication was left unchanged. The first desktop Orca live attempt returned
`window_not_focused` with zero actions while another app was foreground. The
user then brought Orca forward, but its embedded page still reported no
document focus. Desktop action qualification remains open. The isolated
container result above is separate evidence; it does not qualify the desktop
runtime's focus behavior.

Qualify the exact browser/runtime combination on disposable fixtures before
expanding a trial. Confirm focus behavior, page ownership, simple completion,
false `DONE`, changed targets, delayed state, and an interrupted mutation.
Use the fixture's independent event ledger to distinguish UI state from
actual writes; offline provider/process checks alone do not prove live browser
behavior.

Compare Jev with the parent-driven loop on reset copies of the same tasks,
including preparation, independent checks, and cleanup in both timings.
Record failed attempts and handoffs alongside verified completions. Change
one cause of failure or delay at a time, preserve the counterexample, and
evaluate a fresh holdout before broadening use. Revert by returning to the
existing loop on the same page; no browser identity migration is needed.
