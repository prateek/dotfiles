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

DOTFILES_ROOT="${0:A:h:h}"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

stub_bin="$tmp_root/bin"
home_dir="$tmp_root/home"
mkdir -p "$stub_bin" "$home_dir/Library/Preferences"

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
exit 0
EOF
chmod +x "$stub_bin/defaults"

for command in osascript systemsetup pmset launchctl chflags mdutil; do
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
exit 0
EOF
chmod +x "$stub_bin/killall"

cat >"$home_dir/Library/Preferences/com.apple.symbolichotkeys.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
EOF

script="$tmp_root/macos-defaults.sh"
chezmoi \
  --source "$DOTFILES_ROOT" \
  --destination "$home_dir" \
  --cache "$tmp_root/cache" \
  --persistent-state "$tmp_root/chezmoi-state.boltdb" \
  --override-data '{"run_install_scripts":true,"apply_macos_defaults":true,"secrets_enabled":false,"install_profile":"full","manage_zinit_external":false}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/.chezmoiscripts/run_onchange_after_30-macos-defaults.sh.tmpl" \
  >"$script"

bash -n "$script" || die "rendered macOS defaults script has invalid syntax"

PATH="$stub_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
HOME="$home_dir" \
DOTFILES_SKIP_LSREGISTER=1 \
DOTFILES_SKIP_REINDEX=1 \
DOTFILES_SKIP_APP_RESTART=1 \
bash "$script" >/tmp/macos-defaults-script.out

assert_not_contains_file "$log_file" "sudo -v"
assert_not_contains_file "$log_file" "sudo -n true"
assert_not_contains_file "$log_file" "killall -q Activity Monitor Dock Finder Google Chrome Messages Safari SystemUIServer"

print -- "OK macos-defaults-script"
