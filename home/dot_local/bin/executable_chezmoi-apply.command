#!/bin/bash
#
# chezmoi-apply.command — run the full apply in its own Terminal.app window.
#
# macOS opens a .command file in Terminal.app, so `open` on this file, or a
# file:// link to it, runs the apply outside Orca and outside any agent shell.
# The plist guard can then quit and relaunch Orca around the apply, and sudo
# gets a real TTY. The window stays open until a key is pressed.
set -u

cd "$HOME" || exit 1
chezmoi apply "$@"
status=$?
printf '\nchezmoi apply exited %s. Press any key to close this window.\n' "$status"
read -r -n 1 -s
exit "$status"
