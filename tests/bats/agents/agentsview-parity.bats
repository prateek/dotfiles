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

# bats test_tags=host
@test "Agentsview Orca Codex homes agree with the separate wiki sync producer" {
  [ -x "$wiki_script" ] || skip 'requires wiki-agent-sessions sync-sessions; set WIKI_SESSION_SYNC_SCRIPT to its path'
  # An older script ignores the flag and would run a real sync.
  grep -q -- '--print-codex-homes' "$wiki_script" || skip 'wiki sync-sessions predates --print-codex-homes'
  local home
  for home in orca/codex-runtime-home/home orca/codex-accounts/acct-b/home orca/codex-accounts/acct-a/home \
              orca/codex-accounts/.staging/home orca/codex-accounts/no-home orca-dev/codex-accounts/acct-d/home; do
    mkdir -p "$FIXTURE/support/$home"
  done
  touch "$FIXTURE/support/orca/codex-accounts/stray-file"
  render_template home/private_dot_agentsview/modify_private_config.toml.tmpl personal > "$FIXTURE/modifier.py"
  chmod +x "$FIXTURE/modifier.py"
  run -0 bash -c '"$1" --print-codex-homes "$2" > "$3"' _ "$FIXTURE/modifier.py" "$FIXTURE/support" "$FIXTURE/actual.json"
  assert_success
  run -0 bash -c '"$1" --print-codex-homes "$2" > "$3"' _ "$wiki_script" "$FIXTURE/support" "$FIXTURE/expected.json"
  assert_success
  run -0 cmp "$FIXTURE/actual.json" "$FIXTURE/expected.json"
  assert_success
  run -0 jq -r 'map(sub(".*/support/"; "")) | join(" ")' "$FIXTURE/actual.json"
  assert_output 'orca/codex-runtime-home/home orca/codex-accounts/acct-a/home orca/codex-accounts/acct-b/home orca-dev/codex-accounts/acct-d/home'
}
