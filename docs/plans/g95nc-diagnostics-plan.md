---
status: archived
doc_type: plan
created: 2026-10-03
closed: 2026-10-03
related:
  - ../runbooks/g95nc-display.md
current_guidance: ../runbooks/g95nc-display.md
status_detail: "Implemented; command tests and live macOS verification completed."
---

# G95NC Preconditions and Diagnostics

The existing command assumes the over-8K framebuffer setting is enabled, discards
all virtual screens, hides CLI errors, and exits successfully after failed setup
when recovery succeeds.

Preserve `check`, `set [WxH]`, and `reset`, and the default 4864x1368 HiDPI at
60 Hz. Add bounded CLI calls and verification, identity-scoped cleanup, automatic
8K preference setup, private retained logs, and a lock against overlapping runs.
Validate the mirror framebuffer against macOS as well as BetterDisplay.

Use command-boundary fixtures to verify missing preferences, failure and recovery,
unrelated-screen preservation, ambiguous identities, read-only checks, deadlines,
log retention, and idempotent repeated setup. Then exercise the real command on
macOS and deploy only the Raycast script through chezmoi.

Current operating instructions belong in the [runbook](../runbooks/g95nc-display.md).
