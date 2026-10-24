load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  mkdir -p "$FIXTURE/source" "$FIXTURE/scripts/firefox"
  cat > "$FIXTURE/scripts/firefox/install-settings" <<'SCRIPT'
#!/usr/bin/env bash
exit "$INSTALL_STATUS"
SCRIPT
  chmod +x "$FIXTURE/scripts/firefox/install-settings"
  local override
  override="$(jq -n --arg source "$FIXTURE/source" '{chezmoi: {sourceDir: $source}}')"
  render_template home/.chezmoiscripts/run_after_23-firefox-settings.sh.tmpl personal "$override" > "$FIXTURE/hook"
}

@test "Firefox deferral and configuration conflicts let the remaining apply continue" {
  local status
  for status in 2 3; do
    run -0 env INSTALL_STATUS="$status" bash "$FIXTURE/hook"
    assert_success
    assert_output --partial 'warning:'
  done
}

@test "Firefox unexpected installation failures still fail apply" {
  run -1 env INSTALL_STATUS=1 bash "$FIXTURE/hook"
  assert_failure 1
  assert_output --partial 'Firefox settings failed'
}
