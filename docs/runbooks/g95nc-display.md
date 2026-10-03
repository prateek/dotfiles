---
status: current
doc_type: runbook
created: 2026-10-03
related:
  - ../plans/g95nc-diagnostics-plan.md
---

# G95NC Display Command

Run `g95nc check` for read-only display diagnostics, `g95nc set` for a
4864x1368 HiDPI virtual desktop mirrored at 60 Hz, `g95nc butter` for
4608x1296 HiDPI at 120 Hz, or `g95nc reset` to remove
the managed virtual screen and restore the connected panel to 3840x1080 HiDPI
at 60 Hz. Raycast offers the same commands. `g95nc set 4096x1152` overrides
the logical resolution; width snaps to the nearest 32-pixel step at 32:9.

BetterDisplay must be running, with CLI integration enabled. The command needs
`betterdisplaycli` and `python3`. Setup requires one online physical display
matching `Odyssey`. A disconnected panel is allowed for reset.

For a target exceeding 7680x4320 framebuffer dimensions, setup checks the global
`enable16K` preference. If absent or disabled, it quits BetterDisplay, waits for
exit, writes the preference with `defaults`, relaunches the app, and waits for
its CLI. This preference is an internal BetterDisplay setting verified on 5.0.6;
CLI and macOS framebuffer verification remain necessary after an app upgrade.

Butter uses 90% of 5120x1440 at 32:9 (4608x1296), with a 9216x2592
HiDPI framebuffer. Sharp uses 95% (4864x1368). Butter enables the owned virtual
screen's custom refresh rates using the internal BetterDisplay 5.0.6 preferences
`useCustomRefreshRates@VirtualScreen:<tag>` and `refreshRates@VirtualScreen:<tag>`.
The latter must be a JSON string, `[60,120]`. Applying butter restarts BetterDisplay
when rebuilding the virtual screen, so other BetterDisplay virtual screens may
briefly disconnect during that restart.

Butter selects exact advertised HiDPI 120 Hz mode numbers afresh. It starts both
displays at 3840x1080, establishes mirroring, selects the physical 120 Hz mode
again, then grows through 4096x1152 and 4480x1260 to 4608x1296. A direct jump to
the final size left the physical desktop at 60 Hz in local testing. Setup verifies
both displays' refresh rates and framebuffer dimensions through macOS
`system_profiler`, as well as their BetterDisplay state. The physical CLI
resolution getter can retain the native seed size while macOS correctly reports
the enlarged mirror, so macOS dimensions are authoritative. These checks establish
configured refresh; smooth motion and unique delivered frames still require an
end-user test. TestUFO stutter while moving the pointer over its page also occurred
at smaller and native resolutions during local testing.

Cleanup matches the virtual screen's name, vendor, model, and serial and discards
it by its exact BetterDisplay tag ID. Connected display operations use its UUID. Other virtual screens survive. Duplicate identities abort the command.
Failed setup attempts a native HiDPI reset and returns failure even if recovery
succeeds. Interrupted setup also attempts recovery. Repeating setup skips rebuilding
when resolution, HiDPI, refresh, mirroring, main-display status, and macOS framebuffer
verification already match.

Configure the virtual screen's association with the physical display in
BetterDisplay's virtual-screen settings for automatic disconnect on unplug.
The command does not establish that GUI-owned association.

## Logs and Recovery

Every run prints its log path under `${XDG_STATE_HOME:-$HOME/.local/state}/g95nc/`.
Logs contain UTC timestamps, arguments, host and software versions, command output,
errors, exit status, elapsed time, display snapshots, and recovery results.
The directory is private and the command retains the latest 30 logs.

A `lock/` directory prevents overlapping runs. If a run was forcibly killed,
inspect `lock/pid` and verify that process has exited before removing `lock/`.
A normal exit removes the lock. Logs and snapshots contain display identifiers;
review them before sharing.

CLI calls time out after 10 seconds. Verification polls at most 10 times, one
second apart, with each call bounded by the CLI deadline. `G95_COMMAND_TIMEOUT`
and `G95_POLL_ATTEMPTS` override these positive integer limits.

`G95_MATCH`, `G95_VS_NAME`, `G95_VS_SERIAL`, and `G95_VS_MODEL` override the
physical name match and managed identity. `BD_CLI` selects the CLI executable.
Changing the managed identity leaves screens with the old identity untouched.

If setup fails, inspect the printed log and try `g95nc reset`. If BetterDisplay
is unavailable, launch it with `open -a BetterDisplay` and retry. A reset that
cannot verify its result also returns failure.

## Validation

Run `just test-python -p test_g95nc.py` for command-boundary tests and
`shellcheck home/dot_config/raycast/scripts/executable_g95nc.sh` for shell checks.
The tests substitute external applications and do not prove real display behavior.
On macOS, run `g95nc butter`, `g95nc check`, and another `g95nc butter` to verify the
live result and that the second setup preserves the existing virtual screen.
