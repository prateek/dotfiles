#!/usr/bin/env bash
# Audit an existing iOS project against ios-project-scaffold conventions.
#
# Walks a deterministic checklist and prints pass/fail per check with a
# concrete fix command for each failure. Exit code is 0 on clean audit,
# 1 if any check failed.
#
# Usage:
#   audit.sh [--target <dir>]           # default target is $PWD
#   audit.sh --target <dir> --json      # JSON output for LLM consumption
#
# This script handles the deterministic half of the audit: file existence,
# gitignore entries, Makefile targets, YAML shape. The judgment half — is
# Project.swift using the Tuist 4 environmentVariables API correctly, are
# Fastlane lanes well-structured, etc. — belongs to the LLM rubric in the
# skill's SKILL.md, which runs as a second pass.

set -euo pipefail

TARGET="$PWD"
JSON=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --json)   JSON=1; shift ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

cd "$TARGET"

FAILS=0
RESULTS=()

# Always returns 0 so callers can `if check ...; then ...` without tripping
# set -e or being mis-parsed by && / || chains.
check() {
  local name="$1"
  local status="$2"
  local fix="${3:-}"
  if [[ "$status" == "pass" ]]; then
    RESULTS+=("{\"name\":\"$name\",\"status\":\"pass\"}")
    [[ $JSON -eq 0 ]] && printf "  \033[32m✓\033[0m  %s\n" "$name"
  else
    FAILS=$((FAILS + 1))
    RESULTS+=("{\"name\":\"$name\",\"status\":\"fail\",\"fix\":\"${fix//\"/\\\"}\"}")
    if [[ $JSON -eq 0 ]]; then
      printf "  \033[31m✗\033[0m  %s\n" "$name"
      [[ -n "$fix" ]] && printf "     fix: %s\n" "$fix"
    fi
  fi
  return 0
}

file_exists() { [[ -f "$1" ]]; }
dir_exists()  { [[ -d "$1" ]]; }

# Escape-safe grep wrapper. Uses -- to terminate flags so patterns starting
# with a dash are handled correctly.
grep_present() {
  local pattern="$1"
  local file="$2"
  [[ -f "$file" ]] || return 1
  grep -qE -- "$pattern" "$file"
}

section() { [[ $JSON -eq 0 ]] && printf "\n\033[1m%s\033[0m\n" "$1" || true; }

# --- Toolchain pins ---
section "Toolchain and versions"
if file_exists ".xcode-version"; then
  check ".xcode-version present" pass
else
  check ".xcode-version present" fail 'echo "26.3" > .xcode-version'
fi

if file_exists ".ios-runtime"; then
  check ".ios-runtime present" pass
else
  check ".ios-runtime present" fail 'echo "iOS 26.2" > .ios-runtime'
fi

if file_exists ".tuist-version"; then
  check ".tuist-version present" pass
else
  check ".tuist-version present" fail 'echo "4.61.2" > .tuist-version'
fi

if file_exists "mise.toml"; then
  check "mise.toml present" pass
else
  check "mise.toml present" fail "copy from ~/.agents/skills/ios-project-scaffold/assets/templates/mise.toml"
fi

# --- Project hygiene ---
section "Project hygiene"
if file_exists ".gitignore"; then
  check ".gitignore present" pass
else
  check ".gitignore present" fail "copy from ~/.agents/skills/ios-project-scaffold/assets/templates/gitignore"
fi

if file_exists ".gitignore"; then
  if grep_present '^\*\.xcworkspace/' .gitignore; then
    check ".gitignore ignores *.xcworkspace/" pass
  else
    check ".gitignore ignores *.xcworkspace/" fail "add '*.xcworkspace/' to .gitignore"
  fi

  if grep_present '^\*\.xcodeproj/' .gitignore; then
    check ".gitignore ignores *.xcodeproj/" pass
  else
    check ".gitignore ignores *.xcodeproj/" fail "add '*.xcodeproj/' to .gitignore"
  fi

  if grep_present '^\.ios-sim-udid$' .gitignore; then
    check ".gitignore ignores .ios-sim-udid" pass
  else
    check ".gitignore ignores .ios-sim-udid" fail "add '.ios-sim-udid' to .gitignore"
  fi

  if grep_present '^fastlane/\.env$' .gitignore; then
    check ".gitignore ignores fastlane/.env" pass
  else
    check ".gitignore ignores fastlane/.env" fail "add 'fastlane/.env' to .gitignore"
  fi

  if grep_present '^\*\.p8$' .gitignore; then
    check ".gitignore ignores *.p8" pass
  else
    check ".gitignore ignores *.p8" fail "add '*.p8' to .gitignore"
  fi

  if grep_present '^\*\.mobileprovision$' .gitignore; then
    check ".gitignore ignores *.mobileprovision" pass
  else
    check ".gitignore ignores *.mobileprovision" fail "add '*.mobileprovision' to .gitignore"
  fi
fi

if file_exists "Project.swift"; then
  check "Project.swift present (Tuist)" pass
else
  check "Project.swift present (Tuist)" fail "run tuist init or copy Project.swift template"
fi

# --- Makefile targets ---
section "Makefile"
if file_exists "Makefile"; then
  check "Makefile present" pass
  for tgt in generate build run test-unit test-ui test audit beta release metadata \
             boot-lease release-lease kill-dev-processes clean-dev-artifacts \
             check-xcode create-app-in-asc; do
    if grep_present "^${tgt}:" Makefile; then
      check "Makefile target: $tgt" pass
    else
      check "Makefile target: $tgt" fail "add '${tgt}:' target; see ~/.agents/skills/ios-project-scaffold/assets/templates/Makefile"
    fi
  done

  if grep_present 'xcbeautify' Makefile; then
    check "Makefile pipes through xcbeautify" pass
  else
    check "Makefile pipes through xcbeautify" fail "pipe 'xcodebuild ... | xcbeautify' in build/test targets"
  fi

  if grep_present 'id=\$\(IOS_SIM_UDID\)' Makefile; then
    check "Makefile pins simulator by UDID" pass
  else
    check "Makefile pins simulator by UDID" fail 'add -destination "id=$(IOS_SIM_UDID)" to XCBUILD_FLAGS'
  fi
else
  check "Makefile present" fail "copy from ~/.agents/skills/ios-project-scaffold/assets/templates/Makefile"
fi

# --- Fastlane ---
section "Fastlane"
if file_exists "fastlane/Fastfile"; then
  check "fastlane/Fastfile present" pass
else
  check "fastlane/Fastfile present" fail "copy fastlane/Fastfile from the scaffold templates"
fi

if file_exists "fastlane/Appfile"; then
  check "fastlane/Appfile present" pass
else
  check "fastlane/Appfile present" fail "copy fastlane/Appfile from the scaffold templates"
fi

if file_exists "fastlane/.env.example"; then
  check "fastlane/.env.example present" pass
else
  check "fastlane/.env.example present" fail "copy fastlane/.env.example from the scaffold templates"
fi

if file_exists "fastlane/Fastfile"; then
  if grep_present 'app_store_connect_api_key' fastlane/Fastfile; then
    check "Fastfile uses ASC API key auth" pass
  else
    check "Fastfile uses ASC API key auth" fail "add an asc_auth lane using app_store_connect_api_key"
  fi

  if grep_present 'upload_to_testflight' fastlane/Fastfile; then
    check "Fastfile has TestFlight upload lane" pass
  else
    check "Fastfile has TestFlight upload lane" fail "add a :beta lane with upload_to_testflight"
  fi
fi

# --- Flow audit placeholder ---
section "UI flow audit"
if dir_exists ".audit"; then
  check ".audit/ directory present" pass
else
  check ".audit/ directory present" fail "mkdir .audit && copy devices.yaml from the scaffold templates"
fi

if file_exists ".audit/devices.yaml"; then
  check ".audit/devices.yaml present" pass
else
  check ".audit/devices.yaml present" fail "copy from ~/.agents/skills/ios-project-scaffold/assets/templates/devices.yaml"
fi

# --- CI workflows ---
section "CI workflows"
if file_exists ".github/workflows/build.yml"; then
  check ".github/workflows/build.yml present" pass
else
  check ".github/workflows/build.yml present" fail "copy from the scaffold templates"
fi

if file_exists ".github/workflows/testflight.yml"; then
  check ".github/workflows/testflight.yml present" pass
else
  check ".github/workflows/testflight.yml present" fail "copy from the scaffold templates"
fi

if file_exists ".github/workflows/build.yml"; then
  if grep_present "timeout-minutes:" .github/workflows/build.yml; then
    check "build.yml sets timeout-minutes" pass
  else
    check "build.yml sets timeout-minutes" fail "add timeout-minutes: 15 to the job"
  fi

  if grep_present "cancel-in-progress: true" .github/workflows/build.yml; then
    check "build.yml cancels stale runs" pass
  else
    check "build.yml cancels stale runs" fail "add concurrency.cancel-in-progress: true"
  fi

  if grep_present "xcode-version: ['\"]26\\.3['\"]" .github/workflows/build.yml; then
    check "build.yml pins Xcode version" pass
  else
    check "build.yml pins Xcode version" fail "add setup-xcode with xcode-version matching .xcode-version"
  fi
fi

# --- Summary ---
if [[ $JSON -eq 1 ]]; then
  if [[ ${#RESULTS[@]} -eq 0 ]]; then
    printf '{"fails":%d,"checks":[]}\n' "$FAILS"
  else
    printf '{"fails":%d,"checks":[%s]}\n' "$FAILS" "$(IFS=,; echo "${RESULTS[*]}")"
  fi
else
  printf "\n"
  if [[ $FAILS -eq 0 ]]; then
    printf "\033[32mAudit clean.\033[0m\n"
  else
    printf "\033[31m%d check(s) failed.\033[0m\n" "$FAILS"
  fi
fi

exit $(( FAILS > 0 ? 1 : 0 ))
