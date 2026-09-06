load '../../support/common'

setup() {
  setup_fixture
  scanner="$DOTFILES_ROOT/scripts/vm/check-install-log.sh"
  log="$FIXTURE/install.log"
}

@test "Install log scanner accepts successful bootstrap and verification output" {
  cat > "$log" <<'LOG'
Applying macOS settings + app configs...
Bootstrap complete.
SUMMARY|verify|passed=59|failed=0|info=1
LOG
  run_bash 0 "$scanner" "$log"
  assert_success
  assert_output 'install log scan passed'
  [ -z "$stderr" ]
}

@test "Install log scanner reports removed flags sealed writes Spotlight and missing Dock paths" {
  cat > "$log" <<'LOG'
# The -kill option has been removed because it was dangerous and no longer useful.
chmod: Unable to change file mode on /System/Library/CoreServices/Search.bundle/Contents/MacOS/Search: Read-only file system
2026-04-26 17:19:21.744 defaults[815:5785] Could not write domain /.Spotlight-V100/VolumeConfiguration; exiting
find: /Users/admin/Library/Application Support/Dock: No such file or directory
LOG
  run_bash 1 "$scanner" "$log"
  assert_failure 1
  assert_output ''
  [[ "$stderr" == *'removed LaunchServices flag'* ]]
  [[ "$stderr" == *'sealed system write'* ]]
  [[ "$stderr" == *'unsupported Spotlight defaults write'* ]]
  [[ "$stderr" == *'missing clean-VM Dock database path'* ]]
}

@test "Install log scanner reports dynamic loader failures after a successful brew install" {
  cat > "$log" <<'LOG'
`brew bundle` complete! 292 Brewfile dependencies now installed.
dyld[36566]: Library not loaded: /opt/homebrew/opt/simdjson/lib/libsimdjson.31.dylib
  Referenced from: <FD86D65B-7A6E-3DF7-BD83-D0BF5EE08125> /opt/homebrew/Cellar/node@24/24.14.1/bin/node
  Reason: tried: '/opt/homebrew/opt/simdjson/lib/libsimdjson.31.dylib' (no such file)
LOG
  run_bash 1 "$scanner" "$log"
  assert_failure 1
  [[ "$stderr" == *'dynamic loader failure'* ]]
  [[ "$stderr" == *'Library not loaded'* ]]
}

@test "Install log scanner reports attestation systemsetup and protected defaults failures" {
  cat > "$log" <<'LOG'
mise ERROR Failed to install core:ruby@latest: GitHub artifact attestations verification failed for ruby@4.0.3
2026-05-10 01:38:13.260 systemsetup[73367:490181] ### Error:-99 File:/AppleInternal/Library/BuildRoots/4~CJ3IugCZu-TBVIdo7MkmNzjDu6yhNFVWYiW62oo/Library/Caches/com.apple.xbs/TemporaryDirectory.Fxezov/Sources/Admin/InternetServices.m Line:395
2026-05-10 01:38:13.550 defaults[73419:490509] Could not write domain com.apple.universalaccess; exiting
2026-05-10 01:38:14.711 defaults[73516:490913] Could not write domain /Users/prateek/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari; exiting
LOG
  run_bash 1 "$scanner" "$log"
  assert_failure 1
  [[ "$stderr" == *'mise GitHub attestation rate-limit failure'* ]]
  [[ "$stderr" == *'unfiltered systemsetup InternetServices noise'* ]]
  [[ "$stderr" == *'unhandled Universal Access defaults failure'* ]]
  [[ "$stderr" == *'unhandled Safari defaults failure'* ]]
}
