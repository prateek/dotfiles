#!/usr/bin/env zsh
#
# Regression tests for retired-package cleanup:
#   - scripts/packages/uninstall-retired-packages against a stubbed brew
#     (present, absent, and bystander packages)
#   - run_onchange_after_08-retired-packages hook rendering
#   - brewfile.tmpl render failure when a retired name is still declared
#     in a selected group

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "retired-packages: $*"
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

# Line-anchored variant: brew subcommands like "uninstall" contain "install"
# as a substring, so unanchored negative checks lie.
assert_no_line_prefix() {
  local haystack="$1" prefix="$2" label="$3"
  if print -r -- "$haystack" | grep -q "^$prefix"; then
    die "$label: did not expect a line starting with '$prefix'"
  fi
}

DOTFILES_ROOT="${0:A:h:h}"
cleaner="$DOTFILES_ROOT/scripts/packages/uninstall-retired-packages"
[[ -x "$cleaner" ]] || die "cleaner missing or not executable: $cleaner"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT
empty_config="$tmp_root/empty-chezmoi.toml"
: >"$empty_config"

stub_bin="$tmp_root/bin"
mkdir -p "$stub_bin"

export BREW_CALLS="$tmp_root/brew-calls.log"
export BREW_FORMULAS="$tmp_root/installed-formulas"
export BREW_CASKS="$tmp_root/installed-casks"

cat >"$stub_bin/brew" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >>"$BREW_CALLS"
case "$*" in
  "list --formula")
    cat "$BREW_FORMULAS" 2>/dev/null || true ;;
  "list --cask")
    cat "$BREW_CASKS" 2>/dev/null || true ;;
esac
EOF
chmod +x "$stub_bin/brew"

run_cleaner() {
  : >"$BREW_CALLS"
  PATH="$stub_bin:/usr/bin:/bin" "$cleaner" --entries-file "$1" >/dev/null
}

entries="$tmp_root/entries"
printf 'gogstub\tformula\n' >"$entries"
printf 'appstub\tcask\n' >>"$entries"

# Retired packages still installed are uninstalled; bystanders are untouched.
printf 'gogstub\nbystander\n' >"$BREW_FORMULAS"
printf 'appstub\n' >"$BREW_CASKS"
run_cleaner "$entries"
calls="$(<"$BREW_CALLS")"
assert_contains "$calls" "uninstall --formula gogstub" "cleanup"
assert_contains "$calls" "uninstall --cask appstub" "cleanup"
assert_not_contains "$calls" "bystander" "cleanup (unlisted package untouched)"

# Already-clean machine: idempotent no-op.
: >"$BREW_FORMULAS"
: >"$BREW_CASKS"
run_cleaner "$entries"
calls="$(<"$BREW_CALLS")"
assert_no_line_prefix "$calls" "uninstall " "steady"

render_hook() {
  chezmoi \
    --source "$DOTFILES_ROOT" \
    --destination "$tmp_root/home" \
    --cache "$tmp_root/cache" \
    --persistent-state "$tmp_root/chezmoi-state.boltdb" \
    --config "$empty_config" \
    --override-data "$1" \
    execute-template \
    --file "$DOTFILES_ROOT/home/.chezmoiscripts/run_onchange_after_08-retired-packages.sh.tmpl"
}

override='{
  "machine_type": "personal",
  "machines_local": {"run_install_scripts": true},
  "packages": {"retired": {"brews": [{"name": "gogstub"}], "casks": [{"name": "appstub"}]}}
}'
rendered="$(render_hook "$override")"
assert_contains "$rendered" "scripts/packages/uninstall-retired-packages" "hook"
assert_contains "$rendered" 'printf '\''%s\t%s\n'\'' "gogstub" "formula"' "hook"
assert_contains "$rendered" 'printf '\''%s\t%s\n'\'' "appstub" "cask"' "hook"
# script_lib.sh defines dotfiles_sudo_start in every rendered script, so
# assert on the call's message string, not the function name.
assert_contains "$rendered" 'Removing retired apps may need administrator access' "hook (cask entries prompt for sudo)"

# Formula-only retirements never need sudo.
override_brews='{
  "machine_type": "personal",
  "machines_local": {"run_install_scripts": true},
  "packages": {"retired": {"brews": [{"name": "gogstub"}], "casks": []}}
}'
rendered_brews="$(render_hook "$override_brews")"
assert_contains "$rendered_brews" 'printf '\''%s\t%s\n'\'' "gogstub" "formula"' "hook-brews"
assert_not_contains "$rendered_brews" 'Removing retired apps' "hook-brews (no casks, no sudo)"

# Empty retired list renders to a no-op.
override_empty='{
  "machine_type": "personal",
  "machines_local": {"run_install_scripts": true},
  "packages": {"retired": {"brews": [], "casks": []}}
}'
rendered_empty="$(render_hook "$override_empty")"
assert_contains "$rendered_empty" "skipping" "hook-empty"
assert_not_contains "$rendered_empty" "uninstall-retired-packages --entries-file" "hook-empty"

# Machines without package installs render to a no-op.
override_no_install='{
  "machine_type": "personal",
  "machines_local": {"run_install_scripts": false}
}'
rendered_no_install="$(render_hook "$override_no_install")"
assert_contains "$rendered_no_install" "skipping" "hook-no-install"

# A retired name still declared in a selected group fails the Brewfile render:
# cleanup would uninstall it and bundle would reinstall it on every apply.
override_conflict='{
  "machine_type": "personal",
  "packages": {"retired": {"brews": [{"name": "git"}], "casks": []}}
}'
set +e
guard_out="$(chezmoi \
  --source "$DOTFILES_ROOT" \
  --destination "$tmp_root/home" \
  --cache "$tmp_root/cache" \
  --persistent-state "$tmp_root/chezmoi-state.boltdb" \
  --config "$empty_config" \
  --override-data "$override_conflict" \
  execute-template \
  --file "$DOTFILES_ROOT/home/.chezmoitemplates/brewfile.tmpl" 2>&1)"
guard_rc=$?
set -e
[[ $guard_rc -ne 0 ]] || die "guard: retired name in a selected group should fail the render"
assert_contains "$guard_out" 'retired brew "git" is still declared in a selected group' "guard"

print -- "OK retired-packages"
