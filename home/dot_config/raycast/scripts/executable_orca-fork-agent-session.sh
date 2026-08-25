#!/bin/bash
#
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Fork Orca Agent Session
# @raycast.mode silent
# @raycast.packageName Orca
#
# Optional parameters:
# @raycast.icon 🌱
# @raycast.needsConfirmation false
#
# Documentation:
# @raycast.description When Orca is frontmost, fork the agent session in the focused terminal into a new split and continue it there (claude/codex/pi/droid). Bind to ⌥F.
# @raycast.author Prateek Rungta
#
# Thin entry point: all logic lives in the sibling orca-agent-session.py
# (one engine, two Raycast commands). Raycast spawns scripts with a minimal
# PATH; the engine's shebang handles uv resolution itself.

exec "$(dirname "$0")/orca-agent-session.py" --fork
