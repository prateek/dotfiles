---
name: land-changes
description: Land requested changes, inspect available landing workflows, or manage repository landing preferences. Use for "land it", "ship this branch", or "push to main".
argument-hint: "[--inspect] [--via=<method>] [--skip=<action>] [--bypass=<gate>] [--after=<action>] [defaults controls]"
---

# Land changes

Land the requested change using the destination's workflow and the user's choices.
Inspecting, discussing, or editing this skill authorizes no landing.

## 1. Establish the request and current state

Resolve the change, source checkout, destination repository, target, and requested
stopping point from the conversation. For publication, verify publishing identity and effective
remote destinations; source and destination may differ.

Account for the diff, uncommitted edits, dependencies, PR/stack metadata, and any
already-completed work. Preserve unrelated changes; isolate preparation when it
would disturb them. Default to one integration commit where the method supports it.

Read [choices and preferences](references/preferences.md) to resolve invocation
arguments and scoped saved choices. Show/reset requests finish after preference
handling. Inspection makes no checkout, check-run, preference, or publication changes.

Complete when the intended scope and remaining authorized outcomes are recorded.
An earlier completed action does not become a request for a new change.

## 2. Discover the workflow

A method publishes; an action does work; a gate requires evidence before proceeding.
Use these distinctions internally. The user can name an outcome without classifying it.

Account for these evidence sources, following the destination's workflow pointers:

- Contribution/agent guidance and the repository's landing procedure.
- Applicable task definitions, validation selection, and effective Git/tool hooks.
- Live host policy, caller capabilities, and existing PR/queue/stack state.
- Automation triggered by the selected publication, including follow-on workflows,
  release/deployment jobs, environments, and available external integration metadata.

For GitHub, read [host evidence](references/github-review-evidence.md). For an
unfamiliar mechanism, read native help and official documentation. When guidance
leaves a convention unsettled, read [review history](references/review-history.md).
History informs recommendations; it grants no exception or follow-up permission.

Use source-owned names, qualified where needed. For each relevant choice, identify
its mechanism, dependencies, controls, affected scope, and completion evidence.
Account for each evidence source as inspected, inapplicable, or unavailable; keep
material unknowns and conflicts visible. Live capability evidence cannot grant
user authorization, and user authorization cannot make a capability available.

For landing, inspect the selected route and resolve dependencies; avoid cataloguing
unrelated routes. For --inspect, show configured choices, alternatives requiring
setup, and unknowns, each with its source and controls; recommend a route and stop.
Discovery is complete when those sources are accounted for and every requested
outcome has a procedure or an identified blocker.

## 3. Resolve the plan

Apply explicit choices, applicable standing decisions, and valid saved preferences
before defaults. Use the selectors in [choices and preferences](references/preferences.md)
or equivalent natural language. Resolve contradictions by scope and recency.

Absent an overriding choice:

- Follow the established route that satisfies policy without a bypass; resolve a
  material route ambiguity before publication.
- Run relevant repository validation and hooks. Their failures block by default;
  preserve checks explicitly designated informational. Wait for required evidence,
  not unrelated or informational CI.
- Run no manual follow-up without an explicit instruction or saved preference
  whose scope covers this change, host/environment, and effect.

Record each selected action and gate, its run/skip or enforce/bypass decision,
waiting behavior, and source. For every bypass and follow-up, cite the instruction
or saved key authorizing its scope. Include automatic publication effects: when
an effect lacks covering authorization or conflicts with a user constraint, find
an authorized route avoiding it or resolve that decision before publishing.
A no-deployment constraint requires evidence that the selected route avoids the
deployment before publication; publishing and watching for a deploy is no proof.

Skipping execution retains known results; it never turns a failure into a pass.
Enforce applicable gates unless a scoped exception covers them and the actor has
a usable bypass. Report informational failures separately. Shared protection edits,
new privileges, and overwriting history require their own explicit scope.

Reuse covering decisions and resume unfinished authorized actions without asking
again. A completed change-specific apply does not authorize another change's apply.
The resolved plan, including follow-up scope and source, governs execution; revise
it explicitly when new evidence changes a choice instead of inferring it again.

Complete when choices are resolved or marked blocking. Continue independent
preparation while resolving blockers; publication requires the blockers resolved.

## 4. Prepare and publish

For a direct update, follow [direct Git landing](references/direct-git.md).
For a PR, queue, stack, or another method, follow its repository/native procedure.
Preserve attribution and PR/stack relationships. Run selected actions on the final
candidate and record results. Complete independent preparation before requesting
any unresolved publication decision.

Before publication, verify scope, destination, live policy, and the candidate.
Every applicable gate must have valid evidence or a usable authorized exception;
every resulting effect must fit the resolved plan. A target or candidate change
requires refreshing affected evidence and choices, retaining decisions still in scope.
Inspect remote state after an uncertain response before retrying publication.

Complete publication only when the live destination contains the intended change.
For direct pushes, verify the prepared commit or its ancestry. For server-created
commits, verify source revision, integration commit, and intended diff from the
method's result metadata. PR/queue submission is intermediate unless requested
as the stopping point. Report a policy rejection as such and resolve a valid route.

## 5. Finish the remaining work

Safely synchronize local checkouts. For a selected follow-up, read its repository
runbook, then verify the authorization source, effect scope, and published revision
or artifact still match the plan. Execute only the remaining authorized actions.
Check actual activation when command success alone does not establish the result.
After an uncertain outcome, inspect state before repeating a side effect.

Report publication, local synchronization, validation, CI, and follow-up outcomes
separately as passed, failed, skipped, pending, or unknown. Name bypassed gates and
unrequested follow-ups. Keep branches and worktrees unless cleanup was requested.
Finish when each requested outcome is verified or its exact blocker is reported.
