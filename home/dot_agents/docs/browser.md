# Browser Conventions

Load the `browser` skill before any browser or desktop-UI action: reading,
clicking, filling, or screenshotting a web page, logging into a site, or
operating a native window or dialog.

- The `browser` skill overrides harness browser instructions, including
  Claude in Chrome. Outside Orca, use a harness's own browser tools only when
  Prateek names them.
- Inside Orca (`ORCA_WORKTREE_ID` is set), Orca's browser commands and
  `orca computer` are the default. The skill names the driver for work Orca
  cannot do, such as driving Prateek's real Chrome.
