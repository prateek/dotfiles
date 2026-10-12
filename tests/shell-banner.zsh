#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

zmodload zsh/datetime
zmodload zsh/zpty
zmodload zsh/zselect

die() {
  print -u2 -- "shell-banner: $*"
  exit 1
}

assert_empty() {
  local value="$1"
  local label="$2"
  [[ -z "$value" ]] || die "expected empty output for $label, got: ${(qqq)value}"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  [[ "$haystack" == *"$needle"* ]] || die "$label missing expected text: $needle; got: ${(qqq)haystack}"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  [[ "$haystack" != *"$needle"* ]] || die "$label unexpectedly contained: $needle; got: ${(qqq)haystack}"
}

assert_file_contains() {
  local path="$1"
  local needle="$2"
  [[ -r "$path" ]] || die "missing file: $path"
  assert_contains "$(<"$path")" "$needle" "$path"
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT
render_home="$tmp_root/rendered-home"
mkdir -p "$render_home"
chezmoi_cache="$tmp_root/chezmoi-cache"
chezmoi_state="$tmp_root/chezmoi-state.boltdb"
mkdir -p "$chezmoi_cache"
: > "$tmp_root/chezmoi.toml"

DOTFILES_SKIP_PLIST_HOOKS=1 \
DOTFILES_SKIP_LAUNCHCTL_SYNC=1 \
  chezmoi --no-tty \
    --source "$DOTFILES_ROOT" \
    --config "$tmp_root/chezmoi.toml" \
    --override-data '{"machine_type":"ci","chezmoi":{"hostname":"dotfiles-test-host"}}' \
    --destination "$render_home" \
    --cache "$chezmoi_cache" \
    --persistent-state "$chezmoi_state" \
    apply --force --exclude=scripts --parent-dirs \
    "$render_home/.config/dotfiles/shell-banner" \
    "$render_home/.config/zsh/extra/shell-banner.zsh" \
    "$render_home/.config/fastfetch/config.jsonc" \
    "$render_home/.local/bin/dotpkgs" \
    "$render_home/.local/lib/dotpkgs" >/dev/null

# Run the installed implementation with the provisioned Python, avoiding a
# dependency download inside the deliberately empty fixture environment.
helper_python="${TEST_PYTHON:-$(whence -p python3)}"
helper_entry="$render_home/.local/bin/dotpkgs"
cat > "$tmp_root/dotpkgs" <<EOF
#!/bin/sh
exec "$helper_python" "$helper_entry" "\$@"
EOF
chmod +x "$tmp_root/dotpkgs"
BANNER_ROOT="$render_home/.config/dotfiles/shell-banner"
LOADER="$render_home/.config/zsh/extra/shell-banner.zsh"
REFRESH="$BANNER_ROOT/bin/refresh"
MODULE="$BANNER_ROOT/bin/module"
PREVIEW="$BANNER_ROOT/bin/preview"
FASTFETCH_CONFIG="$render_home/.config/fastfetch/config.jsonc"

[[ -x "$REFRESH" ]]                         || die "rendered refresh is not executable"
[[ -x "$MODULE" ]]                          || die "rendered module shim is not executable"
[[ -x "$PREVIEW" ]]                         || die "rendered preview is not executable"
[[ -x "$BANNER_ROOT/bin/sources/chezmoi" ]] || die "rendered chezmoi source script is not executable"
[[ -x "$BANNER_ROOT/bin/sources/brew" ]]    || die "rendered brew source script is not executable"
[[ -x "$BANNER_ROOT/bin/sources/mise" ]]    || die "rendered mise source script is not executable"
[[ -x "$BANNER_ROOT/bin/sources/apm" ]]     || die "rendered apm source script is not executable"
[[ -r "$BANNER_ROOT/feature.env" ]]         || die "rendered feature.env missing"
[[ -r "$BANNER_ROOT/lib/cache.sh"   && ! -x "$BANNER_ROOT/lib/cache.sh"   ]] || die "lib/cache.sh has wrong mode"
[[ -r "$BANNER_ROOT/lib/sources.sh" && ! -x "$BANNER_ROOT/lib/sources.sh" ]] || die "lib/sources.sh has wrong mode"
[[ -r "$BANNER_ROOT/shell/zsh.zsh"  && ! -x "$BANNER_ROOT/shell/zsh.zsh"  ]] || die "shell adapter has wrong mode"
[[ -r "$BANNER_ROOT/README.md"      && ! -x "$BANNER_ROOT/README.md"      ]] || die "README has wrong mode"
[[ -r "$LOADER"                     && ! -x "$LOADER"                     ]] || die "zsh loader has wrong mode"
[[ -r "$FASTFETCH_CONFIG"           && ! -x "$FASTFETCH_CONFIG"           ]] || die "fastfetch config has wrong mode"
[[ ! -e "$BANNER_ROOT/bin/executable_refresh" ]] || die "executable_ prefix leaked into target"

# fastfetch config should reference our module shim via runtime $HOME, quoted
# so a home path containing a space still resolves.
assert_file_contains "$FASTFETCH_CONFIG" '\"${DOTFILES_BANNER_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/shell-banner}\"/bin/module chezmoi'
assert_file_contains "$FASTFETCH_CONFIG" '\"${DOTFILES_BANNER_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/shell-banner}\"/bin/module mise'
# apm is intentionally absent from the default fastfetch config (deferred);
# the per-source script + lib support is still tested independently below.

# ---------- per-source script unit tests via fake CLIs ----------

make_fake_chezmoi() {
  local dir="$1"
  mkdir -p "$dir"
  cat >"$dir/chezmoi" <<'EOF'
#!/usr/bin/env zsh
print -r -- "$*" >> "${BANNER_FAKE_LOG:-/dev/null}"
if [[ -n "${BANNER_FAKE_UMASK_LOG:-}" ]]; then
  umask >> "$BANNER_FAKE_UMASK_LOG"
fi
case "$1$2$3$4$5$6$7$8" in
  *managed*)
    print -r -- 'one'; print -r -- 'two'; print -r -- 'three'
    exit 0
    ;;
esac
if [[ "${BANNER_FAKE_FAIL:-0}" == 1 ]]; then
  print -u2 -- "${BANNER_FAKE_STDERR:-fake chezmoi failure}"
  exit "${BANNER_FAKE_EXIT:-1}"
fi
if [[ "${BANNER_FAKE_CLEAN:-0}" == 1 ]]; then
  exit 0
fi
print -r -- 'M dot_zshrc'
print -r -- ' M dot_gitconfig'
EOF
  chmod +x "$dir/chezmoi"
}

make_fake_brew() {
  local dir="$1"
  mkdir -p "$dir"
  cat >"$dir/brew" <<'EOF'
#!/usr/bin/env zsh
print -r -- "$*" >> "${BANNER_FAKE_LOG:-/dev/null}"
case "$1" in
  info)
    print -r -- '{"formulae":[{"name":"ripgrep","installed":[{"version":"1"}],"versions":{"stable":"2"}},{"name":"jq","installed":[{"version":"1"}],"versions":{"stable":"2"}},{"name":"fc","installed":[{"version":"1"}],"versions":{"stable":"1"}},{"name":"fd","installed":[{"version":"1"}],"versions":{"stable":"1"}}],"casks":[{"token":"iterm2","installed":"1","version":"2"},{"token":"cb","installed":"1","version":"1"}]}'
    ;;
  outdated)
    if [[ "${BANNER_FAKE_FAIL:-0}" == 1 ]]; then
      print -u2 -- 'fake brew failure'
      exit 1
    fi
    if [[ "${BANNER_FAKE_CLEAN:-0}" == 1 ]]; then
      print -r -- '{"formulae":[],"casks":[]}'
    else
      print -r -- '{"formulae":[{"name":"ripgrep"},{"name":"jq"}],"casks":[{"name":"iterm2"}]}'
    fi
    ;;
esac
exit 0
EOF
  chmod +x "$dir/brew"
}

make_fake_mise() {
  local dir="$1"
  mkdir -p "$dir"
  cat >"$dir/mise" <<'EOF'
#!/usr/bin/env zsh
print -r -- "$*" >> "${BANNER_FAKE_LOG:-/dev/null}"
case "$1" in
  outdated)
    if [[ "${BANNER_FAKE_FAIL:-0}" == 1 ]]; then
      print -u2 -- 'fake mise failure'
      exit 1
    fi
    if [[ "${BANNER_FAKE_CLEAN:-0}" == 1 ]]; then
      print -r -- '{}'
    else
      print -r -- '{"node":{"current":"24.12.0","latest":"24.13.0"}}'
    fi
    ;;
  ls)
    print -r -- '{"node":[{"version":"24.12.0","requested_version":"latest","installed":true}],"two":[{"version":"1","installed":true}],"three":[{"version":"1","installed":true}],"four":[{"version":"1","installed":true}],"five":[{"version":"1","installed":true}]}'
    ;;
esac
exit 0
EOF
  chmod +x "$dir/mise"
}

make_fake_apm() {
  local dir="$1"
  mkdir -p "$dir"
  cat >"$dir/apm" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$dir/apm"
  cat >"$dir/dotpkgs" <<'EOF'
#!/bin/sh
printf '1\t3\t0\t0\n[{"name":"github/foo/bar","status":"update_available"}]\n'
EOF
  chmod +x "$dir/dotpkgs"
}

run_refresh_one() {
  local source="$1"
  local fake_dir="$2"
  local state_root="$3"
  local extra_env="${4:-}"
  [[ -x "$fake_dir/dotpkgs" ]] || /bin/cp "$tmp_root/dotpkgs" "$fake_dir/dotpkgs"
  /usr/bin/env -i \
    HOME="$render_home" \
    XDG_CONFIG_HOME="$render_home/.config" \
    XDG_STATE_HOME="$render_home/.local/state" \
    DOTFILES_BANNER_STATE_DIR="$state_root" \
    DOTFILES_BANNER_DOTPKGS_BIN="${fake_dir}/dotpkgs" \
    BANNER_FAKE_LOG="$tmp_root/fake.log" \
    PATH="$fake_dir:/usr/bin:/bin:/usr/sbin:/sbin" \
    ${=extra_env} \
    "$REFRESH" --source "$source"
}

# chezmoi clean
state_chezmoi_clean="$tmp_root/state-chezmoi-clean"
fake_chezmoi="$tmp_root/fake-chezmoi"
make_fake_chezmoi "$fake_chezmoi"
run_refresh_one chezmoi "$fake_chezmoi" "$state_chezmoi_clean" 'BANNER_FAKE_CLEAN=1'
assert_file_contains "$state_chezmoi_clean/sources/chezmoi/state.env" 'DOTFILES_BANNER_RESULT=ok'
assert_file_contains "$state_chezmoi_clean/sources/chezmoi/state.env" 'DOTFILES_BANNER_OUTDATED_COUNT=0'
assert_file_contains "$state_chezmoi_clean/sources/chezmoi/state.env" 'DOTFILES_BANNER_TOTAL_COUNT=3'
assert_file_contains "$state_chezmoi_clean/sources/chezmoi/state.env" 'DOTFILES_BANNER_PARAMS=scope=files'
assert_file_contains "$state_chezmoi_clean/sources/chezmoi/module.txt" '0 / 3 drifted'

# chezmoi drifted
state_chezmoi_dirty="$tmp_root/state-chezmoi-dirty"
run_refresh_one chezmoi "$fake_chezmoi" "$state_chezmoi_dirty"
assert_file_contains "$state_chezmoi_dirty/sources/chezmoi/state.env" 'DOTFILES_BANNER_RESULT=ok'
assert_file_contains "$state_chezmoi_dirty/sources/chezmoi/state.env" 'DOTFILES_BANNER_OUTDATED_COUNT=2'
assert_file_contains "$state_chezmoi_dirty/sources/chezmoi/module.txt" '2 / 3 drifted'

# chezmoi disabled (binary missing)
state_chezmoi_missing="$tmp_root/state-chezmoi-missing"
empty_dir="$tmp_root/empty-bin"
mkdir -p "$empty_dir"
run_refresh_one chezmoi "$empty_dir" "$state_chezmoi_missing"
assert_file_contains "$state_chezmoi_missing/sources/chezmoi/state.env" 'DOTFILES_BANNER_RESULT=disabled'
assert_file_contains "$state_chezmoi_missing/sources/chezmoi/module.txt" 'unavailable'

# chezmoi error
state_chezmoi_err="$tmp_root/state-chezmoi-err"
set +e
run_refresh_one chezmoi "$fake_chezmoi" "$state_chezmoi_err" 'BANNER_FAKE_FAIL=1' 2>"$tmp_root/expected-error"
rc=$?
set -e
(( rc != 0 )) || die 'expected chezmoi refresh failure'
assert_file_contains "$tmp_root/expected-error" 'chezmoi errored'
assert_file_contains "$state_chezmoi_err/sources/chezmoi/state.env" 'DOTFILES_BANNER_RESULT=error'
assert_file_contains "$state_chezmoi_err/sources/chezmoi/last_error" 'fake chezmoi failure'
assert_file_contains "$state_chezmoi_err/sources/chezmoi/module.txt" 'unavailable'

# An error row backs off instead of being permanently stale, so a source that
# is failing for an ambient reason isn't re-probed by every new shell.
run_refresh_if_stale() {
  local state_root="$1" fake_dir="$2" log="$3" stderr_file="$4"
  : >| "$log"
  /usr/bin/env -i \
    HOME="$render_home" \
    XDG_CONFIG_HOME="$render_home/.config" \
    XDG_STATE_HOME="$render_home/.local/state" \
    DOTFILES_BANNER_STATE_DIR="$state_root" \
    DOTFILES_BANNER_DOTPKGS_BIN="${fake_dir}/dotpkgs" \
    BANNER_FAKE_LOG="$log" \
    BANNER_FAKE_FAIL=1 \
    PATH="$fake_dir:/usr/bin:/bin:/usr/sbin:/sbin" \
    "$REFRESH" --source chezmoi --if-stale 2>"$stderr_file"
}
err_log="$tmp_root/chezmoi-err-backoff.log"
err_stderr="$tmp_root/chezmoi-err-backoff.stderr"
# Tolerate a non-zero exit so a regression reports the assertion below rather
# than tripping set -e on the probe it should not have run.
set +e
run_refresh_if_stale "$state_chezmoi_err" "$fake_chezmoi" "$err_log" "$err_stderr"
set -e
[[ ! -s "$err_log" ]] || die 'a just-written error row should suppress the next --if-stale probe'
[[ ! -s "$err_stderr" ]] || die "suppressed probe should be silent, got: $(<"$err_stderr")"

# ...and the backoff expires. Age the row well past any plausible TTL.
err_state="$state_chezmoi_err/sources/chezmoi/state.env"
/usr/bin/sed -i '' \
  "s/^DOTFILES_BANNER_UPDATED_AT=.*/DOTFILES_BANNER_UPDATED_AT=$(( $(/bin/date +%s) - 86400 ))/" \
  "$err_state"
set +e
run_refresh_if_stale "$state_chezmoi_err" "$fake_chezmoi" "$err_log" "$err_stderr"
set -e
[[ -s "$err_log" ]] || die 'a day-old error row should be retried'
assert_file_contains "$err_stderr" 'chezmoi errored'

# Probes see the caller's umask; cache writes stay private.
state_umask="$tmp_root/state-umask"
umask_log="$tmp_root/chezmoi-umask.log"
(
  umask 022
  run_refresh_one chezmoi "$fake_chezmoi" "$state_umask" "BANNER_FAKE_UMASK_LOG=$umask_log"
)
assert_file_contains "$umask_log" '022'
[[ "$(<"$umask_log")" != *077* ]] || die 'chezmoi probe inherited the private cache umask'
# module.txt is the load-bearing mode check: state.env and status.txt get an
# explicit chmod 600, so they stay private even if the re-clamp is dropped,
# whereas module.txt is born under whatever umask is in force at write time.
module_mode="$(stat -f '%Lp' "$state_umask/sources/chezmoi/module.txt")"
[[ "$module_mode" == '600' ]] || die "cache module.txt mode is $module_mode, expected 600"
state_dir_mode="$(stat -f '%Lp' "$state_umask/sources/chezmoi")"
[[ "$state_dir_mode" == '700' ]] || die "cache source dir mode is $state_dir_mode, expected 700"

# Handing the caller's umask to the probe also hands it to mktemp. An owner-
# masking umask must not leave the probe with a stderr file it cannot write.
state_umask_strict="$tmp_root/state-umask-strict"
(
  umask 0700
  run_refresh_one chezmoi "$fake_chezmoi" "$state_umask_strict" 'BANNER_FAKE_CLEAN=1'
)
assert_file_contains "$state_umask_strict/sources/chezmoi/state.env" 'DOTFILES_BANNER_RESULT=ok'

# brew outdated
state_brew="$tmp_root/state-brew"
fake_brew="$tmp_root/fake-brew"
make_fake_brew "$fake_brew"
run_refresh_one brew "$fake_brew" "$state_brew"
assert_file_contains "$state_brew/sources/brew/state.env" 'DOTFILES_BANNER_RESULT=ok'
assert_file_contains "$state_brew/sources/brew/state.env" 'DOTFILES_BANNER_OUTDATED_COUNT=3'
assert_file_contains "$state_brew/sources/brew/state.env" 'DOTFILES_BANNER_TOTAL_COUNT=6'
assert_file_contains "$state_brew/sources/brew/module.txt" '3 / 6 outdated'

# mise outdated
state_mise="$tmp_root/state-mise"
fake_mise="$tmp_root/fake-mise"
make_fake_mise "$fake_mise"
run_refresh_one mise "$fake_mise" "$state_mise"
assert_file_contains "$state_mise/sources/mise/state.env" 'DOTFILES_BANNER_RESULT=ok'
assert_file_contains "$state_mise/sources/mise/state.env" 'DOTFILES_BANNER_OUTDATED_COUNT=1'
assert_file_contains "$state_mise/sources/mise/state.env" 'DOTFILES_BANNER_TOTAL_COUNT=5'
assert_file_contains "$state_mise/sources/mise/module.txt" '1 / 5 outdated'

# apm consumes the same package-summary protocol
state_apm="$tmp_root/state-apm"
fake_apm="$tmp_root/fake-apm"
make_fake_apm "$fake_apm"
run_refresh_one apm "$fake_apm" "$state_apm"
assert_file_contains "$state_apm/sources/apm/state.env" 'DOTFILES_BANNER_RESULT=ok'
assert_file_contains "$state_apm/sources/apm/state.env" 'DOTFILES_BANNER_OUTDATED_COUNT=1'
assert_file_contains "$state_apm/sources/apm/state.env" 'DOTFILES_BANNER_TOTAL_COUNT=3'
assert_file_contains "$state_apm/sources/apm/module.txt" '1 / 3 outdated'

# ---------- module shim ----------

# Module shim prints cached row.
state_module="$tmp_root/state-module"
mkdir -p "$state_module/sources/brew"
print -r -- '✓ 0 / 7 outdated' >| "$state_module/sources/brew/module.txt"
out="$(/usr/bin/env -i HOME="$render_home" \
  DOTFILES_BANNER_STATE_DIR="$state_module" NO_COLOR=1 \
  PATH=/usr/bin:/bin "$MODULE" brew)"
assert_contains "$out" '0 / 7 outdated' 'module shim cached row'

# Module shim falls back when cache missing.
state_module_missing="$tmp_root/state-module-missing"
out="$(/usr/bin/env -i HOME="$render_home" \
  DOTFILES_BANNER_STATE_DIR="$state_module_missing" NO_COLOR=1 \
  PATH=/usr/bin:/bin "$MODULE" mise)"
assert_contains "$out" 'unavailable' 'module shim missing cache'

# ---------- adapter behaviors ----------

run_adapter_tty() {
  local extra_env="${1:-}"
  local name="banner_${RANDOM}_${RANDOM}"
  local runner="$tmp_root/runner_${name}.zsh"
  local output='' chunk='' start quiet_start exited

  cat >"$runner" <<EOF
#!/usr/bin/env zsh
exec env -i \\
  HOME=${(q)render_home} \\
  XDG_CONFIG_HOME=${(q)render_home}/.config \\
  XDG_STATE_HOME=${(q)render_home}/.local/state \\
  PATH=/usr/bin:/bin:/usr/sbin:/sbin \\
  TERM=xterm-256color \\
  $extra_env \\
  /bin/zsh -fic 'source ${(q)LOADER}; exit'
EOF
  chmod +x "$runner"

  # Time the quiet window from the child's exit, not the first poll: a slow
  # first byte otherwise reads as "produced nothing", which is exactly what the
  # assert_empty cases expect, so they would pass without the adapter running.
  zpty -b "$name" "$runner"
  start=$EPOCHREALTIME
  quiet_start=0
  while (( EPOCHREALTIME - start < 10 )); do
    if zpty -rt "$name" chunk >/dev/null 2>&1; then
      output+="$chunk"
      continue
    fi
    if (( quiet_start == 0 )) && ! zpty -t "$name" >/dev/null 2>&1; then
      quiet_start=$EPOCHREALTIME
    fi
    (( quiet_start > 0 && EPOCHREALTIME - quiet_start > 0.15 )) && break
    zselect -t 1 >/dev/null 2>&1 || true  # hundredths of a second
  done
  exited=$quiet_start
  zpty -d "$name" 2>/dev/null || true
  # A wedged adapter still yields whatever it printed first, so without this
  # the timeout is indistinguishable from a clean run.
  (( exited > 0 )) || die "adapter did not exit within 10s (env: ${extra_env:-none})"
  output="${output//$'\r'/}"
  print -r -- "$output"
}

# Disabled exits silently.
output="$(run_adapter_tty 'DOTFILES_BANNER_ENABLED=0')"
assert_empty "$output" 'disabled adapter'

# Non-interactive exits silently even when feature is enabled.
output="$(
  env -i \
    HOME="$render_home" \
    XDG_CONFIG_HOME="$render_home/.config" \
    XDG_STATE_HOME="$render_home/.local/state" \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    TERM=xterm-256color \
    /bin/zsh -fc "source ${(q)LOADER}"
)"
assert_empty "$output" 'non-interactive adapter'

# SSH attached, dumb TERM, missing TERM all suppress.
output="$(run_adapter_tty 'SSH_TTY=/dev/ttys000')"
assert_empty "$output" 'SSH_TTY adapter'
output="$(run_adapter_tty 'SSH_CONNECTION=remote')"
assert_empty "$output" 'SSH_CONNECTION adapter'
output="$(run_adapter_tty 'TERM=dumb')"
assert_empty "$output" 'TERM=dumb adapter'
output="$(run_adapter_tty 'TERM=')"
assert_empty "$output" 'TERM= adapter'

# When fastfetch is missing, adapter prints a one-line install nag.
output="$(run_adapter_tty "DOTFILES_BANNER_FASTFETCH_BIN=/nonexistent/fastfetch NO_COLOR=1")"
assert_contains "$output" 'fastfetch not installed' 'fastfetch-missing nag fires'

# Adapter with fastfetch present invokes it (verify via stub on PATH).
state_ff="$tmp_root/state-fastfetch"
fake_ff_dir="$tmp_root/fake-fastfetch"
mkdir -p "$fake_ff_dir"
cat >"$fake_ff_dir/fastfetch" <<EOF
#!/usr/bin/env zsh
print -r -- "FAKE_FASTFETCH_CALLED args=\$*" >> ${(q)tmp_root}/fastfetch-calls.log
print -r -- 'fake fastfetch banner output'
EOF
chmod +x "$fake_ff_dir/fastfetch"
mkdir -p "$state_ff/sources/chezmoi"
print -r -- '' >| "$state_ff/sources/chezmoi/module.txt"
output="$(run_adapter_tty "DOTFILES_BANNER_STATE_DIR=${(q)state_ff} PATH=${(q)fake_ff_dir}:/usr/bin:/bin:/usr/sbin:/sbin DOTFILES_BANNER_FASTFETCH_BIN=fastfetch NO_COLOR=1")"
assert_contains "$output" 'fake fastfetch banner output' 'adapter invokes fastfetch when present'
[[ -r "$tmp_root/fastfetch-calls.log" ]] || die 'fastfetch was not called'
assert_file_contains "$tmp_root/fastfetch-calls.log" '--config'

# Subshell isolation: run the loader inside a non-zpty subshell, then probe
# whether banner_* functions or BANNER_STATE_* params survived. This keeps
# the test deterministic (no zpty timing) while still catching the env-leak
# regression the round-1 cleanup was meant to prevent.
iso_funcs="$(/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  /bin/zsh -fc "source ${(q)LOADER}; print -lr -- \${(k)functions[(I)banner_*]}" 2>/dev/null)"
[[ -z "$iso_funcs" ]] || die "subshell adapter leaked functions: $iso_funcs"
iso_vars="$(/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  /bin/zsh -fc "source ${(q)LOADER}; print -lr -- \${(k)parameters[(I)BANNER_STATE_*]}" 2>/dev/null)"
[[ -z "$iso_vars" ]] || die "subshell adapter leaked BANNER_STATE_* vars: $iso_vars"

# Local.env is parsed as data, not sourced. Also exercise the strict-identifier
# guard that blocks command-substitution injection in the key column.
banner_lib_root="$BANNER_ROOT"
canary="$tmp_root/local-env-canary-${RANDOM}"
print -r -- "DOTFILES_BANNER_X \$(touch ${(q)canary})=ignored" >| "$banner_lib_root/local.env"
print -r -- 'DOTFILES_BANNER_lower_case=set'                   >>| "$banner_lib_root/local.env"
print -r -- 'print -u2 -- LOCAL_ENV_STDERR'                    >>| "$banner_lib_root/local.env"
print -r -- 'DOTFILES_BANNER_ENABLED=0'                        >>| "$banner_lib_root/local.env"
output="$(run_adapter_tty 'NO_COLOR=1')"
rm -f "$banner_lib_root/local.env"
assert_empty "$output" 'local.env disable applies'
[[ "$output" != *LOCAL_ENV_STDERR* ]] || die 'local.env executed as shell code'
[[ ! -e "$canary" ]] || die 'local.env command-substitution injection slipped past key validator'

# ---------- refresh dispatcher: locking and TTL ----------

state_lock="$tmp_root/state-lock"
fake_chezmoi_slow="$tmp_root/fake-chezmoi-slow"
mkdir -p "$fake_chezmoi_slow"
cat >"$fake_chezmoi_slow/chezmoi" <<'EOF'
#!/usr/bin/env zsh
print -r -- "$*" >> "${BANNER_FAKE_LOG:-/dev/null}"
case "$1$2$3$4$5$6" in
  *managed*)
    print -r -- 'a'; print -r -- 'b'
    exit 0
    ;;
esac
sleep 0.5
print -r -- 'M dot_zshrc'
EOF
chmod +x "$fake_chezmoi_slow/chezmoi"

(
  /usr/bin/env -i \
    HOME="$render_home" \
    XDG_CONFIG_HOME="$render_home/.config" \
    XDG_STATE_HOME="$render_home/.local/state" \
    DOTFILES_BANNER_STATE_DIR="$state_lock" \
    BANNER_FAKE_LOG="$tmp_root/lock-fake.log" \
    PATH="$fake_chezmoi_slow:/usr/bin:/bin:/usr/sbin:/sbin" \
    "$REFRESH" --source chezmoi
) &
pid1=$!
(
  /usr/bin/env -i \
    HOME="$render_home" \
    XDG_CONFIG_HOME="$render_home/.config" \
    XDG_STATE_HOME="$render_home/.local/state" \
    DOTFILES_BANNER_STATE_DIR="$state_lock" \
    BANNER_FAKE_LOG="$tmp_root/lock-fake.log" \
    PATH="$fake_chezmoi_slow:/usr/bin:/bin:/usr/sbin:/sbin" \
    "$REFRESH" --source chezmoi
) &
pid2=$!
wait "$pid1" || true
wait "$pid2" || true
status_calls=0
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" == *status* && "$line" != *managed* ]] && (( status_calls += 1 ))
done < "$tmp_root/lock-fake.log"
(( status_calls == 1 )) || die "expected one status call under lock, got $status_calls"

# Stale lock with old PID is recovered.
state_stalelock="$tmp_root/state-stalelock"
mkdir -p "$state_stalelock/sources/chezmoi/refresh.lock"
print -r -- 999999 >| "$state_stalelock/sources/chezmoi/refresh.lock/owner.pid"
print -r -- 1 >| "$state_stalelock/sources/chezmoi/refresh.lock/started_at"
print -r -- stale-token >| "$state_stalelock/sources/chezmoi/refresh.lock/owner.token"
run_refresh_one chezmoi "$fake_chezmoi" "$state_stalelock" 'BANNER_FAKE_CLEAN=1'
[[ ! -d "$state_stalelock/sources/chezmoi/refresh.lock" ]] || die 'stale lock not cleaned'
assert_file_contains "$state_stalelock/sources/chezmoi/state.env" 'DOTFILES_BANNER_RESULT=ok'

# --if-stale skips when cache is fresh.
state_if_stale="$tmp_root/state-if-stale"
run_refresh_one chezmoi "$fake_chezmoi" "$state_if_stale" 'BANNER_FAKE_CLEAN=1'
: >| "$tmp_root/fake.log"
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DOTFILES_BANNER_STATE_DIR="$state_if_stale" \
  BANNER_FAKE_LOG="$tmp_root/fake.log" \
  PATH="$fake_chezmoi:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_BANNER_CHEZMOI_REFRESH_TTL_SECONDS=3600 \
  BANNER_FAKE_CLEAN=1 \
  "$REFRESH" --source chezmoi --if-stale
[[ ! -s "$tmp_root/fake.log" ]] || die 'fresh cache did not skip refresh'
# Note: --if-stale with TTL=0 always re-runs.
: >| "$tmp_root/fake.log"
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DOTFILES_BANNER_STATE_DIR="$state_if_stale" \
  BANNER_FAKE_LOG="$tmp_root/fake.log" \
  PATH="$fake_chezmoi:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_BANNER_CHEZMOI_REFRESH_TTL_SECONDS=0 \
  BANNER_FAKE_CLEAN=1 \
  "$REFRESH" --source chezmoi --if-stale
[[ -s "$tmp_root/fake.log" ]] || die 'TTL=0 should have re-run check'

# Param change (scope) invalidates fresh cache.
state_params="$tmp_root/state-params"
run_refresh_one chezmoi "$fake_chezmoi" "$state_params" 'BANNER_FAKE_CLEAN=1'
: >| "$tmp_root/fake.log"
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DOTFILES_BANNER_STATE_DIR="$state_params" \
  BANNER_FAKE_LOG="$tmp_root/fake.log" \
  PATH="$fake_chezmoi:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_BANNER_CHEZMOI_SCOPE=apply \
  DOTFILES_BANNER_CHEZMOI_REFRESH_TTL_SECONDS=3600 \
  BANNER_FAKE_CLEAN=1 \
  "$REFRESH" --source chezmoi --if-stale
[[ -s "$tmp_root/fake.log" ]] || die 'scope change should have invalidated cache'

# Per-source disable in DOTFILES_BANNER_SOURCES.
state_sel="$tmp_root/state-sel"
make_fake_chezmoi "$tmp_root/fake-only-cz"
run_refresh_one chezmoi "$tmp_root/fake-only-cz" "$state_sel" 'BANNER_FAKE_CLEAN=1'
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DOTFILES_BANNER_STATE_DIR="$state_sel" \
  PATH="$tmp_root/fake-only-cz:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_BANNER_SOURCES=chezmoi \
  BANNER_FAKE_CLEAN=1 \
  "$REFRESH"
[[ -d "$state_sel/sources/chezmoi" ]] || die 'expected chezmoi source dir'
[[ ! -d "$state_sel/sources/brew" ]]  || die 'brew should not have run when not in DOTFILES_BANNER_SOURCES'

# Concurrent corrupt lock metadata is treated as in-progress (5s grace).
state_grace="$tmp_root/state-grace"
mkdir -p "$state_grace/sources/chezmoi/refresh.lock"
: >| "$tmp_root/grace-fake.log"
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DOTFILES_BANNER_STATE_DIR="$state_grace" \
  BANNER_FAKE_LOG="$tmp_root/grace-fake.log" \
  PATH="$fake_chezmoi:/usr/bin:/bin:/usr/sbin:/sbin" \
  "$REFRESH" --source chezmoi --if-stale
[[ ! -s "$tmp_root/grace-fake.log" ]] || die 'fresh corrupt lock should have blocked refresh'

# Carry forward trunk's future-cache and live-PID lock recovery guarantees.
for timestamp in 1 9999999999; do
  state_recovery="$tmp_root/recovery-$timestamp"
  mkdir -p "$state_recovery/sources/chezmoi/refresh.lock"
  print -r -- "$$" > "$state_recovery/sources/chezmoi/refresh.lock/owner.pid"
  print -r -- "$timestamp" > "$state_recovery/sources/chezmoi/refresh.lock/started_at"
  print -r -- 'old-owner' > "$state_recovery/sources/chezmoi/refresh.lock/owner.token"
  run_refresh_one chezmoi "$fake_chezmoi" "$state_recovery"
  [[ ! -d "$state_recovery/sources/chezmoi/refresh.lock" ]] || die 'stale live-PID lock survived'
  assert_file_contains "$state_recovery/sources/chezmoi/module.txt" '2 / 3 drifted'
done
/usr/bin/sed -i '' 's/^DOTFILES_BANNER_UPDATED_AT=.*/DOTFILES_BANNER_UPDATED_AT=9999999999/' \
  "$state_recovery/sources/chezmoi/state.env"
print -r -- "touch $tmp_root/cache-injection" >> "$state_recovery/sources/chezmoi/state.env"
env DOTFILES_BANNER_STATE_DIR="$state_recovery" DOTFILES_BANNER_SOURCES=chezmoi \
  DOTFILES_BANNER_CHEZMOI_BIN="$fake_chezmoi/chezmoi" "$REFRESH" --if-stale
[[ ! -e "$tmp_root/cache-injection" ]] || die 'state cache executed shell code'
[[ "$(<"$state_recovery/sources/chezmoi/state.env")" != *9999999999* ]] || die 'future cache was not refreshed'

print -- 'OK shell-banner'
