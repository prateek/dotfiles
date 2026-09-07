load '../../support/common'

setup() {
  setup_fixture
  wrapper="$DOTFILES_ROOT/home/dot_local/bin/executable_wiki-sessions-sync"
  archive="$FIXTURE/archive"
  sync_stub="$FIXTURE/sync-sessions"
  qmd_stub="$FIXTURE/qmd"
  calls="$FIXTURE/calls"
  mkdir -p "$archive"
}

write_stubs() {
  local sync_status="$1" qmd_update_status="$2" qmd_files="$3"
  cat > "$sync_stub" <<STUB
#!/bin/sh
printf 'sync\n' >> "$calls"
exit $sync_status
STUB
  cat > "$qmd_stub" <<STUB
#!/bin/sh
printf 'qmd:%s\n' "\$*" >> "$calls"
case "\$3" in
  update) exit $qmd_update_status ;;
  status) printf '    Files:    %s\n' "$qmd_files" ;;
esac
STUB
  chmod +x "$sync_stub" "$qmd_stub"
}

run_wrapper() {
  local expected="$1"
  run_without_reporting_fds "$expected" env \
    WIKI_SESSIONS_CLONE="$archive" \
    WIKI_SESSIONS_SYNC="$sync_stub" \
    QMD_CLI="$qmd_stub" \
    sh "$wrapper"
}

@test "Session sync refreshes the named QMD index only after raw sync succeeds" {
  write_stubs 0 0 1
  : > "$calls"
  run_wrapper 0
  assert_success
  [ "$(< "$calls")" = $'sync\nqmd:--index wiki-agent-sessions update\nqmd:--index wiki-agent-sessions status' ]

  write_stubs 5 0 1
  : > "$calls"
  run_wrapper 5
  assert_failure 5
  [ "$(< "$calls")" = sync ]
}

@test "Session sync distinguishes a stale derived index from a failed archive sync" {
  write_stubs 0 19 1
  : > "$calls"
  run_wrapper 7
  assert_failure 7
  [[ "$stderr" = *"archive synchronized"* ]]
  [ "$(< "$calls")" = $'sync\nqmd:--index wiki-agent-sessions update' ]

  write_stubs 0 0 0
  : > "$calls"
  run_wrapper 7
  assert_failure 7
  [[ "$stderr" = *"QMD index 'wiki-agent-sessions' is empty"* ]]

  write_stubs 0 0 1
  : > "$calls"
  QMD_CLI="$FIXTURE/missing-qmd" WIKI_SESSIONS_SYNC="$sync_stub" \
    run_without_reporting_fds 7 sh "$wrapper"
  assert_failure 7
  [[ "$stderr" = *"archive synchronized"* ]]
  [ "$(< "$calls")" = sync ]
}

@test "Launchd retains the permission-owning app and the app delegates normal runs to the managed wrapper" {
  run chezmoi --source "$DOTFILES_ROOT" execute-template \
    --file "$DOTFILES_ROOT/home/Library/LaunchAgents/com.prateek.wiki-sessions-sync.plist.tmpl"
  assert_success
  program="$(printf '%s\n' "$output" | plutil -extract ProgramArguments.0 raw -o - -)"
  launch_path="$(printf '%s\n' "$output" | plutil -extract EnvironmentVariables.PATH raw -o - -)"
  [ "$program" = "$HOME/Applications/Session Archive Sync.app/Contents/MacOS/SessionArchiveSync" ]
  [[ "$launch_path" = /Applications/AgentsView.app/Contents/MacOS:* ]]

  run grep -F '.local/bin/wiki-sessions-sync' \
    "$DOTFILES_ROOT/scripts/agent-sessions/sync-app/SessionArchiveSync.swift"
  assert_success
}

@test "Managed QMD config includes the model identities persisted by the CLI" {
  run chezmoi --source "$DOTFILES_ROOT" execute-template \
    --file "$DOTFILES_ROOT/home/dot_config/qmd/wiki-agent-sessions.yml.tmpl"
  assert_success
  [[ "$output" = *"path: $HOME/code/github.com/prateek/wiki-agent-sessions"* ]]
  [[ "$output" = *"embed: hf:ggml-org/embeddinggemma-300M-GGUF/embeddinggemma-300M-Q8_0.gguf"* ]]
  [[ "$output" = *"generate: hf:tobil/qmd-query-expansion-1.7B-gguf/qmd-query-expansion-1.7B-q4_k_m.gguf"* ]]
  [[ "$output" = *"rerank: hf:ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF/qwen3-reranker-0.6b-q8_0.gguf"* ]]
}
