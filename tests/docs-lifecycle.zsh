#!/usr/bin/env zsh
set -euo pipefail

ROOT=${0:a:h:h}
VALIDATOR="$ROOT/docs/validate-doc-lifecycle"
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
  'doc_type: reference' \
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

mv "$repo/docs/index.md" "$repo/docs/index.md.bak"
assert_failure_matching "docs root must include index.md" "$VALIDATOR" --repo-root "$repo"
mv "$repo/docs/index.md.bak" "$repo/docs/index.md"

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

write_doc "$repo/docs/plans/link-source.md" \
  '---' \
  'status: current' \
  'doc_type: research' \
  '---' \
  '' \
  '# Link Source' \
  '' \
  'See [Target](target.md).'
write_doc "$repo/docs/plans/target.md" \
  '---' \
  'status: proposed' \
  'doc_type: plan' \
  '---' \
  '' \
  '# Target' \
  '' \
  'Target body.'
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
  'See [Target](../plans/target.md).'
refresh_index
assert_success "$VALIDATOR" --repo-root "$repo" --base HEAD
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
assert_failure "$VALIDATOR" --repo-root "$repo" --base HEAD
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

print -- "docs lifecycle tests passed"
