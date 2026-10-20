---
status: accepted
doc_type: adr
summary: "Apply drives a bundled `dotfiles-permissions` CLI that reads TCC under the helper's own identity; an enabled audit that cannot read TCC fails apply, and the GUI reads only the XDG manifest."
owner: Prateek
created: 2026-10-20
updated: 2026-10-20
related:
  - 0047-tcc-cli-first-apply.md
  - ../plans/tcc-onboarding-plan.md
  - ../runbooks/tcc-onboarding.md
status_detail: "Implemented with automated checks; attended grant, rebuild, and GUI validation remain."
---

# ADR 0057 — The helper's CLI owns TCC access during apply

## Decision

The permission helper bundles a command-line interface, `dotfiles-permissions`,
installed as a chezmoi-managed symlink to the bundle executable. It follows the
composable agent CLI shape: noun-verb commands (`doctor`, `audit`, `grants list`,
`apps list`, `manifest validate`, `settings open`, `gui`), `--json` with stable
shapes on stdout, diagnostics on stderr, and documented exit statuses. The
apply hook runs `audit` through it. Its output names the optional GUI.

Commands that read TCC re-execute the helper as its own responsible process.
TCC then evaluates the helper's Full Disk Access grant, not the terminal's, so
the CLI and the GUI need the same single grant. When the feature is enabled
and the helper cannot read either database, or no usable helper exists, apply
fails with recovery steps instead of continuing. Known deviations and
inconclusive evidence still continue apply with the CLI report.

The GUI and CLI resolve the manifest by XDG convention,
`$XDG_CONFIG_HOME/dotfiles/tcc.json` with the `~/.config` fallback; the GUI
takes no manifest argument. Document opening, the reconcile URL scheme, launch
arguments, and the remembered registry path are removed.

This supersedes [ADR 0047](0047-tcc-cli-first-apply.md).

## Rationale

ADR 0047's audit inherited the calling terminal's access, so a terminal with
Full Disk Access hid a helper without it, and an unreadable database only
produced a warning. Prateek asked for an enabled feature to fail loudly when
the helper lacks the access it needs. Disclaiming responsibility makes the
CLI's result describe the helper itself, which is the access both apply and
the GUI rely on. A conventional CLI gives agents and scripts the same reads
the hook uses without parsing prose. One manifest location removes launch
modes that existed only for ADR 0046's prompt.

## Consequences

Responsibility disclaim uses the private `responsibility_spawnattrs_setdisclaim`
call, which Chromium also uses. It is resolved at run time, so its absence
fails only the TCC commands. If it fails, the CLI exits rather than falling
back to inherited access.

Failing apply makes grant loss expensive, so the installer signs with a
per-machine self-signed certificate instead of ad hoc. Its designated
requirement pins the identifier and certificate leaf, so rebuilds keep the
grant. The keychain password sits in a mode 0600 state file for unattended
signing, which bounds the grant's protection by the user account; `security`
also exposes it to `ps` during the rebuilds that unlock the keychain. Recreating
the identity, and the first build after this change, each cost one re-grant.

A failing hook stops later apply scripts, so the hook runs last and its
failure message names both the recovery and the `tcc_onboarding = false`
override. Deferred updates and install locks remain warnings because they
resolve on the next apply.
