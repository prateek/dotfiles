#!/usr/bin/env zsh
# Tests for the brew:install autoload wrapper.

set -euo pipefail

die() {
  print -u2 -- "brew-install-wrapper: $*"
  exit 1
}

assert_eq() {
  local got="$1"
  local want="$2"
  [[ "$got" == "$want" ]] || die "assert_eq failed: got='$got' want='$want'"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || die "expected to find '$needle' in: $haystack"
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "missing required command: $cmd"
}

DOTFILES_ROOT="${0:A:h:h}"

require_cmd git
require_cmd python3

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

export HOME="$tmp_root/home"
mkdir -p "$HOME"

remote="$tmp_root/remote.git"
seed="$tmp_root/seed"
dotfiles="$tmp_root/dotfiles"

git init -q --bare --initial-branch=master "$remote"
git init -q --initial-branch=master "$seed"
(
  cd "$seed"
  git config user.email test@example.com
  git config user.name test
  git remote add origin "$remote"
  mkdir -p home/.chezmoidata
  print -r -- "[packages]" > home/.chezmoidata/packages.toml
  git add -A
  git commit -qm init
  git push -q -u origin master
)
git clone -q "$remote" "$dotfiles"
git -C "$dotfiles" remote set-head origin -a >/dev/null 2>&1 || true

fpath=("$DOTFILES_ROOT/home/dot_config/zsh/autoload" $fpath)
autoload -Uz brew:install

export DOTFILES_BREW_INSTALL_ROOT="$dotfiles"
export BREW_INSTALL_BRANCH_STAMP="20260512010203"
export W_ARGS_FILE="$tmp_root/w-args.bin"

codex() {
  :
}

w() {
  : >"$W_ARGS_FILE"
  local arg
  for arg in "$@"; do
    printf '%s\0' "$arg" >>"$W_ARGS_FILE"
  done
}

read_w_arg() {
  local index="$1"
  python3 - "$W_ARGS_FILE" "$index" <<'PY'
import sys
path, index = sys.argv[1], int(sys.argv[2])
parts = open(path, "rb").read().split(b"\0")
if parts and parts[-1] == b"":
    parts.pop()
print(parts[index].decode())
PY
}

read_w_count() {
  python3 - "$W_ARGS_FILE" <<'PY'
import sys
parts = open(sys.argv[1], "rb").read().split(b"\0")
if parts and parts[-1] == b"":
    parts.pop()
print(len(parts))
PY
}

echo "• default uses vanilla codex exec in a trunk-based worktree"
brew:install fd >/dev/null

assert_eq "$(read_w_count)" "10"
assert_eq "$(read_w_arg 0)" "run"
assert_eq "$(read_w_arg 1)" "prateek/brew-install-fd-20260512010203"
assert_eq "$(read_w_arg 2)" "--repo"
assert_eq "$(read_w_arg 3)" "${dotfiles:A}"
assert_eq "$(read_w_arg 4)" "--base"
assert_eq "$(read_w_arg 5)" "origin/master"
assert_eq "$(read_w_arg 6)" "--agent"
assert_eq "$(read_w_arg 7)" "codex exec --skip-git-repo-check"
assert_eq "$(read_w_arg 8)" "--"
prompt="$(read_w_arg 9)"
assert_contains "$prompt" "Install/adopt this package request"
assert_contains "$prompt" $'\nfd\n'
assert_contains "$prompt" "You are running in a dedicated dotfiles worktree created from origin/master."
assert_contains "$prompt" "Dangerous bypass mode requested by wrapper: 0"

echo "• --yes gates dangerous Codex mode"
brew:install --yes --branch prateek/custom-package jq >/dev/null

assert_eq "$(read_w_arg 1)" "prateek/custom-package"
assert_eq "$(read_w_arg 7)" "codex --dangerously-bypass-approvals-and-sandbox exec --skip-git-repo-check"
prompt="$(read_w_arg 9)"
assert_contains "$prompt" "jq"
assert_contains "$prompt" "Dangerous bypass mode requested by wrapper: 1"

echo "• generated branches are bounded and valid"
long_request="This package name is deliberately much longer than sixty characters and includes punctuation .. spaces"
brew:install "$long_request" >/dev/null
generated_branch="$(read_w_arg 1)"
assert_contains "$generated_branch" "prateek/brew-install-this-package-name-is-deliberately-much-longer-than-sixty-cha"
git -C "$dotfiles" check-ref-format --branch "$generated_branch" >/dev/null \
  || die "expected generated branch to be a valid git branch: $generated_branch"

echo "• generated branches normalize dots"
brew:install 'foo..bar' >/dev/null
assert_eq "$(read_w_arg 1)" "prateek/brew-install-foo-bar-20260512010203"

echo "• wrapper autoloads the dotfiles w helper"
unfunction w
mkdir -p "$tmp_root/autoload"
cat >"$tmp_root/autoload/w" <<'EOF'
function w() {
  : >"$W_ARGS_FILE"
  local arg
  for arg in "$@"; do
    printf '%s\0' "$arg" >>"$W_ARGS_FILE"
  done
}
w "$@"
EOF
fpath=("$tmp_root/autoload" $fpath)
brew:install rg >/dev/null
assert_eq "$(read_w_arg 0)" "run"
assert_eq "$(read_w_arg 1)" "prateek/brew-install-rg-20260512010203"

echo "• missing w helper fails before command fallback"
unfunction w
mkdir -p "$tmp_root/empty-autoload"
fpath=("$tmp_root/empty-autoload")
if brew:install --trunk origin/master jq >/dev/null 2>&1; then
  die "expected missing w helper to fail"
fi
fpath=("$tmp_root/autoload" "$DOTFILES_ROOT/home/dot_config/zsh/autoload" $fpath)

echo "• invalid explicit branches fail before worktree creation"
if brew:install --branch 'bad..branch' jq >/dev/null 2>&1; then
  die "expected invalid explicit branch to fail"
fi

echo "• explicit branches must not already exist"
(
  cd "$dotfiles"
  git switch -q -c prateek/existing
)
if brew:install --branch prateek/existing jq >/dev/null 2>&1; then
  die "expected existing explicit branch to fail"
fi

echo "OK brew-install-wrapper"
