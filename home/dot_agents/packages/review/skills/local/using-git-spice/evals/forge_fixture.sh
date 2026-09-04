#!/usr/bin/env bash
# Prepare or clean the dedicated prateek/git-spice-evals forge fixture.
# Usage: forge_fixture.sh setup <e3-fresh|e4-stale|e6-unsubmitted|e7-merged> <absolute-dest>
#        forge_fixture.sh cleanup <absolute-dest>

set -euo pipefail

readonly FORGE_REPO="prateek/git-spice-evals"

usage() {
  echo "usage: $0 setup <scenario> <absolute-dest> | cleanup <absolute-dest>" >&2
  exit 2
}

authenticate() {
  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    local token
    token="$(gh auth token)"
    export GITHUB_TOKEN="$token"
  fi
  git-spice auth status --no-prompt >/dev/null
}

cleanup_fixture() {
  local dest="$1"
  local metadata="$dest/.git/forge-eval.json"

  if [[ ! -f "$metadata" ]]; then
    echo "missing fixture metadata: $metadata" >&2
    exit 1
  fi

  local repo
  repo="$(jq -r '.repo' "$metadata")"
  if [[ "$repo" != "$FORGE_REPO" ]]; then
    echo "refusing cleanup for unexpected repository: $repo" >&2
    exit 1
  fi

  while IFS= read -r branch; do
    while IFS= read -r number; do
      [[ -n "$number" ]] || continue
      gh pr close "$number" --repo "$FORGE_REPO" >/dev/null 2>&1 || true
    done < <(gh pr list --repo "$FORGE_REPO" --state open --head "$branch" --json number --jq '.[].number')

    gh api -X DELETE "repos/$FORGE_REPO/git/refs/heads/$branch" >/dev/null 2>&1 || true
  done < <(jq -r '.branches[]' "$metadata")

  echo "forge fixture cleaned; remove local directory when finished: $dest"
}

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

create_stack() {
  local repo="$1"
  local run="$2"
  local base_bare="$3"
  local child_bare="$4"

  printf 'base %s v1\n' "$run" > "$repo/base-$run.txt"
  git -C "$repo" add "base-$run.txt"
  spice "$repo" branch create "$base_bare" -m "Add eval base $run" --no-prompt >/dev/null

  printf 'child %s\n' "$run" > "$repo/child-$run.txt"
  git -C "$repo" add "child-$run.txt"
  spice "$repo" branch create "$child_bare" -m "Add eval child $run" --no-prompt >/dev/null
}

setup_fixture() {
  local scenario="$1"
  local dest="$2"

  case "$scenario" in
    e3-fresh | e4-stale | e6-unsubmitted | e7-merged) ;;
    *) usage ;;
  esac

  if [[ "$dest" != /* ]]; then
    echo "destination must be absolute: $dest" >&2
    exit 1
  fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    echo "refusing to overwrite destination: $dest" >&2
    exit 1
  fi

  mkdir -p -- "$(dirname -- "$dest")"
  gh repo clone "$FORGE_REPO" "$dest" -- --quiet
  configure_repo "$dest"
  spice "$dest" repo init --trunk=master --remote=origin --no-prompt >/dev/null

  local run
  run="${scenario#e?-}-$(date +%s)-$$"
  local base_bare="eval-$run-base"
  local child_bare="eval-$run-child"
  local base_branch="prateek/$base_bare"
  local child_branch="prateek/$child_bare"

  create_stack "$dest" "$run" "$base_bare" "$child_bare"

  jq -n \
    --arg repo "$FORGE_REPO" \
    --arg scenario "$scenario" \
    --arg base "$base_branch" \
    --arg child "$child_branch" \
    '{repo: $repo, scenario: $scenario, branches: [$child, $base]}' \
    > "$dest/.git/forge-eval.json"

  case "$scenario" in
    e3-fresh | e6-unsubmitted)
      ;;

    e4-stale)
      spice "$dest" downstack submit --fill --dry-run --no-prompt >/dev/null
      spice "$dest" downstack submit --fill --no-prompt >/dev/null
      spice "$dest" branch checkout "$base_branch" --no-prompt >/dev/null
      printf 'base %s v2\n' "$run" > "$dest/base-$run.txt"
      git -C "$dest" add "base-$run.txt"
      git -C "$dest" commit --amend --no-edit -q
      spice "$dest" branch checkout "$child_branch" --no-prompt >/dev/null
      ;;

    e7-merged)
      spice "$dest" downstack submit --fill --dry-run --no-prompt >/dev/null
      spice "$dest" downstack submit --fill --no-prompt >/dev/null
      local base_number
      base_number="$(gh pr view "$base_branch" --repo "$FORGE_REPO" --json number --jq .number)"
      gh pr ready "$base_number" --repo "$FORGE_REPO" >/dev/null
      gh pr merge "$base_number" --repo "$FORGE_REPO" --squash >/dev/null
      ;;
  esac

  jq . "$dest/.git/forge-eval.json"
}

authenticate

case "${1:-}" in
  setup)
    [[ $# -eq 3 ]] || usage
    setup_fixture "$2" "$3"
    ;;
  cleanup)
    [[ $# -eq 2 ]] || usage
    cleanup_fixture "$2"
    ;;
  *)
    usage
    ;;
esac
