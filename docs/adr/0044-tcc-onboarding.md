---
status: accepted
doc_type: adr
owner: Prateek
created: 2026-10-05
updated: 2026-10-05
related:
  - ../plans/tcc-onboarding-plan.md
status_detail: "Implemented in source; opt-in terminal prompt. Attended native validation is deferred."
---

# ADR 0044 — Declarative TCC onboarding with a native helper

## Decision

Declare expected macOS permissions per app in one dotfiles data manifest.
Render JSON for a small SwiftUI app that reads TCC databases in read-only mode
and guides the user through the corresponding System Settings changes.
An enabled interactive `chezmoi apply` asks in the terminal after apps are
installed. Choosing yes launches reconciliation; no is the default. The user
grants access, and unresolved permissions can be deferred. Every machine must
opt in through its feature configuration.

The [implementation plan](../plans/tcc-onboarding-plan.md) defines the agreed
behavior and state semantics. The user deferred attended native validation
until after implementation; its completion remains a rollout requirement.

## Rationale

Cross-app onboarding needs an inventory that works without launching every
target app. Read-only TCC inspection provides one shared source of recorded
authorization. A native file drag carries the exact app or helper identity to
the Settings pane and avoids asking the user to locate each bundle manually.

Permission metadata belongs in a dedicated structured-data catalogue, alongside
the repo's package and machine data. Native app preferences keep their existing
owners. Swift consumes rendered JSON, avoiding a second TOML parser.

## Consequences

The helper may need its own Full Disk Access grant before it can inspect other
clients. Its bootstrap and rebuild behavior must be validated before inventory
expansion. Unchanged applies preserve its installed binary; manifest changes
do not alter its signature.

TCC's database is an implementation detail. Unsupported schemas, unavailable
data, and identity ambiguity remain unresolved. An allowed record describes
recorded state; it does not promise that the target app has adopted a change
without restarting or that every runtime operation will succeed.

The app has no privileged service and performs no permission mutations.
macOS retains responsibility for user consent and policy enforcement.

## Alternatives

- Per-app `doctor` adapters provide useful runtime evidence, but require
  separate integrations and often running app processes. Defer them until
  a specific reconciliation failure warrants one.
- A printed checklist is cheap but leaves app discovery and navigation to
  the user, missing the requested drag-and-drop flow.
- Database writes or managed profiles change the authorization mechanism
  and do not serve this user-driven onboarding requirement.
- A third-party permission UI library adds dependency and packaging work
  for a small native surface. Revisit only if the required UI grows.
