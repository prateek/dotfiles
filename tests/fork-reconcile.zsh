#!/usr/bin/env zsh
#
# Regression tests for the downstream-fork install swap:
#   - scripts/packages/reconcile-fork-installs against a stubbed brew
#     (adopt, steady-state, retire scenarios)
#   - run_onchange_after_09-fork-reconcile hook rendering
#   - brewfile.tmpl subtraction of officials replaced by an active fork

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true
# Deterministic env: the reconciler only sets HOMEBREW_CASK_OPTS for the cask
# install, so an ambient value would leak into the mock's recording of every call.
unset HOMEBREW_CASK_OPTS 2>/dev/null || true

die() {
  print -u2 -- "fork-reconcile: $*"
  exit 1
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  [[ "$haystack" == *"$needle"* ]] || die "$label: expected to find '$needle'"
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  [[ "$haystack" != *"$needle"* ]] || die "$label: did not expect '$needle'"
}

# Line-anchored variants: brew subcommands like "uninstall" contain "install"
# as a substring, so unanchored negative checks lie.
assert_no_line_prefix() {
  local haystack="$1" prefix="$2" label="$3"
  if print -r -- "$haystack" | grep -q "^$prefix"; then
    die "$label: did not expect a line starting with '$prefix'"
  fi
}

assert_line_before() {
  local haystack="$1" first="$2" second="$3" label="$4"
  local first_line second_line
  first_line="$(print -r -- "$haystack" | awk -v needle="$first" '$0 == needle { print NR; exit }')"
  second_line="$(print -r -- "$haystack" | awk -v needle="$second" '$0 == needle { print NR; exit }')"
  [[ -n "$first_line" ]] || die "$label: missing line '$first'"
  [[ -n "$second_line" ]] || die "$label: missing line '$second'"
  (( first_line < second_line )) || die "$label: expected '$first' before '$second'"
}

DOTFILES_ROOT="${0:A:h:h}"
reconciler="$DOTFILES_ROOT/scripts/packages/reconcile-fork-installs"
[[ -x "$reconciler" ]] || die "reconciler missing or not executable: $reconciler"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT
empty_config="$tmp_root/empty-chezmoi.toml"
: >"$empty_config"

stub_bin="$tmp_root/bin"
mkdir -p "$stub_bin"

export BREW_CALLS="$tmp_root/brew-calls.log"
export BREW_FORMULAS="$tmp_root/installed-formulas"
export BREW_CASKS="$tmp_root/installed-casks"
export BREW_TAPS="$tmp_root/tapped"
export BREW_REPO="$tmp_root/brew-repo"
export BREW_OUTDATED="$tmp_root/outdated"
: >"$BREW_OUTDATED"

cat >"$stub_bin/brew" <<'EOF'
#!/bin/sh
set -eu
# Record HOMEBREW_CASK_OPTS alongside argv so the test can assert that
# --no-quarantine is passed through the env (it is no longer a CLI flag).
printf '%s%s\n' "${HOMEBREW_CASK_OPTS:+CASK_OPTS=$HOMEBREW_CASK_OPTS }" "$*" >>"$BREW_CALLS"
case "$1" in
  --repository)
    printf '%s\n' "$BREW_REPO" ;;
  tap)
    if [ $# -eq 1 ]; then cat "$BREW_TAPS" 2>/dev/null || true; fi ;;
  list)
    case "$*" in
      "list --formula")
        cat "$BREW_FORMULAS" 2>/dev/null || true ;;
      "list --cask")
        cat "$BREW_CASKS" 2>/dev/null || true ;;
    esac ;;
  outdated)
    cat "$BREW_OUTDATED" 2>/dev/null || true ;;
  install|uninstall) ;;
esac
EOF
chmod +x "$stub_bin/brew"

run_reconciler() {
  : >"$BREW_CALLS"
  PATH="$stub_bin:/usr/bin:/bin" "$reconciler" --entries-file "$1" >/dev/null
}

# Variant that returns stdout so freshness reports can be asserted.
run_reconciler_out() {
  : >"$BREW_CALLS"
  PATH="$stub_bin:/usr/bin:/bin" "$reconciler" --entries-file "$1"
}

entries="$tmp_root/entries-adopt"
printf 'prateek/forks/forkstub-fork\tformula\tforkstub\n' >"$entries"
printf 'prateek/forks/forkstub-app-fork\tcask\tforkstub-app\n' >>"$entries"
printf 'forkstub\n' >"$BREW_FORMULAS"
printf 'forkstub-app\n' >"$BREW_CASKS"
: >"$BREW_TAPS"

run_reconciler "$entries"
calls="$(<"$BREW_CALLS")"
assert_contains "$calls" "tap prateek/forks" "adopt"
assert_contains "$calls" "tap prateek/forks https://github.com/prateek/forks" "adopt (non-conventional tap gets its URL)"
assert_contains "$calls" "uninstall --formula forkstub" "adopt"
assert_contains "$calls" "install --formula prateek/forks/forkstub-fork" "adopt"
assert_contains "$calls" "uninstall --cask forkstub-app" "adopt"
assert_contains "$calls" "CASK_OPTS=--no-quarantine install --cask prateek/forks/forkstub-app-fork" "adopt"
assert_line_before "$calls" "tap prateek/forks https://github.com/prateek/forks" "install --formula prateek/forks/forkstub-fork" "adopt"
assert_line_before "$calls" "uninstall --formula forkstub" "install --formula prateek/forks/forkstub-fork" "adopt"
assert_line_before "$calls" "uninstall --cask forkstub-app" "CASK_OPTS=--no-quarantine install --cask prateek/forks/forkstub-app-fork" "adopt"

printf 'forkstub-fork\n' >"$BREW_FORMULAS"
printf 'forkstub-app-fork\n' >"$BREW_CASKS"
printf 'prateek/forks\n' >"$BREW_TAPS"

run_reconciler "$entries"
calls="$(<"$BREW_CALLS")"
assert_no_line_prefix "$calls" "install " "steady"
assert_no_line_prefix "$calls" "uninstall " "steady"

# Report-only: an installed fork behind the tap's latest build is flagged with
# an upgrade hint, but the reconciler never upgrades or reinstalls it.
printf 'forkstub-app-fork (20260704.13.1) != 20260705.14.1\n' >"$BREW_OUTDATED"
out="$(run_reconciler_out "$entries")"
calls="$(<"$BREW_CALLS")"
assert_contains "$out" "outdated fork: forkstub-app-fork (20260704.13.1) != 20260705.14.1" "report-only (flags the stale fork)"
assert_contains "$out" "brew upgrade --cask forkstub-app-fork" "report-only (hints the upgrade)"
assert_no_line_prefix "$calls" "install " "report-only (no install)"
assert_no_line_prefix "$calls" "upgrade " "report-only (no upgrade)"
assert_not_contains "$out" "outdated fork: forkstub-fork" "report-only (current fork not flagged)"
: >"$BREW_OUTDATED"

tap_dir="$BREW_REPO/Library/Taps/prateek/homebrew-forks"
mkdir -p "$tap_dir/Formula" "$tap_dir/Casks"
touch "$tap_dir/Formula/forkstub-fork.rb" "$tap_dir/Casks/forkstub-app-fork.rb"
: >"$tmp_root/entries-empty"

run_reconciler "$tmp_root/entries-empty"
calls="$(<"$BREW_CALLS")"
assert_contains "$calls" "uninstall --formula forkstub-fork" "retire"
assert_contains "$calls" "uninstall --cask forkstub-app-fork" "retire"
assert_no_line_prefix "$calls" "install " "retire"

# Unmanaged -fork packages (not from the fork tap) are left alone.
printf 'forkstub-fork\nsomeoneelses-fork\n' >"$BREW_FORMULAS"
run_reconciler "$tmp_root/entries-empty"
calls="$(<"$BREW_CALLS")"
assert_not_contains "$calls" "uninstall --formula someoneelses-fork" "retire-unmanaged"

override='{
  "machine_type": "personal",
  "machines_local": {"run_install_scripts": true},
  "packages": {"groups": {"forks": {"entries": [
    {"name": "prateek/forks/forkstub-app-fork", "kind": "cask", "replaces": "forkstub-app"}
  ]}}}
}'
rendered="$(chezmoi \
  --source "$DOTFILES_ROOT" \
  --destination "$tmp_root/home" \
  --cache "$tmp_root/cache" \
  --persistent-state "$tmp_root/chezmoi-state.boltdb" \
  --config "$empty_config" \
  --override-data "$override" \
  execute-template \
  --file "$DOTFILES_ROOT/home/.chezmoiscripts/run_onchange_after_09-fork-reconcile.sh.tmpl")"
assert_contains "$rendered" "scripts/packages/reconcile-fork-installs" "hook"
assert_contains "$rendered" "prateek/forks/forkstub-app-fork" "hook"
assert_contains "$rendered" 'printf '\''%s\t%s\t%s\n'\'' "prateek/forks/forkstub-app-fork" "cask" "forkstub-app"' "hook"
assert_contains "$rendered" 'dotfiles_sudo_start' "hook (cask entries prompt for sudo)"

# ci machine type does not include the forks group: hook renders to a no-op.
rendered_ci="$(chezmoi \
  --source "$DOTFILES_ROOT" \
  --destination "$tmp_root/home" \
  --cache "$tmp_root/cache" \
  --persistent-state "$tmp_root/chezmoi-state.boltdb" \
  --config "$empty_config" \
  --override-data '{"machine_type": "ci"}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/.chezmoiscripts/run_onchange_after_09-fork-reconcile.sh.tmpl")"
assert_contains "$rendered_ci" "skipping" "hook-ci"
assert_not_contains "$rendered_ci" "reconcile-fork-installs --entries-file" "hook-ci"
assert_not_contains "$rendered_ci" 'run_timed "reconcile fork installs"' "hook-ci"
assert_not_contains "$rendered_ci" 'entries_file=' "hook-ci"

override_replaced='{
  "machine_type": "personal",
  "packages": {"groups": {"forks": {"entries": [
    {"name": "prateek/forks/gitleaks-fork", "kind": "formula", "replaces": "gitleaks"}
  ]}}}
}'
brewfile="$(chezmoi \
  --source "$DOTFILES_ROOT" \
  --destination "$tmp_root/home" \
  --cache "$tmp_root/cache" \
  --persistent-state "$tmp_root/chezmoi-state.boltdb" \
  --config "$empty_config" \
  --override-data "$override_replaced" \
  execute-template \
  --file "$DOTFILES_ROOT/home/.chezmoitemplates/brewfile.tmpl")"
assert_not_contains "$brewfile" 'brew "gitleaks"' "brewfile-subtraction"
assert_contains "$brewfile" 'brew "git"' "brewfile-subtraction (unrelated packages intact)"

# With no active forks the Brewfile is unchanged.
brewfile_plain="$(chezmoi \
  --source "$DOTFILES_ROOT" \
  --destination "$tmp_root/home" \
  --cache "$tmp_root/cache" \
  --persistent-state "$tmp_root/chezmoi-state.boltdb" \
  --config "$empty_config" \
  --override-data '{"machine_type": "personal"}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/.chezmoitemplates/brewfile.tmpl")"
assert_contains "$brewfile_plain" 'brew "gitleaks"' "brewfile-plain"

print -- "OK fork-reconcile"
