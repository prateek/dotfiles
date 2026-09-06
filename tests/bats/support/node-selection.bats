load '../../support/common'

setup() {
  setup_fixture
  runner="$DOTFILES_ROOT/scripts/tests/node"
}

@test "Node selection runs native tests with visible assertions" {
  cat > "$FIXTURE/example.test.mjs" <<'JS'
import test from 'node:test';
import assert from 'node:assert/strict';
test('arithmetic witness', () => assert.equal(2 + 3, 5));
JS
  run_bash 0 "$runner" "$FIXTURE/example.test.mjs"
  assert_success
  assert_output --partial 'ok 1 - arithmetic witness'
}

@test "Node selection rejects empty and entirely skipped suites" {
  : > "$FIXTURE/empty.test.mjs"
  run_bash 1 "$runner" "$FIXTURE/empty.test.mjs"
  assert_failure 1
  [[ "$stderr" == *'No Node tests passed'* ]]
  cat > "$FIXTURE/skipped.test.mjs" <<'JS'
import test from 'node:test';
test.skip('deliberately unavailable', () => {});
JS
  run_bash 1 "$runner" "$FIXTURE/skipped.test.mjs"
  assert_failure 1
  [[ "$stderr" == *'No Node tests passed'* ]]
  assert_output --partial '# SKIP'
}

@test "Node selection propagates a missing file and a native assertion failure" {
  run_bash 1 "$runner" "$FIXTURE/missing.test.mjs"
  assert_failure 1
  [[ "$output$stderr" == *'missing.test.mjs'* ]]
  cat > "$FIXTURE/failing.test.mjs" <<'JS'
import test from 'node:test';
import assert from 'node:assert/strict';
test('deliberate mismatch', () => assert.equal(2 + 3, 6));
JS
  run_bash 1 "$runner" "$FIXTURE/failing.test.mjs"
  assert_failure 1
  assert_output --partial 'not ok 1 - deliberate mismatch'
  assert_output --partial 'ERR_ASSERTION'
}
