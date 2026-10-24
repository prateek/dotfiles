---
status: current
doc_type: runbook
summary: "Install and update the portable Firefox Sage theme and Sidebery preferences without migrating browsing data."
created: 2026-10-23
updated: 2026-10-23
related:
  - ../references/chezmoi-architecture.md
---

# Firefox Sage setup

The `personal-apps` package group installs Firefox on personal Macs. Chezmoi
stages [the portable configuration](../../home/dot_config/firefox) at
`~/.config/firefox`; its after-install hook runs
[`scripts/firefox/install-settings`](../../scripts/firefox/install-settings).
Work and headless machines do not receive this configuration.

## What travels

- Sage colors, typography, folder disclosures, selection/focus styles, the
  icon-only spaces bar, group-page styling, and the resize handle.
- Manual sidebar animation, including rapid reversal and Reduce Motion support.
- Selected Firefox behavior and privacy preferences, including telemetry and
  studies disabled and the bookmarks toolbar hidden.
- A Sidebery settings-only import and the names/official links of the extensions
  used with the setup.

Tabs, folders, spaces and their names/icons, bookmarks, history, cookies,
passwords, containers, extension storage, snapshots, sync identities, and site
permissions stay local. The Sidebery export has only `ver` and `settings` keys.
Fresh Sidebery installations start with their default empty tab panel; the CSS
does not depend on panel IDs or Firefox's generated extension UUID.

The custom macOS Dock/app icon is not managed by this bundle. It is separate
from the browser theme. Extension account setup, preferences in other
extensions, and userscripts also remain separate.

## Install

From a checkout selected as the chezmoi source:

```sh
chezmoi diff
chezmoi apply --dry-run --verbose
chezmoi apply
```

Quit Firefox before applying changes. Read-only previews and unchanged installs
work while Firefox is open; an actual write defers until it is closed. The hook
warns and continues the rest of apply when a download is unavailable, Firefox is
running, or configuration needs attention (an ambiguous profile, unmanaged
loader/theme, local edit, symlinked destination, or unwritable bundle). Integrity
failures and unexpected installation errors still fail apply. Resolve the
reported issue and rerun.

The installer uses the unambiguous registered default profile, or creates an
empty `Sage` profile when none are registered. It never changes the default
browser or guesses between ambiguous profiles.

The theme is fetched from the exact upstream revision in
[`ultima.lock.json`](../../home/dot_config/firefox/ultima.lock.json), checked
against its SHA-256, and cached under
`${XDG_CACHE_HOME:-~/.cache}/dotfiles/firefox`. Firefox itself remains on its
normal security-update channel.

FF Ultima's JavaScript loader requires two files in
`Firefox.app/Contents/Resources`: `config.js` and
`defaults/pref/config-prefs.js`. The installer removes upstream's two directives
that disable extension signature and install-origin checks, and refuses unknown
variants of those directives. It records loader ownership in
`Contents/Resources/dotfiles-ultima.json`, so later updates can replace unchanged
managed loaders. A different unmanaged loader requires explicit adoption.

An unwritable app bundle is left untouched; the installer never requests sudo
or changes app ownership. A Firefox update can remove the loader and receipt;
another apply restores them while Firefox is closed. See
[upstream's userChromeJS setup](https://github.com/soulhotel/FF-ULTIMA/blob/32e1aa1bdd2dddd14939d8c21edba917e73b1b8a/userchromejs/readme.md).

### First launch

1. Launch Firefox from Applications after apply finishes.
2. If macOS rejects the modified app as damaged, reinstall Firefox and launch it
   **before rerunning apply** to complete its normal first-launch approval. Do
   not strip quarantine or re-sign the app. Adding loader files to a newly
   downloaded, quarantined bundle remains an attended qualification check.
3. If the installer created Sage, choose **Sage** in Firefox's profile chooser
   and enable **Use the selected profile without asking at startup**. Firefox
   then owns its installation-specific default selection. This explicit choice
   avoids relying on automatic adoption of an empty legacy profile, which
   [Mozilla's profile-selection implementation](https://github.com/mozilla-firefox/firefox/blob/774fa0cf68ccf50e8da30f50e71714abdc4686b5/toolkit/profile/nsToolkitProfileService.cpp#L1802-L1855)
   skips. The actual first chooser interaction on a new Mac still needs an
   attended check.
4. If you reinstalled Firefox in step 2, quit it, rerun `chezmoi apply` to restore
   the loader, and reopen Firefox.

### Finish in Firefox

1. Install [Sidebery](https://addons.mozilla.org/firefox/addon/sidebery/) and
   [userChrome Companion](https://addons.mozilla.org/firefox/addon/userchrome-companion/)
   from Mozilla Add-ons. The remaining extension links are in
   `~/.config/firefox/extensions.json`.
2. In Sidebery Settings → General → Permissions, enable **Hiding tabs** and,
   if wanted, **Bookmarks**. Grant tab hiding here before importing: Sidebery
   5.6.1's import-dialog permission button also requests web/proxy permissions
   that this setup does not use. The individual Hiding tabs control requests
   only tab hiding.
3. In Sidebery Settings → Help → Import addon data, select
   `~/.config/firefox/sidebery-settings.json`. In the macOS file picker, use
   Command-Shift-G to enter the path. Only Settings is present; there are no
   panels, containers, snapshots, or favicons to import. This replaces Sidebery's
   preferences with the supplied defaults, so use it on a fresh installation or
   review it before importing into an already customized Sidebery.
4. Add its Bookmarks panel from Sidebery settings if missing. Open
   Sidebery with Firefox's sidebar control, and drag the divider to the desired
   width. The native horizontal tabs remain available until Sidebery is enabled.

Permissions and extension installation use Firefox's native UI. Dotfiles do
not seed IndexedDB, extension UUID mappings, signed-in accounts, or permission
databases. Sidebery's [versioned export/import implementation](https://github.com/mbnuqw/sidebery/blob/v5.6.1/src/page.setup/components/popup.export-config.vue)
defines the settings-only format.

## Existing themes and multiple profiles

The installer refuses to replace an existing unmanaged theme implicitly. From
the checkout, preview adoption with the intended profile selected explicitly:

```sh
scripts/firefox/install-settings --profile '/path/to/profile' --adopt-theme --dry-run
scripts/firefox/install-settings --profile '/path/to/profile' --adopt-theme
```

The archive must already be cached for a file-level dry run; `--archive` accepts
a downloaded copy and still checks its pinned SHA-256. Use `--source
home/dot_config/firefox` when testing this checkout before its staged config has
been applied. An explicit profile must already exist. When multiple Firefox
installations have different defaults, use `--profile` for each intentional
manual install; the automatic hook continues to warn until the default is
unambiguous.

The preview lists every planned create, replace, and delete, including loader
files in the application bundle. It also lists unmanaged `*.ffu.js` scripts:
these are preserved and remain executable by the loader, so review them before
adoption.

Adoption backs up and replaces conflicting theme **and app loader** files. It
merges a marked block into `user.js`, preserving other text. A matching old
standalone sidebar-motion script is retired; a locally edited copy stops
adoption until you reconcile it. Sidebery settings and browsing state are not
imported. Subsequent applies preserve local edits to managed files; reconcile
those edits into source or preview explicit adoption.

An interrupted install can be rerun with the same source and arguments. The
profile is registered before theme files are written, and already-written files
that match the intended bytes are accepted on retry. An incomplete update is
resumed, not rolled back automatically; keep Firefox closed until it finishes.

Backups contain only replaced configuration files and a path manifest, under
`${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/firefox-settings/`. To restore,
quit Firefox, use the manifest to copy the saved files back, and reconcile the
dotfiles source before applying again. Keep that directory private.

## Change and validate

Edit the source under `home/dot_config/firefox`, then preview and apply through
chezmoi. Theme changes take effect after restarting Firefox. Changes to the
Sidebery settings file require another native import; the installer does not
overwrite live extension settings. To update FF Ultima, review the upstream
revision, update its URL/revision/checksum together, and qualify a disposable
profile before applying to the daily browser.

```sh
just test-python -p test_firefox.py
just test-shell tests/bats/hooks/firefox-settings.bats
just test-docs-lifecycle
git diff --check
```

The fixture suite checks empty-profile installation, repeat applies,
preservation of browsing files and local preferences, private backups, active
profile locks, interrupted installs, loader upgrades/adoption, actionable
previews, download deferral/retry, security-filter failures, symlinked
destinations, and machine gates.
The hook suite checks that configuration conflicts defer while unexpected
failures stop apply. These checks do not replace an actual first-run extension
installation/import check. Local qualification used a disposable,
headless Firefox 158.0.1 profile with signed Sidebery 5.6.1 and Companion 1.25.
It verified the native settings-file import, a newly generated extension UUID,
theme colors, the group-page typography, tab-bar fallback, loaded motion wrapper,
and effective reporting/signature preferences. The individual tab-hiding grant
left web/proxy permissions absent. Fresh-machine checks are listed under
First launch; future Firefox UI changes also need runtime qualification.
