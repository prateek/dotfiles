#!/usr/bin/env bash
# @tuna.name G95NC sharp
# @tuna.subtitle Sharp HiDPI on the Odyssey G95NC
# @tuna.icon symbol:display
# @tuna.mode background
# @tuna.input none
# @tuna.output text
#
# Native Tuna command: runs `g95nc set` as a background Shelf task so the multi-second
# virtual-screen teardown/rebuild streams its progress into the Shelf without blocking the
# launcher. Exit status propagates, so the Shelf marks success/failure.
set -uo pipefail
exec "$HOME/bin/g95nc" set
