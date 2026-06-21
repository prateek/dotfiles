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

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || die "assert_contains failed: missing '$needle' in '$haystack'"
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
export ORCA_TEST_LOG="$tmp_root/orca.log"
export FPATH="$DOTFILES_ROOT/home/dot_config/zsh/autoload:${FPATH:-}"

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

cat >"$stub_bin/orca" <<'EOF'
#!/bin/sh
set -eu

log="${ORCA_TEST_LOG:?}"

if [ "${1:-}" = "status" ] && [ "${2:-}" = "--json" ]; then
  printf 'status\n' >>"$log"
  printf '{"ok":true}\n'
  exit 0
fi

if [ "${1:-}" = "repo" ] && [ "${2:-}" = "add" ]; then
  {
    printf 'repo-add'
    while [ "$#" -gt 0 ]; do
      printf '\t%s' "$1"
      shift
    done
    printf '\n'
  } >>"$log"
  printf '{"ok":true,"result":{"repo":{"id":"repo-id"}}}\n'
  exit 0
fi

if [ "${1:-}" = "worktree" ] && [ "${2:-}" = "create" ]; then
  {
    printf 'worktree-create'
    while [ "$#" -gt 0 ]; do
      printf '\t%s' "$1"
      shift
    done
    printf '\n'
  } >>"$log"
  printf '{"ok":true,"result":{"worktree":{"id":"worktree-id"}}}\n'
  exit 0
fi

printf 'unexpected orca invocation: %s\n' "$*" >&2
exit 1
EOF
chmod +x "$stub_bin/orca"

echo "• ghc clones explicit GitHub URLs over SSH"
: >"$GHC_TEST_LOG"
GHPATH="$tmp_root/code/github.com" \
  zsh "$DOTFILES_ROOT/home/dot_config/zsh/autoload/ghc" "https://github.com/prateek/w"

clone_url="$(awk -F '\t' 'NR==1 { print $2 }' "$GHC_TEST_LOG")"
target_path="$(awk -F '\t' 'NR==1 { print $3 }' "$GHC_TEST_LOG")"
assert_eq "$clone_url" "git@github.com:prateek/w.git"
assert_eq "$target_path" "$tmp_root/code/github.com/prateek/w"

echo "• ohc returns usage without a repo argument"
set +e
zsh "$DOTFILES_ROOT/home/dot_config/zsh/autoload/ohc" >"$tmp_root/ohc-usage.out" 2>"$tmp_root/ohc-usage.err"
usage_rc=$?
set -e
usage_stderr="$(<"$tmp_root/ohc-usage.err")"
assert_eq "$usage_rc" "2"
assert_contains "$usage_stderr" "usage: ohc"
assert_contains "$usage_stderr" "ohc --help"

echo "• ohc help documents supported worktree options"
zsh "$DOTFILES_ROOT/home/dot_config/zsh/autoload/ohc" --help >"$tmp_root/ohc-help.out"
help_stdout="$(<"$tmp_root/ohc-help.out")"
assert_contains "$help_stdout" "--base-branch <ref>"
assert_contains "$help_stdout" "--agent <id>"
assert_contains "$help_stdout" "Do not pass --repo"

echo "• ohc rejects repo selector overrides"
: >"$GHC_TEST_LOG"
: >"$ORCA_TEST_LOG"
set +e
GHPATH="$tmp_root/code/github.com" \
  zsh "$DOTFILES_ROOT/home/dot_config/zsh/autoload/ohc" "prateek/ohc-test" --repo id:other >"$tmp_root/ohc-repo.out" 2>"$tmp_root/ohc-repo.err"
repo_override_rc=$?
set -e
repo_override_stderr="$(<"$tmp_root/ohc-repo.err")"
assert_eq "$repo_override_rc" "2"
assert_contains "$repo_override_stderr" "--repo"
assert_eq "$(<"$GHC_TEST_LOG")" ""

echo "• ohc clones through ghc and creates an Orca worktree"
: >"$GHC_TEST_LOG"
: >"$ORCA_TEST_LOG"
GHPATH="$tmp_root/code/github.com" \
  zsh "$DOTFILES_ROOT/home/dot_config/zsh/autoload/ohc" "https://github.com/prateek/ohc-test" --agent codex --prompt "hi" >/dev/null

clone_url="$(awk -F '\t' 'NR==1 { print $2 }' "$GHC_TEST_LOG")"
target_path="$(awk -F '\t' 'NR==1 { print $3 }' "$GHC_TEST_LOG")"
expected_orca_path="${tmp_root:A}/code/github.com/prateek/ohc-test"
assert_eq "$clone_url" "git@github.com:prateek/ohc-test.git"
assert_eq "$target_path" "$tmp_root/code/github.com/prateek/ohc-test"

repo_add_path="$(awk -F '\t' '$1=="repo-add" { for (i = 2; i <= NF; i++) if ($i == "--path") { print $(i + 1); exit } }' "$ORCA_TEST_LOG")"
worktree_repo="$(awk -F '\t' '$1=="worktree-create" { for (i = 2; i <= NF; i++) if ($i == "--repo") { print $(i + 1); exit } }' "$ORCA_TEST_LOG")"
worktree_name="$(awk -F '\t' '$1=="worktree-create" { for (i = 2; i <= NF; i++) if ($i == "--name") { print $(i + 1); exit } }' "$ORCA_TEST_LOG")"
worktree_agent="$(awk -F '\t' '$1=="worktree-create" { for (i = 2; i <= NF; i++) if ($i == "--agent") { print $(i + 1); exit } }' "$ORCA_TEST_LOG")"

assert_eq "$repo_add_path" "$expected_orca_path"
assert_eq "$worktree_repo" "path:$expected_orca_path"
assert_eq "$worktree_name" "ohc-test"
assert_eq "$worktree_agent" "codex"
