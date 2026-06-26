#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "selected-app-plist-modify: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

apps=(
  "bettertouchtool:com.hegenberg.BetterTouchTool"
  "raycast:com.raycast.macos"
  "tailscale:io.tailscale.ipn.macsys"
  "setapp:com.setapp.DesktopClient"
  "betterdisplay:pro.betterdisplay.BetterDisplay"
)

for app_spec in "${apps[@]}"; do
  app_name="${app_spec%%:*}"
  domain="${app_spec#*:}"
  source_xml="$DOTFILES_ROOT/home/.chezmoitemplates/$domain.plist.tmpl"
  script="$tmp_root/modify_$app_name.py"

  /usr/bin/plutil -lint -s "$source_xml" || die "$source_xml is not a valid plist"

  chezmoi \
    --source "$DOTFILES_ROOT" \
    --override-data '{}' \
    execute-template \
    --file "$DOTFILES_ROOT/home/Library/private_Preferences/modify_private_$domain.plist.tmpl" \
    >"$script"
  chmod +x "$script"
  bash -n "$script"
done

uv run --quiet --python '>=3.11' python - "$tmp_root" "$DOTFILES_ROOT" <<'PY'
import pathlib
import plistlib
import subprocess
import sys

tmp_root = pathlib.Path(sys.argv[1])
dotfiles_root = pathlib.Path(sys.argv[2])
templates_root = dotfiles_root / "home/.chezmoitemplates"

cases = {
    "bettertouchtool": {
        "domain": "com.hegenberg.BetterTouchTool",
        "current": {
            "BTTClipboardManagerEnabledFromShortcuts": False,
            "BTTDropboxSyncActive": False,
            "BTTIdentifierX": "local-identifier",
            "BTTSyncCloudProvider": 0,
            "BTTTrialDate": 7,
            "BTTUsageData": {"2026-04-29": {"local": 1}},
        },
        "local": {
            "BTTDropboxSyncActive": False,
            "BTTIdentifierX": "local-identifier",
            "BTTSyncCloudProvider": 0,
            "BTTTrialDate": 7,
            "BTTUsageData": {"2026-04-29": {"local": 1}},
        },
    },
    "raycast": {
        "domain": "com.raycast.macos",
        "current": {
            "navigationCommandStyleIdentifierKey": "default",
            "raycastAnonymousId": "local-anonymous-id",
            "cloudSync_lastSyncDate": "local-sync-date",
            "mainWindowPositionCache": {"local-display": "{1, 2}"},
        },
        "local": {
            "raycastAnonymousId": "local-anonymous-id",
            "cloudSync_lastSyncDate": "local-sync-date",
            "mainWindowPositionCache": {"local-display": "{1, 2}"},
        },
    },
    "tailscale": {
        "domain": "io.tailscale.ipn.macsys",
        "current": {
            "DidSetVPNOnDemandIsUserConfigured": False,
            "HideDockIcon": False,
            "VPNOnDemandIsUserConfigured": True,
            "com.tailscale.cached.currentProfile": b"local-profile",
            "com.tailscale.cached.profiles": b"local-profiles",
            "com.tailscale.ipn.restartState": "restartVPNIfNeeded",
        },
        "local": {
            "DidSetVPNOnDemandIsUserConfigured": False,
            "VPNOnDemandIsUserConfigured": True,
            "com.tailscale.cached.currentProfile": b"local-profile",
            "com.tailscale.cached.profiles": b"local-profiles",
            "com.tailscale.ipn.restartState": "restartVPNIfNeeded",
        },
    },
    "setapp": {
        "domain": "com.setapp.DesktopClient",
        "current": {
            "EnableLauncher": True,
            "APNSDeviceTokenString": "local-token",
            "CurrentUserAccount": "local-account@example.invalid",
            "known_customers": [{"accountName": "local-account@example.invalid"}],
        },
        "local": {
            "APNSDeviceTokenString": "local-token",
            "CurrentUserAccount": "local-account@example.invalid",
            "known_customers": [{"accountName": "local-account@example.invalid"}],
        },
    },
    "betterdisplay": {
        "domain": "pro.betterdisplay.BetterDisplay",
        "current": {
            "menuLevelContrast": "more",
            "Paddle-BetterDisplay-762421-SD": b"local-license",
            "displayTagIDs": [2, 4, 5],
            "currentColorProfileURL@Display:2": "local-profile",
        },
        "local": {
            "Paddle-BetterDisplay-762421-SD": b"local-license",
            "displayTagIDs": [2, 4, 5],
            "currentColorProfileURL@Display:2": "local-profile",
        },
    },
}

for app_name, spec in cases.items():
    domain = spec["domain"]
    desired = plistlib.loads((templates_root / f"{domain}.plist.tmpl").read_bytes())
    current_path = tmp_root / f"{app_name}-current.plist"
    merged_path = tmp_root / f"{app_name}-merged.plist"
    empty_merged_path = tmp_root / f"{app_name}-empty-merged.plist"
    script = tmp_root / f"modify_{app_name}.py"

    current_path.write_bytes(plistlib.dumps(spec["current"], fmt=plistlib.FMT_BINARY))
    merged_path.write_bytes(subprocess.check_output([str(script)], input=current_path.read_bytes()))
    empty_merged_path.write_bytes(subprocess.check_output([str(script)], input=b""))

    merged = plistlib.loads(merged_path.read_bytes())
    empty_merged = plistlib.loads(empty_merged_path.read_bytes())

    for key, value in desired.items():
        assert merged[key] == value, (app_name, key, merged.get(key), value)
        assert empty_merged[key] == value, (app_name, key, empty_merged.get(key), value)

    for key, value in spec["local"].items():
        assert merged[key] == value, (app_name, key, merged.get(key), value)
        assert key not in empty_merged, (app_name, key)
PY

print -- "OK selected-app-plist-modify"
