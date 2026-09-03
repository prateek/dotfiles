#!/usr/bin/env bash
set -euo pipefail

uv_target="$HOME/.local/bin/uv"
if [[ -x "$uv_target" ]] && "$uv_target" --version >/dev/null 2>&1; then
  exit 0
fi

[[ "$(uname -s)" == "Linux" ]] || exit 0
[[ "$(uname -m)" == "x86_64" ]] || {
  echo "headless uv hook: x86_64 is the only supported Linux architecture" >&2
  exit 1
}

for tool in curl install sha256sum tar; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "headless uv hook: $tool is required to install uv" >&2
    exit 1
  }
done

readonly uv_version="0.12.9"
readonly uv_asset="uv-x86_64-unknown-linux-gnu"
readonly uv_sha256="ec7a99cd05e0cd7f80243f135ce1361c76835cb0ee60055d14d20eba8eba1460"
readonly uv_url="https://github.com/astral-sh/uv/releases/download/${uv_version}/${uv_asset}.tar.gz"

uv_tmp="$(mktemp -d)"
uv_archive="$uv_tmp/$uv_asset.tar.gz"
uv_target_tmp="$uv_target.tmp.$$"
cleanup() {
  rm -rf "$uv_tmp"
  rm -f "$uv_target_tmp"
}
trap cleanup EXIT

echo "headless uv hook: installing uv $uv_version" >&2
curl --fail --location --retry 3 --output "$uv_archive" "$uv_url"
printf '%s  %s\n' "$uv_sha256" "$uv_archive" |
  sha256sum --check --status
tar -xzf "$uv_archive" -C "$uv_tmp"
mkdir -p "$HOME/.local/bin"
install -m 0755 "$uv_tmp/$uv_asset/uv" "$uv_target_tmp"
mv -f "$uv_target_tmp" "$uv_target"
"$uv_target" --version >/dev/null 2>&1 || {
  echo "headless uv hook: uv $uv_version installation failed" >&2
  exit 1
}
