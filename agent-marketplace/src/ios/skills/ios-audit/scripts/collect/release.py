"""Release & Compliance collector.

Captures:
- PrivacyInfo.xcprivacy presence + parsed contents
- Info.plist permissions and URL schemes
- Localization coverage (Localizable.strings per locale, .xcstrings)
- Entitlements (.entitlements)
- Signing configuration from project files
- Export compliance (ITSAppUsesNonExemptEncryption etc.)
- Known-at-risk APIs (private frameworks, UIDeviceIdentifier, etc.)

Output: <output_dir>/release.json
"""

from __future__ import annotations

import os
import plistlib
import re
import subprocess
from pathlib import Path
from typing import Any

from common import RepoInfo, safe_grep, tool_version, write_json

RISKY_APIS = [
    r"\bUIDevice\.current\.identifierForVendor",
    r"\badvertisingIdentifier",
    r"IDFA",
    r"\bAppTrackingTransparency",
    r"\bCLLocationManager",
    r"\bUNUserNotificationCenter",
    r"\bContacts\.",
    r"\bEKEventStore",
    r"\bHKHealthStore",
    r"AVCaptureDevice",
    r"PHPhotoLibrary",
    r"\bFileManager\.default\.url\(for: \.documentDirectory",
]

PRIVACY_USAGE_KEYS = [
    "NSCameraUsageDescription",
    "NSPhotoLibraryUsageDescription",
    "NSPhotoLibraryAddUsageDescription",
    "NSMicrophoneUsageDescription",
    "NSLocationWhenInUseUsageDescription",
    "NSLocationAlwaysAndWhenInUseUsageDescription",
    "NSContactsUsageDescription",
    "NSCalendarsUsageDescription",
    "NSRemindersUsageDescription",
    "NSMotionUsageDescription",
    "NSHealthShareUsageDescription",
    "NSHealthUpdateUsageDescription",
    "NSBluetoothAlwaysUsageDescription",
    "NSBluetoothPeripheralUsageDescription",
    "NSUserTrackingUsageDescription",
    "NSFaceIDUsageDescription",
    "NSSpeechRecognitionUsageDescription",
    "NSLocalNetworkUsageDescription",
]


def collect(*, repo: RepoInfo, output_dir: Path) -> None:
    root = repo.root
    out: dict[str, Any] = {
        "privacy_manifest": _privacy_manifest(root),
        "info_plists": _info_plists(root),
        "entitlements": _entitlements(root),
        "localization": _localization(root),
        "signing": _signing(root),
        "risky_apis": safe_grep(RISKY_APIS, root),
        "fastlane": _fastlane(root),
    }
    out["summary"] = {
        "has_privacy_manifest": bool(out["privacy_manifest"].get("files")),
        "num_info_plists": len(out["info_plists"]),
        "num_entitlements": len(out["entitlements"]),
        "locales": sorted({loc for lp in out["localization"]["locales"] for loc in [lp["locale"]]}),
        "risky_api_sites": len(out["risky_apis"]),
    }
    write_json(output_dir / "release.json", out)


def _privacy_manifest(root: Path) -> dict[str, Any]:
    result: dict[str, Any] = {"files": []}
    for p in root.rglob("PrivacyInfo.xcprivacy"):
        if _is_excluded(p, root):
            continue
        entry: dict[str, Any] = {"path": str(p.relative_to(root))}
        try:
            with p.open("rb") as f:
                entry["contents"] = plistlib.load(f)
        except (plistlib.InvalidFileException, OSError) as e:
            entry["error"] = str(e)
        result["files"].append(entry)
    return result


def _info_plists(root: Path) -> list[dict[str, Any]]:
    plists: list[dict[str, Any]] = []
    for p in root.rglob("Info.plist"):
        if _is_excluded(p, root):
            continue
        entry: dict[str, Any] = {"path": str(p.relative_to(root))}
        try:
            with p.open("rb") as f:
                data = plistlib.load(f)
            entry["bundle_id"] = data.get("CFBundleIdentifier")
            entry["name"] = data.get("CFBundleName")
            entry["display_name"] = data.get("CFBundleDisplayName")
            entry["version"] = data.get("CFBundleShortVersionString")
            entry["build"] = data.get("CFBundleVersion")
            entry["min_os"] = data.get("MinimumOSVersion") or data.get("LSMinimumSystemVersion")
            entry["uses_non_exempt_encryption"] = data.get("ITSAppUsesNonExemptEncryption")
            entry["url_schemes"] = [
                scheme
                for group in data.get("CFBundleURLTypes", []) or []
                for scheme in group.get("CFBundleURLSchemes", []) or []
            ]
            entry["usage_descriptions"] = {
                key: data.get(key) for key in PRIVACY_USAGE_KEYS if key in data
            }
            entry["background_modes"] = data.get("UIBackgroundModes", [])
            entry["supported_orientations"] = data.get("UISupportedInterfaceOrientations", [])
        except (plistlib.InvalidFileException, OSError) as e:
            entry["error"] = str(e)
        plists.append(entry)
    return plists


def _entitlements(root: Path) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    for p in root.rglob("*.entitlements"):
        if _is_excluded(p, root):
            continue
        entry: dict[str, Any] = {"path": str(p.relative_to(root))}
        try:
            with p.open("rb") as f:
                entry["contents"] = plistlib.load(f)
        except (plistlib.InvalidFileException, OSError) as e:
            entry["error"] = str(e)
        results.append(entry)
    return results


def _localization(root: Path) -> dict[str, Any]:
    locales: list[dict[str, Any]] = []
    xcstrings: list[dict[str, Any]] = []
    for p in root.rglob("*.lproj"):
        if _is_excluded(p, root):
            continue
        lproj = p.name.removesuffix(".lproj")
        strings = list(p.glob("*.strings"))
        entry = {
            "locale": lproj,
            "path": str(p.relative_to(root)),
            "files": [str(s.relative_to(root)) for s in strings],
            "key_counts": {},
        }
        for s in strings:
            try:
                with s.open("r", encoding="utf-8", errors="replace") as f:
                    text = f.read()
                entry["key_counts"][s.name] = len(re.findall(r'^\s*"[^"]*"\s*=', text, re.MULTILINE))
            except OSError:
                entry["key_counts"][s.name] = None
        locales.append(entry)
    for p in root.rglob("*.xcstrings"):
        if _is_excluded(p, root):
            continue
        xcstrings.append({"path": str(p.relative_to(root))})
    return {"locales": locales, "xcstrings_catalogs": xcstrings}


def _signing(root: Path) -> dict[str, Any]:
    result: dict[str, Any] = {"xcconfig": [], "pbxproj_signing": []}
    for xc in root.rglob("*.xcconfig"):
        if _is_excluded(xc, root):
            continue
        try:
            text = xc.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        if re.search(r"CODE_SIGN|DEVELOPMENT_TEAM|PROVISIONING", text):
            result["xcconfig"].append({"path": str(xc.relative_to(root)), "snippet": text[:1000]})
    for pbx in root.rglob("*.pbxproj"):
        if _is_excluded(pbx, root):
            continue
        try:
            text = pbx.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        dev_teams = set(re.findall(r"DEVELOPMENT_TEAM\s*=\s*([A-Z0-9]+);", text))
        styles = set(re.findall(r"CODE_SIGN_STYLE\s*=\s*(\w+);", text))
        if dev_teams or styles:
            result["pbxproj_signing"].append({
                "path": str(pbx.relative_to(root)),
                "development_teams": sorted(dev_teams),
                "code_sign_styles": sorted(styles),
            })
    return result


def _fastlane(root: Path) -> dict[str, Any]:
    result: dict[str, Any] = {"present": False}
    fastlane_dir = root / "fastlane"
    if not fastlane_dir.exists():
        return result
    result["present"] = True
    result["files"] = sorted(str(p.relative_to(root)) for p in fastlane_dir.rglob("*") if p.is_file())
    fastfile = fastlane_dir / "Fastfile"
    if fastfile.exists():
        try:
            text = fastfile.read_text(encoding="utf-8", errors="replace")
            result["lanes"] = re.findall(r"lane\s+:(\w+)", text)
        except OSError:
            pass
    return result


def _is_excluded(p: Path, root: Path) -> bool:
    rel = p.relative_to(root).parts
    exclude = {".git", ".build", "DerivedData", "Pods", "Carthage", ".audit", "build"}
    return any(part in exclude for part in rel)
