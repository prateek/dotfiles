#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_PATH="${1:-/Applications/cmux.app}"
DEST_ICON="$APP_PATH/Contents/Resources/AppIcon.icns"
BACKUP_DIR="$HOME/Library/Application Support/cmux/icon-backups"
BACKUP_ICON="$BACKUP_DIR/AppIcon.original.icns"
PNG_SOURCE="$REPO_ROOT/osx-apps/cmux/icon.png"
SVG_SOURCE="$REPO_ROOT/osx-apps/cmux/icon.svg"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "set-cmux-icon.sh: macOS only; skipping."
  exit 0
fi

if [ ! -d "$APP_PATH" ]; then
  echo "set-cmux-icon.sh: $APP_PATH not found; skipping."
  exit 0
fi

SOURCE_PATH=""
SOURCE_TYPE=""
if [ -f "$PNG_SOURCE" ]; then
  SOURCE_PATH="$PNG_SOURCE"
  SOURCE_TYPE="png"
elif [ -f "$SVG_SOURCE" ]; then
  SOURCE_PATH="$SVG_SOURCE"
  SOURCE_TYPE="svg"
else
  echo "set-cmux-icon.sh: missing icon source: $PNG_SOURCE or $SVG_SOURCE" >&2
  exit 1
fi

for cmd in sips iconutil codesign; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "set-cmux-icon.sh: required command not found: $cmd" >&2
    exit 1
  fi
done
if [ "$SOURCE_TYPE" = "svg" ] && ! command -v qlmanage >/dev/null 2>&1; then
  echo "set-cmux-icon.sh: required command not found: qlmanage" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

master_png="$tmpdir/icon-master.png"
iconset_dir="$tmpdir/AppIcon.iconset"
generated_icns="$tmpdir/AppIcon.icns"

if [ "$SOURCE_TYPE" = "png" ]; then
  cp "$SOURCE_PATH" "$master_png"
else
  qlmanage -t -s 1024 -o "$tmpdir" "$SOURCE_PATH" >/dev/null 2>&1
  rendered_png="$tmpdir/$(basename "$SOURCE_PATH").png"
  if [ ! -f "$rendered_png" ]; then
    echo "set-cmux-icon.sh: failed to render $SOURCE_PATH" >&2
    exit 1
  fi
  mv "$rendered_png" "$master_png"
fi

mkdir -p "$iconset_dir"

make_icon() {
  local size="$1"
  local name="$2"
  sips -z "$size" "$size" "$master_png" --out "$iconset_dir/$name" >/dev/null
}

make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png

iconutil -c icns "$iconset_dir" -o "$generated_icns"

if [ -f "$DEST_ICON" ] && cmp -s "$generated_icns" "$DEST_ICON"; then
  echo "cmux icon already up to date."
  exit 0
fi

if [ -f "$DEST_ICON" ] && [ ! -f "$BACKUP_ICON" ]; then
  mkdir -p "$BACKUP_DIR"
  cp "$DEST_ICON" "$BACKUP_ICON"
fi

install -m 0644 "$generated_icns" "$DEST_ICON"
codesign --force --deep --sign - "$APP_PATH" >/dev/null 2>&1

touch "$APP_PATH"
killall Finder >/dev/null 2>&1 || true
killall Dock >/dev/null 2>&1 || true

echo "Applied custom icon to $APP_PATH"
