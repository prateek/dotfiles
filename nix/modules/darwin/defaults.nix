{ lib, config, ... }:

# nix-darwin.system.defaults coverage of macos-defaults.sh.tmpl.
# Anything not modelled here ships in ./activation.nix (pmset/nvram/mdutil,
# inline plists for symbolichotkeys + HIToolbox, chflags, lsregister, …).

lib.mkIf config.profile.applyMacosDefaults {
  system.defaults = {
    NSGlobalDomain = {
      AppleLanguages = [ "en-GB" ];
      AppleLocale = "en_GB@rg=uszzzz";
      AppleInterfaceStyle = "Dark";
      AppleShowScrollBars = "Always";
      AppleHighlightColor = "0.764700 0.976500 0.568600";
      AppleFontSmoothing = 2;
      AppleKeyboardUIMode = 3;
      AppleShowAllExtensions = true;
      AppleMiniaturizeOnDoubleClick = false;
      NSAutomaticWindowAnimationsEnabled = false;
      NSUseAnimatedFocusRing = false;
      NSWindowResizeTime = 1.0e-3;
      KeyRepeat = 1;
      InitialKeyRepeat = 12;
      "com.apple.mouse.tapBehavior" = 1;
      "com.apple.swipescrolldirection" = false;
      "com.apple.sound.beep.volume" = 0.0;
      "com.apple.sound.beep.flash" = 0;
      "com.apple.springing.enabled" = true;
      "com.apple.springing.delay" = 0.0;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;
      NSDocumentSaveNewDocumentsToCloud = false;
      _HIHideMenuBar = false;
    };

    dock = {
      orientation = "left";
      tilesize = 45;
      autohide = true;
      launchanim = false;
      # Hot corner top-right → Desktop (4). Other codes: 2 Mission Control,
      # 3 App windows, 5 Screen saver, 11 Launchpad, 12 Notification Center,
      # 10 Display sleep.
      wvous-tr-corner = 4;
      wvous-tr-modifier = 0;
    };

    finder = {
      AppleShowAllFiles = true;
      ShowStatusBar = true;
      ShowPathbar = true;
      _FXShowPosixPathInTitle = true;
      _FXSortFoldersFirst = true;
      FXDefaultSearchScope = "SCsp";
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "Nlsv";
      ShowExternalHardDrivesOnDesktop = true;
      ShowHardDrivesOnDesktop = true;
      ShowMountedServersOnDesktop = true;
      ShowRemovableMediaOnDesktop = true;
      NewWindowTarget = "PfLo";
    };

    controlcenter = {
      BatteryShowPercentage = true;
      Bluetooth = true;
      Display = true;
      Sound = true;
    };

    WindowManager = {
      EnableTilingOptionAccelerator = false;
      AppWindowGroupingBehavior = true;
      AutoHide = false;
      StandardHideWidgets = false;
      StageManagerHideWidgets = false;
      HideDesktop = true;
    };

    spaces.spans-displays = true;

    screencapture.disable-shadow = true;

    screensaver = {
      askForPassword = true;
      askForPasswordDelay = 0;
    };

    trackpad = {
      Clicking = true;
      TrackpadThreeFingerTapGesture = 0;
    };

    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;
    LaunchServices.LSQuarantine = false;

    CustomUserPreferences = {
      "NSGlobalDomain" = {
        # Three different open-panel keys; setting fewer than all three lets
        # some code paths revert to icon view.
        NSNavPanelFileLastListModeForOpenModeKey = 2;
        NSNavPanelFileListModeForOpenMode2 = 2;
        NavPanelFileListModeForOpenMode = 2;
        shouldShowRSVPDataDetectors = false;
        KB_DoubleQuoteOption = ''"abc"'';
        KB_SingleQuoteOption = "'abc'";
        NSZoomButtonMenuOption = 2;
        WebKitDeveloperExtras = true;
      };

      "com.apple.universalaccess" = {
        closeViewScrollWheelToggle = true;
        # Ctrl + scroll = zoom (262144 = 1 << 18, the Ctrl modifier bit).
        HIDScrollZoomModifierMask = 262144;
        closeViewZoomFollowsFocus = true;
        reduceTransparency = true;
      };

      "com.apple.AppleMultitouchTrackpad" = {
        Clicking = true;
        TrackpadThreeFingerTapGesture = 0;
      };

      "com.apple.driver.AppleBluetoothMultitouch.trackpad" = {
        Clicking = true;
        TrackpadThreeFingerTapGesture = 0;
      };

      "com.apple.BluetoothAudioAgent"."Apple Bitpool Min (editable)" = 40;

      "com.apple.controlcenter" = {
        "NSStatusItem Visible BentoBox" = true;
        "NSStatusItem VisibleCC Battery" = true;
        "NSStatusItem VisibleCC Bluetooth" = true;
        "NSStatusItem VisibleCC WiFi" = true;
        "NSStatusItem VisibleCC Clock" = true;
        "NSStatusItem Visible Shortcuts" = false;
        RemoteLiveActivitiesEnabled = true;
      };

      "com.apple.systemuiserver".menuExtras = [
        "/System/Library/CoreServices/Menu Extras/Bluetooth.menu"
        "/System/Library/CoreServices/Menu Extras/AirPort.menu"
        "/System/Library/CoreServices/Menu Extras/Battery.menu"
        "/System/Library/CoreServices/Menu Extras/Clock.menu"
      ];

      "com.apple.finder" = {
        DisableAllAnimations = true;
        NewWindowTargetPath = "file:///Users/${config.users.users.${config.system.primaryUser}.name or "prateek"}/Downloads/";
        FK_AppCentricShowSidebar = true;
        FK_SidebarWidth = 143;
        SidebarWidth = 143;
        SidebarWidth2 = 205;
        ShowSidebar = true;
        WarnOnEmptyTrash = false;
        FXPreferredSearchViewStyle = "Nlsv";
        RecentsArrangeGroupViewBy = "Date Last Opened";
        FXInfoPanesExpanded = {
          General = true;
          OpenWith = true;
          Privileges = true;
        };
      };

      "com.apple.desktopservices".DSDontWriteNetworkStores = true;

      "com.apple.frameworks.diskimages" = {
        auto-open-ro-root = true;
        auto-open-rw-root = true;
      };

      "com.apple.NetworkBrowser".BrowseAllInterfaces = true;

      "com.apple.helpviewer".DevMode = true;

      "com.apple.print.PrintingPrefs"."Quit When Finished" = true;

      "com.apple.spotlight" = {
        orderedItems = [
          { enabled = 1; name = "APPLICATIONS"; }
          { enabled = 1; name = "SYSTEM_PREFS"; }
          { enabled = 1; name = "DIRECTORIES"; }
          { enabled = 1; name = "PDF"; }
          { enabled = 1; name = "FONTS"; }
          { enabled = 0; name = "DOCUMENTS"; }
          { enabled = 0; name = "MESSAGES"; }
          { enabled = 0; name = "CONTACT"; }
          { enabled = 0; name = "EVENT_TODO"; }
          { enabled = 0; name = "IMAGES"; }
          { enabled = 0; name = "BOOKMARKS"; }
          { enabled = 0; name = "MUSIC"; }
          { enabled = 0; name = "MOVIES"; }
          { enabled = 0; name = "PRESENTATIONS"; }
          { enabled = 0; name = "SPREADSHEETS"; }
          { enabled = 0; name = "SOURCE"; }
          { enabled = 0; name = "MENU_DEFINITION"; }
          { enabled = 0; name = "MENU_OTHER"; }
          { enabled = 0; name = "MENU_CONVERSION"; }
          { enabled = 0; name = "MENU_EXPRESSION"; }
          { enabled = 0; name = "MENU_WEBSEARCH"; }
          { enabled = 0; name = "MENU_SPOTLIGHT_SUGGESTIONS"; }
        ];
      };

      "com.apple.Safari" = {
        UniversalSearchEnabled = false;
        SuppressSearchSuggestions = true;
        WebKitTabToLinksPreferenceKey = true;
        ShowFullURLInSmartSearchField = true;
        HomePage = "about:blank";
        AutoOpenSafeDownloads = false;
        ShowFavoritesBar = false;
        ShowSidebarInTopSites = false;
        FindOnPageMatchesWordStartsOnly = false;
        IncludeDevelopMenu = true;
        WebKitDeveloperExtrasEnabledPreferenceKey = true;
        WebContinuousSpellCheckingEnabled = true;
        AutoFillFromAddressBook = false;
        AutoFillPasswords = false;
        AutoFillCreditCardData = false;
        AutoFillMiscellaneousForms = false;
        WebKitJavaScriptCanOpenWindowsAutomatically = false;
        SendDoNotTrackHTTPHeader = true;
        InstallExtensionUpdatesAutomatically = true;
      };

      "com.apple.ActivityMonitor" = {
        OpenMainWindow = true;
        IconType = 5;
        ShowCategory = 0;
        SortColumn = "CPUUsage";
        SortDirection = 0;
      };

      "com.apple.TextEdit" = {
        RichText = 0;
        PlainTextEncoding = 4;
        PlainTextEncodingForWrite = 4;
      };

      "com.apple.DiskUtility" = {
        DUDebugMenuEnabled = true;
        advanced-image-options = true;
      };

      "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;

      "com.google.Chrome" = {
        ExtensionInstallSources = [
          "https://gist.githubusercontent.com/"
          "http://userscripts.org/*"
        ];
        DisablePrintPreview = true;
        PMPrintingExpandedStateForPrint2 = true;
      };

      "com.apple.messageshelper.MessageController".SOInputLineSettings = {
        automaticEmojiSubstitutionEnablediMessage = false;
        automaticQuoteSubstitutionEnabled = false;
        continuousSpellCheckingEnabled = false;
      };

      "com.apple.SoftwareUpdate" = {
        AutomaticCheckEnabled = true;
        ScheduleFrequency = 1;
        AutomaticDownload = 1;
        CriticalUpdateInstall = 1;
      };
    };
  };
}
