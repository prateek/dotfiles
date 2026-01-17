#!/usr/bin/env zsh
# vim:syntax=zsh
# vim:filetype=zsh
#
# gh account routing rules.
#
# Inputs:
#   $1 = origin remote URL (may be empty)
#   $2 = repo slug like "owner/repo" (may be empty)
#
# Output:
#   prints a gh username configured in `gh auth status`, e.g. "prateek-oai" or "prateek"
#
# Notes:
# - Prefer matching on SSH host aliases first (`github-openai`, `github-prateek`).
# - For commands outside a git repo, we fall back to matching on the repo slug.
# - Final fallback is the default user.

gh_user_for_context() {
  local origin_url="${1:-}"
  local repo_slug="${2:-}"

  # Work
  case "$origin_url" in
    (*github-openai:*) echo "prateek-oai"; return 0 ;;
  esac
  case "$repo_slug" in
    (openai/*) echo "prateek-oai"; return 0 ;;
    (chronosphereio/chronosphere-openai) echo "prateek-oai"; return 0 ;;
  esac

  # Personal
  case "$origin_url" in
    (*github-prateek:*) echo "prateek"; return 0 ;;
  esac
  case "$repo_slug" in
    (prateek/*) echo "prateek"; return 0 ;;
  esac

  # Default
  echo "prateek"
}
