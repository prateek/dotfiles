#!/usr/bin/env zsh
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-${0:A:h:h}}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

mkdir -p "$tmp_root/bin"
cat >"$tmp_root/bin/cursor-agent" <<'SH'
#!/bin/sh
printf '%s\n' "$@"
SH
chmod +x "$tmp_root/bin/cursor-agent"

alias_args="$(
  PATH="$tmp_root/bin:$PATH"
  source "$REPO_ROOT/home/dot_config/zsh/lib/alias.zsh"
  yoloa "do the thing"
)"
[[ "$alias_args" == $'--yolo\n--model\ngpt-5.6-sol-xhigh-fast\ndo the thing' ]] || {
  echo "FAIL: yoloa passed unexpected arguments: $alias_args" >&2
  exit 1
}

echo "ok: yoloa enables Run Everything with GPT-5.6 Sol Extra High Fast"
