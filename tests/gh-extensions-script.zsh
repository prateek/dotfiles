#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true

die() {
  print -u2 -- "gh-extensions-script: $*"
  exit 1
}

assert_contains() {
  local got="$1"
  local want="$2"
  [[ "$got" == *"$want"* ]] || die "expected output to contain '$want'; got: $got"
}

assert_not_contains() {
  local got="$1"
  local unwanted="$2"
  [[ "$got" != *"$unwanted"* ]] || die "expected output not to contain '$unwanted'; got: $got"
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

render_script() {
  local out="$1"
  local machine_type="${2:-ci}"
  env -u DOTFILES_MACHINE_TYPE chezmoi \
    --source "$DOTFILES_ROOT" \
    --destination "$tmp_root/home" \
    --cache "$tmp_root/cache" \
    --persistent-state "$tmp_root/state.boltdb" \
    --override-data "{\"run_install_scripts\":true,\"apply_macos_defaults\":false,\"secrets_enabled\":false,\"machine_type\":\"$machine_type\",\"manage_zinit_external\":false}" \
    execute-template \
    --file "$DOTFILES_ROOT/home/.chezmoiscripts/run_onchange_after_12-gh-extensions.sh.tmpl" \
    >"$out"
}

write_gh_stub() {
  local dir="$1"
  local mode="${2:-ok}"
  mkdir -p "$dir"
  cat >"$dir/gh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >>"\$GH_CALLS"
case "$mode" in
  ok) exit 0 ;;
  fail) exit 1 ;;
esac
EOF
  chmod +x "$dir/gh"
}

script="$tmp_root/gh-extensions.sh"
render_script "$script" ci
bash -n "$script" || die "rendered script has invalid syntax"
assert_contains "$(<"$script")" 'enthus-appdev/gh-attach'

# Case 1: gh missing -> warn + exit 0, no installs.
PATH="/usr/bin:/bin" HOME="$tmp_root/home-1" \
  out="$(bash "$script" 2>&1)" \
  || die "script should exit 0 when gh is missing"
assert_contains "$out" 'gh is not installed'

# Case 2: gh present, extension not installed -> install runs.
stubs_2="$tmp_root/stubs-2"
write_gh_stub "$stubs_2" ok
calls_2="$tmp_root/calls-2.log"
: >"$calls_2"
GH_CALLS="$calls_2" \
PATH="$stubs_2:/usr/bin:/bin" \
HOME="$tmp_root/home-2" \
XDG_DATA_HOME="$tmp_root/home-2/.local/share" \
  bash "$script" >/dev/null
assert_contains "$(<"$calls_2")" 'extension install enthus-appdev/gh-attach'

# Case 3: extension already on disk -> no install call.
stubs_3="$tmp_root/stubs-3"
write_gh_stub "$stubs_3" ok
calls_3="$tmp_root/calls-3.log"
: >"$calls_3"
home_3="$tmp_root/home-3"
mkdir -p "$home_3/.local/share/gh/extensions/gh-attach"
GH_CALLS="$calls_3" \
PATH="$stubs_3:/usr/bin:/bin" \
HOME="$home_3" \
XDG_DATA_HOME="$home_3/.local/share" \
  bash "$script" >/dev/null
assert_not_contains "$(<"$calls_3")" 'extension install'

# Case 4: install failure -> warn but exit 0 (do not abort the apply).
stubs_4="$tmp_root/stubs-4"
write_gh_stub "$stubs_4" fail
calls_4="$tmp_root/calls-4.log"
: >"$calls_4"
GH_CALLS="$calls_4" \
PATH="$stubs_4:/usr/bin:/bin" \
HOME="$tmp_root/home-4" \
XDG_DATA_HOME="$tmp_root/home-4/.local/share" \
  out="$(bash "$script" 2>&1)" \
  || die "script should not abort when an individual extension install fails"
assert_contains "$out" 'gh extension install failed for enthus-appdev/gh-attach'

# Case 5: empty extensions list (a machine type whose groups declare no gh_extensions) is a no-op
# and must not abort under `set -u` — guards the bash 3.2 empty-array idiom.
empty_script="$tmp_root/gh-extensions-empty.sh"
# Strip every entry line so `extensions=(` and `)` are adjacent — a truly empty
# array, not a single empty-string element.
sed '/^  "[^"]*"$/d' "$script" >"$empty_script"
bash -n "$empty_script" || die "empty-list script has invalid syntax"
empty_body="$(<"$empty_script")"
[[ "$empty_body" == *$'extensions=(\n)'* ]] \
  || die "empty-list rendered script should contain a literal empty extensions=() array"
stubs_5="$tmp_root/stubs-5"
write_gh_stub "$stubs_5" ok
calls_5="$tmp_root/calls-5.log"
: >"$calls_5"
GH_CALLS="$calls_5" \
PATH="$stubs_5:/usr/bin:/bin" \
HOME="$tmp_root/home-5" \
XDG_DATA_HOME="$tmp_root/home-5/.local/share" \
  bash "$empty_script" >/dev/null
[[ ! -s "$calls_5" ]] || die "empty extensions list should make no gh calls; got: $(<"$calls_5")"
if [[ -x /bin/bash ]]; then
  GH_CALLS="$calls_5" \
  PATH="$stubs_5:/usr/bin:/bin" \
  HOME="$tmp_root/home-5b" \
  XDG_DATA_HOME="$tmp_root/home-5b/.local/share" \
    /bin/bash "$empty_script" >/dev/null \
    || die "empty-list path must run under macOS system bash 3.2 (/bin/bash)"
fi

print -- "OK gh-extensions-script"
