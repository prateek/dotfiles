---
status: active
doc_type: plan
owner: Prateek
created: 2026-09-27
updated: 2026-09-27
related:
  - ../adr/0035-separate-experimental-jev-browser-skill.md
  - ../adr/0034-discover-jev-controls-in-the-browser-skill.md
  - ../adr/0033-skill-owned-jev-browser-runner.md
  - ../research/jev-browser-integrations.md
status_detail: "Dynamic setup and a small synthetic Cloudflare trial are complete; paired end-to-end performance and broader reliability remain unmeasured."
---

# Remove parent-authored Jev browser manifests

The [previous experiment](jev-browser-runner-plan.md) found that parent job
construction cost more than Jev saved during short browser tasks. Keep that
result frozen. This follow-up tests whether deterministic setup in the
experimental `browser-jev` skill changes the full-task outcome. The dynamic
decision is [ADR 0034](../adr/0034-discover-jev-controls-in-the-browser-skill.md);
[ADR 0035](../adr/0035-separate-experimental-jev-browser-skill.md) keeps it
separate from the regular `browser` skill.

## Contract and implementation

The `browser-jev` skill owns the runner, launcher, and Jev reference. It links
to the regular `browser` skill for policy, driver routing, and resource
ownership. The regular skill's source stays unchanged.

- Accept a small v1 job with `scope.discover: true`: goal, borrowed browser
  identity, exact origin, foreground permission, ordinary input values, and
  optional independent checks. Default the fixed Cloudflare provider and
  bounded action/decision/time budgets. Keep explicit jobs valid as before.
- At every fresh observation, find supported visible controls and generate
  unique CSS selectors and stable node tokens. Bind a supplied value by exact
  `id`/`name`, then exact label/placeholder. Ambiguous bindings hand back.
  Execute bound strings and `true` checkbox values deterministically. Open a
  single Filters disclosure to reveal a missing requested checkbox. Never
  synthesize text or treat page prose as authorization.
- Derive a verifiable value, checked state, or same-origin URL after an action.
  A Filters or page button may use a weaker observed-change receipt. Recheck
  the target immediately before dispatch; never replay a mutation whose reply
  may have been lost.
- Preserve independent final checks when available. Without checks, return
  `verification_required` rather than `verified`. Preserve the existing browser
  router, focus rules, task-owned session, and cleanup contract.

## Qualification and iteration

1. Test the normalized observer and runner with evolving DOM, ambiguous
   fields, unsafe and external controls, stale targets, unsupported widgets,
   focus changes, uncertain effects, and empty final checks. Run the offline
   Node suite and marketplace export checks.
2. Drive the dynamic job through a real isolated agent-browser on the
   independent synthetic fixture. Verify the fixture oracle and forbidden
   effect ledger separately from the runner receipt. Repeat on isolated
   headless Orca before claiming Orca runtime qualification. Desktop focus is
   outside this lane.
3. Run live Cloudflare Jev trials using the new job shape. Record confidence
   distributions, choices, handoffs, token use, setup time, stage timings,
   browser-command count, and independent final outcome. Calibrate the
   confidence policy on development data; do not change the threshold merely
   to increase completion counts.
4. Freeze a new matched development comparison against the ordinary parent
   browser loop. Count browser/session setup, parent preparation, Jev inference,
   verification, and fallback in end-to-end time. Require at least the parent
   completion rate, zero false successes and forbidden effects, and a material
   end-to-end speed gain before a separate holdout. Report failures by cause.
5. If those gates pass, run a withheld task set on both drivers and make a
   separate default-adoption decision. Otherwise keep this mode opt-in and
   retain the failed candidate's receipts intact.

## Current evidence

The new mode passes an isolated real agent-browser search with dynamically
revealed filters, a synthetic prompt-injection/deletion control, and an
independent fixture oracle; no forbidden effect occurred. Supplying both the
query and `published: true` completed that search with zero Jev calls. With
only the query supplied, two real Cloudflare Jev trials completed at floors
0.85 and 0.60: each used one deterministic fill, then two Jev decisions for
Filters and Published with confidence 1. Both passed the fixture oracle with
zero forbidden effects. Earlier trials before deterministic field execution
handed back at confidence 0.52–0.54 before any action. These small development
trials do not establish reliability or full-task speed. The matched comparison
and new Orca headless trial remain open.
