---
status: active
doc_type: plan
owner: Prateek
created: 2026-08-30
updated: 2026-09-28
related:
  - ../adr/0030-touchid-sudo.md
  - ../adr/0038-touchid-sudo-adopts-existing-file.md
  - ../references/chezmoi-architecture.md
status_detail: "Implementation and local checks complete; live authentication has not been exercised."
---

# Touch ID for sudo

Enable Apple's `pam_tid` module through `/etc/pam.d/sudo_local` during
`chezmoi apply`. [ADR 0030](../adr/0030-touchid-sudo.md) records the decision;
[ADR 0038](../adr/0038-touchid-sudo-adopts-existing-file.md) replaces its
exact-payload ownership with `sudo-touchid`'s adopt-and-remove model.

## Scope

- Resolve `touchid_sudo` through `machines.toml`: off by default, explicitly
  enabled for personal and work profiles. Skip non-macOS hosts at runtime.
- Run `run_before_01-touchid-sudo` after Homebrew bootstrap and before core
  tool installation. Render it empty when `run_install_scripts=false`.
- Require the active `sudo_local` include and Apple's root-owned PAM module.
- Create the managed file only when `sudo_local` is absent. Treat any existing
  file or symlink as installed. When disabled, remove any file or symlink; leave
  a directory with a warning.
- Install through a unique temporary name in the PAM directory, then recheck the
  target before renaming, keeping anything that appeared meanwhile.
  Do not request sudo when `sudo_local` already exists.

Keep the existing sudo helper and Jamf elevation behavior. Changes to credential
caching, 1Password askpass, Xcode installation, and tmux support are separate work.

## Validation

Passing local checks cover rendering, machine flags, file contents and permissions,
repeated applies, adoption of existing files, missing prerequisites, removal, and
failed writes. Regressions cover unreadable files, files created during
authentication or staging, and the disabled default for new machine roles. The
sudo fixture checks the requested installation owner and group without requiring
root.
The former Linux flag-value assertion is replaced by executing the rendered hook
with a non-macOS runtime: profile opt-in must never change PAM there.
The Bats suite replaces the old zsh harness's status-name and write-count checks
with file outcomes and injected write failures. Under ADR 0038, metadata repair
and foreign-file preservation on disable were dropped by design, along with
their assertions.

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
