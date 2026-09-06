load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  template=home/.chezmoiscripts/run_after_21-raycast-extensions.sh.tmpl
  render_template "$template" personal '{"machines_local":{"run_install_scripts":true}}' > "$FIXTURE/install.sh"
  extensions="$HOME/.local/share/raycast-extensions"
  stamps="$XDG_STATE_HOME/dotfiles/raycast-extensions"
  local name dir
  for name in orca-worktree pull-requests; do
    dir="$extensions/$name"
    mkdir -p "$dir/src" "$dir/assets"
    printf '{"name":"%s"}\n' "$name" > "$dir/package.json"
    printf '{"lockfileVersion":3}\n' > "$dir/package-lock.json"
    printf '{}\n' > "$dir/tsconfig.json"
    printf 'export default 1;\n' > "$dir/src/$name.tsx"
    printf 'png\n' > "$dir/assets/$name.png"
  done
  cat > "$FIXTURE/bin/npm" <<'STUB'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$FIXTURE/npm.calls"
if [ "${TEST_NPM_FAIL:-}" = "$1" ]; then exit 1; fi
case "$1" in
  ci)
    while [ "$#" -gt 0 ]; do
      if [ "$1" = --prefix ]; then mkdir -p "$2/node_modules"; fi
      shift
    done ;;
  exec) [ "$*" = 'exec -- ray build --non-interactive' ] ;;
  *) printf 'unexpected npm call: %s\n' "$*" >&2; exit 1 ;;
esac
STUB
  chmod +x "$FIXTURE/bin/npm"
  : > "$FIXTURE/npm.calls"
}

build_extensions() {
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [ -z "$stderr" ]
  [ -s "$stamps/orca-worktree.digest" ]
  [ -s "$stamps/pull-requests.digest" ]
  : > "$FIXTURE/npm.calls"
}

assert_only_rebuilt() {
  local name="$1"
  assert_output --partial "Raycast $name extension rebuilt."
  refute_output --partial 'First-time setup'
  [ -z "$stderr" ]
  printf '%s\n' "ci --omit=dev --prefix $extensions/$name" \
    'exec -- ray build --non-interactive' > "$FIXTURE/expected.calls"
  run -0 cmp "$FIXTURE/expected.calls" "$FIXTURE/npm.calls"
  assert_success
}

@test "Raycast build hook is empty when the machine does not select Raycast" {
  render_template "$template" ci '{"machines_local":{"run_install_scripts":true}}' > "$FIXTURE/ci.sh"
  [ ! -s "$FIXTURE/ci.sh" ]
}

@test "Raycast build hook warns and leaves no build stamps when npm is missing" {
  run_without_reporting_fds 0 env PATH=/usr/bin:/bin "$BASH" "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *'npm is not installed; skipping Raycast extension dependency install.'* ]]
  [ ! -e "$stamps" ]
  [ ! -s "$FIXTURE/npm.calls" ]
}

@test "Raycast builds each new extension once with its registration hint and skips unchanged trees" {
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [ -z "$stderr" ]
  local name
  : > "$FIXTURE/expected.calls"
  for name in orca-worktree pull-requests; do
    assert_output --partial "Raycast $name extension built. First-time setup: register it with Raycast by running 'cd $extensions/$name && npm run dev' once"
    [ -s "$stamps/$name.digest" ]
    printf '%s\n' "ci --omit=dev --prefix $extensions/$name" \
      'exec -- ray build --non-interactive' >> "$FIXTURE/expected.calls"
  done
  run -0 cmp "$FIXTURE/expected.calls" "$FIXTURE/npm.calls"
  assert_success
  : > "$FIXTURE/npm.calls"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  assert_output ''
  [ -z "$stderr" ]
  [ ! -s "$FIXTURE/npm.calls" ]
}

@test "Raycast source-only edits rebuild just the changed extension and advance its stamp" {
  build_extensions
  local before
  before="$(cat "$stamps/pull-requests.digest")"
  printf 'export default 2;\n' > "$extensions/pull-requests/src/pull-requests.tsx"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  assert_only_rebuilt pull-requests
  [ "$(cat "$stamps/pull-requests.digest")" != "$before" ]
}

@test "Raycast includes newly added assets in rebuild detection" {
  build_extensions
  printf 'png\n' > "$extensions/orca-worktree/assets/extra.png"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  assert_only_rebuilt orca-worktree
}

@test "Raycast includes source filenames in rebuild detection" {
  build_extensions
  mv "$extensions/orca-worktree/src/orca-worktree.tsx" "$extensions/orca-worktree/src/renamed.tsx"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  assert_only_rebuilt orca-worktree
}

@test "Raycast restores a missing installed tree even when the source stamp matches" {
  build_extensions
  rmdir "$extensions/orca-worktree/node_modules"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  assert_only_rebuilt orca-worktree
  [ -d "$extensions/orca-worktree/node_modules" ]
}

@test "Raycast dependency and build failures preserve the previous stamp and allow a later retry" {
  build_extensions
  local before
  before="$(cat "$stamps/pull-requests.digest")"
  printf 'export default 3;\n' > "$extensions/pull-requests/src/pull-requests.tsx"
  export TEST_NPM_FAIL=ci
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *"Raycast pull-requests extension dependency install failed; retry with: npm ci --omit=dev --prefix $extensions/pull-requests"* ]]
  [ "$(cat "$stamps/pull-requests.digest")" = "$before" ]
  [ "$(cat "$FIXTURE/npm.calls")" = "ci --omit=dev --prefix $extensions/pull-requests" ]
  export TEST_NPM_FAIL=exec
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *"Raycast pull-requests extension build failed; retry with: cd $extensions/pull-requests && npm exec -- ray build --non-interactive"* ]]
  [ "$(cat "$stamps/pull-requests.digest")" = "$before" ]
  unset TEST_NPM_FAIL
  : > "$FIXTURE/npm.calls"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  assert_only_rebuilt pull-requests
  [ "$(cat "$stamps/pull-requests.digest")" != "$before" ]
}

@test "Raycast warns and skips an extension directory without a lockfile" {
  build_extensions
  mkdir -p "$extensions/scratch"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *"Raycast scratch extension lockfile missing: $extensions/scratch/package-lock.json"* ]]
  [ ! -s "$FIXTURE/npm.calls" ]
  [ ! -e "$stamps/scratch.digest" ]
}

@test "Raycast rebuilds successfully under macOS system Bash" {
  build_extensions
  printf 'export default 4;\n' > "$extensions/pull-requests/src/pull-requests.tsx"
  run_without_reporting_fds 0 /bin/bash "$FIXTURE/install.sh"
  assert_success
  assert_only_rebuilt pull-requests
}
