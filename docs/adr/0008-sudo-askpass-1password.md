---
status: accepted
doc_type: adr
created: 2026-05-13
updated: 2026-05-14
owner: Prateek
related:
  - ../dev/sudo-askpass-1password-plan.md
  - 0006-chezmoi-migration-prototype.md
  - ../jamf-self-service-elevation.md
---

# ADR 0008 — Sudo askpass via 1Password

## Context

`chezmoi apply` on Prateek's Jamf-managed work Mac prompts for the macOS user password ~17 times per run. The keepalive (`dotfiles_sudo_start` in `home/.chezmoitemplates/script_lib.sh`, introduced during the chezmoi migration in [ADR 0006](0006-chezmoi-migration-prototype.md)) was designed for normal sudo cache behavior: prime the cache with `sudo -v`, refresh from a background process every 60 s.

The work Mac ships `/etc/sudoers.d/mscp` containing exactly `Defaults timestamp_timeout=0` (29 bytes), pushed by the [mscp `os_sudo_timeout_configure` rule](https://github.com/usnistgov/macos_security/blob/main/rules/os/os_sudo_timeout_configure.yaml) aligned with [CIS Apple macOS Benchmark 5.4](https://www.tenable.com/audits/items/CIS_Apple_macOS_13.0_Ventura_v1.0.0_L1.audit:a2bba56eaf1ac40363b000ff9777a663). With `timestamp_timeout=0` the credential cache is disabled entirely — `sudo -v` succeeds but caches nothing, the keepalive's first `sudo -n -v` ~1 s later fails, the background process self-destructs, every subsequent sudo re-prompts. Confirmed via `sudo cat /etc/sudoers.d/mscp` and `sudo -ll`.

The keepalive cannot be salvaged from our side. The mscp fix script runs `find /etc/sudoers* -type f -exec sed -i '' '/timestamp_timeout/d' {}` before writing its own line, so any competing `Defaults timestamp_timeout=…` under `/etc/sudoers*` gets deleted on every compliance run. Drop-in override schemes are doubly futile: even with the right alphabetical prefix to win the lexical-order race, mscp removes the line.

The right mechanism for unattended sudo when caching is disabled is `SUDO_ASKPASS` — sudo's documented hook for an external program that supplies the password non-interactively. With `sudo -A` and `SUDO_ASKPASS` set, every sudo still authenticates through PAM but the helper provides the password without a tty prompt.

Brew cask installs come along for free. Per Homebrew's `Library/Homebrew/system_command.rb`, the `sudo_prefix` builder checks `ENV.key?("SUDO_ASKPASS")` and adds `-A` to its `/usr/bin/sudo` invocation automatically when the env var is set. Setting `SUDO_ASKPASS` is sufficient for both our scripts and brew. (Verify with `rg 'SUDO_ASKPASS' Library/Homebrew/system_command.rb` against current main; line numbers drift.)

## Decision

Replace the keepalive subsystem with a `SUDO_ASKPASS` helper backed by the 1Password CLI desktop-app integration. Keep the Jamf Self Service elevation hook unchanged (orthogonal — it manages admin-group membership, not sudo caching). Implementation in [`docs/dev/sudo-askpass-1password-plan.md`](../dev/sudo-askpass-1password-plan.md).

Helper at `~/.config/dotfiles/sudo-askpass.sh` (chezmoi-managed, mode 0700) `exec`s `op read --no-newline op://Vault/Item/password`. The 1Password reference is per-machine data templated in directly from `[data.sudo].op_ref` in `chezmoi.toml`, gated on `machine_type == "work"` so non-mscp Macs don't get the prompt. The helper file itself is gated on the same `machine_type` value via `home/.chezmoiignore`, so personal and homelab Macs never see it on disk.

`dotfiles_sudo_setup` (replacing `dotfiles_sudo_start`) checks admin-group membership (calling `dotfiles_admin_elevate` if needed — moved from fallback position to first-position because the old `sudo -n -v` gate doesn't fire under askpass), then if the helper file exists, exports `SUDO_ASKPASS` and defines a `sudo()` shadow that calls `command sudo -A`. No verification probes — first `sudo -A` surfaces helper failures via stderr without pulling the secret into the parent process.

The `sudo()` shadow is defined inside `dotfiles_sudo_setup` so personal and homelab Macs (where the helper isn't rendered) never get the function. Bare `sudo foo` callsites in chezmoi scripts dispatch through the shadow on work Macs and through `/usr/bin/sudo` directly on others. This avoids rewriting every callsite to `sudo -A` (~5 callsites across 5 scripts) and avoids the personal-Mac hard-fail mode where `sudo -A` would fail when no askpass helper is configured.

### Why 1Password over Keychain

A Keychain-backed helper (`security find-generic-password -w`) needs zero TouchID taps but loses on three axes that matter more in this environment:

- **EDR posture.** `security find-generic-password -w` is the textbook MITRE T1555.001 (Keychain credential access) detection. Jamf Protect, SentinelOne, CrowdStrike fire on it; an exception requires a security-team conversation. `op read` is normal 1Password developer behavior on any Mac with the suite installed.
- **Password at rest.** Keychain duplicates the macOS user password into the login Keychain. 1Password points at the existing entry — no new copy.
- **Audit and rotation.** 1Password records vault access; Keychain doesn't. When the macOS password rotates, update once in 1Password and every Mac picks it up; with Keychain we'd re-bootstrap per machine.

The cost is one TouchID tap per `chezmoi apply` and a runtime dependency on 1Password being unlocked. Apply takes ~5 min; one tap up front is acceptable.

## Consequences

`chezmoi apply` drops from ~17 prompts to one TouchID tap on the work Mac. `home/.chezmoitemplates/script_lib.sh` shrinks by ~150 lines (entire keepalive lifecycle); `tests/sudo-keepalive.zsh` shrinks by ~250 lines (6 of 7 cases removed; Jamf elevation cases retained). New `tests/sudo-askpass.zsh` covers the helper, the `sudo()` function dispatch, and `dotfiles_sudo_setup`'s admin-group + helper-detection logic.

Brew cask installs become silent for free via Homebrew's native `SUDO_ASKPASS` detection. No PATH shim, no Brewfile reordering, no callsite rewrites in our scripts.

Chezmoi data gains `[data.sudo].op_ref` (per-machine, in `chezmoi.toml`, gated on `machine_type == "work"` so it never prompts on personal Macs). Empty value on a work Mac fails the template render with an explicit error — the safety net for users who hit Enter at the prompt without setting `DOTFILES_SUDO_OP_REF`.

Personal and homelab Macs don't get the helper rendered at all (gated via `home/.chezmoiignore` on `machine_type`). `dotfiles_sudo_setup` sees no helper file, doesn't export `SUDO_ASKPASS`, doesn't define the `sudo()` shadow, and bare `sudo` calls in scripts dispatch to `/usr/bin/sudo` directly — behavior identical to today (tty prompt).


## Alternatives considered

- **Keychain-backed askpass** (`security find-generic-password -w`). Zero TouchID taps but worse EDR posture, duplicates the password at rest, no audit trail, per-machine bootstrap. Rejected because the EDR signal is real and one TouchID tap is cheap. Documented as a fallback in `script_lib.sh` comments for users without 1Password.

- **TouchID for sudo via `/etc/pam.d/sudo_local`** (`pam_tid.so`). Doesn't reduce prompt count — `pam_tid` shares sudo's timestamp cache; with `timestamp_timeout=0` every sudo still triggers PAM, which means a TouchID tap per sudo (~17 taps). Useful as a separate small commit for everyday CLI sudo outside chezmoi; orthogonal to this ADR.

- **Custom `/etc/sudoers.d/zz-prungta-keepalive` overriding `timestamp_timeout`.** Doubly futile per Context — mscp's fix script `sed`-deletes the line on every compliance run, AND a foreign file in `/etc/sudoers.d/` may be flagged by Jamf inventory as compliance drift.

- **`osascript -e 'do shell script "..." with administrator privileges'`** to bypass sudo entirely. Authorization Services credential cache is per-process and tied to the GUI/Aqua session per [Apple QA1277](https://developer.apple.com/library/archive/qa/qa1277/_index.html); doesn't share across chezmoi script subprocesses. Also bypasses sudo audit. Wrong tool.

- **Rewriting every callsite to `sudo -A`** instead of using a shell-function shadow. Invasive (~12 bare `sudo` invocations across `macos-defaults.sh.tmpl` and the xcode script — distinct from the 5 `dotfiles_sudo_start` callsites the function-shadow approach renames), adds a static-lint regression-catch surface, and fails when run on personal Macs (`sudo -A` fails when no askpass helper is configured per sudo(8)). The function shadow is one place, no callsite churn, and falls through cleanly on personal Macs.

- **Greppping the rendered helper to detect non-empty `op_ref`** instead of gating render via `.chezmoiignore`. Earlier draft used `grep -E '^exec [^"]+ read --no-newline ' "$helper"` to infer template state from the helper's contents. Brittle (any reformatting of the helper template breaks detection) and reads the output of our own template engine to recover an input we already had. Replaced with a `home/.chezmoiignore` template-gate keyed on `machine_type`, matching the existing `cmux`/`zed`/`ghostty` pattern in the same file.

## Future work

- **IT ask for `os_sudo_timeout_configure.odv`.** The mscp rule has an Organization Defined Value field; CIS recommends 0 but the framework supports any non-negative number of minutes. If IT raises the engineering baseline to e.g. 15, sudo's cache resumes and the askpass complexity becomes optional. Worth asking in writing — this is the actual best fix.

- **TouchID via `/etc/pam.d/sudo_local`** as a separate commit for everyday non-chezmoi CLI sudo ergonomics.
