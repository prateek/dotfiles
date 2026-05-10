#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true

die() {
  print -u2 -- "xcode-install-script: $*"
  exit 1
}

assert_contains() {
  local got="$1"
  local want="$2"
  [[ "$got" == *"$want"* ]] || die "expected output to contain '$want'; got: $got"
}

assert_not_contains() {
  local got="$1"
  local bad="$2"
  [[ "$got" != *"$bad"* ]] || die "expected output not to contain '$bad'; got: $got"
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

render_script() {
  local profile="$1"
  local script="$2"
  local install_xcode="${3:-false}"

  chezmoi \
    --source "$DOTFILES_ROOT" \
    --destination "$tmp_root/home" \
    --cache "$tmp_root/cache" \
    --persistent-state "$tmp_root/state.boltdb" \
    --override-data "{\"run_install_scripts\":true,\"apply_macos_defaults\":false,\"secrets_enabled\":false,\"install_profile\":\"$profile\",\"install_xcode\":$install_xcode,\"manage_zinit_external\":false}" \
    execute-template \
    --file "$DOTFILES_ROOT/home/.chezmoiscripts/run_onchange_after_15-xcode.sh.tmpl" \
    >"$script"
}

write_stubs() {
  local dir="$1"
  mkdir -p "$dir"

  cat >"$dir/uname" <<'EOF'
#!/usr/bin/env bash
printf 'Darwin\n'
EOF

  cat >"$dir/id" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-u" ]; then
  printf '0\n'
  exit 0
fi
exec /usr/bin/id "$@"
EOF

  cat >"$dir/jq" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '26.3\n'
EOF

  cat >"$dir/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'brew %s\n' "$*" >> "$XCODE_CALLS"
EOF

  cat >"$dir/xcodes" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  "installed 26.3")
    exit 1
    ;;
  "install 26.3 --experimental-unxip")
    printf 'xcodes %s\n' "$*" >> "$XCODE_CALLS"
    ;;
  "select 26.3")
    printf 'xcodes %s\n' "$*" >> "$XCODE_CALLS"
    ;;
  *)
    printf 'unexpected xcodes call: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF

  cat >"$dir/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'sudo %s\n' "$*" >> "$XCODE_CALLS"
EOF

  chmod +x "$dir/uname" "$dir/id" "$dir/jq" "$dir/brew" "$dir/xcodes" "$dir/sudo"
}

core_script="$tmp_root/xcode-core.sh"
render_script core "$core_script"
bash -n "$core_script" || die "rendered core script has invalid syntax"

full_script="$tmp_root/xcode-full.sh"
render_script full "$full_script" true
bash -n "$full_script" || die "rendered full script has invalid syntax"

full_skip_script="$tmp_root/xcode-full-skip.sh"
render_script full "$full_skip_script" false
bash -n "$full_skip_script" || die "rendered full skip script has invalid syntax"

home_dir="$tmp_root/home"
mkdir -p "$home_dir/.agents/state"
cp "$DOTFILES_ROOT/home/dot_agents/state/ios-triple.json" "$home_dir/.agents/state/ios-triple.json"

stubs="$tmp_root/stubs"
write_stubs "$stubs"
skip_calls="$tmp_root/skip-calls.log"
skip_output="$(
  XCODE_CALLS="$skip_calls" PATH="$stubs:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$home_dir" \
    bash "$full_skip_script" 2>&1
)"
assert_contains "$skip_output" "Skipping Xcode download because xcodes requires Apple ID login"
if [ -e "$skip_calls" ]; then
  skip_out="$(<"$skip_calls")"
  assert_not_contains "$skip_out" "xcodes install 26.3"
  assert_not_contains "$skip_out" "brew install facebook/fb/idb-companion"
  assert_not_contains "$skip_out" "brew install swiftlint"
fi

calls="$tmp_root/install-calls.log"
XCODE_CALLS="$calls" PATH="$stubs:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$home_dir" \
  bash "$full_script" >/dev/null

out="$(<"$calls")"
assert_contains "$out" "xcodes install 26.3 --experimental-unxip"
assert_contains "$out" "xcodes select 26.3"
assert_contains "$out" "sudo xcodebuild -license accept"
assert_contains "$out" "sudo xcodebuild -runFirstLaunch"
assert_contains "$out" "brew install facebook/fb/idb-companion"
assert_contains "$out" "brew install swiftlint"

print -- "OK xcode-install-script"
