load '../../support/common'

setup() {
  setup_fixture
  helper="$DOTFILES_ROOT/agent-marketplace/packages/utils-agent/skills/browser/scripts/orca-import-login"
  url=https://meta.example.com/dashboards/d/rollout
  export ORCA_VERSION=1.4.210 LANDING="$url"
  echo 25 > "$FIXTURE/imported-cookies"
  export ORCA_USER_DATA_PATH="$FIXTURE/orca-data"
  mkdir -p "$ORCA_USER_DATA_PATH"
  # Stands in for the Orca runtime socket that serves the private import method.
  cat > "$FIXTURE/runtime.py" <<'STUB'
import json, os, socket, sys
path = sys.argv[1]
server = socket.socket(socket.AF_UNIX)
server.bind(path)
server.listen()
while True:
    conn, _ = server.accept()
    request = json.loads(conn.makefile().readline())
    with open(os.environ["FIXTURE"] + "/rpc-calls", "a") as log:
        log.write(json.dumps(request) + "\n")
    if request["authToken"] != "fixture-token":
        result = None
    elif request["method"] == "browser.profileDetectBrowsers":
        result = {"browsers": [{"family": "chrome", "label": "Google Chrome",
                  "profiles": [{"name": "Your Chrome", "directory": "Default"}],
                  "selectedProfile": "Default"}]}
    else:
        count = int(open(os.environ["FIXTURE"] + "/imported-cookies").read())
        result = {"ok": True, "profileId": request["params"]["profileId"],
                  "summary": {"totalCookies": count, "importedCookies": count,
                              "skippedCookies": 0, "domains": [".example.com"]}}
    frames = [{"_keepalive": True}, {"id": request["id"], "ok": result is not None,
              "result": result, "error": None if result else {"message": "bad token"}}]
    conn.sendall("".join(json.dumps(f) + "\n" for f in frames).encode())
    conn.close()
STUB
  socket_path="$BATS_TEST_TMPDIR/rt.sock"
  "$TEST_PYTHON" "$FIXTURE/runtime.py" "$socket_path" 3>&- &
  runtime_pid=$!
  printf '{"runtimeId":"rt","authToken":"fixture-token","transports":[{"kind":"unix","endpoint":"%s"}]}\n' \
    "$socket_path" > "$ORCA_USER_DATA_PATH/orca-runtime.json"
  cat > "$FIXTURE/bin/orca" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FIXTURE/orca-calls"
ok() { printf '{"ok":true,"result":%s}\n' "$1"; }
case "$1 $2 $3" in
  "--version  ") echo "$ORCA_VERSION" ;;
  "tab profile create") ok '{"profile":{"id":"prof-1","scope":"imported","source":null}}' ;;
  "tab profile delete") ok '{"deleted":true}' ;;
  "tab create --url") ok '{"browserPageId":"page-1"}' ;;
  "tab close --page") ok '{"closed":true}' ;;
  wait*) ok '{"state":"load"}' ;;
  snapshot*)
    if [ -n "$SNAPSHOT_RESULT" ]; then ok "$SNAPSHOT_RESULT"; else ok "{\"origin\":\"$LANDING\",\"refs\":{}}"; fi ;;
  *) exit 1 ;;
esac
STUB
  chmod +x "$FIXTURE/bin/orca"
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -S "$socket_path" ] && break; sleep 0.1; done
}

teardown() {
  kill "$runtime_pid" 2> /dev/null || true
}

@test "orca-import-login opens the page in a tab signed in with the imported login" {
  run_without_reporting_fds 0 "$helper" --url "$url" --browser chrome --browser-profile 'Your Chrome' --label meta
  assert_equal "$(jq -c . <<< "$output")" \
    "{\"browserPageId\":\"page-1\",\"profileId\":\"prof-1\",\"origin\":\"$url\",\"importedCookies\":25,\"domains\":1}"
  assert_equal "$(jq -c 'select(.method == "browser.profileImportFromBrowser") | .params' "$FIXTURE/rpc-calls")" \
    '{"profileId":"prof-1","browserFamily":"chrome","browserProfile":"Default","supportsPartitionSkippedCookies":true}'
  assert_regex "$(cat "$FIXTURE/orca-calls")" 'tab profile create --label meta --scope imported'
  refute_regex "$(cat "$FIXTURE/orca-calls")" 'delete|close'
  refute_regex "$output$stderr" 'fixture-token'
}

@test "orca-import-login deletes its profile when the import copies no cookies" {
  echo 0 > "$FIXTURE/imported-cookies"
  run_without_reporting_fds 1 "$helper" --url "$url" --browser chrome
  assert_output ''
  assert_regex "$stderr" 'import copied no cookies from chrome Default'
  assert_regex "$(cat "$FIXTURE/orca-calls")" 'tab profile delete --profile prof-1'
  refute_regex "$(cat "$FIXTURE/orca-calls")" 'tab create'
}

@test "orca-import-login closes the tab and deletes the profile when the page lands on Okta" {
  export LANDING=https://example.okta.com/oauth2/v1/authorize
  run_without_reporting_fds 1 "$helper" --url "$url" --browser chrome --verify-timeout 0
  assert_regex "$stderr" 'stopped at the login page on example\.okta\.com'
  assert_regex "$(cat "$FIXTURE/orca-calls")" $'tab close --page page-1 --json\ntab profile delete --profile prof-1'
}

@test "orca-import-login refuses a browser Orca cannot import from before creating anything" {
  run_without_reporting_fds 1 "$helper" --url "$url" --browser prisma
  assert_regex "$stderr" "cannot import from browser family 'prisma'; detected: chrome"
  refute_regex "$(cat "$FIXTURE/orca-calls")" 'tab profile create'
}

@test "orca-import-login stops on an Orca release outside the tested range" {
  export ORCA_VERSION=1.5.0
  run_without_reporting_fds 1 "$helper" --url "$url" --browser chrome
  assert_regex "$stderr" 'Orca 1\.5\.0 is outside the tested range'
  [ ! -e "$FIXTURE/rpc-calls" ]
  assert_equal "$(cat "$FIXTURE/orca-calls")" '--version'
}

@test "orca-import-login accepts a redirect within the same registrable domain" {
  # apex<->www and sibling hosts on the target's own domain are the site, not a
  # bounce to a login page, so the tab must be kept.
  export LANDING=https://www.example.com/dashboards/d/rollout
  run_without_reporting_fds 0 "$helper" --url "$url" --browser chrome --browser-profile 'Your Chrome'
  assert_equal "$(jq -r .origin <<< "$output")" "$LANDING"
  refute_regex "$(cat "$FIXTURE/orca-calls")" 'delete|close'
}

@test "orca-import-login cleans up when an unexpected error interrupts verification" {
  # A non-Failure exception (here a malformed snapshot result) must still tear
  # down the tab and profile this run created, then re-raise the traceback.
  export SNAPSHOT_RESULT='"not-an-object"'
  run_without_reporting_fds 1 "$helper" --url "$url" --browser chrome
  assert_regex "$stderr" 'Traceback'
  assert_regex "$(cat "$FIXTURE/orca-calls")" $'tab close --page page-1 --json\ntab profile delete --profile prof-1'
}
