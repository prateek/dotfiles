setup_brew_state() {
  local state
  unset HOMEBREW_CASK_OPTS
  for state in formulas casks taps outdated calls; do
    : > "$FIXTURE/brew.$state"
  done
  cp "$DOTFILES_ROOT/tests/scenarios/packages/brew.sh" "$FIXTURE/bin/brew"
  cat > "$FIXTURE/bin/uname" <<'STUB'
#!/bin/sh
printf 'Darwin\n'
STUB
  cat > "$FIXTURE/bin/id" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$FIXTURE/id.calls"
if [ "$1" = -u ]; then printf '0\n'; else exec /usr/bin/id "$@"; fi
STUB
  chmod +x "$FIXTURE/bin/brew" "$FIXTURE/bin/uname" "$FIXTURE/bin/id"
}
