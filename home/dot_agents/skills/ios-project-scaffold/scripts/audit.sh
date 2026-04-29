#!/usr/bin/env bash
# Audit an existing iOS project against ios-project-scaffold conventions.

set -euo pipefail

TARGET="$PWD"
JSON=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
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
    if [[ $JSON -eq 0 ]]; then
      printf "  \033[32m✓\033[0m  %s\n" "$name"
    fi
  else
    FAILS=$((FAILS + 1))
    RESULTS+=("{\"name\":\"$name\",\"status\":\"fail\",\"fix\":\"${fix//\"/\\\"}\"}")
    if [[ $JSON -eq 0 ]]; then
      printf "  \033[31m✗\033[0m  %s\n" "$name"
      [[ -n "$fix" ]] && printf "     fix: %s\n" "$fix"
    fi
  fi
}

file_exists() { [[ -f "$1" ]]; }
grep_present() {
  local pattern="$1"
  local file="$2"
  [[ -f "$file" ]] || return 1
  grep -qE -- "$pattern" "$file"
}
section() {
  if [[ $JSON -eq 0 ]]; then
    printf "\n\033[1m%s\033[0m\n" "$1"
  fi
}

simprofile_file="$(find TestPlans -maxdepth 1 -name '*.simprofile.toml' | head -1)"
worktree_script="$(find scripts -maxdepth 1 -name '*_worktree.py' | head -1)"

section "Core repo contract"
for file in ".xcode-version" ".tuist-version" "mise.toml" ".envrc" "AGENTS.md" "Project.swift" "Makefile" "Tuist/Package.swift" "TestPlans/README.md" "docs/operations/runbooks/worktree-execution.md"; do
  if file_exists "$file"; then
    check "$file present" pass
  else
    check "$file present" fail "add $file from the ios-project-scaffold templates"
  fi
done

if [[ -n "$simprofile_file" && -f "$simprofile_file" ]]; then
  check "simprofile present" pass
else
  check "simprofile present" fail "add TestPlans/<App>.simprofile.toml"
fi

if [[ -n "$worktree_script" && -f "$worktree_script" ]]; then
  check "worktree helper present" pass
else
  check "worktree helper present" fail "add scripts/<app>_worktree.py"
fi

section "Git hygiene"
if file_exists ".gitignore"; then
  check ".gitignore present" pass
else
  check ".gitignore present" fail "copy .gitignore from the scaffold templates"
fi

if file_exists ".gitignore"; then
  for pattern in '^\*\.xcworkspace/' '^\*\.xcodeproj/' '^build/' '^fastlane/\.env$' '^\*\.p8$' '^\*\.p12$' '^\*\.mobileprovision$'; do
    if grep_present "$pattern" .gitignore; then
      check ".gitignore includes $pattern" pass
    else
      check ".gitignore includes $pattern" fail "add pattern $pattern to .gitignore"
    fi
  done

  if grep_present '^\.ios-sim-udid$' .gitignore; then
    check ".gitignore does not rely on .ios-sim-udid" fail "remove .ios-sim-udid; simulators should be helper-owned"
  else
    check ".gitignore does not rely on .ios-sim-udid" pass
  fi
fi

if file_exists ".githooks/pre-commit"; then
  check ".githooks/pre-commit present" pass
else
  check ".githooks/pre-commit present" fail "copy .githooks/pre-commit from the scaffold templates"
fi

if file_exists ".githooks/pre-commit"; then
  if grep_present 'git diff --cached --name-only' .githooks/pre-commit; then
    check "pre-commit scopes itself to staged files" pass
  else
    check "pre-commit scopes itself to staged files" fail "make pre-commit read staged files from git diff --cached"
  fi

  if grep_present 'xcodebuild|simctl|periphery' .githooks/pre-commit; then
    check "pre-commit stays off the slow path" fail "remove xcodebuild, simctl, and periphery from .githooks/pre-commit"
  else
    check "pre-commit stays off the slow path" pass
  fi
fi

section "Makefile and helper"
if file_exists "Makefile"; then
  for target in setup-tools hooks-install bootstrap-local generate build build-iphone build-ipad run-iphone run-ipad \
    test-unit test-unit-iphone test-unit-ipad test-snapshot test-ui test-visual test-matrix trace-matrix \
    doctor-state clean-build clean-simulators reset-simulators clean; do
    if grep_present "^${target}:" Makefile; then
      check "Makefile target: $target" pass
    else
      check "Makefile target: $target" fail "add '$target:' to Makefile"
    fi
  done

  if grep_present 'scripts/.+_worktree\.py' Makefile; then
    check "Makefile routes through the worktree helper" pass
  else
    check "Makefile routes through the worktree helper" fail "use scripts/<app>_worktree.py from Makefile"
  fi

  if grep_present 'WITH_TASK,generate' Makefile || grep_present 'exec --task generate' Makefile; then
    check "generate goes through the helper" pass
  else
    check "generate goes through the helper" fail "run make generate via the helper"
  fi

  if grep_present 'IOS_WORKTREE_SIMULATOR_NAME' Makefile && grep_present 'IOS_WORKTREE_DERIVED_DATA_PATH' Makefile; then
    check "Makefile consumes helper-exported environment" pass
  else
    check "Makefile consumes helper-exported environment" fail "use IOS_WORKTREE_* variables in build and test macros"
  fi

  if grep_present 'xcbeautify' Makefile; then
    check "Makefile pipes builds/tests through xcbeautify" pass
  else
    check "Makefile pipes builds/tests through xcbeautify" fail "pipe tuist/xcode output through xcbeautify"
  fi
fi

if [[ -n "$worktree_script" && -f "$worktree_script" ]]; then
  if grep_present 'tuist", "dump", "project' "$worktree_script"; then
    check "helper infers topology from tuist dump project" pass
  else
    check "helper infers topology from tuist dump project" fail "inspect Tuist topology from the helper"
  fi

  if grep_present 'build/derived|build/results|build/simulators|build/state' "$worktree_script"; then
    check "helper keeps mutable state under build/" pass
  else
    check "helper keeps mutable state under build/" fail "move helper-managed outputs under build/"
  fi

  if [[ -n "$simprofile_file" ]] && grep_present "$(basename "$simprofile_file")" "$worktree_script"; then
    check "helper reads the repo simprofile" pass
  else
    check "helper reads the repo simprofile" fail "load TestPlans/<App>.simprofile.toml from the helper"
  fi
fi

section "Tuist metadata"
if file_exists "Project.swift"; then
  if grep_present 'metadata: \.metadata\(tags:' Project.swift; then
    check "Project.swift declares target metadata tags" pass
  else
    check "Project.swift declares target metadata tags" fail "add metadata tags for app and suite targets"
  fi

  for fragment in ':role:app' ':role:suite' ':suite:' ':runtime-class:' ':device-support:'; do
    if grep_present "$fragment" Project.swift; then
      check "Project.swift includes $fragment tags" pass
    else
      check "Project.swift includes $fragment tags" fail "add $fragment metadata in Project.swift"
    fi
  done
fi

if [[ -n "$simprofile_file" && -f "$simprofile_file" ]]; then
  if grep_present '^\[runtimes\.flexible\]' "$simprofile_file" && grep_present '^\[runtimes\.exact\]' "$simprofile_file"; then
    check "simprofile defines runtime classes" pass
  else
    check "simprofile defines runtime classes" fail "add flexible and exact runtime classes"
  fi

  if grep_present '^\[devices\.iphone\]' "$simprofile_file" && grep_present '^\[devices\.ipad\]' "$simprofile_file"; then
    check "simprofile defines preferred devices" pass
  else
    check "simprofile defines preferred devices" fail "add devices.iphone and devices.ipad sections"
  fi
fi

section "CI workflows"
for workflow in ".github/workflows/ci.yml" ".github/workflows/beta.yml"; do
  if file_exists "$workflow"; then
    check "$workflow present" pass
  else
    check "$workflow present" fail "copy $workflow from the scaffold templates"
  fi
done

if file_exists ".github/workflows/ci.yml"; then
  if grep_present 'cancel-in-progress: true' .github/workflows/ci.yml; then
    check "ci.yml cancels stale runs" pass
  else
    check "ci.yml cancels stale runs" fail "set concurrency.cancel-in-progress: true"
  fi

  if grep_present 'xcode-version: "26\.3"' .github/workflows/ci.yml; then
    check "ci.yml pins Xcode" pass
  else
    check "ci.yml pins Xcode" fail "set up Xcode explicitly in ci.yml"
  fi

  for command in 'make build' 'make test-unit' 'make test-ui'; do
    if grep_present "$command" .github/workflows/ci.yml; then
      check "ci.yml runs $command" pass
    else
      check "ci.yml runs $command" fail "add $command to ci.yml"
    fi
  done
fi

if file_exists ".github/workflows/beta.yml"; then
  if grep_present 'cancel-in-progress: false' .github/workflows/beta.yml; then
    check "beta.yml preserves in-flight releases" pass
  else
    check "beta.yml preserves in-flight releases" fail "set concurrency.cancel-in-progress: false"
  fi

  if grep_present 'environment: beta' .github/workflows/beta.yml; then
    check "beta.yml uses an approval-gated environment" pass
  else
    check "beta.yml uses an approval-gated environment" fail "set environment: beta on the deployment job"
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
