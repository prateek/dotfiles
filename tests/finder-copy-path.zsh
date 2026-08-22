#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "finder-copy-path: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
workflow="$DOTFILES_ROOT/home/Library/private_Services/Copy Paths.workflow"
info="$workflow/Contents/Info.plist"
document="$workflow/Contents/Resources/document.wflow"

assert_plist_value() {
  local plist="$1" key="$2" expected="$3" actual
  actual="$(plutil -extract "$key" raw -o - "$plist")" \
    || die "cannot read $key from ${plist#$DOTFILES_ROOT/}"
  [[ "$actual" == "$expected" ]] \
    || die "$key: expected '$expected', got '$actual'"
}

for plist in "$info" "$document"; do
  plutil -lint "$plist" >/dev/null || die "invalid plist: ${plist#$DOTFILES_ROOT/}"
done

/System/Library/CoreServices/pbs -read_bundle "$workflow" >/dev/null 2>&1 \
  || die "macOS rejected the Quick Action service declaration"

assert_plist_value "$info" CFBundleIdentifier com.prateek.services.copy-paths
assert_plist_value "$info" NSServices.0.NSMenuItem.default "Copy Paths"
assert_plist_value "$info" NSServices.0.NSRequiredContext.NSApplicationIdentifier com.apple.finder
assert_plist_value "$info" NSServices.0.NSSendFileTypes.0 public.item

assert_plist_value "$document" workflowMetaData.workflowTypeIdentifier com.apple.Automator.servicesMenu
assert_plist_value "$document" workflowMetaData.serviceApplicationBundleID com.apple.finder
assert_plist_value "$document" workflowMetaData.serviceInputTypeIdentifier com.apple.Automator.fileSystemObject
assert_plist_value "$document" workflowMetaData.serviceOutputTypeIdentifier com.apple.Automator.nothing
assert_plist_value "$document" actions.0.action.ActionBundlePath "/System/Library/Automator/Run Shell Script.action"
assert_plist_value "$document" actions.0.action.ActionParameters.inputMethod 1
assert_plist_value "$document" actions.0.action.ActionParameters.shell /bin/zsh

command_text="$(plutil -extract actions.0.action.ActionParameters.COMMAND_STRING raw -o - "$document")"
expected_command=$'printf \'%s\\n\' "$@" | /usr/bin/pbcopy'
[[ "$command_text" == "$expected_command" ]] || die "unexpected shell command"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT
rendered_home="$tmp_root/rendered-home"
mkdir -p "$rendered_home/Library"
DOTFILES_SKIP_PLIST_HOOKS=1 chezmoi --source "$DOTFILES_ROOT" --destination "$rendered_home" \
  apply --no-tty "$rendered_home/Library/Services" >/dev/null \
  || die "cannot render the Quick Action into an isolated home"
services_mode="$(stat -f '%Lp' "$rendered_home/Library/Services")"
[[ "$services_mode" == 700 ]] || die "Services directory mode: expected 700, got $services_mode"

first="$tmp_root/first path.txt"
second="$tmp_root/second [path].txt"
touch "$first" "$second"

test_command="${command_text/\/usr\/bin\/pbcopy/\/bin\/cat}"
actual="$(/bin/zsh -c "$test_command" -- "$first" "$second")"
expected="$first"$'\n'"$second"
[[ "$actual" == "$expected" ]] || die "selected paths were not preserved one per line"

print -- "OK finder-copy-path"
