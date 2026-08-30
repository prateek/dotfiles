#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

zmodload zsh/datetime

die() {
  print -u2 -- "acpx-poll-stream: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
SCRIPT="$DOTFILES_ROOT/home/dot_agents/bin/executable_poll-stream"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

out="$tmp_root/out"
rc=0
elapsed=0

# Runs poll-stream with stdout captured byte-exact in $out; records $rc and
# wall-clock $elapsed so callers can assert immediacy vs blocking.
run_poll() {
  local start=$EPOCHREALTIME
  set +e
  "$SCRIPT" "$@" >"$out" 2>"$tmp_root/err"
  rc=$?
  set -e
  elapsed=$((EPOCHREALTIME - start))
}

assert_rc() {
  [[ "$rc" -eq "$1" ]] || {
    cat "$tmp_root/err" >&2
    die "$2: expected rc=$1, got rc=$rc"
  }
}

# Command substitution strips trailing newlines, so also compare byte counts
# to catch an implementation that appends a newline to each chunk.
assert_out() {
  [[ "$(cat "$out")" == "$1" ]] || die "$2: expected output '$1', got '$(cat "$out")'"
  [[ "$(wc -c <"$out")" -eq "${#1}" ]] || die "$2: expected ${#1} bytes, got $(wc -c <"$out")"
}

# Successful poll: rc=0 and byte-exact output under one label.
assert_chunk() {
  assert_rc 0 "$2"
  assert_out "$1" "$2"
}

assert_state() {
  [[ "$(cat "$state")" == "$1" ]] || die "$2: expected state=$1, got $(cat "$state")"
}

# (a) Data already pending past the offset: returns immediately, no initial sleep.
log="$tmp_root/a.log"
state="$tmp_root/a.state"
printf 'pending' >"$log"
run_poll "$log" "$state" 3
assert_chunk "pending" "pending data"
(( elapsed < 1.0 )) || die "pending data: expected immediate return, took ${elapsed}s"
assert_state 7 "pending data"

# (b) Blocks on a caught-up log, wakes when a background writer appends.
log="$tmp_root/b.log"
state="$tmp_root/b.state"
: >"$log"
( sleep 0.2; printf 'grew' >>"$log" ) &
writer=$!
run_poll "$log" "$state" 3
wait "$writer"
assert_chunk "grew" "wakeup on growth"
(( elapsed < 3.0 )) || die "wakeup on growth: expected wakeup before timeout, took ${elapsed}s"

# (c) Timeout with no growth: empty stdout, exit 4.
log="$tmp_root/c.log"
state="$tmp_root/c.state"
printf 'stale' >"$log"
print -- "5" >"$state"
run_poll "$log" "$state" 1
assert_rc 4 "timeout"
[[ ! -s "$out" ]] || die "timeout: expected empty stdout, got '$(cat "$out")'"
(( elapsed >= 1.0 )) || die "timeout: returned after ${elapsed}s, before max-wait elapsed"
assert_state 5 "timeout"

# (d) max-bytes caps each call; consecutive calls reassemble the burst losslessly.
log="$tmp_root/d.log"
state="$tmp_root/d.state"
printf 'abcdefghij' >"$log"
run_poll "$log" "$state" 3 4
assert_chunk "abcd" "cap chunk 1"
run_poll "$log" "$state" 3 4
assert_chunk "efgh" "cap chunk 2"
run_poll "$log" "$state" 3 4
assert_chunk "ij" "cap chunk 3"

# (e) Offset persists across calls: only new bytes on the next poll.
assert_state 10 "offset persistence"
printf 'xy' >>"$log"
run_poll "$log" "$state" 3 4
assert_chunk "xy" "offset persistence: new bytes"

# (f) Missing log waits (size 0) instead of erroring; picks up the file once created.
log="$tmp_root/f.log"
state="$tmp_root/f.state"
( sleep 0.2; printf 'born' >"$log" ) &
writer=$!
run_poll "$log" "$state" 3
wait "$writer"
assert_chunk "born" "missing log"

# (g) The default max-bytes=8192 caps a large burst when the 4th arg is omitted.
log="$tmp_root/g.log"
state="$tmp_root/g.state"
head -c 9000 /dev/zero | tr '\0' 'x' >"$log"
run_poll "$log" "$state" 3
assert_rc 0 "default cap"
[[ "$(wc -c <"$out")" -eq 8192 ]] || die "default cap: expected 8192 bytes, got $(wc -c <"$out")"
assert_state 8192 "default cap"

# (h) Leading-zero state offsets are read as decimal, not octal: "08" is not
# even a valid octal numeral, so octal parsing would crash bash arithmetic.
log="$tmp_root/h.log"
state="$tmp_root/h.state"
printf 'abcdefghijkl' >"$log"
print -- "08" >"$state"
run_poll "$log" "$state" 3
assert_chunk "ijkl" "leading-zero offset 08"
print -- "010" >"$state"
run_poll "$log" "$state" 3
assert_chunk "kl" "leading-zero offset 010"
state="$tmp_root/h2.state"
run_poll "$log" "$state" 3 010
assert_chunk "abcdefghij" "leading-zero max-bytes 010 reads as decimal 10"

# (j) A log shorter than the stored offset waits (and times out) but says so
# on stderr, since this is otherwise a silent forever-quiet failure mode.
log="$tmp_root/j.log"
state="$tmp_root/j.state"
printf 'tiny' >"$log"
print -- "20" >"$state"
run_poll "$log" "$state" 1
assert_rc 4 "shrunk log"
grep -q "log shorter than stored offset" "$tmp_root/err" || die "shrunk log: expected shorter-than-offset diagnostic on stderr"
assert_state 20 "shrunk log"

# (i) Hard I/O failure: an unreadable log with pending bytes exits 1 with a
# diagnostic on stderr and leaves the stored offset unadvanced.
log="$tmp_root/i.log"
state="$tmp_root/i.state"
printf 'secret' >"$log"
print -- "2" >"$state"
chmod 000 "$log"
run_poll "$log" "$state" 3
chmod 644 "$log"
assert_rc 1 "hard I/O"
grep -q "poll-stream: read failed" "$tmp_root/err" || die "hard I/O: expected read-failed diagnostic on stderr"
[[ ! -s "$out" ]] || die "hard I/O: expected empty stdout, got '$(cat "$out")'"
assert_state 2 "hard I/O"

# Bad usage: arg-count and numeric-validation failures exit 2 with usage on
# stderr and nothing on stdout.
assert_usage() {
  assert_rc 2 "$1"
  grep -q "usage: poll-stream" "$tmp_root/err" || die "$1: expected usage message on stderr"
  [[ ! -s "$out" ]] || die "$1: expected empty stdout, got '$(cat "$out")'"
}

run_poll
assert_usage "bad usage: no args"
run_poll "$log" "$state" 3 4 5
assert_usage "bad usage: too many args"
run_poll "$log" "$state" soon
assert_usage "bad usage: non-numeric max-wait-s"
run_poll "$log" "$state" 3 lots
assert_usage "bad usage: non-numeric max-bytes"
run_poll "$log" "$state" 3 0
assert_usage "bad usage: zero max-bytes"
run_poll "$log" "$state" 3 00
assert_usage "bad usage: all-zero max-bytes"

print -- "OK acpx-poll-stream"
