load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  template=home/.chezmoiscripts/run_after_22-setapp-apps.sh.tmpl
  render_template "$template" personal '{"machines_local":{"run_install_scripts":true}}' > "$FIXTURE/install.sh"

  # Point the hook's Setapp root at the fixture and mark Setapp "installed".
  root="$FIXTURE/Applications"
  mkdir -p "$root/Setapp.app" "$root/Setapp"
  export DOTFILES_SETAPP_ROOT="$root"
  export DOTFILES_SETAPP_STORE_API="https://example.test/store"

  # A real notarization-free .app inside a real zip, so the hook's actual
  # ditto-extract / find-.app / place logic runs (only the network is stubbed).
  build_fixture_zip

  # Stub curl: the store API returns our catalogue; any archive URL returns the
  # fixture zip. Records requested URLs for assertions.
  cat > "$FIXTURE/bin/curl" <<STUB
#!/bin/sh
out=""; url=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) out="\$2"; shift 2 ;;
    -*) shift ;;
    http*) url="\$1"; shift ;;
    *) shift ;;
  esac
done
printf '%s\n' "\$url" >> "$FIXTURE/curl.urls"
case "\$url" in
  *example.test/store*) cp "$FIXTURE/catalog.json" "\$out" ;;
  *TEST_ARCHIVE_FAIL*) exit 22 ;;
  *) cp "$FIXTURE/fixture.zip" "\$out" ;;
esac
STUB
  chmod +x "$FIXTURE/bin/curl"
  : > "$FIXTURE/curl.urls"
}

build_fixture_zip() {
  local staging="$FIXTURE/staging"
  mkdir -p "$staging/iStat Menus.app/Contents/MacOS"
  printf 'bin\n' > "$staging/iStat Menus.app/Contents/MacOS/iStat Menus"
  chmod +x "$staging/iStat Menus.app/Contents/MacOS/iStat Menus"
  printf '<plist/>\n' > "$staging/iStat Menus.app/Contents/Info.plist"
  ( cd "$staging" && zip -qr "$FIXTURE/fixture.zip" "iStat Menus.app" )
  rm -rf "$staging"
}

# Catalogue naming CleanShot X, iStat Menus, Maestri, Soulver, Yoink (the
# personal set) so name resolution is exercised for the real declared apps.
write_catalog() {
  "$TEST_PYTHON" - "$FIXTURE/catalog.json" <<'PY'
import json, sys
apps = ["CleanShot X", "iStat Menus", "Maestri", "Soulver", "Yoink"]
def app(i, name):
    return {"id": i, "attributes": {"name": name},
            "relationships": {"versions": {"data": [
                {"attributes": {"archive_url": f"https://example.test/app/{i}.zip"}}]}}}
doc = {"data": {"relationships": {"vendors": {"data": [
    {"relationships": {"applications": {"data": [app(i, n) for i, n in enumerate(apps)]}}}]}}}}
json.dump(doc, open(sys.argv[1], "w"))
PY
}

@test "Setapp install hook is empty when the machine does not select Setapp" {
  render_template "$template" ci '{"machines_local":{"run_install_scripts":true}}' > "$FIXTURE/ci.sh"
  [ ! -s "$FIXTURE/ci.sh" ]
}

@test "Setapp install hook downloads and unpacks every declared app that is missing" {
  write_catalog
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  [ -d "$root/Setapp/iStat Menus.app" ]
  [ -x "$root/Setapp/iStat Menus.app/Contents/MacOS/iStat Menus" ]
  # The store catalogue is fetched once, then one archive per declared app (5).
  run -0 grep -c "example.test/store" "$FIXTURE/curl.urls"; assert_output 1
  run -0 grep -c "example.test/app/" "$FIXTURE/curl.urls"; assert_output 5
}

@test "Setapp install hook skips apps that are already installed and never uninstalls" {
  write_catalog
  mkdir -p "$root/Setapp/Yoink.app" "$root/Setapp/Soulver.app" \
           "$root/Setapp/Maestri.app" "$root/Setapp/CleanShot X.app"
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  # Only iStat Menus was missing, so only its archive is fetched.
  run -0 grep -c "example.test/app/" "$FIXTURE/curl.urls"; assert_output 1
  # Pre-existing apps are left in place.
  [ -d "$root/Setapp/Yoink.app" ]
}

@test "Setapp install hook is a no-op when everything is already installed" {
  write_catalog
  for a in "CleanShot X" "iStat Menus" Maestri Soulver Yoink; do mkdir -p "$root/Setapp/$a.app"; done
  run_bash 0 "$FIXTURE/install.sh"
  assert_success
  assert_output --partial "already installed"
  # No catalogue fetch, no downloads.
  [ ! -s "$FIXTURE/curl.urls" ]
}

@test "Setapp install hook warns and skips when Setapp itself is not installed" {
  write_catalog
  rm -rf "$root/Setapp.app"
  run_without_reporting_fds 0 "$BASH" "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *"Setapp is not installed yet"* ]]
  [ ! -s "$FIXTURE/curl.urls" ]
}

@test "Setapp install hook does not fail the apply when the catalogue fetch fails" {
  # No catalog.json written and store URL redirected to a failing path.
  export DOTFILES_SETAPP_STORE_API="https://example.test/TEST_ARCHIVE_FAIL/store"
  render_template "$template" personal '{"machines_local":{"run_install_scripts":true}}' > "$FIXTURE/install.sh"
  run_without_reporting_fds 0 "$BASH" "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *"could not fetch the Setapp store catalog"* ]]
}

@test "Setapp install hook reports a declared app missing from the catalogue" {
  # Catalogue without iStat Menus; the declared name cannot resolve.
  "$TEST_PYTHON" - "$FIXTURE/catalog.json" <<'PY'
import json, sys
doc = {"data": {"relationships": {"vendors": {"data": [
    {"relationships": {"applications": {"data": [
        {"id": 1, "attributes": {"name": "Yoink"},
         "relationships": {"versions": {"data": [
             {"attributes": {"archive_url": "https://example.test/app/1.zip"}}]}}}]}}}]}}}}
json.dump(doc, open(sys.argv[1], "w"))
PY
  mkdir -p "$root/Setapp/Yoink.app"  # only Yoink resolvable+installed
  run_without_reporting_fds 0 "$BASH" "$FIXTURE/install.sh"
  assert_success
  [[ "$stderr" == *"not found in the Setapp catalogue"* ]]
  [[ "$stderr" == *"iStat Menus"* ]]
}
