# Overrides on top of WinMux's shipped defaults (defaults.ncl in the app bundle).
# Display-specific settings live in laptop.ncl and ultrawide.ncl; display.ncl
# picks one and is rewritten by `winmux-display` until WinMux matches profiles
# to the attached display itself (prateek/winmux#47).
let W = import "winmux/winmux.ncl" in
let defaults = import "winmux/defaults.ncl" in
(defaults & (import "display.ncl") & {
  # Only reached with Columns off; the Column invariant forces tiles otherwise.
  default-root-container-layout = 'tab-group,
  # Second chord for move, alongside the shipped alt-shift-h/l. The column-count
  # pair overrides the current workspace until reload.
  mode.main.binding = {
    ctrl-alt-h = "move left",
    ctrl-alt-l = "move right",
    ctrl-alt-c = "column-count off",
    ctrl-alt-shift-c = "column-count 3",
    # Window switcher: type to filter every window, Enter to go. Caps+F on
    # both keyboards (Caps is Ctrl when held); takes Ctrl-F from every app.
    ctrl-f = "lens search",
    # Replace the system app switcher; WinMux disables the native Cmd-Tab pair
    # while bound and restores it on quit (docs/default-config.md). Parked: a
    # WinMux crash is a hard kill that leaves native Cmd-Tab disabled.
    # cmd-tab = "lens recent",
    # cmd-shift-tab = "lens recent",
    # cmd-backtick = "lens app-windows",
  },
  start-at-login = true,
  workspace-sidebar.auto-hide = true,
}) | W.Config
