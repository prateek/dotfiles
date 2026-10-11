---
status: archived
doc_type: plan
created: 2026-10-11
closed: 2026-10-11
current_guidance: ../runbooks/g95nc-display.md
status_detail: "Implemented and installed locally; reset and unsupported-link refusal verified live. Supported-link Sharp/Butter acceptance remains a separate hardware check."
related:
  - ../runbooks/g95nc-display.md
---

# Complete G95NC Modes

Prateek assigns all BetterDisplay app configuration to this command. Reset must
remove every virtual screen and all app preferences. Export a private preference
backup, stop the app, clear its preference domain, and restart. The subsequent
requested baseline is 3840x1080 HiDPI at 120 Hz on the Odyssey, with factory EDID
restored and no mirroring; other displays retain advertised default modes. Repeated reset must converge without requiring a connected G95NC
or a healthy CLI before clearing settings.

Sharp and Butter retain their 4864x1368/60 Hz and 4608x1296/120 Hz desktops.
Preflight the physical 7680x2160 output and native HiDPI seed before mutation;
verify output timing separately from the rendered framebuffer. Accept refresh
rates within 0.2 Hz of the preset, including 59.97 and 119.88 Hz. Exact mode
numbers come from fresh advertised lists. Repeated correct setup must avoid
restarts and display mutations. Failures remain failures after recovery.

Use the real shell entrypoint with external-process fixtures for reset scope,
backups, missing app preferences, stopped app, unsupported links, fractional
timings, false-success mode switches, repeat setup and mode transitions. Update
the runbook and run shell, focused Python and document lifecycle checks.
Installed macOS display overrides and monitor firmware settings are outside the
app preference reset; this command does not install either.

Live acceptance depends on a connection advertising the required output. On an
unsupported connection, verify refusal and reset only; do not claim successful
Sharp or Butter hardware validation from fixtures.

## Validation Record

The original 21 command tests passed before changes. New regressions reproduced
preferences surviving reset, fractional-rate rejection, and success on a
3840x1080 physical signal. Tests that previously preserved unrelated virtual
screens during reset now assert app-wide removal under the requested ownership
contract. Preservation and tag-identity checks remain for successful setup.

The former chezmoi plist template is removed so later applies cannot undo reset.
Its menu/update preference assertions are retired with that ownership. Machine
gate tests now require the plist to be unmanaged on personal and work machines;
command tests cover full preference clearing and private backup preservation.

The live USB-C-to-HDMI connection on 2026-10-11 advertised no 7680x2160 output.
The updated Sharp command refused it before any preference or display writes.

The 31-case command suite passed. Live reset exposed macOS retaining an empty
domain after deletion; an added regression failed on that behavior, then passed
after verification switched to exported preference contents. All 12 affected
reset/recovery cases passed again, as did seven package-gate/plist-discovery
checks, shellcheck, and document lifecycle validation.

Two consecutive live resets succeeded on BetterDisplay 5.1.1. The resulting
state had no virtual screen, over-8K support disabled, mirroring off, and the
connection's advertised default 3840x1080 mode at approximately 120 Hz. The
original settings were retained in a mode-0600 backup. The updated Raycast
script was installed from this worktree and verified with chezmoi. The default
chezmoi source remains the canonical checkout; publication is separate from
this local installation.


## Reset Baseline Follow-up

Prateek subsequently requested the observed 3840x1080 HiDPI/120 Hz desktop as
reset's baseline. The default-mode assertion now applies to non-Odyssey displays;
Odyssey coverage requires HiDPI, 120 Hz, main display, and mirroring off on each
repeat. The two failed-setup recovery assertions now require this same baseline
in place of the former non-HiDPI default; failure status and cleanup assertions
remain unchanged. Added regressions reproduce an active volatile EDID surviving reset and
false success when the requested reset mode is absent. The mode needs no virtual
screen or over-8K setting and does not imply a native-resolution physical signal.


The follow-up ran all 37 command tests. Only the two former recovery-mode
expectations failed; after updating them to the new user-requested baseline,
both passed in a focused rerun. Shellcheck, scoped chezmoi preview/verification,
and docs lifecycle checks passed. The updated command was installed locally.

Two successive live resets then verified 3840x1080 HiDPI at 120 Hz, a 7680x2160
rendered framebuffer, factory EDID, no virtual screens, and mirroring off. The
physical HDMI signal remains 3840x1080 at 119.97 Hz, matching the requested
baseline rather than claiming native-output Sharp/Butter acceptance.
