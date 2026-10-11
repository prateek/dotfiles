---
status: current
doc_type: runbook
created: 2026-10-03
updated: 2026-10-11
related:
  - ../plans/g95nc-diagnostics-plan.md
  - ../plans/g95nc-complete-modes-plan.md
---

# G95NC Display Command

The command owns BetterDisplay's app configuration. Chezmoi installs the command
but leaves the app preference plist unmanaged. Raycast and the CLI expose these
modes:

| Command | Result |
| --- | --- |
| `g95nc sharp` (also `g95nc set`) | 4864x1368 HiDPI desktop, mirrored onto a native 7680x2160 SDR RGB/4:4:4 output at approximately 60 Hz. |
| `g95nc butter` | 4608x1296 HiDPI desktop, mirrored onto the same native output at approximately 120 Hz. |
| `g95nc reset` | Remove **all** BetterDisplay preferences and virtual screens, restart the app, restore factory EDID where readable, and select 3840x1080 HiDPI at 120 Hz on the Odyssey (advertised defaults on other displays). |
| `g95nc check` | Read current display state without changing it. |

`g95nc sharp 4096x1152` overrides the Sharp desktop size; width snaps to the
nearest 32-pixel step at 32:9. `set [WxH]` remains an alias. Butter has a fixed
size and refresh rate.

## Reset

Reset exports the entire preference domain to a private backup while the app is
stopped, then deletes `pro.betterdisplay.BetterDisplay` and relaunches. This is
[BetterDisplay's documented app reset](https://betterdisplay.pro/guide/faq/general/reset-app-settings/).
It clears menu/hotkey settings, remembered display preferences, over-8K support,
virtual-screen refresh settings, and every virtual screen, regardless of name
or identity. Reset works when the G95NC is disconnected or BetterDisplay was
not running; it does not require the old CLI configuration to be responsive.

After restart, the command verifies that no virtual screens remain. Where hardware
EDID is readable, it compares the OS EDID, restores the factory EDID if different,
and verifies the result. Factory EDID must be readable for the Odyssey.
It selects **3840x1080 HiDPI at approximately 120 Hz** on the Odyssey, sets it as
main, and verifies resolution, HiDPI, refresh and mirroring off. An unavailable
mode is an explicit failure after preference cleanup. Other online physical
displays use their advertised `Default` modes.

This reset desktop renders at 7680x2160 but can still travel over a 3840x1080
physical signal on the USB-C-to-HDMI connection. Reset reports that signal; it
does not require native output as Sharp and Butter do. Repeating reset converges
to the same baseline; restarting and fresh app-generated discovery records may
occur on each run.

Backups live under `${XDG_STATE_HOME:-$HOME/.local/state}/g95nc/backups/`, with
mode 0600. A failed export prevents deletion. Backups are retained independently
of diagnostic log rotation and their contents are never copied into the log.
They may contain private preferences; keep them local. To restore one, quit
BetterDisplay, run `defaults import pro.betterdisplay.BetterDisplay /path/to/backup.plist`,
then reopen the app. This also restores the old virtual-screen configuration.

This is an app reset. It does not factory-reset monitor firmware, erase Keychain
items, or remove custom display overrides installed in macOS. The command does
not install those overrides. BetterDisplay documents its broader macOS display
system reset separately; that operation can require a reboot.

## Sharp and Butter

Setup needs `betterdisplaycli`, `python3`, and one online physical display whose
name contains `Odyssey`. It starts BetterDisplay if needed. Before changing
preferences or displays, it requires an advertised native 7680x2160 SDR
RGB/4:4:4 output at the requested refresh and a 3840x1080 HiDPI seed mode.
An unsupported cable, adapter, or input configuration produces an actionable
failure before setup changes. A large rendered framebuffer is not evidence of
a native-resolution signal to the monitor.

Setup enables over-8K framebuffers and the menu-bar icon, restarting BetterDisplay
only when those preferences need changing. It selects an SDR HiDPI seed and,
when needed, a compatible full-chroma connection mode. It uses a virtual screen named
`G95-HiDPI`, vendor `2198`, model `9057`, serial `90570057`. Duplicate managed
identities abort before mutation; rebuilding discards this identity by its exact
BetterDisplay tag. Other virtual screens survive successful setup, but **reset
and failure recovery remove all of them**.

Sharp renders a 9728x2736 framebuffer. Butter renders 9216x2592 and configures its
virtual screen with custom refresh rates `[60,120]`. Butter starts both screens
at the native HiDPI seed, establishes mirroring, then grows through 4096x1152 and
4480x1260 to 4608x1296. Direct jumps previously left the physical desktop at 60 Hz.
Mode numbers are read from the current advertised list, not persisted across
connections or restarts.

Verification checks virtual size, HiDPI, main-display and mirror state; physical
HiDPI and mirror state; both refresh rates; the actual connection mode; and
macOS mirror roles, framebuffer dimensions, and refresh. A tolerance of 0.2 Hz
accepts 59.94/59.97 and 119.88 Hz without accepting 60 Hz for Butter. macOS supplies
the mirror framebuffer dimensions because the physical CLI resolution getter can
retain the seed size. The separate `connectionMode` check prevents a high-resolution
framebuffer downscaled into a low-resolution output from passing verification.

A correct repeated setup does not rebuild the virtual screen or switch display
modes. A failed or interrupted setup attempts the full app reset. Failed setup
still returns failure even when recovery succeeds. These checks verify configured
timing; smooth motion and unique delivered frames still require a human test.

Automatic unplug association remains a BetterDisplay GUI setting, not part of
this command's presets. Internal preferences were originally verified on 5.0.6;
5.1.1 supplies the current mode-list and connection-mode syntax. App upgrades
still require runtime verification.

## Logs and Diagnostics

Each run prints a log path under `${XDG_STATE_HOME:-$HOME/.local/state}/g95nc/`.
Logs contain timestamps, arguments, host/app versions, command output, exit
status, display snapshots, and recovery results. The private directory retains
the latest 30 logs. Review display identifiers before sharing logs.

A `lock/` directory prevents overlapping runs. After a forcibly killed run,
verify that `lock/pid` has exited before removing the lock directory. Normal
exit removes it. CLI calls time out after 10 seconds; verification polls at most
10 times with one second between attempts. `G95_COMMAND_TIMEOUT` and
`G95_POLL_ATTEMPTS` override these positive integer limits.

`G95_MATCH`, `G95_VS_NAME`, `G95_VS_SERIAL`, and `G95_VS_MODEL` override the physical
name match and setup's virtual identity. `BD_CLI` selects the CLI executable.
These identity overrides do not narrow the scope of reset.

## Validation

Run `just test-python -p test_g95nc.py` for command-boundary regression tests and
`shellcheck home/dot_config/raycast/scripts/executable_g95nc.sh` for shell checks.
The fixtures substitute external applications; they cannot prove actual panel
output. On a supported connection, exercise reset twice, Sharp twice, Butter
twice, and transitions between all three, checking both CLI and macOS state.
On an unsupported connection, validate preflight refusal and reset without
claiming successful Sharp or Butter hardware acceptance.
