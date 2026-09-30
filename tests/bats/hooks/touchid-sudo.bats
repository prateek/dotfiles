#!/usr/bin/env bats
load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  scenario="$DOTFILES_ROOT/tests/scenarios/hooks/touchid-sudo.bash"
  hook="home/.chezmoiscripts/run_before_01-touchid-sudo.sh.tmpl"
  export TMPDIR="$FIXTURE/tmp/"
  mkdir -p "$FIXTURE/pam.d" "$TMPDIR"
  printf '%s\n' 'auth include sudo_local' 'auth required pam_opendirectory.so' >"$FIXTURE/pam.d/sudo"
  : >"$FIXTURE/pam_tid.so.2"
  : >"$FIXTURE/sudo.log"
  printf '%s\n' \
    '# Managed by chezmoi (prateek/dotfiles): home/.chezmoitemplates/touchid_sudo.sh' \
    'auth       sufficient     pam_tid.so' >"$FIXTURE/canonical"
  cat >"$FIXTURE/bin/sudo" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FIXTURE/sudo.log"
cmd="$1"
shift
if [ -f "$FIXTURE/fail-command" ] && [ "$cmd" = "$(cat "$FIXTURE/fail-command")" ]; then
  # An interrupted copy must not replace the live configuration.
  if [ "$cmd" = install ]; then printf 'partial\n' >"${!#}"; fi
  printf 'injected %s failure\n' "$cmd" >&2
  exit 1
fi
args=()
owner= group=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) owner="$2"; shift 2 ;;
    -g) group="$2"; shift 2 ;;
    *) args+=("$1"); shift ;;
  esac
done
case "$cmd" in
  install)
    [ "$owner" = "$(id -un)" ] && [ "$group" = "$(id -gn)" ] || {
      printf 'incorrect or missing install ownership\n' >&2
      exit 98
    }
    command install "${args[@]}"
    if [ -f "$FIXTURE/during-install" ]; then bash "$FIXTURE/during-install"; fi
    ;;
  mktemp|mv|rm) exec "$cmd" "${args[@]}" ;;
  *) exit 99 ;;
esac
STUB
  chmod +x "$FIXTURE/bin/sudo"
}

assert_canonical() {
  cmp "$FIXTURE/canonical" "$FIXTURE/pam.d/sudo_local"
  [ ! -L "$FIXTURE/pam.d/sudo_local" ]
  assert_equal "$(stat -f '%Su %Sg %Lp' "$FIXTURE/pam.d/sudo_local")" "$(id -un) $(id -gn) 444"
}

@test "Touch ID hook renders machine flags and literal privileged paths" {
  local machine enabled
  for machine in personal work ci homelab; do
    case "$machine" in
      personal|work) enabled=true ;;
      *) enabled=false ;;
    esac
    render_template "$hook" "$machine" >"$FIXTURE/rendered.sh"
    run_bash 0 -n "$FIXTURE/rendered.sh"
    assert_success
    run -0 grep -F "touchid_sudo_reconcile /etc/pam.d $enabled root wheel /usr/lib/pam/pam_tid.so.2" "$FIXTURE/rendered.sh"
    assert_success
  done
  render_template "$hook" personal '{"machines_local":{"touchid_sudo":false}}' >"$FIXTURE/rendered.sh"
  run -0 grep -F 'touchid_sudo_reconcile /etc/pam.d false root wheel /usr/lib/pam/pam_tid.so.2' "$FIXTURE/rendered.sh"
  assert_success
  render_template "$hook" personal '{"machines_local":{"run_install_scripts":false}}' >"$FIXTURE/rendered.sh"
  [ ! -s "$FIXTURE/rendered.sh" ]
}

@test "Touch ID creates the file and a repeated apply requests no sudo" {
  run_bash 0 "$scenario" true
  assert_success
  assert_equal "$stderr" ''
  assert_canonical
  assert_equal "$(find "$FIXTURE/pam.d" -name '.sudo_local.chezmoi*')" ''
  assert_equal "$(ls -A "$TMPDIR")" ''
  : >"$FIXTURE/sudo.log"
  run_bash 0 "$scenario" true
  assert_success
  assert_equal "$stderr" ''
  [ ! -s "$FIXTURE/sudo.log" ]
  assert_canonical
}

@test "Touch ID treats any existing sudo_local as installed without sudo" {
  local kind
  printf '%s\n' '# sudo_local: local config file for sudo' 'auth       sufficient     pam_tid.so' >"$FIXTURE/apple-template"
  for kind in empty foreign apple-template unreadable symlink dangling-symlink directory; do
    rm -rf "$FIXTURE/pam.d/sudo_local"
    case "$kind" in
      empty) : >"$FIXTURE/pam.d/sudo_local" ;;
      foreign) printf 'auth required pam_opendirectory.so\n' >"$FIXTURE/pam.d/sudo_local" ;;
      apple-template) cp "$FIXTURE/apple-template" "$FIXTURE/pam.d/sudo_local" ;;
      unreadable) cp "$FIXTURE/apple-template" "$FIXTURE/pam.d/sudo_local"; chmod 000 "$FIXTURE/pam.d/sudo_local" ;;
      symlink) ln -s ../apple-template "$FIXTURE/pam.d/sudo_local" ;;
      dangling-symlink) ln -s ../missing "$FIXTURE/pam.d/sudo_local" ;;
      directory) mkdir "$FIXTURE/pam.d/sudo_local" ;;
    esac
    ls -ldn "$FIXTURE/pam.d/sudo_local" >"$FIXTURE/before"
    run_bash 0 "$scenario" true
    assert_success
    assert_equal "$stderr" ''
    assert_regex "$output" 'exists; treating it as installed'
    ls -ldn "$FIXTURE/pam.d/sudo_local" | cmp "$FIXTURE/before" -
    [ ! -s "$FIXTURE/sudo.log" ]
  done
  chmod 600 "$FIXTURE/pam.d/sudo_local" 2>/dev/null || true
}

@test "Touch ID disable removes any sudo_local file or symlink" {
  local kind
  printf 'auth required pam_opendirectory.so\n' >"$FIXTURE/foreign"
  for kind in managed foreign unreadable symlink dangling-symlink; do
    case "$kind" in
      managed) cp "$FIXTURE/canonical" "$FIXTURE/pam.d/sudo_local" ;;
      foreign) cp "$FIXTURE/foreign" "$FIXTURE/pam.d/sudo_local" ;;
      unreadable) cp "$FIXTURE/foreign" "$FIXTURE/pam.d/sudo_local"; chmod 000 "$FIXTURE/pam.d/sudo_local" ;;
      symlink) ln -s ../foreign "$FIXTURE/pam.d/sudo_local" ;;
      dangling-symlink) ln -s ../missing "$FIXTURE/pam.d/sudo_local" ;;
    esac
    run_bash 0 "$scenario" false
    assert_success
    assert_equal "$stderr" ''
    [ ! -e "$FIXTURE/pam.d/sudo_local" ] && [ ! -L "$FIXTURE/pam.d/sudo_local" ]
    # Removing a symlink leaves its target alone.
    [ -f "$FIXTURE/foreign" ]
  done
}

@test "Touch ID disable leaves a sudo_local directory unchanged" {
  mkdir "$FIXTURE/pam.d/sudo_local"
  run_bash 0 "$scenario" false
  assert_success
  assert_regex "$stderr" 'warning:.*is a directory; leaving it unchanged'
  [ -d "$FIXTURE/pam.d/sudo_local" ]
  [ ! -s "$FIXTURE/sudo.log" ]
}

@test "Touch ID keeps a sudo_local created while authenticating or staging" {
  local boundary kind
  printf 'auth required pam_opendirectory.so\n' >"$FIXTURE/foreign"
  for boundary in auth install; do
    for kind in file symlink directory; do
      rm -rf "$FIXTURE/pam.d/sudo_local"
      cat >"$FIXTURE/during-$boundary" <<'CHANGE'
case "$REPLACEMENT_KIND" in
  file) cp "$FIXTURE/foreign" "$FIXTURE/pam.d/sudo_local" ;;
  symlink) ln -s ../foreign "$FIXTURE/pam.d/sudo_local" ;;
  directory) mkdir "$FIXTURE/pam.d/sudo_local" ;;
esac
CHANGE
      export REPLACEMENT_KIND="$kind"
      run_bash 0 "$scenario" true
      assert_success
      assert_regex "$output" 'appeared during setup; treating it as installed'
      case "$kind" in
        file) cmp "$FIXTURE/foreign" "$FIXTURE/pam.d/sudo_local" ;;
        symlink) assert_equal "$(readlink "$FIXTURE/pam.d/sudo_local")" ../foreign ;;
        directory) [ -d "$FIXTURE/pam.d/sudo_local" ] ;;
      esac
      assert_equal "$(ls -A "$TMPDIR")" ''
      assert_equal "$(find "$FIXTURE/pam.d" -name '.sudo_local.chezmoi*')" ''
      rm "$FIXTURE/during-$boundary"
    done
  done
}

@test "Touch ID skips a non-macOS host even when its profile opts in" {
  # Only a Mac type opts in, so the runtime uname check is the guard under test.
  render_template "$hook" personal >"$FIXTURE/rendered.sh"
  printf '#!/bin/sh\nprintf "Linux\\n"\n' >"$FIXTURE/bin/uname"
  chmod +x "$FIXTURE/bin/uname"
  run_bash 0 "$FIXTURE/rendered.sh"
  assert_success
  assert_regex "$output" 'skipped on non-macOS host'
  [ ! -s "$FIXTURE/sudo.log" ]
}

@test "Touch ID requires an active include and a regular module with the expected owner" {
  printf '#auth include sudo_local\n' >"$FIXTURE/pam.d/sudo"
  run_bash 0 "$scenario" true
  assert_success
  assert_regex "$stderr" 'warning:.*no active sudo_local include'
  printf 'auth include sudo_local\n' >"$FIXTURE/pam.d/sudo"
  run_bash 0 "$scenario" true nobody
  assert_success
  assert_regex "$stderr" 'warning:.*regular file owned by nobody'
  rm "$FIXTURE/pam_tid.so.2"
  run_bash 0 "$scenario" true
  assert_success
  assert_regex "$stderr" 'warning:.*must be a regular file'
  ln -s canonical "$FIXTURE/pam_tid.so.2"
  run_bash 0 "$scenario" true
  assert_success
  assert_regex "$stderr" 'warning:.*must be a regular file'
  [ ! -s "$FIXTURE/sudo.log" ]
  [ ! -e "$FIXTURE/pam.d/sudo_local" ]
}

@test "Touch ID removal works after prerequisites disappear and is idempotent" {
  cp "$FIXTURE/canonical" "$FIXTURE/pam.d/sudo_local"
  printf '#auth include sudo_local\n' >"$FIXTURE/pam.d/sudo"
  rm "$FIXTURE/pam_tid.so.2"
  run_bash 0 "$scenario" false
  assert_success
  [ ! -e "$FIXTURE/pam.d/sudo_local" ]
  : >"$FIXTURE/sudo.log"
  run_bash 0 "$scenario" false
  assert_success
  assert_equal "$stderr" ''
  [ ! -s "$FIXTURE/sudo.log" ]
}

@test "Touch ID write failures leave no file and a later apply recovers" {
  local command
  for command in install mv; do
    printf '%s\n' "$command" >"$FIXTURE/fail-command"
    run_bash 1 "$scenario" true
    assert_failure 1
    assert_regex "$stderr" "injected $command failure"
    [ ! -e "$FIXTURE/pam.d/sudo_local" ]
    assert_equal "$(ls -A "$TMPDIR")" ''
    assert_equal "$(find "$FIXTURE/pam.d" -name '.sudo_local.chezmoi*')" ''
    rm "$FIXTURE/fail-command"
    run_bash 0 "$scenario" true
    assert_success
    assert_canonical
    rm -f "$FIXTURE/pam.d/sudo_local"
  done
}

@test "Touch ID removal errors fail the apply" {
  cp "$FIXTURE/canonical" "$FIXTURE/pam.d/sudo_local"
  printf 'rm\n' >"$FIXTURE/fail-command"
  run_bash 1 "$scenario" false
  assert_failure 1
  assert_regex "$stderr" 'injected rm failure'
  cmp "$FIXTURE/canonical" "$FIXTURE/pam.d/sudo_local"
}
