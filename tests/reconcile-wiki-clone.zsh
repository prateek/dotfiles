#!/usr/bin/env zsh
#
# Tests for scripts/agent-sessions/reconcile-wiki-clone against a local bare
# origin: fresh sparse and full clones, idempotence, alias changes, narrowing
# and widening an existing clone, --check drift reporting, the repo lock, and
# the refusal exit codes (remote identity, ignored blob filter, dirty paths
# outside the cone, bad aliases, usage).
#
set -euo pipefail

die() {
  print -u2 -- "reconcile-wiki-clone: $*"
  exit 1
}

REPO_ROOT="${REPO_ROOT:-${0:A:h:h}}"
SCRIPT="$REPO_ROOT/scripts/agent-sessions/reconcile-wiki-clone"
[[ -x "$SCRIPT" ]] || die "missing helper: $SCRIPT"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Isolate git from the machine's config (signing, hooks, default branch).
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$tmp/gitconfig" HOME="$tmp/home"
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
mkdir -p "$HOME"
: >"$GIT_CONFIG_GLOBAL"

# run <expected-rc> <args...>: captures combined output in $out, dies on rc mismatch.
run() {
  local want="$1"; shift
  set +e
  out="$("$SCRIPT" "$@" 2>&1)"
  local rc=$?
  set -e
  [[ $rc -eq $want ]] || die "expected exit $want, got $rc for: $*\n$out"
}

origin="file://$tmp/origin.git"
git init -q --bare -b main "$tmp/origin.git"
# file:// transports only honor --filter when the server side allows it.
git -C "$tmp/origin.git" config uploadpack.allowFilter true

seed="$tmp/seed"
git clone -q "$origin" "$seed" 2>/dev/null
mkdir -p "$seed"/{.agents/skills/session-sync/scripts,.claude,.codex,health,wiki,sessions/alpha/claude/projects,sessions/beta/claude/projects}
# A stand-in for the repo's with-repo-lock: same lock dir, same held-lock
# exit code, same WIKI_REPO_LOCK_HELD marker for the child.
cat >"$seed/.agents/skills/session-sync/scripts/with-repo-lock" <<'LOCK'
#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
lockdir="$(git -C "$repo" rev-parse --absolute-git-dir)/wiki-sessions.lock"
mkdir "$lockdir" 2>/dev/null || { echo "with-repo-lock: held" >&2; exit 75; }
trap 'rm -rf "$lockdir"' EXIT
WIKI_REPO_LOCK_HELD=1 "$@"
LOCK
chmod +x "$seed/.agents/skills/session-sync/scripts/with-repo-lock"
print -- '{}' >"$seed/.claude/settings.json"
print -- '' >"$seed/.codex/config.toml"
print -- '{"host":"alpha"}' >"$seed/health/alpha.json"
print -- '{"host":"beta"}' >"$seed/health/beta.json"
print -- 'page' >"$seed/wiki/page.md"
print -- 'readme' >"$seed/README.md"
head -c 50000 /dev/urandom | base64 >"$seed/sessions/alpha/claude/projects/s1.jsonl"
head -c 50000 /dev/urandom | base64 >"$seed/sessions/beta/claude/projects/s1.jsonl"
git -C "$seed" add -A
git -C "$seed" commit -qm seed
git -C "$seed" push -q origin main

missing_blobs() { git -C "$1" rev-list --objects --all --missing=print | grep -c '^?' || true; }
cone_of() { git -C "$1" sparse-checkout list | tr '\n' ' ' | sed 's/ $//'; }

# --- fresh sparse clone -------------------------------------------------------
c1="$tmp/c1"
run 0 --clone "$c1" --remote "$origin" --sparse --alias alpha
[[ "$(cone_of "$c1")" == ".agents .claude .codex health sessions/alpha" ]] || die "cone: $(cone_of "$c1")"
[[ "$(git -C "$c1" config --get remote.origin.promisor)" == "true" ]] || die "fresh clone is not a promisor clone"
[[ "$(git -C "$c1" config --get remote.origin.partialclonefilter)" == "blob:none" ]] || die "missing blob:none filter"
[[ -f "$c1/sessions/alpha/claude/projects/s1.jsonl" ]] || die "own sessions not checked out"
[[ -f "$c1/health/beta.json" && -f "$c1/.claude/settings.json" ]] || die "shared dirs not checked out"
[[ ! -e "$c1/sessions/beta" && ! -e "$c1/wiki" ]] || die "other hosts' sessions or the wiki checked out"
[[ "$(missing_blobs "$c1")" -gt 0 ]] || die "other host's blobs were fetched"
[[ -z "$(git -C "$c1" status --porcelain)" ]] || die "fresh sparse clone is dirty"
run 0 --clone "$c1" --remote "$origin" --sparse --alias alpha --check
[[ -z "$out" ]] || die "--check on a clone in shape should be silent: $out"

# --- idempotent: nothing to do on a second run, and no lock taken -------------
mkdir "$c1/.git/wiki-sessions.lock"
run 0 --clone "$c1" --remote "$origin" --sparse --alias alpha
[[ "$out" != *narrowing* && "$out" != *updating* && "$out" != *WARNING* ]] || die "second run was not a no-op: $out"
rmdir "$c1/.git/wiki-sessions.lock"

# --- a held repo lock blocks mutations with exit 75 ---------------------------
mkdir "$c1/.git/wiki-sessions.lock"
run 75 --clone "$c1" --remote "$origin" --sparse --alias gamma
rmdir "$c1/.git/wiki-sessions.lock"
[[ "$(cone_of "$c1")" == ".agents .claude .codex health sessions/alpha" ]] || die "cone changed under a held lock"

# --- alias change updates the cone; new files under it stage normally ---------
run 0 --clone "$c1" --remote "$origin" --sparse --alias gamma
[[ "$(cone_of "$c1")" == ".agents .claude .codex health sessions/gamma" ]] || die "cone after alias change: $(cone_of "$c1")"
[[ ! -e "$c1/sessions/alpha" ]] || die "old alias still checked out"
[[ ! -e "$c1/.git/wiki-sessions.lock" ]] || die "lock left behind"
mkdir -p "$c1/sessions/gamma/claude"
print -- 'x' >"$c1/sessions/gamma/claude/s.jsonl"
git -C "$c1" add -A -- sessions/gamma health || die "git add refused paths inside the new cone"
[[ "$(git -C "$c1" diff --cached --name-only)" == "sessions/gamma/claude/s.jsonl" ]] || die "new-alias file not staged"
git -C "$c1" reset -q
rm -rf "$c1/sessions/gamma"

# --- --check reports drift without touching anything --------------------------
git -C "$c1" sparse-checkout add sessions/beta
run 1 --clone "$c1" --remote "$origin" --sparse --alias gamma --check
[[ "$out" == *"cone is"* ]] || die "--check did not report the widened cone: $out"
[[ "$(cone_of "$c1")" == ".agents .claude .codex health sessions/beta sessions/gamma" ]] || die "--check mutated the cone"
run 0 --clone "$c1" --remote "$origin" --sparse --alias gamma
[[ "$(cone_of "$c1")" == ".agents .claude .codex health sessions/gamma" ]] || die "cone not restored: $(cone_of "$c1")"
git -C "$c1" config remote.origin.partialclonefilter blob:limit=10m
run 1 --clone "$c1" --remote "$origin" --sparse --alias gamma --check
[[ "$out" == *"not a blobless partial clone"* ]] || die "--check accepted a non-blob:none filter: $out"
run 0 --clone "$c1" --remote "$origin" --sparse --alias gamma
[[ "$(git -C "$c1" config --get remote.origin.partialclonefilter)" == "blob:none" ]] || die "filter not repinned to blob:none"

# --- remote identity: same repo over another transport passes, other hosts and repos do not
git -C "$c1" remote set-url origin "https://example.com/owner/repo.git"
run 0 --clone "$c1" --remote "ssh://git@example.com/owner/repo" --sparse --alias gamma --check
run 0 --clone "$c1" --remote "git@example.com:owner/repo.git" --sparse --alias gamma --check
run 3 --clone "$c1" --remote "git@evil.example:owner/repo.git" --sparse --alias gamma --check
run 3 --clone "$c1" --remote "git@example.com:owner/other.git" --sparse --alias gamma --check
git -C "$c1" remote set-url origin "$origin"
mkdir -p "$tmp/notaclone"
run 3 --clone "$tmp/notaclone" --remote "$origin" --sparse --alias alpha

# --- narrow an existing full clone in place ----------------------------------
c2="$tmp/c2"
git clone -q "$origin" "$c2"
[[ -e "$c2/sessions/alpha" ]] || die "fixture full clone lacks alpha"
run 1 --clone "$c2" --remote "$origin" --sparse --alias beta --check
[[ "$out" == *"clone is full"* ]] || die "--check did not flag the full clone: $out"
# Dirty or untracked paths outside the cone refuse the narrowing and stay put.
print -- 'edit' >>"$c2/sessions/alpha/claude/projects/s1.jsonl"
print -- 'note' >"$c2/sessions/alpha/claude/projects/untracked.txt"
run 5 --clone "$c2" --remote "$origin" --sparse --alias beta
[[ "$out" == *"outside the cone"* ]] || die "dirty refusal did not explain itself: $out"
[[ "$(git -C "$c2" config --type=bool --get core.sparseCheckout || true)" != "true" ]] || die "refused narrowing still made the clone sparse"
[[ -f "$c2/sessions/alpha/claude/projects/untracked.txt" ]] || die "refusal removed a local file"
git -C "$c2" checkout -q -- sessions/alpha
rm "$c2/sessions/alpha/claude/projects/untracked.txt"
# Dirty paths inside the cone are fine (a sync that died mid-mirror leaves these).
print -- 'wip' >"$c2/sessions/beta/claude/projects/wip.jsonl"
run 0 --clone "$c2" --remote "$origin" --sparse --alias beta
[[ "$out" == *narrowing* && "$out" == *"already in .git remain"* ]] || die "narrowing did not report itself: $out"
[[ ! -e "$c2/sessions/alpha" && -f "$c2/sessions/beta/claude/projects/s1.jsonl" && -f "$c2/sessions/beta/claude/projects/wip.jsonl" ]] || die "narrowed tree wrong"
[[ "$(git -C "$c2" config --get remote.origin.promisor)" == "true" ]] || die "narrowed clone not converted to a promisor clone"
rm "$c2/sessions/beta/claude/projects/wip.jsonl"
run 0 --clone "$c2" --remote "$origin" --sparse --alias beta --check
# Later upstream blobs outside the cone stay unfetched.
head -c 50000 /dev/urandom | base64 >"$seed/sessions/alpha/claude/projects/s2.jsonl"
git -C "$seed" add -A
git -C "$seed" commit -qm "sync(alpha)"
git -C "$seed" push -q origin main
git -C "$c2" pull -q --rebase
[[ "$(missing_blobs "$c2")" -eq 1 ]] || die "expected exactly one lazily skipped blob, got $(missing_blobs "$c2")"
run 0 --clone "$c2" --remote "$origin" --sparse --alias beta
[[ "$out" != *WARNING* ]] || die "converted clone still warns: $out"
# A git operation in progress refuses any mutation.
mkdir "$c2/.git/rebase-merge"
run 5 --clone "$c2" --remote "$origin" --sparse --alias alpha
rmdir "$c2/.git/rebase-merge"

# --- widen a sparse clone back to full ----------------------------------------
run 1 --clone "$c1" --remote "$origin" --full --check
run 0 --clone "$c1" --remote "$origin" --full
[[ "$out" == *widening* ]] || die "widening did not report itself: $out"
[[ -f "$c1/sessions/alpha/claude/projects/s1.jsonl" && -f "$c1/sessions/beta/claude/projects/s1.jsonl" ]] || die "widened tree incomplete"
[[ "$(missing_blobs "$c1")" -eq 0 ]] || die "widened clone still has missing blobs"
[[ "$(git -C "$c1" config --type=bool --get core.sparseCheckout)" == "false" ]] || die "widened clone still sparse"
run 0 --clone "$c1" --remote "$origin" --full
[[ "$out" != *widening* ]] || die "second full run was not a no-op: $out"
run 0 --clone "$c1" --remote "$origin" --full --check

# --- fresh full clone ---------------------------------------------------------
c3="$tmp/c3"
run 0 --clone "$c3" --remote "$origin" --full
[[ -f "$c3/sessions/beta/claude/projects/s1.jsonl" ]] || die "fresh full clone incomplete"
[[ -z "$(git -C "$c3" config --get remote.origin.promisor || true)" ]] || die "full clone should not be a promisor clone"

# --- a server that ignores the blob filter never yields a "sparse" full clone --
git -C "$tmp/origin.git" config uploadpack.allowFilter false
run 5 --clone "$tmp/c4" --remote "$origin" --sparse --alias alpha
[[ ! -e "$tmp/c4" ]] || die "ignored-filter clone was left behind"
c5="$tmp/c5"
git clone -q "$origin" "$c5"
run 5 --clone "$c5" --remote "$origin" --sparse --alias alpha
[[ "$(git -C "$c5" config --type=bool --get core.sparseCheckout || true)" != "true" ]] || die "refused conversion still narrowed the clone"
git -C "$tmp/origin.git" config uploadpack.allowFilter true

# --- unreachable remote: exit 4, nothing created -------------------------------
run 4 --clone "$tmp/c6" --remote "file://$tmp/nope.git" --sparse --alias alpha
[[ ! -e "$tmp/c6" ]] || die "unreachable remote left a directory behind"
run 1 --clone "$tmp/c6" --remote "$origin" --sparse --alias alpha --check
[[ "$out" == *missing* ]] || die "--check on a missing clone: $out"

# --- usage: bad aliases and missing option values -----------------------------
run 2 --clone "$tmp/c7" --remote "$origin" --sparse
run 2 --clone "$tmp/c7" --remote "$origin" --sparse --alias "../wiki"
run 2 --clone "$tmp/c7" --remote "$origin" --sparse --alias "two words"
run 2 --clone "$tmp/c7" --remote "$origin" --sparse --alias
run 2 --clone "$tmp/c7" --remote
[[ ! -e "$tmp/c7" ]] || die "usage errors created a directory"

print -- "OK reconcile-wiki-clone"
