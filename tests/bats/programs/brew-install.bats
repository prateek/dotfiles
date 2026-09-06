load '../../support/common'

setup() {
  setup_fixture
  scenario="$DOTFILES_ROOT/tests/scenarios/programs/brew-install.zsh"
  export DOTFILES_BREW_INSTALL_ROOT="$FIXTURE/dotfiles"
  export BREW_INSTALL_BRANCH_STAMP=20260512010203
  git init -q --bare --initial-branch=master "$FIXTURE/origin.git"
  git init -q --initial-branch=master "$FIXTURE/seed"
  git -C "$FIXTURE/seed" config user.name test
  git -C "$FIXTURE/seed" config user.email test@example.com
  git -C "$FIXTURE/seed" config maintenance.auto false
  git -C "$FIXTURE/seed" commit -q --allow-empty -m init
  git -C "$FIXTURE/seed" remote add origin "$FIXTURE/origin.git"
  git -C "$FIXTURE/seed" push -q -u origin master
  git clone -q "$FIXTURE/origin.git" "$DOTFILES_BREW_INSTALL_ROOT"
  mkdir -p "$FIXTURE/autoload" "$FIXTURE/empty-autoload"
  cat > "$FIXTURE/autoload/w" <<'STUB'
function w() {
  printf '%s\0' "$@" > "$FIXTURE/worktree.args"
}
STUB
}

@test "Brew adoption delegates the literal request to Claude print mode in a trunk worktree" {
  run_zsh 0 "$scenario" defined fd
  assert_success
  mapfile -d '' -t args < "$FIXTURE/worktree.args"
  [ "${#args[@]}" -eq 10 ]
  [ "${args[0]}" = run ]
  [ "${args[1]}" = prateek/brew-install-fd-20260512010203 ]
  [ "${args[2]}" = --repo ]
  [ "${args[3]}" = "$(cd "$DOTFILES_BREW_INSTALL_ROOT" && pwd -P)" ]
  [ "${args[4]}" = --base ]
  [ "${args[5]}" = origin/master ]
  [ "${args[6]}" = --agent ]
  [ "${args[7]}" = 'claude -p' ]
  [ "${args[8]}" = -- ]
  [[ "${args[9]}" == *'Install/adopt this package request'* ]]
  [[ "${args[9]}" == *$'\nfd\n'* ]]
  [[ "${args[9]}" == *'You are running in a dedicated dotfiles worktree created from origin/master.'* ]]
  [[ "${args[9]}" == *'Dangerous bypass mode requested by wrapper: 0'* ]]
}

@test "Brew adoption enables permission bypass only with explicit yes and honors the requested branch" {
  run_zsh 0 "$scenario" defined --yes --branch prateek/custom-package jq
  assert_success
  mapfile -d '' -t args < "$FIXTURE/worktree.args"
  [ "${args[1]}" = prateek/custom-package ]
  [ "${args[7]}" = 'claude --dangerously-skip-permissions -p' ]
  [[ "${args[9]}" == *$'\njq\n'* ]]
  [[ "${args[9]}" == *'Dangerous bypass mode requested by wrapper: 1'* ]]
}

@test "Brew adoption bounds long generated branches and normalizes repeated dots" {
  run_zsh 0 "$scenario" defined 'This package name is deliberately much longer than sixty characters and includes punctuation .. spaces'
  assert_success
  mapfile -d '' -t args < "$FIXTURE/worktree.args"
  [ "${args[1]}" = prateek/brew-install-this-package-name-is-deliberately-much-longer-than-sixty-cha-20260512010203 ]
  run -0 git check-ref-format --branch "${args[1]}"
  assert_success
  run_zsh 0 "$scenario" defined foo..bar
  assert_success
  mapfile -d '' -t args < "$FIXTURE/worktree.args"
  [ "${args[1]}" = prateek/brew-install-foo-bar-20260512010203 ]
}

@test "Brew adoption autoloads the worktree helper" {
  run_zsh 0 "$scenario" autoload rg
  assert_success
  mapfile -d '' -t args < "$FIXTURE/worktree.args"
  [ "${args[0]}" = run ]
  [ "${args[1]}" = prateek/brew-install-rg-20260512010203 ]
}

@test "Brew adoption refuses a missing autoload helper before invoking any command fallback" {
  cat > "$FIXTURE/bin/w" <<'STUB'
#!/bin/sh
touch "$FIXTURE/fallback.called"
STUB
  chmod +x "$FIXTURE/bin/w"
  run_zsh 127 "$scenario" missing --trunk origin/master jq
  assert_failure 127
  [[ "$stderr" == *'missing w worktree helper'* ]]
  [ ! -e "$FIXTURE/worktree.args" ]
  [ ! -e "$FIXTURE/fallback.called" ]
}

@test "Brew adoption refuses invalid or existing explicit branches before worktree creation" {
  run_zsh 1 "$scenario" defined --branch bad..branch jq
  assert_failure 1
  [[ "$stderr" == *'invalid branch name: bad..branch'* ]]
  [ ! -e "$FIXTURE/worktree.args" ]
  git -C "$DOTFILES_BREW_INSTALL_ROOT" branch prateek/existing
  run_zsh 1 "$scenario" defined --branch prateek/existing jq
  assert_failure 1
  [[ "$stderr" == *'branch already exists: prateek/existing'* ]]
  [ ! -e "$FIXTURE/worktree.args" ]
}
