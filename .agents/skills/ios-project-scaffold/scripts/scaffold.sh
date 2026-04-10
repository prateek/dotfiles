#!/usr/bin/env bash
# Scaffold a new iOS project with ios-project-scaffold conventions.
#
# Copies templates from ../assets/templates/ into the target directory,
# substituting placeholder values for project-specific ones. Non-destructive:
# refuses to overwrite existing files unless --force is passed.
#
# Usage:
#   scaffold.sh --target <dir> --name <AppName> --bundle-id <com.foo.Bar> \
#               --team-id <TEAMID> [--force]
#
# After running, follow README.bootstrap.md in the target directory for
# the one-time manual steps (ASC app record, ASC API key, CI secrets).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE_DIR="${SKILL_DIR}/assets/templates"

TARGET=""
APP_NAME=""
BUNDLE_ID=""
TEAM_ID=""
FORCE=0

usage() {
  sed -n '2,14p' "$0"
  exit "${1:-1}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)    TARGET="$2"; shift 2 ;;
    --name)      APP_NAME="$2"; shift 2 ;;
    --bundle-id) BUNDLE_ID="$2"; shift 2 ;;
    --team-id)   TEAM_ID="$2"; shift 2 ;;
    --force)     FORCE=1; shift ;;
    -h|--help)   usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage 1 ;;
  esac
done

[[ -n "$TARGET" && -n "$APP_NAME" && -n "$BUNDLE_ID" && -n "$TEAM_ID" ]] || usage 1

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

copy_template "xcode-version"    ".xcode-version"
copy_template "ios-runtime"      ".ios-runtime"
copy_template "tuist-version"    ".tuist-version"
copy_template "mise.toml"        "mise.toml"
copy_template "gitignore"        ".gitignore"
copy_template "Makefile"         "Makefile"
copy_template "Project.swift.example" "Project.swift"
copy_template "devices.yaml"     ".audit/devices.yaml"
copy_template "fastlane/Fastfile"    "fastlane/Fastfile"
copy_template "fastlane/Appfile"     "fastlane/Appfile"
copy_template "fastlane/.env.example" "fastlane/.env.example"
copy_template "github-workflows/build.yml"       ".github/workflows/build.yml"
copy_template "github-workflows/testflight.yml"  ".github/workflows/testflight.yml"
copy_template "README.bootstrap.md" "README.bootstrap.md"

# Substitute placeholders in copied files. Uses perl -pi (portable across
# macOS BSD and Linux GNU) because macOS BSD sed does not honor \b word
# boundaries. Order matters: longer/more-specific patterns must run before
# shorter/more-general ones.
substitute() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  perl -pi -e "
    s|com\\.example\\.MyApp|${BUNDLE_ID}|g;
    s|MyApp\\.xcworkspace|${APP_NAME}.xcworkspace|g;
    s|MyApp\\.app|${APP_NAME}.app|g;
    s|MyAppUITests|${APP_NAME}UITests|g;
    s|MyAppTests|${APP_NAME}Tests|g;
    s|ABCD123456|${TEAM_ID}|g;
    s|\\bMyApp\\b|${APP_NAME}|g;
  " "$file"
}

for f in \
    "Makefile" \
    "Project.swift" \
    "fastlane/Fastfile" \
    "fastlane/Appfile" \
    "fastlane/.env.example" \
    ".github/workflows/build.yml" \
    ".github/workflows/testflight.yml" \
    "README.bootstrap.md"; do
  substitute "${TARGET}/${f}"
done

# Initial source directories so tuist generate has something to find.
mkdir -p "${TARGET}/Sources" "${TARGET}/Tests" "${TARGET}/Resources"

cat <<'DONE'

Scaffold complete. Next steps:

  1. Read README.bootstrap.md and do the one-time manual steps
     (ASC app record, ASC API key, CI secrets).
  2. git init && git add . && git commit -m "bootstrap"
  3. make check-xcode
  4. make generate
  5. Boot a simulator and write its UDID to .ios-sim-udid
  6. make run

DONE
