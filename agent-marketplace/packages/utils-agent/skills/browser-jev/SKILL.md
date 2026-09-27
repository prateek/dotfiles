---
name: browser-jev
description: Run an explicitly requested Jev browser experiment on an owned Orca page or isolated agent-browser session. Use the regular browser skill for other browser work.
---

# Experimental Jev browser

1. Read the regular [browser skill](../browser/SKILL.md) and its
   [policy](../browser/references/policy.md). Use its harness, driver, identity,
   authorization, focus, and cleanup rules. This experiment supports the
   Orca embedded browser and standalone agent-browser; use the regular skill
   when it selects another driver.
2. Read the [Jev trial reference](references/jev.md) for the job contract and
   handoff rules. Give the runner an owned page, exact allowed origins, a
   bounded goal, and caller-authorized ordinary values. Prefer dynamic
   discovery for reversible tasks; use explicit controls when authorization
   needs a narrower action list.
3. Run [run-jev](scripts/run-jev) with one JSON job on stdin. Check its result
   and the page's actual state. A `verified` result needs independent checks;
   a `handoff` returns control to the same browser workflow. Keep the regular
   browser skill as the default until the experiment meets its evaluation
   gates.
