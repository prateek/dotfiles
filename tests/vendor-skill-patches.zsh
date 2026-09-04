#!/usr/bin/env zsh
set -euo pipefail

# Local deltas on vendored skills are stored as upstream-shaped git patches and
# re-applied by apply-vendor-patches. This test is the gate that keeps them
# applied: a re-vendor that silently drops one, or a hand-edit that diverges
# from its patch, fails here.

REPO_ROOT="${REPO_ROOT:-${0:A:h:h}}"
APPLY="$REPO_ROOT/.agents/skills/agent-skill-management/scripts/apply-vendor-patches"
PACKAGES="$REPO_ROOT/home/dot_agents/packages"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

fail() { print -u2 "FAIL: $*"; exit 1 }

# --- 1. every committed patch is currently applied to its vendored skill ---
"$APPLY" --check >/dev/null || fail "committed patches are not applied to the vendored tree"

# --- 2. the patches are upstream-shaped, so they can become PRs unmodified ---
# Each must target integrations/<harness>/... paths, not our vendor paths.
found_any=0
for patch in "$PACKAGES"/*/patches/*/**/*.patch(N); do
  found_any=1
  grep -q '^+++ b/integrations/' "$patch" \
    || fail "$patch does not target upstream integrations/ paths"
  grep -q '^+++ b/home/' "$patch" \
    && fail "$patch targets a repo-local path; author it against upstream instead"
done
(( found_any )) || fail "no vendor patches found; this test would silently pass forever"

# --- 3. all patches reapply from pristine upstream content, in order ---
# Reverting only one patch would not catch a later patch that silently depends
# on an earlier one, which is exactly what breaks on a real re-vendor.
work="$tmp_root/repo"
mkdir -p "$work"
cp -R "$REPO_ROOT/home" "$work/home"
cp -R "$REPO_ROOT/.agents" "$work/.agents"
git -C "$work" init -q .
git -C "$work" -c user.email=t@t -c user.name=t add -A
git -C "$work" -c user.email=t@t -c user.name=t commit -qm base

work_packages="$work/home/dot_agents/packages"
apply="$work/.agents/skills/agent-skill-management/scripts/apply-vendor-patches"

# Reverse every patch, newest first, to get back to pristine upstream content.
patches=("${(@f)$(print -l "$PACKAGES"/*/patches/*/**/*.patch(N) | sort -r)}")
(( ${#patches} )) || fail "no patches to reverse"
for patch in $patches; do
  rel="${patch#$PACKAGES/}"
  pkg="${rel%%/*}"
  skill="${${rel#$pkg/patches/}%%/*}"
  vendor_rel="home/dot_agents/packages/$pkg/skills/vendor/$skill"
  target="$(grep -m1 '^+++ b/' "$patch" | sed 's|^+++ b/||')"
  depth=0
  IFS=/ read -rA parts <<<"$target"
  for i in {1..${#parts}}; do
    if [[ "${parts[$i]}" == "$skill" ]]; then depth=$((i + 1)); break; fi
  done
  (( depth > 0 )) || fail "could not derive strip depth for $patch"
  git -C "$work" apply --reverse -p"$depth" --directory="$vendor_rel" "$patch" \
    || fail "could not reverse $rel to reach pristine content"
done

AGENT_SKILL_PACKAGES_ROOT="$work_packages" "$apply" --check \
  --packages-root "$work_packages" >/dev/null 2>&1 \
  && fail "--check passed on a fully reverted tree; the gate does not work"

# --- 3b. the reverted tree really is pristine upstream ---
# Reverting only undoes what the patches describe, so a hand edit outside every
# hunk would survive both the revert and the reapply and slip past the byte
# comparison below. The recorded hash is the independent witness.
for hashfile in "$PACKAGES"/*/patches/*/pristine.sha256(N); do
  skill="$(basename "$(dirname "$hashfile")")"
  pkg="${${hashfile#$PACKAGES/}%%/*}"
  reverted="$work_packages/$pkg/skills/vendor/$skill/SKILL.md"
  [[ -f "$reverted" ]] || fail "no vendored SKILL.md for $skill"
  want="$(cut -d' ' -f1 <"$hashfile")"
  got="$(shasum -a 256 "$reverted" | cut -d' ' -f1)"
  [[ "$want" == "$got" ]] \
    || fail "$skill reverts to $got, not the recorded pristine $want; the tree carries an edit no patch describes"
done

AGENT_SKILL_PACKAGES_ROOT="$work_packages" "$apply" \
  --packages-root "$work_packages" >/dev/null \
  || fail "patches do not reapply cleanly onto pristine upstream content"

AGENT_SKILL_PACKAGES_ROOT="$work_packages" "$apply" --check \
  --packages-root "$work_packages" >/dev/null \
  || fail "--check still failing after a full reapply"

# --- 4. the reapplied tree matches the committed one byte for byte ---
diff -r "$REPO_ROOT/home/dot_agents/packages" "$work_packages" >/dev/null \
  || fail "reapplied tree differs from the committed tree"

echo "ok: vendor skill patches (applied, upstream-shaped, revert reaches recorded pristine, reapply byte-identical)"
