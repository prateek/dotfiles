setup_drift() {
  setup_fixture
  local name
  for name in ${!DOTFILES_CHEZMOI_DRIFT_@} ${!DRIFT_STUB_@}; do
    unset "$name"
  done
  unset SSH_TTY SSH_CONNECTION NO_COLOR
  export XDG_CONFIG_HOME="$HOME/.config" TERM=xterm-256color
  export DRIFT_ROOT="$XDG_CONFIG_HOME/dotfiles/chezmoi-drift"
  export DRIFT_STATE="$FIXTURE/drift-state"
  export DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$DRIFT_STATE"
  export DOTFILES_CHEZMOI_DRIFT_CHEZMOI_BIN="$FIXTURE/bin/chezmoi-status"
  export DRIFT_STUB_LOG="$FIXTURE/status.calls"
  export REFRESH="$DRIFT_ROOT/bin/refresh"
  export LOADER="$XDG_CONFIG_HOME/zsh/extra/chezmoi-drift.zsh"
  : > "$FIXTURE/chezmoi.toml"
  run_without_reporting_fds 0 env DOTFILES_SKIP_PLIST_HOOKS=1 chezmoi \
    --source "$DOTFILES_ROOT" --destination "$HOME" \
    --config "$FIXTURE/chezmoi.toml" --cache "$XDG_CACHE_HOME" \
    --persistent-state "$FIXTURE/chezmoi-state.boltdb" --no-tty \
    --override-data '{"machine_type":"ci","chezmoi":{"hostname":"dotfiles-test-host"}}' \
    apply --force --exclude=scripts --parent-dirs "$DRIFT_ROOT" "$LOADER"
  assert_success
  [ -z "$stderr" ]
  cat > "$DOTFILES_CHEZMOI_DRIFT_CHEZMOI_BIN" <<'STUB'
#!/bin/sh
exec "$TEST_PYTHON" "$DOTFILES_ROOT/tests/scenarios/shell/drift-chezmoi.py" "$@"
STUB
  chmod +x "$DOTFILES_CHEZMOI_DRIFT_CHEZMOI_BIN"
}

write_drift_state() {
  local signature="${1:-fixture-drift}" count="${2:-3}" updated="${3:-$(date +%s)}"
  local banner="${4-dotfiles drift | 3 files differ | checked 09:42}"
  mkdir -p "$DRIFT_STATE"
  cat > "$DRIFT_STATE/state.env" <<EOF
DOTFILES_CHEZMOI_DRIFT_CACHE_VERSION=1
DOTFILES_CHEZMOI_DRIFT_STATUS_COUNT=$count
DOTFILES_CHEZMOI_DRIFT_SIGNATURE=$signature
DOTFILES_CHEZMOI_DRIFT_UPDATED_AT=$updated
DOTFILES_CHEZMOI_DRIFT_NEXT_REFRESH_AFTER=$((updated + 3600))
DOTFILES_CHEZMOI_DRIFT_BANNER_TTL_SECONDS=21600
DOTFILES_CHEZMOI_DRIFT_SCOPE=files
DOTFILES_CHEZMOI_DRIFT_RENDERER_EFFECTIVE=compact
DOTFILES_CHEZMOI_DRIFT_PALETTE_EFFECTIVE=amber
DOTFILES_CHEZMOI_DRIFT_CHECKED_LABEL=09:42
DOTFILES_CHEZMOI_DRIFT_RESULT=ok
EOF
  printf '%s\n' "$banner" > "$DRIFT_STATE/banner.txt"
  printf '\033[38;5;214m%s\033[0m\n' "$banner" > "$DRIFT_STATE/banner.ansi"
}

drift_cache_value() {
  local key="$1" value="$2"
  run -0 rg -Fx "DOTFILES_CHEZMOI_DRIFT_$key=$value" "$DRIFT_STATE/state.env"
  assert_success
}

# The interactive child expands its own variables.
# shellcheck disable=SC2016
drift_startup() {
  run_zsh 0 "$DOTFILES_ROOT/tests/support/pty-dialogue.zsh" \
    "$FIXTURE/startup.pty" __DRIFT_STARTUP_DONE__ acknowledged \
    env "$@" "$TEST_ZSH" -fic '
      stty -echo
      zmodload zsh/datetime
      started=$EPOCHREALTIME
      source "$LOADER"
      print -r -- "$(( (EPOCHREALTIME - started) * 1000 ))" > "$FIXTURE/startup-ms"
      print -r -- __DRIFT_STARTUP_DONE__
      read -r acknowledgment
      [[ "$acknowledgment" == acknowledged ]]
    '
  assert_success
  [ -z "$stderr" ]
  # Bats assertions consume the terminal transcript through output.
  # shellcheck disable=SC2034
  output="$("$TEST_PYTHON" - "$FIXTURE/startup.pty" <<'PY'
from pathlib import Path
import sys
print(Path(sys.argv[1]).read_text().replace("__DRIFT_STARTUP_DONE__\n", ""), end="")
PY
)"
}

wait_drift() {
  "$TEST_PYTHON" - "$1" "$2" <<'PY'
from pathlib import Path
import sys, time
path, expected = Path(sys.argv[1]), sys.argv[2] == "present"
deadline = time.monotonic() + 5
while path.exists() != expected:
    if time.monotonic() > deadline:
        raise SystemExit(f"timed out waiting for {path} to be {sys.argv[2]}")
    time.sleep(0.01)
PY
}

finish_drift_background() {
  : > "$FIXTURE/status.release"
  if [[ -e "$FIXTURE/background.expected" || -e "$FIXTURE/status.started" ]]; then
    wait_drift "$FIXTURE/status.started" present
    wait_drift "$FIXTURE/status.finished" present
    wait_drift "$DRIFT_STATE/refresh.lock" absent
  fi
}
