#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""Shared plist merge engine — prelude.

Each per-app modify script includes this prelude, then sets
`desired_xml` from a base64-encoded `.chezmoitemplates/<bundle-id>.plist.tmpl`
fragment, then includes plist-merge-postlude.py.

Reads stdin as the current binary plist, merges keys from the desired
fragment (preserving keys we don't manage), applies `chezmoi-delete`
directives parsed from the rendered XML, writes binary plist to stdout.
"""
import base64
import copy
import io
import os
import plistlib
import re
import sys
