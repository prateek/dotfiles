# Settings for the built-in panel alone. Selected by display.ncl.
let A = import "apps.ncl" in
let is-app = A.is-app in
# Chromium incognito windows float; Self Service's admin sign-in is one (see apps.ncl).
let is-incognito = A.is-incognito in
let browsers = A.browsers in
let editors = A.editors in
let comms = A.comms in
{
  # Workspace 1 is one full-width tab group; workspace 2 turns Columns on below.
  columns.count = 'off,
  gaps.inner = { horizontal = 0, vertical = 0 },
  gaps.outer = { bottom = 0, left = 0, right = 0, top = 0 },
  # Runs once when a window is detected. Editors go to workspace 1, browsers and
  # comms to 2, and any other app's windows float until it gets a rule.
  arrive = fun w _ _ =>
    if w.class != 'tiled then {}
    else if is-app browsers w && is-incognito w then { float = true }
    else if is-app editors w then { workspace = "1" }
    else if is-app (browsers @ comms) w then { workspace = "2" }
    else { float = true },
  # Browsers left, Slack, Zoom and Self Service tabbed right. `winmux-rows`
  # restacks the two as rows until the next reload.
  workspace."2".columns = {
    count = 2,
    place = fun w _ _ => {
      column = if is-app browsers w then 1 else 2,
      overflow = 'tab-group,
    },
  },
}
