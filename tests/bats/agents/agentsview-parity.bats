# Child-shell snippets expand their own positional arguments.
# shellcheck disable=SC2016
load '../../support/common'
load '../../support/chezmoi'

setup() {
  wiki_script="${WIKI_SESSION_SYNC_SCRIPT:-$HOME/code/github.com/prateek/wiki-agent-sessions/.agents/skills/session-sync/scripts/sync-sessions}"
  setup_fixture
}

# bats test_tags=host
@test "Agentsview archive sources agree with the separate wiki sync producer" {
  [ -x "$wiki_script" ] || skip 'requires wiki-agent-sessions sync-sessions; set WIKI_SESSION_SYNC_SCRIPT to its path'
  local root
  for root in alpha/claude/projects alpha/cursor/projects beta/claude/projects beta/codex/sessions selfhost/claude/projects; do
    mkdir -p "$FIXTURE/clone/sessions/$root"
  done
  render_template home/private_dot_agentsview/modify_private_config.toml.tmpl personal \
    '{"machines_local":{"wiki_host_alias":"selfhost"}}' > "$FIXTURE/modifier.py"
  chmod +x "$FIXTURE/modifier.py"
  run -0 bash -c '"$1" --print-session-sources "$2" selfhost > "$3"' _ "$FIXTURE/modifier.py" "$FIXTURE/clone" "$FIXTURE/actual.json"
  assert_success
  run -0 bash -c '"$1" --print-session-sources "$2" selfhost > "$3"' _ "$wiki_script" "$FIXTURE/clone" "$FIXTURE/expected.json"
  assert_success
  run -0 cmp "$FIXTURE/actual.json" "$FIXTURE/expected.json"
  assert_success
}
