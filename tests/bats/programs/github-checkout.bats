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
printf '%s\n' "$*" >> "$GHC_TEST_LOG.commands"
[ "${1:-}" = -C ] && shift 2
case "${1:-}" in
  clone)
    eval "url=\${$(($# - 1))}" "dir=\${$#}"
    printf '%s\n' "$url" "$dir" >> "$GHC_TEST_LOG"
    mkdir -p "$dir/.git"
    ;;
  config)
    [ "$*" = 'config --get spice.branchCreate.prefix' ] && [ -n "${GHC_TEST_PREFIX:-}" ] || exit 1
    printf '%s\n' "$GHC_TEST_PREFIX"
    ;;
  status) ;;
  symbolic-ref) printf '%s\n' refs/remotes/origin/main ;;
  checkout|pull|remote|fetch|maintenance) ;;
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
  assert_equal "$(head -n 1 "$GHC_TEST_LOG.commands")" "clone git@github.com:prateek/w.git $GHPATH/prateek/w"
  assert_equal "$(cat "$FIXTURE/pwd")" "$(cd "$GHPATH/prateek/w" && pwd -P)"
}

# Real git against a local bare origin; only `maintenance start` is stubbed so
# the test never installs launchd jobs.
use_real_git_with_origin() {
  real_git="$(PATH="${PATH#"$FIXTURE/bin:"}" command -v git)"
  cat > "$FIXTURE/bin/git" <<STUB
#!/bin/sh
if [ "\$1 \$2 \$3 \$4" = "-C \$2 maintenance start" ]; then
  printf '%s\\n' "\$2" >> "$FIXTURE/maintenance-started"
  exit 0
fi
exec "$real_git" "\$@"
STUB
  chmod +x "$FIXTURE/bin/git"
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
  local seed="$FIXTURE/seed" origin="$FIXTURE/origin/prateek/big.git"
  "$real_git" init -q -b main "$seed"
  "$real_git" -C "$seed" commit -q --allow-empty -m one
  "$real_git" -C "$seed" tag v1
  "$real_git" -C "$seed" branch prateek/mine
  "$real_git" -C "$seed" branch other/theirs
  "$real_git" init -q --bare -b main "$origin"
  "$real_git" -C "$origin" config uploadpack.allowFilter true
  "$real_git" -C "$seed" push -q --tags "$origin" 'refs/heads/*:refs/heads/*'
  mkdir -p "$HOME/.config/git"
  export GIT_CONFIG_GLOBAL="$FIXTURE/gitconfig"
  cat > "$GIT_CONFIG_GLOBAL" <<CONFIG
[url "file://$FIXTURE/origin/"]
	insteadOf = git@github.com:
[spice "branchCreate"]
	prefix = ${1-prateek/}
[include]
	path = $HOME/.config/git/config.local
CONFIG
  cp "$GIT_CONFIG_GLOBAL" "$FIXTURE/gitconfig.before"
}

@test "ghc --large makes an unshallow partial clone of trunk and the branch prefix, without tags" {
  use_real_git_with_origin
  run_zsh 0 "$scenario" ghc prateek/big --large
  assert_success
  dir="$GHPATH/prateek/big"
  assert_equal "$(git -C "$dir" config remote.origin.partialclonefilter)" blob:none
  assert_equal "$(git -C "$dir" rev-parse --is-shallow-repository)" false
  assert_equal "$(git -C "$dir" config remote.origin.tagOpt)" --no-tags
  assert_equal "$(git -C "$dir" tag)" ''
  assert_equal "$(git -C "$dir" for-each-ref --format='%(refname)' refs/remotes/origin | sort)" \
    "$(printf '%s\n' refs/remotes/origin/HEAD refs/remotes/origin/main refs/remotes/origin/prateek/mine)"
}

@test "ghc --large registers maintenance in config.local and leaves the managed global config alone" {
  use_real_git_with_origin
  run_zsh 0 "$scenario" ghc --large prateek/big
  assert_success
  dir="$(cd "$GHPATH/prateek/big" && pwd -P)"
  assert_equal "$(git config --file "$HOME/.config/git/config.local" --get-all maintenance.repo)" "$dir"
  cmp "$FIXTURE/gitconfig.before" "$GIT_CONFIG_GLOBAL"
  assert_equal "$(cat "$FIXTURE/maintenance-started")" "$GHPATH/prateek/big"
}

@test "ghc --large without a git-spice prefix tracks only the default branch" {
  use_real_git_with_origin ''
  run_zsh 0 "$scenario" ghc --large prateek/big
  assert_success
  assert_equal "$(git -C "$GHPATH/prateek/big" config --get-all remote.origin.fetch)" \
    '+refs/heads/main:refs/remotes/origin/main'
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

@test "ohc --large in any position clones through ghc --large and keeps the flag out of Orca" {
  run_zsh 0 "$scenario" ohc prateek/big --agent codex --large
  assert_success
  assert_regex "$(head -n 1 "$GHC_TEST_LOG.commands")" '^clone --filter=blob:none --no-tags --single-branch '
  mapfile -d '' -t invocation < "$ORCA_TEST_LOG.create"
  for arg in "${invocation[@]}"; do
    [ "$arg" != --large ]
  done
}
