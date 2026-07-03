#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true

zmodload zsh/datetime
zmodload zsh/zpty
zmodload zsh/zselect

die() {
  print -u2 -- "plist-hooks: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
hooks_src="$DOTFILES_ROOT/scripts/chezmoi-hooks/plist-hooks.sh"
guard_src="$hooks_src"
post_src="$hooks_src"

[[ -x $hooks_src ]] || die "missing plist-hooks script: $hooks_src"

bash -n "$hooks_src" || die "plist-hooks script syntax error"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

# -- Stub helpers ------------------------------------------------------------

write_chezmoi_status_stub() {
  # $1: name (no extension); $2: stdout payload (printf-style line)
  # Stub behaves like real chezmoi: emits the payload only when called as
  # `chezmoi status --path-style=absolute [--destination <dir>]`. The
  # guard always passes --path-style=absolute and adds --destination iff
  # CHEZMOI_DEST_DIR is set. Either invocation is accepted.
  local dir="$tmp_root/stubs-$1"
  mkdir -p "$dir"
  cat >"$dir/chezmoi" <<EOF
#!/usr/bin/env bash
case "\$*" in
  "status --path-style=absolute"|"status --path-style=absolute --destination "*)
$2
    ;;
esac
EOF
  chmod +x "$dir/chezmoi"
  print -- "$dir"
}

# Builds a guard copy with /usr/bin/lsappinfo redirected to a stub that
# claims the listed bundle ids are running. Empty list = no apps running.
guard_copy_with_lsappinfo() {
  # $1: target script path; $2..$N: running bundle ids
  local target="$1"; shift
  local stubdir="$tmp_root/lsapp-stub-${target##*/}"
  mkdir -p "$stubdir"
  if (( $# == 0 )); then
    cat >"$stubdir/lsappinfo" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  else
    {
      print -- '#!/usr/bin/env bash'
      print -- 'if [[ "$1" == "info" && "$3" == "bundleid" ]]; then'
      print -- '  case "$4" in'
      for id in "$@"; do
        print -- "    \"$id\") printf '\"LSBundleIdentifier\"=\"%s\"\\n' \"\$4\";;"
      done
      print -- '  esac'
      print -- 'fi'
    } >"$stubdir/lsappinfo"
  fi
  chmod +x "$stubdir/lsappinfo"
  cp "$guard_src" "$target"
  sed -i '' "s|/usr/bin/lsappinfo|$stubdir/lsappinfo|g" "$target"
}

# Builds a post-hook copy with /usr/bin/{killall,open} redirected to stubs
# that append "[killall|open] <args>" lines to the named log file.
post_copy_with_logging() {
  # $1: target script path; $2: log file path
  local target="$1" log="$2"
  local stubdir="$tmp_root/post-stub-${target##*/}"
  mkdir -p "$stubdir"
  cat >"$stubdir/killall" <<EOF
#!/usr/bin/env bash
echo "[killall] \$*" >> "$log"
EOF
  cat >"$stubdir/open" <<EOF
#!/usr/bin/env bash
echo "[open] \$*" >> "$log"
EOF
  chmod +x "$stubdir/killall" "$stubdir/open"
  cp "$post_src" "$target"
  sed -i '' "s|/usr/bin/killall|$stubdir/killall|g; s|/usr/bin/open|$stubdir/open|g" "$target"
}

# One lsappinfo/osascript stub pair, shared by every interactive case: which
# ids are running and which of those are "stuck" (osascript is invoked but
# they never actually quit) is chosen per-run via STUB_RUNNING_IDS /
# STUB_STUCK_IDS env vars rather than baked into the script text.
write_quit_stubs() {
  local dir="$1"
  mkdir -p "$dir"
  cat >"$dir/lsappinfo" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "info" && "$3" == "bundleid" ]]; then
  id="$4"
  case " $STUB_RUNNING_IDS " in
    *" $id "*) ;;
    *) exit 0 ;;
  esac
  [[ -e "$STUB_MARKERS_DIR/$id.quit" ]] && exit 0
  printf '"LSBundleIdentifier"="%s"\n' "$id"
fi
EOF
  cat >"$dir/osascript" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$STUB_MARKERS_DIR/osascript.log"
id="$(printf '%s\n' "$2" | sed -n 's/.*id "\(.*\)" to quit.*/\1/p')"
case " $STUB_STUCK_IDS " in
  *" $id "*) ;;
  *) : > "$STUB_MARKERS_DIR/$id.quit" ;;
esac
EOF
  chmod +x "$dir/lsappinfo" "$dir/osascript"
}

# Runs a guard copy under a real pty (chezmoi wires a hook's stdin/stdout to
# its own, so the guard only takes its interactive branch under a real tty —
# see run_adapter_tty in tests/chezmoi-drift-banner.zsh for the same idiom).
# $1: output file to write combined stdout+stderr to (the guard's own exit
# code is appended as "EXIT_CODE:<n>" so the caller can assert on it without
# a second pty run); $2: guard copy path; $3: env assignment lines to export
# inside the pty; $4: response to send at the "[Y/n]" prompt ("" = bare
# Enter). Writes to a file rather than returning via command substitution:
# `$(...)` runs in a subshell, and zpty's job bookkeeping gets confused
# spawned from inside one.
run_guard_interactive() {
  local outfile="$1" guard="$2" envlines="$3" response="$4"
  local name="ph_${RANDOM}_${RANDOM}"
  local runner="$tmp_root/runner_${name}.sh"
  cat >"$runner" <<EOF
#!/usr/bin/env bash
$envlines
"$guard" pre
echo "EXIT_CODE:\$?"
EOF
  chmod +x "$runner"

  local output='' chunk='' start
  zpty -b "$name" "$runner"

  start=$EPOCHREALTIME
  while (( EPOCHREALTIME - start < 5 )); do
    if zpty -rt "$name" chunk 2>/dev/null; then
      output+="$chunk"
      [[ "$output" == *'[Y/n]'* ]] && break
    fi
    zselect -t 0.02 >/dev/null 2>&1 || true
  done
  # zpty -w with an empty string sends nothing at all (not even the trailing
  # newline that non-empty strings get) - send a bare newline explicitly for
  # the default-yes ("" = Enter) case.
  if [[ -z "$response" ]]; then
    zpty -w -n "$name" $'\n'
  else
    zpty -w "$name" "$response"
  fi

  local quiet_start=$EPOCHREALTIME
  start=$EPOCHREALTIME
  while (( EPOCHREALTIME - start < 10 )); do
    if zpty -rt "$name" chunk 2>/dev/null; then
      output+="$chunk"
      quiet_start=$EPOCHREALTIME
      continue
    fi
    [[ "$output" == *'EXIT_CODE:'* ]] && (( EPOCHREALTIME - quiet_start > 0.3 )) && break
    zselect -t 0.05 >/dev/null 2>&1 || true
  done
  zpty -d "$name" 2>/dev/null || true

  print -r -- "${output//$'\r'/}" > "$outfile"
}

# -- guard-running-apps tests -----------------------------------------------

# Case A: pending change, app running -> exit 1
home_a="$tmp_root/home_a"; state_a="$tmp_root/state_a"
mkdir -p "$home_a" "$state_a"
stubs_a="$(write_chezmoi_status_stub a "  printf ' M %s/Library/Preferences/com.example.foo.plist\n' \"\$HOME\"")"
guard_a="$tmp_root/guard_a.sh"
guard_copy_with_lsappinfo "$guard_a" com.example.foo
set +e
PATH="$stubs_a:$PATH" XDG_STATE_HOME="$state_a" HOME="$home_a" bash "$guard_a" pre >/dev/null 2>&1
rc_a=$?
set -e
[[ $rc_a -eq 1 ]] || die "case A: expected exit 1, got $rc_a"
[[ "$(<"$state_a/dotfiles/plist-pending.txt")" == "com.example.foo" ]] || die "case A: pending file mismatch"

# Case B: pending change, app NOT running -> exit 0
home_b="$tmp_root/home_b"; state_b="$tmp_root/state_b"
mkdir -p "$home_b" "$state_b"
stubs_b="$(write_chezmoi_status_stub b "  printf ' M %s/Library/Preferences/com.example.foo.plist\n' \"\$HOME\"")"
guard_b="$tmp_root/guard_b.sh"
guard_copy_with_lsappinfo "$guard_b"  # no running apps
PATH="$stubs_b:$PATH" XDG_STATE_HOME="$state_b" HOME="$home_b" bash "$guard_b" pre >/dev/null 2>&1
[[ "$(<"$state_b/dotfiles/plist-pending.txt")" == "com.example.foo" ]] || die "case B: pending file mismatch"

# Case C: SKIP=1 short-circuits the guard (now a single env var that
# also short-circuits the post-hook; see Case K).
home_c="$tmp_root/home_c"; state_c="$tmp_root/state_c"
mkdir -p "$home_c" "$state_c"
stubs_c="$(write_chezmoi_status_stub c "  printf ' M %s/Library/Preferences/com.example.foo.plist\n' \"\$HOME\"")"
guard_c="$tmp_root/guard_c.sh"
guard_copy_with_lsappinfo "$guard_c" com.example.foo
PATH="$stubs_c:$PATH" XDG_STATE_HOME="$state_c" HOME="$home_c" \
  DOTFILES_SKIP_PLIST_HOOKS=1 bash "$guard_c" pre >/dev/null 2>&1

# Case D: no pending changes -> exit 0, empty pending file
home_d="$tmp_root/home_d"; state_d="$tmp_root/state_d"
mkdir -p "$home_d" "$state_d"
stubs_d="$(write_chezmoi_status_stub d "  :")"
guard_d="$tmp_root/guard_d.sh"
guard_copy_with_lsappinfo "$guard_d"
PATH="$stubs_d:$PATH" XDG_STATE_HOME="$state_d" HOME="$home_d" bash "$guard_d" pre >/dev/null 2>&1
[[ ! -s "$state_d/dotfiles/plist-pending.txt" ]] || die "case D: pending file must be empty"

# Case E: sandbox container path is recognized
home_e="$tmp_root/home_e"; state_e="$tmp_root/state_e"
mkdir -p "$home_e" "$state_e"
stubs_e="$(write_chezmoi_status_stub e "  printf ' M %s/Library/Containers/com.example.bar/Data/Library/Preferences/com.example.bar.plist\n' \"\$HOME\"")"
guard_e="$tmp_root/guard_e.sh"
guard_copy_with_lsappinfo "$guard_e"  # not running
PATH="$stubs_e:$PATH" XDG_STATE_HOME="$state_e" HOME="$home_e" bash "$guard_e" pre >/dev/null 2>&1
[[ "$(<"$state_e/dotfiles/plist-pending.txt")" == "com.example.bar" ]] || die "case E: sandbox path not recognized"

# -- post-apply-plists tests ------------------------------------------------

# Case F: empty pending file -> no-op, file removed
state_f="$tmp_root/state_f"
mkdir -p "$state_f/dotfiles"
: > "$state_f/dotfiles/plist-pending.txt"
post_f="$tmp_root/post_f.sh"
log_f="$tmp_root/calls_f.log"
post_copy_with_logging "$post_f" "$log_f"
XDG_STATE_HOME="$state_f" bash "$post_f" post
[[ ! -e "$state_f/dotfiles/plist-pending.txt" ]] || die "case F: file should be removed"
[[ ! -s "$log_f" ]] || die "case F: no commands should have run"

# Case G: missing pending file -> no-op
state_g="$tmp_root/state_g"
post_g="$tmp_root/post_g.sh"
log_g="$tmp_root/calls_g.log"
post_copy_with_logging "$post_g" "$log_g"
XDG_STATE_HOME="$state_g" bash "$post_g" post
[[ ! -e "$log_g" ]] || die "case G: no commands should have run"

# Case H: pending list, no relaunch -> killall once, no opens
state_h="$tmp_root/state_h"
mkdir -p "$state_h/dotfiles"
printf 'com.example.foo\ncom.example.bar\n' > "$state_h/dotfiles/plist-pending.txt"
post_h="$tmp_root/post_h.sh"
log_h="$tmp_root/calls_h.log"
post_copy_with_logging "$post_h" "$log_h"
XDG_STATE_HOME="$state_h" bash "$post_h" post
[[ ! -e "$state_h/dotfiles/plist-pending.txt" ]] || die "case H: file should be removed"
[[ "$(grep -c killall "$log_h")" -eq 1 ]] || die "case H: expected 1 killall, got $(grep -c killall "$log_h")"
[[ "$(grep -c '\[open\]' "$log_h")" -eq 0 ]] || die "case H: expected 0 opens"

# Case I: pending list + RELAUNCH=1 -> killall once + open per id
state_i="$tmp_root/state_i"
mkdir -p "$state_i/dotfiles"
printf 'com.example.foo\ncom.example.bar\n' > "$state_i/dotfiles/plist-pending.txt"
post_i="$tmp_root/post_i.sh"
log_i="$tmp_root/calls_i.log"
post_copy_with_logging "$post_i" "$log_i"
XDG_STATE_HOME="$state_i" DOTFILES_RELAUNCH_AFTER_APPLY=1 bash "$post_i" post
[[ "$(grep -c killall "$log_i")" -eq 1 ]] || die "case I: expected 1 killall"
[[ "$(grep -c '\[open\]' "$log_i")" -eq 2 ]] || die "case I: expected 2 opens, got $(grep -c '\[open\]' "$log_i")"

# Case J: chezmoi dry-run forms → both hooks early-exit, no side effects.
# Cobra accepts --dry-run, --dry-run=true, -n, and short-flag bundles
# containing n (-nv, -vn). All must skip; --dry-run=false must NOT skip.
guard_j_base="$tmp_root/guard_j_base.sh"
guard_copy_with_lsappinfo "$guard_j_base" com.example.foo

run_pre_dryrun_case() {
  # $1: label; $2: CHEZMOI_ARGS value; $3: expect_skip (yes|no)
  local label="$1" args="$2" expect="$3"
  local home="$tmp_root/home_j_$label" state="$tmp_root/state_j_$label"
  mkdir -p "$home" "$state"
  local stubs
  stubs="$(write_chezmoi_status_stub "j_$label" "  printf ' M %s/Library/Preferences/com.example.foo.plist\n' \"\$HOME\"")"
  local guard_copy="$tmp_root/guard_j_$label.sh"
  cp "$guard_j_base" "$guard_copy"
  set +e
  CHEZMOI_ARGS="$args" PATH="$stubs:$PATH" XDG_STATE_HOME="$state" HOME="$home" \
    bash "$guard_copy" pre >/dev/null 2>&1
  local rc=$?
  set -e
  if [[ $expect == yes ]]; then
    [[ $rc -eq 0 ]] || die "case J/$label: expected skip exit 0, got $rc"
    [[ ! -s "$state/dotfiles/plist-pending.txt" ]] || die "case J/$label: pre-hook must not write state on dry-run"
  else
    [[ $rc -eq 1 ]] || die "case J/$label: expected guard to fire (rc=1), got $rc"
    [[ -s "$state/dotfiles/plist-pending.txt" ]] || die "case J/$label: pre-hook should write state for non-dry-run"
  fi
}

run_pre_dryrun_case dryrun     "chezmoi apply --dry-run"      yes
run_pre_dryrun_case dryrun_eq  "chezmoi apply --dry-run=true" yes
run_pre_dryrun_case short_n    "chezmoi apply -n"             yes
run_pre_dryrun_case short_nv   "chezmoi apply -nv"            yes
run_pre_dryrun_case short_vn   "chezmoi apply -vn"            yes
run_pre_dryrun_case dryrun_no  "chezmoi apply --dry-run=false" no
run_pre_dryrun_case verbose    "chezmoi apply -v"             no

run_post_dryrun_case() {
  local label="$1" args="$2" expect="$3"
  local state="$tmp_root/state_jp_$label"
  mkdir -p "$state/dotfiles"
  printf 'com.example.foo\n' > "$state/dotfiles/plist-pending.txt"
  local post_copy="$tmp_root/post_j_$label.sh"
  local log="$tmp_root/calls_j_$label.log"
  post_copy_with_logging "$post_copy" "$log"
  CHEZMOI_ARGS="$args" XDG_STATE_HOME="$state" bash "$post_copy" post
  if [[ $expect == yes ]]; then
    [[ ! -e "$log" ]] || die "case J/$label: post-hook must not invoke killall/open on dry-run"
    [[ -s "$state/dotfiles/plist-pending.txt" ]] || die "case J/$label: post-hook must leave state on dry-run"
  else
    [[ "$(grep -c killall "$log")" -eq 1 ]] || die "case J/$label: post-hook should kill cfprefsd"
  fi
}

run_post_dryrun_case dryrun    "chezmoi apply --dry-run"       yes
run_post_dryrun_case dryrun_eq "chezmoi apply --dry-run=true"  yes
run_post_dryrun_case short_nv  "chezmoi apply -nv"             yes
run_post_dryrun_case dryrun_no "chezmoi apply --dry-run=false" no

# Case K: DOTFILES_SKIP_PLIST_HOOKS=1 short-circuits both hooks. The
# sandboxed-apply path in scripts/audit/zsh-fresh-shells.zsh sets this
# because running apps only read their real ~/Library/Preferences, so
# the race premise doesn't apply when chezmoi targets a temp HOME.

# K1 (pre-hook): SKIP=1 → exit 0 immediately, no chezmoi call, no state.
home_k1="$tmp_root/home_k1"; state_k1="$tmp_root/state_k1"
mkdir -p "$home_k1" "$state_k1"
# Stub chezmoi to fail loudly if called — guard must short-circuit first.
stub_dir_k1="$tmp_root/stubs-k1"
mkdir -p "$stub_dir_k1"
cat >"$stub_dir_k1/chezmoi" <<'EOF'
#!/usr/bin/env bash
echo "FAIL: chezmoi was invoked despite SKIP=1; guard must short-circuit" >&2
exit 99
EOF
chmod +x "$stub_dir_k1/chezmoi"
guard_k1="$tmp_root/guard_k1.sh"
guard_copy_with_lsappinfo "$guard_k1" com.example.foo
set +e
DOTFILES_SKIP_PLIST_HOOKS=1 \
  PATH="$stub_dir_k1:$PATH" XDG_STATE_HOME="$state_k1" HOME="$home_k1" \
  bash "$guard_k1" pre >/dev/null 2>&1
rc_k1=$?
set -e
[[ $rc_k1 -eq 0 ]] || die "case K1: SKIP=1 must exit 0, got $rc_k1"
[[ ! -e "$state_k1/dotfiles/plist-pending.txt" ]] || die "case K1: must not write state file when skipping"

# K2 (post-hook): SKIP=1 → exit 0 immediately even with non-empty state,
#                 no killall, state file untouched.
state_k2="$tmp_root/state_k2"
mkdir -p "$state_k2/dotfiles"
printf 'com.example.foo\n' > "$state_k2/dotfiles/plist-pending.txt"
post_k2="$tmp_root/post_k2.sh"
log_k2="$tmp_root/calls_k2.log"
post_copy_with_logging "$post_k2" "$log_k2"
DOTFILES_SKIP_PLIST_HOOKS=1 XDG_STATE_HOME="$state_k2" bash "$post_k2" post
[[ ! -e "$log_k2" ]] || die "case K2: SKIP=1 post-hook must not call killall/open"
[[ -s "$state_k2/dotfiles/plist-pending.txt" ]] || die "case K2: SKIP=1 post-hook must leave state file untouched"

# -- interactive quit-and-relaunch prompt (pre-hook, under a real pty) ------

quit_stub_dir="$tmp_root/quit-stubs"
write_quit_stubs "$quit_stub_dir"

guard_copy_with_quit_stubs() {
  local target="$1"
  cp "$hooks_src" "$target"
  sed -i '' "s|/usr/bin/lsappinfo|$quit_stub_dir/lsappinfo|g; s|/usr/bin/osascript|$quit_stub_dir/osascript|g" "$target"
}

quit_env_lines() {
  # $1 stub PATH prefix; $2 XDG_STATE_HOME; $3 HOME; $4 STUB_RUNNING_IDS;
  # $5 STUB_STUCK_IDS; $6 STUB_MARKERS_DIR; $7 extra env line (optional)
  print -r -- "export PATH=\"$1:\$PATH\""
  print -r -- "export XDG_STATE_HOME=\"$2\""
  print -r -- "export HOME=\"$3\""
  print -r -- "export STUB_RUNNING_IDS=\"$4\""
  print -r -- "export STUB_STUCK_IDS=\"$5\""
  print -r -- "export STUB_MARKERS_DIR=\"$6\""
  [[ -n "${7:-}" ]] && print -r -- "$7"
}

# Case L: interactive, single "yes" answers for two running apps, both
# actually quit -> exit 0, osascript invoked for both, both land in
# plist-quit-by-guard.txt.
home_l="$tmp_root/home_l"; state_l="$tmp_root/state_l"; markers_l="$tmp_root/markers_l"
mkdir -p "$home_l" "$state_l" "$markers_l"
stubs_l="$(write_chezmoi_status_stub l "  printf ' M %s/Library/Preferences/com.example.foo.plist\n M %s/Library/Preferences/com.example.bar.plist\n' \"\$HOME\" \"\$HOME\"")"
guard_l="$tmp_root/guard_l.sh"
guard_copy_with_quit_stubs "$guard_l"
outfile_l="$tmp_root/out_l.txt"
run_guard_interactive "$outfile_l" "$guard_l" \
  "$(quit_env_lines "$stubs_l" "$state_l" "$home_l" "com.example.foo com.example.bar" "" "$markers_l")" \
  ""
out_l="$(<"$outfile_l")"
[[ "$out_l" == *'EXIT_CODE:0'* ]] || die "case L: expected exit 0; got: $out_l"
grep -q "com.example.foo" "$markers_l/osascript.log" || die "case L: osascript not called for foo"
grep -q "com.example.bar" "$markers_l/osascript.log" || die "case L: osascript not called for bar"
quit_l="$state_l/dotfiles/plist-quit-by-guard.txt"
[[ -s "$quit_l" ]] || die "case L: quit-by-guard file missing/empty"
grep -qx "com.example.foo" "$quit_l" || die "case L: foo missing from quit-by-guard"
grep -qx "com.example.bar" "$quit_l" || die "case L: bar missing from quit-by-guard"

# Case M: interactive, answers no -> exit 0, osascript never called, nothing
# quit, pending list untouched (risk accepted, apply proceeds anyway).
home_m="$tmp_root/home_m"; state_m="$tmp_root/state_m"; markers_m="$tmp_root/markers_m"
mkdir -p "$home_m" "$state_m" "$markers_m"
stubs_m="$(write_chezmoi_status_stub m "  printf ' M %s/Library/Preferences/com.example.foo.plist\n M %s/Library/Preferences/com.example.bar.plist\n' \"\$HOME\" \"\$HOME\"")"
guard_m="$tmp_root/guard_m.sh"
guard_copy_with_quit_stubs "$guard_m"
outfile_m="$tmp_root/out_m.txt"
run_guard_interactive "$outfile_m" "$guard_m" \
  "$(quit_env_lines "$stubs_m" "$state_m" "$home_m" "com.example.foo com.example.bar" "" "$markers_m")" \
  "n"
out_m="$(<"$outfile_m")"
[[ "$out_m" == *'EXIT_CODE:0'* ]] || die "case M: expected exit 0; got: $out_m"
[[ ! -e "$markers_m/osascript.log" ]] || die "case M: osascript must not be called when declining"
[[ ! -s "$state_m/dotfiles/plist-quit-by-guard.txt" ]] || die "case M: quit-by-guard file must stay empty"
grep -qx "com.example.foo" "$state_m/dotfiles/plist-pending.txt" || die "case M: pending file missing foo"
grep -qx "com.example.bar" "$state_m/dotfiles/plist-pending.txt" || die "case M: pending file missing bar"

# Case N: interactive, answers yes, one app quits and the other never does
# (a save dialog is "stuck" open) -> exit 0 either way (never blocks), only
# the one that actually quit lands in plist-quit-by-guard.txt. Timeout
# forced to 1s so the case doesn't wait out the real 20s default.
home_n="$tmp_root/home_n"; state_n="$tmp_root/state_n"; markers_n="$tmp_root/markers_n"
mkdir -p "$home_n" "$state_n" "$markers_n"
stubs_n="$(write_chezmoi_status_stub n "  printf ' M %s/Library/Preferences/com.example.foo.plist\n M %s/Library/Preferences/com.example.bar.plist\n' \"\$HOME\" \"\$HOME\"")"
guard_n="$tmp_root/guard_n.sh"
guard_copy_with_quit_stubs "$guard_n"
outfile_n="$tmp_root/out_n.txt"
run_guard_interactive "$outfile_n" "$guard_n" \
  "$(quit_env_lines "$stubs_n" "$state_n" "$home_n" "com.example.foo com.example.bar" "com.example.bar" "$markers_n" \
    "export DOTFILES_PLIST_QUIT_TIMEOUT_SECS=1")" \
  ""
out_n="$(<"$outfile_n")"
[[ "$out_n" == *'EXIT_CODE:0'* ]] || die "case N: expected exit 0 (never blocks); got: $out_n"
[[ "$out_n" == *"com.example.bar did not quit"* ]] || die "case N: expected a did-not-quit warning for bar"
quit_n="$state_n/dotfiles/plist-quit-by-guard.txt"
grep -qx "com.example.foo" "$quit_n" || die "case N: foo (which quit) missing from quit-by-guard"
! grep -qx "com.example.bar" "$quit_n" || die "case N: bar (stuck) should not be in quit-by-guard"

# -- post-hook relaunch selection --------------------------------------------

# Case O: plist-quit-by-guard.txt relaunches unconditionally; an id only in
# plist-pending.txt (RELAUNCH_AFTER_APPLY unset) does not.
state_o="$tmp_root/state_o"
mkdir -p "$state_o/dotfiles"
printf 'com.example.foo\ncom.example.bar\n' > "$state_o/dotfiles/plist-pending.txt"
printf 'com.example.foo\n' > "$state_o/dotfiles/plist-quit-by-guard.txt"
post_o="$tmp_root/post_o.sh"
log_o="$tmp_root/calls_o.log"
post_copy_with_logging "$post_o" "$log_o"
XDG_STATE_HOME="$state_o" bash "$post_o" post
[[ "$(grep -c '\[open\]' "$log_o")" -eq 1 ]] || die "case O: expected exactly 1 open, got $(grep -c '\[open\]' "$log_o")"
grep -q 'com.example.foo' "$log_o" || die "case O: expected an open for com.example.foo"
! grep -q 'com.example.bar' "$log_o" || die "case O: com.example.bar should not have been opened"

# Case P: after a run, plist-quit-by-guard.txt is removed alongside the
# pending file.
[[ ! -e "$state_o/dotfiles/plist-quit-by-guard.txt" ]] || die "case P: quit-by-guard file should be removed"
[[ ! -e "$state_o/dotfiles/plist-pending.txt" ]] || die "case P: pending file should be removed"

# Case Q: an id in both plist-quit-by-guard.txt and (RELAUNCH_AFTER_APPLY=1)
# plist-pending.txt is only opened once.
state_q="$tmp_root/state_q"
mkdir -p "$state_q/dotfiles"
printf 'com.example.foo\ncom.example.bar\n' > "$state_q/dotfiles/plist-pending.txt"
printf 'com.example.foo\n' > "$state_q/dotfiles/plist-quit-by-guard.txt"
post_q="$tmp_root/post_q.sh"
log_q="$tmp_root/calls_q.log"
post_copy_with_logging "$post_q" "$log_q"
XDG_STATE_HOME="$state_q" DOTFILES_RELAUNCH_AFTER_APPLY=1 bash "$post_q" post
[[ "$(grep -c '\[open\]' "$log_q")" -eq 2 ]] || die "case Q: expected 2 opens (foo deduped), got $(grep -c '\[open\]' "$log_q")"
[[ "$(grep -c 'com.example.foo' "$log_q")" -eq 1 ]] || die "case Q: com.example.foo should only be opened once"

print -- "OK plist-hooks"
