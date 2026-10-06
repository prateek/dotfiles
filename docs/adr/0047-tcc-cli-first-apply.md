---
status: accepted
doc_type: adr
owner: Prateek
created: 2026-10-06
updated: 2026-10-06
related:
  - 0046-tcc-onboarding.md
  - ../plans/tcc-onboarding-plan.md
  - ../runbooks/tcc-onboarding.md
status_detail: "CLI-first integration implemented; attended grant and rebuild validation remains deferred."
---

# ADR 0047 — CLI-first permission auditing during apply

## Decision

An enabled `chezmoi apply` audits recorded access headlessly after installing
apps. Personal, work, and homelab Mac roles enable it by default; CI and devbox
remain disabled. Host and local overrides retain precedence. This replaces
[ADR 0046](0046-tcc-onboarding.md)'s opt-in terminal prompt.

The CLI shares app resolution, read-only TCC queries, and stored-requirement
validation with the native helper. Matching installed expectations are quiet.
Known deviations and unknown evidence print reasons and one shell-safe command
opening the registry document in the helper. Apply never launches the GUI or
changes grants. The user walks through repair in the native window.

The [plan](../plans/tcc-onboarding-plan.md) records scope and acceptance; the
[runbook](../runbooks/tcc-onboarding.md) defines commands and exit statuses.

## Rationale

An automatic audit surfaces drift without interrupting apply for a question or
opening a window. Sharing the permission core keeps CLI and GUI interpretation
consistent. A document-open command also reaches an already-running helper.

## Consequences

CLI evidence describes its calling process context, not the GUI helper's access.
Unreadable databases, ambiguous subjects, unsupported or conflicting evidence,
and unverifiable signatures remain unknown. The GUI checks its own bootstrap
access. A valid signature failing the stored requirement remains stale.

No installed targets means there is nothing to reconcile; it establishes no
grant. Unknown evidence has a distinct exit status from known deviations. Apply
continues with guidance for either, but invalid manifests and unexpected audit
or build failures fail the hook.

A reused helper must advertise the CLI contract in its signed bundle metadata.
Legacy helpers are never called with unknown flags that could launch their GUI.
Missing tools, deferred updates, and installation locks report audit availability
and recovery without claiming convergence. Source/toolchain digests preserve
unchanged bundles; registry edits do not rebuild them. Ad-hoc signature retention
and real Settings changes still require attended validation.
