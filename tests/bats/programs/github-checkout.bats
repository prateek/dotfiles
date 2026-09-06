# Injection probes must remain literal arguments.
# shellcheck disable=SC2016
load '../../support/common'

setup() {
  setup_fixture
  export GHPATH="$FIXTURE/code/github.com"
  export GHC_TEST_LOG="$FIXTURE/git.log" ORCA_TEST_LOG="$FIXTURE/orca"
  scenario="$DOTFILES_ROOT/tests/scenarios/programs/github-checkout.zsh"
  cat > "$FIXTURE/bin/git" <<'STUB'
#!/bin/sh
set -eu
case "${1:-}" in
  clone)
    printf '%s\n' "$2" "$3" >> "$GHC_TEST_LOG"
    mkdir -p "$3/.git"
    ;;
  status) ;;
  symbolic-ref) printf '%s\n' refs/remotes/origin/main ;;
  checkout|pull) ;;
  *) printf 'unexpected git command: %s\n' "$*" >&2; exit 99 ;;
esac
STUB
  cat > "$FIXTURE/bin/orca" <<'STUB'
#!/bin/sh
set -eu
case "${1:-} ${2:-}" in
  'status --json') printf '{"ok":true}\n' ;;
  'repo add')
    [ "$3" = --path ] && [ -d "$4/.git" ]
    printf '%s\n' "$4" > "$ORCA_TEST_LOG.registered"
    printf '{"ok":true}\n'
    ;;
  'worktree create')
    [ -s "$ORCA_TEST_LOG.registered" ]
    printf '%s\0' "$@" > "$ORCA_TEST_LOG.create"
    printf '{"ok":true,"result":{"worktree":{"id":"worktree-id"}}}\n'
    ;;
  *) printf 'unexpected orca command: %s\n' "$*" >&2; exit 99 ;;
esac
STUB
  chmod +x "$FIXTURE/bin/git" "$FIXTURE/bin/orca"
}

@test "ghc clones an explicit GitHub URL over SSH and changes the caller directory" {
  run_zsh 0 "$scenario" ghc https://github.com/prateek/w
  assert_success
  mapfile -t cloned < "$GHC_TEST_LOG"
  assert_equal "${cloned[0]}" 'git@github.com:prateek/w.git'
  assert_equal "${cloned[1]}" "$GHPATH/prateek/w"
  assert_equal "$(cat "$FIXTURE/pwd")" "$(cd "$GHPATH/prateek/w" && pwd -P)"
}

@test "ohc without a repository explains usage on stderr and exits 2" {
  run_zsh 2 "$scenario" ohc
  assert_failure 2
  assert_output ''
  assert_regex "$stderr" 'usage: ohc'
  assert_regex "$stderr" 'ohc --help'
}

@test "ohc help documents worktree options and repository ownership" {
  run_zsh 0 "$scenario" ohc --help
  assert_success
  assert_output --partial '--base-branch <ref>'
  assert_output --partial '--agent <id>'
  assert_output --partial 'Do not pass --repo'
  assert_equal "$stderr" ''
}

@test "ohc rejects a repository override before cloning or registering" {
  run_zsh 2 "$scenario" ohc prateek/ohc-test --repo id:other
  assert_failure 2
  assert_regex "$stderr" --repo
  [ ! -e "$GHC_TEST_LOG" ]
  [ ! -e "$ORCA_TEST_LOG.registered" ]
  [ ! -e "$ORCA_TEST_LOG.create" ]
}

@test "ohc registers the clone and forwards literal worktree arguments" {
  run_zsh 0 "$scenario" ohc https://github.com/prateek/ohc-test --agent codex --prompt 'hi ; $(touch injected) *'
  assert_success
  mapfile -t cloned < "$GHC_TEST_LOG"
  assert_equal "${cloned[0]}" 'git@github.com:prateek/ohc-test.git'
  assert_equal "${cloned[1]}" "$GHPATH/prateek/ohc-test"
  expected_path="$(cd "$GHPATH/prateek/ohc-test" && pwd -P)"
  assert_equal "$(cat "$ORCA_TEST_LOG.registered")" "$expected_path"
  mapfile -d '' -t invocation < "$ORCA_TEST_LOG.create"
  for ((i = 2; i < ${#invocation[@]}; i++)); do
    case "${invocation[i]}" in
      --repo) repo="${invocation[i+1]}" ;;
      --name) name="${invocation[i+1]}" ;;
      --agent) agent="${invocation[i+1]}" ;;
      --prompt) prompt="${invocation[i+1]}" ;;
    esac
  done
  assert_equal "${repo:-}" "path:$expected_path"
  assert_equal "${name:-}" ohc-test
  assert_equal "${agent:-}" codex
  assert_equal "${prompt:-}" 'hi ; $(touch injected) *'
  [ ! -e "$expected_path/injected" ]
}
