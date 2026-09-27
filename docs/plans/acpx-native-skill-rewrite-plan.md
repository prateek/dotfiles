---
status: archived
doc_type: plan
created: 2026-09-26
updated: 2026-09-26
closed: 2026-09-26
current_guidance:
  - ../runbooks/acpx-skill-rewrite.md
related:
  - ../runbooks/acpx-skill-rewrite.md
  - acpx-skill-rewrite-plan.md
status_detail: "Native ACP flows authored and verified with mock agents; no production sweep executed."
---

# Native acpx skill rewrite flows

The first version placed every model invocation inside a Python action, hiding
rewrite/review/fix from the native viewer. Move each model step into an `acp`
node, with deterministic Git and patch operations in JavaScript action nodes.

The parent prepares a source snapshot, launches a bounded number of native
per-skill flow commands through managed `runShell`, assembles their patches,
runs one native afablex review node, and exports the validated patch. Each child
has setup, Astra rewrite, draft capture, Opus review, review verification, Astra
fix, and final capture nodes. Native run bundles retain every ACP conversation.
The existing runtime requires separate child runs: nested parallel graph rendering
and a native bounded map remain upstream limitations.

Retain authored-only scope, exact child model pins, isolated checkouts, patch and
report gates, one version increment per changed plugin, source/index preservation,
and explicit execution. Retire the Python driver without an alias.

## Verification

The seven Node contract scenarios preserve the previous six tests' guarantees
and add native-node visibility and child-run failure handling. The subprocess
timeout test now checks deadline forwarding and cancellation through the acpx
context; process-group ownership belongs to acpx rather than a custom controller.
A local acpx 0.19.3 smoke check runs two fixture skills through a mock ACP adapter
and verifies native conversation artifacts, including the single final-review
node. Syntax, docs lifecycle, and diff checks complete the authoring scope.
The native deadline check also confirms termination and reaping of a timed-out
fixture process. The native viewer previews both definitions with zero executed
steps.
The production skill sweep and real providers remain unexecuted.
