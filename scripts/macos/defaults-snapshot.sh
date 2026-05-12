#!/usr/bin/env bash
set -euo pipefail

payload_hash="${1:-}"

if [ -n "$payload_hash" ]; then
  printf 'payload=%s\n' "$payload_hash"
fi

if [ "$(uname -s)" != "Darwin" ]; then
  printf 'os=non-darwin\n'
  exit 0
fi

snapshot_default() {
  local domain key
  domain="$1"
  key="$2"
  printf '\n[defaults:%s:%s]\n' "$domain" "$key"
  defaults read "$domain" "$key" 2>/dev/null || true
}

snapshot_current_host_default() {
  local domain key
  domain="$1"
  key="$2"
  printf '\n[defaults-current-host:%s:%s]\n' "$domain" "$key"
  defaults -currentHost read "$domain" "$key" 2>/dev/null || true
}

snapshot_byhost_default() {
  local found path pattern key
  pattern="$1"
  key="$2"
  found=0
  for path in $pattern; do
    [ -e "$path" ] || continue
    found=1
    printf '\n[defaults-file:%s:%s]\n' "$path" "$key"
    defaults read "$path" "$key" 2>/dev/null || true
  done
  if [ "$found" -eq 0 ]; then
    printf '\n[defaults-file:%s:%s]\nmissing\n' "$pattern" "$key"
  fi
}

snapshot_plist_key() {
  local key_path plist
  plist="$1"
  key_path="$2"
  printf '\n[plist:%s:%s]\n' "$plist" "$key_path"
  [ -e "$plist" ] || {
    printf 'missing\n'
    return 0
  }
  /usr/libexec/PlistBuddy -c "Print :$key_path" "$plist" 2>/dev/null || true
}

snapshot_file_flags() {
  local flags path
  path="$1"
  printf '\n[file-flags:%s]\n' "$path"
  # macOS exposes Finder's hidden bit through the BSD file flags column.
  # This intentionally ignores size, mtime, owner, and mode.
  # shellcheck disable=SC2012
  flags="$(ls -ldO "$path" 2>/dev/null | awk '{print $5}' || true)"
  case "$flags" in
    *hidden*) printf 'hidden\n' ;;
    '') ;;
    *) printf 'not-hidden\n' ;;
  esac
}

snapshot_power_plist_key() {
  local key plist power_source
  plist="$1"
  power_source="$2"
  key="$3"
  printf '[%s:%s:%s]\n' "$plist" "$power_source" "$key"
  /usr/libexec/PlistBuddy -c "Print :\"$power_source\":\"$key\"" "$plist" 2>/dev/null || true
}

snapshot_power_management_settings() {
  local include_desktop_sleep_keys key plist power_management_plists power_source
  include_desktop_sleep_keys=0
  if ! pmset -g batt 2>/dev/null | grep -q "InternalBattery"; then
    include_desktop_sleep_keys=1
  fi

  power_management_plists="${MACOS_DEFAULTS_TEST_POWER_MANAGEMENT_PLISTS:-/Library/Preferences/com.apple.PowerManagement.plist /Library/Preferences/com.apple.PowerManagement.*.plist}"

  printf '\n[power-management]\n'
  for plist in $power_management_plists; do
    [ -e "$plist" ] || continue
    for power_source in "AC Power" "Battery Power"; do
      for key in "Hibernate Mode" "Standby Delay" "High Standby Delay" "RestartAfterKernelPanic"; do
        snapshot_power_plist_key "$plist" "$power_source" "$key"
      done
      if [ "$include_desktop_sleep_keys" -eq 1 ]; then
        for key in "System Sleep Timer" "Standby Enabled" "AutoPowerOff Enabled" "AutoPowerOff Delay"; do
          snapshot_power_plist_key "$plist" "$power_source" "$key"
        done
      fi
    done
  done
}

snapshot_timezone() {
  local zone

  printf '\n[timezone]\n'
  zone="$(readlink /etc/localtime 2>/dev/null || true)"
  case "$zone" in
    */zoneinfo/*) printf '%s\n' "${zone##*/zoneinfo/}" ;;
    '') ;;
    *) printf '%s\n' "$zone" ;;
  esac
}

snapshot_nvram() {
  printf '\n[nvram:SystemAudioVolume]\n'
  nvram SystemAudioVolume 2>/dev/null || true
}

snapshot_launchctl_rcd() {
  local uid
  uid="$(id -u 2>/dev/null || true)"
  printf '\n[launchctl-disabled:com.apple.rcd]\n'
  [ -n "$uid" ] || return 0
  launchctl print-disabled "gui/$uid" 2>/dev/null | grep -F '"com.apple.rcd"' || true
}

snapshot_power_management_settings
snapshot_timezone
snapshot_nvram
snapshot_launchctl_rcd
snapshot_file_flags "$HOME/Library"
snapshot_file_flags /Volumes

snapshot_default /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled
snapshot_default /Library/Preferences/com.apple.loginwindow AdminHostInfo

snapshot_default NSGlobalDomain AppleLanguages
snapshot_default NSGlobalDomain AppleLocale
snapshot_current_host_default NSGlobalDomain com.apple.mouse.tapBehavior
snapshot_default NSGlobalDomain com.apple.mouse.tapBehavior
snapshot_default NSGlobalDomain com.apple.swipescrolldirection
snapshot_default NSGlobalDomain AppleKeyboardUIMode
snapshot_default NSGlobalDomain KeyRepeat
snapshot_default NSGlobalDomain InitialKeyRepeat
snapshot_default NSGlobalDomain AppleFontSmoothing
snapshot_default NSGlobalDomain com.apple.sound.beep.volume
snapshot_default NSGlobalDomain com.apple.sound.beep.flash
snapshot_default NSGlobalDomain AppleHighlightColor
snapshot_default NSGlobalDomain AppleInterfaceStyle
snapshot_default NSGlobalDomain AppleShowScrollBars
snapshot_default NSGlobalDomain NSAutomaticWindowAnimationsEnabled
snapshot_default NSGlobalDomain NSWindowResizeTime
snapshot_default NSGlobalDomain NSUseAnimatedFocusRing
snapshot_default NSGlobalDomain AppleMiniaturizeOnDoubleClick
snapshot_default NSGlobalDomain NSZoomButtonMenuOption
snapshot_default NSGlobalDomain shouldShowRSVPDataDetectors
snapshot_default NSGlobalDomain KB_DoubleQuoteOption
snapshot_default NSGlobalDomain KB_SingleQuoteOption
snapshot_default NSGlobalDomain NSNavPanelExpandedStateForSaveMode
snapshot_default NSGlobalDomain NSNavPanelExpandedStateForSaveMode2
snapshot_default NSGlobalDomain NSNavPanelFileLastListModeForOpenModeKey
snapshot_default NSGlobalDomain NSNavPanelFileListModeForOpenMode2
snapshot_default NSGlobalDomain NavPanelFileListModeForOpenMode
snapshot_default NSGlobalDomain PMPrintingExpandedStateForPrint
snapshot_default NSGlobalDomain PMPrintingExpandedStateForPrint2
snapshot_default NSGlobalDomain NSDocumentSaveNewDocumentsToCloud
snapshot_default NSGlobalDomain AppleShowAllExtensions
snapshot_default NSGlobalDomain com.apple.springing.enabled
snapshot_default NSGlobalDomain com.apple.springing.delay
snapshot_default NSGlobalDomain WebKitDeveloperExtras

snapshot_byhost_default "$HOME/Library/Preferences/ByHost/com.apple.systemuiserver.*" dontAutoLoad
snapshot_default com.apple.systemuiserver menuExtras

snapshot_default com.apple.controlcenter "NSStatusItem Visible BentoBox"
snapshot_default com.apple.controlcenter "NSStatusItem VisibleCC Battery"
snapshot_default com.apple.controlcenter "NSStatusItem VisibleCC Bluetooth"
snapshot_default com.apple.controlcenter "NSStatusItem VisibleCC WiFi"
snapshot_default com.apple.controlcenter "NSStatusItem VisibleCC Clock"
snapshot_default com.apple.controlcenter "NSStatusItem Visible Shortcuts"
snapshot_default com.apple.controlcenter RemoteLiveActivitiesEnabled
for i in {0..12}; do
  snapshot_default com.apple.controlcenter "NSStatusItem Visible Item-$i"
done

snapshot_default com.apple.AppleMultitouchTrackpad Clicking
snapshot_default com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking
snapshot_default com.apple.AppleMultitouchTrackpad TrackpadThreeFingerTapGesture
snapshot_default com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerTapGesture
snapshot_default com.apple.universalaccess closeViewScrollWheelToggle
snapshot_default com.apple.universalaccess HIDScrollZoomModifierMask
snapshot_default com.apple.universalaccess closeViewZoomFollowsFocus
snapshot_default com.apple.universalaccess reduceTransparency
snapshot_default com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)"

snapshot_default com.apple.screensaver askForPassword
snapshot_default com.apple.screensaver askForPasswordDelay
snapshot_default com.apple.screencapture disable-shadow

snapshot_default com.apple.print.PrintingPrefs "Quit When Finished"
snapshot_default com.apple.LaunchServices LSQuarantine
snapshot_default com.apple.helpviewer DevMode

snapshot_default com.apple.finder DisableAllAnimations
snapshot_default com.apple.finder NewWindowTarget
snapshot_default com.apple.finder NewWindowTargetPath
snapshot_default com.apple.finder ShowExternalHardDrivesOnDesktop
snapshot_default com.apple.finder ShowHardDrivesOnDesktop
snapshot_default com.apple.finder ShowMountedServersOnDesktop
snapshot_default com.apple.finder ShowRemovableMediaOnDesktop
snapshot_default com.apple.finder AppleShowAllFiles
snapshot_default com.apple.finder ShowStatusBar
snapshot_default com.apple.finder ShowPathbar
snapshot_default com.apple.finder _FXShowPosixPathInTitle
snapshot_default com.apple.finder _FXSortFoldersFirst
snapshot_default com.apple.finder FXDefaultSearchScope
snapshot_default com.apple.finder FXEnableExtensionChangeWarning
snapshot_default com.apple.finder WarnOnEmptyTrash
snapshot_default com.apple.finder OpenWindowForNewRemovableDisk
snapshot_default com.apple.finder FXPreferredViewStyle
snapshot_default com.apple.finder FXPreferredSearchViewStyle
snapshot_default com.apple.finder ShowSidebar
snapshot_default com.apple.finder FK_AppCentricShowSidebar
snapshot_default com.apple.finder FK_SidebarWidth
snapshot_default com.apple.finder SidebarWidth
snapshot_default com.apple.finder SidebarWidth2
snapshot_default com.apple.finder RecentsArrangeGroupViewBy
snapshot_default com.apple.finder FXInfoPanesExpanded

finder_plist="$HOME/Library/Preferences/com.apple.finder.plist"
for parent in DesktopViewSettings FK_StandardViewSettings StandardViewSettings; do
  snapshot_plist_key "$finder_plist" "$parent:IconViewSettings:showItemInfo"
  snapshot_plist_key "$finder_plist" "$parent:IconViewSettings:arrangeBy"
  snapshot_plist_key "$finder_plist" "$parent:IconViewSettings:gridSpacing"
  snapshot_plist_key "$finder_plist" "$parent:IconViewSettings:iconSize"
done
snapshot_plist_key "$finder_plist" "DesktopViewSettings:IconViewSettings:labelOnBottom"

snapshot_default com.apple.desktopservices DSDontWriteNetworkStores
snapshot_default com.apple.frameworks.diskimages auto-open-ro-root
snapshot_default com.apple.frameworks.diskimages auto-open-rw-root
snapshot_default com.apple.NetworkBrowser BrowseAllInterfaces

snapshot_default com.apple.dock orientation
snapshot_default com.apple.dock tilesize
snapshot_default com.apple.dock autohide
snapshot_default com.apple.dock launchanim
snapshot_default com.apple.dock wvous-tr-corner
snapshot_default com.apple.dock wvous-tr-modifier

snapshot_default com.apple.WindowManager HideDesktop
snapshot_default com.apple.WindowManager EnableTilingOptionAccelerator
snapshot_default com.apple.WindowManager AppWindowGroupingBehavior
snapshot_default com.apple.WindowManager AutoHide
snapshot_default com.apple.WindowManager StageManagerHideWidgets
snapshot_default com.apple.WindowManager StandardHideWidgets
snapshot_default com.apple.spaces spans-displays
snapshot_default com.apple.spotlight orderedItems

snapshot_default com.apple.Safari UniversalSearchEnabled
snapshot_default com.apple.Safari SuppressSearchSuggestions
snapshot_default com.apple.Safari WebKitTabToLinksPreferenceKey
snapshot_default com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks
snapshot_default com.apple.Safari ShowFullURLInSmartSearchField
snapshot_default com.apple.Safari HomePage
snapshot_default com.apple.Safari AutoOpenSafeDownloads
snapshot_default com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2BackspaceKeyNavigationEnabled
snapshot_default com.apple.Safari ShowFavoritesBar
snapshot_default com.apple.Safari ShowSidebarInTopSites
snapshot_default com.apple.Safari FindOnPageMatchesWordStartsOnly
snapshot_default com.apple.Safari IncludeDevelopMenu
snapshot_default com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey
snapshot_default com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled
snapshot_default com.apple.Safari WebContinuousSpellCheckingEnabled
snapshot_default com.apple.Safari AutoFillFromAddressBook
snapshot_default com.apple.Safari AutoFillPasswords
snapshot_default com.apple.Safari AutoFillCreditCardData
snapshot_default com.apple.Safari AutoFillMiscellaneousForms
snapshot_default com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically
snapshot_default com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically
snapshot_default com.apple.Safari SendDoNotTrackHTTPHeader
snapshot_default com.apple.Safari InstallExtensionUpdatesAutomatically

messages_plist="$HOME/Library/Preferences/com.apple.messageshelper.MessageController.plist"
snapshot_plist_key "$messages_plist" "SOInputLineSettings:automaticEmojiSubstitutionEnablediMessage"
snapshot_plist_key "$messages_plist" "SOInputLineSettings:automaticQuoteSubstitutionEnabled"
snapshot_plist_key "$messages_plist" "SOInputLineSettings:continuousSpellCheckingEnabled"
snapshot_default com.apple.ActivityMonitor OpenMainWindow
snapshot_default com.apple.ActivityMonitor IconType
snapshot_default com.apple.ActivityMonitor ShowCategory
snapshot_default com.apple.ActivityMonitor SortColumn
snapshot_default com.apple.ActivityMonitor SortDirection
snapshot_default com.apple.TextEdit RichText
snapshot_default com.apple.TextEdit PlainTextEncoding
snapshot_default com.apple.TextEdit PlainTextEncodingForWrite
snapshot_default com.apple.DiskUtility DUDebugMenuEnabled
snapshot_default com.apple.DiskUtility advanced-image-options
snapshot_default com.apple.TimeMachine DoNotOfferNewDisksForBackup
snapshot_default com.google.Chrome ExtensionInstallSources
snapshot_default com.google.Chrome DisablePrintPreview
snapshot_default com.google.Chrome PMPrintingExpandedStateForPrint2

hotkeys_plist="$HOME/Library/Preferences/com.apple.symbolichotkeys.plist"
for id in 18 26 28 29 30 31 64 65 164 184; do
  snapshot_plist_key "$hotkeys_plist" "AppleSymbolicHotKeys:$id:enabled"
done

snapshot_default com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID
snapshot_default com.apple.HIToolbox AppleEnabledInputSources
snapshot_default com.apple.HIToolbox AppleFnUsageType
snapshot_default com.apple.HIToolbox AppleSelectedInputSources
snapshot_default com.apple.SoftwareUpdate AutomaticCheckEnabled
snapshot_default com.apple.SoftwareUpdate ScheduleFrequency
snapshot_default com.apple.SoftwareUpdate AutomaticDownload
snapshot_default com.apple.SoftwareUpdate CriticalUpdateInstall
