# Child snippets expand their own variables.
# shellcheck disable=SC2016
load '../../support/common'
load '../../support/drift'

setup() { setup_drift; }
teardown() { finish_drift_background; }

@test "drift materializes executable commands and readable data at native target paths" {
  local path
  for path in bin/refresh bin/preview; do
    [ -x "$DRIFT_ROOT/$path" ]
  done
  for path in README.md lib/cache.sh shell/zsh.zsh feature.env art/compact.txt art/images/amber-badge.png; do
    [ -r "$DRIFT_ROOT/$path" ]
    [ ! -x "$DRIFT_ROOT/$path" ]
  done
  [ -r "$LOADER" ]
  [ ! -x "$LOADER" ]
  [ ! -e "$DRIFT_ROOT/bin/executable_refresh" ]
  [ ! -e "$DRIFT_ROOT/feature.env.tmpl" ]
}

@test "drift startup is silent when disabled, noninteractive, terminal-less, or remote" {
  write_drift_state
  local gate
  for gate in DOTFILES_CHEZMOI_DRIFT_ENABLED=0 TERM=dumb TERM= SSH_TTY=/dev/ttys000 SSH_CONNECTION=remote; do
    drift_startup "$gate"
    assert_output ''
  done
  run_zsh 0 -c 'source "$LOADER"'
  assert_success
  assert_output ''
  [ -z "$stderr" ]
  [ ! -e "$DRIFT_STUB_LOG" ]
}

@test "drift startup seeds a missing cache silently in the background" {
  : > "$FIXTURE/background.expected"
  drift_startup
  assert_output ''
  wait_drift "$DRIFT_STATE/state.env" present
  finish_drift_background
  drift_cache_value STATUS_COUNT 2
}

@test "drift cached output is colored by default and plain with NO_COLOR" {
  write_drift_state
  drift_startup
  assert_output $'\033[38;5;214mdotfiles drift | 3 files differ | checked 09:42\033[0m'
  write_drift_state changed
  drift_startup NO_COLOR=1
  assert_output 'dotfiles drift | 3 files differ | checked 09:42'
}

@test "drift throttles repeated signatures and recovers corrupt display timestamps" {
  write_drift_state
  drift_startup NO_COLOR=1
  assert_output 'dotfiles drift | 3 files differ | checked 09:42'
  drift_startup NO_COLOR=1
  assert_output ''
  printf '1 +\n' > "$DRIFT_STATE/last_shown"
  drift_startup NO_COLOR=1
  assert_output 'dotfiles drift | 3 files differ | checked 09:42'
  write_drift_state changed 3 "$(date +%s)" 'dotfiles drift | changed signature'
  drift_startup NO_COLOR=1
  assert_output 'dotfiles drift | changed signature'
}

@test "drift treats cache and local overrides as data without executing injected shell code" {
  : > "$FIXTURE/background.expected"
  write_drift_state clean 0 0 ''
  printf 'print -r -- pwned > "%s/pwned"\n' "$FIXTURE" >> "$DRIFT_STATE/state.env"
  drift_startup
  assert_output ''
  wait_drift "$FIXTURE/status.finished" present
  finish_drift_background
  [ ! -e "$FIXTURE/pwned" ]
  write_drift_state
  printf 'print -u2 -- LOCAL_ENV_STDERR\nDOTFILES_CHEZMOI_DRIFT_ENABLED=TRUE\n' > "$DRIFT_ROOT/local.env"
  drift_startup NO_COLOR=1
  assert_output 'dotfiles drift | 3 files differ | checked 09:42'
}

@test "drift local overrides can disable startup and select preview rendering" {
  write_drift_state
  printf 'DOTFILES_CHEZMOI_DRIFT_ENABLED=0\n' > "$DRIFT_ROOT/local.env"
  drift_startup
  assert_output ''
  printf 'DOTFILES_CHEZMOI_DRIFT_RENDERER=box\n' > "$DRIFT_ROOT/local.env"
  run_without_reporting_fds 0 "$DRIFT_ROOT/bin/preview" --sample
  assert_success
  assert_output --partial '+-- dotfiles drift'
  [ -z "$stderr" ]
  [ ! -e "$DRIFT_STUB_LOG" ]
}

@test "drift refresh excludes scripts, preserves the caller umask, and writes private cache files" {
  run_bash 0 -c 'umask 022; exec "$REFRESH"'
  assert_success
  assert_output ''
  [ -z "$stderr" ]
  assert_equal "$(cat "$DRIFT_STUB_LOG")" '["--no-tty", "--no-pager", "--color=false", "--refresh-externals=never", "status", "--exclude=scripts"]'
  assert_equal "$(cat "$FIXTURE/status.umask")" 022
  run_without_reporting_fds 0 "$TEST_PYTHON" -c '
import os, pathlib, stat
root = pathlib.Path(os.environ["DRIFT_STATE"])
assert stat.S_IMODE(root.stat().st_mode) == 0o700
for name in ("state.env", "status.txt", "banner.txt", "banner.ansi"):
    assert stat.S_IMODE((root / name).stat().st_mode) == 0o600, name
'
  assert_success
  drift_cache_value STATUS_COUNT 2
}

@test "drift refresh normalizes uppercase booleans and invalid TTL to one hour" {
  run_without_reporting_fds 0 env DOTFILES_CHEZMOI_DRIFT_ENABLED=TRUE \
    DOTFILES_CHEZMOI_DRIFT_REFRESH_TTL_SECONDS=abc "$REFRESH"
  assert_success
  [ -z "$stderr" ]
  run_without_reporting_fds 0 "$TEST_PYTHON" -c '
import os, pathlib
state = dict(line.split("=", 1) for line in (pathlib.Path(os.environ["DRIFT_STATE"]) / "state.env").read_text().splitlines())
prefix = "DOTFILES_CHEZMOI_DRIFT_"
assert int(state[prefix + "NEXT_REFRESH_AFTER"]) - int(state[prefix + "UPDATED_AT"]) == 3600
'
  assert_success
}

@test "drift refresh falls back from unsupported images and invalidates a changed renderer" {
  run_without_reporting_fds 0 "$REFRESH"
  assert_success
  run_without_reporting_fds 0 env DOTFILES_CHEZMOI_DRIFT_RENDERER=box "$REFRESH" --if-stale
  assert_success
  [[ "$(cat "$DRIFT_STATE/banner.txt")" == *'+-- dotfiles drift'* ]]
  run_without_reporting_fds 0 env DOTFILES_CHEZMOI_DRIFT_RENDERER=image "$REFRESH"
  assert_success
  [[ "$(cat "$DRIFT_STATE/banner.txt")" == *'+-- dotfiles drift'* ]]
  assert_equal "$(wc -l < "$DRIFT_STUB_LOG" | tr -d ' ')" 3
}

@test "drift refresh uses current scope and TTL rather than cached configuration" {
  write_drift_state
  run_without_reporting_fds 0 env DOTFILES_CHEZMOI_DRIFT_REFRESH_TTL_SECONDS=0 "$REFRESH" --if-stale
  assert_success
  run_without_reporting_fds 0 env DOTFILES_CHEZMOI_DRIFT_SCOPE=apply "$REFRESH" --if-stale
  assert_success
  assert_equal "$(tail -1 "$DRIFT_STUB_LOG")" '["--no-tty", "--no-pager", "--color=false", "--refresh-externals=never", "status"]'
  assert_equal "$(wc -l < "$DRIFT_STUB_LOG" | tr -d ' ')" 2
  drift_cache_value SCOPE apply
}

@test "drift refresh repairs partial and future caches while leaving complete fresh caches alone" {
  write_drift_state
  run_without_reporting_fds 0 "$REFRESH" --if-stale
  assert_success
  [ ! -e "$DRIFT_STUB_LOG" ]
  rm "$DRIFT_STATE/banner.txt" "$DRIFT_STATE/banner.ansi"
  run_without_reporting_fds 0 "$REFRESH" --if-stale
  assert_success
  [ -s "$DRIFT_STATE/banner.txt" ]
  [ -s "$DRIFT_STATE/banner.ansi" ]
  write_drift_state future 3 9999999999
  run_without_reporting_fds 0 "$REFRESH" --if-stale
  assert_success
  assert_equal "$(wc -l < "$DRIFT_STUB_LOG" | tr -d ' ')" 2
}

@test "drift startup returns the stale banner before a blocked background refresh completes" {
  : > "$FIXTURE/background.expected"
  write_drift_state stale 3 0
  drift_startup NO_COLOR=1 DRIFT_STUB_BLOCK=1
  assert_output 'dotfiles drift | 3 files differ | checked 09:42'
  wait_drift "$FIXTURE/status.started" present
  [ ! -e "$FIXTURE/status.finished" ]
  [ ! -e "$DRIFT_STATE/status.txt" ]
  run_without_reporting_fds 0 "$TEST_PYTHON" -c '
import os, pathlib
elapsed = float((pathlib.Path(os.environ["FIXTURE"]) / "startup-ms").read_text())
assert elapsed < 700, elapsed
'
  assert_success
  finish_drift_background
  drift_cache_value STATUS_COUNT 2
}

@test "drift leaves a newly created incomplete refresh lock intact" {
  mkdir -p "$DRIFT_STATE/refresh.lock"
  run_without_reporting_fds 0 "$REFRESH" --if-stale
  assert_success
  [ -d "$DRIFT_STATE/refresh.lock" ]
  [ ! -e "$DRIFT_STUB_LOG" ]
}

@test "drift recovers dead owners, future locks, and old locks whose PID is still alive" {
  local owner started
  for owner in 999999 "$$"; do
    for started in 1 9999999999; do
      mkdir -p "$DRIFT_STATE/refresh.lock"
      printf '%s\n' "$owner" > "$DRIFT_STATE/refresh.lock/owner.pid"
      printf '%s\n' "$started" > "$DRIFT_STATE/refresh.lock/started_at"
      printf 'stale-token\n' > "$DRIFT_STATE/refresh.lock/owner.token"
      run_without_reporting_fds 0 "$REFRESH"
      assert_success
      [ ! -d "$DRIFT_STATE/refresh.lock" ]
    done
  done
  assert_equal "$(wc -l < "$DRIFT_STUB_LOG" | tr -d ' ')" 4
}

@test "drift concurrent refreshes share one status call while the first owns the lock" {
  run_without_reporting_fds 0 env DRIFT_STUB_BLOCK=1 "$TEST_PYTHON" "$DOTFILES_ROOT/tests/scenarios/shell/drift-concurrent.py"
  assert_success
  assert_output ''
  [ -z "$stderr" ]
  assert_equal "$(wc -l < "$DRIFT_STUB_LOG" | tr -d ' ')" 1
  [ ! -d "$DRIFT_STATE/refresh.lock" ]
  drift_cache_value STATUS_COUNT 2
}

@test "drift clean refresh ignores successful stderr and resets the display throttle" {
  write_drift_state
  drift_startup NO_COLOR=1
  assert_output --partial 'dotfiles drift'
  run_without_reporting_fds 0 env DRIFT_STUB_CLEAN=1 DRIFT_STUB_STDERR='benign warning' "$REFRESH"
  assert_success
  [ -z "$stderr" ]
  drift_cache_value STATUS_COUNT 0
  [ ! -s "$DRIFT_STATE/banner.txt" ]
  [ ! -e "$DRIFT_STATE/last_shown_signature" ]
  write_drift_state
  drift_startup NO_COLOR=1
  assert_output --partial 'dotfiles drift'
}

@test "drift failed refresh records its error and preserves a usable cached banner" {
  write_drift_state failure-cache
  cp "$DRIFT_STATE/banner.txt" "$FIXTURE/expected-banner"
  run_without_reporting_fds 1 env DRIFT_STUB_FAIL=1 "$REFRESH"
  assert_failure 1
  [ -z "$stderr" ]
  [[ "$(cat "$DRIFT_STATE/last_error")" == *'stub failure'* ]]
  cmp "$FIXTURE/expected-banner" "$DRIFT_STATE/banner.txt"
  drift_cache_value STATUS_COUNT 3
  drift_cache_value SIGNATURE failure-cache
}

@test "drift failed refresh for a changed scope publishes an error instead of old-scope drift" {
  write_drift_state failure-cache
  run_without_reporting_fds 1 env DRIFT_STUB_FAIL=1 DOTFILES_CHEZMOI_DRIFT_SCOPE=apply "$REFRESH" --if-stale
  assert_failure 1
  drift_cache_value SCOPE apply
  drift_cache_value STATUS_COUNT 0
  drift_cache_value SIGNATURE error
  drift_cache_value RESULT error
}

@test "drift failed startup stays silent and cools down repeated refresh attempts" {
  : > "$FIXTURE/background.expected"
  write_drift_state startup-failure 0 0 ''
  export DRIFT_STUB_FAIL=1
  drift_startup
  assert_output ''
  wait_drift "$DRIFT_STATE/last_error" present
  finish_drift_background
  [[ "$(cat "$DRIFT_STATE/last_error")" == *'stub failure'* ]]
  drift_startup
  assert_output ''
  assert_equal "$(wc -l < "$DRIFT_STUB_LOG" | tr -d ' ')" 1
}
