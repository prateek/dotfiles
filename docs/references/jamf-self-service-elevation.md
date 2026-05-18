---
status: current
doc_type: reference
created: 2026-05-12
updated: 2026-05-12
related:
  - ../adr/0008-sudo-askpass-1password.md
  - ../plans/sudo-askpass-1password-plan.md
status_detail: "Current behavior until ADR 0008 lands in code; the checkout still uses dotfiles_sudo_start and sudo-keepalive."
---

# Jamf Self Service elevation hook

`chezmoi apply` runs a sudo-keepalive (`dotfiles_sudo_start` in
`home/.chezmoitemplates/script_lib.sh`) so long install scripts (Homebrew,
Xcode, brew bundle, macOS defaults) don't re-prompt mid-run. On a personal
Mac the user is permanently in the `admin` group and `sudo` works
unconditionally; on an MDM-managed work Mac the user has to "elevate" first
through the IT-provided Self Service app, which adds them to `admin` for ~1h.

This hook fires that elevation automatically when the keepalive would
otherwise fail because the user isn't yet admin.

## How it wires up

1. `chezmoi init` prompts once for `machine_type` (`personal` / `homelab` /
   `work`). On `work` it also prompts once for the Jamf Self Service
   policy ID that grants temp admin (see "Finding the policy ID" below).
2. Both values are written to `~/.config/chezmoi/chezmoi.toml` under
   `[data]` and `[data.elevation]`.
3. `chezmoi apply` materializes them into `~/.config/dotfiles/elevation.sh`
   from `home/dot_config/dotfiles/elevation.sh.tmpl`. That file just sets
   `DOTFILES_ELEVATION_METHOD` and `DOTFILES_JAMF_POLICY_ID`.
4. When `dotfiles_sudo_start` runs and the sudo cache is cold, it calls
   `dotfiles_admin_elevate` first. That function sources the env file and,
   for `jamf-self-service`:
   - Returns immediately if `id -Gn` already shows `admin`.
   - Otherwise opens
     `jamfselfservice://content?entity=policy&action=execute&id=<id>`,
     which auto-runs the policy (no extra click required).
   - Polls `id -Gn` every second for up to 30s for `admin` to appear.
   - Returns 0 on success, non-zero (and aborts the apply) on timeout.
5. Control returns to the keepalive's normal `sudo -v` path.

If `DOTFILES_ELEVATION_METHOD` is `none` (or the env file is missing), the
hook is a no-op and behavior matches a personal Mac.

## Overrides

| Variable                       | Effect                                           |
| ------------------------------ | ------------------------------------------------ |
| `DOTFILES_MACHINE_TYPE`        | Skip the `chezmoi init` prompt for machine type. |
| `DOTFILES_ELEVATION_METHOD`    | Force `none` / `jamf-self-service` per shell.    |
| `DOTFILES_JAMF_POLICY_ID`      | Override the rendered policy ID per shell.       |

To change the persistent values, either edit
`~/.config/chezmoi/chezmoi.toml` directly or rerun `chezmoi init` with the
relevant `DOTFILES_*` env var set.

## Finding the policy ID

The policy ID is per-org and per-policy, so it is not committed to the
repo. To recover it:

1. Open Self Service and note the human-readable name of the policy that
   grants temporary admin (e.g. "Temp Admin").
2. Find the per-user catalog cache and grep for the name:

   ```
   grep -B1 -A2 'Temp Admin' \
     "$HOME/Library/Application Support/com.jamfsoftware.selfservice.mac/CocoaAppCD.storedata"
   ```

   The output includes a line like
   `<attribute name="id" type="int64">1234</attribute>` adjacent to the
   matched `<attribute name="name" type="string">Temp Admin</attribute>`.
   That number is the policy ID.
3. Construct and verify the URL:

   ```
   open "jamfselfservice://content?entity=policy&action=execute&id=1234"
   ```

   The Self Service window opens and the policy auto-runs in 5–10s. Tail
   the Jamf log to confirm:

   ```
   sudo grep 'Temp Admin' /var/log/jamf.log | tail -3
   ```

   You should see a fresh `Executing Policy <name> (Self Service)` entry.

## When to refresh the ID

If your org renames the policy, replaces it with a new one, or changes its
ID, the deep-link will silently no-op. Symptoms:

- `chezmoi apply` stalls at the elevation hook for 30s and then aborts
  with `Could not elevate to administrator.`
- No new `Executing Policy <name>` line appears in `/var/log/jamf.log`.

Re-run the discovery steps above and update the ID with one of:

- `DOTFILES_JAMF_POLICY_ID=<new-id> chezmoi init` (re-renders config), or
- Edit `jamf_self_service_policy_id` under `[data.elevation]` in
  `~/.config/chezmoi/chezmoi.toml`, then `chezmoi apply` to re-render
  `~/.config/dotfiles/elevation.sh`.

## Auditability note

The elevation runs through the same policy that the Self Service GUI
button invokes, so it shows up in Jamf's policy logs the same way. If your
IT team monitors Self Service usage, programmatic invocations are
indistinguishable from a manual click.
