load '../../support/common'

setup() {
  setup_fixture
  export QUEUE_AGENT=claude QUEUE_BUNDLE=com.stablyai.orca
  mkdir -p "$HOME/bin"
  cat > "$FIXTURE/bin/lsappinfo" <<'STUB'
#!/bin/sh
printf '"bundleid"="%s"\n' "$QUEUE_BUNDLE"
STUB
  cat > "$FIXTURE/bin/osascript" <<'STUB'
#!/bin/sh
cat > "$FIXTURE/keystrokes"
STUB
  cat > "$HOME/bin/orca-agent-session" <<'STUB'
#!/bin/sh
if [ "$QUEUE_AGENT" = unknown ]; then
  printf '{"error":"Could not identify the focused session"}\n'
  exit 1
fi
printf '{"agent":"%s"}\n' "$QUEUE_AGENT"
STUB
  chmod +x "$FIXTURE/bin/lsappinfo" "$FIXTURE/bin/osascript" \
    "$HOME/bin/orca-agent-session"
}

@test "Claude queue shortcut refuses other Orca agents without typing" {
  for QUEUE_AGENT in codex pi omp unknown; do
    export QUEUE_AGENT
    run_bash 1 "$DOTFILES_ROOT/bin/claude-queue-draft"
    assert_regex "$stderr" 'Claude'
    [ ! -e "$FIXTURE/keystrokes" ]
  done
}

@test "Claude queue shortcut works before Raycast assets are applied" {
  run_bash 0 "$DOTFILES_ROOT/bin/claude-queue-draft"
  assert_regex "$(cat "$FIXTURE/keystrokes")" 'keystroke "/q "'
  assert_regex "$(cat "$FIXTURE/keystrokes")" 'key code 7 using \{control down\}'
  assert_regex "$(cat "$FIXTURE/keystrokes")" 'key code 36'
}

@test "Claude queue shortcut does nothing outside supported terminals" {
  export QUEUE_BUNDLE=com.apple.finder
  run_bash 0 "$DOTFILES_ROOT/bin/claude-queue-draft"
  [ ! -e "$FIXTURE/keystrokes" ]
}
