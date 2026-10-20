load '../../support/common'

setup() {
  setup_fixture
  pane_cmd="$DOTFILES_ROOT/agent-marketplace/packages/utils-agent/skills/acpx/scripts/acpx-pane"
  log="$FIXTURE/run log"
  export XDG_STATE_HOME="$FIXTURE/state" ORCA_TERMINAL_HANDLE=term_parent
  printf '@1|acpx\n' > "$FIXTURE/windows"
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
  "worktree current")
    [ -n "${ORCA_TERMINAL_HANDLE:-}${ORCA_WORKTREE_ID:-}" ] || exit 1
    printf '{"ok":true,"result":{"worktree":{"id":"w1"}}}\n'
    ;;
  "terminal split")
    [ -z "${SPLIT_FAILS:-}" ] || exit 1
    touch "$FIXTURE/server-started"
    printf '{"result":{"split":{"handle":"term_child"}}}\n'
    ;;
  "terminal show")
    case " $* " in
      *" --terminal term_stale "*)
        printf '{"ok":true,"result":{"terminal":{"handle":"term_stale","worktreeId":"w1","connected":false}}}\n' ;;
      *" --terminal term_parent "*)
        if [ -n "${PARENT_IN_OTHER_WORKTREE:-}" ]; then
          printf '{"ok":true,"result":{"terminal":{"handle":"term_parent","worktreeId":"w2","connected":true}}}\n'
        else
          printf '{"ok":true,"result":{"terminal":{"handle":"term_parent","worktreeId":"w1","connected":true}}}\n'
        fi ;;
      *" --terminal term_agent "*)
        printf '{"ok":true,"result":{"terminal":{"handle":"term_agent","worktreeId":"w1","connected":true}}}\n' ;;
      *)
        printf '{"ok":true,"result":{"terminal":{"handle":"term_active","worktreeId":"w1","connected":true}}}\n' ;;
    esac
    ;;
  "terminal list")
    printf '{"ok":true,"result":{"terminals":[{"handle":"term_agent","worktreeId":"w1","connected":true,"agentIdentity":"codex","title":"Agent"}]}}\n'
    ;;
  "terminal switch") printf '{}\n' ;;
  "terminal close") printf '{}\n' ;;
  *) exit 1 ;;
esac
STUB
  cat > "$FIXTURE/bin/tmux" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FIXTURE/tmux-calls"
while [ "$1" = -S ] || [ "$1" = -f ]; do shift 2; done
start_runner() {
  if [ -n "${PANE_INPUT_FIFO:-}" ]; then
    bash -c "$1" < "$PANE_INPUT_FIFO" > "$FIXTURE/pane-screen" 2>&1 &
  else
    bash -c "$1" < /dev/null > "$FIXTURE/pane-screen" 2>&1 &
  fi
  printf '%s\n' "$!" >> "$FIXTURE/pane-runner-pids"
}
cmd="$1"
shift
target="" name="" format=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -t) target="$2"; shift 2 ;;
    -n) name="$2"; shift 2 ;;
    -F) format="$2"; shift 2 ;;
    -c) shift 2 ;;
    -k|-P) shift ;;
    *) break ;;
  esac
done
case "$cmd" in
  has-session) [ -e "$FIXTURE/server-started" ] ;;
  list-windows)
    case "$format" in
      '#{window_id}|#{window_name}') cat "$FIXTURE/windows" ;;
      '#{window_name}') cut -d'|' -f2- "$FIXTURE/windows" ;;
      '#{window_id}') cut -d'|' -f1 "$FIXTURE/windows" ;;
      *) exit 1 ;;
    esac
    ;;
  rename-window)
    awk -F'|' -v id="$target" -v label="$1" 'BEGIN{OFS="|"} $1==id {$2=label} {print}' "$FIXTURE/windows" > "$FIXTURE/windows.new"
    mv "$FIXTURE/windows.new" "$FIXTURE/windows"
    ;;
  respawn-pane) start_runner "$1" ;;
  new-window)
    if [ -n "${PAUSE_TAB_CREATE:-}" ]; then
      touch "$FIXTURE/tab-create-entered"
      while [ ! -e "$FIXTURE/tab-create-release" ]; do sleep 0.1; done
    fi
    id="@$(($(wc -l < "$FIXTURE/windows") + 1))"
    printf '%s|%s\n' "$id" "$name" >> "$FIXTURE/windows"
    start_runner "$1"
    printf '%s\n' "$id"
    ;;
  kill-window)
    grep -v "^$target|" "$FIXTURE/windows" > "$FIXTURE/windows.new" || true
    mv "$FIXTURE/windows.new" "$FIXTURE/windows"
    touch "$FIXTURE/release"
    ;;
  *) exit 1 ;;
esac
STUB
  chmod +x "$FIXTURE/bin/acpx" "$FIXTURE/bin/orca" "$FIXTURE/bin/tmux"
}

@test "acpx-pane runs inline outside Orca and returns its status" {
  unset ORCA_TERMINAL_HANDLE
  run_bash 3 "$pane_cmd" --log "$log" --label agpt -- --format text agpt prompt -s review 'two words'
  assert_output ''
  assert_equal "$(cat "$log")" $'arg:--format\narg:text\narg:agpt\narg:prompt\narg:-s\narg:review\narg:two words\n[done] end_turn'
  run ! rg -q 'terminal split|terminal switch' "$FIXTURE/orca-calls"
  [ ! -e "$FIXTURE/tmux-calls" ]
}

@test "acpx-pane --inline keeps the run out of tmux" {
  run_bash 3 "$pane_cmd" --log "$log" --label agpt --inline -- agpt prompt -s review hi
  assert_equal "$(tail -1 "$log")" '[done] end_turn'
  [ ! -e "$FIXTURE/tmux-calls" ]
}

@test "acpx-pane --view creates the empty shared view without starting acpx" {
  run_bash 0 "$pane_cmd" --view
  assert_output 'pane: term_child'
  [ ! -e "$log" ]
  assert_equal "$(rg -c 'terminal split' "$FIXTURE/orca-calls")" 1
}

@test "a stale parent handle opens the shared view beside an agent in the current worktree" {
  export PARENT_IN_OTHER_WORKTREE=1
  run_bash 0 "$pane_cmd" --view
  assert_output 'pane: term_child'
  assert_regex "$(cat "$FIXTURE/orca-calls")" 'terminal list --worktree id:w1'
  assert_regex "$(cat "$FIXTURE/orca-calls")" 'terminal split --terminal term_agent --direction horizontal'
  run ! rg -q 'terminal split --terminal term_parent' "$FIXTURE/orca-calls"
}

@test "acpx-pane runs inline once when Orca cannot open the shared view" {
  export SPLIT_FAILS=1
  run_bash 3 "$pane_cmd" --log "$log" --label agpt -- agpt prompt -s review hi
  assert_regex "$stderr" 'could not open the tmux view; running inline'
  assert_equal "$(cat "$log")" $'arg:agpt\narg:prompt\narg:-s\narg:review\narg:hi\n[done] end_turn'
  [ ! -e "$FIXTURE/tmux-calls" ]
}

@test "acpx-pane shares one Orca view, labels tabs, and preserves arguments and status" {
  # shellcheck disable=SC2016
  run_bash 3 "$pane_cmd" --log "$log" --label agpt -- agpt prompt -s review 'two words; $(touch injected)'
  assert_regex "$output" '^pane: term_child; tab: 01 [0-9][0-9]:[0-9][0-9] agpt$'
  assert_equal "$(cat "$log")" $'arg:agpt\narg:prompt\narg:-s\narg:review\narg:two words; $(touch injected)\n[done] end_turn'
  [ ! -e injected ]
  run_bash 3 "$pane_cmd" --log "$FIXTURE/second log" --label aopus -- aopus prompt -s second-review hi
  assert_regex "$output" '^pane: term_child; tab: 02 [0-9][0-9]:[0-9][0-9] aopus$'
  assert_equal "$(rg -c 'terminal split' "$FIXTURE/orca-calls")" 1
  assert_regex "$(cat "$FIXTURE/windows")" '@2'
  count_script=$(rg --files "$XDG_STATE_HOME/acpx-pane" | rg '/count.sh$')
  assert_equal "$(bash "$count_script")" 'sessions: 2'
  run_bash 0 "$pane_cmd" --view
  assert_output 'pane: term_child'
  assert_regex "$(cat "$FIXTURE/orca-calls")" 'terminal switch --terminal term_child'
}

@test "stopping one waiting helper closes its tab" {
  export ACPX_TEST_WAIT=1
  "$pane_cmd" --log "$log" --label agpt -- agpt prompt -s review hi > "$FIXTURE/launcher-output" 2>&1 &
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
  assert_regex "$(cat "$FIXTURE/tmux-calls")" 'kill-window -t @1'
}

@test "a fresh session's idle window is reused after earlier windows disappear" {
  run_bash 3 "$pane_cmd" --log "$log" --label agpt -- agpt prompt -s review hi
  printf '@1|acpx\n' > "$FIXTURE/windows"
  run_bash 3 "$pane_cmd" --log "$FIXTURE/next log" --label aopus -- aopus prompt -s second-review hi
  assert_regex "$output" '^pane: term_child; tab: 02 [0-9][0-9]:[0-9][0-9] aopus$'
  assert_regex "$(cat "$FIXTURE/windows")" '^@1\|02 [0-9][0-9]:[0-9][0-9] aopus$'
  run ! rg -q 'new-window' "$FIXTURE/tmux-calls"
}

@test "a closed view reopens attached to the running session" {
  key=$(printf %s "$ORCA_TERMINAL_HANDLE" | shasum -a 256 | cut -c1-16)
  mkdir -p "$XDG_STATE_HOME/acpx-pane/$key"
  printf 'term_stale\n' > "$XDG_STATE_HOME/acpx-pane/$key/pane"
  run_bash 0 "$pane_cmd" --view
  assert_output 'pane: term_child'
  assert_equal "$(rg -c 'terminal split' "$FIXTURE/orca-calls")" 1
  assert_regex "$(cat "$FIXTURE/orca-calls")" 'tmux\.sock -f .* new-session -A -s acpx'
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
  run ! rg -q 'terminal split|terminal switch' "$FIXTURE/orca-calls"
  [ ! -e "$FIXTURE/tmux-calls" ]
  touch "$FIXTURE/release-lock"
  wait "$holder"
  wait "$launcher"
  assert_equal "$(cat "$FIXTURE/launcher-output")" 'pane: term_child'
  assert_equal "$(rg -c 'terminal split' "$FIXTURE/orca-calls")" 1
}

@test "closing a completed tab waits for a concurrent launch" {
  export PANE_INPUT_FIFO="$FIXTURE/pane-input"
  mkfifo "$PANE_INPUT_FIFO"
  "$pane_cmd" --log "$log" --label agpt -- agpt prompt -s review hi > "$FIXTURE/first-output" 2>&1 &
  first=$!
  exec 8> "$PANE_INPUT_FIFO"
  first_status=0
  wait "$first" || first_status=$?
  assert_equal "$first_status" 3
  first_runner=$(head -1 "$FIXTURE/pane-runner-pids")

  unset PANE_INPUT_FIFO
  PAUSE_TAB_CREATE=1 ACPX_TEST_WAIT=1 "$pane_cmd" --log "$FIXTURE/second-log" --label aopus -- aopus prompt -s second-review hi > "$FIXTURE/second-output" 2>&1 &
  second=$!
  for _ in {1..30}; do
    [ -e "$FIXTURE/tab-create-entered" ] && break
    sleep 0.1
  done
  [ -e "$FIXTURE/tab-create-entered" ]
  printf x >&8
  sleep 0.3
  run ! rg -q 'terminal close' "$FIXTURE/orca-calls"
  touch "$FIXTURE/tab-create-release"
  for _ in {1..30}; do
    run ! kill -0 "$first_runner" 2> /dev/null && break
    sleep 0.1
  done
  run ! kill -0 "$first_runner" 2> /dev/null
  run ! rg -q 'terminal close' "$FIXTURE/orca-calls"
  kill -TERM "$second"
  second_status=0
  wait "$second" || second_status=$?
  assert_equal "$second_status" 130
  exec 8>&-
}
