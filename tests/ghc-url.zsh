#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "ghc-url: $*"
  exit 1
}

assert_eq() {
  local got="$1"
  local want="$2"
  [[ "$got" == "$want" ]] || die "assert_eq failed: got='$got' want='$want'"
}

DOTFILES_ROOT="${0:A:h:h}"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

export HOME="$tmp_root/home"
export GHPATH="$tmp_root/code/github.com"
mkdir -p "$HOME" "$GHPATH"

stub_bin="$tmp_root/bin"
mkdir -p "$stub_bin"
export PATH="$stub_bin:/usr/bin:/bin"
export GHC_TEST_LOG="$tmp_root/ghc.log"

cat >"$stub_bin/git" <<'EOF'
#!/bin/sh
set -eu

log="${GHC_TEST_LOG:?}"

case "${1:-}" in
  clone)
    printf 'clone\t%s\t%s\n' "${2:-}" "${3:-}" >>"$log"
    mkdir -p "${3:?missing target}/.git"
    exit 0
    ;;
  status)
    exit 0
    ;;
  symbolic-ref)
    printf '%s\n' 'refs/remotes/origin/HEAD'
    exit 0
    ;;
  show-ref)
    exit 1
    ;;
  checkout|pull)
    exit 0
    ;;
esac

printf 'unexpected git invocation: %s\n' "$*" >&2
exit 1
EOF
chmod +x "$stub_bin/git"

echo "• ghc clones explicit GitHub URLs over SSH"
: >"$GHC_TEST_LOG"
GHPATH="$tmp_root/code/github.com" \
  zsh "$DOTFILES_ROOT/zsh/autoload/ghc" "https://github.com/prateek/w"

clone_url="$(awk -F '\t' 'NR==1 { print $2 }' "$GHC_TEST_LOG")"
target_path="$(awk -F '\t' 'NR==1 { print $3 }' "$GHC_TEST_LOG")"
assert_eq "$clone_url" "git@github.com:prateek/w.git"
assert_eq "$target_path" "$tmp_root/code/github.com/prateek/w"
