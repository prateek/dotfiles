---
status: accepted
doc_type: plan
owner: Prateek
created: 2026-05-13
updated: 2026-05-15
related:
  - ../adr/0008-sudo-askpass-1password.md
  - ../adr/0006-chezmoi-migration-prototype.md
  - ../references/jamf-self-service-elevation.md
status_detail: "Accepted design; implementation is pending in this checkout. Current code still uses dotfiles_sudo_start, test-sudo-keepalive, and the Jamf keepalive reference."
---

# Sudo Askpass via 1Password Plan

## Goal

Reduce `chezmoi apply` from ~17 password prompts to one TouchID tap on Macs where mscp enforces `Defaults timestamp_timeout=0`, by replacing the keepalive subsystem with a `SUDO_ASKPASS` helper backed by the 1Password CLI.

Rationale and the Keychain-vs-1Password decision live in [ADR 0008](../adr/0008-sudo-askpass-1password.md). This plan describes the changes.

## Shape

### New file: helper script (templated, work-Mac only)

`home/dot_config/dotfiles/private_executable_sudo-askpass.sh.tmpl` — chezmoi materializes to `~/.config/dotfiles/sudo-askpass.sh` mode 0700 only on work Macs (gated via `home/.chezmoiignore` — see below):

```sh
#!/bin/sh
op_bin=/opt/homebrew/bin/op
[ -x "$op_bin" ] || op_bin=/usr/local/bin/op
exec "$op_bin" read --no-newline {{ .sudo.op_ref | quote }}
```

Two-path fallback covers Apple Silicon and Intel Homebrew prefixes. Manual / mise installs of `op` would need a one-line edit; the helper template stays simple in exchange.

### Gate the helper render via `home/.chezmoiignore`

Add a new block to `home/.chezmoiignore`, placed after the credentials block (around line 14, before the package-cask blocks). Use the file's `{{/* ... */}}` comment style:

```text
{{/* sudo-askpass helper is only meaningful on Macs with mscp-style no-cache
     sudo policy. See docs/plans/sudo-askpass-1password-plan.md. */}}
{{- if ne .machine_type "work" }}
.config/dotfiles/sudo-askpass.sh
{{- end }}
```

Personal and homelab Macs don't render the helper at all. `dotfiles_sudo_setup` keys off helper presence — no need to grep the helper's contents for template state.

### Edits to `home/.chezmoitemplates/script_lib.sh`

Delete: `dotfiles_sudo_state_dir`, `dotfiles_sudo_pid_file`, `dotfiles_sudo_preexisting_file`, `dotfiles_sudo_parent_pid_file`, `dotfiles_sudo_parent_pid`, `dotfiles_sudo_keepalive_active`, `dotfiles_sudo_stop`, and the nohup keepalive loop inside `dotfiles_sudo_start`. Approximately 150 lines.

Keep: `dotfiles_admin_elevate`, `_dotfiles_elevate_jamf_self_service`. Orthogonal — Jamf manages admin-group membership, not sudo caching.

Replace `dotfiles_sudo_start` with `dotfiles_sudo_setup`, placed where the deleted sudo machinery began (~line 96), preserving the file's generic→specific helper ordering:

```sh
dotfiles_sudo_setup() {
  if ! groups | grep -qw admin; then
    log "Administrator group membership required."
    dotfiles_admin_elevate || die "Could not elevate to administrator. See docs/references/jamf-self-service-elevation.md."
  fi

  local helper="${HOME}/.config/dotfiles/sudo-askpass.sh"
  if [ -x "$helper" ]; then
    export SUDO_ASKPASS="$helper"
    # Shadow sudo to add -A. Defined inside setup so personal/homelab Macs
    # (where the helper isn't rendered) never see the function and bare sudo
    # calls in scripts dispatch to /usr/bin/sudo as today.
    sudo() { command sudo -A "$@"; }
  fi
}
```

`dotfiles_sudo_setup` calls `dotfiles_admin_elevate` first (gated on `groups | grep -qw admin`) instead of as a fallback when sudo cache fails. The old gating relied on `sudo -n -v` failing — under askpass that gate doesn't fire, so admin elevation must be checked explicitly.

### Callsite renames in chezmoi scripts

Rename `dotfiles_sudo_start "..."` → `dotfiles_sudo_setup` at five sites:

- `home/.chezmoiscripts/run_once_before_00-homebrew.sh.tmpl:15`
- `home/.chezmoiscripts/run_onchange_after_10-brew-bundle.sh.tmpl:37`
- `home/.chezmoiscripts/run_onchange_after_15-xcode.sh.tmpl:51`
- `home/.chezmoiscripts/run_onchange_after_15-xcode.sh.tmpl:62`
- `home/.chezmoiscripts/run_onchange_after_30-macos-defaults.sh.tmpl:25`

The reason-string argument is dropped — the new function doesn't need it (no interactive prompt to label).

No other callsite edits — bare `sudo` lines in `home/.chezmoitemplates/macos-defaults.sh.tmpl` and the xcode script dispatch through the shadow function. Brew is its own Ruby subprocess that calls `/usr/bin/sudo` directly, but it auto-detects `SUDO_ASKPASS` in env and adds `-A` itself (see ADR 0008 Context).

### Chezmoi data additions

`home/.chezmoi.toml.tmpl` gains a `[data.sudo]` section, gated on `machine_type == "work"` (matching the `jamf_policy_id` pattern at lines 60-62).

**Preamble** — insert after line 62 (the `jamf_policy_id` block):

```text
{{- /* 1Password secret reference for the macOS user password. Required on
       Macs with mscp-style no-cache sudo policy; not prompted elsewhere. */ -}}
{{- $sudoOpRef := env "DOTFILES_SUDO_OP_REF" -}}
{{- if and (not $sudoOpRef) (eq $machineType "work") -}}
{{-   $sudoOpRef = promptStringOnce . "sudo_op_ref" "1Password secret reference for macOS sudo password (op://Vault/Item/password)" "" -}}
{{- end -}}
{{- if and (eq $machineType "work") (not $sudoOpRef) -}}
{{-   fail "DOTFILES_SUDO_OP_REF or sudo_op_ref prompt cannot be empty on work machines." -}}
{{- end -}}
```

**Body** — append after the existing `[data.elevation]` block at lines 85-87:

```toml
[data.sudo]
op_ref = {{ $sudoOpRef | quote }}
```

`fail` on empty value catches the "user hit Enter at the prompt" mistake. Recovery is in step 6 of Bootstrap.

Asymmetry note: the askpass helper inlines the templated `op_ref` directly rather than sourcing `~/.config/dotfiles/<name>.sh` like `elevation.sh` does, because sudo `exec`s the helper directly with no shell to source from.

### CI workflow

`.github/workflows/install-smoke.yml`: add `make test-sudo-askpass` to the "Tart helper contract" step, after `make test-plist-hooks` (line 55). The bootstrap-smoke step (`chezmoi init --promptDefaults`) leaves `machine_type` at its `personal` default (per `home/.chezmoi.toml.tmpl:47`), so the gate skips the prompt and the helper isn't rendered. `dotfiles_sudo_setup` then sees no helper, doesn't export `SUDO_ASKPASS`, and the `sudo()` shadow is never defined. CI is safe without env-var tuning. `apply --dry-run` doesn't execute scripts in any case.

## Bootstrap (one-time per work Mac)

1. Confirm 1Password 8 desktop app is installed, signed in, and unlocked. Settings → Developer → "Integrate with 1Password CLI" must be ON.
2. Confirm `op` is on PATH. Already in `home/.chezmoidata/packages.toml` (cask `1password-cli`, in both core and full profiles, lines 34 and 304).
3. Locate the 1Password item for the macOS user password (most users already have one). If absent, create it interactively in the 1Password app — don't pass the password as a CLI argument (it would land in shell history and `ps` output).
4. Capture the secret reference: 1Password app → right-click item → "Copy Secret Reference". Looks like `op://Private/Mac Login - foo/password`.
5. Bootstrap the reference. The env-var path bakes the value directly into rendered `~/.config/chezmoi/chezmoi.toml` (bypassing `promptStringOnce`); to change later, re-run with the new value or edit `chezmoi.toml` directly. Mirrors the `jamf_policy_id` bootstrap pattern in `docs/references/jamf-self-service-elevation.md`:
   ```sh
   DOTFILES_SUDO_OP_REF='op://Private/Mac Login - foo/password' chezmoi init …
   ```
6. **Recovery:** if `chezmoi init` ever fails with the "cannot be empty" guard (e.g. you hit Enter at an interactive prompt), edit `~/.config/chezmoi/chezmoi.toml`'s `[data.sudo].op_ref` directly to set the value, or re-run `chezmoi init` with `DOTFILES_SUDO_OP_REF` set (the env-var path bakes the value into the rendered file on every init). `promptStringOnce` reads from the data map (specifically the rendered `chezmoi.toml`), not from chezmoi state — there is no state bucket to clear.
7. `chezmoi apply` materializes the helper. First subsequent apply triggers one TouchID prompt (1Password biometric), then runs silent.

## Validation

Replace `tests/sudo-keepalive.zsh` with `tests/sudo-askpass.zsh` covering:

- Helper file exists, is executable, mode 0700, syntactically valid sh.
- Helper produces a password from a stub `op` (PATH-shimmed for the test).
- `dotfiles_sudo_setup` calls `dotfiles_admin_elevate` when user not in admin group; skips when already admin.
- `dotfiles_sudo_setup` exports `SUDO_ASKPASS` and defines `sudo()` when the helper is present and executable.
- `dotfiles_sudo_setup` does NOT export `SUDO_ASKPASS` and does NOT define `sudo()` when the helper file is absent (personal-Mac path).
- `sudo()` (when defined) dispatches to `command sudo -A`; `command sudo` (when not) goes directly to `/usr/bin/sudo`. Test with stub `sudo`.
- Idempotency: calling `dotfiles_sudo_setup` twice produces the same env, no state files, no errors.

Reuse the existing stub-`sudo`-on-PATH harness from `tests/sudo-keepalive.zsh:14-46`. Keep the Jamf elevation cases (`run_admin_elevate_case`) verbatim. Remove the keepalive-specific cases: `run_helper_case`, `run_auto_cleanup_case`, `run_chezmoi_parent_case`, `run_parent_lookup_race_case`, `run_stale_parent_case`, `run_missing_parent_marker_case` — six of seven existing cases.

After the migration, `grep -rn 'sudo-keepalive\|dotfiles_sudo_start' .` should return zero hits.

### Makefile and tests/README.md updates

`Makefile`:
- Line 2 (the long `.PHONY` declaration): rename `test-sudo-keepalive` → `test-sudo-askpass`.
- Replace target body for `test-sudo-keepalive` (currently: `@zsh ./tests/sudo-keepalive.zsh`) with `test-sudo-askpass` invoking `tests/sudo-askpass.zsh`.

`tests/README.md` line 58: rename `make test-sudo-keepalive` → `make test-sudo-askpass`.

### Before handoff

```sh
make test-sudo-askpass
make test-macos-defaults-script
make test-chezmoi-config
chezmoi --source "$PWD/home" apply --dry-run --verbose --include=scripts
git diff --check
```

Then real `chezmoi apply` on the work Mac: expect exactly one TouchID tap at the start and zero password prompts after.

## Documentation

Edit `docs/references/jamf-self-service-elevation.md`:
- Subhead changes from "sudo keepalive" to "Askpass + Jamf elevation".
- Update "How it wires up": `dotfiles_sudo_setup` calls `dotfiles_admin_elevate` first (gated on `groups | grep -qw admin`), then exports `SUDO_ASKPASS` and shadows `sudo()` when an op-backed helper is present.
- Cross-reference this plan and ADR 0008.

No new reference doc.

## Out of scope

- **IT exception ask for `os_sudo_timeout_configure.odv`** — best long-term fix, but a conversation, not a code change. See [ADR 0008 Future work](../adr/0008-sudo-askpass-1password.md#future-work).
- **TouchID via `/etc/pam.d/sudo_local`** for everyday non-chezmoi sudo — separate small commit.
- **Per-script `dotfiles_admin_recheck` for >1h Jamf grant expiry** — apply takes ~5 min in practice; document as a known limitation in `docs/references/jamf-self-service-elevation.md` instead.
- **Concurrent `chezmoi apply` runs** — `op` may return `another sign-in is in progress` for the loser; sudo surfaces the failure on stderr. Acceptable; no data corruption.
