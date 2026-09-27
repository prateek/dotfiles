load '../../support/common'

setup() {
  setup_fixture
  pane_cmd="$DOTFILES_ROOT/agent-marketplace/packages/utils-agent/skills/acpx/scripts/acpx-pane"
  log="$FIXTURE/run log"
  export XDG_STATE_HOME="$FIXTURE/state" ORCA_TERMINAL_HANDLE=term_parent
  printf 'w1:t1|1|w1:p1\n' > "$FIXTURE/tabs"
  cat > "$FIXTURE/bin/acpx" <<'STUB'
#!/bin/sh
printf 'arg:%s\n' "$@"
if [ -n "${ACPX_TEST_WAIT:-}" ]; then
  while [ ! -e "$FIXTURE/release" ]; do sleep 0.1; done
fi
printf '[done] end_turn\n'
exit 3
STUB
  cat > "$FIXTURE/bin/orca" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FIXTURE/orca-calls"
case "$1 $2" in
  "terminal split")
    [ -z "${SPLIT_FAILS:-}" ] || exit 1
    touch "$FIXTURE/server-started"
    printf '{"result":{"split":{"handle":"term_child"}}}\n'
    ;;
  "terminal show")
    if [ -n "${STALE_VIEW:-}" ]; then
      printf '{"result":{"terminal":{"connected":false}}}\n'
    else
      printf '{"result":{"terminal":{"connected":true}}}\n'
    fi
    ;;
  "terminal switch") printf '{}\n' ;;
  "terminal close") printf '{}\n' ;;
  *) exit 1 ;;
esac
STUB
  cat > "$FIXTURE/bin/herdr" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FIXTURE/herdr-calls"
[ "$1" = --session ] && shift 2
case "$1 $2" in
  "workspace list")
    if [ -n "${STALE_VIEW:-}" ] && [ ! -e "$FIXTURE/server-started" ]; then
      printf '{"error":{"code":"server_not_running"}}\n'
      exit 0
    fi
    printf '{"result":{"workspaces":[{"workspace_id":"w1"}]}}\n'
    ;;
  "session delete") printf 'deleted\n' ;;
  "tab list")
    jq -Rn '[inputs | split("|") | {tab_id: .[0], label: .[1]}] | {result:{tabs:.}}' < "$FIXTURE/tabs"
    ;;
  "tab rename")
    awk -F'|' -v id="$3" -v label="$4" 'BEGIN{OFS="|"} $1==id {$2=label} {print}' "$FIXTURE/tabs" > "$FIXTURE/tabs.new"
    mv "$FIXTURE/tabs.new" "$FIXTURE/tabs"
    printf '{}\n'
    ;;
  "tab create")
    if [ -n "${PAUSE_TAB_CREATE:-}" ]; then
      touch "$FIXTURE/tab-create-entered"
      while [ ! -e "$FIXTURE/tab-create-release" ]; do sleep 0.1; done
    fi
    while [ "$#" -gt 0 ]; do
      [ "$1" = --label ] && label="$2"
      shift
    done
    printf 'w1:t2|%s|w1:p2\n' "$label" >> "$FIXTURE/tabs"
    printf '{"result":{"tab":{"tab_id":"w1:t2"},"root_pane":{"pane_id":"w1:p2"}}}\n'
    ;;
  "tab get")
    grep -q "^$3|" "$FIXTURE/tabs" && printf '{}\n'
    ;;
  "tab close")
    grep -v "^$3|" "$FIXTURE/tabs" > "$FIXTURE/tabs.new" || true
    mv "$FIXTURE/tabs.new" "$FIXTURE/tabs"
    touch "$FIXTURE/release"
    printf '{}\n'
    ;;
  "pane list")
    printf '{"result":{"panes":[{"tab_id":"w1:t1","pane_id":"w1:p1"}]}}\n'
    ;;
  "pane run")
    if [ -n "${PANE_INPUT_FIFO:-}" ]; then
      bash -c "$4" < "$PANE_INPUT_FIFO" > "$FIXTURE/pane-screen" 2>&1 &
    else
      bash -c "$4" < /dev/null > "$FIXTURE/pane-screen" 2>&1 &
    fi
    printf '%s\n' "$!" >> "$FIXTURE/pane-runner-pids"
    printf '{}\n'
    ;;
  *) exit 1 ;;
esac
STUB
  chmod +x "$FIXTURE/bin/acpx" "$FIXTURE/bin/orca" "$FIXTURE/bin/herdr"
}

@test "acpx-pane runs inline outside Orca and returns its status" {
  unset ORCA_TERMINAL_HANDLE
  run_bash 3 "$pane_cmd" --log "$log" --label agpt -- --format text agpt exec 'two words'
  assert_output ''
  assert_equal "$(cat "$log")" $'arg:--format\narg:text\narg:agpt\narg:exec\narg:two words\n[done] end_turn'
  [ ! -e "$FIXTURE/orca-calls" ]
}

@test "acpx-pane --inline keeps the run out of Herdr" {
  run_bash 3 "$pane_cmd" --log "$log" --label agpt --inline -- agpt exec hi
  assert_equal "$(tail -1 "$log")" '[done] end_turn'
  [ ! -e "$FIXTURE/herdr-calls" ]
}

@test "acpx-pane --view creates the empty shared view without starting acpx" {
  run_bash 0 "$pane_cmd" --view
  assert_output 'pane: term_child'
  [ ! -e "$log" ]
  assert_equal "$(rg -c 'terminal split' "$FIXTURE/orca-calls")" 1
}

@test "acpx-pane runs inline once when Orca cannot open the shared view" {
  export SPLIT_FAILS=1
  run_bash 3 "$pane_cmd" --log "$log" --label agpt -- agpt exec hi
  assert_regex "$stderr" 'could not open Herdr; running inline'
  assert_equal "$(cat "$log")" $'arg:agpt\narg:exec\narg:hi\n[done] end_turn'
  [ ! -e "$FIXTURE/herdr-calls" ]
}

@test "acpx-pane shares one Orca view, labels tabs, and preserves arguments and status" {
  run_bash 3 "$pane_cmd" --log "$log" --label agpt -- agpt exec 'two words; $(touch injected)'
  assert_regex "$output" '^pane: term_child; tab: 01 [0-9][0-9]:[0-9][0-9] agpt$'
  assert_equal "$(cat "$log")" $'arg:agpt\narg:exec\narg:two words; $(touch injected)\n[done] end_turn'
  [ ! -e injected ]
  run_bash 3 "$pane_cmd" --log "$FIXTURE/second log" --label aopus -- aopus exec hi
  assert_regex "$output" '^pane: term_child; tab: 02 [0-9][0-9]:[0-9][0-9] aopus$'
  assert_equal "$(rg -c 'terminal split' "$FIXTURE/orca-calls")" 1
  assert_regex "$(cat "$FIXTURE/tabs")" 'w1:t2'
  count_script=$(rg --files "$XDG_STATE_HOME/acpx-pane" | rg '/count.sh$')
  assert_equal "$(bash "$count_script")" 'sessions: 2'
  run_bash 0 "$pane_cmd" --view
  assert_output 'pane: term_child'
  assert_regex "$(cat "$FIXTURE/orca-calls")" 'terminal switch --terminal term_child'
}

@test "stopping one waiting helper closes its tab" {
  export ACPX_TEST_WAIT=1
  "$pane_cmd" --log "$log" --label agpt -- agpt exec hi > "$FIXTURE/launcher-output" 2>&1 &
  launcher=$!
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    [ -s "$FIXTURE/launcher-output" ] && break
    sleep 0.1
  done
  [ -s "$FIXTURE/launcher-output" ]
  kill -TERM "$launcher"
  status=0
  wait "$launcher" || status=$?
  assert_equal "$status" 130
  assert_regex "$(cat "$FIXTURE/herdr-calls")" 'tab close w1:t1'
}

@test "a restored blank tab is reused after earlier tabs disappear" {
  run_bash 3 "$pane_cmd" --log "$log" --label agpt -- agpt exec hi
  printf 'w1:t1|1|w1:p1\n' > "$FIXTURE/tabs"
  run_bash 3 "$pane_cmd" --log "$FIXTURE/next log" --label aopus -- aopus exec hi
  assert_regex "$output" '^pane: term_child; tab: 02 [0-9][0-9]:[0-9][0-9] aopus$'
  assert_regex "$(cat "$FIXTURE/tabs")" 'w1:t1\|02 [0-9][0-9]:[0-9][0-9] aopus\|w1:p1'
  ! rg -q 'tab create' "$FIXTURE/herdr-calls"
}

@test "a stopped Herdr session is discarded before reopening the view" {
  key=$(printf %s "$ORCA_TERMINAL_HANDLE" | shasum -a 256 | cut -c1-16)
  mkdir -p "$XDG_STATE_HOME/acpx-pane/$key"
  printf 'term_stale\n' > "$XDG_STATE_HOME/acpx-pane/$key/pane"
  export STALE_VIEW=1
  run_bash 0 "$pane_cmd" --view
  assert_output 'pane: term_child'
  assert_regex "$(cat "$FIXTURE/herdr-calls")" "session delete acpx-$key"
  assert_equal "$(rg -c 'terminal split' "$FIXTURE/orca-calls")" 1
}

@test "a launch waits for a live shared-view lock" {
  key=$(printf %s "$ORCA_TERMINAL_HANDLE" | shasum -a 256 | cut -c1-16)
  state="$XDG_STATE_HOME/acpx-pane/$key"
  mkdir -p "$state"
  python3 - "$state/lock.flock" "$FIXTURE" <<'PY' &
import fcntl
import pathlib
import sys
import time

lock = open(sys.argv[1], "a")
fcntl.flock(lock, fcntl.LOCK_EX)
fixture = pathlib.Path(sys.argv[2])
(fixture / "lock-held").touch()
deadline = time.monotonic() + 5
while not (fixture / "release-lock").exists() and time.monotonic() < deadline:
    time.sleep(0.05)
PY
  holder=$!
  for _ in {1..30}; do
    [ -e "$FIXTURE/lock-held" ] && break
    sleep 0.1
  done
  [ -e "$FIXTURE/lock-held" ]
  "$pane_cmd" --view > "$FIXTURE/launcher-output" 2>&1 &
  launcher=$!
  sleep 0.3
  [ ! -e "$FIXTURE/orca-calls" ]
  touch "$FIXTURE/release-lock"
  wait "$holder"
  wait "$launcher"
  assert_equal "$(cat "$FIXTURE/launcher-output")" 'pane: term_child'
}

@test "closing a completed tab waits for a concurrent launch" {
  export PANE_INPUT_FIFO="$FIXTURE/pane-input"
  mkfifo "$PANE_INPUT_FIFO"
  "$pane_cmd" --log "$log" --label agpt -- agpt exec hi > "$FIXTURE/first-output" 2>&1 &
  first=$!
  exec 8> "$PANE_INPUT_FIFO"
  first_status=0
  wait "$first" || first_status=$?
  assert_equal "$first_status" 3
  first_runner=$(head -1 "$FIXTURE/pane-runner-pids")

  unset PANE_INPUT_FIFO
  PAUSE_TAB_CREATE=1 ACPX_TEST_WAIT=1 "$pane_cmd" --log "$FIXTURE/second-log" --label aopus -- aopus exec hi > "$FIXTURE/second-output" 2>&1 &
  second=$!
  for _ in {1..30}; do
    [ -e "$FIXTURE/tab-create-entered" ] && break
    sleep 0.1
  done
  [ -e "$FIXTURE/tab-create-entered" ]
  printf x >&8
  sleep 0.3
  ! rg -q 'terminal close' "$FIXTURE/orca-calls"
  touch "$FIXTURE/tab-create-release"
  for _ in {1..30}; do
    ! kill -0 "$first_runner" 2> /dev/null && break
    sleep 0.1
  done
  ! kill -0 "$first_runner" 2> /dev/null
  ! rg -q 'terminal close' "$FIXTURE/orca-calls"
  kill -TERM "$second"
  second_status=0
  wait "$second" || second_status=$?
  assert_equal "$second_status" 130
  exec 8>&-
}
