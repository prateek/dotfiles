# Native UI driver

Outside Orca, native windows, system dialogs, browser chrome, and webviews
belong to desktop automation, not a page driver.

1. Use the harness's Computer Use tool when it offers one.
2. Otherwise, if `peekaboo` is installed, use it (`peekaboo --help`): capture
   the window, act on element ids from the latest capture, and capture again
   to confirm the UI advanced.
3. Target the named app window only, and restore focus to where Prateek left
   it when the task ends.
