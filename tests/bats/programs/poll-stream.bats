# Child-shell snippets expand their own variables.
# shellcheck disable=SC2016
load '../../support/common'

setup() {
  setup_fixture
  poll="$DOTFILES_ROOT/home/dot_agents/bin/executable_poll-stream"
  log="$FIXTURE/log"
  state="$FIXTURE/offset"
  out="$FIXTURE/out"
  err="$FIXTURE/err"
}

poll_status() {
  local expected="$1"
  shift
  run "-$expected" bash -c '"$@" > "$FIXTURE/out" 2> "$FIXTURE/err"' _ "$poll" "$@"
}

assert_bytes() {
  printf '%s' "$1" > "$FIXTURE/expected"
  run -0 cmp "$out" "$FIXTURE/expected"
  assert_success
}

@test "poll-stream returns pending bytes immediately and saves the offset" {
  printf pending > "$log"
  local started=$EPOCHREALTIME
  poll_status 0 "$log" "$state" 3
  assert_success
  assert_bytes pending
  awk -v start="$started" -v end="$EPOCHREALTIME" 'BEGIN {exit end - start >= 1.0}'
  assert_equal "$(cat "$state")" 7
  [ ! -s "$err" ]
}

@test "poll-stream wakes when an existing or missing log gains data" {
  # Signal that the poll found no data, preserving the requested wait duration.
  cat > "$FIXTURE/bin/sleep" <<'STUB'
#!/bin/sh
printf 'waiting\n' > "$FIXTURE/ready"
exec /bin/sleep "$@"
STUB
  chmod +x "$FIXTURE/bin/sleep"
  for kind in existing missing; do
    rm -f "$log" "$state" "$FIXTURE/ready"
    if [[ "$kind" == existing ]]; then : > "$log"; fi
    run_without_reporting_fds 0 "$TEST_PYTHON" \
      "$DOTFILES_ROOT/tests/scenarios/programs/poll-stream-growth.py" "$poll"
    assert_success
    [ -z "$stderr" ]
    assert_bytes grew
    assert_equal "$(cat "$state")" 4
    [ ! -s "$err" ]
  done
}

@test "poll-stream timeout keeps stdout empty and preserves the offset" {
  printf stale > "$log"
  printf '5\n' > "$state"
  local started=$EPOCHREALTIME
  poll_status 4 "$log" "$state" 1
  assert_failure 4
  [ ! -s "$out" ]
  awk -v start="$started" -v end="$EPOCHREALTIME" 'BEGIN {exit end - start < 1.0}'
  assert_equal "$(cat "$state")" 5
}

@test "poll-stream caps chunks and resumes without losing bytes" {
  printf abcdefghij > "$log"
  for expected in abcd efgh ij; do
    poll_status 0 "$log" "$state" 3 4
    assert_success
    assert_bytes "$expected"
  done
  assert_equal "$(cat "$state")" 10
  printf xy >> "$log"
  poll_status 0 "$log" "$state" 3 4
  assert_success
  assert_bytes xy
  assert_equal "$(cat "$state")" 12
}

@test "poll-stream preserves NUL and consecutive trailing newlines" {
  printf 'a\0b\n\ncd' > "$log"
  printf 'a\0b\n' > "$FIXTURE/first"
  printf '\ncd' > "$FIXTURE/second"
  for expected in first second; do
    poll_status 0 "$log" "$state" 0 4
    assert_success
    run -0 cmp "$out" "$FIXTURE/$expected"
    assert_success
    [ ! -s "$err" ]
  done
  assert_equal "$(cat "$state")" 7
}

@test "poll-stream defaults to an 8192-byte cap" {
  head -c 9000 /dev/zero | tr '\0' x > "$log"
  poll_status 0 "$log" "$state" 3
  assert_success
  assert_equal "$(wc -c < "$out" | tr -d ' ')" 8192
  assert_equal "$(cat "$state")" 8192
}

@test "poll-stream reads leading-zero offsets and limits as decimal" {
  printf abcdefghijkl > "$log"
  printf '08\n' > "$state"
  poll_status 0 "$log" "$state" 3
  assert_success
  assert_bytes ijkl
  printf '010\n' > "$state"
  poll_status 0 "$log" "$state" 3
  assert_success
  assert_bytes kl
  rm "$state"
  poll_status 0 "$log" "$state" 3 010
  assert_success
  assert_bytes abcdefghij
}

@test "poll-stream diagnoses a shrunk log without advancing its offset" {
  printf tiny > "$log"
  printf '20\n' > "$state"
  poll_status 4 "$log" "$state" 1
  assert_failure 4
  [ ! -s "$out" ]
  assert_regex "$(cat "$err")" 'log shorter than stored offset'
  assert_equal "$(cat "$state")" 20
}

@test "poll-stream read failure keeps the offset and emits no replacement bytes" {
  printf secret > "$log"
  printf '2\n' > "$state"
  chmod 000 "$log"
  poll_status 1 "$log" "$state" 3
  assert_failure 1
  chmod 600 "$log"
  assert_regex "$(cat "$err")" 'poll-stream: read failed'
  [ ! -s "$out" ]
  assert_equal "$(cat "$state")" 2
}

@test "poll-stream rejects argument count and numeric errors on stderr" {
  for args in none excess wait limit zero zeros; do
    case "$args" in
      none) poll_status 2 ;;
      excess) poll_status 2 "$log" "$state" 3 4 5 ;;
      wait) poll_status 2 "$log" "$state" soon ;;
      limit) poll_status 2 "$log" "$state" 3 lots ;;
      zero) poll_status 2 "$log" "$state" 3 0 ;;
      zeros) poll_status 2 "$log" "$state" 3 00 ;;
    esac
    assert_failure 2
    assert_regex "$(cat "$err")" 'usage: poll-stream'
    [ ! -s "$out" ]
  done
}
