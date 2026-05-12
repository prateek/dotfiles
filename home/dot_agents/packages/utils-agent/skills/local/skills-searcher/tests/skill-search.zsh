#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "skill-search tests: $*"
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

SKILL_ROOT="${0:A:h:h}"
CLI="$SKILL_ROOT/scripts/skill-search"
REPO_ROOT="$(cd "$SKILL_ROOT/../../../.." && pwd)"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

stub_bin="$tmp_root/bin"
mkdir -p "$stub_bin"
export STUB_LOG="$tmp_root/stub.log"

cat >"$stub_bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log="${STUB_LOG:?}"

if [[ "${1:-}" == "version" ]]; then
  printf 'gh version 9.9.9\n'
  exit 0
fi

if [[ "${1:-}" == "skill" && "${2:-}" == "search" ]]; then
  query="${3:-}"
  printf 'gh-skill\t%s\n' "$query" >>"$log"
  if [[ "${GH_SKILL_RATE_LIMIT:-0}" == "1" ]]; then
    printf 'GitHub API rate limit exceeded. Please wait a minute and try again.\n' >&2
    exit 1
  fi
  cat <<'JSON'
[
  {
    "repo": "owner-high/repo",
    "path": ".agents/skills/chezmoi/SKILL.md",
    "skillName": "chezmoi",
    "namespace": "dotfiles",
    "description": "Chezmoi workflow skill",
    "stars": 50
  }
]
JSON
  exit 0
fi

[[ "${1:-}" == "api" ]] || {
  printf 'unexpected gh invocation: %s\n' "$*" >&2
  exit 1
}
shift

endpoint=""
path_filter=""
for arg in "$@"; do
  case "$arg" in
    rate_limit|/search/code|repos/*)
      endpoint="$arg"
      ;;
    path=*)
      path_filter="${arg#path=}"
      ;;
  esac
done

if [[ "$endpoint" == "rate_limit" ]]; then
  cat <<'JSON'
{"resources":{"search":{"remaining":0,"reset":1893456000}}}
JSON
  exit 0
fi

if [[ "$endpoint" == "/search/code" ]]; then
  printf 'github-code\n' >>"$log"
  if [[ "${GITHUB_CODE_RATE_LIMIT:-0}" == "1" ]]; then
    printf 'gh: API rate limit exceeded for user ID 123 (HTTP 403)\n' >&2
    exit 1
  fi
  cat <<'JSON'
{
  "total_count": 2,
  "items": [
    {
      "repository": {"full_name": "owner-high/repo"},
      "path": ".agents/skills/chezmoi/SKILL.md",
      "html_url": "https://github.test/owner-high/repo/skill"
    },
    {
      "repository": {"full_name": "owner-low/repo"},
      "path": "docs/chezmoi-skill.md",
      "html_url": "https://github.test/owner-low/repo/skill"
    }
  ]
}
JSON
  exit 0
fi

if [[ "$endpoint" =~ ^repos/([^/]+/[^/]+)/commits$ ]]; then
  repo="${BASH_REMATCH[1]}"
  printf 'commits\t%s\t%s\n' "$repo" "$path_filter" >>"$log"
  count=1
  case "$repo:$path_filter" in
    owner-high/repo:.agents/skills/chezmoi/SKILL.md) count=7 ;;
    owner-mid/repo:skills/chezmoi/SKILL.md) count=3 ;;
    owner-low/repo:docs/chezmoi-skill.md) count=1 ;;
    owner-high/repo:) count=70 ;;
    owner-mid/repo:) count=30 ;;
    owner-low/repo:) count=10 ;;
  esac
  if [[ "$count" -gt 1 ]]; then
    printf 'HTTP/2.0 200 OK\r\n'
    printf 'Link: <https://api.github.test/commits?per_page=1&page=%s>; rel="last"\r\n' "$count"
    printf '\r\n'
    printf '[{"sha":"abc"}]\n'
  else
    printf 'HTTP/2.0 200 OK\r\n\r\n[{"sha":"abc"}]\n'
  fi
  exit 0
fi

if [[ "$endpoint" =~ ^repos/([^/]+/[^/]+)$ ]]; then
  repo="${BASH_REMATCH[1]}"
  case "$repo" in
    owner-high/repo) stars=50 ;;
    owner-mid/repo) stars=30 ;;
    owner-low/repo) stars=1 ;;
    *) stars=0 ;;
  esac
  printf '{"stargazers_count":%s}\n' "$stars"
  exit 0
fi

printf 'unexpected gh api endpoint: %s\n' "$endpoint" >&2
exit 1
EOF
chmod +x "$stub_bin/gh"

cat >"$stub_bin/src" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log="${STUB_LOG:?}"

if [[ "${1:-}" == "version" ]]; then
  printf 'Current version: 9.9.9\n'
  exit 0
fi

[[ "${1:-}" == "search" ]] || {
  printf 'unexpected src invocation: %s\n' "$*" >&2
  exit 1
}

query=""
for arg in "$@"; do
  query="$arg"
done
printf 'sourcegraph\t%s\n' "$query" >>"$log"

cat <<'JSON'
{
  "Results": [
    {
      "__typename": "FileMatch",
      "repository": {"name": "github.com/owner-mid/repo"},
      "file": {
        "path": "skills/chezmoi/SKILL.md",
        "commit": {"oid": "deadbeef"},
        "content": "---\nname: chezmoi-sourcegraph\ndescription: Sourcegraph-discovered chezmoi skill\n---\n"
      }
    },
    {
      "__typename": "FileMatch",
      "repository": {"name": "gitlab.com/ignored/repo"},
      "file": {"path": "skills/ignored/SKILL.md", "content": ""}
    }
  ]
}
JSON
EOF
chmod +x "$stub_bin/src"

cat >"$stub_bin/npx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == *"--help"* ]]; then
  printf 'skills help\n'
  exit 0
fi

[[ "$*" == *"skills find"* ]] || {
  printf 'unexpected npx invocation: %s\n' "$*" >&2
  exit 1
}

cat <<'TEXT'
Install with npx skills add <owner/repo@skill>

owner-low/repo@chezmoi-helper 42 installs
└ https://skills.sh/owner-low/repo/chezmoi-helper
TEXT
EOF
chmod +x "$stub_bin/npx"

cat >"$stub_bin/uv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'uv 9.9.9\n'
EOF
chmod +x "$stub_bin/uv"

echo "• skill-search packaged executable is runnable"
[[ -x "$CLI" ]] || die "CLI is not executable: $CLI"
"$CLI" --help >/dev/null
if command -v chezmoi >/dev/null 2>&1 && [[ -f "$REPO_ROOT/home/bin/symlink_skill-search.tmpl" ]]; then
  rendered_symlink="$(chezmoi execute-template <"$REPO_ROOT/home/bin/symlink_skill-search.tmpl")"
  assert_eq "$rendered_symlink" "$REPO_ROOT/home/dot_agents/packages/utils-agent/skills/local/skills-searcher/scripts/skill-search"
fi

run_cli() {
  env PATH="$stub_bin:$PATH" python3 "$CLI" "$@"
}

echo "• skill-search doctor validates each backend"
doctor_output="$(run_cli --json doctor)"
assert_contains "$doctor_output" '"overall": "ok"'
assert_contains "$doctor_output" '"name": "gh-skill"'
assert_contains "$doctor_output" '"name": "sourcegraph"'
assert_contains "$doctor_output" '"name": "npx-skills"'

echo "• skill-search searches all backends, merges duplicates, and sorts by stars"
: >"$STUB_LOG"
search_output="$(run_cli search chezmoi --limit 5 --no-progress)"
assert_eq "$(print -r -- "$search_output" | sed -n '1p')" "sources	stars	installs	file_commits	repo_commits	repo	path	skill_name	namespace	description	url	preview_command	install_command"
assert_eq "$(print -r -- "$search_output" | sed -n '2p' | cut -f6)" "owner-high/repo"
assert_contains "$(print -r -- "$search_output" | sed -n '2p')" "gh-skill,github-code"
assert_eq "$(print -r -- "$search_output" | sed -n '3p' | cut -f6)" "owner-mid/repo"
assert_eq "$(print -r -- "$search_output" | sed -n '4p' | cut -f6)" "owner-low/repo"
stub_log_contents="$(cat "$STUB_LOG")"
assert_contains "$stub_log_contents" "(file:chezmoi OR repo:chezmoi OR content:/(?m)^(name|description):.*chezmoi/)"
owner_high_file_commits="$(
  awk -F '\t' '$1 == "commits" && $2 == "owner-high/repo" && $3 == ".agents/skills/chezmoi/SKILL.md" { count++ } END { print count + 0 }' "$STUB_LOG"
)"
assert_eq "$owner_high_file_commits" "1"

echo "• skill-search supports ascending sort direction"
ascending_output="$(run_cli search chezmoi --limit 5 --sort-by file-commits --direction asc --no-progress --no-header)"
assert_eq "$(print -r -- "$ascending_output" | sed -n '1p' | cut -f6)" "owner-low/repo"
assert_eq "$(print -r -- "$ascending_output" | sed -n '2p' | cut -f6)" "owner-mid/repo"
assert_eq "$(print -r -- "$ascending_output" | sed -n '3p' | cut -f6)" "owner-high/repo"

echo "• skill-search emits structured JSON"
json_output="$(run_cli --json search chezmoi --limit 5 --no-progress)"
assert_contains "$json_output" '"backends"'
assert_contains "$json_output" '"sourcegraph"'
assert_contains "$json_output" '"repo": "owner-high/repo"'

echo "• skill-search progress includes incremental backend results"
progress_stdout="$tmp_root/progress.stdout"
progress_stderr="$tmp_root/progress.stderr"
run_cli search chezmoi --limit 5 --progress >"$progress_stdout" 2>"$progress_stderr"
progress_stderr_contents="$(cat "$progress_stderr")"
assert_contains "$progress_stderr_contents" $'progress	backend	name=gh-skill	status=started'
assert_contains "$progress_stderr_contents" $'result	gh-skill	50'
assert_contains "$progress_stderr_contents" $'progress	enrich-file	repo=owner-high/repo'

echo "• skill-search degrades when GitHub code search is rate-limited"
rate_limited_json="$(env GITHUB_CODE_RATE_LIMIT=1 PATH="$stub_bin:$PATH" python3 "$CLI" --json search chezmoi --limit 5 --no-progress)"
assert_contains "$rate_limited_json" '"github-code"'
assert_contains "$rate_limited_json" '"status": "rate_limited"'
assert_contains "$rate_limited_json" '"repo": "owner-mid/repo"'

echo "• skill-search raw prints backend-native output"
raw_output="$(run_cli raw sourcegraph chezmoi --limit 2)"
assert_contains "$raw_output" '"Results"'
