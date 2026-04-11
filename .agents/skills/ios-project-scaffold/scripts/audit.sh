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
# gitignore entries, Makefile targets, hook shape, and workflow structure.
# The judgment half — is Project.swift using the Tuist 4 environmentVariables
# API correctly, are the Fastlane lanes well-structured, and so on — belongs
# to the rubric in SKILL.md.

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

grep_present() {
  local pattern="$1"
  local file="$2"
  [[ -f "$file" ]] || return 1
  grep -qE -- "$pattern" "$file"
}

grep_absent() {
  local pattern="$1"
  local file="$2"
  [[ -f "$file" ]] || return 1
  ! grep -qE -- "$pattern" "$file"
}

section() { [[ $JSON -eq 0 ]] && printf "\n\033[1m%s\033[0m\n" "$1" || true; }

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

  if grep_present '^\*\.p12$' .gitignore; then
    check ".gitignore ignores *.p12" pass
  else
    check ".gitignore ignores *.p12" fail "add '*.p12' to .gitignore"
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

for config in ".swiftlint.yml" ".swiftformat" ".typos.toml"; do
  if file_exists "$config"; then
    check "$config present" pass
  else
    check "$config present" fail "copy $config from the scaffold templates"
  fi
done

if file_exists ".githooks/pre-commit"; then
  check ".githooks/pre-commit present" pass
else
  check ".githooks/pre-commit present" fail "copy .githooks/pre-commit from the scaffold templates"
fi

if file_exists ".githooks/pre-push"; then
  check ".githooks/pre-push absent" fail "remove .githooks/pre-push; the default scaffold only installs pre-commit"
else
  check ".githooks/pre-push absent" pass
fi

if file_exists ".githooks/pre-commit"; then
  if grep_present 'git diff --cached --name-only' .githooks/pre-commit; then
    check "pre-commit scopes itself to staged files" pass
  else
    check "pre-commit scopes itself to staged files" fail "make pre-commit read staged files from git diff --cached"
  fi

  if grep_absent 'xcodebuild|simctl|periphery' .githooks/pre-commit; then
    check "pre-commit stays on the fast local path" pass
  else
    check "pre-commit stays on the fast local path" fail "remove xcodebuild, simctl, and periphery from .githooks/pre-commit"
  fi
fi

section "Makefile"
if file_exists "Makefile"; then
  check "Makefile present" pass
else
  check "Makefile present" fail "copy from ~/.agents/skills/ios-project-scaffold/assets/templates/Makefile"
fi

if file_exists "Makefile"; then
  for tgt in setup-tools bootstrap-local format lint generate build run test \
             test-unit test-ui beta release metadata boot-lease release-lease \
             hooks-install kill-dev-processes clean-dev-artifacts check-xcode \
             create-app-in-asc; do
    if grep_present "^${tgt}:" Makefile; then
      check "Makefile target: $tgt" pass
    else
      check "Makefile target: $tgt" fail "add '${tgt}:' target; see ~/.agents/skills/ios-project-scaffold/assets/templates/Makefile"
    fi
  done

  if grep_present 'swiftformat --lint' Makefile; then
    check "Makefile lint runs SwiftFormat" pass
  else
    check "Makefile lint runs SwiftFormat" fail "add 'swiftformat --lint .' to the lint target"
  fi

  if grep_present 'swiftlint lint' Makefile; then
    check "Makefile lint runs SwiftLint" pass
  else
    check "Makefile lint runs SwiftLint" fail "add 'swiftlint lint --quiet' to the lint target"
  fi

  if grep_present 'typos ' Makefile; then
    check "Makefile lint runs typos" pass
  else
    check "Makefile lint runs typos" fail "add 'typos .' to the lint target"
  fi

  if grep_present 'core\.hooksPath \.githooks' Makefile; then
    check "Makefile installs repo-owned hooks" pass
  else
    check "Makefile installs repo-owned hooks" fail "set git core.hooksPath to .githooks in hooks-install"
  fi

  if grep_present 'xcbeautify' Makefile; then
    check "Makefile pipes xcodebuild through xcbeautify" pass
  else
    check "Makefile pipes xcodebuild through xcbeautify" fail "pipe 'xcodebuild ... | xcbeautify' in build/test targets"
  fi

  if grep_present 'id=\$\(IOS_SIM_UDID\)' Makefile; then
    check "Makefile pins simulator by UDID" pass
  else
    check "Makefile pins simulator by UDID" fail 'add -destination "id=$(IOS_SIM_UDID)" to XCBUILD_FLAGS'
  fi

  if file_exists ".periphery.yml"; then
    if grep_present '^analyze:' Makefile; then
      check "Makefile target: analyze" pass
    else
      check "Makefile target: analyze" fail "add 'analyze:' when .periphery.yml is present"
    fi

    if grep_present '^periphery = "3\.7\.2"$' mise.toml; then
      check "mise.toml pins periphery in strict mode" pass
    else
      check "mise.toml pins periphery in strict mode" fail "add periphery to the [tools] table in mise.toml"
    fi
  fi
fi

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

section "CI workflows"
if file_exists ".github/workflows/ci.yml"; then
  check ".github/workflows/ci.yml present" pass
else
  check ".github/workflows/ci.yml present" fail "copy from the scaffold templates"
fi

if file_exists ".github/workflows/security.yml"; then
  check ".github/workflows/security.yml present" pass
else
  check ".github/workflows/security.yml present" fail "copy from the scaffold templates"
fi

if file_exists ".github/workflows/testflight.yml"; then
  check ".github/workflows/testflight.yml present" pass
else
  check ".github/workflows/testflight.yml present" fail "copy from the scaffold templates"
fi

if file_exists ".github/workflows/ci.yml"; then
  if grep_present "timeout-minutes:" .github/workflows/ci.yml; then
    check "ci.yml sets timeout-minutes" pass
  else
    check "ci.yml sets timeout-minutes" fail "add timeout-minutes to each job"
  fi

  if grep_present "cancel-in-progress: true" .github/workflows/ci.yml; then
    check "ci.yml cancels stale runs" pass
  else
    check "ci.yml cancels stale runs" fail "add concurrency.cancel-in-progress: true"
  fi

  if grep_present "xcode-version: ['\"]26\\.3['\"]" .github/workflows/ci.yml; then
    check "ci.yml pins Xcode version" pass
  else
    check "ci.yml pins Xcode version" fail "add setup-xcode with xcode-version matching .xcode-version"
  fi

  for cmd in "make lint" "make test-unit" "make test-ui"; do
    if grep_present "$cmd" .github/workflows/ci.yml; then
      check "ci.yml runs $cmd" pass
    else
      check "ci.yml runs $cmd" fail "add '$cmd' to ci.yml"
    fi
  done
fi

if file_exists ".github/workflows/security.yml"; then
  if grep_present "zizmor" .github/workflows/security.yml; then
    check "security.yml runs zizmor" pass
  else
    check "security.yml runs zizmor" fail "add a zizmor step to security.yml"
  fi
fi

if file_exists ".github/workflows/testflight.yml"; then
  if grep_present "environment: testflight" .github/workflows/testflight.yml; then
    check "testflight.yml requires environment approval" pass
  else
    check "testflight.yml requires environment approval" fail "set environment: testflight on the release job"
  fi

  if grep_present "cancel-in-progress: false" .github/workflows/testflight.yml; then
    check "testflight.yml preserves in-flight releases" pass
  else
    check "testflight.yml preserves in-flight releases" fail "set concurrency.cancel-in-progress: false"
  fi
fi

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
