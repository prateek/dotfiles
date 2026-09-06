load '../../support/common'

setup() {
  setup_fixture
  mkdir -p "$FIXTURE/cases"
  runner="$DOTFILES_ROOT/scripts/tests/python"
}

@test "Python suite discovers native cases without a registry entry" {
  cat > "$FIXTURE/cases/test_example.py" <<'CASE'
import unittest

class Example(unittest.TestCase):
    def test_example(self):
        self.assertEqual('literal'.upper(), 'LITERAL')
CASE
  run -0 "$TEST_PYTHON" -B "$runner" discover -s "$FIXTURE/cases"
  assert_success
  assert_output --partial 'Ran 1 test'
}

@test "Python suite rejects empty and entirely skipped selections" {
  run -1 "$TEST_PYTHON" -B "$runner" discover -s "$FIXTURE/cases"
  assert_failure 1
  assert_output --partial 'No Python tests executed'
  cat > "$FIXTURE/cases/test_example.py" <<'CASE'
import unittest

class Example(unittest.TestCase):
    @unittest.skip('requires unavailable host state')
    def test_example(self):
        pass
CASE
  run -1 "$TEST_PYTHON" -B "$runner" discover -s "$FIXTURE/cases"
  assert_failure 1
  assert_output --partial 'requires unavailable host state'
  assert_output --partial 'No Python tests executed'
}

@test "Python suite propagates assertion and import failures" {
  cat > "$FIXTURE/cases/test_example.py" <<'CASE'
import unittest

class Example(unittest.TestCase):
    def test_example(self):
        self.assertEqual('actual', 'expected')
CASE
  run -1 "$TEST_PYTHON" -B "$runner" discover -s "$FIXTURE/cases"
  assert_failure 1
  assert_output --partial 'AssertionError'
  printf 'import deliberately_missing_test_dependency\n' > "$FIXTURE/cases/test_example.py"
  run -1 "$TEST_PYTHON" -B "$runner" discover -s "$FIXTURE/cases"
  assert_failure 1
  assert_output --partial 'ModuleNotFoundError'
}
