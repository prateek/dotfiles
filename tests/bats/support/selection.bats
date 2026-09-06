load '../../support/common'

setup() {
  setup_fixture
  mkdir -p "$FIXTURE/cases"
  runner="$DOTFILES_ROOT/scripts/tests/shell"
}

@test "shell suite discovers an eligible case without a registry entry" {
  cat > "$FIXTURE/cases/example.bats" <<'CASE'
@test "independent worked example" {
  [ "$(printf '%s' preserved)" = preserved ]
}
CASE
  run -0 bash "$runner" "$FIXTURE/cases"
  assert_success
  assert_output --partial 'ok 1 independent worked example'
}

@test "shell suite rejects empty and entirely skipped selections" {
  run -1 bash "$runner" "$FIXTURE/cases"
  assert_failure 1
  assert_output --partial 'No shell tests selected'
  cat > "$FIXTURE/cases/example.bats" <<'CASE'
@test "requires unavailable host state" {
  skip 'host state is unavailable'
}
CASE
  run -1 bash "$runner" "$FIXTURE/cases"
  assert_failure 1
  assert_output --partial 'All selected shell tests were skipped'
}

@test "shell suite excludes manual lanes and supports explicit tag selection" {
  cat > "$FIXTURE/cases/example.bats" <<'CASE'
@test "ordinary case" { [ 1 = 1 ]; }
# bats test_tags=host
@test "host case" { [ 1 = 1 ]; }
# bats test_tags=network
@test "network case" { [ 1 = 1 ]; }
# bats test_tags=vm
@test "vm case" { [ 1 = 1 ]; }
CASE
  run -0 bash "$runner" "$FIXTURE/cases"
  assert_success
  assert_output --partial 'ok 1 ordinary case'
  refute_output --partial 'host case'
  refute_output --partial 'network case'
  refute_output --partial 'vm case'
  run -0 env BATS_TAGS=host bash "$runner" "$FIXTURE/cases"
  assert_success
  assert_output --partial 'ok 1 host case'
  refute_output --partial 'ordinary case'
}

@test "shell suite propagates assertion failure" {
  cat > "$FIXTURE/cases/example.bats" <<'CASE'
@test "deliberate failure" { [ actual = expected ]; }
CASE
  run -1 bash "$runner" "$FIXTURE/cases"
  assert_failure 1
  assert_output --partial 'not ok 1 deliberate failure'
}

@test "shell suite fails visibly when its required runner is absent" {
  run -1 env PATH=/usr/bin:/bin "$BASH" "$runner" "$FIXTURE/cases"
  assert_failure 1
  assert_output --partial 'Missing Bats'
}
