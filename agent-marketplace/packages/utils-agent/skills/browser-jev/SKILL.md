---
name: browser-jev
description: Run an explicitly requested Jev browser experiment on an owned Orca page or isolated agent-browser session. Use the regular browser skill for other browser work.
---

# Experimental Jev browser

Use this skill only when the user explicitly requests a Jev browser experiment.
The regular [browser skill](../browser/SKILL.md) remains the default and owns
harness, driver, identity, authorization, focus, and cleanup policy. Jev adds a
bounded decision loop for an owned page in Orca or an isolated agent-browser
session; it does not select or create the browser identity.

## Run a trial

1. Read the regular browser skill and its
   [policy](../browser/references/policy.md). Follow their rules for the chosen
   harness and driver. Use Jev only with Orca or standalone agent-browser; if
   the regular skill selects another driver, continue with that skill instead.
2. Read the [Jev trial reference](references/jev.md). It defines job fields,
   runtime and focus requirements, handoffs, and qualification limits. Choose
   dynamic discovery for authorized, reversible work with ordinary controls.
   Choose explicit controls when the action list must be narrower. Keep
   consequential writes, credential entry, login, CAPTCHA, unsupported widgets,
   and visual judgment in the parent browser workflow.
3. Give the runner an owned page, exact allowed origins, a bounded goal, and
   caller-authorized ordinary values. Supply independent final checks whenever
   the outcome has a machine-readable predicate. For desktop Orca, also meet
   the reference's foreground agreement and focus checks; isolated headless
   sessions use their qualified background mode.
4. Run [run-jev](scripts/run-jev) with one JSON job on stdin. Inspect the JSON result,
   then verify the page's actual state. Report success only when independent
   checks establish the requested outcome. A `handoff` returns control to the
   regular browser workflow on the same page; reconcile any uncertain action
   before retrying it.

Keep the regular browser skill as the default until the experiment meets its
documented evaluation gates.
