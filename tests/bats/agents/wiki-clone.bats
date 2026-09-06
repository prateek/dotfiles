load '../../support/common'

setup() {
  setup_fixture
  script="$DOTFILES_ROOT/scripts/agent-sessions/reconcile-wiki-clone"
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
  origin="file://$FIXTURE/origin.git"
  seed="$FIXTURE/seed"
  clone="$FIXTURE/clone"
  git init -q --bare -b main "$FIXTURE/origin.git"
  git -C "$FIXTURE/origin.git" config uploadpack.allowFilter true
  git init -q -b main "$seed"
  git -C "$seed" config maintenance.auto false
  git -C "$seed" remote add origin "$origin"
  mkdir -p "$seed/.agents/skills/session-sync/scripts" "$seed/.claude" "$seed/.codex" \
    "$seed/health" "$seed/wiki" "$seed/sessions/alpha/claude/projects" "$seed/sessions/beta/claude/projects"
  cat > "$seed/.agents/skills/session-sync/scripts/with-repo-lock" <<'STUB'
#!/bin/bash
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
lockdir="$(git -C "$repo" rev-parse --absolute-git-dir)/wiki-sessions.lock"
mkdir "$lockdir" 2>/dev/null || { echo 'with-repo-lock: held' >&2; exit 75; }
trap 'rmdir "$lockdir"' EXIT
WIKI_REPO_LOCK_HELD=1 "$@"
STUB
  chmod +x "$seed/.agents/skills/session-sync/scripts/with-repo-lock"
  printf '{}\n' > "$seed/.claude/settings.json"
  : > "$seed/.codex/config.toml"
  printf '{"host":"alpha"}\n' > "$seed/health/alpha.json"
  printf '{"host":"beta"}\n' > "$seed/health/beta.json"
  printf 'wiki page\n' > "$seed/wiki/page.md"
  printf 'readme\n' > "$seed/README.md"
  printf 'alpha transcript\n' > "$seed/sessions/alpha/claude/projects/s1.jsonl"
  printf 'beta transcript\n' > "$seed/sessions/beta/claude/projects/s1.jsonl"
  git -C "$seed" add -A
  git -C "$seed" commit -qm seed
  git -C "$seed" push -q origin main
}

reconcile() {
  local expected="$1"
  shift
  run_bash "$expected" "$script" --clone "$clone" --remote "$origin" "$@"
  [ "$status" -eq "$expected" ]
}

create_sparse() {
  reconcile 0 --sparse --alias alpha
  assert_success
}

cone() {
  git -C "$clone" sparse-checkout list
}

missing_blobs() {
  git -C "$clone" rev-list --objects --all --missing=print | awk '/^\?/{n++} END {print n+0}'
}

@test "Wiki sparse clone fetches its own sessions and shared files while leaving other hosts and wiki blobs unfetched" {
  create_sparse
  [ "$(cone)" = $'.agents\n.claude\n.codex\nhealth\nsessions/alpha' ]
  [ "$(git -C "$clone" config --get remote.origin.promisor)" = true ]
  [ "$(git -C "$clone" config --get remote.origin.partialclonefilter)" = blob:none ]
  [ -f "$clone/sessions/alpha/claude/projects/s1.jsonl" ]
  [ -f "$clone/health/beta.json" ] && [ -f "$clone/.claude/settings.json" ]
  [ ! -e "$clone/sessions/beta" ] && [ ! -e "$clone/wiki" ]
  [ "$(missing_blobs)" -gt 0 ]
  [ -z "$(git -C "$clone" status --porcelain)" ]
  reconcile 0 --sparse --alias alpha --check
  assert_success
  assert_output ''
  [ -z "$stderr" ]
}

@test "Wiki clone no-op avoids the repository lock while a held lock prevents mutation" {
  create_sparse
  mkdir "$clone/.git/wiki-sessions.lock"
  reconcile 0 --sparse --alias alpha
  assert_success
  refute_output --partial narrowing
  refute_output --partial updating
  [[ "$stderr" != *WARNING* ]]
  reconcile 75 --sparse --alias gamma
  assert_failure 75
  [[ "$stderr" == *'with-repo-lock: held'* ]]
  [ "$(cone)" = $'.agents\n.claude\n.codex\nhealth\nsessions/alpha' ]
}

@test "Wiki clone alias changes update the cone, release the lock, and allow new session files to stage" {
  create_sparse
  reconcile 0 --sparse --alias gamma
  assert_success
  [ "$(cone)" = $'.agents\n.claude\n.codex\nhealth\nsessions/gamma' ]
  [ ! -e "$clone/sessions/alpha" ]
  [ ! -e "$clone/.git/wiki-sessions.lock" ]
  mkdir -p "$clone/sessions/gamma/claude"
  printf 'gamma session\n' > "$clone/sessions/gamma/claude/s.jsonl"
  git -C "$clone" add -A -- sessions/gamma health
  [ "$(git -C "$clone" diff --cached --name-only)" = sessions/gamma/claude/s.jsonl ]
}

@test "Wiki clone check reports cone and filter drift without mutation and reconciliation repairs both" {
  create_sparse
  git -C "$clone" sparse-checkout add sessions/beta
  reconcile 1 --sparse --alias alpha --check
  assert_failure 1
  assert_output --partial 'cone is'
  [ "$(cone)" = $'.agents\n.claude\n.codex\nhealth\nsessions/alpha\nsessions/beta' ]
  reconcile 0 --sparse --alias alpha
  assert_success
  [ "$(cone)" = $'.agents\n.claude\n.codex\nhealth\nsessions/alpha' ]
  git -C "$clone" config remote.origin.partialclonefilter blob:limit=10m
  reconcile 1 --sparse --alias alpha --check
  assert_failure 1
  assert_output --partial 'not a blobless partial clone'
  [ "$(git -C "$clone" config --get remote.origin.partialclonefilter)" = blob:limit=10m ]
  reconcile 0 --sparse --alias alpha
  assert_success
  [ "$(git -C "$clone" config --get remote.origin.partialclonefilter)" = blob:none ]
}

@test "Wiki clone compares remote identity across transports and refuses another host, repository, or non-clone" {
  create_sparse
  git -C "$clone" remote set-url origin https://example.com/owner/repo.git
  local remote
  for remote in ssh://git@example.com/owner/repo git@example.com:owner/repo.git; do
    run_bash 0 "$script" --clone "$clone" --remote "$remote" --sparse --alias alpha --check
    assert_success
  done
  for remote in git@evil.example:owner/repo.git git@example.com:owner/other.git; do
    run_bash 3 "$script" --clone "$clone" --remote "$remote" --sparse --alias alpha --check
    assert_failure 3
    [[ "$stderr" == *'unexpected remote'* ]]
  done
  local non_clone="$FIXTURE/not-a-clone"
  mkdir "$non_clone"
  run_bash 3 "$script" --clone "$non_clone" --remote "$origin" --sparse --alias alpha
  assert_failure 3
  [[ "$stderr" == *'exists but is not a git clone'* ]]
}

@test "Wiki clone narrowing preserves outside changes on refusal and keeps inside changes on successful conversion" {
  git clone -q "$origin" "$clone"
  reconcile 1 --sparse --alias beta --check
  assert_failure 1
  assert_output --partial 'clone is full'
  printf 'edit\n' >> "$clone/sessions/alpha/claude/projects/s1.jsonl"
  printf 'note\n' > "$clone/sessions/alpha/claude/projects/untracked.txt"
  reconcile 5 --sparse --alias beta
  assert_failure 5
  [[ "$stderr" == *'outside the cone'* ]]
  [ "$(cat "$clone/sessions/alpha/claude/projects/s1.jsonl")" = $'alpha transcript\nedit' ]
  [ "$(cat "$clone/sessions/alpha/claude/projects/untracked.txt")" = note ]
  run -1 git -C "$clone" config --get core.sparseCheckout
  assert_failure 1
  git -C "$clone" checkout -q -- sessions/alpha
  rm "$clone/sessions/alpha/claude/projects/untracked.txt"
  printf 'wip\n' > "$clone/sessions/beta/claude/projects/wip.jsonl"
  reconcile 0 --sparse --alias beta
  assert_success
  assert_output --partial narrowing
  [[ "$stderr" == *'already in .git remain'* ]]
  [ ! -e "$clone/sessions/alpha" ]
  [ -f "$clone/sessions/beta/claude/projects/s1.jsonl" ]
  [ "$(cat "$clone/sessions/beta/claude/projects/wip.jsonl")" = wip ]
  [ "$(git -C "$clone" config --get remote.origin.promisor)" = true ]
  rm "$clone/sessions/beta/claude/projects/wip.jsonl"
  reconcile 0 --sparse --alias beta --check
  assert_success

  printf 'later alpha transcript\n' > "$seed/sessions/alpha/claude/projects/s2.jsonl"
  git -C "$seed" add -A
  git -C "$seed" commit -qm 'sync(alpha)'
  git -C "$seed" push -q origin main
  git -C "$clone" pull -q --rebase
  [ "$(missing_blobs)" -eq 1 ]
  reconcile 0 --sparse --alias beta
  assert_success
  [[ "$stderr" != *WARNING* ]]
  mkdir "$clone/.git/rebase-merge"
  reconcile 5 --sparse --alias alpha
  assert_failure 5
  [ "$(cone)" = $'.agents\n.claude\n.codex\nhealth\nsessions/beta' ]
}

@test "Wiki clone widening fetches all missing blobs and converges to a full checkout" {
  create_sparse
  reconcile 1 --full --check
  assert_failure 1
  reconcile 0 --full
  assert_success
  assert_output --partial widening
  [ -f "$clone/sessions/alpha/claude/projects/s1.jsonl" ]
  [ -f "$clone/sessions/beta/claude/projects/s1.jsonl" ]
  [ "$(missing_blobs)" -eq 0 ]
  [ "$(git -C "$clone" config --type=bool --get core.sparseCheckout)" = false ]
  reconcile 0 --full
  assert_success
  refute_output --partial widening
  reconcile 0 --full --check
  assert_success
}

@test "Wiki fresh full clone includes other hosts without promisor configuration" {
  reconcile 0 --full
  assert_success
  [ -f "$clone/sessions/beta/claude/projects/s1.jsonl" ]
  run -1 git -C "$clone" config --get remote.origin.promisor
  assert_failure 1
  assert_output ''
}

@test "Wiki clone refuses a server without blob filtering and leaves new or existing destinations intact" {
  git -C "$FIXTURE/origin.git" config uploadpack.allowFilter false
  reconcile 5 --sparse --alias alpha
  assert_failure 5
  [[ "$stderr" == *'does not support partial-clone filters'* ]]
  [ ! -e "$clone" ]
  git clone -q "$origin" "$clone"
  reconcile 5 --sparse --alias alpha
  assert_failure 5
  [[ "$stderr" == *'does not support partial-clone filters'* ]]
  run -1 git -C "$clone" config --get core.sparseCheckout
  assert_failure 1
  [ -f "$clone/sessions/beta/claude/projects/s1.jsonl" ]
}

@test "Wiki clone reports unreachable and missing repositories without creating a destination" {
  run_bash 4 "$script" --clone "$clone" --remote "file://$FIXTURE/nope.git" --sparse --alias alpha
  assert_failure 4
  [[ "$stderr" == *'cannot reach'* ]]
  [ ! -e "$clone" ]
  reconcile 1 --sparse --alias alpha --check
  assert_failure 1
  assert_output --partial missing
  [ ! -e "$clone" ]
}

@test "Wiki clone rejects missing or unsafe aliases and missing option values before creating anything" {
  reconcile 2 --sparse
  assert_failure 2
  [[ "$stderr" == *'--sparse needs --alias'* ]]
  local alias
  for alias in ../wiki 'two words'; do
    reconcile 2 --sparse --alias "$alias"
    assert_failure 2
    [[ "$stderr" == *'invalid alias'* ]]
  done
  reconcile 2 --sparse --alias
  assert_failure 2
  [[ "$stderr" == *usage:* ]]
  run_bash 2 "$script" --clone "$clone" --remote
  assert_failure 2
  [[ "$stderr" == *usage:* ]]
  [ ! -e "$clone" ]
}
