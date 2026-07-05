#!/usr/bin/env bash
# @tuna.name PANW password
# @tuna.subtitle Read from 1Password and paste
# @tuna.icon symbol:key.fill
# @tuna.mode inline
# @tuna.input none
# @tuna.output none
#
# Inline, NOT background: the paste keystroke targets whatever field is focused, so it must
# run in the foreground flow rather than behind the Shelf window. Never prints the secret.
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

pw=$(op read "op://sit2vqyvky7qzyumcj7j3mlf24/iwkie33ipaj5jydxy4qx3ngoqe/password") \
  || { echo "1Password read failed" >&2; exit 1; }
old=$(pbpaste 2>/dev/null || true)
printf %s "$pw" | pbcopy
sleep 0.15
osascript -e 'tell application "System Events" to keystroke "v" using command down'
sleep 0.4
printf %s "$old" | pbcopy
