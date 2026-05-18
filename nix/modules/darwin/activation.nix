{
  lib,
  config,
  pkgs,
  ...
}:

# Imperative defaults that nix-darwin doesn't model:
# - pmset / nvram / systemsetup (power, audio, restart-freeze, timezone)
# - chflags (~/Library, /Volumes visibility)
# - inline plists (symbolichotkeys, HIToolbox) via `defaults import`
# - LaunchServices register, Spotlight reindex (optional, env-gated)
# - cfprefsd nudge at the end (replaces the chezmoi post-apply hook)
# - Per-bundle partial-merge plists via scripts/macos/plist-merge

let
  inherit (lib) optionalString;

  # Bundles whose preferences need partial-merge semantics (preserve
  # runtime-managed keys). Each value is the path to a plain .plist file
  # describing the keys we manage. The activation iterates these, base64s
  # the file contents, and shells out to scripts/macos/plist-merge.
  managedPlists = {
    "com.raycast.macos" = ../../../home/.chezmoitemplates/com.raycast.macos.plist.tmpl;
    "com.hegenberg.BetterTouchTool" = ../../../home/.chezmoitemplates/com.hegenberg.BetterTouchTool.plist.tmpl;
    "io.tailscale.ipn.macsys" = ../../../home/.chezmoitemplates/io.tailscale.ipn.macsys.plist.tmpl;
    "com.prakashjoshipax.VoiceInk" = ../../../home/.chezmoitemplates/com.prakashjoshipax.VoiceInk.plist.tmpl;
    "net.elasticthreads.nv" = ../../../home/.chezmoitemplates/net.elasticthreads.nv.plist.tmpl;
    "dev.kdrag0n.MacVirt" = ../../../home/.chezmoitemplates/dev.kdrag0n.MacVirt.plist.tmpl;
    "com.manytricks.Moom" = ../../../home/.chezmoitemplates/com.manytricks.Moom.plist.tmpl;
    "com.jordanbaird.Ice" = ../../../home/.chezmoitemplates/com.jordanbaird.Ice.plist.tmpl;
    "com.cmuxterm.app" = ../../../home/.chezmoitemplates/com.cmuxterm.app.plist.tmpl;
    "com.setapp.DesktopClient" = ../../../home/.chezmoitemplates/com.setapp.DesktopClient.plist.tmpl;
    "pro.betterdisplay.BetterDisplay" = ../../../home/.chezmoitemplates/pro.betterdisplay.BetterDisplay.plist.tmpl;
  };

  plistMerge = ../../../scripts/macos/plist-merge;

  # Repo root at evaluation time. nix-darwin activation runs against the
  # _stored_ derivation paths, so we copy the merger and the desired
  # fragments into the activation closure via builtins.toString.
  mkPlistMergeCall = bundleId: fragmentPath: ''
    if [ -r "${toString fragmentPath}" ]; then
      base64_payload="$(base64 < "${toString fragmentPath}" | tr -d '\n')"
      ${toString plistMerge} \
        --bundle-id '${bundleId}' \
        --desired-b64 "$base64_payload" \
        || echo "[nix-darwin] warn: plist-merge failed for ${bundleId}." >&2
    fi
  '';
in
lib.mkIf config.profile.applyMacosDefaults {

  system.activationScripts.macosImperativeDefaults.text = ''
    set -eu

    # System Settings can race our writes. Quit it (and the legacy app).
    /usr/bin/osascript -e 'tell application "System Settings" to quit' 2>/dev/null || true
    /usr/bin/osascript -e 'tell application "System Preferences" to quit' 2>/dev/null || true

    # ----- Boot, power, sleep -----
    /usr/sbin/nvram SystemAudioVolume=" " || true
    /usr/bin/pmset -a standbydelay 86400 || true
    /usr/bin/pmset -a hibernatemode 0 || true
    /usr/sbin/systemsetup -setrestartfreeze on > /dev/null 2>&1 || true
    if ! /usr/bin/pmset -g batt 2>/dev/null | grep -q "InternalBattery"; then
      /usr/bin/pmset -a sleep 0 standby 0 autopoweroff 0 > /dev/null 2>&1 || true
    fi
    # HiDPI; requires logout/restart.
    /usr/bin/defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true || true

    # ----- Locale, timezone -----
    /usr/sbin/systemsetup -settimezone "America/New_York" > /dev/null 2>&1 || true

    # ----- Login window admin host info -----
    /usr/bin/defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName || true

    # ----- Library / Volumes visibility -----
    /usr/bin/chflags nohidden "$HOME/Library" 2>/dev/null || true
    /usr/bin/chflags nohidden /Volumes 2>/dev/null || true

    # ----- Disable music app media-key hijack -----
    /bin/launchctl unload -w /System/Library/LaunchAgents/com.apple.rcd.plist 2>/dev/null || true

    # ----- Spotlight: reindex (optional) -----
    if [ "''${DOTFILES_SKIP_REINDEX:-0}" != "1" ]; then
      /usr/bin/killall mds >/dev/null 2>&1 || true
      /usr/sbin/mdutil -i on / >/dev/null 2>&1 || true
      /usr/sbin/mdutil -E / >/dev/null 2>&1 || true
    fi

    # ----- LaunchServices: rebuild Open With (optional) -----
    if [ "''${DOTFILES_SKIP_LSREGISTER:-0}" != "1" ]; then
      /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -r -domain local -domain system -domain user >/dev/null 2>&1 || true
    fi

    # ----- ByHost menu extras (chase the volatile UUID-suffixed plist) -----
    for domain in "$HOME"/Library/Preferences/ByHost/com.apple.systemuiserver.*; do
      [ -e "$domain" ] || continue
      /usr/bin/defaults write "$domain" dontAutoLoad -array \
        "/System/Library/CoreServices/Menu Extras/TimeMachine.menu" \
        "/System/Library/CoreServices/Menu Extras/Volume.menu" \
        "/System/Library/CoreServices/Menu Extras/User.menu" 2>/dev/null || true
    done

    # ----- Control center filler slots: default Item-0..Item-12 off -----
    for i in $(seq 0 12); do
      /usr/bin/defaults write com.apple.controlcenter \
        "NSStatusItem Visible Item-$i" -bool false 2>/dev/null || true
    done

    # ----- Finder icon-view geometry (PlistBuddy across 3 parent keys) -----
    icon_cmds=""
    for parent in DesktopViewSettings FK_StandardViewSettings StandardViewSettings; do
      icon_cmds="$icon_cmds -c \"Set :''${parent}:IconViewSettings:showItemInfo true\""
      icon_cmds="$icon_cmds -c \"Set :''${parent}:IconViewSettings:arrangeBy grid\""
      icon_cmds="$icon_cmds -c \"Set :''${parent}:IconViewSettings:gridSpacing 54\""
      icon_cmds="$icon_cmds -c \"Set :''${parent}:IconViewSettings:iconSize 64\""
    done
    icon_cmds="$icon_cmds -c \"Set DesktopViewSettings:IconViewSettings:labelOnBottom false\""
    eval "/usr/libexec/PlistBuddy $icon_cmds \"$HOME/Library/Preferences/com.apple.finder.plist\"" 2>/dev/null || true

    # ----- Inline plist: disable conflicting symbolic hotkeys -----
    HOTKEYS_PLIST="$HOME/Library/Preferences/com.apple.symbolichotkeys.plist"
    /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys dict" "$HOTKEYS_PLIST" 2>/dev/null || true
    for id in 18 26 28 29 30 31 64 65 164 184; do
      /usr/libexec/PlistBuddy -c "Delete :AppleSymbolicHotKeys:$id" "$HOTKEYS_PLIST" 2>/dev/null || true
      /usr/libexec/PlistBuddy \
        -c "Add :AppleSymbolicHotKeys:$id dict" \
        -c "Add :AppleSymbolicHotKeys:$id:enabled bool false" \
        "$HOTKEYS_PLIST" 2>/dev/null || true
    done

    # ----- Inline plist: keyboard layout (ABC) + input sources (PressAndHold) -----
    HITOOLBOX_TMP="$(mktemp -d)/hitoolbox.plist"
    cat > "$HITOOLBOX_TMP" <<'PLIST'
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>AppleCurrentKeyboardLayoutInputSourceID</key>
      <string>com.apple.keylayout.ABC</string>
      <key>AppleEnabledInputSources</key>
      <array>
        <dict>
          <key>InputSourceKind</key><string>Keyboard Layout</string>
          <key>KeyboardLayout ID</key><integer>252</integer>
          <key>KeyboardLayout Name</key><string>ABC</string>
        </dict>
        <dict>
          <key>Bundle ID</key><string>com.apple.CharacterPaletteIM</string>
          <key>InputSourceKind</key><string>Non Keyboard Input Method</string>
        </dict>
        <dict>
          <key>Bundle ID</key><string>com.apple.PressAndHold</string>
          <key>InputSourceKind</key><string>Non Keyboard Input Method</string>
        </dict>
      </array>
      <key>AppleFnUsageType</key>
      <integer>0</integer>
      <key>AppleSelectedInputSources</key>
      <array>
        <dict>
          <key>InputSourceKind</key><string>Keyboard Layout</string>
          <key>KeyboardLayout ID</key><integer>252</integer>
          <key>KeyboardLayout Name</key><string>ABC</string>
        </dict>
        <dict>
          <key>Bundle ID</key><string>com.apple.PressAndHold</string>
          <key>InputSourceKind</key><string>Non Keyboard Input Method</string>
        </dict>
      </array>
    </dict>
    </plist>
    PLIST
    /usr/bin/defaults import com.apple.HIToolbox "$HITOOLBOX_TMP" || true
    rm -rf "$(dirname "$HITOOLBOX_TMP")"

    # ----- Partial-merge plists (preserve runtime keys) -----
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList mkPlistMergeCall managedPlists)}

    # ----- Cfprefsd nudge so GUI apps re-read prefs on next launch -----
    /usr/bin/killall cfprefsd >/dev/null 2>&1 || true

    # ----- Restart UI apps so they pick up changes -----
    if [ "''${DOTFILES_SKIP_APP_RESTART:-0}" != "1" ]; then
      /usr/bin/killall -q "Activity Monitor" "Dock" "Finder" "Google Chrome" \
        "Messages" "Safari" "SystemUIServer" 2>/dev/null || true
    fi
  '';
}
