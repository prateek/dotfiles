import json
from collections.abc import Callable
from dataclasses import dataclass


def check_cmux(test, merged):
    for key in merged:
        if key.startswith("shortcut."):
            test.assertIs(type(merged[key]), bytes, f"{key} must remain plist data")
    test.assert_typed_equal(
        json.loads(merged["shortcut.focusDown"]),
        {
            "command": False,
            "control": True,
            "key": "j",
            "option": False,
            "shift": False,
        },
    )
    test.assert_typed_equal(
        json.loads(merged["shortcut.prevSurface"]),
        {
            "command": True,
            "control": False,
            "key": "[",
            "option": False,
            "shift": True,
        },
    )


def check_voiceink(test, merged):
    test.assertIs(
        type(merged["customPrompts"]), bytes, "customPrompts must remain plist data"
    )
    prompts = json.loads(merged["customPrompts"])
    test.assertEqual(
        [prompt["title"] for prompt in prompts],
        ["Default", "Assistant", "Edit", "diane"],
    )
    test.assertEqual(prompts[-1]["id"], "E7CF4884-519C-4024-AA3C-EEDF43EC372B")
    test.assertIn("You are Diane", prompts[-1]["promptText"])


def check_tuna(test, merged):
    test.assertEqual(
        merged["ConfigSyncCustomFolderPath"], str(test.home / ".config/tuna")
    )


def check_moom(test, merged):
    test.assertEqual(len(merged["Custom Controls"]), 11)
    test.assertEqual(len(merged["Custom Controls (4001)"]), 11)
    test.assertEqual(merged["Custom Controls (4001)"][0].get("Title"), "Examples")
    test.assertEqual(merged["Keyboard Controls"]["Visual Representation"], "\u2303Q")


@dataclass(frozen=True)
class Scenario:
    bundle_id: str
    overrides: dict
    local: dict
    expected: dict
    check: Callable | None = None


SCENARIOS = {
    "moom": Scenario(
        bundle_id="com.manytricks.Moom",
        overrides={"Application Mode": 99, "Custom Controls": []},
        local={"SULastCheckTime": "local-state", "Unmanaged Local Key": {"kept": True}},
        expected={"Application Mode": 2},
        check=check_moom,
    ),
    "thaw": Scenario(
        bundle_id="com.stonerl.Thaw",
        overrides={
            "EnableAlwaysHiddenSection": True,
            "SUAutomaticallyUpdate": False,
            "SectionDividerStyle": 0,
        },
        local={
            "DisplayIceBarConfigurations": b"local-per-display-bar-config",
            "MenuBarAppearanceConfigurationV2": b"local-menu-bar-appearance",
            "MenuBarItemManager.knownItemIdentifiers": ["com.example.app:Item-0"],
            "NSStatusItem Preferred Position Thaw.ControlItem.Visible": 316,
            "NSWindow Frame SettingsWindow": "local-window-frame",
            "SULastCheckTime": "local-update-state",
        },
        expected={
            "EnableAlwaysHiddenSection": False,
            "SUAutomaticallyUpdate": True,
            "SUEnableAutomaticChecks": True,
            "SectionDividerStyle": 1,
        },
    ),
    "orbstack": Scenario(
        bundle_id="dev.kdrag0n.MacVirt",
        overrides={"global_showMenubarExtra": False},
        local={
            "drm_lastState": '{"entitlementTier":0,"entitlementType":0}',
            "selectedTab": "k8s-pods",
            "NSWindow Frame main": "local-window-frame",
            "SULastCheckTime": "local-update-state",
        },
        expected={"global_showMenubarExtra": True},
    ),
    "nvalt": Scenario(
        bundle_id="net.elasticthreads.nv",
        overrides={
            "AppActivationKeyCode": 999,
            "Bookmarks": ["local"],
            "DefaultEEIdentifier": "local.editor",
        },
        local={
            "DirectoryAlias": b"local-directory-alias",
            "NSWindow Frame NotationWindow": "local-window-frame",
            "SULastCheckTime": "local-update-state",
        },
        expected={
            "AppActivationKeyCode": 49,
            "AppActivationModifiers": 2048,
            "Bookmarks": [],
            "BookmarksVisible": False,
            "ColorScheme": 2,
            "DefaultEEIdentifier": "com.microsoft.VSCode",
            "UserEEIdentifiers": [
                "com.apple.TextEdit",
                "dev.zed.Zed",
                "com.todesktop.230313mzl4w4u92",
                "com.microsoft.VSCode",
            ],
            "ShowDockIcon": False,
            "StatusBarItem": True,
        },
    ),
    "bettertouchtool": Scenario(
        bundle_id="com.hegenberg.BetterTouchTool",
        overrides={"BTTClipboardManagerEnabledFromShortcuts": False},
        local={
            "BTTDropboxSyncActive": False,
            "BTTIdentifierX": "local-identifier",
            "BTTSyncCloudProvider": 0,
            "BTTTrialDate": 7,
            "BTTUsageData": {"2026-04-29": {"local": 1}},
        },
        expected={
            "BTTClipboardManagerEnabledFromShortcuts": True,
            "BTTRemoteEnabled": False,
        },
    ),
    "raycast": Scenario(
        bundle_id="com.raycast.macos",
        overrides={"navigationCommandStyleIdentifierKey": "default"},
        local={
            "raycastAnonymousId": "local-anonymous-id",
            "cloudSync_lastSyncDate": "local-sync-date",
            "mainWindowPositionCache": {"local-display": "{1, 2}"},
        },
        expected={"navigationCommandStyleIdentifierKey": "vim"},
    ),
    "tailscale": Scenario(
        bundle_id="io.tailscale.ipn.macsys",
        overrides={"HideDockIcon": False},
        local={
            "DidSetVPNOnDemandIsUserConfigured": False,
            "VPNOnDemandIsUserConfigured": True,
            "com.tailscale.cached.currentProfile": b"local-profile",
            "com.tailscale.cached.profiles": b"local-profiles",
            "com.tailscale.ipn.restartState": "restartVPNIfNeeded",
        },
        expected={"HideDockIcon": True, "UnstableUpdatesEnabled": False},
    ),
    "setapp": Scenario(
        bundle_id="com.setapp.DesktopClient",
        overrides={"EnableLauncher": True},
        local={
            "APNSDeviceTokenString": "local-token",
            "CurrentUserAccount": "local-account@example.invalid",
            "known_customers": [{"accountName": "local-account@example.invalid"}],
        },
        expected={"EnableLauncher": False},
    ),
    "betterdisplay": Scenario(
        bundle_id="pro.betterdisplay.BetterDisplay",
        overrides={"menuLevelContrast": "more"},
        local={
            "Paddle-BetterDisplay-762421-SD": b"local-license",
            "displayTagIDs": [2, 4, 5],
            "currentColorProfileURL@Display:2": "local-profile",
        },
        expected={"menuLevelContrast": "hide", "SUSendProfileInfo": False},
    ),
    "cmux": Scenario(
        bundle_id="com.cmuxterm.app",
        overrides={
            "appearanceMode": "dark",
            "browserHostWhitelist": "old.example",
            "shortcut.focusDown": b'{"command":true,"control":false,"key":"x","option":false'
            b',"shift":false}',
        },
        local={
            "cmux.session.lastWindowGeometry.v1": b"local-window-state",
            "posthog.lastActiveDayUTC": "local-state",
            "Unmanaged Local Key": {"kept": True},
        },
        expected={
            "appearanceMode": "dark",
            "browserHostWhitelist": "chatgpt.com\n"
            "google.com\n"
            "gmail.com\n"
            "anthropic.com\n"
            "openai.com",
            "browserThemeMode": "system",
            "sidebarActiveTabIndicatorStyle": "solidFill",
            "sidebarAppearanceDefaultsVersion": 1,
            "sidebarTintOpacity": 0.18,
        },
        check=check_cmux,
    ),
    "voiceink": Scenario(
        bundle_id="com.prakashjoshipax.VoiceInk",
        overrides={
            "CurrentTranscriptionModel": "local-model",
            "OpenAISelectedModel": "local-openai-model",
            "selectedAIProvider": "Local",
            "customPrompts": b"local-prompts",
            "KeyboardShortcuts_pasteLastTranscription": '{"carbonKeyCode":1,"carbonModifiers":0}',
            "KeyboardShortcuts_toggleMiniRecorder2": '{"carbonKeyCode":80,"carbonModifiers":0}',
            "didMigrateHotkeys_v2": False,
            "selectedHotkey1": "local-hotkey-1",
            "selectedHotkey2": "local-hotkey-2",
            "selectedPromptId": "local-prompt-id",
        },
        # The recorder owns toggleEnhancement's lifecycle; managing it can bind
        # the shortcut outside the visible recorder window and cause apply churn.
        local={
            "APIKeyMigrationToKeychainCompleted_v2": True,
            "KeyboardShortcuts_toggleEnhancement": '{"carbonKeyCode":2,"carbonModifiers":0}',
            "LicenseKeychainMigrationCompleted": True,
            "NSWindow Frame VoiceInkHistoryWindowFrame": "local-window-frame",
            "selectedAudioDeviceUID": "BuiltInMicrophoneDevice",
            "SULastCheckTime": "local-update-state",
            "VoiceInkTrialStartDate": "local-trial-state",
        },
        expected={
            "CurrentTranscriptionModel": "parakeet-tdt-0.6b-v3",
            "OpenAISelectedModel": "gpt-5.4-mini",
            "SelectedLanguage": "en",
            "audioInputMode": "Prioritized",
            "selectedAIProvider": "Gemini",
            "isAIEnhancementEnabled": True,
            "isPauseMediaEnabled": False,
            "isSystemMuteEnabled": True,
            "useScreenCaptureContext": False,
            "IsMenuBarOnly": True,
            "powerModeUIFlag": False,
            "selectedPromptId": "E7CF4884-519C-4024-AA3C-EEDF43EC372B",
            "KeyboardShortcuts_pasteLastTranscription": '{"carbonKeyCode":9,"carbonModifiers":2304}',
            "KeyboardShortcuts_toggleMiniRecorder2": '{"carbonKeyCode":80,"carbonModifiers":0}',
            "selectedHotkey1": "none",
            "selectedHotkey2": "custom",
            "didMigrateHotkeys_v2": True,
        },
        check=check_voiceink,
    ),
    "tuna": Scenario(
        bundle_id="com.brnbw.Tuna",
        overrides={
            "ConfigSyncUsesCustomFolder": False,
            "ConfigSyncCustomFolderPath": "/old/config",
            "CLIEnabled": False,
            "URLSchemeAllowsShellCommandExecution": False,
        },
        local={
            "KeyboardShortcuts_activate": '{"carbonKeyCode":99,"carbonModifiers":0}',
            "NSWindow Frame Settings": "local-window-frame",
            "SULastCheckTime": "local-update-state",
            "Unmanaged Local Key": {"catalog": ["local-entry"]},
        },
        expected={
            "ConfigSyncUsesCustomFolder": True,
            "CLIEnabled": True,
            "URLSchemeAllowsShellCommandExecution": True,
        },
        check=check_tuna,
    ),
}
