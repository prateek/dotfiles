#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "scripts/audit/macos-settings-coverage.sh: macOS only; skipping."
  exit 0
fi

COVERAGE_INDEX="$(uv run --quiet --python '>=3.11' python - "$REPO_ROOT" <<'PY'
import pathlib
import sys
import tomllib

root = pathlib.Path(sys.argv[1])

def emit(items, source, default_action="yes"):
    for item in items or []:
        action = item.get("action", default_action)
        if action != "ignore":
            print(f"{item['domain']}\t{item['key']}\t{action}\t{source}")

def emit_app_defaults(defaults, source):
    if isinstance(defaults, list):
        emit(defaults, source, "yes")
        return
    for domain, values in (defaults or {}).items():
        for key in values:
            print(f"{domain}\t{key}\tyes\t{source}")

system_path = root / "home/.chezmoidata/system/macos.toml"
system = tomllib.loads(system_path.read_text())
macos = system.get("system", {}).get("macos", {})
emit(macos.get("defaults", []), "home/.chezmoidata/system/macos.toml", macos.get("default_action", "managed"))

for app_path in sorted((root / "home/.chezmoidata/apps").glob("*.toml")):
    data = tomllib.loads(app_path.read_text())
    for app in data.get("apps", {}).values():
        emit_app_defaults(app.get("defaults", {}), str(app_path.relative_to(root)))
PY
)"

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

coverage_by_repo() {
  local domain="$1"
  local key="$2"
  local line=""

  line="$(printf '%s\n' "$COVERAGE_INDEX" | awk -F '\t' -v domain="$domain" -v key="$key" '$1 == domain && $2 == key { print $3 "\t" $4; exit }')"

  if [ -n "$line" ]; then
    echo "$line"
  else
    echo "no	-"
  fi
}

echo "# macOS settings coverage (selected keys)"
echo "# Source: home/.chezmoidata/system/macos.toml and home/.chezmoidata/apps/*.toml"
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

  "com.apple.finder AppleShowAllFiles"
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

  managed_info="$(coverage_by_repo "$domain" "$key")"
  managed="${managed_info%%$'\t'*}"
  where="${managed_info#*$'\t'}"

  printf "%s\t%s\t%s\t%s\t%s\n" "$domain" "$key" "$current" "$managed" "$where"
done | LC_ALL=C sort -t $'\t' -k4,4r -k1,1 -k2,2

echo
echo "# Notes"
echo "# - This is not exhaustive; it checks a small set of high-signal preferences."
echo "# - managed=yes means this repo applies that key."
