load '../../support/common'

setup() {
  setup_fixture
  pane_cmd="$DOTFILES_ROOT/agent-marketplace/src/utils-agent/skills/acpx/scripts/acpx-pane"
  log="$FIXTURE/run log"
  export XDG_STATE_HOME="$FIXTURE/state" ORCA_TERMINAL_HANDLE=term_parent
  cat > "$FIXTURE/bin/acpx" <<'STUB'
#!/bin/sh
printf 'arg:%s\n' "$@"
printf '[done] end_turn\n'
exit 3
STUB
  printf '#!/bin/sh\nexit 0\n' > "$FIXTURE/bin/pi-viewer"
  printf '#!/bin/sh\nexit 0\n' > "$FIXTURE/bin/pi"
  cat > "$FIXTURE/bin/orca" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FIXTURE/orca-calls"
case "$1 $2" in
  "worktree current")
    [ -n "${ORCA_TERMINAL_HANDLE:-}${ORCA_WORKTREE_ID:-}" ] || exit 1
    printf '{"ok":true,"result":{"worktree":{"id":"%s","path":"/work/%s"}}}\n' "${WORKTREE:-w1}" "${WORKTREE:-w1}"
    ;;
  "terminal split")
    [ -z "${SPLIT_FAILS:-}" ] || exit 1
    [ -z "${SLOW_SPLIT:-}" ] || sleep 1
    printf 'split\n' >> "$FIXTURE/split-log"
    printf '{"result":{"split":{"handle":"term_viewer%s"}}}\n' "$(wc -l < "$FIXTURE/split-log" | tr -d ' ')"
    ;;
  "terminal show")
    case " $* " in
      *" --terminal term_viewer"*)
        if [ -e "$FIXTURE/viewer-closed" ]; then connected=false; else connected=true; fi
        printf '{"ok":true,"result":{"terminal":{"connected":%s}}}\n' "$connected" ;;
      *" --terminal term_parent "*)
        if [ -n "${PARENT_IN_OTHER_WORKTREE:-}" ]; then
          printf '{"ok":true,"result":{"terminal":{"handle":"term_parent","worktreeId":"w2","connected":true}}}\n'
        else
          printf '{"ok":true,"result":{"terminal":{"handle":"term_parent","worktreeId":"%s","connected":true}}}\n' "${WORKTREE:-w1}"
        fi ;;
      *)
        printf '{"ok":true,"result":{"terminal":{"handle":"term_active","worktreeId":"w1","connected":true}}}\n' ;;
    esac
    ;;
  "terminal list")
    printf '{"ok":true,"result":{"terminals":[{"handle":"term_agent","worktreeId":"w1","connected":true,"agentIdentity":"codex","title":"Agent"}]}}\n'
    ;;
  "terminal switch") printf '{}\n' ;;
  *) exit 1 ;;
esac
STUB
  chmod +x "$FIXTURE/bin/acpx" "$FIXTURE/bin/orca" "$FIXTURE/bin/pi-viewer" "$FIXTURE/bin/pi"
}

@test "acpx-pane runs inline outside Orca and returns its status" {
  unset ORCA_TERMINAL_HANDLE
  run_bash 3 "$pane_cmd" --log "$log" -- --format text agpt prompt -s review 'two words'
  assert_output ''
  assert_equal "$(cat "$log")" $'arg:--format\narg:text\narg:agpt\narg:prompt\narg:-s\narg:review\narg:two words\n[done] end_turn'
  run ! rg -q 'terminal split|terminal switch' "$FIXTURE/orca-calls"
}

@test "acpx-pane --inline runs without opening a viewer" {
  run_bash 3 "$pane_cmd" --log "$log" --inline -- agpt prompt -s review hi
  assert_equal "$(tail -1 "$log")" '[done] end_turn'
  [ ! -e "$FIXTURE/orca-calls" ]
}

@test "a --label from the earlier interface is ignored" {
  run_bash 3 "$pane_cmd" --log "$log" --label agpt --inline -- agpt prompt -s review hi
  assert_equal "$(head -1 "$log")" 'arg:agpt'
}

@test "acpx-pane runs inline when pi-viewer is missing" {
  rm "$FIXTURE/bin/pi-viewer"
  PATH=$(printf '%s\n' "$PATH" | tr ':' '\n' | while read -r dir; do [ -x "$dir/pi-viewer" ] || printf '%s:' "$dir"; done)
  export PATH="${PATH%:}"
  run ! command -v pi-viewer
  command -v python3 orca jq > /dev/null
  run_bash 3 "$pane_cmd" --log "$log" -- agpt prompt -s review hi
  assert_equal "$(tail -1 "$log")" '[done] end_turn'
  [ ! -e "$FIXTURE/orca-calls" ]
}

@test "acpx-pane --view opens the viewer for the worktree without starting acpx" {
  run_bash 0 "$pane_cmd" --view
  assert_output 'pane: term_viewer1'
  [ ! -e "$log" ]
  split=$(rg 'terminal split' "$FIXTURE/orca-calls")
  assert_regex "$split" 'terminal split --terminal term_parent --direction horizontal'
  assert_equal "${split##* --command }" "exec env ACPX_CWD=/work/w1 $(printf %q "$FIXTURE/bin/pi-viewer") acpx --json"
  assert_regex "$(cat "$FIXTURE/orca-calls")" 'terminal switch --terminal term_viewer1'
}

@test "a stale parent handle opens the viewer beside an agent in the current worktree" {
  export PARENT_IN_OTHER_WORKTREE=1
  run_bash 0 "$pane_cmd" --view
  assert_output 'pane: term_viewer1'
  assert_regex "$(cat "$FIXTURE/orca-calls")" 'terminal list --worktree id:w1'
  assert_regex "$(cat "$FIXTURE/orca-calls")" 'terminal split --terminal term_agent --direction horizontal'
  run ! rg -q 'terminal split --terminal term_parent' "$FIXTURE/orca-calls"
}

@test "acpx-pane still runs when Orca cannot open the viewer" {
  export SPLIT_FAILS=1
  run_bash 3 "$pane_cmd" --log "$log" -- agpt prompt -s review hi
  assert_regex "$stderr" 'could not open the viewer; running without it'
  assert_equal "$(cat "$log")" $'arg:agpt\narg:prompt\narg:-s\narg:review\narg:hi\n[done] end_turn'
}

@test "runs in one worktree share its viewer and keep their arguments and status" {
  # shellcheck disable=SC2016
  run_bash 3 "$pane_cmd" --log "$log" -- agpt prompt -s review 'two words; $(touch injected)'
  assert_output 'pane: term_viewer1'
  assert_equal "$(cat "$log")" $'arg:agpt\narg:prompt\narg:-s\narg:review\narg:two words; $(touch injected)\n[done] end_turn'
  [ ! -e injected ]
  run_bash 3 "$pane_cmd" --log "$FIXTURE/second log" -- aopus prompt -s second-review hi
  assert_output 'pane: term_viewer1'
  assert_equal "$(wc -l < "$FIXTURE/split-log" | tr -d ' ')" 1
}

@test "another worktree gets its own viewer" {
  run_bash 3 "$pane_cmd" --log "$log" -- agpt prompt -s review hi
  WORKTREE=w2 run_bash 3 "$pane_cmd" --log "$log" -- agpt prompt -s review hi
  assert_output 'pane: term_viewer2'
  assert_regex "$(rg 'terminal split' "$FIXTURE/orca-calls" | tail -1)" 'ACPX_CWD=/work/w2 '
}

@test "a closed viewer reopens on the next run" {
  run_bash 3 "$pane_cmd" --log "$log" -- agpt prompt -s review hi
  touch "$FIXTURE/viewer-closed"
  run_bash 3 "$pane_cmd" --log "$log" -- agpt prompt -s review hi
  assert_output 'pane: term_viewer2'
}

@test "concurrent launches in one worktree open a single viewer" {
  export SLOW_SPLIT=1
  "$pane_cmd" --log "$FIXTURE/a log" -- agpt prompt -s a hi > "$FIXTURE/a out" 2>&1 &
  first=$!
  "$pane_cmd" --log "$FIXTURE/b log" -- agpt prompt -s b hi > "$FIXTURE/b out" 2>&1 &
  second=$!
  wait "$first" || true
  wait "$second" || true
  assert_equal "$(wc -l < "$FIXTURE/split-log" | tr -d ' ')" 1
  assert_equal "$(cat "$FIXTURE/a out" "$FIXTURE/b out" | sort -u)" 'pane: term_viewer1'
}
