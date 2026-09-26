# Native UI driver

Use native automation for app windows, system dialogs, browser chrome, and
webviews that the selected page driver cannot control.

1. **Driver.** Inside Orca, use `orca computer` through the
   [Orca guide](orca.md#native-ui-and-annotations). Outside Orca, use the
   harness's Computer Use tool, or installed `peekaboo` when none is offered.
   Read that tool's guide or `--help`; report a blocker if neither is available.
2. **Target.** Inspect the named app's windows and capture its accessibility
   state. Continue when the intended window and target element are identified.
3. **Act.** Follow the [interaction loop](../policy.md#interaction) and
   [focus hand-off](../policy.md#focus). Capture the result and verify the
   requested app state before reporting success.

## Prisma Access Browser

Orca does not detect Prisma for cookie import. Work in Prisma itself using
the native driver above, or ask Prateek to sign in through a supported browser
for import. Use the app's UI rather than decrypting its cookie store.

- Load a page in the background with `open -g -a "Prisma Browser" <url>`.
- Inside Orca, inspect `orca computer get-app-state --app com.talon-sec.Work`
  without `--restore-window`. The accessibility tree exposes browser chrome;
  use the screenshot for page content.
- Use element-targeted actions where the tree exposes a settable or actionable
  element. For native typing, hotkeys, or coordinate clicks, establish the
  [focus hand-off](../policy.md#focus) first.
