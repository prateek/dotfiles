---
status: current
doc_type: reference
created: 2026-05-12
updated: 2026-06-29
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
   `work` / `ci`). On `work` it also prompts once for the Jamf Self Service
   policy ID that grants temp admin (see "Finding the policy ID" below).
2. `machine_type` and the policy ID are written to
   `~/.config/chezmoi/chezmoi.toml` under `[data]` (identity). The elevation
   method is not stored there; it resolves at apply time from
   `home/.chezmoidata/machines.toml` (`work` → `jamf-self-service`, others →
   `none`).
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

## Trigger on demand from Raycast

The apply-time hook only fires during `chezmoi apply`. To grab temp admin any
time without an apply, there is a Raycast Script Command, **Temp Admin**, at
`~/.config/raycast/scripts/temp-admin.sh` (chezmoi source:
`home/dot_config/raycast/scripts/executable_temp-admin.sh`, gated on the
`raycast` cask). It does the same thing as
`_dotfiles_elevate_jamf_self_service`: returns early if already `admin`,
otherwise sources `~/.config/dotfiles/elevation.sh` for the method and policy
ID, opens the Self Service deep-link, and polls `id -Gn` for up to 30s. The
policy ID is read at runtime, so nothing org-specific is committed.

One-time setup per machine (Raycast does not persist script directories in its
readable plist, so this cannot be automated):

1. Raycast → Settings → Extensions → `+` → **Add Script Directory**.
2. Select `~/.config/raycast/scripts`.

The command then appears in root search as **Temp Admin**. On a personal Mac
(method `none`) it just reports that you are already an administrator.

## Overrides

| Variable                       | Effect                                           |
| ------------------------------ | ------------------------------------------------ |
| `DOTFILES_ELEVATION_METHOD`    | Force `none` / `jamf-self-service` per shell.    |
| `DOTFILES_JAMF_POLICY_ID`      | Override the rendered policy ID per shell.       |

These two are per-shell runtime overrides read by `elevation.sh`. To change the
persistent values: select the machine type with
`chezmoi init --promptChoice 'machine_type=<type>'`; the elevation method follows
from `machines.toml` (override per machine via a host-local `[data.machines_local]`
block); the policy ID lives at `[data].jamf_policy_id` — edit
`~/.config/chezmoi/chezmoi.toml` or rerun `chezmoi init`.

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

- `DOTFILES_JAMF_POLICY_ID=<new-id> chezmoi apply` for a one-shot run (the
  runtime env var wins for that apply's elevation), or
- Edit `jamf_policy_id` under `[data]` in `~/.config/chezmoi/chezmoi.toml` (or
  rerun `chezmoi init`), then `chezmoi apply` to re-render
  `~/.config/dotfiles/elevation.sh`.

## Auditability note

The elevation runs through the same policy that the Self Service GUI
button invokes, so it shows up in Jamf's policy logs the same way. If your
IT team monitors Self Service usage, programmatic invocations are
indistinguishable from a manual click.
