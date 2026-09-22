---
status: active
doc_type: plan
owner: Prateek
created: 2026-08-30
updated: 2026-09-22
related:
  - ../adr/0030-touchid-sudo.md
  - ../references/chezmoi-architecture.md
status_detail: "Implementation and local checks complete; live authentication has not been exercised."
---

# Touch ID for sudo

Enable Apple's `pam_tid` module through `/etc/pam.d/sudo_local` during
`chezmoi apply`. [ADR 0030](../adr/0030-touchid-sudo.md) records the decision.

## Scope

- Resolve `touchid_sudo` through `machines.toml`: off by default, explicitly
  enabled for personal and work profiles. Skip non-macOS hosts at runtime.
- Run `run_before_01-touchid-sudo` after Homebrew bootstrap and before core
  tool installation. Render it empty when `run_install_scripts=false`.
- Require the active `sudo_local` include and Apple's root-owned PAM module.
- Create the managed file, repair its metadata, and remove it when disabled.
  Preserve any file whose full contents differ, including a manually enabled
  Apple template. Preserve symlinks and other non-regular files.
  Compare unreadable files with administrator access before deciding ownership.
- Install through a unique temporary name in the PAM directory, then recheck the
  target before renaming. Recheck after authentication before removal, too.
  Do not request sudo when the managed file is already correct.

Keep the existing sudo helper and Jamf elevation behavior. Changes to credential
caching, 1Password askpass, Xcode installation, and tmux support are separate work.

## Validation

Passing local checks cover rendering, machine flags, file contents and permissions,
repeated applies, foreign files, missing prerequisites, removal, and failed writes.
Regressions cover unreadable files, administrator edits during authentication or
staging, and the disabled default for new machine roles. The sudo fixture checks
the requested installation owner and group without requiring root.
The former Linux flag-value assertion is replaced by executing the rendered hook
with a non-macOS runtime: profile opt-in must never change PAM there.
The Bats suite replaces the old zsh harness's status-name and write-count checks
with file outcomes and injected write failures. Manual Apple configurations are
now preserved. The incidental one-line log assertion was dropped.

```sh
just test-shell tests/bats/hooks/touchid-sudo.bats tests/bats/hooks/chezmoi-status.bats
just test-python -p test_machines.py
just test-docs-lifecycle
git diff --check
```

Also run shellcheck on the library and rendered hook, and preview the hook with
`chezmoi diff` and `chezmoi apply --dry-run --verbose`.

Live authentication remains a separate attended check. In a GUI terminal, apply
the hook, run `sudo -k`, then `sudo -v`, and confirm Touch ID works. Confirm password
fallback when Touch ID is unavailable. On work Macs, confirm the required Jamf
admin grant first. See [operator guidance](../references/chezmoi-architecture.md#touch-id-for-sudo).
