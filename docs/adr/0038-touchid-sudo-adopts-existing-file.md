---
status: accepted
doc_type: adr
owner: Prateek
created: 2026-09-28
updated: 2026-09-28
related:
  - 0030-touchid-sudo.md
  - ../plans/touchid-sudo-plan.md
  - ../references/chezmoi-architecture.md
current_guidance: ../references/chezmoi-architecture.md
---

# ADR 0038 — Touch ID for sudo adopts any existing sudo_local

## Decision

Follow `sudo-touchid`'s ownership model for `/etc/pam.d/sudo_local`. With
`touchid_sudo` on, any existing `sudo_local` counts as installed: the hook logs
it and requests no sudo. With the flag off, the hook removes the file or symlink
whatever it contains. It still writes its payload only when the path is absent,
after checking the `sudo_local` include and Apple's module, and it still keeps a
file that appears while it authenticates or stages. This supersedes
[ADR 0030](0030-touchid-sudo.md)'s exact-payload ownership.

## Rationale

A hand-made `sudo_local` from Apple's template already enables Touch ID, but
exact-payload ownership warned about it on every apply and offered no fix short
of a manual root edit. The flag is the declared intent for this path, so any
file there already satisfies "on", and "off" means no `sudo_local` at all. This
also drops the privileged content comparison and metadata repair, which only
existed to decide ownership.
See [upstream source](https://github.com/artginzburg/sudo-touchid/blob/14fa45788d117b38d7c813804780fca46626e6f8/sudo-touchid.sh).

## Consequences

The hook no longer repairs owner, group, or mode on an existing file, and it
does not check that an existing file contains `pam_tid`. Turning the flag off
deletes any other rules someone kept in `sudo_local`. That includes machines
that never set it, since `false` is the default for homelab, CI, and new roles;
opt in before hand-editing `sudo_local` there. A directory at that path
is still left alone with a warning. Operating instructions live in
[Chezmoi Architecture](../references/chezmoi-architecture.md#touch-id-for-sudo).
