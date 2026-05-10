#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Render Chrome managed-policy plist.

Emits an XML plist suitable for `/Library/Managed Preferences/com.google.Chrome.plist`
when scripts/macos/apply.sh is run with DOTFILES_APPLY_PRIVILEGED_APP_ASSETS=1.

The data lives inline below — small, rarely-changes, single consumer. Add
keys to FORCELIST or extend `build_payload` to include other policy fields.

Usage:
    scripts/macos/render-chrome-policy.py [--output <path>]
"""
from __future__ import annotations

import argparse
import pathlib
import plistlib
import sys


# Chrome extensions to force-install for every Chrome profile on this machine.
# Format: "<extension-id>;<update-url>". Update URL is the Chrome Web Store
# update endpoint for production extensions.
_CWS_UPDATE = "https://clients2.google.com/service/update2/crx"
FORCELIST: list[str] = [
    f"aeblfdkhhhdcdjpifhhbdiojplfjncoa;{_CWS_UPDATE}",  # 1Password
    f"eimadpbcbfnmbkopoojfekhnkhdbieeh;{_CWS_UPDATE}",  # Dark Reader
    f"dbepggeogbaibhgnhhndojpepiihcmeb;{_CWS_UPDATE}",  # Vimium
    f"dhdgffkkebhmkfjojejmpbldmpobfkfo;{_CWS_UPDATE}",  # Tampermonkey
]


def build_payload() -> dict:
    payload: dict = {}
    if FORCELIST:
        payload["ExtensionInstallForcelist"] = list(FORCELIST)
    return payload


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default="", help="write plist here instead of stdout")
    args = parser.parse_args(argv)

    content = plistlib.dumps(build_payload(), fmt=plistlib.FMT_XML, sort_keys=True)

    if args.output:
        pathlib.Path(args.output).write_bytes(content)
    else:
        sys.stdout.buffer.write(content)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
