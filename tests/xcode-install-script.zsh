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

# Empty --config isolates renders from this host's chezmoi config so a local
# [data.machines_local] cannot skew results; machine_type is pinned per render.
empty_config="$tmp_root/empty-chezmoi.toml"
: >"$empty_config"

render_script() {
  local machine_type="$1"
  local script="$2"

  chezmoi \
    --source "$DOTFILES_ROOT" \
    --config "$empty_config" \
    --destination "$tmp_root/home" \
    --cache "$tmp_root/cache" \
    --persistent-state "$tmp_root/state.boltdb" \
    --override-data "{\"machine_type\":\"$machine_type\",\"machines_local\":{\"run_install_scripts\":true}}" \
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

  # Return the pinned version for .xcode_version; empty for .xcode_version_min so
  # the (optional) minimum path stays inactive in this fixture.
  cat >"$dir/jq" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  *xcode_version_min*) printf '\n' ;;
  *xcode_version*) printf '26.3\n' ;;
  *) exec /usr/bin/jq "$@" ;;
esac
EOF

  cat >"$dir/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'brew %s\n' "$*" >> "$XCODE_CALLS"
EOF

  # XCODE_PRESENT=1 makes the pinned version report as already installed.
  cat >"$dir/xcodes" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  "installed 26.3")
    [ "${XCODE_PRESENT:-0}" = "1" ] && exit 0 || exit 1
    ;;
  "install 26.3 --experimental-unxip"|"select 26.3")
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

home_dir="$tmp_root/home"
mkdir -p "$home_dir/.agents/state"
cp "$DOTFILES_ROOT/home/dot_agents/state/ios-triple.json" "$home_dir/.agents/state/ios-triple.json"

stubs="$tmp_root/stubs"
write_stubs "$stubs"
base_path="$stubs:/usr/bin:/bin:/usr/sbin:/sbin"

# ci has no dev-apple group: render, syntax-check, and confirm it skips cleanly.
ci_script="$tmp_root/xcode-ci.sh"
render_script ci "$ci_script"
bash -n "$ci_script" || die "rendered ci script has invalid syntax"
ci_out="$(XCODE_CALLS=/dev/null PATH="$base_path" HOME="$home_dir" bash "$ci_script" </dev/null 2>&1)"
assert_contains "$ci_out" "no dev-apple group"

personal_script="$tmp_root/xcode-personal.sh"
render_script personal "$personal_script"
bash -n "$personal_script" || die "rendered personal script has invalid syntax"

# Absent Xcode + non-interactive + not forced -> fail loudly, no download.
fail_calls="$tmp_root/fail-calls.log"; : >"$fail_calls"
set +e
fail_out="$(XCODE_CALLS="$fail_calls" PATH="$base_path" HOME="$home_dir" bash "$personal_script" </dev/null 2>&1)"
fail_rc=$?
set -e
[[ $fail_rc -ne 0 ]] || die "expected non-interactive apply without Xcode to fail loudly; got exit 0"
assert_contains "$fail_out" "non-interactive"
assert_not_contains "$(<"$fail_calls")" "xcodes install 26.3"

# Absent Xcode + forced (DOTFILES_INSTALL_XCODE) -> download, select, setup, brews.
calls="$tmp_root/install-calls.log"; : >"$calls"
DOTFILES_INSTALL_XCODE=true XCODE_CALLS="$calls" PATH="$base_path" HOME="$home_dir" \
  bash "$personal_script" </dev/null >/dev/null
out="$(<"$calls")"
assert_contains "$out" "xcodes install 26.3 --experimental-unxip"
assert_contains "$out" "xcodes select 26.3"
assert_contains "$out" "sudo xcodebuild -license accept"
assert_contains "$out" "sudo xcodebuild -runFirstLaunch"
assert_contains "$out" "brew install facebook/fb/idb-companion"
assert_contains "$out" "brew install swiftlint"

# Present Xcode -> no download, just select + setup (check&set is idempotent).
present_calls="$tmp_root/present-calls.log"; : >"$present_calls"
XCODE_PRESENT=1 XCODE_CALLS="$present_calls" PATH="$base_path" HOME="$home_dir" \
  bash "$personal_script" </dev/null >/dev/null
present_out="$(<"$present_calls")"
assert_not_contains "$present_out" "xcodes install 26.3"
assert_contains "$present_out" "xcodes select 26.3"

print -- "OK xcode-install-script"
