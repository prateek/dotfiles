load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  app=/Applications/WinMux.app
  printf '#!/bin/sh\nexit 0\n' > "$FIXTURE/bin/winmux"
  # A brew on PATH stops brew_shellenv from putting the host's real winmux ahead of the stub.
  printf '#!/bin/sh\nexit 0\n' > "$FIXTURE/bin/brew"
  # The hook follows the CLI's symlinks, as it must for brew's link into the Caskroom.
  cli="$(readlink -f "$FIXTURE/bin/winmux")"
  # Fake xattr: paths listed in $FIXTURE/quarantined carry the attribute;
  # XATTR_FAIL makes removal fail.
  cat > "$FIXTURE/bin/xattr" <<'STUB'
#!/bin/bash
list="$FIXTURE/quarantined"
case "$1" in
  -p) grep -qxF "$3" "$list" 2>/dev/null ;;
  -dr)
    [ -z "${XATTR_FAIL:-}" ] || exit 1
    printf '%s\n' "$3" >> "$FIXTURE/cleared"
    grep -vxF "$3" "$list" > "$list.next" || true
    mv "$list.next" "$list" ;;
  *) exit 2 ;;
esac
STUB
  chmod +x "$FIXTURE/bin/winmux" "$FIXTURE/bin/brew" "$FIXTURE/bin/xattr"
  render_template home/.chezmoiscripts/run_after_14-winmux-quarantine.sh.tmpl personal > "$FIXTURE/quarantine.sh"
}

@test "a quarantined app and CLI are both cleared" {
  printf '%s\n' "$app" "$cli" > "$FIXTURE/quarantined"

  run_bash 0 "$FIXTURE/quarantine.sh"
  assert_success
  [ "$(cat "$FIXTURE/cleared")" = "$app"$'\n'"$cli" ]
  assert_output --partial "cleared Gatekeeper quarantine from $app"
  assert_output --partial "cleared Gatekeeper quarantine from $cli"
}

@test "an unquarantined install is left alone and the run is silent" {
  run_bash 0 "$FIXTURE/quarantine.sh"
  assert_success
  [ ! -e "$FIXTURE/cleared" ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "a failed removal warns with the manual command and does not fail the apply" {
  printf '%s\n' "$app" > "$FIXTURE/quarantined"

  XATTR_FAIL=1 run_bash 0 "$FIXTURE/quarantine.sh"
  assert_success
  [[ "$stderr" == *"run: xattr -dr com.apple.quarantine \"$app\""* ]]
}
