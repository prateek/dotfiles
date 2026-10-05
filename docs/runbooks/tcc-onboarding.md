---
status: active
doc_type: runbook
created: 2026-10-05
updated: 2026-10-05
related:
  - ../plans/tcc-onboarding-plan.md
  - ../adr/0044-tcc-onboarding.md
status_detail: "Source implementation and automated checks; attended native grant flow remains unverified."
---

# macOS permission onboarding

Dotfiles Permissions compares declared access with read-only TCC records and
checks whether stored code requirements still match installed apps. The user
changes grants in System Settings. This feature is disabled on every machine
until explicitly enabled.

## Enable and open

Review [the manifest](../../home/.chezmoidata/tcc.toml) first. Add this to the
existing chezmoi configuration file under its machine-local feature overrides:

```toml
[data.machines_local]
tcc_onboarding = true
```

Alternatively set the feature in the appropriate committed host layer of
`home/.chezmoidata/machines.toml`. Preserve any other local feature overrides.

Preview with `chezmoi diff` and `chezmoi apply --dry-run --verbose`, then apply
when ready. The enabled hook builds `~/Applications/Dotfiles Permissions.app`
and validates `~/.config/dotfiles/tcc.json`. An interactive console-user apply
asks `Review macOS app permissions now? [y/N]`. No is the default. The question
appears on each enabled interactive apply, before any permission scan.

Yes opens a reconciliation scan through LaunchServices. All recorded grants
matching the installed identities means the helper exits without a window.
Otherwise it shows unresolved entries. Apply returns after launch; Later or
closing the helper leaves unresolved grants for the next review.

SSH, CI, non-console-user, and noninteractive applies print a resume command
without prompting or launching the GUI. Build or manifest errors fail the
hook; missing grants and GUI launch failures do not. Dry runs execute no hook.

Open the installed app manually to see the full inventory:

```sh
open -a "$HOME/Applications/Dotfiles Permissions.app"
```

The app is installed only by an enabled apply, or explicitly with
`scripts/macos/install-tcc-onboarding`. Disabling the feature stops apply-time
onboarding and leaves the existing app and grants in place.

## Grant and refresh

If the databases are unreadable, the first step offers the helper itself as a
Full Disk Access drag tile. Grant access and use **Relaunch helper** if needed.
The helper's launch context matters: terminal or SSH access to a database does
not establish that the GUI app can read it.

Each permission group shows the exact resolved subject and its reason. Opening
Settings displays a small floating companion panel near the lower right of the
screen, with a draggable app icon for Accessibility, Input Monitoring, or Full
Disk Access. **All permissions** returns to the inventory; **Reveal in Finder**
is available as a fallback. The panel can be moved to keep the Settings list
clear. These native interactions await attended validation.

Screen Recording currently opens its Settings pane with guidance; its drag
instruction is withheld pending native validation. Microphone and Camera need
the target app to request access. Open the app and use the relevant feature,
then return to review. Automation, Files & Folders, and other services are
outside this initial reader's service table.

The helper refreshes when activated and every five seconds while visible, with
at most one scan running. A scan opens each database once and closes it afterward.
No data-access grant is requested through another app's identity.

## Interpret the result

| Result | Meaning and next step |
| --- | --- |
| Allowed in macOS | A recorded allow matches the installed code requirement. Restart the target if it has not adopted a change. |
| Not allowed | A recorded denial; review the permission in Settings. |
| Needs reauthorization | The app has a valid signature but fails the stored code requirement. Remove and re-add the exact app where Settings permits, then relaunch it. |
| Needs review | Absent/unreadable/unsupported/conflicting evidence, or a code signature that cannot be verified. Expand Details. |
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

The current installer requires a compatible Swift toolchain and macOS SDK on
the target host. Toolchain-free installation through published releases is
deferred to the [standalone-tool follow-up](../plans/tcc-onboarding-plan.md#future-follow-up-standalone-tool-and-releases).

The installer hashes app sources and toolchain inputs. Unchanged applies reuse
the signed bundle, and manifest edits do not rebuild it. A changed app is staged
and signature-checked before replacement. If the helper is open, the update is
deferred: close it and rerun apply. Concurrent installs also defer.

Local builds use ad-hoc signing. A new build can require Full Disk Access again;
a stable bundle ID alone does not promise grant retention. Reauthorization is
part of the attended checklist below. An interrupted installer can leave
`~/.cache/dotfiles/tcc-onboarding/install.lock` (under `XDG_CACHE_HOME` when set).
Remove that empty directory only after confirming no install is running.

## Audit the remaining machines

The read-only auditor exports normalized observations and installed bundle
paths. It omits raw rows, code requirement blobs, and Automation target identity.
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

1. Enable the feature and verify the terminal no/yes flow through a real apply.
2. Grant the helper Full Disk Access through its tile. Relaunch and confirm it
   reads both databases independently of terminal permissions.
3. For each supported drag service, drop a target, enable its entry, and confirm
   refresh. Check that the panel remains accessible while Settings has focus.
4. Confirm missing, duplicate, denied, and stale targets are explained correctly.
   Verify stale-grant removal/re-add recovery for the service being tested.
5. Choose Later, reopen, and complete the remaining grant. Manual launches,
   including opening the manifest file, must show the inventory even when it
   is reconciled. A repeat apply may ask in the terminal, but after yes a
   reconciled inventory opens no window.
6. Revoke a grant and verify a new scan notices it. Rebuild the helper and check
   whether its own access needs reauthorization. An unchanged build preserves it.
7. Validate Screen Recording's manual flow before enabling a drag instruction.
   Verify Microphone/Camera requests originate in the target app.

Attended E2E is explicitly pending. Do not treat fixture success or a signed
build as evidence that Settings accepted a drag or that a grant survived rebuild.
