#!/usr/bin/env zsh

# mise: runtime/toolchain manager (node/go/ruby)
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate --shims zsh)"
fi
