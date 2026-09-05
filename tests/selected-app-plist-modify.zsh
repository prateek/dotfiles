#!/usr/bin/env zsh
set -euo pipefail
export DOTFILES_SKIP_LAUNCHCTL_SYNC=1
exec uv run --quiet --python '>=3.14' python -B "${0:A:h}/config_merge/run.py" \
  --app bettertouchtool raycast tailscale setapp betterdisplay "$@"
