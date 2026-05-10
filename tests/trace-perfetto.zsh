#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "trace-perfetto: $*"
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || die "expected file: $1"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || die "expected output to contain: $needle"
}

assert_file_not_contains() {
  local file="$1"
  local needle="$2"
  if grep -Fq "$needle" "$file"; then
    die "expected $file not to contain: $needle"
  fi
}

assert_private_mode() {
  python3 - "$1" <<'PY'
import os
import stat
import sys

path = sys.argv[1]
mode = stat.S_IMODE(os.stat(path).st_mode)
assert mode & 0o077 == 0, f"{path} mode {mode:o} is visible to group/other"
PY
}

DOTFILES_ROOT="${0:A:h:h}"
TRACE_DIR="$DOTFILES_ROOT/scripts/trace"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

fixture="$TMP_ROOT/xtrace.log"
cat >"$fixture" <<'EOF'
ordinary stderr survives outside the trace parser
+DFX|v=1|ts=1.000000|pid=42|sub=0|src=/tmp/install.sh|line=10|name=/tmp/install.sh|stack=|ctx=toplevel| install_main
+DFX|v=1|ts=1.010000|pid=42|sub=0|src=/tmp/install.sh|line=20|name=install_brewfile|stack=install_brewfile,install_main|ctx=toplevel,shfunc| API_TOKEN=supersecret brew bundle install --token abc123
+DFX|v=1|ts=1.050000|pid=42|sub=0|src=/tmp/install.sh|line=21|name=install_brewfile|stack=install_brewfile,install_main|ctx=toplevel,shfunc| echo done
+DFX|v=1|ts=not-a-time|pid=42|sub=0|src=/tmp/install.sh|line=22|name=bad|stack=|ctx=toplevel| ignored
EOF

converted="$TMP_ROOT/fixture.perfetto.json"
summary="$TMP_ROOT/summary.json"
"$TRACE_DIR/xtrace-to-perfetto" --output "$converted" --summary-output "$summary" --process-name fixture --pid-offset 100 "$fixture"
assert_file "$converted"
assert_file "$summary"
python3 -m json.tool "$converted" >/dev/null
python3 -m json.tool "$summary" >/dev/null
assert_file_not_contains "$converted" "supersecret"
assert_file_not_contains "$converted" "abc123"

python3 - "$converted" <<'PY'
import json
import sys
from pathlib import Path

events = json.loads(Path(sys.argv[1]).read_text())["traceEvents"]
names = [event.get("name", "") for event in events]
assert any("brew bundle" in name for name in names), names
assert any(name == "Install Brewfile" for name in names), names
assert not any(name.startswith("0") and "brew" in name.lower() for name in names), names
assert any(event.get("name") == "process_name" for event in events), events

process_names = {event["pid"]: event["args"]["name"] for event in events if event.get("name") == "process_name"}
assert process_names[1420] == "fixture pid 42 - semantic steps", process_names
assert process_names[1421] == "fixture pid 42 - major commands", process_names
assert process_names[1422] == "fixture pid 42 - all commands", process_names

thread_names = {(event["pid"], event["tid"]): event["args"]["name"] for event in events if event.get("name") == "thread_name"}
assert "major commands" in thread_names.values(), thread_names
assert "all commands" in thread_names.values(), thread_names
assert "Install Main" in thread_names.values(), thread_names
assert "  Install Brewfile" in thread_names.values(), thread_names

major_commands = [event for event in events if event.get("cat") == "zsh-major-command" and "brew bundle" in event.get("name", "")]
assert major_commands, events

semantic_events = [event for event in events if event.get("cat") == "zsh-function" and event.get("pid") == 1420]
semantic_names = {event["name"] for event in semantic_events}
assert "Install Main" in semantic_names, semantic_names
assert "Install Brewfile" in semantic_names, semantic_names
assert all(event["pid"] == 1420 for event in semantic_events), semantic_events

command_pids = {event["pid"] for event in events if event.get("cat") in ("zsh-command", "zsh-major-command")}
semantic_pids = {event["pid"] for event in semantic_events}
assert command_pids and semantic_pids, (command_pids, semantic_pids)
assert command_pids.isdisjoint(semantic_pids), (command_pids, semantic_pids)

metadata_by_track = {
    (event["pid"], event["tid"]): event["args"]["name"]
    for event in events
    if event.get("name") == "thread_name"
}
expected_tracks = {
    (1420, 1): "Install Main",
    (1420, 2): "  Install Brewfile",
    (1421, 1): "major commands",
    (1422, 1): "all commands",
}
assert expected_tracks.items() <= metadata_by_track.items(), metadata_by_track

x_events = [event for event in events if event.get("ph") == "X"]
for event in x_events:
    assert (event["pid"], event["tid"]) in metadata_by_track, event
    assert isinstance(event["ts"], int), event
    assert event["dur"] > 0, event

assert all(event["pid"] == 1422 for event in x_events if event.get("cat") == "zsh-command")
assert all(event["pid"] == 1421 for event in x_events if event.get("cat") == "zsh-major-command")
assert all(event["pid"] == 1420 for event in semantic_events)

semantic_layout = {
    event["name"]: event["tid"]
    for event in x_events
    if event.get("cat") == "zsh-function" and event.get("pid") == 1420
}
assert semantic_layout["Install Main"] == 1, semantic_layout
assert semantic_layout["Install Brewfile"] == 2, semantic_layout
PY

viewer_url="$("$TRACE_DIR/open-perfetto" "$converted" --port 0 --idle-timeout 1 --no-open --print-url 2>"$TMP_ROOT/open-perfetto.stderr")"
assert_contains "$viewer_url" "https://ui.perfetto.dev/#!/?url=http%3A%2F%2F127.0.0.1%3A"

sample="$TMP_ROOT/sample.zsh"
cat >"$sample" <<'EOF'
#!/usr/bin/env zsh
set -e
outer() {
  inner
}
inner() {
  echo "sample ok"
}
outer
EOF
chmod +x "$sample"

run_dir="$TMP_ROOT/run"
"$TRACE_DIR/run-zsh" --output-dir "$run_dir" --process-name sample -- "$sample" >/dev/null 2>"$TMP_ROOT/run-zsh.stderr"
assert_file "$run_dir/stdout.log"
assert_file "$run_dir/stderr.log"
assert_file "$run_dir/manifest.json"
assert_file "$run_dir/trace.perfetto.json"
assert_private_mode "$run_dir"
assert_private_mode "$run_dir/stdout.log"
assert_private_mode "$run_dir/stderr.log"
assert_private_mode "$run_dir/trace.perfetto.json"
grep -Fq "sample ok" "$run_dir/stdout.log" || die "expected run-zsh stdout capture"
python3 -m json.tool "$run_dir/trace.perfetto.json" >/dev/null

merged="$TMP_ROOT/merged.perfetto.json"
"$TRACE_DIR/merge-perfetto" --output "$merged" "$converted" "$run_dir/trace.perfetto.json" >/dev/null
assert_file "$merged"
assert_private_mode "$merged"
python3 -m json.tool "$merged" >/dev/null

set +e
"$TRACE_DIR/merge-perfetto" --output "$TMP_ROOT/missing.perfetto.json" "$converted" "$TMP_ROOT/does-not-exist.perfetto.json" >"$TMP_ROOT/merge-missing.stdout" 2>"$TMP_ROOT/merge-missing.stderr"
merge_missing_rc=$?
set -e
[[ "$merge_missing_rc" -ne 0 ]] || die "expected merge-perfetto to fail for a missing input"
grep -Fq "trace file not found" "$TMP_ROOT/merge-missing.stderr" || die "expected missing trace error"

fail_dir="$TMP_ROOT/fail"
set +e
"$TRACE_DIR/run-zsh" --output-dir "$fail_dir" --process-name failing -- zsh -c 'echo failing; false' >/dev/null 2>"$TMP_ROOT/fail-zsh.stderr"
fail_rc=$?
set -e
[[ "$fail_rc" -eq 1 ]] || die "expected failing command rc=1, got $fail_rc"
assert_file "$fail_dir/manifest.json"
assert_file "$fail_dir/trace.perfetto.json"

convert_fail_dir="$TMP_ROOT/convert-fail"
mkdir -p "$convert_fail_dir/trace.perfetto.json"
set +e
"$TRACE_DIR/run-zsh" --output-dir "$convert_fail_dir" --process-name convert-fail -- zsh -c 'true' >/dev/null 2>"$TMP_ROOT/convert-fail.stderr"
convert_fail_rc=$?
set -e
[[ "$convert_fail_rc" -ne 0 ]] || die "expected run-zsh to fail when conversion fails after a successful command"
assert_file "$convert_fail_dir/manifest.json"
grep -Fq "xtrace conversion failed" "$TMP_ROOT/convert-fail.stderr" || die "expected conversion failure warning"
python3 - "$convert_fail_dir/manifest.json" <<'PY'
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text())
assert manifest["command_rc"] == 0, manifest
assert manifest["convert_rc"] != 0, manifest
PY

help_output="$(bash "$DOTFILES_ROOT/scripts/vm/test-install-tart.sh" --help)"
assert_contains "$help_output" "DOTFILES_TRACE=1"
# install.sh was retired in favor of the chezmoi one-liner; the legacy
# bootstrap-trace assertions that targeted install.sh are no longer applicable.
assert_file_not_contains "$DOTFILES_ROOT/scripts/vm/test-install-tart.sh" "DOTFILES_BOOTSTRAP_TRACE_FILE"

print -- "OK trace-perfetto"
