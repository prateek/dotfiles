#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "grmrepo-refresh: $*"
  exit 1
}

assert_contains_line() {
  local haystack="$1"
  local needle="$2"
  print -r -- "$haystack" | grep -Fqx "$needle" || die "missing line: $needle"
}

assert_not_contains_line() {
  local haystack="$1"
  local needle="$2"
  if print -r -- "$haystack" | grep -Fqx "$needle"; then
    die "unexpected line: $needle"
  fi
}

DOTFILES_ROOT="${0:A:h:h}"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

export HOME="$tmp_root/home"
export GHPATH="$HOME/code/github.com"
mkdir -p "$HOME" "$GHPATH"

create_repo() {
  local dir="$1"
  local remote="${2:-}"

  mkdir -p "$dir"
  git init -q "$dir"
  (
    cd "$dir"
    git config user.email test@example.com
    git config user.name test
    : > README.md
    git add README.md
    git commit -qm init
    if [[ -n "$remote" ]]; then
      git remote add origin "$remote"
    fi
  )
}

config_path="$tmp_root/grm-config.toml"
create_repo "$GHPATH/test-owner/test-repo" "git@github.com:test-owner/test-repo.git"

echo "• grmrepo-refresh emits a tree per owner with canonical-root header"
GRMREPO_CONFIG="$config_path" zsh "$DOTFILES_ROOT/bin/grmrepo-refresh" >/dev/null
config_contents="$(<"$config_path")"
assert_contains_line "$config_contents" "# Canonical clone root:"
assert_contains_line "$config_contents" "#   - ~/code/github.com/<owner>/<repo>"
assert_contains_line "$config_contents" "[[trees]]"
assert_contains_line "$config_contents" "root = \"~/code/github.com/test-owner\""
assert_contains_line "$config_contents" "name = \"test-repo\""
assert_contains_line "$config_contents" "url = \"git@github.com:test-owner/test-repo.git\""
