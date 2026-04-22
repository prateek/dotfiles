#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "repo-index: $*"
  exit 1
}

assert_eq() {
  local got="$1"
  local want="$2"
  [[ "$got" == "$want" ]] || die "assert_eq failed: got='$got' want='$want'"
}

assert_contains_line() {
  local haystack="$1"
  local needle="$2"
  print -r -- "$haystack" | grep -Fqx "$needle" || die "missing line: $needle"
}

DOTFILES_ROOT="${0:A:h:h}"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

export HOME="$tmp_root/home"
export GHPATH="$tmp_root/code/github.com"
mkdir -p "$HOME" "$GHPATH" "$HOME/code"

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

create_repo "$GHPATH/test-owner/test-repo"
create_repo "$HOME/code/openai" "git@github.com:openai/openai.git"

mkdir -p "$GHPATH/test-owner/worktree-like"
cat >"$GHPATH/test-owner/worktree-like/.git" <<'EOF'
gitdir: /tmp/not-a-real-worktree
EOF

echo "• repo-index emits canonical clones as TSV"
tsv_output="$(zsh "$DOTFILES_ROOT/bin/repo-index" --format tsv)"
assert_contains_line "$tsv_output" "openai/openai	https://github.com/openai/openai	$HOME/code/openai"
assert_contains_line "$tsv_output" "test-owner/test-repo	https://github.com/test-owner/test-repo	$GHPATH/test-owner/test-repo"
if print -r -- "$tsv_output" | grep -Fq "worktree-like"; then
  die "expected worktree-like entry to be ignored"
fi

echo "• repo-index emits slugs"
slugs_output="$(zsh "$DOTFILES_ROOT/bin/repo-index" --format slugs)"
assert_contains_line "$slugs_output" "openai/openai"
assert_contains_line "$slugs_output" "test-owner/test-repo"

echo "• repo-index rejects unsupported formats"
set +e
invalid_output="$(zsh "$DOTFILES_ROOT/bin/repo-index" --format nope 2>&1)"
invalid_rc=$?
set -e
assert_eq "$invalid_rc" "2"
print -r -- "$invalid_output" | grep -Fq "repo-index: unknown format: nope" || die "expected invalid format error"
