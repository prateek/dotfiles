DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export DOTFILES_ROOT
TEST_PYTHON="${TEST_PYTHON:-$(python3 -c 'import sys; print(sys.executable)')}"
export TEST_PYTHON
bats_require_minimum_version 1.14.0
load "$DOTFILES_ROOT/build/test-libraries/bats-support-0.3.0/load.bash"
load "$DOTFILES_ROOT/build/test-libraries/bats-assert-2.1.0/load.bash"

setup_fixture() {
  local name
  for name in ${!CHEZMOI_@} ${!GIT_@} ${!ORCA_@}; do
    unset "$name"
  done
  unset BASH_ENV ENV CDPATH GHPATH FPATH
  unset DOTFILES_SKIP_PLIST_HOOKS DOTFILES_RELAUNCH_AFTER_APPLY
  export FIXTURE="$BATS_TEST_TMPDIR/fixture space"
  export HOME="$FIXTURE/home" ZDOTDIR="$FIXTURE/home"
  export XDG_CONFIG_HOME="$FIXTURE/config" XDG_STATE_HOME="$FIXTURE/state"
  export XDG_DATA_HOME="$FIXTURE/data" XDG_CACHE_HOME="$FIXTURE/cache"
  export XDG_RUNTIME_DIR="$FIXTURE/run"
  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
  export DOTFILES_SKIP_LAUNCHCTL_SYNC=1
  export TEST_ZSH="${TEST_ZSH:-/bin/zsh}"
  mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$XDG_DATA_HOME" \
    "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR" "$FIXTURE/bin"
  export PATH="$FIXTURE/bin:$PATH"
}

run_without_reporting_fds() {
  local expected="$1"
  shift
  run "-$expected" --separate-stderr "$TEST_PYTHON" -c '
import os, sys
os.closerange(3, os.sysconf("SC_OPEN_MAX"))
os.execvp(sys.argv[1], sys.argv[1:])
' "$@"
}

run_zsh() {
  local expected="$1"
  shift
  run_without_reporting_fds "$expected" "$TEST_ZSH" -f "$@"
}

run_bash() {
  local expected="$1"
  shift
  run_without_reporting_fds "$expected" "$BASH" "$@"
}
