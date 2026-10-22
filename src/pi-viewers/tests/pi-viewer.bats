load '../../../tests/support/common'

setup() {
  setup_fixture
  launcher="$DOTFILES_ROOT/src/pi-viewers/bin/pi-viewer"
  export XDG_STATE_HOME="$FIXTURE/state"
  cat > "$FIXTURE/bin/pi" <<'STUB'
#!/bin/sh
printf 'arg:%s\n' "$@" > "$FIXTURE/pi-args"
env | grep -E '^(PI_VIEWER|PI_CODING_AGENT_DIR|ACPX_CWD|ACPX_PREFIX|CCWF_RUN|CCWF_REPLAY|CCWF_MODE)=' | sort > "$FIXTURE/pi-env"
STUB
  chmod +x "$FIXTURE/bin/pi"
}

@test "pi-viewer workflow starts pi with the workflow extension and a private agent directory" {
  run_bash 0 "$launcher" workflow --mode table wf_123
  assert_output ''
  assert_equal "$(cat "$FIXTURE/pi-env")" $'CCWF_MODE=table\nCCWF_RUN=wf_123\nPI_CODING_AGENT_DIR='"$XDG_STATE_HOME"$'/pi-viewers/pi-agent\nPI_VIEWER=workflow'
  assert_equal "$(head -3 "$FIXTURE/pi-args")" $'arg:-ne\narg:-e\narg:'"$DOTFILES_ROOT"'/src/pi-viewers/workflow/viewer.ts'
  assert_regex "$(tr '\n' ' ' < "$FIXTURE/pi-args")" 'arg:--no-session arg:--offline $'
  settings="$XDG_STATE_HOME/pi-viewers/pi-agent/settings.json"
  assert_equal "$(jq -c '[.enableInstallTelemetry, .enableAnalytics, .theme]' "$settings")" '[false,false,"dark"]'
  assert_equal "$(python3 -c 'import os, sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777)[2:])' "$XDG_STATE_HOME/pi-viewers/pi-agent")" 700
}

@test "pi-viewer acpx scopes the sessions it watches" {
  run_bash 0 "$launcher" acpx --cwd /work/w1 --prefix review
  assert_equal "$(cat "$FIXTURE/pi-env")" $'ACPX_CWD=/work/w1\nACPX_PREFIX=review\nPI_CODING_AGENT_DIR='"$XDG_STATE_HOME"$'/pi-viewers/pi-agent\nPI_VIEWER=acpx'
  assert_equal "$(sed -n 3p "$FIXTURE/pi-args")" "arg:$DOTFILES_ROOT/src/pi-viewers/acpx/viewer.ts"
}

@test "pi-viewer rejects an unknown viewer or an option for the other one" {
  run_bash 2 "$launcher" tail
  assert_regex "$stderr" '^usage: pi-viewer'
  run_bash 2 "$launcher" acpx --once
  assert_regex "$stderr" 'unexpected argument for acpx: --once'
  [ ! -e "$FIXTURE/pi-args" ]
}

@test "pi-viewer workflow --once prints JSON without pi" {
  rm "$FIXTURE/bin/pi"
  export CCWF_PROJECTS="$FIXTURE/projects"
  mkdir -p "$CCWF_PROJECTS"
  run_bash 1 "$launcher" workflow --once
  assert_regex "$stderr" 'no workflow runs under'
  [ ! -e "$FIXTURE/pi-args" ]
}

@test "pi-viewer finds its package through the chezmoi symlink" {
  ln -s "$launcher" "$FIXTURE/bin/pi-viewer"
  run_bash 0 "$FIXTURE/bin/pi-viewer" acpx
  assert_equal "$(sed -n 3p "$FIXTURE/pi-args")" "arg:$DOTFILES_ROOT/src/pi-viewers/acpx/viewer.ts"
}

@test "pi-viewer carries the viewers' earlier state directories over once" {
  mkdir -p "$XDG_STATE_HOME/acpx-viewer/summaries" "$XDG_STATE_HOME/workflow-viewer" "$XDG_STATE_HOME/acpx-pane/pi-agent"
  printf 'left\n' > "$XDG_STATE_HOME/acpx-viewer/placement"
  printf '12\n' > "$XDG_STATE_HOME/acpx-viewer/roster-rows"
  printf '{"30":"Label"}\n' > "$XDG_STATE_HOME/acpx-viewer/summaries/abc.json"
  printf 'table\n' > "$XDG_STATE_HOME/workflow-viewer/mode"
  printf '48\n' > "$XDG_STATE_HOME/workflow-viewer/left-width-tree"
  printf '60\n' > "$XDG_STATE_HOME/workflow-viewer/left-width-table"
  run_bash 0 "$launcher" workflow
  assert_equal "$(cat "$XDG_STATE_HOME/pi-viewers/acpx/placement" "$XDG_STATE_HOME/pi-viewers/acpx/size-strip" "$XDG_STATE_HOME/pi-viewers/acpx/summaries/abc.json")" $'left\n12\n{"30":"Label"}'
  assert_equal "$(cat "$XDG_STATE_HOME/pi-viewers/workflow/mode" "$XDG_STATE_HOME/pi-viewers/workflow/size-side")" $'table\n48'
  [ ! -e "$XDG_STATE_HOME/pi-viewers/workflow/left-width-table" ]
  [ ! -e "$XDG_STATE_HOME/acpx-viewer" ] && [ ! -e "$XDG_STATE_HOME/workflow-viewer" ] && [ ! -e "$XDG_STATE_HOME/acpx-pane/pi-agent" ]
  printf 'top\n' > "$XDG_STATE_HOME/pi-viewers/acpx/placement"
  mkdir -p "$XDG_STATE_HOME/acpx-viewer"
  run_bash 0 "$launcher" workflow
  assert_equal "$(cat "$XDG_STATE_HOME/pi-viewers/acpx/placement")" top
}
