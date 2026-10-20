---
status: active
doc_type: runbook
summary: "The dotfiles-permissions CLI, apply-time audit that fails without helper access, the guided window, stale-grant recovery, and pending attended validation."
created: 2026-10-05
updated: 2026-10-20
related:
  - ../plans/tcc-onboarding-plan.md
  - ../adr/0057-tcc-helper-cli-owns-access.md
status_detail: "Source implementation and automated checks; attended native grant flow remains unverified."
---

# macOS permission onboarding

Dotfiles Permissions compares declared access with read-only TCC records and
checks whether stored code requirements still match installed apps. The user
changes grants in System Settings. Read-only auditing defaults on for personal,
work, and homelab Macs; CI and devbox roles remain disabled. Host and local
`tcc_onboarding` overrides still take precedence.
[ADR 0057](../adr/0057-tcc-helper-cli-owns-access.md) records the design.

## The CLI

An enabled apply builds or reuses `~/Applications/Dotfiles Permissions.app` and
links `~/.local/bin/dotfiles-permissions` to its executable. The CLI is the
interface for scripts, agents, and apply; the window is an optional guided view.

```sh
dotfiles-permissions doctor             # helper, manifest, and the helper's own TCC access
dotfiles-permissions audit              # grants needing attention; quiet when all match
dotfiles-permissions grants list --app orca
dotfiles-permissions apps list          # which installed copy each manifest app resolves to
dotfiles-permissions manifest validate
dotfiles-permissions settings open fullDiskAccess
dotfiles-permissions gui                # open the guided review window
```

Every command accepts `--json`, which prints one JSON object on stdout and
nothing else. Errors under `--json` are `{"error": {"code", "message", ...}}`
with codes `usage`, `manifest_invalid`, `tcc_unreadable`, `unknown_app`,
`settings_unavailable`, and `gui_unavailable`. `audit` and `grants list`
return a `summary` of state counts and a `grants` array of
`{app, name, service, reason, state, detail, path, client}`; `audit` lists only
grants that need attention and adds `gui_command`. `doctor` returns `ok`,
`version`, `bundle`, `responsibility`, `manifest`, `databases`, and `next_steps`.

Exit statuses: 0 success; 2 `audit` found known deviations; 3 `audit` evidence
is inconclusive, including mixed known and unknown results; 64 usage error;
65 invalid or unreadable manifest; 70 other failure; 77 the helper cannot read
the TCC databases.

The manifest is `$XDG_CONFIG_HOME/dotfiles/tcc.json`, defaulting to
`~/.config/dotfiles/tcc.json`, which chezmoi renders from
[the catalogue](../../home/.chezmoidata/tcc.toml). `--manifest PATH` reads another
file for one command. The window always reads the default path and takes no
launch arguments. GUI launches see only the launchd environment, which does not
set `XDG_CONFIG_HOME` here, so the window falls back to `~/.config`; that matches
the shell's value. Export the variable to launchd too before moving it.

## Whose access is checked

`doctor`, `audit`, and `grants list` re-execute the helper as its own
responsible process before reading TCC. TCC therefore evaluates the helper's
Full Disk Access grant, not the terminal's: a terminal with Full Disk Access
does not mask a helper without it. `doctor` reports `responsibility: helper`
when this worked. The GUI uses the same grant, so one grant serves both.

## Apply

Review the catalogue, then preview with `chezmoi diff` and
`chezmoi apply --dry-run --verbose`. Dry runs do not build or read TCC. An
enabled apply runs `audit`. It never prompts, launches the GUI, or changes
grants, and SSH and noninteractive applies take the same path.

- Matching installed expectations produce no output. Uninstalled apps are not
  deviations, and no installed targets is not proof that any grant exists.
- Deviations (2) and inconclusive evidence (3) print the CLI report, including
  the `gui` command, and apply continues.
- An unreadable TCC database (77) fails apply with grant instructions. The hook
  runs last so the failure skips no other apply hook. Grant
  the helper Full Disk Access as in [Grant and refresh](#grant-and-refresh) and
  rerun apply. After a helper rebuild an existing entry no longer matches; remove
  it with − and add the app again.
- An invalid manifest (65), a failed build, a missing Swift toolchain, or any
  other audit failure fails apply.
- A deferred update (the window is open) audits with the verified installed
  helper. An installed helper that predates the CLI is never sent commands; the
  hook warns and skips the audit until the update lands. An install lock warns
  and asks for a retry.

To disable apply-time auditing while preserving the installed app and grants,
set this in the existing local feature overrides:

```toml
[data.machines_local]
tcc_onboarding = false
```

Disabling the feature stops managing the CLI symlink, manifest, and hook;
chezmoi leaves the existing files, app, and grants in place.
The app is installed only by an enabled apply, or explicitly with
`scripts/macos/install-tcc-onboarding`.

## Grant and refresh

If the databases are unreadable, the first step offers the helper itself as a
Full Disk Access drag tile. Target tasks are withheld until permission records
are readable. Grant access and use **Relaunch Helper** if needed.
The CLI checks the same grant, so `dotfiles-permissions doctor` confirms it
from a terminal or SSH session.

The app uses a compact window with a transparent, hidden title bar and no
status strip. It defaults to **By permission**, so Accessibility tasks can be
completed before switching Settings panes. More → View also offers
**By app**, **Drag shelf**, larger text, the full inventory, and an optional
menu bar icon. View shortcuts ⌘1/2/3 change presentation; ⌘R rechecks, ⇧⌘A shows
all permissions, and ⌘] advances. One row expands into its reason, recovery
steps, exact subject, and evidence. Selection survives rechecks and grouping
changes, including after the last grant matches.

Use More → Keep above Settings to keep this window beside Settings. Drag the entire file
tile into a supported permission list. **File Details…** offers **Copy Path**,
**Show in Finder**, and the add-button/⌘⇧G keyboard alternative for that exact
subject. The drag shelf collects eligible files for the same Settings pane.
Closing or minimizing the window stops polling; closing preserves the session.
Use the Dock, ⌘Tab, View → Open, or the optional menu bar icon to return.

Stale-grant recovery stays inline, with service-appropriate removal, re-add,
and restart instructions. Bootstrap offers **Relaunch**. App-owned requests
without a recorded decision offer **Open app**: use the relevant feature, then
return and recheck. Microphone, Camera, and Screen Recording offer no drag
instruction. A recorded denial, mismatch, or uncertainty offers Settings first.
Automation, Files & Folders, and other services remain outside the service table.

**Later** defers a task for this session without changing its grant. Deferring
all remaining tasks pauses the review; **Resume** brings them back. A matching
final task stays visible until **Summary** is chosen. Only More remains in the header; manual Recheck is in that menu (⌘R); Next and Summary live in the
active card, Resume sits beside the paused review, and Relaunch beside bootstrap
instructions; the last-check timestamp is in **Evidence**.
Settings-opening errors remain visible in the working window.

The helper refreshes when activated and every five seconds while visible, with
at most one scan running. A scan opens each database once and closes it afterward.
No data-access grant is requested through another app's identity.

## Interpret the result

| Result | Meaning and next step |
| --- | --- |
| Recorded allow | A recorded allow matches the installed code requirement. Restart the target if it has not adopted a change. |
| Not allowed | A recorded denial; review the permission in Settings. |
| Identity changed | The app has a valid signature but fails the stored code requirement. Remove and re-add the exact app where Settings permits, then relaunch it. |
| Needs a grant | No recorded decision for the resolved subject and permission. Follow the service-specific action. |
| Cannot check | Unreadable/unsupported/conflicting evidence, ambiguous copies, or unverifiable code. Expand Evidence; do not infer a stale grant. |
| Not installed | No matching bundle or helper exists; it does not trigger onboarding. |

Both user and system databases must be readable for a conclusive grant. The
reader does not prefer an allowed row over conflicting evidence. It supports
the observed `auth_value`/`csreq` schema; only `auth_value = 2` with a matching
requirement is allowed. Missing or malformed requirements stay unresolved.

Multiple installed copies require **Choose app** or an explicit `path` in the
manifest. Interactive selection lasts only for that app session. A `helper_path`
relative to the bundle identifies a separate executable client and drag target;
paths resolving outside the owning bundle are rejected.

Recorded state is not a runtime test of the target app. A matching signature
cannot rule out process caches or policy overrides. The helper never resets
permissions, writes TCC, or toggles Settings controls automatically.

## Updates

Building or updating requires a compatible Swift toolchain and macOS SDK.
Without Swift, the installer reuses an existing bundle only if its identity and
signature verify, with a warning that it was not updated. If none is usable, the
enabled hook fails apply.
Toolchain-free installation through published releases is
deferred to the [standalone-tool follow-up](../plans/tcc-onboarding-plan.md#future-follow-up-standalone-tool-registry-and-launch).

The installer hashes app sources and toolchain inputs. Unchanged applies reuse
the signed bundle, and manifest edits do not rebuild it. A changed app is staged
and signature-checked before replacement. If the helper is open, the update is
deferred: quit the app (⌘Q) and rerun apply. Closing its window keeps the
process alive. CLI runs of the same binary never defer an update. The enabled
hook can still audit a verified existing bundle that advertises CLI support
(`DotfilesPermissionsCLIVersion` 2) while the update is deferred. An older
bundle is skipped with a warning until it is updated. A concurrent installer
advises retrying; quitting the helper does not resolve an install lock.

The installer signs with a per-machine self-signed identity, "Dotfiles
Permissions Code Signing", kept in `~/Library/Keychains/dotfiles-codesign.keychain-db`.
It creates the identity once, unlocks that keychain itself with the random
password in `$XDG_STATE_HOME/dotfiles/codesign/keychain-password` (mode 0600),
and adds the keychain to the user search list, because `codesign` finds
identities only there. Nothing prompts, including over SSH. The helper's
designated requirement is `identifier "com.prateek.DotfilesPermissions" and
certificate leaf = H"…"`, so its Full Disk Access grant survives rebuilds.

Any process running as you can read that password and sign as the helper, so
the grant is protected about as well as your user account. `security` accepts
passwords only as arguments, so the password is briefly visible to `ps` while
the installer creates or unlocks the keychain. That happens only when the
helper is rebuilt; unchanged applies read the certificate without unlocking.
The installer never rewrites the keychain search list from an empty read. Replacing the
identity (deleting the keychain or losing the password file) changes the
requirement: the installer refuses to sign without the password, and after
recreating the keychain the grant must be removed and re-added once. The first
build after moving from ad-hoc signing needs the same one-time re-grant.

The install lock, `$XDG_CACHE_HOME/dotfiles/tcc-onboarding/install.lock`, is a
symlink to its owner's PID, created atomically. A lock whose owner is no longer
running, or a directory lock from an earlier installer, is removed with a
warning, so an interrupted install never blocks later updates.

## Audit the remaining machines

The read-only auditor exports normalized observations and installed bundle
paths: everything under the Applications folders plus every copy LaunchServices
registers for each observed bundle client, the same candidates the helper resolves. It omits raw rows, code requirement blobs, and Automation target identity.
Captures are private mode 0600 files outside the public repo:

```sh
scripts/macos/audit-tcc --output \
  "$HOME/.local/state/dotfiles/captures/tcc/$(date +%F)-this-mac.json"
```

For a trusted SSH alias, run the script through standard input and save the
result locally without installing anything remotely:

```sh
umask 077
ssh -o BatchMode=yes TRUSTED_ALIAS 'python3 - --output -' \
  < scripts/macos/audit-tcc > /private/tmp/tcc-remote-audit.json
```

The command reports inaccessible databases explicitly. Inspect the capture
before promoting observations into `tcc.toml`. An existing grant can be obsolete;
recorded denial is not a request to grant access. Keep employer-specific subjects
in the work overlay, not this public catalogue.

Initial evidence on October 5, 2026:

- This Mac: user and system databases readable; 102 and 32 normalized observations.
  Nine installed apps supply the initial 18 expected grants for supported services.
  The private capture is `~/.local/state/dotfiles/captures/tcc/2026-10-05-personal-mbp.json`.
  This audit inspected recorded state; it did not validate every stored signature.
- Mini: `m4mini` timed out; `m4mini.local` failed host-key verification. Audit pending
  a trusted reachable alias. No SSH trust settings or remote configuration changed.
- Work Mac: deferred as requested. No connection attempted.

KeyPath's observed Full Disk Access denial was not adopted as an expectation.
The catalogue is an audit baseline, not an exhaustive list of app requirements.

## Validation and attended checklist

Automated commands are in the [tests index](../../tests/README.md#permission-onboarding).
They cover the native reader, real code-signing comparisons, app resolution,
rendering, and terminal/installer behavior. Build artifacts stay under ignored
`build/`; tests neither query live TCC nor drive Settings.

When the user is available, start in a disposable Mac VM and record its macOS
version and app identities:

1. Verify an enabled apply audits without a terminal prompt or GUI activation.
   Matching installed expectations must produce no audit output; deviations and
   unknown evidence must print reasons and the `gui` command. Run
   `dotfiles-permissions gui` and confirm the inventory opens.
2. Before the helper has access, confirm apply fails with exit 77 even from a
   terminal that has Full Disk Access. Grant the helper Full Disk Access through
   its tile, then confirm `doctor` and the relaunched window read both databases.
3. For each supported drag service, drop a target, enable its entry, and confirm
   refresh. Check that the checklist remains accessible while Settings has focus.
4. Confirm missing, duplicate, denied, and stale targets are explained correctly.
   Verify stale-grant removal/re-add recovery for the service being tested.
5. Choose Later, reopen, and complete the remaining grant. Manual launches
   must show the inventory even when it is reconciled. A repeat apply with matching installed expectations must be
   quiet and leave the helper's window state unchanged.
6. Revoke a grant and verify a new scan notices it. Rebuild the helper and
   confirm apply fails until its grant is re-added. An unchanged build preserves it.
7. Validate Screen Recording's manual flow before enabling a drag instruction.
   Verify Microphone/Camera requests originate in the target app.
8. Verify Dock/Cmd-Tab, menus, minimize/close, saved window placement, and
   switching between Settings and unrelated apps. Confirm there is only one
   helper window; pinning is explicit and unpinning returns its level to normal, and errors
   and required actions remain visible while scrolling.
9. Review light/dark appearance, Increase Contrast, Full Keyboard Access, and
   VoiceOver. Verify exact app/helper targets using the keyboard fallback,
   stable focus through refresh, and one announcement per meaningful change.
   Check minimum-size windows, long names, and long helper paths.

Attended E2E is explicitly pending. Do not treat fixture success or a signed
build as evidence that Settings accepted a drag or that a grant survived rebuild.
