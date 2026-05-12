#!/usr/bin/env bash
# Scaffold a new iOS project with ios-project-scaffold conventions.
#
# Usage:
#   scaffold.sh --target <dir> --name <AppName> --bundle-id <com.foo.Bar> \
#               --team-id <TEAMID> [--with-analysis] [--force]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE_DIR="${SKILL_DIR}/assets/templates"

TARGET=""
APP_NAME=""
BUNDLE_ID=""
TEAM_ID=""
FORCE=0
WITH_ANALYSIS=0

usage() {
  sed -n '2,8p' "$0"
  exit "${1:-1}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --name) APP_NAME="$2"; shift 2 ;;
    --bundle-id) BUNDLE_ID="$2"; shift 2 ;;
    --team-id) TEAM_ID="$2"; shift 2 ;;
    --with-analysis) WITH_ANALYSIS=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage 1 ;;
  esac
done

[[ -n "$TARGET" && -n "$APP_NAME" && -n "$BUNDLE_ID" && -n "$TEAM_ID" ]] || usage 1

APP_SLUG="$(printf '%s' "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
[[ -n "$APP_SLUG" ]] || { echo "error: --name must contain at least one alphanumeric character" >&2; exit 1; }

mkdir -p "$TARGET"
cd "$TARGET"

copy_template() {
  local src_name="$1"
  local dest_name="$2"
  local src="${TEMPLATE_DIR}/${src_name}"
  local dest="${TARGET}/${dest_name}"

  if [[ -e "$dest" && $FORCE -eq 0 ]]; then
    echo "skip: $dest_name already exists (use --force to overwrite)"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  echo "created: $dest_name"
}

copy_template "xcode-version" ".xcode-version"
copy_template "tuist-version" ".tuist-version"
copy_template "mise.toml" "mise.toml"
copy_template "envrc" ".envrc"
copy_template "gitignore" ".gitignore"
copy_template "AGENTS.md" "AGENTS.md"
copy_template "Makefile" "Makefile"
copy_template "swiftlint.yml" ".swiftlint.yml"
copy_template "swiftformat" ".swiftformat"
copy_template "typos.toml" ".typos.toml"
copy_template "githooks/pre-commit" ".githooks/pre-commit"
copy_template "Project.swift.example" "Project.swift"
copy_template "Tuist/Package.swift" "Tuist/Package.swift"
copy_template "TestPlans/README.md" "TestPlans/README.md"
copy_template "TestPlans/App.simprofile.toml" "TestPlans/${APP_NAME}.simprofile.toml"
copy_template "docs/operations/runbooks/worktree-execution.md" "docs/operations/runbooks/worktree-execution.md"
copy_template "scripts/app_worktree.py" "scripts/${APP_SLUG}_worktree.py"
copy_template "scripts/trace_execution.py" "scripts/trace_execution.py"
copy_template "fastlane/Fastfile" "fastlane/Fastfile"
copy_template "fastlane/Appfile" "fastlane/Appfile"
copy_template "fastlane/.env.example" "fastlane/.env.example"
copy_template "github-workflows/ci.yml" ".github/workflows/ci.yml"
copy_template "github-workflows/security.yml" ".github/workflows/security.yml"
copy_template "github-workflows/beta.yml" ".github/workflows/beta.yml"
copy_template "README.bootstrap.md" "README.bootstrap.md"
copy_template "app/App.swift" "${APP_NAME}/App/${APP_NAME}App.swift"
copy_template "app/ContentView.swift" "${APP_NAME}/Home/ContentView.swift"

if [[ $WITH_ANALYSIS -eq 1 ]]; then
  copy_template "periphery.yml" ".periphery.yml"
fi

chmod +x "${TARGET}/.githooks/pre-commit"
chmod +x "${TARGET}/scripts/${APP_SLUG}_worktree.py"
chmod +x "${TARGET}/scripts/trace_execution.py"

substitute() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  perl -0pi -e '
    s/__APP_NAME__/$ENV{APP_NAME}/g;
    s/__APP_SLUG__/$ENV{APP_SLUG}/g;
    s/__BUNDLE_ID__/$ENV{BUNDLE_ID}/g;
    s/__TEAM_ID__/$ENV{TEAM_ID}/g;
  ' "$file"
}

export APP_NAME APP_SLUG BUNDLE_ID TEAM_ID

while IFS= read -r -d '' file; do
  substitute "$file"
done < <(find "$TARGET" -type f \( \
  -name '*.md' -o \
  -name '*.swift' -o \
  -name '*.py' -o \
  -name '*.toml' -o \
  -name '*.yml' -o \
  -name '*.yaml' -o \
  -name '*.rb' -o \
  -name 'Makefile' -o \
  -name '.envrc' -o \
  -name '.env.example' -o \
  -name 'Appfile' \
  \) -print0)

if [[ $WITH_ANALYSIS -eq 1 ]]; then
  perl -0pi -e 's/\n\[env\]/\nperiphery = "3.7.2"\n\n[env]/' "${TARGET}/mise.toml"

  cat >> "${TARGET}/Makefile" <<'EOF'

.PHONY: analyze

analyze: generate
	periphery scan --config .periphery.yml
EOF
fi

mkdir -p \
  "${TARGET}/build/derived" \
  "${TARGET}/build/results" \
  "${TARGET}/build/screenshots" \
  "${TARGET}/build/archives" \
  "${TARGET}/build/exports" \
  "${TARGET}/build/state" \
  "${TARGET}/build/simulators" \
  "${TARGET}/Tests/Unit" \
  "${TARGET}/Tests/UI" \
  "${TARGET}/Tests/Snapshot" \
  "${TARGET}/Tests/Visual" \
  "${TARGET}/TestsSupport"

cat <<'DONE'

Scaffold complete. Next steps:

  1. Read README.bootstrap.md.
  2. git init
  3. make bootstrap-local
  4. make generate
  5. make build
  6. make run-iphone
  7. make test-matrix
  8. git add . && git commit -m "bootstrap"

DONE
