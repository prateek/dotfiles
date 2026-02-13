#!/usr/bin/env zsh
# E2E integration tests for repo_select + w + Worktrunk hooks.

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "e2e-worktrees: $*"
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f "$path" ]] || die "expected file: $path"
}

assert_dir() {
  local path="$1"
  [[ -d "$path" ]] || die "expected dir: $path"
}

assert_eq() {
  local got="$1"
  local want="$2"
  [[ "$got" == "$want" ]] || die "assert_eq failed: got='$got' want='$want'"
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "missing required command: $cmd"
}

DOTFILES_ROOT="${0:A:h:h}"

require_cmd git
require_cmd wt
require_cmd fzf
require_cmd zoxide
require_cmd python3

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

export HOME="$tmp_root/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"
export _ZO_DATA_DIR="$XDG_DATA_HOME/zoxide"

mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"

# Ensure hooks + helpers are found.
export PATH="$DOTFILES_ROOT/bin:$PATH"

# Stub repo-index for deterministic repo_select / --repo resolution.
stub_bin="$tmp_root/bin"
mkdir -p "$stub_bin"
export PATH="$stub_bin:$PATH"
unfunction repo-index 2>/dev/null || true
unalias repo-index 2>/dev/null || true
hash -r 2>/dev/null || true

repos_dir="$tmp_root/repos"
mkdir -p "$repos_dir"

export REPO_INDEX_REPOS_DIR="$repos_dir"

cat >"$stub_bin/repo-index" <<'EOF'
#!/bin/sh
set -eu
 : "${REPO_INDEX_REPOS_DIR:?REPO_INDEX_REPOS_DIR not set}"
format="tsv"
if [ "${1:-}" = "--format" ]; then
  format="${2:-tsv}"
fi
case "$format" in
  tsv)
    printf '%s\t%s\t%s\n' "test-owner/test-repo" "https://github.com/test-owner/test-repo" "$REPO_INDEX_REPOS_DIR/test-repo"
    printf '%s\t%s\t%s\n' "openai/openai" "https://github.com/openai/openai" "$REPO_INDEX_REPOS_DIR/openai"
    ;;
  *)
    echo "repo-index stub: unsupported format: $format" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$stub_bin/repo-index"

# Worktrunk user config (symlink to dotfiles-managed config).
mkdir -p "$XDG_CONFIG_HOME/worktrunk"
ln -snf "$DOTFILES_ROOT/.config/worktrunk/config.toml" "$XDG_CONFIG_HOME/worktrunk/config.toml"

# Load zsh autoloaded functions.
fpath=("$DOTFILES_ROOT/zsh/autoload" $fpath)
autoload -Uz repo_select w

create_repo() {
  local dir="$1"
  local origin="$2"
  mkdir -p "$dir"
  git init -q "$dir"
  (
    cd "$dir"
    git config user.email test@example.com
    git config user.name test
    echo "hello" > README.md
    mkdir -p src docs
    echo "src" > src/file.txt
    echo "docs" > docs/file.txt
    git add -A
    git commit -qm init
    git remote add origin "$origin"
  )
}

echo "• repo_select non-interactive"
create_repo "$repos_dir/test-repo" "https://github.com/test-owner/test-repo.git"
create_repo "$repos_dir/openai" "https://github.com/openai/openai.git"
sel="$(repo_select --format slug --filter "$repos_dir/test-repo")"
assert_eq "$sel" "test-owner/test-repo"

echo "• w new creates centralized worktree"
(
  cd "$repos_dir/test-repo"
  w new --here "feature/foo" --base @
)
wt1="$HOME/code/wt/test-owner-test-repo.feature-foo/test-repo"
assert_dir "$wt1"
head_branch="$(git -C "$wt1" rev-parse --abbrev-ref HEAD)"
assert_eq "$head_branch" "feature/foo"

echo "• w new is idempotent on existing branch"
(
  cd "$repos_dir/test-repo"
  out="$(w new --here "feature/foo" --base @)"
  rc=$?
  assert_eq "$rc" "0"
  if print -r -- "$out" | grep -Fq "already exists"; then
    die "unexpected branch-exists error from w new"
  fi
)

echo "• w cd switches and cds into worktree"
pwd_after="$(
  cd "$repos_dir/test-repo"
  w cd --here "feature/foo" >/dev/null 2>&1
  pwd -P
)"
assert_eq "$pwd_after" "${wt1:A}"

echo "• w switch fuzzy-picks an existing worktree"
pwd_after="$(
  cd "$repos_dir/test-repo"
  wt1_display="${wt1/#$HOME/~}"
  w switch --root "$HOME/code/wt" --filter "$wt1_display" >/dev/null 2>&1
  pwd -P
)"
assert_eq "$pwd_after" "${wt1:A}"

echo "• w run executes agent command in worktree"
(
  cd "$repos_dir/test-repo"
  w run --here "agent/run" --base @ --agent 'sh -c "echo ok > .agent_ran"'
)
wt2="$HOME/code/wt/test-owner-test-repo.agent-run/test-repo"
assert_file "$wt2/.agent_ran"
assert_eq "$(cat "$wt2/.agent_ran")" "ok"

echo "• w run works on existing branch"
(
  cd "$repos_dir/test-repo"
  w new --here "agent/existing" --base @ --no-cd
  w run --here "agent/existing" --agent 'sh -c "echo ok > .agent_ran2"'
)
wt2b="$HOME/code/wt/test-owner-test-repo.agent-existing/test-repo"
assert_file "$wt2b/.agent_ran2"
assert_eq "$(cat "$wt2b/.agent_ran2")" "ok"

echo "• sparse hook applies when requested"
create_repo "$repos_dir/sparse-repo" "https://github.com/test-owner/sparse-repo.git"
(
  cd "$repos_dir/sparse-repo"
  w new --here "sparse/test" --base @ --sparse src --sparse docs
)
wt3="$HOME/code/wt/test-owner-sparse-repo.sparse-test/sparse-repo"
assert_dir "$wt3"
sparse_list="$(git -C "$wt3" sparse-checkout list | tr -d '\r')"
print -r -- "$sparse_list" | grep -Eq '^src/?$' || die "expected sparse-checkout list to include src; got: $sparse_list"
print -r -- "$sparse_list" | grep -Eq '^docs/?$' || die "expected sparse-checkout list to include docs; got: $sparse_list"

echo "• OpenAI venv hook (stubbed monorepo_setup.sh)"
cat >"$repos_dir/openai/monorepo_setup.sh" <<'EOF'
#!/usr/bin/env sh
venv_setup_build() {
  mkdir -p "$MONOREPO_VENV/bin"
  cat > "$MONOREPO_VENV/bin/python" <<'PY'
#!/usr/bin/env sh
exit 0
PY
  chmod +x "$MONOREPO_VENV/bin/python"
}
EOF
chmod +x "$repos_dir/openai/monorepo_setup.sh"
(
  cd "$repos_dir/openai"
  git add monorepo_setup.sh
  git commit -qm "add stub monorepo_setup.sh"
  w new --here "venv/test" --base @
)
wt4="$HOME/code/wt/openai-openai.venv-test/openai"
assert_dir "$wt4"
assert_file "$HOME/.virtualenvs/openai-venv-test/bin/python"

echo "• w list shows centralized worktrees"
list_json="$(w ls --format json)"
printf '%s' "$list_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("\n".join(sorted({i.get("path","") for i in d})))' | grep -Fqx "$wt1" || die "w list missing: $wt1"
printf '%s' "$list_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("\n".join(sorted({i.get("path","") for i in d})))' | grep -Fqx "$wt2" || die "w list missing: $wt2"
printf '%s' "$list_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("\n".join(sorted({i.get("path","") for i in d})))' | grep -Fqx "$wt3" || die "w list missing: $wt3"
printf '%s' "$list_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("\n".join(sorted({i.get("path","") for i in d})))' | grep -Fqx "$wt4" || die "w list missing: $wt4"

echo "• w rm removes a clean worktree with --yes"
w rm --yes --filter "feature/foo" >/dev/null
[[ ! -d "$wt1" ]] || die "expected clean worktree removed: $wt1"
git -C "$repos_dir/test-repo" show-ref --verify --quiet refs/heads/feature/foo && die "expected branch removed: feature/foo"

echo "• w rm --filter requires a single match"
(
  cd "$repos_dir/test-repo"
  w new --here "ambig/one" --base @ --no-cd >/dev/null
  w new --here "ambig/two" --base @ --no-cd >/dev/null
)
wt_ambig_one="$HOME/code/wt/test-owner-test-repo.ambig-one/test-repo"
wt_ambig_two="$HOME/code/wt/test-owner-test-repo.ambig-two/test-repo"
assert_dir "$wt_ambig_one"
assert_dir "$wt_ambig_two"
if w rm --yes --filter "ambig" >/dev/null 2>&1; then
  die "expected w rm --filter ambig to fail due to multiple matches"
fi
assert_dir "$wt_ambig_one"
assert_dir "$wt_ambig_two"

echo "• w rm does not remove dirty worktree without confirmation"
(
  cd "$repos_dir/test-repo"
  w new --here "dirty/rm" --base @ --no-cd >/dev/null
)
wt_dirty="$HOME/code/wt/test-owner-test-repo.dirty-rm/test-repo"
assert_dir "$wt_dirty"
echo "dirty" > "$wt_dirty/.dirty.txt"
if w rm --filter "dirty/rm" >/dev/null 2>&1; then
  die "expected w rm to fail for dirty worktree without --yes"
fi
assert_dir "$wt_dirty"

echo "• w rm removes dirty worktree with --yes"
w rm --yes --filter "dirty/rm" >/dev/null
[[ ! -d "$wt_dirty" ]] || die "expected dirty worktree removed: $wt_dirty"

echo "• broken worktrees show as stale"
broken_parent="$HOME/code/wt/broken-owner-broken-repo.broken-branch"
broken_leaf="$broken_parent/broken-repo"
mkdir -p "$broken_leaf"
cat >"$broken_leaf/.git" <<'EOF'
gitdir: /does/not/exist
EOF

w help >/dev/null 2>&1
got_gitdir="$(_w_gitdir_for_worktree "$broken_leaf")"
assert_eq "$got_gitdir" ""

ls_out="$(w ls --all --root "$HOME/code/wt" --format table -l)"
broken_display="$broken_leaf"
ls_line="$(print -r -- "$ls_out" | grep -F "$broken_display" | head -n 1 || true)"
[[ -n "$ls_line" ]] || die "expected w ls to include: $broken_leaf"
print -r -- "$ls_line" | grep -Fq "✗ stale" || die "expected w ls to mark stale: $broken_leaf"

echo "• w switch can filter stale rows"
pwd_after="$(
  cd "$repos_dir/test-repo"
  w switch --all --root "$HOME/code/wt" --filter "stale" >/dev/null 2>&1
  pwd -P
)"
assert_eq "$pwd_after" "${broken_leaf:A}"

echo "• w rm does not remove stale entries; use prune"
if w rm --all --root "$HOME/code/wt" --filter "stale" >/dev/null 2>&1; then
  die "expected w rm to fail for stale selection"
fi
assert_dir "$broken_leaf"

echo "• w prune removes stale worktree dirs (safe)"
prune_out="$(w prune)"
print -r -- "$prune_out" | grep -Fq "$broken_leaf" || die "expected w prune dry-run output to mention: $broken_leaf"
w prune --yes >/dev/null
[[ ! -d "$broken_leaf" ]] || die "expected stale worktree removed: $broken_leaf"
assert_dir "$wt2"

echo "OK"
