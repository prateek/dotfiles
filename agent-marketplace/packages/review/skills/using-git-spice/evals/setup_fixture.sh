#!/usr/bin/env bash
# Materialize a local git-spice eval in a fresh absolute destination.
# Usage: setup_fixture.sh <fixture_name> <dest_dir>

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <fixture_name> <dest_dir>" >&2
  exit 2
fi

FIXTURE="$1"
DEST="$2"
ORIGIN="${DEST}.origin.git"
HOLDER="${DEST}.holder"
OTHER="${DEST}.other"

case "$FIXTURE" in
  basic | ambiguous-init | untracked-worktree | conflict | worktree-trunk | commit-only | lower-layer | ambiguous-delete | test-restack) ;;
  *)
    echo "unknown fixture: $FIXTURE" >&2
    exit 1
    ;;
esac

if [[ "$DEST" != /* ]]; then
  echo "destination must be absolute: $DEST" >&2
  exit 1
fi

for path in "$DEST" "$ORIGIN" "$HOLDER" "$OTHER"; do
  if [[ -e "$path" || -L "$path" ]]; then
    echo "refusing to overwrite fixture path: $path" >&2
    exit 1
  fi
done

command -v git-spice >/dev/null
mkdir -p -- "$(dirname -- "$DEST")"

configure_repo() {
  local repo="$1"
  git -C "$repo" config user.name "Git Spice Eval"
  git -C "$repo" config user.email "git-spice-eval@example.com"
  git -C "$repo" config rerere.enabled true
  git -C "$repo" config spice.branchCreate.prefix prateek/
  git -C "$repo" config spice.submit.draft true
  git -C "$repo" config spice.repoSync.restack upstack
  git -C "$repo" config spice.rebaseContinue.edit false
  git -C "$repo" config spice.experiment.commitFixup true
  git -C "$repo" config spice.experiment.commitPick true
}

spice() {
  local repo="$1"
  shift
  (cd "$repo" && git-spice "$@")
}

init_repo() {
  local repo="$1"
  git init --bare -q "$ORIGIN"
  git clone -q "$ORIGIN" "$repo"
  configure_repo "$repo"
  printf 'base\n' > "$repo/base.txt"
  git -C "$repo" add base.txt
  git -C "$repo" commit -qm "base"
  git -C "$repo" push -qu origin master
  spice "$repo" repo init --trunk=master --remote=origin --no-prompt >/dev/null
}

create_branch() {
  local repo="$1"
  local name="$2"
  local file="$3"
  local content="$4"
  local message="$5"
  printf '%s\n' "$content" > "$repo/$file"
  git -C "$repo" add "$file"
  spice "$repo" branch create "$name" -m "$message" --no-prompt >/dev/null
}

case "$FIXTURE" in
  basic)
    init_repo "$DEST"
    create_branch "$DEST" "inspect" "inspect.txt" "inspect" "inspect stack"
    ;;

  ambiguous-init)
    git init --bare -q "$ORIGIN"
    git clone -q "$ORIGIN" "$DEST"
    configure_repo "$DEST"
    printf 'base\n' > "$DEST/base.txt"
    git -C "$DEST" add base.txt
    git -C "$DEST" commit -qm "base"
    git -C "$DEST" branch main
    git -C "$DEST" push -qu origin master main
    git --git-dir="$ORIGIN" symbolic-ref HEAD refs/heads/unknown
    git -C "$DEST" checkout -qb prateek/work
    ;;

  untracked-worktree)
    init_repo "$HOLDER"
    git -C "$HOLDER" worktree add -qb prateek/untracked "$DEST" master
    ;;

  conflict)
    init_repo "$DEST"
    printf 'parent-v1\n' > "$DEST/shared.txt"
    git -C "$DEST" add shared.txt
    spice "$DEST" branch create parent -m "parent change" --no-prompt >/dev/null
    printf 'child-v1\n' > "$DEST/shared.txt"
    git -C "$DEST" add shared.txt
    spice "$DEST" branch create child -m "child change" --no-prompt >/dev/null
    spice "$DEST" branch checkout prateek/parent --no-prompt >/dev/null
    printf 'parent-v2\n' > "$DEST/shared.txt"
    git -C "$DEST" add shared.txt
    git -C "$DEST" commit --amend --no-edit -q
    if spice "$DEST" upstack restack --no-prompt >/dev/null 2>&1; then
      echo "fixture error: expected a restack conflict" >&2
      exit 1
    fi
    ;;

  worktree-trunk)
    init_repo "$HOLDER"
    git -C "$HOLDER" worktree add -qb prateek/current "$DEST" master
    spice "$DEST" branch track --base=master --no-prompt >/dev/null
    git clone -q "$ORIGIN" "$OTHER"
    configure_repo "$OTHER"
    printf 'remote advance\n' > "$OTHER/remote.txt"
    git -C "$OTHER" add remote.txt
    git -C "$OTHER" commit -qm "advance trunk"
    git -C "$OTHER" push -q origin master
    ;;

  commit-only)
    init_repo "$DEST"
    spice "$DEST" branch create commit-only --no-commit --no-prompt >/dev/null
    printf 'commit me\n' > "$DEST/change.txt"
    ;;

  lower-layer)
    init_repo "$HOLDER"
    create_branch "$HOLDER" "models" "models.txt" "model v1" "add models"
    create_branch "$HOLDER" "api" "api.txt" "api v1" "add api"
    spice "$HOLDER" branch checkout prateek/models --no-prompt >/dev/null
    git -C "$HOLDER" worktree add -q "$DEST" prateek/api
    ;;

  ambiguous-delete)
    init_repo "$DEST"
    create_branch "$DEST" "base-layer" "layer1.txt" "one" "add base layer"
    create_branch "$DEST" "top-layer" "layer2.txt" "two" "add top layer"
    ;;

  test-restack)
    init_repo "$DEST"
    printf '#!/usr/bin/env bash\nset -euo pipefail\nprintf \"tests passed\\\\n\"\n' > "$DEST/run-tests.sh"
    chmod +x "$DEST/run-tests.sh"
    git -C "$DEST" add run-tests.sh
    git -C "$DEST" commit -qm "add tests"
    git -C "$DEST" push -q origin master
    create_branch "$DEST" "parent" "parent.txt" "parent v1" "add parent"
    create_branch "$DEST" "child" "child.txt" "child v1" "add child"
    spice "$DEST" branch checkout prateek/parent --no-prompt >/dev/null
    printf 'parent v2\n' > "$DEST/parent.txt"
    git -C "$DEST" add parent.txt
    git -C "$DEST" commit --amend --no-edit -q
    spice "$DEST" branch checkout prateek/child --no-prompt >/dev/null
    ;;
esac

printf 'fixture=%s\nrepo=%s\n' "$FIXTURE" "$DEST"
