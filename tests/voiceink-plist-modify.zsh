#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "voiceink-plist-modify: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

source_xml="$DOTFILES_ROOT/home/.chezmoitemplates/com.prakashjoshipax.VoiceInk.plist.tmpl"
script="$tmp_root/modify_voiceink.py"
current_plist="$tmp_root/current.plist"
merged_plist="$tmp_root/merged.plist"
empty_merged_plist="$tmp_root/empty-merged.plist"

/usr/bin/plutil -lint -s "$source_xml" || die "$source_xml is not a valid plist"

chezmoi \
  --source "$DOTFILES_ROOT" \
  --override-data '{"manage_zinit_external":false}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/Library/Preferences/modify_private_com.prakashjoshipax.VoiceInk.plist.tmpl" \
  >"$script"
chmod +x "$script"

uv run --quiet --python '>=3.11' python -m py_compile "$script"

uv run --quiet --python '>=3.11' python - "$current_plist" <<'PY'
import pathlib
import plistlib
import sys

path = pathlib.Path(sys.argv[1])
payload = {
    "CurrentTranscriptionModel": "local-model",
    "OpenAISelectedModel": "local-openai-model",
    "selectedAIProvider": "Local",
    "APIKeyMigrationToKeychainCompleted_v2": True,
    "customPrompts": b"local-prompts",
    "KeyboardShortcuts_pasteLastTranscription": '{"carbonKeyCode":1,"carbonModifiers":0}',
    "KeyboardShortcuts_toggleEnhancement": '{"carbonKeyCode":2,"carbonModifiers":0}',
    "KeyboardShortcuts_toggleMiniRecorder2": '{"carbonKeyCode":80,"carbonModifiers":0}',
    "didMigrateHotkeys_v2": False,
    "LicenseKeychainMigrationCompleted": True,
    "NSWindow Frame VoiceInkHistoryWindowFrame": "local-window-frame",
    "selectedAudioDeviceUID": "BuiltInMicrophoneDevice",
    "selectedHotkey1": "local-hotkey-1",
    "selectedHotkey2": "local-hotkey-2",
    "selectedPromptId": "local-prompt-id",
    "SULastCheckTime": "local-update-state",
    "VoiceInkTrialStartDate": "local-trial-state",
}
with path.open("wb") as file:
    plistlib.dump(payload, file, fmt=plistlib.FMT_BINARY)
PY

"$script" <"$current_plist" | cat >"$merged_plist"
"$script" </dev/null | cat >"$empty_merged_plist"

uv run --quiet --python '>=3.11' python - "$merged_plist" "$empty_merged_plist" <<'PY'
import json
import pathlib
import plistlib
import sys

merged = plistlib.loads(pathlib.Path(sys.argv[1]).read_bytes())
empty_merged = plistlib.loads(pathlib.Path(sys.argv[2]).read_bytes())
prompts = json.loads(merged["customPrompts"].decode("utf-8"))
empty_prompts = json.loads(empty_merged["customPrompts"].decode("utf-8"))

assert merged["CurrentTranscriptionModel"] == "parakeet-tdt-0.6b-v3"
assert merged["OpenAISelectedModel"] == "gpt-5.4-mini"
assert merged["SelectedLanguage"] == "en"
assert merged["audioInputMode"] == "Prioritized"
assert merged["selectedAIProvider"] == "OpenAI"
assert merged["isAIEnhancementEnabled"] is False
assert merged["isPauseMediaEnabled"] is False
assert merged["isSystemMuteEnabled"] is True
assert merged["useScreenCaptureContext"] is False
assert merged["IsMenuBarOnly"] is True
assert merged["powerModeUIFlag"] is False
assert merged["selectedPromptId"] == "E7CF4884-519C-4024-AA3C-EEDF43EC372B"
assert [prompt["title"] for prompt in prompts] == ["Default", "Assistant", "Edit", "diane"]
assert prompts[-1]["id"] == "E7CF4884-519C-4024-AA3C-EEDF43EC372B"
assert "You are Diane" in prompts[-1]["promptText"]
assert merged["KeyboardShortcuts_pasteLastTranscription"] == '{"carbonKeyCode":9,"carbonModifiers":2304}'
# KeyboardShortcuts_toggleEnhancement is intentionally not managed: the app
# (MiniRecorderShortcutManager) sets and clears this key based on the recorder
# window lifecycle. Persisting it would cause apply churn and risk binding the
# shortcut outside the recorder's intended visible window. We assert that the
# merge preserves the local app-managed value and never overwrites it.
assert merged["KeyboardShortcuts_toggleEnhancement"] == '{"carbonKeyCode":2,"carbonModifiers":0}'
assert merged["KeyboardShortcuts_toggleMiniRecorder2"] == '{"carbonKeyCode":80,"carbonModifiers":0}'
assert merged["selectedHotkey1"] == "none"
assert merged["selectedHotkey2"] == "custom"
assert merged["didMigrateHotkeys_v2"] is True
assert merged["APIKeyMigrationToKeychainCompleted_v2"] is True
assert merged["LicenseKeychainMigrationCompleted"] is True
assert merged["NSWindow Frame VoiceInkHistoryWindowFrame"] == "local-window-frame"
assert merged["selectedAudioDeviceUID"] == "BuiltInMicrophoneDevice"
assert merged["SULastCheckTime"] == "local-update-state"
assert merged["VoiceInkTrialStartDate"] == "local-trial-state"

assert empty_merged["CurrentTranscriptionModel"] == "parakeet-tdt-0.6b-v3"
assert empty_merged["selectedAIProvider"] == "OpenAI"
assert empty_merged["KeyboardShortcuts_pasteLastTranscription"] == '{"carbonKeyCode":9,"carbonModifiers":2304}'
# Empty stdin (no current plist): the merge must not introduce
# KeyboardShortcuts_toggleEnhancement, since the app owns its lifecycle.
assert "KeyboardShortcuts_toggleEnhancement" not in empty_merged
assert empty_merged["KeyboardShortcuts_toggleMiniRecorder2"] == '{"carbonKeyCode":80,"carbonModifiers":0}'
assert empty_merged["selectedHotkey1"] == "none"
assert empty_merged["selectedHotkey2"] == "custom"
assert empty_merged["didMigrateHotkeys_v2"] is True
assert [prompt["title"] for prompt in empty_prompts] == ["Default", "Assistant", "Edit", "diane"]
PY

print -- "OK voiceink-plist-modify"
