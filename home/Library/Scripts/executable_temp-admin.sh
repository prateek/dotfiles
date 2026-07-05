#!/usr/bin/env bash
# @tuna.name Temp admin
# @tuna.subtitle Temporary admin elevation (Jamf)
# @tuna.icon symbol:lock.shield
# @tuna.mode background
# @tuna.input none
# @tuna.output text
#
# Native Tuna command: runs the Jamf temp-admin elevation as a background Shelf task so its
# output lands in the Shelf and it never blocks the launcher.
set -uo pipefail
exec "$HOME/.config/raycast/scripts/temp-admin.sh"
