# Overrides on top of WinMux's shipped defaults (defaults.ncl in the app bundle).
let W = import "winmux/winmux.ncl" in
let is-app = fun ids w => std.array.elem w.app.bundleId ids in
# Self Service's admin sign-in is an ephemeral ASWebAuthenticationSession window
# in the default browser. At placement its title is "Untitled - … (Incognito)"
# and `document` is about:blank, so the Chromium incognito suffix is the only
# signal; Safari and Arc private windows carry no such suffix.
let is-incognito = fun w => std.string.contains "(Incognito)" w.title in
let browsers = ["com.talon-sec.Work", "com.google.Chrome", "company.thebrowser.Browser"] in
let editors = ["com.todesktop.230313mzl4w4u92", "com.stablyai.orca"] in
let comms = ["io.agentsview.desktop", "com.tinyspeck.slackmacgap", "com.jamfsoftware.selfservice.mac"] in
# Sized for the 32:9 Odyssey G95NC: browsers left, editors centred, comms right.
# Place re-runs on every arrival but not on `move left/right` (docs/columns.md).
let work-mode = {
  count = 3,
  widths = [1.0 / 4, 1.0 / 2, 1.0 / 4],
  place = fun w _ _ => {
    column =
      if is-app browsers w then (if is-incognito w then 'last else 1)
      else if is-app editors w then 2
      else if is-app comms w then 'last
      else 'nearest-empty,
    overflow = 'tab-group,
  },
} in
((import "winmux/defaults.ncl") & {
  columns = work-mode,
  # Only reached with Columns off (`column-count off`); the Column invariant forces tiles otherwise.
  default-root-container-layout = 'tab-group,
  gaps.inner = { horizontal = 2, vertical = 2 },
  gaps.outer = { bottom = 2, left = 2, right = 2, top = 2 },
  # Second chord for move, alongside the shipped alt-shift-h/l. The column-count
  # pair switches the grid off on the laptop panel; the override lasts until reload.
  mode.main.binding = {
    ctrl-alt-h = "move left",
    ctrl-alt-l = "move right",
    ctrl-alt-c = "column-count off",
    ctrl-alt-shift-c = "column-count 3",
  },
  start-at-login = true,
  workspace-sidebar.auto-hide = true,
}) | W.Config
