#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "search-github-skills: $*"
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
  print -r -- "$haystack" | grep -Fq -- "$needle" || die "missing text: $needle"
}

assert_rc() {
  local want_rc="$1"
  shift

  set +e
  REPLY="$("$@" 2>&1)"
  local got_rc=$?
  set -e

  [[ "$got_rc" == "$want_rc" ]] || die "expected rc $want_rc, got $got_rc: $REPLY"
}

DOTFILES_ROOT="${0:A:h:h}"
SCRIPT="$DOTFILES_ROOT/scripts/search-github-skills"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

stub_bin="$tmp_root/bin"
mkdir -p "$stub_bin"
export GH_STUB_LOG="$tmp_root/gh.log"

cat >"$stub_bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log="${GH_STUB_LOG:?}"

[[ "${1:-}" == "api" ]] || {
  printf 'unexpected gh invocation: %s\n' "$*" >&2
  exit 1
}
shift

endpoint=""
query=""
file_path=""
per_page=""
page=""

for arg in "$@"; do
  case "$arg" in
    rate_limit)
      endpoint="$arg"
      ;;
    /search/code|repos/*)
      endpoint="$arg"
      ;;
    q=*)
      query="${arg#q=}"
      ;;
    path=*)
      file_path="${arg#path=}"
      ;;
    per_page=*)
      per_page="${arg#per_page=}"
      ;;
    page=*)
      page="${arg#page=}"
      ;;
  esac
done

if [[ "$endpoint" == "rate_limit" ]]; then
  printf '1700000000\n'
  exit 0
fi

if [[ "$endpoint" == "/search/code" ]]; then
  printf 'query\t%s\tper_page=%s\tpage=%s\n' "$query" "$per_page" "$page" >>"$log"
  if [[ "${GH_STUB_RATE_LIMIT:-0}" == "1" ]]; then
    printf 'gh: API rate limit exceeded for user ID 123 (HTTP 403)\n' >&2
    exit 1
  fi
  cat <<'TSV'
owner-low/repo	docs/chezmoi-skill.md	https://example.test/owner-low/repo/skill
owner-high/repo	.skills/plain/SKILL.md	https://example.test/owner-high/repo/skill
owner-mid/repo	skills/chezmoi/SKILL.md	https://example.test/owner-mid/repo/skill
TSV
  exit 0
fi

repo_stars() {
  case "$1" in
    owner-high/repo) printf '50\n' ;;
    owner-mid/repo) printf '30\n' ;;
    owner-low/repo) printf '1\n' ;;
    *) printf '0\n' ;;
  esac
}

commit_total() {
  local repo="$1"
  local path="$2"

  if [[ -n "$path" ]]; then
    case "$repo:$path" in
      owner-high/repo:.skills/plain/SKILL.md) printf '2\n' ;;
      owner-mid/repo:skills/chezmoi/SKILL.md) printf '9\n' ;;
      owner-low/repo:docs/chezmoi-skill.md) printf '1\n' ;;
      *) printf '0\n' ;;
    esac
    return
  fi

  case "$repo" in
    owner-high/repo) printf '20\n' ;;
    owner-mid/repo) printf '10\n' ;;
    owner-low/repo) printf '30\n' ;;
    *) printf '0\n' ;;
  esac
}

emit_commit_response() {
  local count="$1"

  if [[ "$count" -gt 1 ]]; then
    printf 'HTTP/2.0 200 OK\r\n'
    printf 'Link: <https://api.github.test/commits?per_page=1&page=%s>; rel="last"\r\n' "$count"
    printf '\r\n'
    printf '[{"sha":"abc"}]\n'
  elif [[ "$count" -eq 1 ]]; then
    printf 'HTTP/2.0 200 OK\r\n'
    printf '\r\n'
    printf '[{"sha":"abc"}]\n'
  else
    printf 'HTTP/2.0 200 OK\r\n'
    printf '\r\n'
    printf '[]\n'
  fi
}

if [[ "$endpoint" =~ ^repos/([^/]+/[^/]+)/commits$ ]]; then
  repo="${BASH_REMATCH[1]}"
  emit_commit_response "$(commit_total "$repo" "$file_path")"
  exit 0
fi

if [[ "$endpoint" =~ ^repos/([^/]+/[^/]+)$ ]]; then
  repo="${BASH_REMATCH[1]}"
  repo_stars "$repo"
  exit 0
fi

printf 'unexpected gh api endpoint: %s\n' "$endpoint" >&2
exit 1
EOF
chmod +x "$stub_bin/gh"

run_script() {
  env PATH="$stub_bin:$PATH" bash "$SCRIPT" "$@"
}

echo "• search-github-skills sorts by stars descending by default"
desc_output="$(run_script --limit 3)"
assert_eq "$(print -r -- "$desc_output" | sed -n '1p')" "stars	file_commits	repo_commits	repo	file	url"
assert_eq "$(print -r -- "$desc_output" | sed -n '2p' | cut -f4)" "owner-high/repo"
assert_eq "$(print -r -- "$desc_output" | sed -n '3p' | cut -f4)" "owner-mid/repo"
assert_eq "$(print -r -- "$desc_output" | sed -n '4p' | cut -f4)" "owner-low/repo"
gh_log_contents="$(cat "$GH_STUB_LOG")"
assert_contains "$gh_log_contents" "query	chezmoi filename:skill.md in:file,path	per_page=3	page=1"

echo "• search-github-skills bounds the default code-search request"
: >"$GH_STUB_LOG"
default_output="$(run_script --no-header)"
assert_eq "$(print -r -- "$default_output" | wc -l | tr -d ' ')" "3"
gh_log_contents="$(cat "$GH_STUB_LOG")"
assert_contains "$gh_log_contents" "query	chezmoi filename:skill.md in:file,path	per_page=25	page=1"

echo "• search-github-skills accepts sort direction as a CLI argument"
asc_output="$(run_script --sort-by file-commits --direction asc --limit 3 --no-header)"
assert_eq "$(print -r -- "$asc_output" | sed -n '1p' | cut -f4)" "owner-low/repo"
assert_eq "$(print -r -- "$asc_output" | sed -n '2p' | cut -f4)" "owner-high/repo"
assert_eq "$(print -r -- "$asc_output" | sed -n '3p' | cut -f4)" "owner-mid/repo"

echo "• search-github-skills can stream progress and incremental results"
progress_stdout="$tmp_root/progress.stdout"
progress_stderr="$tmp_root/progress.stderr"
run_script --progress --limit 2 >"$progress_stdout" 2>"$progress_stderr"
progress_stdout_contents="$(cat "$progress_stdout")"
progress_stderr_contents="$(cat "$progress_stderr")"
assert_eq "$(print -r -- "$progress_stdout_contents" | sed -n '2p' | cut -f4)" "owner-high/repo"
assert_eq "$(print -r -- "$progress_stdout_contents" | sed -n '3p' | cut -f4)" "owner-low/repo"
assert_contains "$progress_stderr_contents" "progress	search	query=chezmoi filename:skill.md in:file,path	limit=2	sort_by=stars	direction=desc"
assert_contains "$progress_stderr_contents" "progress	enrich	index=1	repo=owner-low/repo	file=docs/chezmoi-skill.md"
assert_contains "$progress_stderr_contents" "result	1	1	30	owner-low/repo	docs/chezmoi-skill.md	https://example.test/owner-low/repo/skill"
assert_contains "$progress_stderr_contents" "progress	sort	rows=2	sort_by=stars	direction=desc"

echo "• search-github-skills rejects invalid options"
assert_rc 2 run_script --direction sideways
assert_contains "$REPLY" "--direction must be asc or desc"
assert_rc 2 run_script --sort-by nope
assert_contains "$REPLY" "--sort-by must be stars, file-commits, or repo-commits"

echo "• search-github-skills reports code-search rate limits clearly"
assert_rc 1 env GH_STUB_RATE_LIMIT=1 PATH="$stub_bin:$PATH" bash "$SCRIPT" --limit 1
assert_contains "$REPLY" "GitHub code search rate limit exceeded"
