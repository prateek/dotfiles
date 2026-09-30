load '../../support/common'

setup() {
  setup_fixture
  export ONSTART_LOG="$FIXTURE/calls"
  : >"$ONSTART_LOG"
  script="$DOTFILES_ROOT/scripts/devbox/onstart"
  state="$XDG_STATE_HOME/dotfiles"
  mkdir -p "$HOME/.local/bin"
  stub chezmoi 'if [[ "$*" == *execute-template* ]]; then printf "%s\n" "${STUB_MACHINE_TYPE:-devbox}"; fi'
  # flock -n <fd|file> [command]: fail when the test holds the lock.
  stub flock '[[ -z "${STUB_LOCK_HELD:-}" ]] || exit 1; shift 2; [[ $# -eq 0 ]] || "$@"'
  stub setsid ''
  stub "$HOME/.local/bin/orca-devpod-reconcile" ''
}

# Each stub records its name and arguments, then runs its body.
stub() {
  local path="$1"
  [[ "$path" == /* ]] || path="$FIXTURE/bin/$path"
  printf '#!/usr/bin/env bash\nprintf "%%s %%s\\n" "${0##*/}" "$*" >>"$ONSTART_LOG"\n%s\n' "$2" >"$path"
  chmod +x "$path"
}

wait_for_log() {
  local _
  for _ in $(seq 50); do
    grep -Fxq "$1" "$ONSTART_LOG" && return
    sleep 0.1
  done
  return 1
}

@test "The first boot detaches the first apply and touches nothing else" {
  run_bash 0 "$script"
  assert_success
  [[ "$stderr" == *"first apply detached; follow $state/devbox-first-apply.log"* ]]
  wait_for_log "setsid $script --first-apply"
  run grep -v '^flock ' "$ONSTART_LOG"
  assert_output "setsid $script --first-apply"
}

@test "A boot during the first apply leaves it running" {
  STUB_LOCK_HELD=1 run_bash 0 "$script"
  assert_success
  [[ "$stderr" == *"first apply still running"* ]]
  run grep -v '^flock ' "$ONSTART_LOG"
  assert_failure
}

@test "The first apply selects devbox, applies, marks success, and starts Orca" {
  DEVBOX_ORCA_HEADLESS_ENABLED=true run_bash 0 "$script" --first-apply
  assert_success
  [ -e "$state/devbox-first-apply.done" ]
  run cat "$ONSTART_LOG"
  assert_line --index 1 "chezmoi --no-pager --no-tty init --source $DOTFILES_ROOT --promptChoice machine_type=devbox"
  assert_line --index 3 "chezmoi --no-pager --no-tty apply"
  assert_line --index 4 "orca-devpod-reconcile start"
}

@test "The first apply refuses a config of another machine type" {
  STUB_MACHINE_TYPE=work run_bash 1 "$script" --first-apply
  assert_failure
  [[ "$stderr" == *"refusing to apply machine_type=work (expected devbox)"* ]]
  [ ! -e "$state/devbox-first-apply.done" ]
  run grep -E '^(chezmoi --no-pager --no-tty apply|orca-devpod-reconcile .*)$' "$ONSTART_LOG"
  assert_failure
}

@test "Later boots only reconcile Orca, detached, as the env says" {
  stub setsid 'exec "$@"'
  mkdir -p "$state"
  touch "$state/devbox-first-apply.done"
  DEVBOX_ORCA_HEADLESS_ENABLED=true run_bash 0 "$script"
  assert_success
  wait_for_log "orca-devpod-reconcile start"
  DEVBOX_ORCA_HEADLESS_ENABLED=false run_bash 0 "$script"
  assert_success
  wait_for_log "orca-devpod-reconcile stop"
  run grep -v '^flock ' "$ONSTART_LOG"
  assert_output $'setsid '"$script"$' --reconcile-orca\norca-devpod-reconcile start\nsetsid '"$script"$' --reconcile-orca\norca-devpod-reconcile stop'
}
