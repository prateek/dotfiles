# Settings for the 32:9 Odyssey G95NC with the lid shut. Selected by display.ncl.
let A = import "apps.ncl" in
let is-app = A.is-app in
let is-incognito = A.is-incognito in
let browsers = A.browsers in
let editors = A.editors in
let comms = A.comms in
let utilities = A.utilities in
{
  gaps.inner = { horizontal = 2, vertical = 2 },
  gaps.outer = { bottom = 2, left = 2, right = 2, top = 2 },
  # Browsers left, editors centred, comms and utilities such as 1Password right.
  # Place re-runs on every arrival but not on `move left/right` (docs/columns.md).
  columns = {
    count = 3,
    widths = [1.0 / 4, 1.0 / 2, 1.0 / 4],
    place = fun w _ _ => {
      column =
        if is-app browsers w then (if is-incognito w then 'last else 1)
        else if is-app editors w then 2
        else if is-app comms w then 'last
        else if is-app utilities w then 'last
        else 'nearest-empty,
      overflow = 'tab-group,
    },
  },
}
