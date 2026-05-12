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
  print -u2 -- "chezmoi-drift-banner: $*"
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

DOTFILES_SKIP_PLIST_HOOKS=1 \
  chezmoi --no-tty \
    --source "$DOTFILES_ROOT/home" \
    --destination "$render_home" \
    --cache "$chezmoi_cache" \
    --persistent-state "$chezmoi_state" \
    apply --force --exclude=scripts --parent-dirs \
    "$render_home/.config/dotfiles/chezmoi-drift" \
    "$render_home/.config/zsh/extra/chezmoi-drift.zsh" >/dev/null

DRIFT_ROOT="$render_home/.config/dotfiles/chezmoi-drift"
LOADER="$render_home/.config/zsh/extra/chezmoi-drift.zsh"
REFRESH="$DRIFT_ROOT/bin/refresh"

[[ -x "$REFRESH" ]] || die "rendered refresh is not executable"
[[ -x "$DRIFT_ROOT/bin/preview" ]] || die "rendered preview is not executable"
[[ -r "$DRIFT_ROOT/feature.env" ]] || die "rendered feature.env missing"
[[ -r "$LOADER" ]] || die "rendered zsh loader missing"
[[ -r "$DRIFT_ROOT/README.md" && ! -x "$DRIFT_ROOT/README.md" ]] || die "rendered README has wrong mode"
[[ -r "$DRIFT_ROOT/lib/cache.sh" && ! -x "$DRIFT_ROOT/lib/cache.sh" ]] || die "rendered cache library has wrong mode"
[[ -r "$DRIFT_ROOT/shell/zsh.zsh" && ! -x "$DRIFT_ROOT/shell/zsh.zsh" ]] || die "rendered shell adapter has wrong mode"
[[ -r "$DRIFT_ROOT/feature.env" && ! -x "$DRIFT_ROOT/feature.env" ]] || die "rendered feature.env has wrong mode"
[[ -r "$LOADER" && ! -x "$LOADER" ]] || die "rendered zsh loader has wrong mode"
[[ -r "$DRIFT_ROOT/art/compact.txt" && ! -x "$DRIFT_ROOT/art/compact.txt" ]] || die "rendered compact art has wrong mode"
[[ -r "$DRIFT_ROOT/art/images/amber-badge.png" && ! -x "$DRIFT_ROOT/art/images/amber-badge.png" ]] || die "rendered amber image has wrong mode"
[[ ! -e "$DRIFT_ROOT/bin/executable_refresh" ]] || die "source executable_ prefix leaked into target"
[[ ! -e "$DRIFT_ROOT/feature.env.tmpl" ]] || die "source .tmpl suffix leaked into target"

write_state() {
  local state_dir="$1"
  local signature="$2"
  local count="${3:-3}"
  local updated_at="${4:-$EPOCHSECONDS}"
  local banner="${5:-dotfiles drift | 3 files differ | checked 09:42}"
  local next_refresh_after=$(( updated_at + 3600 ))

  mkdir -p "$state_dir"
  cat >"$state_dir/state.env" <<EOF
DOTFILES_CHEZMOI_DRIFT_CACHE_VERSION=1
DOTFILES_CHEZMOI_DRIFT_STATUS_COUNT=$count
DOTFILES_CHEZMOI_DRIFT_SIGNATURE=$signature
DOTFILES_CHEZMOI_DRIFT_UPDATED_AT=$updated_at
DOTFILES_CHEZMOI_DRIFT_NEXT_REFRESH_AFTER=$next_refresh_after
DOTFILES_CHEZMOI_DRIFT_BANNER_TTL_SECONDS=21600
DOTFILES_CHEZMOI_DRIFT_SCOPE=files
DOTFILES_CHEZMOI_DRIFT_RENDERER_EFFECTIVE=compact
DOTFILES_CHEZMOI_DRIFT_PALETTE_EFFECTIVE=amber
DOTFILES_CHEZMOI_DRIFT_CHECKED_LABEL=09:42
DOTFILES_CHEZMOI_DRIFT_RESULT=ok
EOF
  print -r -- "$banner" >| "$state_dir/banner.txt"
  print -r -- $'\033[38;5;214m'"$banner"$'\033[0m' >| "$state_dir/banner.ansi"
}

run_adapter_tty() {
  local state_dir="$1"
  local extra_env="${2:-}"
  local name="drift_${RANDOM}_${RANDOM}"
  local runner="$tmp_root/runner_${name}.zsh"
  local output='' chunk='' start quiet_start finished

  cat >"$runner" <<EOF
#!/usr/bin/env zsh
exec env -i \\
  HOME=${(q)render_home} \\
  XDG_CONFIG_HOME=${(q)render_home}/.config \\
  XDG_STATE_HOME=${(q)render_home}/.local/state \\
  PATH=/usr/bin:/bin:/usr/sbin:/sbin \\
  TERM=xterm-256color \\
  DOTFILES_CHEZMOI_DRIFT_STATE_DIR=${(q)state_dir} \\
  $extra_env \\
  /bin/zsh -fic 'source ${(q)LOADER}; exit'
EOF
  chmod +x "$runner"

  zpty -b "$name" "$runner"
  start=$EPOCHREALTIME
  quiet_start=$EPOCHREALTIME
  while (( EPOCHREALTIME - start < 3 )); do
    if zpty -rt "$name" chunk >/dev/null 2>&1; then
      output+="$chunk"
      quiet_start=$EPOCHREALTIME
      continue
    fi
    (( EPOCHREALTIME - quiet_start > 0.15 )) && break
    zselect -t 0.02 >/dev/null 2>&1 || true
  done
  zpty -d "$name" 2>/dev/null || true

  finished=$EPOCHREALTIME
  print -r -- "$(( (finished - start) * 1000 ))" >| "$tmp_root/last-adapter-elapsed-ms"
  output="${output//$'\r'/}"
  print -r -- "$output"
}

wait_for_file() {
  local path="$1"
  local timeout="${2:-3}"
  local start=$EPOCHREALTIME

  while (( EPOCHREALTIME - start < timeout )); do
    [[ -e "$path" ]] && return 0
    zselect -t 0.05 >/dev/null 2>&1 || true
  done

  return 1
}

make_stub_chezmoi() {
  local dir="$1"
  mkdir -p "$dir"
  cat >"$dir/chezmoi" <<'EOF'
#!/usr/bin/env zsh
print -r -- "$*" >> "$DRIFT_STUB_LOG"
if [[ -n "${DRIFT_STUB_UMASK_LOG:-}" ]]; then
  umask >> "$DRIFT_STUB_UMASK_LOG"
fi
if [[ -n "${DRIFT_STUB_STDERR:-}" ]]; then
  print -u2 -- "$DRIFT_STUB_STDERR"
fi
if [[ -n "${DRIFT_STUB_SLEEP:-}" ]]; then
  sleep "$DRIFT_STUB_SLEEP"
fi
if [[ "${DRIFT_STUB_FAIL:-0}" == 1 ]]; then
  print -u2 -- "stub failure"
  exit 42
fi
if [[ "${DRIFT_STUB_CLEAN:-0}" == 1 ]]; then
  exit 0
fi
print -r -- 'M dot_zshrc'
print -r -- ' M dot_gitconfig'
EOF
  chmod +x "$dir/chezmoi"
}

# Disabled config exits silently.
state_disabled="$tmp_root/state-disabled"
write_state "$state_disabled" sig-disabled
output="$(run_adapter_tty "$state_disabled" 'DOTFILES_CHEZMOI_DRIFT_ENABLED=0')"
assert_empty "$output" 'disabled config'

# Non-interactive shells exit silently even with a dirty cache.
state_noninteractive="$tmp_root/state-noninteractive"
write_state "$state_noninteractive" sig-noninteractive
output="$(
  env -i \
    HOME="$tmp_root/home" \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    TERM=xterm-256color \
    DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_noninteractive" \
    XDG_CONFIG_HOME="$render_home/.config" \
    /bin/zsh -fc "source ${(q)LOADER}"
)"
assert_empty "$output" 'non-interactive shell'

# Missing cache prints nothing while seeding refresh in the background.
state_missing="$tmp_root/state-missing"
stub_missing="$tmp_root/stub-missing"
log_missing="$tmp_root/missing.log"
make_stub_chezmoi "$stub_missing"
output="$(run_adapter_tty "$state_missing" "DRIFT_STUB_LOG=${(q)log_missing} PATH=${(q)stub_missing}:/usr/bin:/bin:/usr/sbin:/sbin")"
assert_empty "$output" 'missing cache'
wait_for_file "$log_missing" || die 'missing cache did not start refresh'
wait_for_file "$state_missing/state.env" || die 'missing cache refresh did not write state'

# Corrupt cache lines are treated as data, not startup code.
state_corrupt="$tmp_root/state-corrupt"
mkdir -p "$state_corrupt"
now="$EPOCHSECONDS"
cat >"$state_corrupt/state.env" <<EOF
DOTFILES_CHEZMOI_DRIFT_STATUS_COUNT=0
DOTFILES_CHEZMOI_DRIFT_SIGNATURE=clean
DOTFILES_CHEZMOI_DRIFT_UPDATED_AT=$now
DOTFILES_CHEZMOI_DRIFT_SCOPE=files
print -r -- pwned >$tmp_root/pwned
EOF
output="$(run_adapter_tty "$state_corrupt")"
assert_empty "$output" 'corrupt cache'
[[ ! -e "$tmp_root/pwned" ]] || die 'state.env executed as shell code'

# Dirty cache prints once, then throttles the same signature.
state_dirty="$tmp_root/state-dirty"
write_state "$state_dirty" sig-dirty
output="$(run_adapter_tty "$state_dirty" 'NO_COLOR=1')"
assert_contains "$output" 'dotfiles drift' 'dirty cache first print'
output="$(run_adapter_tty "$state_dirty" 'NO_COLOR=1')"
assert_empty "$output" 'same signature throttle'
print -r -- '1 +' >| "$state_dirty/last_shown"
output="$(run_adapter_tty "$state_dirty" 'NO_COLOR=1')"
assert_contains "$output" 'dotfiles drift' 'corrupt last_shown recovers'
[[ "$output" != *'bad math expression'* ]] || die 'corrupt last_shown emitted zsh arithmetic error'

# A changed signature prints immediately.
write_state "$state_dirty" sig-changed 3 "$EPOCHSECONDS" 'dotfiles drift | changed signature'
output="$(run_adapter_tty "$state_dirty" 'NO_COLOR=1')"
assert_contains "$output" 'changed signature' 'changed signature print'

# TERM=dumb exits before printing.
state_dumb="$tmp_root/state-dumb"
write_state "$state_dumb" sig-dumb
output="$(run_adapter_tty "$state_dumb" 'TERM=dumb')"
assert_empty "$output" 'TERM=dumb'

# Missing TERM and SSH TTY sessions exit before printing.
state_no_term="$tmp_root/state-no-term"
write_state "$state_no_term" sig-no-term
output="$(run_adapter_tty "$state_no_term" 'TERM=')"
assert_empty "$output" 'missing TERM'

state_ssh="$tmp_root/state-ssh"
write_state "$state_ssh" sig-ssh
output="$(run_adapter_tty "$state_ssh" 'SSH_TTY=/dev/ttys000')"
assert_empty "$output" 'SSH TTY'

# NO_COLOR selects the plain banner.
state_plain="$tmp_root/state-plain"
write_state "$state_plain" sig-plain
output="$(run_adapter_tty "$state_plain" 'NO_COLOR=1')"
assert_contains "$output" 'dotfiles drift | 3 files differ' 'NO_COLOR plain output'
[[ "$output" != *$'\033['* ]] || die "NO_COLOR output included ANSI escapes"

# Machine-local local.env can disable the banner before .zshrc.local would run.
state_local_disable="$tmp_root/state-local-disable"
write_state "$state_local_disable" sig-local-disable
print -r -- 'DOTFILES_CHEZMOI_DRIFT_ENABLED=0' >| "$DRIFT_ROOT/local.env"
output="$(run_adapter_tty "$state_local_disable")"
rm -f "$DRIFT_ROOT/local.env"
assert_empty "$output" 'local.env disabled config'

# Machine-local local.env is parsed as data, not sourced as startup code.
state_local_data="$tmp_root/state-local-data"
write_state "$state_local_data" sig-local-data
{
  print -r -- 'print -u2 -- LOCAL_ENV_STDERR'
  print -r -- 'DOTFILES_CHEZMOI_DRIFT_ENABLED=TRUE'
} >| "$DRIFT_ROOT/local.env"
output="$(run_adapter_tty "$state_local_data" 'NO_COLOR=1')"
rm -f "$DRIFT_ROOT/local.env"
assert_contains "$output" 'dotfiles drift' 'local.env parsed data'
[[ "$output" != *LOCAL_ENV_STDERR* ]] || die 'local.env executed as shell code'

# Preview samples use the same local.env override path as refresh and startup.
print -r -- 'DOTFILES_CHEZMOI_DRIFT_RENDERER=box' >| "$DRIFT_ROOT/local.env"
output="$(
  /usr/bin/env -i \
    HOME="$render_home" \
    XDG_CONFIG_HOME="$render_home/.config" \
    XDG_STATE_HOME="$render_home/.local/state" \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    "$DRIFT_ROOT/bin/preview" --sample
)"
rm -f "$DRIFT_ROOT/local.env"
assert_contains "$output" '+-- dotfiles drift' 'preview local.env renderer'

# Default scope excludes scripts.
state_default_scope="$tmp_root/state-default-scope"
stub_default_scope="$tmp_root/stub-default-scope"
log_default_scope="$tmp_root/default-scope.log"
make_stub_chezmoi "$stub_default_scope"
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DRIFT_STUB_LOG="$log_default_scope" \
  PATH="$stub_default_scope:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_default_scope" \
  "$REFRESH"
assert_file_contains "$log_default_scope" 'status --exclude=scripts'

# Refresh keeps private state writes without changing chezmoi's status umask.
state_umask="$tmp_root/state-umask"
stub_umask="$tmp_root/stub-umask"
log_umask="$tmp_root/umask.log"
umask_log="$tmp_root/status-umask.log"
make_stub_chezmoi "$stub_umask"
(
  umask 022
  /usr/bin/env -i \
    HOME="$render_home" \
    XDG_CONFIG_HOME="$render_home/.config" \
    XDG_STATE_HOME="$render_home/.local/state" \
    DRIFT_STUB_LOG="$log_umask" \
    DRIFT_STUB_UMASK_LOG="$umask_log" \
    PATH="$stub_umask:/usr/bin:/bin:/usr/sbin:/sbin" \
    DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_umask" \
    "$REFRESH"
)
assert_file_contains "$umask_log" '022'
[[ "$(<"$umask_log")" != *077* ]] || die 'chezmoi status inherited private state umask'

# Refresh normalizes uppercase truthy and invalid numeric config values.
state_normalized="$tmp_root/state-normalized"
stub_normalized="$tmp_root/stub-normalized"
log_normalized="$tmp_root/normalized.log"
make_stub_chezmoi "$stub_normalized"
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DRIFT_STUB_LOG="$log_normalized" \
  PATH="$stub_normalized:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_normalized" \
  DOTFILES_CHEZMOI_DRIFT_ENABLED=TRUE \
  DOTFILES_CHEZMOI_DRIFT_REFRESH_TTL_SECONDS=abc \
  "$REFRESH"
assert_file_contains "$log_normalized" 'status --exclude=scripts'
assert_file_contains "$state_normalized/state.env" 'DOTFILES_CHEZMOI_DRIFT_NEXT_REFRESH_AFTER='

# Unsupported image mode falls back to an ASCII renderer during refresh.
state_image="$tmp_root/state-image"
stub_dir="$tmp_root/stub-image"
log_image="$tmp_root/image.log"
make_stub_chezmoi "$stub_dir"
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DRIFT_STUB_LOG="$log_image" \
  PATH="$stub_dir:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_image" \
  DOTFILES_CHEZMOI_DRIFT_RENDERER=image \
  "$REFRESH"
assert_file_contains "$state_image/banner.txt" '+-- dotfiles drift'

# Renderer changes invalidate an otherwise fresh cache.
state_renderer="$tmp_root/state-renderer"
stub_renderer="$tmp_root/stub-renderer"
log_renderer="$tmp_root/renderer.log"
make_stub_chezmoi "$stub_renderer"
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DRIFT_STUB_LOG="$log_renderer" \
  PATH="$stub_renderer:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_renderer" \
  DOTFILES_CHEZMOI_DRIFT_RENDERER=compact \
  "$REFRESH"
: >| "$log_renderer"
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DRIFT_STUB_LOG="$log_renderer" \
  PATH="$stub_renderer:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_renderer" \
  DOTFILES_CHEZMOI_DRIFT_RENDERER=box \
  "$REFRESH" --if-stale
assert_file_contains "$log_renderer" 'status --exclude=scripts'
assert_file_contains "$state_renderer/banner.txt" '+-- dotfiles drift'

# Refresh honors current config instead of stale scope stored in state.env.
state_scope="$tmp_root/state-scope"
stub_scope="$tmp_root/stub-scope"
log_scope="$tmp_root/scope.log"
make_stub_chezmoi "$stub_scope"
write_state "$state_scope" sig-scope 3 0
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DRIFT_STUB_LOG="$log_scope" \
  PATH="$stub_scope:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_scope" \
  DOTFILES_CHEZMOI_DRIFT_SCOPE=apply \
  "$REFRESH" --if-stale
assert_file_contains "$log_scope" 'status'
[[ "$(<"$log_scope")" != *'--exclude=scripts'* ]] || die 'refresh used stale files scope from state.env'

# Refresh TTL is recomputed from updated_at and current config, not cached deadline.
state_ttl="$tmp_root/state-ttl"
stub_ttl="$tmp_root/stub-ttl"
log_ttl="$tmp_root/ttl.log"
make_stub_chezmoi "$stub_ttl"
write_state "$state_ttl" sig-ttl 3 "$EPOCHSECONDS"
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DRIFT_STUB_LOG="$log_ttl" \
  PATH="$stub_ttl:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_ttl" \
  DOTFILES_CHEZMOI_DRIFT_REFRESH_TTL_SECONDS=0 \
  "$REFRESH" --if-stale
assert_file_contains "$log_ttl" 'status --exclude=scripts'

# Partial and future-dated caches are not treated as fresh.
state_partial="$tmp_root/state-partial"
stub_partial="$tmp_root/stub-partial"
log_partial="$tmp_root/partial.log"
make_stub_chezmoi "$stub_partial"
write_state "$state_partial" sig-partial 3 "$EPOCHSECONDS"
rm -f "$state_partial/banner.txt" "$state_partial/banner.ansi"
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DRIFT_STUB_LOG="$log_partial" \
  PATH="$stub_partial:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_partial" \
  "$REFRESH" --if-stale
assert_file_contains "$log_partial" 'status --exclude=scripts'

state_future="$tmp_root/state-future"
stub_future="$tmp_root/stub-future"
log_future="$tmp_root/future.log"
make_stub_chezmoi "$stub_future"
write_state "$state_future" sig-future 3 9999999999
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DRIFT_STUB_LOG="$log_future" \
  PATH="$stub_future:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_future" \
  "$REFRESH" --if-stale
assert_file_contains "$log_future" 'status --exclude=scripts'

# A stale interactive cache starts a background refresh.
state_stale="$tmp_root/state-stale"
stub_stale="$tmp_root/stub-stale"
log_stale="$tmp_root/stale.log"
make_stub_chezmoi "$stub_stale"
write_state "$state_stale" sig-stale 3 0
rm -f "$state_stale/status.txt"
output="$(
  run_adapter_tty "$state_stale" "DRIFT_STUB_LOG=${(q)log_stale} DRIFT_STUB_SLEEP=1 PATH=${(q)stub_stale}:/usr/bin:/bin:/usr/sbin:/sbin"
)"
assert_contains "$output" 'dotfiles drift' 'stale cache still prints cached banner'
adapter_elapsed_ms="$(<"$tmp_root/last-adapter-elapsed-ms")"
(( adapter_elapsed_ms < 700 )) || die "stale cache refresh ran in foreground: ${adapter_elapsed_ms}ms"
wait_for_file "$log_stale" || die 'stale cache did not start refresh'
wait_for_file "$state_stale/status.txt" || die 'background refresh did not complete'

# Incomplete fresh lock metadata is treated as an active in-progress lock.
state_incomplete_lock="$tmp_root/state-incomplete-lock"
stub_incomplete_lock="$tmp_root/stub-incomplete-lock"
log_incomplete_lock="$tmp_root/incomplete-lock.log"
make_stub_chezmoi "$stub_incomplete_lock"
mkdir -p "$state_incomplete_lock/refresh.lock"
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DRIFT_STUB_LOG="$log_incomplete_lock" \
  PATH="$stub_incomplete_lock:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_incomplete_lock" \
  "$REFRESH" --if-stale
[[ ! -e "$log_incomplete_lock" ]] || die 'incomplete fresh lock was removed'

# Stale locks are recovered before refreshing.
state_stale_lock="$tmp_root/state-stale-lock"
stub_stale_lock="$tmp_root/stub-stale-lock"
log_stale_lock="$tmp_root/stale-lock.log"
make_stub_chezmoi "$stub_stale_lock"
mkdir -p "$state_stale_lock/refresh.lock"
print -r -- 999999 >| "$state_stale_lock/refresh.lock/owner.pid"
print -r -- 1 >| "$state_stale_lock/refresh.lock/started_at"
print -r -- stale-token >| "$state_stale_lock/refresh.lock/owner.token"
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DRIFT_STUB_LOG="$log_stale_lock" \
  PATH="$stub_stale_lock:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_stale_lock" \
  "$REFRESH" --if-stale
assert_file_contains "$log_stale_lock" 'status --exclude=scripts'
[[ ! -d "$state_stale_lock/refresh.lock" ]] || die 'stale lock was not removed'

# Future-dated lock metadata is treated as corrupt instead of freezing refresh.
state_future_lock="$tmp_root/state-future-lock"
stub_future_lock="$tmp_root/stub-future-lock"
log_future_lock="$tmp_root/future-lock.log"
make_stub_chezmoi "$stub_future_lock"
mkdir -p "$state_future_lock/refresh.lock"
print -r -- $$ >| "$state_future_lock/refresh.lock/owner.pid"
print -r -- 9999999999 >| "$state_future_lock/refresh.lock/started_at"
print -r -- stale-token >| "$state_future_lock/refresh.lock/owner.token"
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DRIFT_STUB_LOG="$log_future_lock" \
  PATH="$stub_future_lock:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_future_lock" \
  "$REFRESH" --if-stale
assert_file_contains "$log_future_lock" 'status --exclude=scripts'
[[ ! -d "$state_future_lock/refresh.lock" ]] || die 'future lock was not removed'

# Old live-PID locks are recovered to avoid PID reuse freezing refresh forever.
state_reused_pid_lock="$tmp_root/state-reused-pid-lock"
stub_reused_pid_lock="$tmp_root/stub-reused-pid-lock"
log_reused_pid_lock="$tmp_root/reused-pid-lock.log"
make_stub_chezmoi "$stub_reused_pid_lock"
mkdir -p "$state_reused_pid_lock/refresh.lock"
print -r -- $$ >| "$state_reused_pid_lock/refresh.lock/owner.pid"
print -r -- 1 >| "$state_reused_pid_lock/refresh.lock/started_at"
print -r -- stale-token >| "$state_reused_pid_lock/refresh.lock/owner.token"
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DRIFT_STUB_LOG="$log_reused_pid_lock" \
  PATH="$stub_reused_pid_lock:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_reused_pid_lock" \
  "$REFRESH" --if-stale
assert_file_contains "$log_reused_pid_lock" 'status --exclude=scripts'
[[ ! -d "$state_reused_pid_lock/refresh.lock" ]] || die 'old live-pid lock was not removed'

# Concurrent refreshes share one active lock.
state_lock="$tmp_root/state-lock"
stub_lock="$tmp_root/stub-lock"
log_lock="$tmp_root/lock.log"
make_stub_chezmoi "$stub_lock"
mkdir -p "$state_lock"
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DRIFT_STUB_LOG="$log_lock" \
  DRIFT_STUB_SLEEP=0.5 \
  PATH="$stub_lock:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_lock" \
  "$REFRESH" --if-stale &
pid1=$!
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DRIFT_STUB_LOG="$log_lock" \
  DRIFT_STUB_SLEEP=0.5 \
  PATH="$stub_lock:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_lock" \
  "$REFRESH" --if-stale &
pid2=$!
wait "$pid1"
wait "$pid2"
lock_log_text="$(<"$log_lock")"
lines=("${(@f)lock_log_text}")
(( $#lines == 1 )) || die "expected one refresh under lock, got $#lines"

# Clean refreshes clear display throttle so recurring drift can show again.
state_clean="$tmp_root/state-clean"
stub_clean="$tmp_root/stub-clean"
log_clean="$tmp_root/clean.log"
make_stub_chezmoi "$stub_clean"
write_state "$state_clean" sig-clean 2 0
print -r -- sig-clean >| "$state_clean/last_shown_signature"
print -r -- "$EPOCHSECONDS" >| "$state_clean/last_shown"
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DRIFT_STUB_LOG="$log_clean" \
  DRIFT_STUB_CLEAN=1 \
  PATH="$stub_clean:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_clean" \
  "$REFRESH"
[[ ! -e "$state_clean/last_shown_signature" ]] || die 'clean refresh left last_shown_signature behind'

# Successful stderr does not count as drift.
state_stderr="$tmp_root/state-stderr"
stub_stderr="$tmp_root/stub-stderr"
log_stderr="$tmp_root/stderr.log"
make_stub_chezmoi "$stub_stderr"
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DRIFT_STUB_LOG="$log_stderr" \
  DRIFT_STUB_CLEAN=1 \
  DRIFT_STUB_STDERR='benign warning' \
  PATH="$stub_stderr:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_stderr" \
  "$REFRESH"
assert_file_contains "$state_stderr/state.env" 'DOTFILES_CHEZMOI_DRIFT_STATUS_COUNT=0'
[[ ! -s "$state_stderr/banner.txt" ]] || die 'stderr-only status produced a banner'

# Refresh failures write last_error and do not remove an existing banner.
state_fail="$tmp_root/state-fail"
stub_fail="$tmp_root/stub-fail"
log_fail="$tmp_root/fail.log"
make_stub_chezmoi "$stub_fail"
write_state "$state_fail" sig-fail
set +e
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DRIFT_STUB_LOG="$log_fail" \
  DRIFT_STUB_FAIL=1 \
  PATH="$stub_fail:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_fail" \
  "$REFRESH"
refresh_status=$?
set -e
(( refresh_status != 0 )) || die 'expected refresh failure'
assert_file_contains "$state_fail/last_error" 'stub failure'
assert_file_contains "$state_fail/banner.txt" 'dotfiles drift'
assert_file_contains "$state_fail/state.env" 'DOTFILES_CHEZMOI_DRIFT_STATUS_COUNT=3'
assert_file_contains "$state_fail/state.env" 'DOTFILES_CHEZMOI_DRIFT_SIGNATURE=sig-fail'

# Failed refreshes for a different scope do not publish stale old-scope drift.
state_fail_scope="$tmp_root/state-fail-scope"
stub_fail_scope="$tmp_root/stub-fail-scope"
log_fail_scope="$tmp_root/fail-scope.log"
make_stub_chezmoi "$stub_fail_scope"
write_state "$state_fail_scope" sig-fail-scope
set +e
/usr/bin/env -i \
  HOME="$render_home" \
  XDG_CONFIG_HOME="$render_home/.config" \
  XDG_STATE_HOME="$render_home/.local/state" \
  DRIFT_STUB_LOG="$log_fail_scope" \
  DRIFT_STUB_FAIL=1 \
  PATH="$stub_fail_scope:/usr/bin:/bin:/usr/sbin:/sbin" \
  DOTFILES_CHEZMOI_DRIFT_STATE_DIR="$state_fail_scope" \
  DOTFILES_CHEZMOI_DRIFT_SCOPE=apply \
  "$REFRESH" --if-stale
refresh_status=$?
set -e
(( refresh_status != 0 )) || die 'expected scoped refresh failure'
assert_file_contains "$state_fail_scope/state.env" 'DOTFILES_CHEZMOI_DRIFT_SCOPE=apply'
assert_file_contains "$state_fail_scope/state.env" 'DOTFILES_CHEZMOI_DRIFT_SIGNATURE=error'
assert_file_contains "$state_fail_scope/state.env" 'DOTFILES_CHEZMOI_DRIFT_RESULT=error'

# Startup failure retry is cooled down after last_error is written.
state_startup_fail="$tmp_root/state-startup-fail"
stub_startup_fail="$tmp_root/stub-startup-fail"
log_startup_fail="$tmp_root/startup-fail.log"
make_stub_chezmoi "$stub_startup_fail"
write_state "$state_startup_fail" sig-startup-fail 0 0 ''
output="$(
  run_adapter_tty "$state_startup_fail" "DRIFT_STUB_LOG=${(q)log_startup_fail} DRIFT_STUB_FAIL=1 PATH=${(q)stub_startup_fail}:/usr/bin:/bin:/usr/sbin:/sbin"
)"
assert_empty "$output" 'startup refresh failure output'
wait_for_file "$state_startup_fail/last_error" || die 'startup refresh failure did not write last_error'
output="$(
  run_adapter_tty "$state_startup_fail" "DRIFT_STUB_LOG=${(q)log_startup_fail} DRIFT_STUB_FAIL=1 PATH=${(q)stub_startup_fail}:/usr/bin:/bin:/usr/sbin:/sbin"
)"
assert_empty "$output" 'cooled down startup refresh failure output'
startup_fail_log_text="$(<"$log_startup_fail")"
startup_fail_lines=("${(@f)startup_fail_log_text}")
(( $#startup_fail_lines == 1 )) || die "startup failure did not cool down retries; got $#startup_fail_lines calls"

print -- 'OK chezmoi-drift-banner'
