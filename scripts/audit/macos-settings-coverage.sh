#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
MACOS_SCRIPT="${MACOS_SCRIPT:-$REPO_ROOT/macos}"
APPLY_SCRIPT="${APPLY_SCRIPT:-$REPO_ROOT/scripts/macos/apply.sh}"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "scripts/audit/macos-settings-coverage.sh: macOS only; skipping."
  exit 0
fi

if [ ! -f "$MACOS_SCRIPT" ]; then
  echo "macos settings script not found: $MACOS_SCRIPT" >&2
  exit 1
fi

read_value() {
  local domain="$1"
  local key="$2"

  if [ "$domain" = "NSGlobalDomain" ]; then
    defaults read -g "$key" 2>/dev/null || true
  else
    defaults read "$domain" "$key" 2>/dev/null || true
  fi
}

collapse() {
  # collapse whitespace/newlines, keep it readable
  tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

managed_by_repo() {
  local domain="$1"
  local key="$2"

  # Special case: Text replacements are applied via `plutil` in scripts/macos/apply.sh.
  if [ "$domain" = "NSGlobalDomain" ] && [ "$key" = "NSUserDictionaryReplacementItems" ] && [ -f "$APPLY_SCRIPT" ]; then
    local line=""
    if command -v rg >/dev/null 2>&1; then
      line="$(rg -n "NSUserDictionaryReplacementItems" "$APPLY_SCRIPT" | head -n 1 || true)"
    else
      line="$(grep -n "NSUserDictionaryReplacementItems" "$APPLY_SCRIPT" | head -n 1 || true)"
    fi
    if [ -n "$line" ]; then
      echo "yes	${line%%:*}:${line#*:}"
    else
      echo "no	-"
    fi
    return 0
  fi

  local line=""
  local needle="defaults write $domain $key "
  if [ "$domain" = "NSGlobalDomain" ]; then
    if command -v rg >/dev/null 2>&1; then
      line="$(rg -nF "$needle" "$MACOS_SCRIPT" | head -n 1 || true)"
    else
      line="$(grep -nF "$needle" "$MACOS_SCRIPT" | head -n 1 || true)"
    fi
  else
    if command -v rg >/dev/null 2>&1; then
      line="$(rg -nF "$needle" "$MACOS_SCRIPT" | head -n 1 || true)"
    else
      line="$(grep -nF "$needle" "$MACOS_SCRIPT" | head -n 1 || true)"
    fi
  fi

  if [ -n "$line" ]; then
    echo "yes	${line%%:*}:${line#*:}"
  else
    echo "no	-"
  fi
}

echo "# macOS settings coverage (selected keys)"
echo "# Scripts: $MACOS_SCRIPT | $APPLY_SCRIPT"
echo

printf "domain\tkey\tcurrent_value\tmanaged\twhere\n"

keys=(
  "NSGlobalDomain KeyRepeat"
  "NSGlobalDomain InitialKeyRepeat"
  "NSGlobalDomain AppleShowScrollBars"
  "NSGlobalDomain NSDocumentSaveNewDocumentsToCloud"
  "NSGlobalDomain NSDisableAutomaticTermination"
  "NSGlobalDomain AppleKeyboardUIMode"
  "NSGlobalDomain com.apple.sound.beep.volume"
  "NSGlobalDomain com.apple.sound.beep.feedback"
  "NSGlobalDomain NSUserDictionaryReplacementItems"

  "com.apple.dock orientation"
  "com.apple.dock tilesize"
  "com.apple.dock autohide"
  "com.apple.dock autohide-delay"
  "com.apple.dock autohide-time-modifier"
  "com.apple.dock mru-spaces"
  "com.apple.dock showhidden"

  "com.apple.screencapture location"
  "com.apple.screencapture type"
  "com.apple.screencapture disable-shadow"

  "com.apple.finder NewWindowTargetPath"
  "com.apple.finder ShowStatusBar"
  "com.apple.finder ShowPathbar"
  "NSGlobalDomain AppleShowAllExtensions"
)

for item in "${keys[@]}"; do
  domain="${item%% *}"
  key="${item#* }"

  current="$(read_value "$domain" "$key" | collapse)"
  [ -n "$current" ] || current="(unset)"

  managed_info="$(managed_by_repo "$domain" "$key")"
  managed="${managed_info%%$'\t'*}"
  where="${managed_info#*$'\t'}"

  printf "%s\t%s\t%s\t%s\t%s\n" "$domain" "$key" "$current" "$managed" "$where"
done | LC_ALL=C sort -t $'\t' -k4,4r -k1,1 -k2,2

echo
echo "# Notes"
echo "# - This is not exhaustive; it checks a small set of high-signal preferences."
echo "# - 'managed=yes' means this repo applies that key (not necessarily the same current value)."
