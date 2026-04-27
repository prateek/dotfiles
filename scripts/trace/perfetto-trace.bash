#!/usr/bin/env bash
# shellcheck shell=bash

TRACE_FILE="${TRACE_FILE:-}"
TRACE_CATEGORY="${TRACE_CATEGORY:-trace}"
TRACE_PROCESS_NAME="${TRACE_PROCESS_NAME:-host}"
TRACE_THREAD_NAME="${TRACE_THREAD_NAME:-main}"
TRACE_PID="${TRACE_PID:-1}"
TRACE_TID="${TRACE_TID:-1}"
TRACE_SORT_INDEX="${TRACE_SORT_INDEX:-0}"

TRACE_OPEN=0
TRACE_EVENT_WRITTEN=0

trace_now_us() {
  python3 - <<'PY' 2>/dev/null || printf '%s000000\n' "$(date +%s)"
import time
print(time.time_ns() // 1000)
PY
}

trace_json() {
  python3 - "$1" <<'PY' 2>/dev/null || printf '"%s"' "$1"
import json
import sys
print(json.dumps(sys.argv[1]))
PY
}

trace_write_event() {
  [ "$TRACE_OPEN" = "1" ] || return 0

  local comma=""
  if [ "$TRACE_EVENT_WRITTEN" = "1" ]; then
    comma=","
  fi
  printf '%s%s\n' "$comma" "$1" >>"$TRACE_FILE"
  TRACE_EVENT_WRITTEN=1
}

trace_init() {
  [ -n "$TRACE_FILE" ] || return 0
  mkdir -p "$(dirname "$TRACE_FILE")"
  printf '{"traceEvents":[\n' >"$TRACE_FILE"
  TRACE_OPEN=1
  TRACE_EVENT_WRITTEN=0

  trace_write_event "$(printf '{"name":"process_name","ph":"M","pid":%s,"tid":0,"args":{"name":%s}}' \
    "$TRACE_PID" "$(trace_json "$TRACE_PROCESS_NAME")")"
  trace_write_event "$(printf '{"name":"process_sort_index","ph":"M","pid":%s,"tid":0,"args":{"sort_index":%s}}' \
    "$TRACE_PID" "$TRACE_SORT_INDEX")"
  trace_write_event "$(printf '{"name":"thread_name","ph":"M","pid":%s,"tid":%s,"args":{"name":%s}}' \
    "$TRACE_PID" "$TRACE_TID" "$(trace_json "$TRACE_THREAD_NAME")")"
  trace_write_event "$(printf '{"name":"thread_sort_index","ph":"M","pid":%s,"tid":%s,"args":{"sort_index":%s}}' \
    "$TRACE_PID" "$TRACE_TID" "$TRACE_SORT_INDEX")"
}

trace_emit() {
  [ "$TRACE_OPEN" = "1" ] || return 0

  local name="$1"
  local start_us="$2"
  local end_us="$3"
  local rc="${4:-0}"
  local duration_us="$(( end_us - start_us ))"
  if [ "$duration_us" -lt 0 ]; then
    duration_us=0
  fi

  trace_write_event "$(printf '{"name":%s,"cat":%s,"ph":"X","ts":%s,"dur":%s,"pid":%s,"tid":%s,"args":{"rc":%s}}' \
    "$(trace_json "$name")" \
    "$(trace_json "$TRACE_CATEGORY")" \
    "$start_us" \
    "$duration_us" \
    "$TRACE_PID" \
    "$TRACE_TID" \
    "$rc")"
}

trace_finish() {
  [ "$TRACE_OPEN" = "1" ] || return 0
  printf ']}\n' >>"$TRACE_FILE"
  TRACE_OPEN=0
}

run_traced_logged() {
  local name="$1"
  shift

  local start_us end_us rc
  start_us="$(trace_now_us)"
  set +e
  if [ -n "${LOG_FILE:-}" ]; then
    "$@" >>"$LOG_FILE" 2>&1
  else
    "$@"
  fi
  rc=$?
  set -e
  end_us="$(trace_now_us)"
  trace_emit "$name" "$start_us" "$end_us" "$rc"
  return "$rc"
}

run_traced_tee() {
  local name="$1"
  shift

  local start_us end_us rc
  start_us="$(trace_now_us)"
  set +e
  if [ -n "${LOG_FILE:-}" ]; then
    "$@" 2>&1 | tee -a "$LOG_FILE"
    rc="${PIPESTATUS[0]}"
  else
    "$@"
    rc=$?
  fi
  set -e
  end_us="$(trace_now_us)"
  trace_emit "$name" "$start_us" "$end_us" "$rc"
  return "$rc"
}
