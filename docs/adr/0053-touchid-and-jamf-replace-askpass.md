---
status: accepted
doc_type: adr
summary: "Sudo during chezmoi apply authenticates with Touch ID on personal Macs and Jamf Self Service elevation on work Macs; the 1Password askpass helper is not built."
owner: Prateek
created: 2026-10-17
updated: 2026-10-17
related:
  - 0008-sudo-askpass-1password.md
  - 0030-touchid-sudo.md
  - 0038-touchid-sudo-adopts-existing-file.md
  - ../references/jamf-self-service-elevation.md
  - ../retired.md
current_guidance:
  - ../references/jamf-self-service-elevation.md
  - ../references/chezmoi-architecture.md
status_detail: "Closes the askpass design from ADR 0008 and its plan without building it."
---

# Touch ID and Jamf elevation replace the askpass helper

## Decision

`chezmoi apply` gets its privileges two ways, and neither is the 1Password
askpass helper that [ADR 0008](0008-sudo-askpass-1password.md) accepted.
On personal Macs, sudo authenticates with Touch ID through the `sudo_local`
configuration from [ADR 0030](0030-touchid-sudo.md) and
[ADR 0038](0038-touchid-sudo-adopts-existing-file.md). On Jamf-managed work
Macs, the operator takes temporary admin elevation through
[Jamf Self Service](../references/jamf-self-service-elevation.md) before the
apply. The keepalive helper stays only as the fallback where neither applies.
ADR 0008 is superseded and its plan is retired unbuilt.

## Context

ADR 0008 was accepted on 2026-05-15 with a design for a `SUDO_ASKPASS` helper
that reads the password from 1Password, so a work Mac with no sudo credential
caching would need one Touch ID tap per apply. Five months later nothing had
been built, the Touch ID path had landed for personal machines, and the Jamf
elevation reference had become the documented work-Mac procedure. The
quarterly review surfaced the plan as idle, and Prateek chose to close it.

## Alternatives

- **Build the askpass helper as designed.** Still possible from the retired
  plan in git history. Rejected because the two paths above already cover
  every machine the repo manages, and the helper would add a 1Password
  dependency to the privileged path.
- **Keep the plan parked.** Rejected because no trigger would reopen it; a
  work Mac that loses Jamf elevation would need a new decision anyway.

## Consequences

- ADR 0008 carries a supersession banner and points here.
- The sudo askpass plan is in the [retirement ledger](../retired.md).
- The keepalive helper and its tests remain until a machine type needs
  neither Touch ID nor Jamf elevation, at which point that is a new decision.
