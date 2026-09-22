---
status: accepted
doc_type: adr
owner: Prateek
created: 2026-08-30
updated: 2026-09-22
related:
  - ../plans/touchid-sudo-plan.md
  - ../references/chezmoi-architecture.md
---

# ADR 0030 — Touch ID for sudo

## Decision

Enable Apple's built-in `pam_tid` module by managing `/etc/pam.d/sudo_local`
through a focused chezmoi hook. The `touchid_sudo` machine flag enables it on
personal and work Macs; CI and homelab default to disabled.

The hook owns only its exact two-line payload. It preserves foreign contents,
including files made from Apple's template, and refuses symlinks or other
non-regular files. It checks that `/etc/pam.d/sudo` includes `sudo_local` and that
Apple's module is a regular root-owned file before enabling the rule. It writes
with an atomic rename and repairs owner, group, and mode drift on its own file.
Disabling the flag removes only that exact managed payload.

## Rationale

This uses the site-local file provided by macOS without editing `/etc/pam.d/sudo`
or adding another PAM module. Touch ID availability is checked during
authentication, so configuration does not depend on a connected keyboard,
enrollment, or lid state.

The `sudo-touchid` package uses the same mechanism. Its current implementation
treats any existing `sudo_local` as installed and removes the entire file when
disabled. A local hook keeps file ownership and repeated-apply behavior explicit.
See [upstream source](https://github.com/artginzburg/sudo-touchid/blob/14fa45788d117b38d7c813804780fca46626e6f8/sudo-touchid.sh).

## Consequences

The first write requires administrator access. Later applies need no sudo when
the file is correct. Work Macs still require their temporary admin grant; Touch
ID does not change sudoers authorization. A baseline without the `sudo_local`
include prevents enablement and produces a warning.

This decision does not change credential caching, add password retrieval, or
enable Touch ID inside tmux. Implementation is tracked in the
[plan](../plans/touchid-sudo-plan.md); operating instructions live in
[Chezmoi Architecture](../references/chezmoi-architecture.md#touch-id-for-sudo).
