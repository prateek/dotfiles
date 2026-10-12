load '../../support/common'

setup() {
  setup_fixture
  local name
  for name in ${!DOTFILES_BANNER_@}; do
    unset "$name"
  done
  export DOTFILES_BANNER_ROOT="$HOME/.config/dotfiles/shell-banner"
  export DOTFILES_BANNER_STATE_DIR="$XDG_STATE_HOME/banner"
  export DOTFILES_BANNER_SOURCES=chezmoi
  export BANNER_REPAIR_PROBES="$FIXTURE/probes"
  : > "$FIXTURE/chezmoi.toml"
  chezmoi --no-tty --source "$DOTFILES_ROOT" --config "$FIXTURE/chezmoi.toml" \
    --override-data '{"machine_type":"ci","chezmoi":{"hostname":"dotfiles-test-host"}}' \
    --destination "$HOME" --cache "$XDG_CACHE_HOME/chezmoi" \
    --persistent-state "$FIXTURE/chezmoi-state.boltdb" \
    apply --force --exclude=scripts --parent-dirs "$DOTFILES_BANNER_ROOT"
  cat > "$FIXTURE/bin/chezmoi" <<'FAKE'
#!/bin/sh
for arg do
  case "$arg" in
    status) printf 'status\n' >> "$BANNER_REPAIR_PROBES"; printf ' M .zshrc\n'; exit 0 ;;
    managed) printf '.zshrc\n.config\n'; exit 0 ;;
  esac
done
printf 'Unexpected chezmoi arguments: %s\n' "$*" >&2
exit 2
FAKE
  chmod +x "$FIXTURE/bin/chezmoi"
  export DOTFILES_BANNER_CHEZMOI_BIN="$FIXTURE/bin/chezmoi"
  run_zsh 0 "$DOTFILES_BANNER_ROOT/bin/refresh" --source chezmoi
  assert_success
  assert_output ''
  [ -z "$stderr" ]
  CACHE_DIR="$DOTFILES_BANNER_STATE_DIR/sources/chezmoi"
}

assert_cache_repaired() {
  local missing="$1"
  rm "$CACHE_DIR/$missing"
  run_zsh 0 "$DOTFILES_BANNER_ROOT/bin/refresh" --if-stale --source chezmoi
  assert_success
  assert_output ''
  [ -z "$stderr" ]
  [ -s "$CACHE_DIR/$missing" ]

  NO_COLOR=1 run_zsh 0 "$DOTFILES_BANNER_ROOT/bin/module" chezmoi
  assert_success
  assert_output --regexp '^ 1 / 2 drifted  · checked [0-9]{2}:[0-9]{2}$'
  NO_COLOR='' run_zsh 0 "$DOTFILES_BANNER_ROOT/bin/module" chezmoi
  assert_success
  assert_output --partial $'\033[38;2;232;175;52m 1 / 2 drifted\033[0m'
  "$TEST_PYTHON" - "$CACHE_DIR" <<'PY'
from pathlib import Path
import stat
import sys
cache = Path(sys.argv[1])
assert stat.S_IMODE(cache.stat().st_mode) == 0o700
for name in ('state.env', 'module.txt', 'module.ansi'):
    assert stat.S_IMODE((cache / name).stat().st_mode) == 0o600, name
PY
}

@test "refresh repairs a missing plain row even when source state is fresh" {
  assert_cache_repaired module.txt
}

@test "refresh repairs a missing colored row even when source state is fresh" {
  assert_cache_repaired module.ansi
}

@test "refresh skips external probes when fresh cache rows are complete" {
  cp "$BANNER_REPAIR_PROBES" "$FIXTURE/probes-before"
  run_zsh 0 "$DOTFILES_BANNER_ROOT/bin/refresh" --if-stale --source chezmoi
  assert_success
  assert_output ''
  [ -z "$stderr" ]
  cmp "$FIXTURE/probes-before" "$BANNER_REPAIR_PROBES"
}
