load '../../support/common'

setup() {
  setup_fixture
  unset CLAUDE_CODE_SESSION_ID ACPX_PARENT_SESSION
  pane_cmd="$DOTFILES_ROOT/agent-marketplace/packages/utils-agent/skills/acpx/scripts/acpx-pane"
  log="$FIXTURE/run log"
  cat > "$FIXTURE/bin/acpx" <<'STUB'
#!/bin/sh
printf 'arg:%s\n' "$@"
printf '[done] end_turn\n'
exit 3
STUB
  # Stands in for the Orca runtime: a split runs its startup command as the
  # pane process, with no keyboard attached.
  cat > "$FIXTURE/bin/orca" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FIXTURE/orca-calls"
case "$1 $2" in
  "terminal split")
    while [ "$#" -gt 0 ]; do
      [ "$1" = --command ] && command="$2"
      shift
    done
    bash -c "$command" < /dev/null > "$FIXTURE/pane-screen" 2>&1 &
    # A CLI timeout can report failure after the app already opened the pane.
    [ -z "${SPLIT_FAILS_AFTER_START:-}" ] || { sleep 0.5; exit 1; }
    printf '{"ok":true,"result":{"split":{"handle":"term_child"}}}\n'
    ;;
  "terminal show")
    printf '{"ok":true,"result":{"terminal":{"title":"Fix the login bug","connected":true}}}\n'
    ;;
  *) exit 1 ;;
esac
STUB
  chmod +x "$FIXTURE/bin/acpx" "$FIXTURE/bin/orca"
}

@test "acpx-pane runs acpx inline outside Orca and returns its status" {
  run_bash 3 "$pane_cmd" --log "$log" --label agpt -- --format text agpt exec 'two words'
  assert_output ''
  assert_equal "$(cat "$log")" $'arg:--format\narg:text\narg:agpt\narg:exec\narg:two words\n[done] end_turn'
  [ ! -e "$FIXTURE/orca-calls" ]
}

@test "acpx-pane --inline keeps the run out of an Orca pane" {
  export ORCA_TERMINAL_HANDLE=term_parent
  run_bash 3 "$pane_cmd" --log "$log" --label agpt --inline -- agpt exec hi
  assert_equal "$(tail -1 "$log")" '[done] end_turn'
  [ ! -e "$FIXTURE/orca-calls" ]
}

@test "acpx-pane opens a titled split beside the caller and relays the run through the log" {
  export ORCA_TERMINAL_HANDLE=term_parent CLAUDE_CODE_SESSION_ID=72dee454-7465-45a4-bb9e-39ecd6803c22
  run_bash 3 "$pane_cmd" --log "$log" --label agpt -- agpt exec 'two words; $(touch injected)'
  assert_output 'pane: term_child'
  assert_regex "$(cat "$FIXTURE/orca-calls")" 'terminal split --terminal term_parent --direction horizontal'
  assert_equal "$(cat "$log")" $'arg:agpt\narg:exec\narg:two words; $(touch injected)\n[done] end_turn'
  # The pane may still be drawing its close prompt after the launcher returns.
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    grep -q 'Press any key' "$FIXTURE/pane-screen" && break
    sleep 0.2
  done
  screen=$(cat "$FIXTURE/pane-screen")
  assert_regex "$screen" $'\e\\]0;acpx agpt ← claude 72dee454\a'
  assert_regex "$screen" 'parent session: claude 72dee454-7465-45a4-bb9e-39ecd6803c22'
  assert_regex "$screen" 'parent pane: +Fix the login bug'
  assert_regex "$screen" 'arg:two words'
  assert_regex "$screen" 'acpx exited 3\. Press any key to close this pane\.'
  [ ! -e injected ]
}

@test "acpx-pane waits on a pane whose split reported failure instead of running acpx again" {
  export ORCA_TERMINAL_HANDLE=term_parent SPLIT_FAILS_AFTER_START=1
  run_bash 3 "$pane_cmd" --log "$log" --label agpt -- agpt exec hi
  assert_output 'pane: unknown'
  assert_equal "$(cat "$log")" $'arg:agpt\narg:exec\narg:hi\n[done] end_turn'
}
