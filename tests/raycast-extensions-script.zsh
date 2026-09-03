#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "raycast-extensions-script: $*"
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
tmpl="$DOTFILES_ROOT/home/.chezmoiscripts/run_after_21-raycast-extensions.sh.tmpl"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

# Empty --config isolates renders from this host's chezmoi config so a local
# [data.machines_local] cannot skew results; machine_type is pinned per render.
empty_config="$tmp_root/empty-chezmoi.toml"
: >"$empty_config"

render_script() {
  local out="$1"
  local machine_type="$2"
  chezmoi \
    --source "$DOTFILES_ROOT" \
    --config "$empty_config" \
    --destination "$tmp_root/render-home" \
    --cache "$tmp_root/cache" \
    --persistent-state "$tmp_root/state.boltdb" \
    --override-data "{\"machine_type\":\"$machine_type\",\"machines_local\":{\"run_install_scripts\":true}}" \
    execute-template \
    --file "$tmpl" \
    >"$out"
}

# npm stub: logs every argv, and on `ci` lays down node_modules under --prefix so
# the script's "built tree present" check behaves like a real install.
stub_bin="$tmp_root/bin"
mkdir -p "$stub_bin"
cat >"$stub_bin/npm" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$NPM_CALLS"
if [ "${NPM_FAIL:-}" = "$1" ]; then
  exit 1
fi
if [ "$1" = "ci" ]; then
  prefix=""
  while [ "$#" -gt 0 ]; do
    if [ "$1" = "--prefix" ]; then prefix="$2"; fi
    shift
  done
  mkdir -p "$prefix/node_modules"
fi
STUB
chmod +x "$stub_bin/npm"

home="$tmp_root/home"
extensions="$home/.local/share/raycast-extensions"
state="$home/.local/state"
calls="$tmp_root/npm-calls.log"

seed_extension() {
  local dir="$extensions/$1"
  mkdir -p "$dir/src" "$dir/assets"
  printf '{"name":"%s"}\n' "$1" >"$dir/package.json"
  printf '{"lockfileVersion":3}\n' >"$dir/package-lock.json"
  printf '{}\n' >"$dir/tsconfig.json"
  printf 'export default 1;\n' >"$dir/src/$1.tsx"
  printf 'png\n' >"$dir/assets/$1.png"
}

run_script() {
  : >"$calls"
  NPM_CALLS="$calls" PATH="$stub_bin:/usr/bin:/bin" HOME="$home" XDG_STATE_HOME="$state" \
    "$@" 2>&1
}

script="$tmp_root/raycast-extensions.sh"
render_script "$script" personal
bash -n "$script" || die "rendered script has invalid syntax"

# ci carries no raycast cask, so the gate renders nothing and chezmoi skips the
# empty script entirely (the invariant in tests/chezmoi-script-status.zsh).
ci_script="$tmp_root/raycast-extensions-ci.sh"
render_script "$ci_script" ci
[[ -s "$ci_script" ]] && die "ci render should be empty (gate must skip the build)" || true

# Case 1: npm missing -> warn + exit 0, nothing built.
seed_extension orca-worktree
seed_extension pull-requests
out="$(PATH="/usr/bin:/bin" HOME="$home" XDG_STATE_HOME="$state" bash "$script" 2>&1)" \
  || die "script should exit 0 when npm is missing"
assert_contains "$out" 'npm is not installed'
[[ ! -e "$state/dotfiles/raycast-extensions" ]] || die "no stamp should be written when npm is missing"

# Case 2: fresh machine -> every extension installs and builds, one stamp each,
# and the one-time registration hint names each extension's own directory.
out="$(run_script bash "$script")" || die "first build should exit 0"
for name in orca-worktree pull-requests; do
  assert_contains "$(<"$calls")" "ci --omit=dev --prefix $extensions/$name"
  assert_contains "$(<"$calls")" 'exec -- ray build --non-interactive'
  assert_contains "$out" "Raycast $name extension built. First-time setup: register it with Raycast by running 'cd $extensions/$name && npm run dev' once"
  [[ -s "$state/dotfiles/raycast-extensions/$name.digest" ]] || die "missing stamp for $name"
done
[[ "$(grep -c '^exec -- ray build' "$calls")" == 2 ]] || die "expected exactly two ray builds; got: $(<"$calls")"

# Case 3: nothing changed -> a second apply makes no npm calls.
out="$(run_script bash "$script")" || die "idempotent rerun should exit 0"
[[ ! -s "$calls" ]] || die "unchanged extensions should not rebuild; got: $(<"$calls")"
assert_not_contains "$out" 'extension built'

# Case 4: a source-only edit rebuilds that extension alone, without the
# first-time hint, and moves its stamp.
before="$(<"$state/dotfiles/raycast-extensions/pull-requests.digest")"
printf 'export default 2;\n' >"$extensions/pull-requests/src/pull-requests.tsx"
out="$(run_script bash "$script")" || die "source-change rerun should exit 0"
assert_contains "$(<"$calls")" "ci --omit=dev --prefix $extensions/pull-requests"
assert_not_contains "$(<"$calls")" "prefix $extensions/orca-worktree"
assert_contains "$out" 'Raycast pull-requests extension rebuilt.'
assert_not_contains "$out" 'First-time setup'
[[ "$(<"$state/dotfiles/raycast-extensions/pull-requests.digest")" != "$before" ]] || die "stamp should change with the source"

# Case 5: a new file under assets/ and a renamed source file each count as a change.
printf 'png\n' >"$extensions/orca-worktree/assets/extra.png"
out="$(run_script bash "$script")" || die "asset-add rerun should exit 0"
assert_contains "$(<"$calls")" "prefix $extensions/orca-worktree"
mv "$extensions/orca-worktree/src/orca-worktree.tsx" "$extensions/orca-worktree/src/renamed.tsx"
out="$(run_script bash "$script")" || die "rename rerun should exit 0"
assert_contains "$(<"$calls")" "prefix $extensions/orca-worktree"

# Case 6: a wiped node_modules with a matching stamp rebuilds anyway.
rm -rf "$extensions/orca-worktree/node_modules"
out="$(run_script bash "$script")" || die "wiped-tree rerun should exit 0"
assert_contains "$(<"$calls")" "prefix $extensions/orca-worktree"
assert_not_contains "$(<"$calls")" "prefix $extensions/pull-requests"

# Case 7: install failure -> warn, no stamp update, apply continues (exit 0).
printf 'export default 3;\n' >"$extensions/pull-requests/src/pull-requests.tsx"
stale="$(<"$state/dotfiles/raycast-extensions/pull-requests.digest")"
out="$(NPM_FAIL=ci run_script bash "$script")" || die "install failure must not abort the apply"
assert_contains "$out" "Raycast pull-requests extension dependency install failed; retry with: npm ci --omit=dev --prefix $extensions/pull-requests"
[[ "$(<"$state/dotfiles/raycast-extensions/pull-requests.digest")" == "$stale" ]] || die "failed install must not advance the stamp"
# Build failure likewise leaves the stamp alone so the next apply retries.
out="$(NPM_FAIL=exec run_script bash "$script")" || die "build failure must not abort the apply"
assert_contains "$out" "Raycast pull-requests extension build failed; retry with: cd $extensions/pull-requests && npm exec -- ray build --non-interactive"
[[ "$(<"$state/dotfiles/raycast-extensions/pull-requests.digest")" == "$stale" ]] || die "failed build must not advance the stamp"
out="$(run_script bash "$script")" || die "retry after failure should exit 0"
assert_contains "$out" 'Raycast pull-requests extension rebuilt.'

# Case 8: a directory without a lockfile is warned about and skipped.
mkdir -p "$extensions/scratch"
out="$(run_script bash "$script")" || die "lockfile-less dir should not abort"
assert_contains "$out" "Raycast scratch extension lockfile missing: $extensions/scratch/package-lock.json"
[[ ! -s "$calls" ]] || die "lockfile-less dir should not trigger npm; got: $(<"$calls")"

# Case 9: macOS system bash 3.2 runs the array and nullglob paths.
if [[ -x /bin/bash ]]; then
  printf 'export default 4;\n' >"$extensions/pull-requests/src/pull-requests.tsx"
  out="$(run_script /bin/bash "$script")" || die "script must run under /bin/bash 3.2"
  assert_contains "$out" 'Raycast pull-requests extension rebuilt.'
fi

print -- "OK raycast-extensions-script"
