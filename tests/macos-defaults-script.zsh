#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true

die() {
  print -u2 -- "macos-defaults-script: $*"
  exit 1
}

assert_not_contains_file() {
  local file="$1"
  local needle="$2"
  if grep -Fqx -- "$needle" "$file"; then
    die "unexpected log line: $needle"
  fi
}

assert_contains_file() {
  local file="$1"
  local needle="$2"
  if ! grep -Fqx -- "$needle" "$file"; then
    die "missing log line: $needle"
  fi
}

DOTFILES_ROOT="${0:A:h:h}"
chezmoi_bin="$(command -v chezmoi)"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

stub_bin="$tmp_root/bin"
home_dir="$tmp_root/home"
state_dir="$tmp_root/state"
mkdir -p "$stub_bin" "$home_dir/Library/Preferences" "$state_dir"

log_file="$tmp_root/commands.log"
: > "$log_file"
export MACOS_DEFAULTS_TEST_LOG="$log_file"

cat >"$stub_bin/defaults" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'defaults %s\n' "$*" >> "$MACOS_DEFAULTS_TEST_LOG"
if [ "${1:-}" = "import" ]; then
  exit 0
fi
if [ "${1:-}" = "read" ]; then
  if [ "$#" -eq 2 ]; then
    printf '%s\n' "${MACOS_DEFAULTS_TEST_UNRELATED_SNAPSHOT:-stable}"
  else
    printf '%s\n' "${MACOS_DEFAULTS_TEST_SNAPSHOT:-stable}"
  fi
  exit 0
fi
if [ "${1:-}" = "-currentHost" ] && [ "${2:-}" = "read" ]; then
  printf '%s\n' "${MACOS_DEFAULTS_TEST_SNAPSHOT:-stable}"
  exit 0
fi
exit 0
EOF
chmod +x "$stub_bin/defaults"

for command in osascript systemsetup pmset launchctl chflags mdutil nvram; do
  cat >"$stub_bin/$command" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s %s\n' "$(basename "$0")" "$*" >> "$MACOS_DEFAULTS_TEST_LOG"
exit 0
EOF
  chmod +x "$stub_bin/$command"
done

cat >"$stub_bin/uname" <<'EOF'
#!/usr/bin/env bash
printf 'Darwin\n'
EOF
chmod +x "$stub_bin/uname"

cat >"$stub_bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'sudo %s\n' "$*" >> "$MACOS_DEFAULTS_TEST_LOG"
case "$*" in
  "-v"|"-n true")
    exit 42
    ;;
esac
exit 0
EOF
chmod +x "$stub_bin/sudo"

cat >"$stub_bin/id" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "-u" ]; then
  printf '0\n'
  exit 0
fi
exec /usr/bin/id "$@"
EOF
chmod +x "$stub_bin/id"

cat >"$stub_bin/killall" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'killall %s\n' "$*" >> "$MACOS_DEFAULTS_TEST_LOG"
if [ "${1:-}" = "mds" ]; then
  printf 'No matching processes belonging to you were found\n' >&2
  exit 1
fi
exit 0
EOF
chmod +x "$stub_bin/killall"

cat >"$stub_bin/ls" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'drwx------@ 99 prateek staff hidden %s Jan 1 00:00 %s\n' "${MACOS_DEFAULTS_TEST_LS_SIZE:-1000}" "${@: -1}"
EOF
chmod +x "$stub_bin/ls"

cat >"$home_dir/Library/Preferences/com.apple.symbolichotkeys.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
EOF

power_plist="$tmp_root/power-management.plist"
/usr/libexec/PlistBuddy -c 'Clear dict' "$power_plist" >/dev/null
/usr/libexec/PlistBuddy -c 'Add :"AC Power" dict' "$power_plist"
/usr/libexec/PlistBuddy -c 'Add :"AC Power":"Standby Delay" integer 86400' "$power_plist"
power_hash_before="$(
  PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="$home_dir" \
  MACOS_DEFAULTS_TEST_POWER_MANAGEMENT_PLISTS="$power_plist" \
    "$DOTFILES_ROOT/scripts/macos/defaults-snapshot.sh" payload |
    shasum -a 256 | awk '{print $1}'
)"
/usr/libexec/PlistBuddy -c 'Set :"AC Power":"Standby Delay" 42' "$power_plist"
power_hash_after="$(
  PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  HOME="$home_dir" \
  MACOS_DEFAULTS_TEST_POWER_MANAGEMENT_PLISTS="$power_plist" \
    "$DOTFILES_ROOT/scripts/macos/defaults-snapshot.sh" payload |
    shasum -a 256 | awk '{print $1}'
)"
[[ "$power_hash_before" != "$power_hash_after" ]] || die "power-management standby delay drift should change the snapshot hash"

script="$tmp_root/macos-defaults.sh"
PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
HOME="$home_dir" \
XDG_STATE_HOME="$state_dir" \
"$chezmoi_bin" \
  --source "$DOTFILES_ROOT" \
  --destination "$home_dir" \
  --cache "$tmp_root/cache" \
  --persistent-state "$tmp_root/chezmoi-state.boltdb" \
  --override-data '{"run_install_scripts":true,"apply_macos_defaults":true,"secrets_enabled":false,"install_profile":"full","manage_zinit_external":false}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/.chezmoiscripts/run_onchange_after_30-macos-defaults.sh.tmpl" \
  >"$script"

bash -n "$script" || die "rendered macOS defaults script has invalid syntax"

script_unrelated_render="$tmp_root/macos-defaults-unrelated-render.sh"
PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
HOME="$home_dir" \
XDG_STATE_HOME="$state_dir" \
MACOS_DEFAULTS_TEST_UNRELATED_SNAPSHOT=changed \
"$chezmoi_bin" \
  --source "$DOTFILES_ROOT" \
  --destination "$home_dir" \
  --cache "$tmp_root/cache" \
  --persistent-state "$tmp_root/chezmoi-state.boltdb" \
  --override-data '{"run_install_scripts":true,"apply_macos_defaults":true,"secrets_enabled":false,"install_profile":"full","manage_zinit_external":false}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/.chezmoiscripts/run_onchange_after_30-macos-defaults.sh.tmpl" \
  >"$script_unrelated_render"
if ! cmp -s "$script" "$script_unrelated_render"; then
  die "unrelated defaults data should not change the rendered run_onchange script"
fi

script_unrelated_ls_render="$tmp_root/macos-defaults-unrelated-ls-render.sh"
PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
HOME="$home_dir" \
XDG_STATE_HOME="$state_dir" \
MACOS_DEFAULTS_TEST_LS_SIZE=2000 \
"$chezmoi_bin" \
  --source "$DOTFILES_ROOT" \
  --destination "$home_dir" \
  --cache "$tmp_root/cache" \
  --persistent-state "$tmp_root/chezmoi-state.boltdb" \
  --override-data '{"run_install_scripts":true,"apply_macos_defaults":true,"secrets_enabled":false,"install_profile":"full","manage_zinit_external":false}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/.chezmoiscripts/run_onchange_after_30-macos-defaults.sh.tmpl" \
  >"$script_unrelated_ls_render"
if ! cmp -s "$script" "$script_unrelated_ls_render"; then
  die "unrelated file metadata should not change the rendered run_onchange script"
fi

script_drift_render="$tmp_root/macos-defaults-drift-render.sh"
PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
HOME="$home_dir" \
XDG_STATE_HOME="$state_dir" \
MACOS_DEFAULTS_TEST_SNAPSHOT=changed \
"$chezmoi_bin" \
  --source "$DOTFILES_ROOT" \
  --destination "$home_dir" \
  --cache "$tmp_root/cache" \
  --persistent-state "$tmp_root/chezmoi-state.boltdb" \
  --override-data '{"run_install_scripts":true,"apply_macos_defaults":true,"secrets_enabled":false,"install_profile":"full","manage_zinit_external":false}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/.chezmoiscripts/run_onchange_after_30-macos-defaults.sh.tmpl" \
  >"$script_drift_render"
if ! cmp -s "$script" "$script_drift_render"; then
  die "live macOS state should not change the rendered run_onchange script"
fi

script_force_render="$tmp_root/macos-defaults-force-render.sh"
PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
HOME="$home_dir" \
XDG_STATE_HOME="$state_dir" \
DOTFILES_FORCE_MACOS_DEFAULTS=1 \
"$chezmoi_bin" \
  --source "$DOTFILES_ROOT" \
  --destination "$home_dir" \
  --cache "$tmp_root/cache" \
  --persistent-state "$tmp_root/chezmoi-state.boltdb" \
  --override-data '{"run_install_scripts":true,"apply_macos_defaults":true,"secrets_enabled":false,"install_profile":"full","manage_zinit_external":false}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/.chezmoiscripts/run_onchange_after_30-macos-defaults.sh.tmpl" \
  >"$script_force_render"
if ! cmp -s "$script" "$script_force_render"; then
  die "DOTFILES_FORCE_MACOS_DEFAULTS should not change the rendered run_onchange script"
fi

force_script_empty="$tmp_root/macos-defaults-force-empty.sh"
PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
HOME="$home_dir" \
XDG_STATE_HOME="$state_dir" \
"$chezmoi_bin" \
  --source "$DOTFILES_ROOT" \
  --destination "$home_dir" \
  --cache "$tmp_root/cache" \
  --persistent-state "$tmp_root/chezmoi-state.boltdb" \
  --override-data '{"run_install_scripts":true,"apply_macos_defaults":true,"secrets_enabled":false,"install_profile":"full","manage_zinit_external":false}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/.chezmoiscripts/run_after_29-macos-defaults-force.sh.tmpl" \
  >"$force_script_empty"
[[ ! -s "$force_script_empty" ]] || die "macOS defaults force script should render empty without force"

force_script="$tmp_root/macos-defaults-force.sh"
PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
HOME="$home_dir" \
XDG_STATE_HOME="$state_dir" \
DOTFILES_FORCE_MACOS_DEFAULTS=true \
"$chezmoi_bin" \
  --source "$DOTFILES_ROOT" \
  --destination "$home_dir" \
  --cache "$tmp_root/cache" \
  --persistent-state "$tmp_root/chezmoi-state.boltdb" \
  --override-data '{"run_install_scripts":true,"apply_macos_defaults":true,"secrets_enabled":false,"install_profile":"full","manage_zinit_external":false}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/.chezmoiscripts/run_after_29-macos-defaults-force.sh.tmpl" \
  >"$force_script"
[[ -s "$force_script" ]] || die "truthy DOTFILES_FORCE_MACOS_DEFAULTS should render the force script"
bash -n "$force_script" || die "rendered macOS defaults force script has invalid syntax"

script_force_falsey_render="$tmp_root/macos-defaults-force-falsey-render.sh"
PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
HOME="$home_dir" \
XDG_STATE_HOME="$state_dir" \
DOTFILES_FORCE_MACOS_DEFAULTS=false \
"$chezmoi_bin" \
  --source "$DOTFILES_ROOT" \
  --destination "$home_dir" \
  --cache "$tmp_root/cache" \
  --persistent-state "$tmp_root/chezmoi-state.boltdb" \
  --override-data '{"run_install_scripts":true,"apply_macos_defaults":true,"secrets_enabled":false,"install_profile":"full","manage_zinit_external":false}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/.chezmoiscripts/run_onchange_after_30-macos-defaults.sh.tmpl" \
  >"$script_force_falsey_render"
if ! cmp -s "$script" "$script_force_falsey_render"; then
  die "falsey DOTFILES_FORCE_MACOS_DEFAULTS should not change the rendered run_onchange script"
fi

force_script_falsey="$tmp_root/macos-defaults-force-falsey.sh"
PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
HOME="$home_dir" \
XDG_STATE_HOME="$state_dir" \
DOTFILES_FORCE_MACOS_DEFAULTS=false \
"$chezmoi_bin" \
  --source "$DOTFILES_ROOT" \
  --destination "$home_dir" \
  --cache "$tmp_root/cache" \
  --persistent-state "$tmp_root/chezmoi-state.boltdb" \
  --override-data '{"run_install_scripts":true,"apply_macos_defaults":true,"secrets_enabled":false,"install_profile":"full","manage_zinit_external":false}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/.chezmoiscripts/run_after_29-macos-defaults-force.sh.tmpl" \
  >"$force_script_falsey"
[[ ! -s "$force_script_falsey" ]] || die "falsey DOTFILES_FORCE_MACOS_DEFAULTS should render an empty force script"
assert_not_contains_file "$log_file" "systemsetup -gettimezone"
assert_not_contains_file "$log_file" "systemsetup -getrestartfreeze"
: > "$log_file"

run_out="$tmp_root/macos-defaults-script.out"
PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
HOME="$home_dir" \
XDG_STATE_HOME="$state_dir" \
DOTFILES_SKIP_LSREGISTER=1 \
DOTFILES_SKIP_APP_RESTART=1 \
bash "$script" >"$run_out"

assert_not_contains_file "$log_file" "sudo -v"
assert_not_contains_file "$log_file" "sudo -n true"
assert_not_contains_file "$log_file" "killall -q Activity Monitor Dock Finder Google Chrome Messages Safari SystemUIServer"
assert_contains_file "$log_file" "killall mds"
assert_contains_file "$log_file" "sudo mdutil -i on /"
assert_contains_file "$log_file" "sudo mdutil -E /"

state_file="$state_dir/dotfiles/macos-defaults.state"
[[ -s "$state_file" ]] || die "macOS defaults state stamp was not written"

: > "$log_file"
skip_out="$tmp_root/macos-defaults-script-skip.out"
PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
HOME="$home_dir" \
XDG_STATE_HOME="$state_dir" \
DOTFILES_SKIP_LSREGISTER=1 \
DOTFILES_SKIP_APP_RESTART=1 \
bash "$script" >"$skip_out"

assert_not_contains_file "$log_file" "sudo mdutil -i on /"
assert_not_contains_file "$log_file" "sudo mdutil -E /"
assert_not_contains_file "$log_file" "killall mds"
assert_not_contains_file "$log_file" "defaults write NSGlobalDomain AppleLanguages -array en-GB"
grep -Fq "macOS defaults already applied for this desired state; skipping." "$skip_out" \
  || die "macOS defaults should report a state-stamp skip"

: > "$log_file"
force_out="$tmp_root/macos-defaults-script-force.out"
PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
HOME="$home_dir" \
XDG_STATE_HOME="$state_dir" \
DOTFILES_SKIP_LSREGISTER=1 \
DOTFILES_SKIP_APP_RESTART=1 \
bash "$force_script" >"$force_out"

assert_contains_file "$log_file" "killall mds"
assert_contains_file "$log_file" "sudo mdutil -i on /"
assert_contains_file "$log_file" "sudo mdutil -E /"

: > "$log_file"
drift_out="$tmp_root/macos-defaults-script-drift.out"
PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
HOME="$home_dir" \
XDG_STATE_HOME="$state_dir" \
MACOS_DEFAULTS_TEST_SNAPSHOT=changed \
DOTFILES_SKIP_LSREGISTER=1 \
DOTFILES_SKIP_APP_RESTART=1 \
bash "$script" >"$drift_out"

assert_contains_file "$log_file" "killall mds"
assert_contains_file "$log_file" "sudo mdutil -i on /"
assert_contains_file "$log_file" "sudo mdutil -E /"

print -- "OK macos-defaults-script"
