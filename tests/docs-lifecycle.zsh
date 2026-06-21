#!/usr/bin/env zsh
set -euo pipefail

# This suite builds throwaway git repos under $TMPDIR. When run from the prek
# pre-commit hook, git exports GIT_DIR/GIT_WORK_TREE/etc. into the environment,
# and `git config`/`git init` honor those over `-C` — so without scrubbing them,
# our fixture setup would write into the real repo's config. Isolate from any
# inherited git context before touching git.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_COMMON_DIR GIT_PREFIX GIT_NAMESPACE GIT_ALTERNATE_OBJECT_DIRECTORIES

ROOT=${0:a:h:h}
VALIDATOR="$ROOT/docs/validate-doc-lifecycle.py"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
OUT="$TMPDIR/out"
ERR="$TMPDIR/err"

write_doc() {
  local doc_path=$1
  mkdir -p "${doc_path:h}"
  shift
  printf '%s\n' "$@" > "$doc_path"
}

refresh_index() {
  local root=${repo:-}
  [[ -n "$root" && -d "$root/docs" ]] || return 0

  {
    print -- '---'
    print -- 'status: current'
    print -- 'doc_type: index'
    print -- '---'
    print -- ''
    print -- '# Documentation Index'
    print -- ''
    find "$root/docs" -type f -name '*.md' | sed "s#^$root/docs/##" | LC_ALL=C sort | while IFS= read -r rel; do
      print -- "- [$rel]($rel)"
    done
  } > "$root/docs/index.md"
}

assert_success() {
  if [[ $# -gt 0 && "$1" == "$VALIDATOR" ]]; then
    refresh_index
  fi
  "$@" >"$OUT" 2>"$ERR" || {
    print -u2 -- "expected success: $*"
    print -u2 -- "--- stdout ---"
    cat "$OUT" >&2
    print -u2 -- "--- stderr ---"
    cat "$ERR" >&2
    exit 1
  }
}

assert_failure() {
  if "$@" >"$OUT" 2>"$ERR"; then
    print -u2 -- "expected failure: $*"
    print -u2 -- "--- stdout ---"
    cat "$OUT" >&2
    print -u2 -- "--- stderr ---"
    cat "$ERR" >&2
    exit 1
  fi
}

assert_failure_matching() {
  local pattern=$1
  shift
  assert_failure "$@"
  if ! grep -F -- "$pattern" "$ERR" >/dev/null; then
    print -u2 -- "expected failure matching: $pattern"
    print -u2 -- "--- stderr ---"
    cat "$ERR" >&2
    exit 1
  fi
}

write_matrix_doc() {
  local doc_path=$1
  local lifecycle_status=$2
  local doc_type=$3
  local title=$4
  local -a lines
  lines=(
    '---'
    "status: $lifecycle_status"
    "doc_type: $doc_type"
  )

  case "$lifecycle_status" in
    archived)
      lines+=('closed: 2026-05-11' 'current_guidance: ../current-guide.md')
      ;;
    superseded)
      lines+=('closed: 2026-05-11' 'superseded_by: ../current-guide.md')
      ;;
    rejected)
      lines+=('closed: 2026-05-11' 'status_detail: "No successor."')
      ;;
  esac

  lines+=('---' '' "# $title" '' 'Body.')
  write_doc "$doc_path" "${lines[@]}"
}

assert_matrix_status() {
  local doc_type=$1
  local lifecycle_status=$2
  local expected=$3
  local doc_path="$repo/docs/matrix/${doc_type}-${lifecycle_status}.md"
  write_matrix_doc \
    "$doc_path" \
    "$lifecycle_status" \
    "$doc_type" \
    "Matrix $doc_type $lifecycle_status"
  refresh_index
  assert_failure_matching "$expected" "$VALIDATOR" --repo-root "$repo"
  rm "$doc_path"
  refresh_index
}

repo="$TMPDIR/repo"
mkdir -p "$repo/docs/adr" "$repo/docs/plans"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name "Docs Lifecycle Test"
git -C "$repo" config commit.gpgSign false

write_doc "$repo/docs/adr/0001-decision.md" \
  '---' \
  'status: accepted' \
  'doc_type: adr' \
  '---' \
  '' \
  '# Decision' \
  '' \
  'Accepted decision body.'

write_doc "$repo/docs/plans/old-plan.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Old Plan' \
  '' \
  'Historical body.'

write_doc "$repo/docs/plans/replaced-plan.md" \
  '---' \
  'status: superseded' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'superseded_by: ../current-guide.md' \
  '---' \
  '' \
  '# Replaced Plan' \
  '' \
  'Historical body.'

write_doc "$repo/docs/current-guide.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Current Guide' \
  '' \
  'Current body.'

write_doc "$repo/docs/index.md" \
  '---' \
  'status: current' \
  'doc_type: index' \
  '---' \
  '' \
  '# Documentation Index' \
  '' \
  'Start here.'

write_doc "$repo/docs/plans/inline-guidance.md" \
  '---' \
  'status: archived' \
  'doc_type: research' \
  'closed: 2026-05-11' \
  'current_guidance: [../current-guide.md]' \
  '---' \
  '' \
  '# Inline Guidance' \
  '' \
  'Historical body.'

assert_success "$VALIDATOR" --repo-root "$repo"
assert_success "$VALIDATOR" --repo-root "$repo" --docs-root "$repo/docs"

typeset -A allowed_status_matrix=(
  adr 'proposed active accepted superseded rejected archived'
  plan 'draft proposed accepted active superseded rejected archived'
  runbook 'active current superseded archived'
  reference 'active current superseded archived'
  research 'draft active current superseded archived'
  convention 'active current superseded archived'
  index 'active current'
)
for doc_type in ${(k)allowed_status_matrix}; do
  for lifecycle_status in ${(s: :)allowed_status_matrix[$doc_type]}; do
    write_matrix_doc \
      "$repo/docs/matrix/${doc_type}-${lifecycle_status}.md" \
      "$lifecycle_status" \
      "$doc_type" \
      "Matrix $doc_type $lifecycle_status"
  done
done
assert_success "$VALIDATOR" --repo-root "$repo"

assert_matrix_status adr current "ADRs must not use status 'current'"
assert_matrix_status plan current "completed plans must be archived or superseded"
assert_matrix_status runbook proposed "doc_type 'runbook' cannot use status 'proposed'"
assert_matrix_status reference accepted "doc_type 'reference' cannot use status 'accepted'"
assert_matrix_status research proposed "doc_type 'research' cannot use status 'proposed'"
assert_matrix_status convention proposed "doc_type 'convention' cannot use status 'proposed'"
assert_matrix_status index archived "doc_type index must use status active or current"

rm -rf "$repo/docs/matrix"
refresh_index

write_doc "$repo/guides/index.md" \
  '---' \
  'status: current' \
  'doc_type: index' \
  '---' \
  '' \
  '# Guides Index' \
  '' \
  '- [Index](index.md)' \
  '- [Guide](guide.md)'
write_doc "$repo/guides/guide.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Guide'
assert_success "$VALIDATOR" --repo-root "$repo" --docs-root "$repo/guides"
mkdir -p "$repo/guides/dev"
write_doc "$repo/guides/dev/guide.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Custom Dev Guide'
write_doc "$repo/guides/index.md" \
  '---' \
  'status: current' \
  'doc_type: index' \
  '---' \
  '' \
  '# Guides Index' \
  '' \
  '- [Index](index.md)' \
  '- [Guide](guide.md)' \
  '- [Custom Dev Guide](dev/guide.md)'
assert_success "$VALIDATOR" --repo-root "$repo" --docs-root "$repo/guides"
rm -rf "$repo/guides"

mv "$repo/docs/index.md" "$repo/docs/index.md.bak"
assert_failure_matching "docs root must include index.md" "$VALIDATOR" --repo-root "$repo"
mv "$repo/docs/index.md.bak" "$repo/docs/index.md"

write_doc "$repo/docs/index.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Documentation Index'
assert_failure_matching "docs root index must use doc_type index" "$VALIDATOR" --repo-root "$repo"
refresh_index

write_doc "$repo/docs/plans/current-plan.md" \
  '---' \
  'status: current' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Current Plan' \
  '' \
  'A plan cannot be steady-state guidance.'
assert_failure_matching "completed plans must be archived or superseded" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/current-plan.md"

write_doc "$repo/docs/adr/0002-current-decision.md" \
  '---' \
  'status: current' \
  'doc_type: adr' \
  '---' \
  '' \
  '# Current Decision'
assert_failure_matching "ADRs must not use status 'current'" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/adr/0002-current-decision.md"

write_doc "$repo/docs/index.md" \
  '---' \
  'status: archived' \
  'doc_type: index' \
  'closed: 2026-05-11' \
  'current_guidance: current-guide.md' \
  '---' \
  '' \
  '# Documentation Index'
assert_failure_matching "doc_type index must use status active or current" "$VALIDATOR" --repo-root "$repo"
refresh_index

write_doc "$repo/docs/plans/bad-status.md" \
  '---' \
  'status: stale' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Bad Status'
assert_failure_matching "status must be one of" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/bad-status.md"

write_doc "$repo/docs/plans/empty-status.md" \
  '---' \
  'status:' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Empty Status'
assert_failure_matching "status must be one of" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/empty-status.md"

write_doc "$repo/docs/plans/bad-type.md" \
  '---' \
  'status: current' \
  'doc_type: memo' \
  '---' \
  '' \
  '# Bad Type'
assert_failure_matching "doc_type must be one of" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/bad-type.md"

write_doc "$repo/docs/plans/accepted-reference.md" \
  '---' \
  'status: accepted' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Accepted Reference'
assert_failure_matching "doc_type 'reference' cannot use status 'accepted'" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/accepted-reference.md"

write_doc "$repo/docs/plans/empty-type.md" \
  '---' \
  'status: current' \
  'doc_type:' \
  '---' \
  '' \
  '# Empty Type'
assert_failure_matching "doc_type must be one of" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/empty-type.md"

write_doc "$repo/docs/plans/no-frontmatter.md" \
  '# No Frontmatter'
assert_failure_matching "missing YAML frontmatter" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/no-frontmatter.md"

write_doc "$repo/docs/plans/no-h1.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  'No H1 here.'
assert_failure_matching "Markdown body must start with an H1" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/no-h1.md"

write_doc "$repo/docs/plans/closed-missing-date.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Closed Missing Date'
assert_failure_matching "requires closed" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/closed-missing-date.md"

write_doc "$repo/docs/plans/closed-invalid-date.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: not-a-date' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Closed Invalid Date'
assert_failure_matching "closed must be an ISO date" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/closed-invalid-date.md"

write_doc "$repo/docs/plans/invalid-created-date.md" \
  '---' \
  'status: active' \
  'doc_type: plan' \
  'created: not-a-date' \
  '---' \
  '' \
  '# Invalid Created Date'
assert_failure_matching "created must be an ISO date" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/invalid-created-date.md"

write_doc "$repo/docs/plans/invalid-updated-date.md" \
  '---' \
  'status: active' \
  'doc_type: plan' \
  'updated: not-a-date' \
  '---' \
  '' \
  '# Invalid Updated Date'
assert_failure_matching "updated must be an ISO date" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/invalid-updated-date.md"

write_doc "$repo/docs/plans/open-with-closed-date.md" \
  '---' \
  'status: active' \
  'doc_type: reference' \
  'closed: 2026-05-11' \
  '---' \
  '' \
  '# Open With Closed Date'
assert_failure_matching "closed is only valid for archived, superseded, or rejected docs" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/open-with-closed-date.md"

write_doc "$repo/docs/plans/closed-missing-guidance.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  '---' \
  '' \
  '# Closed Missing Guidance'
assert_failure_matching "requires current_guidance" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/closed-missing-guidance.md"

write_doc "$repo/docs/plans/closed-empty-guidance.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance:' \
  '---' \
  '' \
  '# Closed Empty Guidance'
assert_failure_matching "requires non-empty current_guidance" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/closed-empty-guidance.md"

write_doc "$repo/docs/plans/closed-empty-inline-guidance.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: []' \
  '---' \
  '' \
  '# Closed Empty Inline Guidance'
assert_failure_matching "requires non-empty current_guidance" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/closed-empty-inline-guidance.md"

write_doc "$repo/docs/plans/closed-quoted-empty-guidance.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ""' \
  '---' \
  '' \
  '# Closed Quoted Empty Guidance'
assert_failure_matching "requires non-empty current_guidance" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/closed-quoted-empty-guidance.md"

write_doc "$repo/docs/plans/superseded-missing-target.md" \
  '---' \
  'status: superseded' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  '---' \
  '' \
  '# Superseded Missing Target'
assert_failure_matching "requires superseded_by" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/superseded-missing-target.md"

write_doc "$repo/docs/plans/superseded-missing-date.md" \
  '---' \
  'status: superseded' \
  'doc_type: plan' \
  'superseded_by: ../current-guide.md' \
  '---' \
  '' \
  '# Superseded Missing Date'
assert_failure_matching "requires closed" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/superseded-missing-date.md"

write_doc "$repo/docs/plans/superseded-empty-target.md" \
  '---' \
  'status: superseded' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'superseded_by:' \
  '---' \
  '' \
  '# Superseded Empty Target'
assert_failure_matching "requires non-empty superseded_by" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/superseded-empty-target.md"

write_doc "$repo/docs/plans/broken-target.md" \
  '---' \
  'status: superseded' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'superseded_by: missing.md' \
  '---' \
  '' \
  '# Broken Target'
assert_failure_matching "superseded_by target must be a repo-local relative path that exists" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/broken-target.md"

write_doc "$repo/docs/plans/broken-related.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  'related: missing.md' \
  '---' \
  '' \
  '# Broken Related'
assert_failure_matching "related target must be a repo-local relative path that exists" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/broken-related.md"

write_doc "$repo/docs/plans/external-target.md" \
  '---' \
  'status: archived' \
  'doc_type: research' \
  'closed: 2026-05-11' \
  'current_guidance: ~/dotfiles/docs/current-guide.md' \
  '---' \
  '' \
  '# External Target'
assert_failure_matching "current_guidance target must be a repo-local relative path that exists" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/external-target.md"

outside="$TMPDIR/outside.md"
printf '%s\n' '# Outside' > "$outside"
write_doc "$repo/docs/plans/escaping-target.md" \
  '---' \
  'status: archived' \
  'doc_type: research' \
  'closed: 2026-05-11' \
  "current_guidance: ../../../${outside:t}" \
  '---' \
  '' \
  '# Escaping Target'
assert_failure_matching "current_guidance target must be a repo-local relative path that exists" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/escaping-target.md"

write_doc "$repo/docs/plans/anchor-only-target.md" \
  '---' \
  'status: archived' \
  'doc_type: research' \
  'closed: 2026-05-11' \
  'current_guidance: "#current-guide"' \
  '---' \
  '' \
  '# Anchor Only Target'
assert_failure_matching "current_guidance target must be a repo-local relative path that exists" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/anchor-only-target.md"

write_doc "$repo/docs/plans/rejected-missing-rationale.md" \
  '---' \
  'status: rejected' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  '---' \
  '' \
  '# Rejected Missing Rationale'
assert_failure_matching "status 'rejected' requires current_guidance or status_detail" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/rejected-missing-rationale.md"

write_doc "$repo/docs/plans/rejected-empty-guidance.md" \
  '---' \
  'status: rejected' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: []' \
  '---' \
  '' \
  '# Rejected Empty Guidance'
assert_failure_matching "status 'rejected' requires current_guidance or status_detail" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/rejected-empty-guidance.md"

write_doc "$repo/docs/plans/rejected-empty-detail.md" \
  '---' \
  'status: rejected' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'status_detail: ""' \
  '---' \
  '' \
  '# Rejected Empty Detail'
assert_failure_matching "status 'rejected' requires current_guidance or status_detail" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/rejected-empty-detail.md"

write_doc "$repo/docs/plans/nested-frontmatter.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  'owner:' \
  '  name: Prateek' \
  '---' \
  '' \
  '# Nested Frontmatter'
assert_failure_matching "unsupported nested or indented value" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/nested-frontmatter.md"

write_doc "$repo/docs/plans/block-frontmatter.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  'status_detail: |' \
  '  Unsupported block value.' \
  '---' \
  '' \
  '# Block Frontmatter'
assert_failure_matching "block scalars are not supported" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/block-frontmatter.md"

write_doc "$repo/docs/plans/duplicate-frontmatter.md" \
  '---' \
  'status: current' \
  'status: active' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Duplicate Frontmatter'
assert_failure_matching "duplicate key 'status'" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/duplicate-frontmatter.md"

write_doc "$repo/docs/plans/unsupported-key.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  'skill_path: ../../home/dot_agents/skills/example/' \
  '---' \
  '' \
  '# Unsupported Key'
assert_failure_matching "unsupported frontmatter key 'skill_path'" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/unsupported-key.md"

printf '<html></html>\n' > "$repo/docs/plans/capture.html"
assert_failure_matching "non-Markdown content is not allowed under docs/" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/capture.html"

print -- '__pycache__/' > "$repo/.gitignore"
mkdir -p "$repo/docs/__pycache__"
printf 'ignored bytecode\n' > "$repo/docs/__pycache__/validate-doc-lifecycle.cpython-313.pyc"
assert_success "$VALIDATOR" --repo-root "$repo"
rm -rf "$repo/docs/__pycache__" "$repo/.gitignore"

write_doc "$repo/docs/plans/unindexed.md" \
  '---' \
  'status: proposed' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Unindexed'
refresh_index
perl -0pi -e 's#^.*plans/unindexed\.md.*\n##m' "$repo/docs/index.md"
assert_failure_matching "missing docs index entry for plans/unindexed.md" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/unindexed.md"

refresh_index
print -- '- [Missing](plans/missing.md)' >> "$repo/docs/index.md"
assert_failure_matching "index link target must exist: plans/missing.md" "$VALIDATOR" --repo-root "$repo"
perl -0pi -e 's#\n- \[Missing\]\(plans/missing\.md\)\n##' "$repo/docs/index.md"

write_doc "$repo/docs/plans/misdirected-index.md" \
  '---' \
  'status: proposed' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Misdirected Index'
write_doc "$repo/docs/plans/misdirected-target.md" \
  '---' \
  'status: proposed' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Misdirected Target'
refresh_index
perl -0pi -e 's#- \[plans/misdirected-index\.md\]\(plans/misdirected-index\.md\)#- [plans/misdirected-index.md](plans/misdirected-target.md)#' "$repo/docs/index.md"
assert_failure_matching "missing docs index entry for plans/misdirected-index.md" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/misdirected-index.md" "$repo/docs/plans/misdirected-target.md"
refresh_index

write_doc "$repo/docs/plans/broken-body-link.md" \
  '---' \
  'status: proposed' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Broken Body Link' \
  '' \
  'See [missing](missing.md).'
assert_failure_matching "Markdown link target must exist: missing.md" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/broken-body-link.md"

write_doc "$repo/docs/plans/code-block-body-link.md" \
  '---' \
  'status: proposed' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Code Block Body Link' \
  '' \
  '```markdown' \
  '[missing](missing.md)' \
  '```'
assert_success "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/code-block-body-link.md"

write_doc "$repo/docs/plans/stale-reference.md" \
  '---' \
  'status: proposed' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Stale Reference' \
  '' \
  'Read docs/dev/old-plan.md.'
assert_failure_matching "stale moved docs path reference" "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/stale-reference.md"

write_doc "$repo/docs/plans/stale-reference-code-block.md" \
  '---' \
  'status: proposed' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Stale Reference Code Block' \
  '' \
  '```text' \
  'docs/dev/old-plan.md' \
  '```'
assert_success "$VALIDATOR" --repo-root "$repo"
rm "$repo/docs/plans/stale-reference-code-block.md"

write_doc "$repo/docs/dev/foo.md" \
  '---' \
  'status: proposed' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Retired Dev Folder'
refresh_index
assert_failure_matching "docs/dev is retired" "$VALIDATOR" --repo-root "$repo"
rm -rf "$repo/docs/dev"

write_doc "$repo/docs/dev/no-frontmatter.md" \
  '# Retired Dev Folder Without Frontmatter'
refresh_index
assert_failure_matching "docs/dev is retired" "$VALIDATOR" --repo-root "$repo"
rm -rf "$repo/docs/dev"

write_doc "$repo/docs/plans/link-source.md" \
  '---' \
  'status: archived' \
  'doc_type: research' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Link Source' \
  '' \
  'See [target.md](target.md).' \
  'See [other.md](other.md).'
write_doc "$repo/docs/plans/target.md" \
  '---' \
  'status: proposed' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Target' \
  '' \
  'Target body.'
write_doc "$repo/docs/plans/other.md" \
  '---' \
  'status: proposed' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Other' \
  '' \
  'Other body.'
refresh_index

git -C "$repo" add docs
git -C "$repo" commit -q -m base

mkdir -p "$repo/docs/research"
git -C "$repo" mv docs/plans/link-source.md docs/research/link-source.md
write_doc "$repo/docs/research/link-source.md" \
  '---' \
  'status: archived' \
  'doc_type: research' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Link Source' \
  '' \
  'See [target.md](../plans/target.md).' \
  'See [other.md](../plans/other.md).'
refresh_index
assert_success "$VALIDATOR" --repo-root "$repo" --base HEAD
git -C "$repo" restore --source=HEAD --staged --worktree -- docs

mkdir -p "$repo/docs/research"
git -C "$repo" mv docs/plans/link-source.md docs/research/link-source.md
write_doc "$repo/docs/research/link-source.md" \
  '---' \
  'status: archived' \
  'doc_type: research' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Link Source' \
  '' \
  'See [../plans/target.md](../plans/target.md).' \
  'See [../plans/other.md](../plans/other.md).'
refresh_index
assert_success "$VALIDATOR" --repo-root "$repo" --base HEAD
git -C "$repo" restore --source=HEAD --staged --worktree -- docs

mkdir -p "$repo/docs/research"
git -C "$repo" mv docs/plans/link-source.md docs/research/link-source.md
write_doc "$repo/docs/research/link-source.md" \
  '---' \
  'status: archived' \
  'doc_type: research' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Link Source' \
  '' \
  'See [../plans/target.md](../plans/target.md).' \
  'See [other.md](other.md).'
write_doc "$repo/docs/research/other.md" \
  '---' \
  'status: active' \
  'doc_type: research' \
  '---' \
  '' \
  '# Wrong Other' \
  '' \
  'This keeps one unchanged relative link valid while changing its target.'
refresh_index
assert_failure_matching "body edits are blocked" "$VALIDATOR" --repo-root "$repo" --base HEAD
git -C "$repo" restore --source=HEAD --staged --worktree -- docs

mkdir -p "$repo/docs/research"
git -C "$repo" mv docs/plans/link-source.md docs/research/link-source.md
write_doc "$repo/docs/research/target.md" \
  '---' \
  'status: active' \
  'doc_type: research' \
  '---' \
  '' \
  '# Wrong Target' \
  '' \
  'This keeps the unchanged relative link valid while changing its target.'
write_doc "$repo/docs/research/other.md" \
  '---' \
  'status: active' \
  'doc_type: research' \
  '---' \
  '' \
  '# Wrong Other' \
  '' \
  'This keeps the unchanged relative link valid while changing its target.'
refresh_index
assert_failure_matching "locked doc move must preserve Markdown link targets" "$VALIDATOR" --repo-root "$repo" --base HEAD
git -C "$repo" restore --source=HEAD --staged --worktree -- docs

git -C "$repo" mv docs/adr/0001-decision.md docs/adr/0001-renamed-decision.md
assert_success "$VALIDATOR" --repo-root "$repo" --base HEAD

write_doc "$repo/docs/adr/0001-renamed-decision.md" \
  '---' \
  'status: accepted' \
  'doc_type: adr' \
  '---' \
  '' \
  '# Decision' \
  '' \
  'Edited accepted decision body.'
assert_failure_matching "body edits are blocked" "$VALIDATOR" --repo-root "$repo" --base HEAD
git -C "$repo" mv docs/adr/0001-renamed-decision.md docs/adr/0001-decision.md
git -C "$repo" checkout -q -- docs/adr/0001-decision.md

rm "$repo/docs/adr/0001-decision.md"
assert_failure_matching "locked historical doc cannot be deleted" "$VALIDATOR" --repo-root "$repo" --base HEAD
git -C "$repo" checkout -q -- docs/adr/0001-decision.md

rm "$repo/docs/plans/old-plan.md"
assert_failure_matching "locked historical doc cannot be deleted" "$VALIDATOR" --repo-root "$repo" --base HEAD
git -C "$repo" checkout -q -- docs/plans/old-plan.md
assert_success "$VALIDATOR" --repo-root "$repo" --base HEAD

assert_failure_matching "base ref does not exist" "$VALIDATOR" --repo-root "$repo" --base missing-ref

write_doc "$repo/docs/plans/old-plan.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  'status_detail: "metadata-only edits are allowed"' \
  '---' \
  '' \
  '# Old Plan' \
  '' \
  'Historical body.'
assert_success "$VALIDATOR" --repo-root "$repo" --base HEAD

write_doc "$repo/docs/plans/old-plan.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Old Plan' \
  '' \
  'Edited historical body.'
assert_failure_matching "body edits are blocked" "$VALIDATOR" --repo-root "$repo" --base HEAD
git -C "$repo" checkout -q -- docs/plans/old-plan.md

write_doc "$repo/docs/adr/0001-decision.md" \
  '---' \
  'status: accepted' \
  'doc_type: adr' \
  '---' \
  '' \
  '# Decision' \
  '' \
  'Edited accepted decision body.'
assert_failure_matching "body edits are blocked" "$VALIDATOR" --repo-root "$repo" --base HEAD
git -C "$repo" checkout -q -- docs/adr/0001-decision.md

write_doc "$repo/docs/adr/0001-decision.md" \
  '---' \
  'status: active' \
  'doc_type: adr' \
  '---' \
  '' \
  '# Decision' \
  '' \
  'Accepted decision body.'
assert_failure_matching "accepted ADRs can only remain accepted or close" "$VALIDATOR" --repo-root "$repo" --base HEAD
git -C "$repo" checkout -q -- docs/adr/0001-decision.md

write_doc "$repo/docs/adr/0001-decision.md" \
  '---' \
  'status: current' \
  'doc_type: adr' \
  '---' \
  '' \
  '# Decision' \
  '' \
  'Accepted decision body.'
assert_failure_matching "accepted ADRs can only remain accepted or close" "$VALIDATOR" --repo-root "$repo" --base HEAD
git -C "$repo" checkout -q -- docs/adr/0001-decision.md

write_doc "$repo/docs/adr/0002-active-decision.md" \
  '---' \
  'status: active' \
  'doc_type: adr' \
  '---' \
  '' \
  '# Active Decision' \
  '' \
  'Active decision body.'
git -C "$repo" add docs/adr/0002-active-decision.md
git -C "$repo" commit -q -m 'add active adr'

write_doc "$repo/docs/adr/0002-active-decision.md" \
  '---' \
  'status: current' \
  'doc_type: adr' \
  '---' \
  '' \
  '# Active Decision' \
  '' \
  'Active decision body.'
assert_failure_matching "ADRs must not use status 'current'" "$VALIDATOR" --repo-root "$repo" --base HEAD
git -C "$repo" checkout -q -- docs/adr/0002-active-decision.md

write_doc "$repo/docs/plans/open-plan.md" \
  '---' \
  'status: draft' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Open Plan' \
  '' \
  'Draft body.'
git -C "$repo" add docs/plans/open-plan.md
git -C "$repo" commit -q -m 'add draft'

write_doc "$repo/docs/plans/open-plan.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Open Plan' \
  '' \
  'Edited while closing.'
assert_failure_matching "body edits are blocked" "$VALIDATOR" --repo-root "$repo" --base HEAD

write_doc "$repo/docs/plans/open-plan.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Open Plan' \
  '' \
  'Draft body.'
assert_success "$VALIDATOR" --repo-root "$repo" --base HEAD

write_doc "$repo/docs/plans/draft-research.md" \
  '---' \
  'status: draft' \
  'doc_type: research' \
  '---' \
  '' \
  '# Draft Research' \
  '' \
  'Draft body.'
git -C "$repo" add docs/plans/draft-research.md
git -C "$repo" commit -q -m 'add draft research'

write_doc "$repo/docs/plans/draft-research.md" \
  '---' \
  'status: current' \
  'doc_type: research' \
  '---' \
  '' \
  '# Draft Research' \
  '' \
  'Draft body.'
assert_failure_matching "invalid status transition" "$VALIDATOR" --repo-root "$repo" --base HEAD
git -C "$repo" checkout -q -- docs/plans/draft-research.md

write_doc "$repo/docs/plans/proposed-plan.md" \
  '---' \
  'status: proposed' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Proposed Plan' \
  '' \
  'Proposed body.'
git -C "$repo" add docs/plans/proposed-plan.md
git -C "$repo" commit -q -m 'add proposed plan'

write_doc "$repo/docs/plans/proposed-plan.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Proposed Plan' \
  '' \
  'Proposed body.'
assert_failure_matching "invalid status transition" "$VALIDATOR" --repo-root "$repo" --base HEAD
git -C "$repo" checkout -q -- docs/plans/proposed-plan.md

write_doc "$repo/docs/plans/accepted-plan.md" \
  '---' \
  'status: accepted' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Accepted Plan' \
  '' \
  'Accepted body.'
git -C "$repo" add docs/plans/accepted-plan.md
git -C "$repo" commit -q -m 'add accepted plan'

write_doc "$repo/docs/plans/accepted-plan.md" \
  '---' \
  'status: active' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Accepted Plan' \
  '' \
  'Accepted body.'
assert_success "$VALIDATOR" --repo-root "$repo" --base HEAD

write_doc "$repo/docs/type-transition.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Type Transition' \
  '' \
  'Body.'
git -C "$repo" add docs/type-transition.md
git -C "$repo" commit -q -m 'add reference'

write_doc "$repo/docs/type-transition.md" \
  '---' \
  'status: current' \
  'doc_type: research' \
  '---' \
  '' \
  '# Type Transition' \
  '' \
  'Body.'
assert_failure_matching "invalid doc_type transition" "$VALIDATOR" --repo-root "$repo" --base HEAD
git -C "$repo" checkout -q -- docs/type-transition.md

write_doc "$repo/docs/adr/0002-active.md" \
  '---' \
  'status: active' \
  'doc_type: adr' \
  '---' \
  '' \
  '# Active Decision' \
  '' \
  'Decision body.'
git -C "$repo" add docs/adr/0002-active.md
git -C "$repo" commit -q -m 'add active adr'

write_doc "$repo/docs/adr/0002-active.md" \
  '---' \
  'status: accepted' \
  'doc_type: adr' \
  '---' \
  '' \
  '# Active Decision' \
  '' \
  'Decision body.'
assert_success "$VALIDATOR" --repo-root "$repo" --base HEAD

write_doc "$repo/docs/plans/reference-conversion.md" \
  '---' \
  'status: active' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Reference Conversion' \
  '' \
  'Plan body.'
write_doc "$repo/docs/plans/runbook-conversion.md" \
  '---' \
  'status: active' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Runbook Conversion' \
  '' \
  'Plan body.'
git -C "$repo" add docs/plans/reference-conversion.md docs/plans/runbook-conversion.md
git -C "$repo" commit -q -m 'add conversion plans'

write_doc "$repo/docs/plans/reference-conversion.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Reference Conversion' \
  '' \
  'Plan body.'
write_doc "$repo/docs/plans/runbook-conversion.md" \
  '---' \
  'status: current' \
  'doc_type: runbook' \
  '---' \
  '' \
  '# Runbook Conversion' \
  '' \
  'Plan body.'
assert_success "$VALIDATOR" --repo-root "$repo" --base HEAD

write_doc "$repo/docs/plans/rejected-plan.md" \
  '---' \
  'status: rejected' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'status_detail: "No successor."' \
  '---' \
  '' \
  '# Rejected Plan' \
  '' \
  'Rejected body.'
write_doc "$repo/docs/plans/superseded-plan.md" \
  '---' \
  'status: superseded' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'superseded_by: ../current-guide.md' \
  '---' \
  '' \
  '# Superseded Plan' \
  '' \
  'Superseded body.'
git -C "$repo" add docs/plans/rejected-plan.md docs/plans/superseded-plan.md
git -C "$repo" commit -q -m 'add closed plans'

write_doc "$repo/docs/plans/rejected-plan.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Rejected Plan' \
  '' \
  'Rejected body.'
write_doc "$repo/docs/plans/superseded-plan.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Superseded Plan' \
  '' \
  'Superseded body.'
assert_success "$VALIDATOR" --repo-root "$repo" --base HEAD

main_repo="$repo"

repo="$TMPDIR/history-created-close"
mkdir -p "$repo/docs/plans"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name "Docs Lifecycle Test"
git -C "$repo" config commit.gpgSign false
write_doc "$repo/docs/current-guide.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Current Guide'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m base
history_base=$(git -C "$repo" rev-parse HEAD)

write_doc "$repo/docs/plans/branch-created.md" \
  '---' \
  'status: active' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Branch Created' \
  '' \
  'Active body.'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'add active plan'

write_doc "$repo/docs/plans/branch-created.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Branch Created' \
  '' \
  'Edited while closing.'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'close with body edit'
assert_failure_matching "body edits are blocked because this change closes the doc" "$VALIDATOR" --repo-root "$repo" --base "$history_base"

repo="$TMPDIR/history-move-close-not-git-rename"
mkdir -p "$repo/docs/plans" "$repo/docs/references"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name "Docs Lifecycle Test"
git -C "$repo" config commit.gpgSign false
write_doc "$repo/docs/current-guide.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Current Guide'
write_doc "$repo/docs/plans/moved-plan.md" \
  '---' \
  'status: active' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Moved Plan' \
  '' \
  'Original short body.'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m base
history_base=$(git -C "$repo" rev-parse HEAD)

rm "$repo/docs/plans/moved-plan.md"
write_doc "$repo/docs/references/moved-plan.md" \
  '---' \
  'status: archived' \
  'doc_type: reference' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Moved Plan' \
  '' \
  'A completely different closure body that should not be treated as a metadata-only move.'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'move and close with body edit'
assert_failure_matching "body edits are blocked because this change closes the doc" "$VALIDATOR" --repo-root "$repo" --base "$history_base"

repo="$TMPDIR/history-malformed-created-close"
mkdir -p "$repo/docs/plans"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name "Docs Lifecycle Test"
git -C "$repo" config commit.gpgSign false
write_doc "$repo/docs/current-guide.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Current Guide'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m base
history_base=$(git -C "$repo" rev-parse HEAD)

write_doc "$repo/docs/plans/branch-created.md" \
  '# Branch Created' \
  '' \
  'Malformed intermediate body.'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'add malformed plan'

write_doc "$repo/docs/plans/branch-created.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Branch Created' \
  '' \
  'Edited while closing.'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'close malformed plan'
assert_failure_matching "missing YAML frontmatter" "$VALIDATOR" --repo-root "$repo" --base "$history_base"

repo="$TMPDIR/history-empty-status"
mkdir -p "$repo/docs/plans"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name "Docs Lifecycle Test"
git -C "$repo" config commit.gpgSign false
write_doc "$repo/docs/current-guide.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Current Guide'
write_doc "$repo/docs/plans/empty-status.md" \
  '---' \
  'status: active' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Empty Status'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m base
history_base=$(git -C "$repo" rev-parse HEAD)

write_doc "$repo/docs/plans/empty-status.md" \
  '---' \
  'status:' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Empty Status'
git -C "$repo" add docs
git -C "$repo" commit -q -m 'empty status'
assert_failure_matching "status must be one of" "$VALIDATOR" --repo-root "$repo" --base "$history_base"

repo="$TMPDIR/history-invalid-added-plan"
mkdir -p "$repo/docs/plans"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name "Docs Lifecycle Test"
git -C "$repo" config commit.gpgSign false
write_doc "$repo/docs/current-guide.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Current Guide'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m base
history_base=$(git -C "$repo" rev-parse HEAD)

write_doc "$repo/docs/plans/bad-current-plan.md" \
  '---' \
  'status: current' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Bad Current Plan'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'add invalid current plan'

write_doc "$repo/docs/plans/bad-current-plan.md" \
  '---' \
  'status: active' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Bad Current Plan'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'fix current plan status'
assert_failure_matching "completed plans must be archived or superseded" "$VALIDATOR" --repo-root "$repo" --base "$history_base"

repo="$TMPDIR/history-uses-merge-base"
mkdir -p "$repo/docs/plans"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name "Docs Lifecycle Test"
git -C "$repo" config commit.gpgSign false
write_doc "$repo/docs/current-guide.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Current Guide'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m base
git -C "$repo" branch feature

write_doc "$repo/docs/plans/master-plan.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Master Plan' \
  '' \
  'Closed on the base branch after the feature branch point.'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'advance base docs'
advanced_base=$(git -C "$repo" rev-parse HEAD)

git -C "$repo" checkout -q feature
write_doc "$repo/docs/plans/feature-plan.md" \
  '---' \
  'status: active' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Feature Plan'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'add feature docs'
assert_success "$VALIDATOR" --repo-root "$repo" --base "$advanced_base"

repo="$TMPDIR/history-synthetic-merge-uses-review-head"
mkdir -p "$repo/docs/plans"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name "Docs Lifecycle Test"
git -C "$repo" config commit.gpgSign false
write_doc "$repo/docs/current-guide.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Current Guide'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m base
git -C "$repo" branch feature

write_doc "$repo/docs/plans/master-plan.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Master Plan' \
  '' \
  'Closed on the base branch after the feature branch point.'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'advance base docs'
advanced_base=$(git -C "$repo" rev-parse HEAD)

git -C "$repo" checkout -q feature
write_doc "$repo/docs/plans/feature-plan.md" \
  '---' \
  'status: active' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Feature Plan'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'add feature docs'
feature_tip=$(git -C "$repo" rev-parse HEAD)

git -C "$repo" checkout -q --detach "$advanced_base"
git -C "$repo" checkout -q "$feature_tip" -- docs/plans/feature-plan.md
refresh_index
git -C "$repo" add docs
merge_tree=$(git -C "$repo" write-tree)
merge_commit=$(printf '%s\n' 'synthetic pull request merge' | git -C "$repo" commit-tree "$merge_tree" -p "$advanced_base" -p "$feature_tip")
git -C "$repo" checkout -q "$merge_commit"
assert_success "$VALIDATOR" --repo-root "$repo" --base "$advanced_base"

repo="$TMPDIR/history-branch-merge-nonlinear"
mkdir -p "$repo/docs/plans"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name "Docs Lifecycle Test"
git -C "$repo" config commit.gpgSign false
write_doc "$repo/docs/current-guide.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Current Guide'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m base
history_base=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" branch side

write_doc "$repo/docs/plans/open.md" \
  '---' \
  'status: active' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Open'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'add open plan'
feature_tip=$(git -C "$repo" rev-parse HEAD)

git -C "$repo" checkout -q side
write_doc "$repo/docs/plans/closed.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Closed' \
  '' \
  'Closed on a side branch.'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'add closed plan'
side_tip=$(git -C "$repo" rev-parse HEAD)

git -C "$repo" checkout -q --detach "$feature_tip"
git -C "$repo" checkout -q "$side_tip" -- docs/plans/closed.md
refresh_index
git -C "$repo" add docs
merge_tree=$(git -C "$repo" write-tree)
merge_commit=$(printf '%s\n' 'merge docs side branch' | git -C "$repo" commit-tree "$merge_tree" -p "$feature_tip" -p "$side_tip")
git -C "$repo" checkout -q "$merge_commit"
assert_success "$VALIDATOR" --repo-root "$repo" --base "$history_base"

repo="$TMPDIR/history-merge-edits-locked-non-first-parent"
mkdir -p "$repo/docs/adr" "$repo/docs/plans"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name "Docs Lifecycle Test"
git -C "$repo" config commit.gpgSign false
write_doc "$repo/docs/current-guide.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Current Guide'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m base
history_base=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" branch side

write_doc "$repo/docs/plans/open.md" \
  '---' \
  'status: active' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Open'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'add open plan'
feature_tip=$(git -C "$repo" rev-parse HEAD)

git -C "$repo" checkout -q side
write_doc "$repo/docs/adr/0001-side-decision.md" \
  '---' \
  'status: accepted' \
  'doc_type: adr' \
  '---' \
  '' \
  '# Side Decision' \
  '' \
  'Accepted on a side branch.'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'add side decision'
side_tip=$(git -C "$repo" rev-parse HEAD)

git -C "$repo" checkout -q --detach "$feature_tip"
git -C "$repo" checkout -q "$side_tip" -- docs/adr/0001-side-decision.md
write_doc "$repo/docs/adr/0001-side-decision.md" \
  '---' \
  'status: accepted' \
  'doc_type: adr' \
  '---' \
  '' \
  '# Side Decision' \
  '' \
  'Edited in merge resolution.'
refresh_index
git -C "$repo" add docs
merge_tree=$(git -C "$repo" write-tree)
merge_commit=$(printf '%s\n' 'merge side decision badly' | git -C "$repo" commit-tree "$merge_tree" -p "$feature_tip" -p "$side_tip")
git -C "$repo" checkout -q "$merge_commit"
assert_failure_matching "body edits are blocked" "$VALIDATOR" --repo-root "$repo" --base "$history_base"

repo="$TMPDIR/history-intermediate-rename-before-close"
mkdir -p "$repo/docs/plans" "$repo/docs/references" "$repo/docs/runbooks"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name "Docs Lifecycle Test"
git -C "$repo" config commit.gpgSign false
write_doc "$repo/docs/current-guide.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Current Guide'
write_doc "$repo/docs/plans/foo.md" \
  '---' \
  'status: active' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Foo' \
  '' \
  'Original body.'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m base
history_base=$(git -C "$repo" rev-parse HEAD)

git -C "$repo" mv docs/plans/foo.md docs/references/foo.md
write_doc "$repo/docs/references/foo.md" \
  '---' \
  'status: active' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Foo' \
  '' \
  'Edited while open.'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'move and edit while open'

git -C "$repo" mv docs/references/foo.md docs/runbooks/foo.md
write_doc "$repo/docs/runbooks/foo.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Foo' \
  '' \
  'Edited while open.'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'close after intermediate rename'
assert_success "$VALIDATOR" --repo-root "$repo" --base "$history_base"

repo="$TMPDIR/history-push-merge-validates-merge-commit"
mkdir -p "$repo/docs/adr"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name "Docs Lifecycle Test"
git -C "$repo" config commit.gpgSign false
write_doc "$repo/docs/adr/0001-decision.md" \
  '---' \
  'status: accepted' \
  'doc_type: adr' \
  '---' \
  '' \
  '# Decision' \
  '' \
  'Accepted body.'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m base
git -C "$repo" branch feature

write_doc "$repo/docs/current-guide.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Current Guide'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'advance first parent'
push_before=$(git -C "$repo" rev-parse HEAD)

git -C "$repo" checkout -q feature
write_doc "$repo/docs/plans/feature-plan.md" \
  '---' \
  'status: active' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Feature Plan'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'add feature docs'
feature_tip=$(git -C "$repo" rev-parse HEAD)

git -C "$repo" checkout -q --detach "$push_before"
git -C "$repo" checkout -q "$feature_tip" -- docs/plans/feature-plan.md
write_doc "$repo/docs/adr/0001-decision.md" \
  '---' \
  'status: accepted' \
  'doc_type: adr' \
  '---' \
  '' \
  '# Decision' \
  '' \
  'Edited in merge resolution.'
refresh_index
git -C "$repo" add docs
merge_tree=$(git -C "$repo" write-tree)
merge_commit=$(printf '%s\n' 'push merge with bad resolution' | git -C "$repo" commit-tree "$merge_tree" -p "$push_before" -p "$feature_tip")
git -C "$repo" checkout -q "$merge_commit"
assert_failure_matching "body edits are blocked" "$VALIDATOR" --repo-root "$repo" --base "$push_before"

repo="$TMPDIR/history-feature-merge-base-validates-merge-commit"
mkdir -p "$repo/docs/plans"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name "Docs Lifecycle Test"
git -C "$repo" config commit.gpgSign false
write_doc "$repo/docs/current-guide.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Current Guide'
write_doc "$repo/docs/plans/base-plan.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Base Plan' \
  '' \
  'Historical body.'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m base
git -C "$repo" branch feature

write_doc "$repo/docs/plans/master-plan.md" \
  '---' \
  'status: active' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Master Plan'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'advance base'
advanced_base=$(git -C "$repo" rev-parse HEAD)

git -C "$repo" checkout -q feature
write_doc "$repo/docs/plans/feature-plan.md" \
  '---' \
  'status: active' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Feature Plan'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'add feature plan'
feature_tip=$(git -C "$repo" rev-parse HEAD)

git -C "$repo" checkout -q --detach "$feature_tip"
git -C "$repo" checkout -q "$advanced_base" -- docs/plans/master-plan.md
write_doc "$repo/docs/plans/base-plan.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Base Plan' \
  '' \
  'Edited in feature merge resolution.'
refresh_index
git -C "$repo" add docs
merge_tree=$(git -C "$repo" write-tree)
merge_commit=$(printf '%s\n' 'feature merges advanced base badly' | git -C "$repo" commit-tree "$merge_tree" -p "$feature_tip" -p "$advanced_base")
git -C "$repo" checkout -q "$merge_commit"
assert_failure_matching "body edits are blocked" "$VALIDATOR" --repo-root "$repo" --base "$advanced_base"

repo="$TMPDIR/history-close-rename-hidden"
mkdir -p "$repo/docs/plans"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name "Docs Lifecycle Test"
git -C "$repo" config commit.gpgSign false
write_doc "$repo/docs/current-guide.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Current Guide'
write_doc "$repo/docs/plans/old-name.md" \
  '---' \
  'status: active' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Old Name' \
  '' \
  'Original body.'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m base
history_base=$(git -C "$repo" rev-parse HEAD)

rm "$repo/docs/plans/old-name.md"
write_doc "$repo/docs/plans/new-name.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# New Name' \
  '' \
  'Edited while closing.'
refresh_index
assert_failure_matching "closed doc added while deleting open doc" "$VALIDATOR" --repo-root "$repo" --base "$history_base"
git -C "$repo" add docs
git -C "$repo" commit -q -m 'hide close behind rename'
assert_failure_matching "closed doc added while deleting open doc" "$VALIDATOR" --repo-root "$repo" --base "$history_base"

repo="$TMPDIR/history-broken-link-fixed"
mkdir -p "$repo/docs/plans"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name "Docs Lifecycle Test"
git -C "$repo" config commit.gpgSign false
write_doc "$repo/docs/current-guide.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Current Guide'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m base
history_base=$(git -C "$repo" rev-parse HEAD)

write_doc "$repo/docs/plans/broken-link.md" \
  '---' \
  'status: active' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Broken Link' \
  '' \
  'See [missing](missing.md).'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'add broken link'

write_doc "$repo/docs/plans/missing.md" \
  '---' \
  'status: active' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Missing'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'add missing target'
assert_failure_matching "Markdown link target must exist: missing.md" "$VALIDATOR" --repo-root "$repo" --base "$history_base"

repo="$TMPDIR/history-bad-guidance-fixed"
mkdir -p "$repo/docs/plans"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name "Docs Lifecycle Test"
git -C "$repo" config commit.gpgSign false
write_doc "$repo/docs/current-guide.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Current Guide'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m base
history_base=$(git -C "$repo" rev-parse HEAD)

write_doc "$repo/docs/plans/bad-guidance.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: missing.md' \
  '---' \
  '' \
  '# Bad Guidance'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'add bad guidance'

write_doc "$repo/docs/plans/bad-guidance.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Bad Guidance'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'fix guidance'
assert_failure_matching "current_guidance target must be a repo-local relative path that exists: missing.md" "$VALIDATOR" --repo-root "$repo" --base "$history_base"

repo="$TMPDIR/history-created-archived-edit"
mkdir -p "$repo/docs/plans"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name "Docs Lifecycle Test"
git -C "$repo" config commit.gpgSign false
write_doc "$repo/docs/current-guide.md" \
  '---' \
  'status: current' \
  'doc_type: reference' \
  '---' \
  '' \
  '# Current Guide'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m base
history_base=$(git -C "$repo" rev-parse HEAD)

write_doc "$repo/docs/plans/branch-archived.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Branch Archived' \
  '' \
  'Archived body.'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'add archived plan'

write_doc "$repo/docs/plans/branch-archived.md" \
  '---' \
  'status: archived' \
  'doc_type: plan' \
  'closed: 2026-05-11' \
  'current_guidance: ../current-guide.md' \
  '---' \
  '' \
  '# Branch Archived' \
  '' \
  'Edited archived body.'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'edit archived plan body'
assert_failure_matching "body edits are blocked" "$VALIDATOR" --repo-root "$repo" --base "$history_base"

repo="$TMPDIR/history-duplicate-body-delete"
mkdir -p "$repo/docs/adr"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name "Docs Lifecycle Test"
git -C "$repo" config commit.gpgSign false
write_doc "$repo/docs/adr/0001-decision.md" \
  '---' \
  'status: accepted' \
  'doc_type: adr' \
  '---' \
  '' \
  '# Decision' \
  '' \
  'Shared body.'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m base
history_base=$(git -C "$repo" rev-parse HEAD)

rm "$repo/docs/adr/0001-decision.md"
write_doc "$repo/docs/adr/0002-unrelated.md" \
  '---' \
  'status: accepted' \
  'doc_type: adr' \
  '---' \
  '' \
  '# Unrelated' \
  '' \
  'Shared body.'
refresh_index
git -C "$repo" add docs
git -C "$repo" commit -q -m 'replace with unrelated duplicate body'
assert_failure_matching "locked historical doc cannot be deleted" "$VALIDATOR" --repo-root "$repo" --base "$history_base"

repo="$main_repo"

print -- "docs lifecycle tests passed"
